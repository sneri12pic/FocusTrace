package com.stepandemianenko.focustrace

import android.app.usage.UsageStatsManager
import android.content.Context

/**
 * Android's own aggregated usage buckets, for history from before FocusTrace
 * recorded anything. These are approximate: Android decides the bucket
 * boundaries and how long each interval type is kept (OEM-dependent), and they
 * carry no launch counts or sessions. Read-only; Flutter stores them apart from
 * the precisely reconstructed `daily_app_usage` rows.
 */
internal object OsUsageHistory {
    private const val DAY_MS = 24L * 60 * 60 * 1_000

    // Generous query windows; Android returns only what it still retains.
    private val intervals = listOf(
        Triple(UsageStatsManager.INTERVAL_DAILY, "daily", 31L),
        Triple(UsageStatsManager.INTERVAL_MONTHLY, "monthly", 2 * 366L),
    )

    fun read(context: Context, nowMs: Long): List<Map<String, Any>> {
        val manager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val userFacing = HashMap<String, Boolean>()
        val labels = HashMap<String, String>()
        val rows = mutableListOf<Map<String, Any>>()
        for ((interval, name, lookbackDays) in intervals) {
            // Some OEMs repeat a package within one bucket; keep its largest total.
            val best = HashMap<Pair<Long, String>, android.app.usage.UsageStats>()
            for (stat in manager.queryUsageStats(interval, nowMs - lookbackDays * DAY_MS, nowMs).orEmpty()) {
                if (stat.totalTimeInForeground <= 0) continue
                val key = stat.firstTimeStamp to stat.packageName
                if ((best[key]?.totalTimeInForeground ?: -1) < stat.totalTimeInForeground) best[key] = stat
            }
            for ((key, stat) in best) {
                val packageName = key.second
                if (!userFacing.getOrPut(packageName) { UsageStats.isUserFacingApp(context, packageName) }) continue
                rows += mapOf(
                    "interval" to name,
                    "startMs" to stat.firstTimeStamp,
                    "endMs" to stat.lastTimeStamp,
                    "packageName" to packageName,
                    "appName" to labels.getOrPut(packageName) { UsageStats.appLabelFor(context, packageName) },
                    "foregroundMs" to stat.totalTimeInForeground,
                )
            }
        }
        return rows
    }
}
