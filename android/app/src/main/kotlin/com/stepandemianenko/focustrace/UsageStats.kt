package com.stepandemianenko.focustrace

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.SystemClock
import java.util.Calendar

/** Today's per-app foreground time, shared by MainActivity and the home widget. */
object UsageStats {
    data class AppUsage(
        val totalMs: Long,
        val lastUsedMs: Long,
        val launchCount: Int,
    )

    internal enum class EventKind {
        Foreground,
        Background,
        Other,
    }

    internal data class EventRecord(
        val packageName: String,
        val timeStampMs: Long,
        val kind: EventKind,
    )

    internal class QueryMetrics {
        var queryCount = 0
        var eventsIterated = 0
        var queryFromMs: Long? = null
        var queryToMs: Long? = null
        var queryAndIterationNs = 0L
        var aggregationNs = 0L
        var latestForegroundEventMs: Long? = null

        val queryWindowMs: Long?
            get() = queryFromMs?.let { from -> queryToMs?.let { to -> to - from } }
    }

    internal data class BlockerSnapshot(
        val currentForegroundPackage: String?,
        val latestForegroundEventMs: Long?,
        val usageMs: Map<String, Long>,
    )

    internal data class QueryWindow(
        val fromMs: Long,
        val toMs: Long,
    )

    internal class IncrementalState {
        private var dayStartMs: Long? = null
        private var restrictedPackages: Set<String> = emptySet()
        private var cursorMs: Long? = null
        private var lastSuccessfulToMs: Long? = null
        private val cursorEvents = HashSet<EventRecord>()
        private var foregroundPackage: String? = null
        private var foregroundStartedAtMs: Long? = null
        private var latestForegroundEventMs: Long? = null
        private val committedUsageMs = HashMap<String, Long>()

        fun nextQuery(
            dayStartMs: Long,
            nowMs: Long,
            restrictedPackages: Set<String>,
        ): QueryWindow {
            require(nowMs >= dayStartMs)
            if (this.dayStartMs != dayStartMs ||
                this.restrictedPackages != restrictedPackages ||
                lastSuccessfulToMs?.let { nowMs < it } == true
            ) {
                reset(dayStartMs, restrictedPackages)
            }
            return QueryWindow(cursorMs ?: dayStartMs, nowMs)
        }

        fun apply(
            window: QueryWindow,
            events: Iterable<EventRecord>,
        ): BlockerSnapshot {
            check(window.fromMs == (cursorMs ?: dayStartMs))
            check(window.toMs >= window.fromMs)
            var newestTimestampMs = cursorMs
            val newestEvents = HashSet(cursorEvents)
            for (event in events) {
                if (event.timeStampMs < window.fromMs || event.timeStampMs >= window.toMs) {
                    continue
                }
                val newest = newestTimestampMs
                if (newest != null && event.timeStampMs < newest) continue
                if (newest == null || event.timeStampMs > newest) {
                    newestTimestampMs = event.timeStampMs
                    newestEvents.clear()
                }
                if (!newestEvents.add(event)) continue
                when (event.kind) {
                    EventKind.Foreground -> openForeground(event)
                    EventKind.Background -> {
                        if (foregroundPackage == event.packageName) {
                            closeForeground(event.timeStampMs)
                        }
                    }
                    EventKind.Other -> Unit
                }
            }
            cursorMs = newestTimestampMs
            cursorEvents.clear()
            cursorEvents.addAll(newestEvents)
            lastSuccessfulToMs = window.toMs
            return snapshot(window.toMs)
        }

        fun snapshot(nowMs: Long): BlockerSnapshot {
            val usageMs = HashMap(committedUsageMs)
            val packageName = foregroundPackage
            val startedAtMs = foregroundStartedAtMs
            if (packageName != null &&
                packageName in restrictedPackages &&
                startedAtMs != null &&
                nowMs > startedAtMs
            ) {
                usageMs[packageName] =
                    (usageMs[packageName] ?: 0L) + (nowMs - startedAtMs)
            }
            return BlockerSnapshot(
                currentForegroundPackage = packageName,
                latestForegroundEventMs = latestForegroundEventMs,
                usageMs = usageMs.filterValues { it > 0L },
            )
        }

        fun invalidate() {
            dayStartMs = null
            restrictedPackages = emptySet()
            cursorMs = null
            lastSuccessfulToMs = null
            cursorEvents.clear()
            foregroundPackage = null
            foregroundStartedAtMs = null
            latestForegroundEventMs = null
            committedUsageMs.clear()
        }

        private fun reset(dayStartMs: Long, restrictedPackages: Set<String>) {
            invalidate()
            this.dayStartMs = dayStartMs
            this.restrictedPackages = restrictedPackages.toSet()
        }

        private fun openForeground(event: EventRecord) {
            if (foregroundPackage == event.packageName) {
                latestForegroundEventMs = event.timeStampMs
                return
            }
            closeForeground(event.timeStampMs)
            foregroundPackage = event.packageName
            foregroundStartedAtMs = event.timeStampMs
            latestForegroundEventMs = event.timeStampMs
        }

        private fun closeForeground(endedAtMs: Long) {
            val packageName = foregroundPackage
            val startedAtMs = foregroundStartedAtMs
            if (packageName != null &&
                packageName in restrictedPackages &&
                startedAtMs != null &&
                endedAtMs > startedAtMs
            ) {
                committedUsageMs[packageName] =
                    (committedUsageMs[packageName] ?: 0L) + (endedAtMs - startedAtMs)
            }
            foregroundPackage = null
            foregroundStartedAtMs = null
            latestForegroundEventMs = null
        }
    }

    data class ForegroundInterval(
        val packageName: String,
        val startedAtMs: Long,
        val endedAtMs: Long,
    )

    fun startOfTodayMillis(): Long = startOfDayMillis(System.currentTimeMillis())

    internal fun startOfDayMillis(nowMs: Long): Long = Calendar.getInstance().apply {
        timeInMillis = nowMs
        set(Calendar.HOUR_OF_DAY, 0)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
    }.timeInMillis

    fun todayTotals(context: Context): Map<String, AppUsage> {
        val now = System.currentTimeMillis()
        return foregroundTotals(context, startOfTodayMillis(), now)
            .filter { it.value.totalMs > 0L && isUserFacingApp(context, it.key) }
    }

    fun foregroundTotals(
        context: Context,
        fromMs: Long,
        toMs: Long,
        packageNames: Set<String>? = null,
    ): Map<String, AppUsage> {
        return foregroundTotals(context, fromMs, toMs, packageNames, null)
    }

    internal fun incrementalBlockerSnapshot(
        context: Context,
        dayStartMs: Long,
        nowMs: Long,
        packageNames: Set<String>,
        state: IncrementalState,
        metrics: QueryMetrics?,
    ): BlockerSnapshot {
        val window = state.nextQuery(dayStartMs, nowMs, packageNames)
        val records = eventRecords(context, window.fromMs, window.toMs, metrics)
        val startedAtNs = metrics?.let { SystemClock.elapsedRealtimeNanos() }
        val snapshot = state.apply(window, records)
        if (startedAtNs != null) {
            metrics.aggregationNs += SystemClock.elapsedRealtimeNanos() - startedAtNs
            metrics.latestForegroundEventMs = snapshot.latestForegroundEventMs
        }
        return snapshot
    }

    private fun foregroundTotals(
        context: Context,
        fromMs: Long,
        toMs: Long,
        packageNames: Set<String>?,
        metrics: QueryMetrics?,
    ): Map<String, AppUsage> {
        val records = eventRecords(context, fromMs, toMs, metrics)
        val startedAtNs = metrics?.let { SystemClock.elapsedRealtimeNanos() }
        val totals = aggregateEvents(records, toMs, packageNames)
        if (startedAtNs != null) {
            metrics.aggregationNs += SystemClock.elapsedRealtimeNanos() - startedAtNs
        }
        return totals
    }

    fun foregroundIntervals(
        context: Context,
        fromMs: Long,
        toMs: Long,
    ): List<ForegroundInterval> {
        return aggregateIntervals(eventRecords(context, fromMs, toMs), toMs)
            .filter {
                it.endedAtMs > it.startedAtMs &&
                    it.packageName != context.packageName &&
                    isUserFacingApp(context, it.packageName)
            }
    }

    internal fun aggregateIntervals(
        events: Iterable<EventRecord>,
        toMs: Long,
        packageNames: Set<String>? = null,
    ): List<ForegroundInterval> {
        val intervals = mutableListOf<ForegroundInterval>()
        var foregroundPackage: String? = null
        var foregroundSince = 0L

        fun closeForeground(endedAtMs: Long) {
            val packageName = foregroundPackage ?: return
            if (endedAtMs > foregroundSince &&
                (packageNames == null || packageName in packageNames)
            ) {
                intervals.add(
                    ForegroundInterval(
                        packageName = packageName,
                        startedAtMs = foregroundSince,
                        endedAtMs = endedAtMs,
                    )
                )
            }
            foregroundPackage = null
        }

        for (event in events) {
            when (event.kind) {
                EventKind.Foreground -> {
                    if (foregroundPackage == event.packageName) continue
                    closeForeground(event.timeStampMs)
                    foregroundPackage = event.packageName
                    foregroundSince = event.timeStampMs
                }
                EventKind.Background -> {
                    if (foregroundPackage == event.packageName) {
                        closeForeground(event.timeStampMs)
                    }
                }
                EventKind.Other -> Unit
            }
        }
        closeForeground(toMs)
        return intervals
    }

    internal fun aggregateEvents(
        events: Iterable<EventRecord>,
        toMs: Long,
        packageNames: Set<String>? = null,
    ): Map<String, AppUsage> {
        val totals = HashMap<String, Long>()
        val foregroundSince = HashMap<String, Long>()
        val lastUsed = HashMap<String, Long>()
        val lastBackground = HashMap<String, Long>()
        val launches = HashMap<String, Int>()
        var lastForegroundPackage: String? = null

        for (event in events) {
            val packageName = event.packageName
            val isRequested = packageNames == null || packageName in packageNames
            when (event.kind) {
                EventKind.Foreground -> {
                    val isAlreadyForeground = foregroundSince.containsKey(packageName)
                    val returnedAfterGap =
                        lastBackground[packageName]?.let {
                            event.timeStampMs - it >= MIN_RELAUNCH_GAP_MS
                        } == true
                    val isLaunch =
                        !isAlreadyForeground &&
                            (
                                lastForegroundPackage != packageName ||
                                    returnedAfterGap
                                )
                    lastForegroundPackage = packageName

                    // Only one app is foreground at a time. Newer Android often
                    // omits the background event for the outgoing app, so close
                    // any other open session here or its time overlaps this one
                    // and totals stack past wall-clock.
                    val stale = foregroundSince.keys.filter { it != packageName }
                    for (other in stale) {
                        val start = foregroundSince.remove(other) ?: continue
                        if (event.timeStampMs > start) {
                            totals[other] =
                                (totals[other] ?: 0L) + (event.timeStampMs - start)
                        }
                        lastBackground[other] = event.timeStampMs
                        lastUsed[other] = event.timeStampMs
                    }
                    if (!isRequested) continue

                    // Some Android versions emit both the legacy MOVE event and
                    // ACTIVITY_RESUMED. Keep the first timestamp and count the
                    // pair as one launch.
                    if (!foregroundSince.containsKey(packageName)) {
                        foregroundSince[packageName] = event.timeStampMs
                    }
                    if (isLaunch) {
                        launches[packageName] = (launches[packageName] ?: 0) + 1
                    }
                    lastUsed[packageName] = event.timeStampMs
                }
                EventKind.Background -> {
                    if (!isRequested) continue
                    lastBackground[packageName] = event.timeStampMs
                    val start = foregroundSince.remove(packageName)
                    if (start != null && event.timeStampMs > start) {
                        totals[packageName] =
                            (totals[packageName] ?: 0L) + (event.timeStampMs - start)
                    }
                    lastUsed[packageName] = event.timeStampMs
                }
                EventKind.Other -> Unit
            }
        }

        // Apps still in the foreground at query time have no closing event.
        for ((packageName, start) in foregroundSince) {
            if (toMs > start) {
                totals[packageName] = (totals[packageName] ?: 0L) + (toMs - start)
                lastUsed[packageName] = toMs
            }
        }

        return totals
            .filterValues { it > 0L }
            .mapValues { (packageName, totalMs) ->
                AppUsage(
                    totalMs = totalMs,
                    lastUsedMs = lastUsed[packageName] ?: toMs,
                    launchCount = launches[packageName] ?: 0,
                )
            }
    }

    fun currentForegroundPackage(context: Context, fromMs: Long, toMs: Long): String? {
        return currentForegroundPackage(context, fromMs, toMs, null)
    }

    private fun currentForegroundPackage(
        context: Context,
        fromMs: Long,
        toMs: Long,
        metrics: QueryMetrics?,
    ): String? {
        val usageStatsManager =
            context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val startedAtNs = metrics?.startQuery(fromMs, toMs)
        try {
            val events = usageStatsManager.queryEvents(fromMs, toMs)
            val event = UsageEvents.Event()
            var current: String? = null
            var currentSinceMs: Long? = null
            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                metrics?.let { it.eventsIterated += 1 }
                val packageName = event.packageName ?: continue
                if (isForegroundEvent(event.eventType)) {
                    current = packageName
                    currentSinceMs = event.timeStamp
                } else if (isBackgroundEvent(event.eventType) && current == packageName) {
                    current = null
                    currentSinceMs = null
                }
            }
            metrics?.latestForegroundEventMs = currentSinceMs
            return current
        } finally {
            if (startedAtNs != null) {
                metrics.queryAndIterationNs += SystemClock.elapsedRealtimeNanos() - startedAtNs
            }
        }
    }

    private fun eventRecords(
        context: Context,
        fromMs: Long,
        toMs: Long,
        metrics: QueryMetrics? = null,
    ): List<EventRecord> {
        val usageStatsManager =
            context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val startedAtNs = metrics?.startQuery(fromMs, toMs)
        try {
            return buildList {
                val events = usageStatsManager.queryEvents(fromMs, toMs)
                val event = UsageEvents.Event()
                while (events.hasNextEvent()) {
                    events.getNextEvent(event)
                    metrics?.let { it.eventsIterated += 1 }
                    val packageName = event.packageName ?: continue
                    add(
                        EventRecord(
                            packageName = packageName,
                            timeStampMs = event.timeStamp,
                            kind = when {
                                isForegroundEvent(event.eventType) -> EventKind.Foreground
                                isBackgroundEvent(event.eventType) -> EventKind.Background
                                else -> EventKind.Other
                            },
                        )
                    )
                }
            }
        } finally {
            if (startedAtNs != null) {
                metrics.queryAndIterationNs += SystemClock.elapsedRealtimeNanos() - startedAtNs
            }
        }
    }

    private fun QueryMetrics.startQuery(fromMs: Long, toMs: Long): Long {
        queryCount += 1
        queryFromMs = queryFromMs?.let { minOf(it, fromMs) } ?: fromMs
        queryToMs = queryToMs?.let { maxOf(it, toMs) } ?: toMs
        return SystemClock.elapsedRealtimeNanos()
    }

    // ponytail: launchable-in-app-drawer is the system-app filter; whitelist packages here if a wanted app gets dropped.
    fun isUserFacingApp(context: Context, packageName: String): Boolean {
        return context.packageManager.getLaunchIntentForPackage(packageName) != null
    }

    fun appLabelFor(context: Context, packageName: String): String {
        return try {
            val applicationInfo =
                context.packageManager.getApplicationInfo(packageName, 0)
            context.packageManager.getApplicationLabel(applicationInfo).toString()
        } catch (_: PackageManager.NameNotFoundException) {
            packageName
        }
    }

    @Suppress("DEPRECATION")
    private fun isForegroundEvent(eventType: Int): Boolean {
        return eventType == UsageEvents.Event.MOVE_TO_FOREGROUND ||
            (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
                eventType == UsageEvents.Event.ACTIVITY_RESUMED)
    }

    @Suppress("DEPRECATION")
    private fun isBackgroundEvent(eventType: Int): Boolean {
        return eventType == UsageEvents.Event.MOVE_TO_BACKGROUND ||
            (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
                eventType == UsageEvents.Event.ACTIVITY_PAUSED)
    }

    private const val MIN_RELAUNCH_GAP_MS = 1_000L
}
