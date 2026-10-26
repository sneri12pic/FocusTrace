package com.stepandemianenko.focustrace

import android.content.Context
import android.os.Build
import androidx.annotation.RequiresApi
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.HealthConnectFeatures
import androidx.health.connect.client.changes.DeletionChange
import androidx.health.connect.client.changes.UpsertionChange
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.request.ChangesTokenRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import java.time.Duration
import java.time.Instant
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * Reads exercise sessions from Health Connect into [HealthConnectStore].
 *
 * Read-only: FocusTrace writes nothing to Health Connect. The first run (and
 * any run after the changes token expired) reconciles the last 30 days, the
 * most Health Connect lets an app read without the history permission; later
 * runs apply the change log, so updates, deletions and late-arriving sessions
 * from the source app are mirrored. The token is saved only after a run
 * finishes, so an interrupted run repeats safely: every write is an upsert or
 * delete keyed by the Health Connect record id.
 */
class HealthConnectImporter(
    context: Context,
    private val store: HealthConnectStore = HealthConnectStore(context),
    /** Tests only; the real client comes from the installed provider. */
    private val clientOverride: HealthConnectClient? = null,
) {
    private val app = context.applicationContext

    data class Result(val outcome: String, val changed: Int)

    fun sdkStatus(): String = when {
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O -> STATUS_UNAVAILABLE
        else -> when (HealthConnectClient.getSdkStatus(app)) {
            HealthConnectClient.SDK_AVAILABLE -> STATUS_AVAILABLE
            HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED ->
                STATUS_UPDATE_REQUIRED
            else -> STATUS_UNAVAILABLE
        }
    }

    fun client(): HealthConnectClient? = clientOverride
        ?: if (sdkStatus() == STATUS_AVAILABLE) HealthConnectClient.getOrCreate(app) else null

    suspend fun grantedPermissions(): Set<String> =
        client()?.permissionController?.getGrantedPermissions() ?: emptySet()

    fun backgroundReadSupported(): Boolean {
        val client = client() ?: return false
        return client.features.getFeatureStatus(
            HealthConnectFeatures.FEATURE_READ_HEALTH_DATA_IN_BACKGROUND,
        ) == HealthConnectFeatures.FEATURE_STATUS_AVAILABLE
    }

    /** Settings and permissions are rechecked on every run, foreground or not. */
    suspend fun run(
        inBackground: Boolean,
        nowMillis: Long = System.currentTimeMillis(),
    ): Result {
        if (!store.enabled) return Result(OUTCOME_DISABLED, 0)
        // The client library needs API 26; sdkStatus() already reports unavailable below it.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            store.recordAttempt(OUTCOME_UNAVAILABLE, 0, nowMillis)
            return Result(OUTCOME_UNAVAILABLE, 0)
        }
        // One run at a time per process, so a manual import and the worker never interleave.
        return runLock.withLock { runLocked(inBackground, Instant.ofEpochMilli(nowMillis)) }
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private suspend fun runLocked(inBackground: Boolean, now: Instant): Result {
        if (!store.enabled) return Result(OUTCOME_DISABLED, 0)
        val result = try {
            runChecked(inBackground, now)
        } catch (_: SecurityException) {
            Result(OUTCOME_PERMISSION_MISSING, 0)
        } catch (_: Exception) {
            Result(OUTCOME_FAILED, 0)
        }
        // A run cut short by turning the integration off records nothing.
        if (result.outcome != OUTCOME_DISABLED && store.enabled) {
            store.recordAttempt(result.outcome, result.changed, now.toEpochMilli())
        }
        return result
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private suspend fun runChecked(inBackground: Boolean, now: Instant): Result {
        val client = client() ?: return Result(
            if (sdkStatus() == STATUS_UPDATE_REQUIRED) OUTCOME_UPDATE_REQUIRED
            else OUTCOME_UNAVAILABLE,
            0,
        )
        val granted = client.permissionController.getGrantedPermissions()
        if (READ_EXERCISE !in granted) return Result(OUTCOME_PERMISSION_MISSING, 0)
        if (inBackground &&
            (!backgroundReadSupported() || READ_IN_BACKGROUND !in granted)
        ) {
            return Result(OUTCOME_BACKGROUND_PERMISSION_MISSING, 0)
        }

        var changed = 0
        var token = store.changesToken
        if (token != null) {
            while (true) {
                val response = client.getChanges(token!!)
                if (response.changesTokenExpired) {
                    token = null
                    break
                }
                if (!store.enabled) return Result(OUTCOME_DISABLED, 0)
                for (change in response.changes) {
                    when (change) {
                        is UpsertionChange -> {
                            val record = change.record as? ExerciseSessionRecord ?: continue
                            if (record.metadata.dataOrigin.packageName == app.packageName) continue
                            if (store.upsert(record.toWorkout())) changed++
                        }
                        is DeletionChange -> if (store.delete(change.recordId)) changed++
                    }
                }
                token = response.nextChangesToken
                if (!response.hasMore) break
            }
        }
        if (token == null) {
            // Taken before reading, so anything written meanwhile is picked up next run.
            token = client.getChangesToken(
                ChangesTokenRequest(setOf(ExerciseSessionRecord::class)),
            )
            val from = now.minus(Duration.ofDays(RECONCILE_DAYS))
            val to = now.plus(Duration.ofDays(1))
            val seen = mutableSetOf<String>()
            var pageToken: String? = null
            do {
                val response = client.readRecords(
                    ReadRecordsRequest(
                        recordType = ExerciseSessionRecord::class,
                        timeRangeFilter = TimeRangeFilter.between(from, to),
                        pageToken = pageToken,
                    ),
                )
                if (!store.enabled) return Result(OUTCOME_DISABLED, 0)
                for (record in response.records) {
                    if (record.metadata.dataOrigin.packageName == app.packageName) continue
                    seen += record.metadata.id
                    if (store.upsert(record.toWorkout())) changed++
                }
                pageToken = response.pageToken
            } while (pageToken != null)
            changed += store.deleteMissingBetween(from.toEpochMilli(), to.toEpochMilli(), seen)
        }
        if (!store.enabled) return Result(OUTCOME_DISABLED, 0)
        store.changesToken = token
        return Result(if (changed > 0) OUTCOME_IMPORTED else OUTCOME_NO_NEW, changed)
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun ExerciseSessionRecord.toWorkout() = ImportedWorkout(
        id = metadata.id,
        sourcePackage = metadata.dataOrigin.packageName,
        exerciseType = exerciseType,
        title = title,
        startMillis = startTime.toEpochMilli(),
        endMillis = endTime.toEpochMilli(),
        startZoneOffsetSeconds = startZoneOffset?.totalSeconds,
        lastModifiedMillis = metadata.lastModifiedTime.toEpochMilli(),
    )

    companion object {
        const val STATUS_AVAILABLE = "available"
        const val STATUS_UNAVAILABLE = "unavailable"
        const val STATUS_UPDATE_REQUIRED = "updateRequired"

        const val OUTCOME_IMPORTED = HealthConnectStore.OUTCOME_IMPORTED
        const val OUTCOME_NO_NEW = HealthConnectStore.OUTCOME_NO_NEW
        const val OUTCOME_DISABLED = "disabled"
        const val OUTCOME_UNAVAILABLE = "unavailable"
        const val OUTCOME_UPDATE_REQUIRED = "updateRequired"
        const val OUTCOME_PERMISSION_MISSING = "permissionMissing"
        const val OUTCOME_BACKGROUND_PERMISSION_MISSING = "backgroundPermissionMissing"
        const val OUTCOME_FAILED = "failed"

        val READ_EXERCISE = HealthPermission.getReadPermission(ExerciseSessionRecord::class)
        const val READ_IN_BACKGROUND = HealthPermission.PERMISSION_READ_HEALTH_DATA_IN_BACKGROUND
        private const val RECONCILE_DAYS = 30L
        private val runLock = Mutex()
    }
}
