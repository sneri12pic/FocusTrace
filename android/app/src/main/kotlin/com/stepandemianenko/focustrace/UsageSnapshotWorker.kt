package com.stepandemianenko.focustrace

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteException
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.util.Calendar

class UsageSnapshotWorker(
    appContext: Context,
    workerParams: WorkerParameters,
) : Worker(appContext, workerParams) {
    override fun doWork(): Result {
        if (!FocusTracePermissions.hasUsageAccess(applicationContext)) {
            return Result.success()
        }

        return try {
            val now = System.currentTimeMillis()
            val totals = UsageStats.todayTotals(applicationContext)
            val rows = UsageSnapshotMapper.rows(totals) { packageName ->
                UsageStats.appLabelFor(applicationContext, packageName)
            }
            val intervals = UsageSnapshotMapper.intervalRows(
                UsageStats.foregroundIntervals(
                    applicationContext,
                    UsageStats.startOfTodayMillis(),
                    now,
                ),
            ) { packageName ->
                UsageStats.appLabelFor(applicationContext, packageName)
            }
            UsageSnapshotStore(applicationContext).replaceToday(rows, intervals)
            // Keep both widgets current even when Flutter has not been opened.
            UsageWidgetProvider.refreshAll(applicationContext, totals)
            Result.success()
        } catch (_: SecurityException) {
            // Permission can be revoked between the initial check and query.
            Result.success()
        } catch (_: SQLiteException) {
            Result.retry()
        } catch (_: Exception) {
            Result.retry()
        }
    }
}

internal data class UsageSnapshotRow(
    val appKey: String,
    val appName: String,
    val durationSeconds: Long,
    val launchCount: Int,
)

internal data class UsageIntervalRow(
    val id: String,
    val appKey: String,
    val appName: String,
    val startedAtMs: Long,
    val endedAtMs: Long,
)

internal object UsageSnapshotMapper {
    fun rows(
        totals: Map<String, UsageStats.AppUsage>,
        labelFor: (String) -> String,
    ): List<UsageSnapshotRow> {
        return totals
            .map { (packageName, usage) ->
                UsageSnapshotRow(
                    appKey = packageName,
                    appName = labelFor(packageName),
                    durationSeconds = usage.totalMs / 1_000L,
                    launchCount = usage.launchCount,
                )
            }
            .filter { it.durationSeconds > 0L }
            .sortedByDescending { it.durationSeconds }
    }

    fun intervalRows(
        intervals: List<UsageStats.ForegroundInterval>,
        labelFor: (String) -> String,
    ): List<UsageIntervalRow> {
        val labels = mutableMapOf<String, String>()
        return intervals.map { interval ->
            UsageIntervalRow(
                id = "${interval.packageName}:${interval.startedAtMs}",
                appKey = interval.packageName,
                appName = labels.getOrPut(interval.packageName) {
                    labelFor(interval.packageName)
                },
                startedAtMs = interval.startedAtMs,
                endedAtMs = interval.endedAtMs,
            )
        }
    }
}

internal class UsageSnapshotStore(private val context: Context) {
    fun replaceToday(
        rows: List<UsageSnapshotRow>,
        intervals: List<UsageIntervalRow> = emptyList(),
    ) {
        val databaseFile = context.getDatabasePath(DATABASE_NAME)
        if (!databaseFile.exists()) {
            // Flutter creates and migrates the shared database on first use.
            // A later periodic run will snapshot after that initialization.
            return
        }

        SQLiteDatabase.openDatabase(
            databaseFile.path,
            null,
            SQLiteDatabase.OPEN_READWRITE,
        ).use { database ->
            val hasDailyUsage = database.hasTable(TABLE_DAILY_USAGE)
            val hasUsageIntervals = database.hasTable(TABLE_USAGE_INTERVALS)
            if (!hasDailyUsage && !hasUsageIntervals) {
                return
            }
            val calendar = Calendar.getInstance()
            val day = dayKey(calendar)
            val dayStartMs = calendar.apply {
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }.timeInMillis
            val nextDayMs = (calendar.clone() as Calendar).apply {
                add(Calendar.DAY_OF_MONTH, 1)
            }.timeInMillis
            database.beginTransaction()
            try {
                if (hasDailyUsage) {
                    database.delete(TABLE_DAILY_USAGE, "day = ?", arrayOf(day))
                    for (row in rows) {
                        database.insertWithOnConflict(
                            TABLE_DAILY_USAGE,
                            null,
                            ContentValues().apply {
                                put("day", day)
                                put("app_key", row.appKey)
                                put("app_name", row.appName)
                                put("package_name", row.appKey)
                                putNull("process_name")
                                put("duration_seconds", row.durationSeconds)
                                put("launch_count", row.launchCount)
                            },
                            SQLiteDatabase.CONFLICT_REPLACE,
                        )
                    }
                }
                if (hasUsageIntervals) {
                    database.delete(
                        TABLE_USAGE_INTERVALS,
                        "started_at >= ? AND started_at < ?",
                        arrayOf(dayStartMs.toString(), nextDayMs.toString()),
                    )
                    for (interval in intervals) {
                        database.insertWithOnConflict(
                            TABLE_USAGE_INTERVALS,
                            null,
                            ContentValues().apply {
                                put("id", interval.id)
                                put("app_key", interval.appKey)
                                put("app_name", interval.appName)
                                put("started_at", interval.startedAtMs)
                                put("ended_at", interval.endedAtMs)
                            },
                            SQLiteDatabase.CONFLICT_REPLACE,
                        )
                    }
                }
                database.setTransactionSuccessful()
            } finally {
                database.endTransaction()
            }
        }
    }

    private fun SQLiteDatabase.hasTable(tableName: String): Boolean {
        rawQuery(
            "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
            arrayOf(tableName),
        ).use { cursor ->
            return cursor.moveToFirst()
        }
    }

    companion object {
        internal const val DATABASE_NAME = "focus_trace.db"
        internal const val TABLE_DAILY_USAGE = "daily_app_usage"
        internal const val TABLE_USAGE_INTERVALS = "usage_intervals"

        internal fun dayKey(calendar: Calendar): String {
            return "%04d-%02d-%02d".format(
                calendar.get(Calendar.YEAR),
                calendar.get(Calendar.MONTH) + 1,
                calendar.get(Calendar.DAY_OF_MONTH),
            )
        }
    }
}
