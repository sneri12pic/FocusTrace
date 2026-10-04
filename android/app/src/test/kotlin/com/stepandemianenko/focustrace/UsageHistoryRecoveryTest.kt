package com.stepandemianenko.focustrace

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.util.Calendar
import java.util.TimeZone

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], manifest = Config.NONE)
class UsageHistoryRecoveryTest {
    private lateinit var context: Context
    private lateinit var db: SQLiteDatabase
    private lateinit var store: UsageSnapshotStore
    private val zone = TimeZone.getTimeZone("UTC")
    private val day1 = time(7)
    private val day2 = time(8)
    private val now = time(8, 0, 20)
    private var events = emptyList<UsageStats.EventRecord>()
    private var queries = 0
    private val diagnostics = mutableListOf<String>()

    @Before fun setUp() {
        context = RuntimeEnvironment.getApplication()
        context.deleteDatabase(UsageSnapshotStore.DATABASE_NAME)
        db = context.openOrCreateDatabase(UsageSnapshotStore.DATABASE_NAME, 0, null)
        db.execSQL("CREATE TABLE daily_app_usage (day TEXT, app_key TEXT, app_name TEXT, " +
            "package_name TEXT, process_name TEXT, duration_seconds INTEGER NOT NULL, " +
            "launch_count INTEGER NOT NULL, PRIMARY KEY(day, app_key))")
        db.execSQL("CREATE TABLE usage_intervals (id TEXT PRIMARY KEY, app_key TEXT, " +
            "app_name TEXT, started_at INTEGER, ended_at INTEGER)")
        db.execSQL("CREATE TABLE usage_snapshot_days (day TEXT PRIMARY KEY, start_ms INTEGER, " +
            "end_ms INTEGER, timezone_id TEXT, queried_at_ms INTEGER, covered_until_ms INTEGER, status TEXT)")
        db.execSQL("CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)")
        db.version = 5
        store = UsageSnapshotStore(context)
    }

    @After fun tearDown() { db.close(); context.deleteDatabase(UsageSnapshotStore.DATABASE_NAME) }

    private fun recovery() = UsageHistoryRecovery(store, { from, to ->
        queries++
        events.filter { it.timeStampMs >= from && it.timeStampMs < to }
    }, { it == "instagram" }, { it }, { diagnostics.add(it) })

    @Test fun diagnosticDurationDecreasePreservesData() {
        seedPartial()
        events = listOf(fullTrace().first(), fullTrace().last())
        repair()
        assertTrue(diagnostics.any { "rejected=duration_decrease" in it &&
            "package=instagram stored_seconds=2400 candidate_seconds=0" in it })
        assertEquals(2400L, total())
        assertEquals("unavailable", status())
    }

    @Test fun diagnosticIntervalGapPreservesData() {
        db.execSQL("INSERT INTO usage_intervals VALUES ('old', 'instagram', 'Instagram', ${time(7, 10)}, ${time(7, 10, 5)})")
        events = fullTrace()
        repair()
        assertTrue(diagnostics.any { "rejected=interval_gap" in it &&
            "uncovered=${time(7, 10)}..${time(7, 10, 5)}" in it &&
            "candidate_neighbors=[${time(7, 12)}..${time(7, 12, 40)}]" in it })
        assertEquals(1L, scalar("SELECT COUNT(*) FROM usage_intervals"))
        assertEquals("unavailable", status())
    }

    @Test fun diagnosticEligibilityReasonsDoNotLeakTokens() {
        val window = UsageDayWindow.recent(time(7, 23, 45), zone).last()
        val log: (String) -> Unit = { diagnostics.add(it) }
        assertTrue(store.replaceDay(window, listOf(row(2400)), emptyList(), "", log))
        assertFalse(store.replaceDay(window.copy(nowMs = window.nowMs - 1), listOf(row(2500)), emptyList(), "", log))
        assertTrue(diagnostics.last().contains("rejected=stale_result"))
        assertFalse(store.replaceDay(window.copy(startMs = window.startMs - 1), listOf(row(2500)), emptyList(), "", log))
        assertTrue(diagnostics.last().contains("rejected=boundary_mismatch"))
        assertFalse(store.replaceDay(window, listOf(row(2500)), emptyList(), "private-token", log))
        assertTrue(diagnostics.last().contains("rejected=generation_mismatch"))
        assertFalse(diagnostics.any { "private-token" in it })
        events = fullTrace()
        repair()
        assertFalse(store.replaceDay(window.copy(nowMs = now + 1), listOf(row(4000)), emptyList(), "", log))
        assertTrue(diagnostics.last().contains("rejected=reconciliation_cooldown"))
        assertEquals(2940L, total())
    }

    @Test fun diagnosticFailureCannotChangePersistenceOutcome() {
        val window = UsageDayWindow.recent(time(7, 23, 45), zone).last()
        val broken: (String) -> Unit = { error("diagnostic sink failed") }
        assertTrue(store.replaceDay(window, listOf(row(2400)), emptyList(), "", broken))
        assertFalse(store.replaceDay(window, listOf(row(0)), emptyList(), "", broken))
        assertEquals(2400L, total())
        assertEquals("partial", status())
    }

    @Test fun diagnosticUnavailableSchemaAndDatabase() {
        val window = UsageDayWindow.recent(now, zone).first()
        val log: (String) -> Unit = { diagnostics.add(it) }
        db.version = 4
        assertFalse(store.replaceDay(window, emptyList(), emptyList(), "", log))
        assertTrue(diagnostics.last().contains("rejected=schema_unavailable version=4"))
        db.close()
        context.deleteDatabase(UsageSnapshotStore.DATABASE_NAME)
        assertFalse(store.replaceDay(window, emptyList(), emptyList(), "", log))
        assertTrue(diagnostics.last().contains("rejected=database_unavailable"))
    }

    private fun interval(start: Long, end: Long) =
        UsageIntervalRow("instagram:$start", "instagram", "Instagram", start, end)

    @Test fun deviceEndpointTranslationsRecoverWithoutDuplicateIntervals() {
        for (shift in listOf(140L, 265L, 387L, -265L, 1000L, -1000L)) {
            for (table in listOf("daily_app_usage", "usage_intervals", "usage_snapshot_days")) db.delete(table, null, null)
            val partial = UsageDayWindow.recent(time(7, 23), zone).last()
            val old = interval(time(7, 12), time(7, 12) + 29506)
            val fresh = interval(old.startedAtMs + shift, old.endedAtMs + shift)
            assertTrue(store.replaceDay(partial, listOf(row(29)), listOf(old), ""))
            val complete = partial.copy(nowMs = now)
            assertTrue("shift=$shift", store.replaceDay(complete, listOf(row(29)), listOf(fresh), ""))
            assertFalse(store.replaceDay(complete, listOf(row(29)), listOf(fresh), ""))
            assertEquals(29L, total())
            assertEquals("reconciled", status())
            assertEquals(1L, scalar("SELECT COUNT(*) FROM usage_intervals"))
            assertEquals(fresh.startedAtMs, scalar("SELECT started_at FROM usage_intervals"))
        }
    }

    @Test fun translationCannotHideMissingShortenedLongShiftOrAmbiguousIntervals() {
        val partial = UsageDayWindow.recent(time(7, 23), zone).last()
        val old = interval(time(7, 12), time(7, 12) + 30000)
        assertTrue(store.replaceDay(partial, listOf(row(30)), listOf(old), ""))
        val bad = listOf(
            emptyList(),
            listOf(interval(old.startedAtMs + 265, old.endedAtMs + 264)),
            listOf(interval(old.startedAtMs + 1001, old.endedAtMs + 1001)),
            listOf(interval(old.startedAtMs - 1001, old.endedAtMs - 1001)),
            listOf(interval(old.startedAtMs + 265, old.endedAtMs + 30000)), // Closed session cannot arbitrarily grow.
            listOf(interval(old.startedAtMs + 200, old.endedAtMs + 200), interval(old.startedAtMs + 300, old.endedAtMs + 300)),
        )
        for (candidate in bad) {
            assertFalse(store.replaceDay(partial.copy(nowMs = now), listOf(row(60)), candidate, ""))
            assertEquals(30L, total())
            assertEquals("partial", status())
            assertEquals(old.startedAtMs, scalar("SELECT started_at FROM usage_intervals"))
        }
        val shifted = listOf(interval(old.startedAtMs + 265, old.endedAtMs + 265))
        assertFalse(store.replaceDay(partial.copy(nowMs = now), listOf(row(0)), shifted, ""))
        assertEquals(30L, total())
    }

    @Test fun translatedCandidateCannotServeTwoStoredSessionsOrStrictCoverage() {
        val partial = UsageDayWindow.recent(time(7, 23), zone).last()
        val old = interval(time(7, 12), time(7, 12) + 30000)
        for (other in listOf(interval(old.startedAtMs + 100, old.endedAtMs + 100),
                interval(old.startedAtMs + 5000, old.endedAtMs - 5000))) {
            for (table in listOf("daily_app_usage", "usage_intervals", "usage_snapshot_days")) db.delete(table, null, null)
            assertTrue(store.replaceDay(partial, listOf(row(30)), listOf(old, other), ""))
            val fresh = interval(old.startedAtMs + 265, old.endedAtMs + 265)
            assertFalse(store.replaceDay(partial.copy(nowMs = now), listOf(row(60)), listOf(fresh), ""))
            assertEquals(2L, scalar("SELECT COUNT(*) FROM usage_intervals"))
        }
    }

    @Test fun clockSequenceTranslationPreservesAdjacentTinySession() {
        val partial = UsageDayWindow.recent(time(7, 23), zone).last()
        val base = time(7, 12)
        // Device intervals relative to 1789376100000; the third translated row
        // is a controlled fixture, not a claim about captured device logs.
        val old = listOf(interval(base + 460, base + 848),
            interval(base + 882, base + 12543), interval(base + 12578, base + 12643))
        val fresh = old.map { interval(it.startedAtMs + 140, it.endedAtMs + 140) }
        assertTrue(store.replaceDay(partial, listOf(row(12)), old, ""))
        val next = partial.copy(nowMs = partial.nowMs + 1000)
        assertTrue(store.replaceDay(next, listOf(row(12)), fresh, ""))
        assertTrue(store.replaceDay(next.copy(nowMs = next.nowMs + 1000), listOf(row(12)), fresh, ""))
        assertEquals(3L, scalar("SELECT COUNT(*) FROM usage_intervals"))
        assertEquals(12114L, scalar("SELECT SUM(ended_at - started_at) FROM usage_intervals"))
    }

    @Test fun uniformTranslationCannotHideMissingShortenedOrInconsistentTinySession() {
        val partial = UsageDayWindow.recent(time(7, 23), zone).last()
        val base = time(7, 12)
        val old = listOf(interval(base + 460, base + 848),
            interval(base + 882, base + 12543), interval(base + 12578, base + 12643))
        val fresh = old.map { interval(it.startedAtMs + 140, it.endedAtMs + 140) }
        assertTrue(store.replaceDay(partial, listOf(row(12)), old, ""))
        for (bad in listOf(fresh.dropLast(1),
                fresh.dropLast(1) + interval(base + 12718, base + 12782),
                fresh.dropLast(1) + interval(base + 12818, base + 12883),
                fresh + old.map { interval(it.startedAtMs + 150, it.endedAtMs + 150) })) {
            assertFalse(store.replaceDay(partial.copy(nowMs = now), listOf(row(60)), bad, ""))
            assertEquals(12L, total())
            assertEquals("partial", status())
            assertEquals(3L, scalar("SELECT COUNT(*) FROM usage_intervals"))
        }
    }

    @Test fun snapshotClippedSessionMayExtendAfterItsStartTimestampShifts() {
        val old = interval(time(7, 12), time(7, 12) + 30000)
        val partial = UsageDayWindow.recent(old.endedAtMs, zone).last()
        assertTrue(store.replaceDay(partial, listOf(row(30)), listOf(old), ""))
        val fresh = interval(old.startedAtMs + 140, old.endedAtMs + 60140)
        assertTrue(store.replaceDay(partial.copy(nowMs = fresh.endedAtMs + 1000), listOf(row(90)), listOf(fresh), ""))
        assertEquals(90L, total())
        assertEquals("partial", status())
        assertEquals(1L, scalar("SELECT COUNT(*) FROM usage_intervals"))
    }

    @Test fun translationDoesNotCrossDayBoundaryOrMatchDisjointShortSession() {
        val partial = UsageDayWindow.recent(time(7, 23), zone).last()
        for (old in listOf(interval(day1 + 50, day1 + 30050), interval(time(7, 12), time(7, 12) + 100))) {
            for (table in listOf("daily_app_usage", "usage_intervals", "usage_snapshot_days")) db.delete(table, null, null)
            assertTrue(store.replaceDay(partial, listOf(row(30)), listOf(old), ""))
            val shift = if (old.startedAtMs == day1 + 50) -140L else 265L
            val fresh = interval(old.startedAtMs + shift, old.endedAtMs + shift)
            assertFalse(store.replaceDay(partial.copy(nowMs = now), listOf(row(30)), listOf(fresh), ""))
            assertEquals(old.startedAtMs, scalar("SELECT started_at FROM usage_intervals"))
        }
    }

    @Test fun acceptedTranslationStillRollsBackOnPersistenceFailure() {
        val partial = UsageDayWindow.recent(time(7, 23), zone).last()
        val old = interval(time(7, 12), time(7, 12) + 29506)
        assertTrue(store.replaceDay(partial, listOf(row(29)), listOf(old), ""))
        db.execSQL("CREATE TRIGGER fail_translation BEFORE INSERT ON usage_intervals BEGIN SELECT RAISE(ABORT, 'failure'); END")
        assertThrows(android.database.sqlite.SQLiteException::class.java) {
            store.replaceDay(partial.copy(nowMs = now), listOf(row(60)),
                listOf(interval(old.startedAtMs + 265, old.endedAtMs + 265)), "")
        }
        assertEquals(29L, total())
        assertEquals("partial", status())
        assertEquals(old.startedAtMs, scalar("SELECT started_at FROM usage_intervals"))
    }

    @Test fun rebootMissingEventsContinueAcceptedCurrentDayWithoutDuplicatingUsage() {
        val savedAt = time(7, 12)
        val partial = UsageDayWindow.recent(savedAt, zone).last()
        assertTrue(store.replaceDay(partial, listOf(row(320)),
            listOf(interval(savedAt - 320000, savedAt)), ""))
        events = listOf(event(savedAt - 360000, UsageStats.EventKind.EndForeground),
            event(savedAt + 1000, UsageStats.EventKind.DiscardForeground),
            event(savedAt + 2000, UsageStats.EventKind.Foreground),
            event(savedAt + 62000, UsageStats.EventKind.Background))
        val recovered = recovery().snapshotAndRecover(savedAt + 63000, zone)
        assertEquals(380000L, recovered.getValue("instagram").totalMs)
        assertEquals(380L, total())
        recovery().snapshotAndRecover(savedAt + 64000, zone)
        assertEquals(380L, total())
        assertEquals(2L, scalar("SELECT COUNT(*) FROM usage_intervals"))
        assertEquals("partial", status())
        assertEquals(savedAt + 64000, scalar("SELECT covered_until_ms FROM usage_snapshot_days WHERE day='2026-09-07'"))
    }

    @Test fun blockerRestoresSpentAndPartialAllowanceThenCountsOnlyNewTime() {
        val state = UsageStats.IncrementalState()
        val start = time(7, 12)
        val window = state.nextQuery(day1, start, setOf("instagram"))
        state.apply(window, listOf(event(start - 10000, UsageStats.EventKind.Foreground)))
        state.retainAcceptedUsage(mapOf("instagram" to UsageStats.AppUsage(240000, start, 1)), start)
        state.retainAcceptedUsage(mapOf("instagram" to UsageStats.AppUsage(240000, start, 1)), start)
        assertEquals(240000L, state.snapshot(start).usageMs.getValue("instagram"))
        assertEquals(300000L, state.snapshot(start + 60000).usageMs.getValue("instagram"))
        state.invalidate()
        state.nextQuery(day1, start, setOf("instagram"))
        state.retainAcceptedUsage(mapOf("instagram" to UsageStats.AppUsage(320000, start, 1)), start)
        assertEquals(320000L, state.snapshot(start).usageMs.getValue("instagram"))
        state.nextQuery(day2, now, setOf("instagram"))
        assertTrue(state.snapshot(now).usageMs.isEmpty())
    }

    @Test fun acceptedBaselineRejectsWrongGenerationFutureAndHistoricalBoundaries() {
        val partial = UsageDayWindow.recent(time(7, 12), zone).last()
        assertTrue(store.replaceDay(partial, listOf(row(320)), emptyList(), ""))
        assertNotNull(store.acceptedSnapshot(partial, ""))
        assertNull(store.acceptedSnapshot(partial, "changed"))
        assertNull(store.acceptedSnapshot(partial.copy(nowMs = partial.nowMs - 1), ""))
        assertNull(store.acceptedSnapshot(partial.copy(startMs = day1 - 1), ""))
        assertNull(store.acceptedSnapshot(partial.copy(nowMs = now), ""))
    }

    @Test fun nativeBlockerBootstrapUsesDatabaseWhenAndroidHasNoEarlierEvents() {
        val savedAt = time(7, 12)
        val partial = UsageDayWindow.recent(savedAt, TimeZone.getDefault()).last()
        assertTrue(store.replaceDay(partial, listOf(row(320)), emptyList(), ""))
        val snapshot = UsageStats.incrementalBlockerSnapshot(context, partial.startMs,
            savedAt + 1000, setOf("instagram"), UsageStats.IncrementalState(), null)
        assertEquals(320000L, snapshot.usageMs.getValue("instagram"))
    }

    @Test fun rebootContinuationRollbackPreservesAcceptedPrefix() {
        val savedAt = time(7, 12)
        assertTrue(store.replaceDay(UsageDayWindow.recent(savedAt, zone).last(),
            listOf(row(320)), listOf(interval(savedAt - 320000, savedAt)), ""))
        events = listOf(event(savedAt + 1000, UsageStats.EventKind.Foreground),
            event(savedAt + 61000, UsageStats.EventKind.Background))
        db.execSQL("CREATE TRIGGER fail_continuation BEFORE INSERT ON usage_intervals BEGIN SELECT RAISE(ABORT, 'failure'); END")
        assertThrows(android.database.sqlite.SQLiteException::class.java) {
            recovery().snapshotAndRecover(savedAt + 62000, zone)
        }
        assertEquals(320L, total())
        assertEquals(1L, scalar("SELECT COUNT(*) FROM usage_intervals"))
        assertEquals(savedAt, scalar("SELECT covered_until_ms FROM usage_snapshot_days WHERE day='2026-09-07'"))
    }

    private fun repair() = recovery().snapshotAndRecover(now, zone, day1, day2, includeToday = false)

    private fun fullTrace() = listOf(
        event(time(6, 23), UsageStats.EventKind.EndForeground),
        event(time(7, 12), UsageStats.EventKind.Foreground),
        event(time(7, 12, 40), UsageStats.EventKind.Background),
        event(time(7, 23, 50), UsageStats.EventKind.Foreground),
        event(time(7, 23, 59), UsageStats.EventKind.Background),
        event(time(8, 0, 10), UsageStats.EventKind.EndForeground),
    )

    @Test fun delayedWorkerRepairsFortyMinutesToFortyNineAndKeepsTodaySeparate() {
        events = fullTrace().dropLast(1) // No interaction/event after midnight.
        recovery().snapshotAndRecover(time(7, 23, 45), zone)
        assertEquals(2400L, total())
        assertEquals("partial", status())
        recovery().snapshotAndRecover(now, zone)
        assertEquals(2940L, total())
        assertEquals("reconciled", status())
        assertEquals(2L, scalar("SELECT COUNT(*) FROM usage_intervals WHERE started_at >= $day1 AND started_at < $day2"))
        assertEquals(0L, scalar("SELECT COUNT(*) FROM daily_app_usage WHERE day = '2026-09-08'"))
        assertEquals(day2, scalar("SELECT covered_until_ms FROM usage_snapshot_days WHERE day = '2026-09-07'"))
    }

    @Test fun entireMissedDayIsReconstructedBeforeHistoryRead() {
        events = fullTrace()
        repair()
        assertEquals(2940L, total())
        assertEquals("reconciled", status())
    }

    @Test fun legacyPartialDataWithoutMetadataIsNotTreatedAsFinal() {
        seedPartial()
        events = fullTrace()
        repair()
        assertEquals(2940L, total())
        assertEquals("reconciled", status())
    }

    @Test fun emptyOrTruncatedRetainedEventsNeverEraseExistingData() {
        seedPartial()
        repair()
        assertEquals(2400L, total())
        assertEquals("unavailable", status())
        events = fullTrace().drop(1) // Nonempty trace but start coverage is unknown.
        repair()
        assertEquals(2400L, total())
        assertEquals("unavailable", status())
    }

    @Test fun permissionOrLockedQueryFailurePreservesHistory() {
        seedPartial()
        val denied = UsageHistoryRecovery(store, { _, _ -> throw SecurityException("locked") }, { true }, { it })
        assertThrows(SecurityException::class.java) { denied.snapshotAndRecover(now, zone) }
        assertEquals(2400L, total())
        assertNull(status())
    }

    @Test fun legitimateEmptyDayWithRetainedBoundaryEvidenceCanBeFinalized() {
        events = listOf(
            event(time(6, 23), UsageStats.EventKind.EndForeground),
            event(time(8, 0, 10), UsageStats.EventKind.EndForeground),
        )
        repair()
        assertEquals(0L, total())
        assertEquals("reconciled", status())
        assertEquals(0L, scalar("SELECT COUNT(*) FROM usage_intervals"))
    }

    @Test fun apparentZeroEvenWithAnchorsCannotErasePositiveSnapshot() {
        seedPartial()
        events = listOf(fullTrace().first(), fullTrace().last())
        repair()
        assertEquals(2400L, total())
        assertEquals("unavailable", status())
    }

    @Test fun openSessionWithoutEndBoundaryEvidenceLeavesHistoryUnfinalized() {
        seedPartial()
        events = fullTrace().dropLast(2) // Last retained event is the 23:50 resume.
        repair()
        assertEquals(2400L, total())
        assertEquals("unavailable", status())
    }

    @Test fun retainedScreenOffStateCanRepresentAnEntireIdleDay() {
        events = listOf(event(time(6, 23), UsageStats.EventKind.EndForeground))
        repair()
        assertEquals(0L, total())
        assertEquals("reconciled", status())
    }

    @Test fun orphanPauseDoesNotProveStartCoverage() {
        seedPartial()
        events = fullTrace().mapIndexed { index, event ->
            if (index == 0) event.copy(kind = UsageStats.EventKind.Background) else event
        }
        repair()
        assertEquals(2400L, total())
        assertEquals("unavailable", status())
    }

    @Test fun clockRollbackStillReturnsLiveUsageWithoutOverwritingFinalDay() {
        events = fullTrace()
        repair()
        val live = recovery().snapshotAndRecover(time(7, 23, 45), zone)
        assertEquals(2400000L, live.getValue("instagram").totalMs)
        assertEquals(2940L, total())
        assertEquals("reconciled", status())
    }

    @Test fun capturedWindowSurvivesMidnightAndTimezoneChangeDuringQuery() {
        events = fullTrace()
        val original = TimeZone.getDefault()
        try {
            val crossing = UsageHistoryRecovery(store, { from, to ->
                TimeZone.setDefault(TimeZone.getTimeZone("Pacific/Auckland"))
                events.filter { it.timeStampMs >= from && it.timeStampMs < to }
            }, { it == "instagram" }, { it })
            crossing.snapshotAndRecover(time(7, 23, 45), zone)
            assertEquals(2400L, total())
            assertEquals(time(7, 23, 45), scalar("SELECT covered_until_ms FROM usage_snapshot_days WHERE day = '2026-09-07'"))
            assertEquals(0L, scalar("SELECT COUNT(*) FROM daily_app_usage WHERE day = '2026-09-08'"))
        } finally { TimeZone.setDefault(original) }
    }

    @Test fun failedIntervalInsertRollsBackTotalsIntervalsAndMetadata() {
        events = fullTrace()
        recovery().snapshotAndRecover(time(7, 23, 45), zone)
        db.execSQL("CREATE TRIGGER fail_interval BEFORE INSERT ON usage_intervals " +
            "BEGIN SELECT RAISE(ABORT, 'forced failure'); END")
        assertThrows(android.database.sqlite.SQLiteException::class.java) { repair() }
        assertEquals(2400L, total())
        assertEquals("partial", status())
        assertEquals(1L, scalar("SELECT COUNT(*) FROM usage_intervals"))
        assertEquals(2400000L, scalar("SELECT SUM(ended_at - started_at) FROM usage_intervals"))
    }

    @Test fun repeatedRecoveryIsIdempotentAndDoesNotRequeryFinalizedDay() {
        events = fullTrace()
        repair(); repair(); repair()
        assertEquals(1, queries)
        assertEquals(2940L, total())
        assertEquals(2L, scalar("SELECT COUNT(*) FROM usage_intervals"))
    }

    @Test fun staleQueryCannotOverwriteNewerPartialOrCompletedSnapshot() {
        val window = UsageDayWindow.recent(time(7, 23, 45), zone).last()
        assertTrue(store.replaceDay(window, listOf(row(2400)), emptyList(), ""))
        assertFalse(store.replaceDay(window.copy(nowMs = time(7, 23)), listOf(row(2500)), emptyList(), ""))
        assertEquals(2400L, total())
        events = fullTrace()
        repair()
        assertFalse(store.replaceDay(window, listOf(row(4000)), emptyList(), ""))
        assertEquals(2940L, total())
        assertEquals("reconciled", status())
    }

    @Test fun flutterClearOrImportDuringQueryRejectsInflightResult() {
        events = fullTrace()
        val interrupted = UsageHistoryRecovery(store, { _, _ ->
            db.beginTransaction()
            try {
                db.execSQL("DELETE FROM daily_app_usage")
                db.execSQL("DELETE FROM usage_intervals")
                db.execSQL("DELETE FROM usage_snapshot_days")
                db.execSQL("INSERT OR REPLACE INTO settings VALUES ('usage_recovery_generation', 'after-clear')")
                db.setTransactionSuccessful()
            } finally { db.endTransaction() }
            events
        }, { true }, { it })
        interrupted.snapshotAndRecover(now, zone, day1, day2, false)
        assertEquals(0L, total())
        assertNull(status())
        assertEquals(0L, scalar("SELECT COUNT(*) FROM usage_intervals"))
    }

    @Test fun uninstalledPreviouslyStoredPackageRemainsRecoverable() {
        seedPartial()
        events = fullTrace()
        UsageHistoryRecovery(store, { _, _ -> events }, { false }, { it })
            .snapshotAndRecover(now, zone, day1, day2, false)
        assertEquals(2940L, total())
    }

    @Test fun legacyCrossMidnightIntervalsAreSplitWithoutDuplicates() {
        db.execSQL("INSERT INTO usage_intervals VALUES ('instagram:${day1 - 60000}', 'instagram', 'Instagram', ${day1 - 60000}, ${day1 + 60000})")
        events = listOf(
            event(day1 - 60000, UsageStats.EventKind.Foreground),
            event(day1 + 60000, UsageStats.EventKind.Background),
            fullTrace().last(),
        )
        repair()
        assertEquals(60L, total())
        assertEquals(2L, scalar("SELECT COUNT(*) FROM usage_intervals"))
        assertEquals(120000L, scalar("SELECT SUM(ended_at - started_at) FROM usage_intervals"))
    }

    @Test fun intervalEvidenceCannotBeLostEvenWhenTotalsWouldIncrease() {
        db.execSQL("INSERT INTO usage_intervals VALUES ('old', 'instagram', 'Instagram', ${time(7, 10)}, ${time(7, 10, 5)})")
        events = fullTrace()
        repair()
        assertEquals("unavailable", status())
        assertEquals(1L, scalar("SELECT COUNT(*) FROM usage_intervals"))
    }

    @Test fun oldDatabaseAndMissingDatabaseAreNotCreatedOrMutatedByWorker() {
        db.version = 4
        seedPartial()
        events = fullTrace()
        repair()
        assertEquals(2400L, total())
        assertEquals(4, db.version)
        assertNull(status())
        db.close()
        context.deleteDatabase(UsageSnapshotStore.DATABASE_NAME)
        repair()
        assertFalse(context.getDatabasePath(UsageSnapshotStore.DATABASE_NAME).exists())
    }

    @Test fun dstDaysUseCalendarBoundariesAndRecoveryIsBounded() {
        val london = TimeZone.getTimeZone("Europe/London")
        val spring = Calendar.getInstance(london).apply { set(2026, 2, 30, 12, 0, 0); set(Calendar.MILLISECOND, 0) }
        val autumn = Calendar.getInstance(london).apply { set(2026, 9, 26, 12, 0, 0); set(Calendar.MILLISECOND, 0) }
        val shortDay = UsageDayWindow.recent(spring.timeInMillis, london).first { it.day == "2026-03-29" }
        val longDay = UsageDayWindow.recent(autumn.timeInMillis, london).first { it.day == "2026-10-25" }
        assertEquals(23 * 3600000L, shortDay.endMs - shortDay.startMs)
        assertEquals(25 * 3600000L, longDay.endMs - longDay.startMs)
        events = fullTrace()
        recovery().snapshotAndRecover(now, zone, time(1), time(2), false)
        assertEquals(0, queries)
    }

    private fun seedPartial() {
        db.execSQL("INSERT INTO daily_app_usage VALUES ('2026-09-07', 'instagram', 'Instagram', 'instagram', NULL, 2400, 1)")
    }

    @Test fun unresolvedReadsAreThrottledAndRetryAfterFifteenMinutes() {
        seedPartial()
        repair(); repair()
        assertEquals(1, queries)
        events = fullTrace()
        recovery().snapshotAndRecover(now + UsageSnapshotStore.RETRY_INTERVAL_MS, zone, day1, day2, false)
        assertEquals(2, queries)
        assertEquals(2940L, total())
    }

    @Test fun reconciledDayCanPickUpDelayedEventsOnBoundedRecheck() {
        events = fullTrace().filter { it.timeStampMs !in time(7, 23, 50)..time(7, 23, 59) }
        repair()
        assertEquals(2400L, total())
        events = fullTrace()
        repair()
        assertEquals(1, queries)
        recovery().snapshotAndRecover(now + UsageSnapshotStore.RECHECK_INTERVAL_MS, zone, day1, day2, false)
        assertEquals(2940L, total())
        assertEquals("reconciled", status())
        assertEquals(2, queries)
    }

    @Test fun unavailableRecheckKeepsReconciledDataAndBacksOff() {
        events = fullTrace()
        repair()
        events = emptyList()
        val later = now + UsageSnapshotStore.RECHECK_INTERVAL_MS
        recovery().snapshotAndRecover(later, zone, day1, day2, false)
        recovery().snapshotAndRecover(later, zone, day1, day2, false)
        assertEquals(2, queries)
        assertEquals(2940L, total())
        assertEquals("reconciled", status())
    }

    @Test fun simultaneousHistoricalReadersShareTheCompletedAttempt() {
        events = fullTrace()
        val pool = java.util.concurrent.Executors.newFixedThreadPool(2)
        try {
            val jobs = (1..2).map { pool.submit { repair() } }
            jobs.forEach { it.get(10, java.util.concurrent.TimeUnit.SECONDS) }
            assertEquals(1, queries)
            assertEquals(2940L, total())
        } finally { pool.shutdownNow() }
    }

    @Test fun packageFilterRunsOncePerDistinctPackagePerDay() {
        events = fullTrace()
        var lookups = 0
        UsageHistoryRecovery(store, { _, _ -> events }, { lookups++; true }, { it })
            .snapshotAndRecover(now, zone, day1, day2, false)
        assertEquals(1, lookups)
    }

    @Test fun workerDoesNotWriteAnUnknownNewerSchema() {
        seedPartial()
        db.version = 6
        events = fullTrace()
        repair()
        assertEquals(2400L, total())
        assertEquals(6, db.version)
        assertNull(status())
    }
    private fun total(): Long = scalar("SELECT COALESCE(SUM(duration_seconds), 0) FROM daily_app_usage WHERE day = '2026-09-07'")
    private fun scalar(sql: String): Long = db.rawQuery(sql, null).use { it.moveToFirst(); it.getLong(0) }
    private fun status(): String? = db.rawQuery("SELECT status FROM usage_snapshot_days WHERE day = '2026-09-07'", null)
        .use { if (it.moveToFirst()) it.getString(0) else null }
    private fun row(seconds: Long) = UsageSnapshotRow("instagram", "Instagram", seconds, 1)
    private fun event(ms: Long, kind: UsageStats.EventKind) = UsageStats.EventRecord("instagram", ms, kind)
    private fun time(day: Int, hour: Int = 0, minute: Int = 0): Long = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
        clear(); set(2026, Calendar.SEPTEMBER, day, hour, minute)
    }.timeInMillis
}
