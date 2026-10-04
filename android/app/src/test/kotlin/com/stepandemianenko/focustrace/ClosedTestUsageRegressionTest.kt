package com.stepandemianenko.focustrace

import android.app.usage.UsageEvents
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** Synthetic event regressions; these do not certify OEM event delivery or overlays. */
class ClosedTestUsageRegressionTest {
    @Test
    fun screenOffWithoutPauseStopsAllAccountingPaths() {
        assertGlobalStop(UsageEvents.Event.SCREEN_NON_INTERACTIVE)
    }

    @Test
    fun keyguardWithoutPauseStopsAllAccountingPaths() {
        assertGlobalStop(UsageEvents.Event.KEYGUARD_SHOWN)
    }

    @Test
    fun shutdownWithoutPauseDoesNotCountPoweredOffTime() {
        assertGlobalStop(UsageEvents.Event.DEVICE_SHUTDOWN)
    }

    @Test
    fun startupDiscardsUnclosedPreRebootSessionAndKeepsCompletedUsage() {
        val events = listOf(
            foreground("app", 0), background("app", 60_000),
            foreground("app", 70_000), raw(UsageEvents.Event.DEVICE_STARTUP, 3_600_000),
            foreground("app", 3_610_000), background("app", 3_670_000),
        )
        assertAllPaths(events, 4_000_000, 120_000)
    }

    @Test
    fun oneMinuteMultipleShortSessionsAndLongSessionAgreeAcrossPaths() {
        val events = listOf(
            foreground("app", 0), background("app", 60_000),
            foreground("app", 70_000), background("app", 70_300),
            foreground("app", 71_000), background("app", 71_700),
            foreground("app", 80_000), background("app", 3_680_000),
        )
        assertAllPaths(events, 4_000_000, 3_661_000)
    }

    @Test
    fun homeAnotherAppAndLatePauseDoNotExtendRestrictedUsage() {
        val events = listOf(
            foreground("app", 0),
            foreground("launcher", 60_000),
            foreground("other", 70_000),
            background("app", 90_000),
        )
        assertAllPaths(events, 120_000, 60_000)
    }

    @Test
    fun splitScreenResumeTraceUsesExclusiveAttribution() {
        val events = listOf(foreground("app", 0), foreground("other", 60_000))
        val totals = UsageStats.aggregateEvents(events, 120_000)
        assertEquals(120_000, totals.values.sumOf { it.totalMs })
        assertAllPaths(events, 120_000, 60_000)
    }

    @Test
    fun midnightContinuationIsClippedAndDoesNotCountAsANewLaunch() {
        val dayStart = 86_400_000L
        val events = UsageStats.eventsInWindow(
            listOf(foreground("app", dayStart - 60_000), background("app", dayStart + 60_000)),
            dayStart,
            dayStart + 120_000,
        )
        assertEquals(60_000, UsageStats.aggregateEvents(events, dayStart + 120_000).getValue("app").totalMs)
        assertEquals(0, UsageStats.aggregateEvents(events, dayStart + 120_000).getValue("app").launchCount)
        val interval = UsageStats.aggregateIntervals(events, dayStart + 120_000).single()
        assertEquals(dayStart, interval.startedAtMs)
        assertEquals(dayStart + 60_000, interval.endedAtMs)
    }

    @Test
    fun limitContinuesAfterMidnightAndColdServiceRestartWithoutAnotherResume() {
        val dayStart = 86_400_000L
        val state = UsageStats.IncrementalState()
        state.apply(state.nextQuery(0, dayStart, setOf("app")), listOf(foreground("app", dayStart - 60_000)))
        val next = state.nextQuery(dayStart, dayStart + 180_000, setOf("app"))
        val events = UsageStats.eventsInWindow(listOf(foreground("app", dayStart - 60_000)), next.fromMs, next.toMs)
        val live = state.apply(next, events)
        val restarted = UsageStats.IncrementalState()
        val cold = restarted.apply(restarted.nextQuery(dayStart, next.toMs, setOf("app")), events)
        assertEquals(live, cold)
        assertEquals("app", cold.currentForegroundPackage)
        assertEquals(180_000, cold.usageMs.getValue("app"))
        val rule = RestrictionRule(appKey = "app", appName = "App", type = RestrictionRuleType.DailyLimit, limitMinutes = 2)
        assertEquals(true, RestrictionRules.isBlocked(rule, next.toMs, cold.usageMs.getValue("app") / 1_000))
    }

    @Test
    fun screenOffBeforeMidnightDoesNotSeedANewDaySession() {
        val events = UsageStats.eventsInWindow(
            listOf(foreground("app", 100), raw(UsageEvents.Event.SCREEN_NON_INTERACTIVE, 200)),
            1_000,
            2_000,
        )
        assertEquals(emptyList<UsageStats.EventRecord>(), events)
    }

    @Test
    fun noRetainedResumeDoesNotInventUsageFromAnOrphanPause() {
        val events = UsageStats.eventsInWindow(listOf(background("app", 1_500)), 1_000, 2_000)
        assertEquals(emptyMap<String, UsageStats.AppUsage>(), UsageStats.aggregateEvents(events, 2_000))
    }

    @Test
    fun repeatedRefreshThenTargetRelaunchPreservesSpentAllowance() {
        val state = UsageStats.IncrementalState()
        val first = listOf(foreground("app", 0), background("app", 60_000))
        state.apply(state.nextQuery(0, 70_000, setOf("app")), first)
        val next = state.nextQuery(0, 140_000, setOf("app"))
        val snapshot = state.apply(next, listOf(background("app", 60_000), foreground("app", 80_000)))
        assertEquals(120_000, snapshot.usageMs.getValue("app"))
        val last = state.apply(state.nextQuery(0, 150_000, setOf("app")), listOf(foreground("app", 80_000)))
        assertEquals(130_000, last.usageMs.getValue("app"))
    }

    private fun assertGlobalStop(type: Int) {
        val events = listOf(foreground("app", 0), raw(type, 60_000))
        assertAllPaths(events, 3_600_000, 60_000)
        val state = UsageStats.IncrementalState()
        val result = state.apply(state.nextQuery(0, 3_600_000, setOf("app")), events)
        assertNull(result.currentForegroundPackage)
    }

    private fun assertAllPaths(events: List<UsageStats.EventRecord>, toMs: Long, expectedMs: Long) {
        assertEquals(expectedMs, UsageStats.aggregateEvents(events, toMs, setOf("app")).getValue("app").totalMs)
        assertEquals(expectedMs, UsageStats.aggregateIntervals(events, toMs, setOf("app")).sumOf { it.endedAtMs - it.startedAtMs })
        val state = UsageStats.IncrementalState()
        assertEquals(expectedMs, state.apply(state.nextQuery(0, toMs, setOf("app")), events).usageMs.getValue("app"))
    }

    private fun foreground(app: String, at: Long) = UsageStats.EventRecord(app, at, UsageStats.EventKind.Foreground)
    private fun background(app: String, at: Long) = UsageStats.EventRecord(app, at, UsageStats.EventKind.Background)
    private fun raw(type: Int, at: Long) = UsageStats.EventRecord("", at, UsageStats.eventKind(type))
}
