package com.stepandemianenko.focustrace

import org.junit.Assert.assertEquals
import org.junit.Test

class UsageStatsTest {
    @Test
    fun duplicateAndQuickSameAppResumeCountAsOneLaunch() {
        val totals = UsageStats.aggregateEvents(
            events = listOf(
                foreground("app", 0),
                foreground("app", 5),
                background("app", 1_000),
                foreground("app", 1_050),
                background("app", 2_000),
            ),
            toMs = 2_000,
        )

        assertEquals(1, totals.getValue("app").launchCount)
        assertEquals(1_950, totals.getValue("app").totalMs)
    }

    @Test
    fun returningAfterAnotherForegroundAppCountsANewLaunch() {
        val totals = UsageStats.aggregateEvents(
            events = listOf(
                foreground("app", 0),
                background("app", 1_000),
                foreground("launcher", 1_010),
                background("launcher", 1_100),
                foreground("app", 1_200),
                background("app", 2_000),
            ),
            toMs = 2_000,
            packageNames = setOf("app"),
        )

        assertEquals(2, totals.getValue("app").launchCount)
    }

    @Test
    fun switchingAppsWithoutABackgroundEventDoesNotOverlapTime() {
        // Newer Android omits the background event for the outgoing app.
        val totals = UsageStats.aggregateEvents(
            events = listOf(
                foreground("a", 0),
                foreground("b", 1_000),
                foreground("a", 2_000),
            ),
            toMs = 3_000,
        )

        assertEquals(2_000, totals.getValue("a").totalMs)
        assertEquals(1_000, totals.getValue("b").totalMs)
    }

    @Test
    fun returningAfterALongBackgroundGapCountsANewLaunch() {
        val totals = UsageStats.aggregateEvents(
            events = listOf(
                foreground("app", 0),
                background("app", 1_000),
                foreground("app", 3_000),
                background("app", 4_000),
            ),
            toMs = 4_000,
        )

        assertEquals(2, totals.getValue("app").launchCount)
    }

    private fun foreground(packageName: String, timeStampMs: Long) =
        UsageStats.EventRecord(
            packageName = packageName,
            timeStampMs = timeStampMs,
            kind = UsageStats.EventKind.Foreground,
        )

    private fun background(packageName: String, timeStampMs: Long) =
        UsageStats.EventRecord(
            packageName = packageName,
            timeStampMs = timeStampMs,
            kind = UsageStats.EventKind.Background,
        )
}
