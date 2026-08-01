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
            val totals = UsageStats.todayTotals(applicationContext)
            val rows = UsageSnapshotMapper.rows(totals) { packageName ->
                UsageStats.appLabelFor(applicationContext, packageName)
            }
            UsageSnapshotStore(applicationContext).replaceToday(rows)
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
}

internal class UsageSnapshotStore(private val context: Context) {
    fun replaceToday(rows: List<UsageSnapshotRow>) {
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
            if (!database.hasDailyUsageTable()) {
                return
            }
            val day = dayKey(Calendar.getInstance())
            database.beginTransaction()
            try {
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
                database.setTransactionSuccessful()
            } finally {
                database.endTransaction()
            }
        }
    }

    private fun SQLiteDatabase.hasDailyUsageTable(): Boolean {
        rawQuery(
            "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
            arrayOf(TABLE_DAILY_USAGE),
        ).use { cursor ->
            return cursor.moveToFirst()
        }
    }

    companion object {
        internal const val DATABASE_NAME = "focus_trace.db"
        internal const val TABLE_DAILY_USAGE = "daily_app_usage"

        internal fun dayKey(calendar: Calendar): String {
            return "%04d-%02d-%02d".format(
                calendar.get(Calendar.YEAR),
                calendar.get(Calendar.MONTH) + 1,
                calendar.get(Calendar.DAY_OF_MONTH),
            )
        }
    }
}
