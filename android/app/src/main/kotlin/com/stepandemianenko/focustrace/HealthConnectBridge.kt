package com.stepandemianenko.focustrace

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.records.ExerciseSessionRecord
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * `focustrace/health_connect`: settings, permission requests and manual
 * imports for the optional Health Connect integration. Every call answers
 * with the full current state, so Flutter never has to guess.
 */
class HealthConnectBridge(private val activity: Activity) {
    private val store = HealthConnectStore(activity)
    private val importer = HealthConnectImporter(activity, store)
    private val scope = MainScope()
    private var pendingPermissions: ((Set<String>) -> Unit)? = null

    fun configure(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            scope.launch {
                try {
                    when (call.method) {
                        "state" -> result.success(state())
                        "enable" -> result.success(enable())
                        "disable" -> {
                            store.enabled = false
                            HealthConnectScheduler.reconcile(activity)
                            result.success(state())
                        }
                        "setAutoImport" -> result.success(setAutoImport(call.arguments == true))
                        "importNow" -> {
                            withContext(Dispatchers.IO) { importer.run(inBackground = false) }
                            result.success(state())
                        }
                        "workouts" -> result.success(withContext(Dispatchers.IO) { workouts() })
                        "clearImported" -> {
                            withContext(Dispatchers.IO) { store.clearImported() }
                            result.success(state())
                        }
                        "openPermissionSettings" -> {
                            openPermissionSettings()
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("HEALTH_CONNECT_FAILED", error.javaClass.simpleName, null)
                }
            }
        }
    }

    /** Returns true when the result belonged to a Health Connect request. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) return false
        val granted = PermissionController.createRequestPermissionResultContract()
            .parseResult(resultCode, data)
        pendingPermissions?.invoke(granted)
        pendingPermissions = null
        return true
    }

    fun dispose() = scope.cancel()

    private suspend fun enable(): Map<String, Any?> {
        if (importer.client() == null) return state()
        if (requestIfMissing(setOf(HealthConnectImporter.READ_EXERCISE))) {
            store.enabled = true
            HealthConnectScheduler.reconcile(activity)
        }
        return state()
    }

    private suspend fun setAutoImport(on: Boolean): Map<String, Any?> {
        if (!on) {
            store.autoImport = false
        } else if (importer.backgroundReadSupported() &&
            requestIfMissing(setOf(HealthConnectImporter.READ_IN_BACKGROUND))
        ) {
            store.autoImport = true
        }
        HealthConnectScheduler.reconcile(activity)
        return state()
    }

    /** Asks only for what is not granted yet; true once all of [permissions] are held. */
    private suspend fun requestIfMissing(permissions: Set<String>): Boolean {
        val granted = importer.grantedPermissions()
        if (granted.containsAll(permissions)) return true
        if (pendingPermissions != null) return false
        val intent = PermissionController.createRequestPermissionResultContract()
            .createIntent(activity, permissions - granted)
        val result = CompletableDeferred<Set<String>>()
        pendingPermissions = { result.complete(it) }
        try {
            @Suppress("DEPRECATION")
            activity.startActivityForResult(intent, PERMISSION_REQUEST_CODE)
        } catch (_: ActivityNotFoundException) {
            pendingPermissions = null
            return false
        }
        return (granted + result.await()).containsAll(permissions)
    }

    private suspend fun state(): Map<String, Any?> {
        val sdkStatus = importer.sdkStatus()
        val granted = if (sdkStatus == HealthConnectImporter.STATUS_AVAILABLE) {
            try {
                importer.grantedPermissions()
            } catch (_: Exception) {
                emptySet()
            }
        } else {
            emptySet()
        }
        return withContext(Dispatchers.IO) {
            mapOf(
                "sdkStatus" to sdkStatus,
                "enabled" to store.enabled,
                "autoImport" to store.autoImport,
                "readGranted" to (HealthConnectImporter.READ_EXERCISE in granted),
                "backgroundGranted" to (HealthConnectImporter.READ_IN_BACKGROUND in granted),
                "backgroundSupported" to (
                    sdkStatus == HealthConnectImporter.STATUS_AVAILABLE &&
                        importer.backgroundReadSupported()
                    ),
                "lastSuccessMillis" to store.lastSuccessMillis,
                "lastAttemptMillis" to store.lastAttemptMillis,
                "lastOutcome" to store.lastOutcome,
                "lastImportedCount" to store.lastImportedCount,
                "workoutCount" to store.workoutCount(),
            )
        }
    }

    private fun workouts(): List<Map<String, Any?>> {
        val labels = mutableMapOf<String, String>()
        return store.workouts().map { workout ->
            mapOf(
                "id" to workout.id,
                "sourcePackage" to workout.sourcePackage,
                "sourceName" to labels.getOrPut(workout.sourcePackage) {
                    appLabel(workout.sourcePackage)
                },
                "exerciseType" to workout.exerciseType,
                "category" to category(workout.exerciseType),
                "title" to workout.title,
                "startMillis" to workout.startMillis,
                "endMillis" to workout.endMillis,
                "startZoneOffsetSeconds" to workout.startZoneOffsetSeconds,
            )
        }
    }

    /** A coarse label Flutter can localize; the exact type stays available. */
    private fun category(type: Int): String = when (type) {
        ExerciseSessionRecord.EXERCISE_TYPE_STRENGTH_TRAINING,
        ExerciseSessionRecord.EXERCISE_TYPE_WEIGHTLIFTING,
        ExerciseSessionRecord.EXERCISE_TYPE_CALISTHENICS -> "strength"
        ExerciseSessionRecord.EXERCISE_TYPE_RUNNING,
        ExerciseSessionRecord.EXERCISE_TYPE_RUNNING_TREADMILL -> "running"
        ExerciseSessionRecord.EXERCISE_TYPE_WALKING -> "walking"
        ExerciseSessionRecord.EXERCISE_TYPE_BIKING,
        ExerciseSessionRecord.EXERCISE_TYPE_BIKING_STATIONARY -> "cycling"
        ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_OPEN_WATER,
        ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_POOL -> "swimming"
        ExerciseSessionRecord.EXERCISE_TYPE_YOGA -> "yoga"
        else -> "other"
    }

    private fun appLabel(packageName: String): String = try {
        val pm = activity.packageManager
        pm.getApplicationLabel(pm.getApplicationInfo(packageName, 0)).toString()
    } catch (_: PackageManager.NameNotFoundException) {
        packageName
    }

    private fun openPermissionSettings() {
        val intent = when (importer.sdkStatus()) {
            HealthConnectImporter.STATUS_AVAILABLE ->
                HealthConnectClient.getHealthConnectManageDataIntent(activity)
            // Older Android without the module, or an outdated provider: its Play page.
            else -> Intent(
                Intent.ACTION_VIEW,
                Uri.parse("market://details?id=$PROVIDER_PACKAGE&url=healthconnect%3A%2F%2Fonboarding"),
            ).setPackage("com.android.vending")
        }
        try {
            activity.startActivity(intent)
        } catch (_: ActivityNotFoundException) {
        }
    }

    companion object {
        const val CHANNEL = "focustrace/health_connect"
        private const val PERMISSION_REQUEST_CODE = 7105
        private const val PROVIDER_PACKAGE = "com.google.android.apps.healthdata"
    }
}
