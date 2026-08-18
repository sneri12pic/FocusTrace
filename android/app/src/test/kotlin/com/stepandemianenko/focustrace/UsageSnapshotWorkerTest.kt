package com.stepandemianenko.focustrace

import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.Calendar

class UsageSnapshotWorkerTest {
    @Test
    fun mapperConvertsUsageToSortedDatabaseRows() {
        val rows = UsageSnapshotMapper.rows(
            mapOf(
                "com.example.short" to UsageStats.AppUsage(
                    totalMs = 90_999,
                    lastUsedMs = 2,
                    launchCount = 2,
                ),
                "com.example.long" to UsageStats.AppUsage(
                    totalMs = 3_600_000,
                    lastUsedMs = 1,
                    launchCount = 7,
                ),
            ),
        ) { packageName -> "Label for $packageName" }

        assertEquals(
            listOf("com.example.long", "com.example.short"),
            rows.map { it.appKey },
        )
        assertEquals(3_600L, rows.first().durationSeconds)
        assertEquals(7, rows.first().launchCount)
        assertEquals("Label for com.example.long", rows.first().appName)
        assertEquals(90L, rows.last().durationSeconds)
    }

    @Test
    fun dayKeyMatchesFlutterDatabaseFormat() {
        val calendar = Calendar.getInstance().apply {
            set(Calendar.YEAR, 2026)
            set(Calendar.MONTH, Calendar.JULY)
            set(Calendar.DAY_OF_MONTH, 9)
        }

        assertEquals("2026-07-09", UsageSnapshotStore.dayKey(calendar))
    }

    @Test
    fun intervalMapperUsesStablePackageAndStartIdentifier() {
        val rows = UsageSnapshotMapper.intervalRows(
            listOf(
                UsageStats.ForegroundInterval(
                    packageName = "com.example.reader",
                    startedAtMs = 1_000,
                    endedAtMs = 4_000,
                )
            )
        ) { "Reader" }

        assertEquals("com.example.reader:1000", rows.single().id)
        assertEquals("Reader", rows.single().appName)
        assertEquals(4_000, rows.single().endedAtMs)
    }

    @Test
    fun schedulerUsesAndroidMinimumPeriodicInterval() {
        assertEquals(15L, UsageSnapshotScheduler.REPEAT_INTERVAL_MINUTES)
        assertEquals("focustrace_usage_snapshot", UsageSnapshotScheduler.UNIQUE_WORK_NAME)
    }
}
