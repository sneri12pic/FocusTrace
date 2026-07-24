package com.stepandemianenko.focustrace

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
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

    fun startOfTodayMillis(): Long = Calendar.getInstance().apply {
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
        val usageStatsManager =
            context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val records = buildList {
            val events = usageStatsManager.queryEvents(fromMs, toMs)
            val event = UsageEvents.Event()
            while (events.hasNextEvent()) {
                events.getNextEvent(event)
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
        return aggregateEvents(records, toMs, packageNames)
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
                    if (!isRequested) continue

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
        val usageStatsManager =
            context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = usageStatsManager.queryEvents(fromMs, toMs)
        val event = UsageEvents.Event()
        var current: String? = null
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val packageName = event.packageName ?: continue
            if (isForegroundEvent(event.eventType)) {
                current = packageName
            } else if (isBackgroundEvent(event.eventType) && current == packageName) {
                current = null
            }
        }
        return current
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
