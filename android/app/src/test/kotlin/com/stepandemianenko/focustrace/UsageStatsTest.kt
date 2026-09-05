package com.stepandemianenko.focustrace

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
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
    fun unrequestedForegroundClosesRequestedAppWithoutBackgroundEvent() {
        val totals = UsageStats.aggregateEvents(
            events = listOf(
                foreground("restricted.a", 0),
                foreground("unrestricted.b", 1_000),
            ),
            toMs = 5_000,
            packageNames = setOf("restricted.a"),
        )

        assertEquals(1_000, totals.getValue("restricted.a").totalMs)
        assertEquals(1, totals.getValue("restricted.a").launchCount)
        assertEquals(setOf("restricted.a"), totals.keys)
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

    @Test
    fun intervalsCloseOnAppSwitchAndAtQueryEnd() {
        val intervals = UsageStats.aggregateIntervals(
            events = listOf(
                foreground("a", 0),
                foreground("a", 10),
                foreground("b", 1_000),
            ),
            toMs = 2_000,
        )

        assertEquals(2, intervals.size)
        assertEquals("a", intervals[0].packageName)
        assertEquals(0, intervals[0].startedAtMs)
        assertEquals(1_000, intervals[0].endedAtMs)
        assertEquals("b", intervals[1].packageName)
        assertEquals(2_000, intervals[1].endedAtMs)
    }

    @Test
    fun incrementalStateProcessesNormalForegroundAndBackgroundTransitions() {
        val state = UsageStats.IncrementalState()
        val first = state.nextQuery(0, 1_000, setOf("restricted.a"))
        val open = state.apply(first, listOf(foreground("restricted.a", 100)))

        assertEquals(UsageStats.QueryWindow(0, 1_000), first)
        assertEquals("restricted.a", open.currentForegroundPackage)
        assertEquals(900, open.usageMs.getValue("restricted.a"))

        val second = state.nextQuery(0, 2_000, setOf("restricted.a"))
        val closed = state.apply(second, listOf(background("restricted.a", 1_500)))

        assertEquals(UsageStats.QueryWindow(100, 2_000), second)
        assertNull(closed.currentForegroundPackage)
        assertEquals(1_400, closed.usageMs.getValue("restricted.a"))
    }

    @Test
    fun incrementalStateClosesMissingBackgroundOnLaterForeground() {
        val state = UsageStats.IncrementalState()
        val snapshot = advance(
            state = state,
            nowMs = 5_000,
            restrictedPackages = setOf("restricted.a", "restricted.b"),
            events = listOf(
                foreground("restricted.a", 0),
                foreground("restricted.b", 1_000),
            ),
        )

        assertEquals(1_000, snapshot.usageMs.getValue("restricted.a"))
        assertEquals(4_000, snapshot.usageMs.getValue("restricted.b"))
        assertEquals("restricted.b", snapshot.currentForegroundPackage)
    }

    @Test
    fun incrementalStateIgnoresDuplicateForegroundLifecycleEvents() {
        val state = UsageStats.IncrementalState()
        val snapshot = advance(
            state = state,
            nowMs = 1_000,
            restrictedPackages = setOf("restricted.a"),
            events = listOf(
                foreground("restricted.a", 100),
                foreground("restricted.a", 150),
            ),
        )

        assertEquals(900, snapshot.usageMs.getValue("restricted.a"))
        assertEquals(150L, snapshot.latestForegroundEventMs)
    }

    @Test
    fun incrementalQueryBoundaryIsExclusiveThenInclusive() {
        val state = UsageStats.IncrementalState()
        val first = state.nextQuery(0, 1_000, setOf("restricted.a"))
        state.apply(
            first,
            listOf(
                foreground("restricted.a", 0),
                background("restricted.a", 1_000),
            ),
        )

        val second = state.nextQuery(0, 2_000, setOf("restricted.a"))
        val snapshot = state.apply(
            second,
            listOf(
                foreground("restricted.a", 0),
                background("restricted.a", 1_000),
            ),
        )

        assertEquals(UsageStats.QueryWindow(0, 2_000), second)
        assertEquals(1_000, snapshot.usageMs.getValue("restricted.a"))
        assertNull(snapshot.currentForegroundPackage)
    }

    @Test
    fun eventPublishedAfterAnEmptyQueryIsStillProcessed() {
        val state = UsageStats.IncrementalState()
        advance(
            state = state,
            nowMs = 500,
            restrictedPackages = setOf("restricted.a"),
            events = listOf(foreground("unrestricted.b", 100)),
        )
        val emptyWindow = state.nextQuery(0, 1_000, setOf("restricted.a"))
        state.apply(emptyWindow, emptyList())

        val retryWindow = state.nextQuery(0, 2_000, setOf("restricted.a"))
        val snapshot = state.apply(
            retryWindow,
            listOf(
                foreground("unrestricted.b", 100),
                foreground("restricted.a", 900),
            ),
        )

        assertEquals(UsageStats.QueryWindow(100, 1_000), emptyWindow)
        assertEquals(UsageStats.QueryWindow(100, 2_000), retryWindow)
        assertEquals("restricted.a", snapshot.currentForegroundPackage)
        assertEquals(1_100, snapshot.usageMs.getValue("restricted.a"))
    }

    @Test
    fun unrestrictedForegroundClosesIncrementalRestrictedSession() {
        val state = UsageStats.IncrementalState()
        val snapshot = advance(
            state = state,
            nowMs = 5_000,
            restrictedPackages = setOf("restricted.a"),
            events = listOf(
                foreground("restricted.a", 0),
                foreground("unrestricted.b", 1_000),
            ),
        )

        assertEquals(1_000, snapshot.usageMs.getValue("restricted.a"))
        assertEquals("unrestricted.b", snapshot.currentForegroundPackage)
        assertEquals(setOf("restricted.a"), snapshot.usageMs.keys)
    }

    @Test
    fun restrictedForegroundStartsAfterUnrestrictedForeground() {
        val state = UsageStats.IncrementalState()
        val snapshot = advance(
            state = state,
            nowMs = 3_000,
            restrictedPackages = setOf("restricted.a"),
            events = listOf(
                foreground("unrestricted.b", 0),
                foreground("restricted.a", 1_000),
            ),
        )

        assertEquals(2_000, snapshot.usageMs.getValue("restricted.a"))
        assertEquals("restricted.a", snapshot.currentForegroundPackage)
    }

    @Test
    fun midnightChangeResetsUsageAndBootstrapsNewDay() {
        val state = UsageStats.IncrementalState()
        advance(
            state = state,
            dayStartMs = 0,
            nowMs = 10_000,
            restrictedPackages = setOf("restricted.a"),
            events = listOf(foreground("restricted.a", 1_000)),
        )

        val newDayStart = 86_400_000L
        val window = state.nextQuery(
            newDayStart,
            newDayStart + 2_000,
            setOf("restricted.a"),
        )
        val snapshot = state.apply(
            window,
            listOf(foreground("restricted.a", newDayStart + 500)),
        )

        assertEquals(UsageStats.QueryWindow(newDayStart, newDayStart + 2_000), window)
        assertEquals(1_500, snapshot.usageMs.getValue("restricted.a"))
    }

    @Test
    fun permissionRestorationBootstrapsAfterInvalidation() {
        val state = UsageStats.IncrementalState()
        advance(
            state = state,
            nowMs = 2_000,
            restrictedPackages = setOf("restricted.a"),
            events = listOf(foreground("restricted.a", 1_000)),
        )

        state.invalidate()
        val restoredWindow = state.nextQuery(0, 3_000, setOf("restricted.a"))
        val restored = state.apply(
            restoredWindow,
            listOf(
                foreground("restricted.a", 1_000),
                background("restricted.a", 2_500),
            ),
        )

        assertEquals(UsageStats.QueryWindow(0, 3_000), restoredWindow)
        assertEquals(1_500, restored.usageMs.getValue("restricted.a"))
    }

    @Test
    fun rebuiltStateBootstrapsToSameResult() {
        val events = listOf(
            foreground("restricted.a", 1_000),
            background("restricted.a", 2_000),
            foreground("restricted.a", 3_000),
        )
        val original = advance(
            state = UsageStats.IncrementalState(),
            nowMs = 4_000,
            restrictedPackages = setOf("restricted.a"),
            events = events,
        )
        val rebuilt = advance(
            state = UsageStats.IncrementalState(),
            nowMs = 4_000,
            restrictedPackages = setOf("restricted.a"),
            events = events,
        )

        assertEquals(original, rebuilt)
    }

    @Test
    fun restrictionSetChangeInvalidatesAndRebuildsUsage() {
        val state = UsageStats.IncrementalState()
        advance(
            state = state,
            nowMs = 2_000,
            restrictedPackages = setOf("restricted.a"),
            events = listOf(
                foreground("restricted.a", 0),
                foreground("restricted.b", 1_000),
            ),
        )

        val rebuildWindow = state.nextQuery(0, 3_000, setOf("restricted.b"))
        val rebuilt = state.apply(
            rebuildWindow,
            listOf(
                foreground("restricted.a", 0),
                foreground("restricted.b", 1_000),
                background("restricted.b", 2_500),
            ),
        )

        assertEquals(UsageStats.QueryWindow(0, 3_000), rebuildWindow)
        assertEquals(mapOf("restricted.b" to 1_500L), rebuilt.usageMs)
    }

    @Test
    fun openForegroundUsageThroughNowIsNotCommittedTwice() {
        val state = UsageStats.IncrementalState()
        val first = advance(
            state = state,
            nowMs = 2_000,
            restrictedPackages = setOf("restricted.a"),
            events = listOf(foreground("restricted.a", 0)),
        )
        val second = advance(
            state = state,
            nowMs = 3_000,
            restrictedPackages = setOf("restricted.a"),
        )
        val closed = advance(
            state = state,
            nowMs = 5_000,
            restrictedPackages = setOf("restricted.a"),
            events = listOf(background("restricted.a", 4_000)),
        )

        assertEquals(2_000, first.usageMs.getValue("restricted.a"))
        assertEquals(3_000, second.usageMs.getValue("restricted.a"))
        assertEquals(4_000, closed.usageMs.getValue("restricted.a"))
    }

    @Test
    fun unsuccessfulQueryDoesNotAdvanceCursor() {
        val state = UsageStats.IncrementalState()
        val attempted = state.nextQuery(0, 1_000, setOf("restricted.a"))
        val retried = state.nextQuery(0, 2_000, setOf("restricted.a"))

        assertEquals(UsageStats.QueryWindow(0, 1_000), attempted)
        assertEquals(UsageStats.QueryWindow(0, 2_000), retried)
    }

    @Test
    fun backwardsClockMovementInvalidatesCursor() {
        val state = UsageStats.IncrementalState()
        advance(
            state = state,
            nowMs = 2_000,
            restrictedPackages = setOf("restricted.a"),
            events = listOf(foreground("restricted.a", 1_000)),
        )

        val window = state.nextQuery(0, 1_500, setOf("restricted.a"))

        assertEquals(UsageStats.QueryWindow(0, 1_500), window)
    }

    private fun advance(
        state: UsageStats.IncrementalState,
        dayStartMs: Long = 0,
        nowMs: Long,
        restrictedPackages: Set<String>,
        events: List<UsageStats.EventRecord> = emptyList(),
    ): UsageStats.BlockerSnapshot {
        val window = state.nextQuery(dayStartMs, nowMs, restrictedPackages)
        return state.apply(window, events)
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
