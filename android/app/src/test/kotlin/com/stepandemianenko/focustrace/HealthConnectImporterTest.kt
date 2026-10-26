package com.stepandemianenko.focustrace

import android.content.Context
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.health.connect.client.testing.FakeHealthConnectClient
import androidx.health.connect.client.testing.FakePermissionController
import java.time.Duration
import java.time.Instant
import java.time.ZoneOffset
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], manifest = Config.NONE)
class HealthConnectImporterTest {
    private val context: Context = RuntimeEnvironment.getApplication()
    private val now: Instant = Instant.parse("2026-10-26T12:00:00Z")
    private lateinit var store: HealthConnectStore
    private lateinit var permissions: FakePermissionController
    private lateinit var client: FakeHealthConnectClient

    @Before
    fun setUp() {
        store = HealthConnectStore(context)
        store.clearImported()
        store.enabled = true
        store.autoImport = false
        permissions = FakePermissionController(grantAll = false)
        permissions.grantPermission(HealthConnectImporter.READ_EXERCISE)
        client = FakeHealthConnectClient(
            packageName = "com.hevy",
            permissionController = permissions,
        )
    }

    private fun importer() = HealthConnectImporter(context, store, client)

    private fun session(daysAgo: Long, title: String) = ExerciseSessionRecord(
        startTime = now.minus(Duration.ofDays(daysAgo)),
        startZoneOffset = ZoneOffset.ofHours(1),
        endTime = now.minus(Duration.ofDays(daysAgo)).plus(Duration.ofMinutes(45)),
        endZoneOffset = ZoneOffset.ofHours(1),
        exerciseType = ExerciseSessionRecord.EXERCISE_TYPE_STRENGTH_TRAINING,
        title = title,
        metadata = Metadata.manualEntry(),
    )

    @Test
    fun firstRunImportsTheLast30DaysWithSourceThenFindsNothingNew() = runBlocking {
        client.insertRecords(listOf(session(2, "Push"), session(40, "Too old")))

        val first = importer().run(inBackground = false, nowMillis = now.toEpochMilli())
        assertEquals(HealthConnectImporter.OUTCOME_IMPORTED, first.outcome)
        val workouts = store.workouts()
        assertEquals(listOf("Push"), workouts.map { it.title })
        assertEquals("com.hevy", workouts.single().sourcePackage)
        assertEquals(3600, workouts.single().startZoneOffsetSeconds)

        val second = importer().run(inBackground = false, nowMillis = now.toEpochMilli())
        assertEquals(HealthConnectImporter.OUTCOME_NO_NEW, second.outcome)
        assertEquals(1, store.workoutCount())
        assertTrue(store.lastSuccessMillis > 0)
    }

    @Test
    fun changesMirrorSourceUpdatesDeletionsAndLateArrivals() = runBlocking {
        val id = client.insertRecords(listOf(session(2, "Push"))).recordIdsList.single()
        importer().run(inBackground = false, nowMillis = now.toEpochMilli())

        // A late-arriving session for an earlier day, an edit and a deletion.
        client.insertRecords(listOf(session(5, "Legs")))
        val stored = client.readRecords(
            ReadRecordsRequest(
                ExerciseSessionRecord::class,
                TimeRangeFilter.after(now.minus(Duration.ofDays(30))),
            ),
        ).records.single { it.metadata.id == id }
        client.updateRecords(
            listOf(
                ExerciseSessionRecord(
                    startTime = stored.startTime,
                    startZoneOffset = stored.startZoneOffset,
                    endTime = stored.endTime,
                    endZoneOffset = stored.endZoneOffset,
                    exerciseType = stored.exerciseType,
                    title = "Push day",
                    metadata = stored.metadata,
                ),
            ),
        )
        importer().run(inBackground = false, nowMillis = now.toEpochMilli())
        assertEquals(setOf("Push day", "Legs"), store.workouts().map { it.title }.toSet())

        client.deleteRecords(ExerciseSessionRecord::class, listOf(id), emptyList())
        // connect-testing alpha03 emits no DeletionChange, so this covers the
        // reconcile path that also runs when Health Connect expires the token.
        store.changesToken = null
        val result = importer().run(inBackground = false, nowMillis = now.toEpochMilli())
        assertEquals(HealthConnectImporter.OUTCOME_IMPORTED, result.outcome)
        assertEquals(listOf("Legs"), store.workouts().map { it.title })
    }

    @Test
    fun disabledIntegrationReadsAndRecordsNothing() = runBlocking {
        client.insertRecords(listOf(session(1, "Push")))
        store.enabled = false

        val result = importer().run(inBackground = false, nowMillis = now.toEpochMilli())
        assertEquals(HealthConnectImporter.OUTCOME_DISABLED, result.outcome)
        assertEquals(0, store.workoutCount())
        assertNull(store.lastOutcome)
    }

    @Test
    fun revokedAccessIsReportedAndKeepsImportedWorkouts() = runBlocking {
        client.insertRecords(listOf(session(1, "Push")))
        importer().run(inBackground = false, nowMillis = now.toEpochMilli())
        permissions.revokeAllPermissions()

        val result = importer().run(inBackground = false, nowMillis = now.toEpochMilli())
        assertEquals(HealthConnectImporter.OUTCOME_PERMISSION_MISSING, result.outcome)
        assertEquals(1, store.workoutCount())
        assertEquals(HealthConnectImporter.OUTCOME_PERMISSION_MISSING, store.lastOutcome)
    }

    @Test
    fun backgroundRunNeedsTheBackgroundPermission() = runBlocking {
        client.insertRecords(listOf(session(1, "Push")))

        val result = importer().run(inBackground = true, nowMillis = now.toEpochMilli())
        assertEquals(HealthConnectImporter.OUTCOME_BACKGROUND_PERMISSION_MISSING, result.outcome)
        assertEquals(0, store.workoutCount())
    }

    @Test
    fun ownRecordsAreNeverImported() = runBlocking {
        val own = FakeHealthConnectClient(
            packageName = context.packageName,
            permissionController = permissions,
        )
        own.insertRecords(listOf(session(1, "Mine")))

        val result = HealthConnectImporter(context, store, own).run(inBackground = false, nowMillis = now.toEpochMilli())
        assertEquals(HealthConnectImporter.OUTCOME_NO_NEW, result.outcome)
        assertEquals(0, store.workoutCount())
    }

    @Test
    fun clearingImportedDataForgetsTheChangesToken() = runBlocking {
        client.insertRecords(listOf(session(1, "Push")))
        importer().run(inBackground = false, nowMillis = now.toEpochMilli())

        store.clearImported()
        assertEquals(0, store.workoutCount())
        assertNull(store.changesToken)
        // The next run reconciles the window again instead of reading only changes.
        importer().run(inBackground = false, nowMillis = now.toEpochMilli())
        assertEquals(1, store.workoutCount())
    }
}
