package com.stepandemianenko.focustrace

import android.content.Context
import java.util.Calendar
import java.util.TimeZone

/** Immutable local-calendar assignment, shared by query, clipping and storage. */
internal data class UsageDayWindow(
    val day: String,
    val startMs: Long,
    val endMs: Long,
    val nowMs: Long,
    val timezoneId: String,
) {
    val queryEndMs: Long get() = minOf(endMs, nowMs)
    val historical: Boolean get() = endMs <= nowMs

    companion object {
        fun recent(nowMs: Long, zone: TimeZone): List<UsageDayWindow> {
            val calendar = Calendar.getInstance(zone.clone() as TimeZone).apply {
                timeInMillis = nowMs
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                add(Calendar.DAY_OF_MONTH, -RECOVERY_DAYS)
            }
            return (0..RECOVERY_DAYS).map {
                val day = UsageSnapshotStore.dayKey(calendar)
                val start = calendar.timeInMillis
                calendar.add(Calendar.DAY_OF_MONTH, 1)
                UsageDayWindow(day, start, calendar.timeInMillis, nowMs, zone.id)
            }
        }

        // A bounded attempt window, NOT a claim that Android retains three days.
        const val RECOVERY_DAYS = 3
    }
}

/** The sole Android totals/interval writer, used by WorkManager and channel reads. */
internal class UsageHistoryRecovery(
    private val store: UsageSnapshotStore,
    private val readEvents: (Long, Long) -> List<UsageStats.EventRecord>,
    private val includePackage: (String) -> Boolean,
    private val labelFor: (String) -> String,
    private val diagnostic: (String) -> Unit = {},
) {
    constructor(context: Context) : this(
        UsageSnapshotStore(context),
        { from, to -> UsageStats.eventRecords(context, from, to) },
        { UsageStats.isUserFacingApp(context, it) },
        { UsageStats.appLabelFor(context, it) },
        { message ->
            if (context.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE != 0) {
                android.util.Log.d("FTUsageRecovery", message)
            }
        },
    )

    fun snapshotAndRecover(
        nowMs: Long = System.currentTimeMillis(),
        zone: TimeZone = TimeZone.getDefault(),
        fromMs: Long = Long.MIN_VALUE,
        toMs: Long = Long.MAX_VALUE,
        includeToday: Boolean = true,
    ): Map<String, UsageStats.AppUsage> = synchronized(writerLock) {
        val windows = UsageDayWindow.recent(nowMs, zone)
        val pending = windows.filter {
            (if (it.historical) it.startMs < toMs && it.endMs > fromMs else includeToday) &&
                (!it.historical || store.needsRecovery(it))
        }
        diagnostic("request now=$nowMs zone=${zone.id} history=$fromMs..$toMs today=$includeToday candidates=${pending.map { it.day }}")
        if (pending.isEmpty()) return@synchronized emptyMap()
        val generation = store.generation()
        // One raw event stream supplies both aggregates and evidence, including
        // a preceding state anchor and events after completed days. No separate
        // totals/interval queries that can observe different event versions.
        val queryStart = (pending.first().startMs - LOOKBACK_MS).coerceAtLeast(0)
        val records = readEvents(queryStart, nowMs)
            .filter { it.timeStampMs >= queryStart && it.timeStampMs < nowMs }
            .sortedBy { it.timeStampMs }
        diagnostic("query from=$queryStart to=$nowMs events=${records.size}")
        var todayTotals = emptyMap<String, UsageStats.AppUsage>()
        for (window in pending) {
            val events = UsageStats.eventsInWindow(records, window.startMs, window.queryEndMs)
            // Keep formerly stored packages when they have since been uninstalled.
            val knownPackages = store.packageNames(window)
            val packages = events.map { it.packageName }.distinct().filter {
                it.isNotEmpty() && (it in knownPackages || includePackage(it))
            }.toSet()
            val totals = UsageStats.aggregateEvents(events, window.queryEndMs, packages)
            if (!window.historical) todayTotals = totals
            val covered = hasCoverage(records, window)
            if (!covered && (window.historical || totals.isEmpty())) {
                // A nonempty but unanchored trace can also be truncated. Retain
                // existing snapshots; do not call its apparent zero a success.
                store.markUnavailable(window, generation)
                diagnostic("day=${window.day} result=preserved reason=coverage_unavailable")
                continue
            }
            var written = store.replaceDay(
                window,
                UsageSnapshotMapper.rows(totals, labelFor),
                UsageSnapshotMapper.intervalRows(
                    UsageStats.aggregateIntervals(events, window.queryEndMs, packages),
                    labelFor,
                ),
                generation,
                diagnostic,
            )
            // A reboot can shorten Android's earlier trace. Continue an accepted
            // current-day prefix without erasing it or rejecting all later usage.
            if (!written && !window.historical) {
                val accepted = store.acceptedSnapshot(window, generation)
                if (accepted != null) {
                    val tailWindow = window.copy(startMs = accepted.coveredUntilMs)
                    val tailEvents = UsageStats.eventsInWindow(records, accepted.coveredUntilMs, nowMs)
                    val tailTotals = UsageStats.aggregateEvents(tailEvents, nowMs, packages)
                    // As for a live snapshot, observed post-startup sessions can
                    // advance partial data without certifying a lost reboot gap.
                    if (hasCoverage(records, tailWindow) || tailTotals.isNotEmpty()) {
                        val continued = continueTotals(accepted.totals, tailTotals)
                        val tailIntervals = UsageSnapshotMapper.intervalRows(UsageStats.aggregateIntervals(tailEvents, nowMs, packages), labelFor)
                        written = store.replaceDay(window, UsageSnapshotMapper.rows(continued, labelFor),
                            accepted.intervals + tailIntervals, generation, diagnostic)
                        if (written) {
                            todayTotals = continued
                            diagnostic("day=${window.day} result=continued from=${accepted.coveredUntilMs} seconds=${continued.values.sumOf { it.totalMs } / 1000}")
                        }
                    }
                }
            }
            if (!written) store.markUnavailable(window, generation)
            diagnostic("day=${window.day} result=${if (written) "saved" else "preserved"} historical=${window.historical} seconds=${totals.values.sumOf { it.totalMs } / 1000}")
        }
        todayTotals
    }

    companion object {
        private const val LOOKBACK_MS = 24L * 60 * 60 * 1_000
        internal fun continueTotals(
            accepted: Map<String, UsageStats.AppUsage>,
            tail: Map<String, UsageStats.AppUsage>,
        ): Map<String, UsageStats.AppUsage> = (accepted.keys + tail.keys).associateWith { app ->
            val old = accepted[app]
            val fresh = tail[app]
            UsageStats.AppUsage((old?.totalMs ?: 0) + (fresh?.totalMs ?: 0),
                maxOf(old?.lastUsedMs ?: 0, fresh?.lastUsedMs ?: 0),
                (old?.launchCount ?: 0) + (fresh?.launchCount ?: 0))
        }

        // All native writers run in the default application process. Queries and
        // writes serialize here; SQLite also checks version/bounds under its
        // write transaction. Flutter no longer writes Android live snapshots.
        private val writerLock = Any()

        internal fun hasCoverage(
            records: List<UsageStats.EventRecord>,
            window: UsageDayWindow,
        ): Boolean {
            // Android has no explicit retention-completeness flag. Require a
            // known foreground state at/before the boundary, plus a closed end
            // state or later event. This assumes retained events are contiguous;
            // it cannot certify that an OEM recorded every lifecycle transition.
            var knownStart = false
            for (event in records) {
                if (event.timeStampMs > window.startMs) break
                when (event.kind) {
                    UsageStats.EventKind.Foreground, UsageStats.EventKind.EndForeground -> knownStart = true
                    UsageStats.EventKind.DiscardForeground -> knownStart = false
                    // An orphan pause cannot tell us whether another app was
                    // already foreground before the retained stream starts.
                    else -> Unit
                }
            }
            if (!knownStart) return false
            // A startup with an unmatched active session has an unknowable end.
            // Keep the audit's discard behavior for live accounting, but do not
            // certify the affected historical reconstruction as complete.
            var active: String? = null
            var knownEnd = false
            for (event in records) {
                if (event.timeStampMs >= window.queryEndMs) break
                when (event.kind) {
                    UsageStats.EventKind.Foreground -> {
                        active = event.packageName
                        knownEnd = true
                    }
                    UsageStats.EventKind.Background -> if (active == event.packageName) active = null
                    UsageStats.EventKind.EndForeground -> {
                        active = null
                        knownEnd = true
                    }
                    UsageStats.EventKind.DiscardForeground -> {
                        if (event.timeStampMs >= window.startMs && active != null) return false
                        active = null
                        knownEnd = false
                    }
                    UsageStats.EventKind.Other -> Unit
                }
            }
            // A successful query through captured now with a retained closed
            // state needs no new phone interaction after midnight. For an open
            // or unknown end state, require evidence beyond the day instead.
            return !window.historical || (knownEnd && active == null) ||
                records.any { it.timeStampMs >= window.endMs }
        }
    }
}
