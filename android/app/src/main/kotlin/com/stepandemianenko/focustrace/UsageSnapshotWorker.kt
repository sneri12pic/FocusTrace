package com.stepandemianenko.focustrace

import android.content.Context
import android.database.sqlite.SQLiteException
import androidx.work.Worker
import androidx.work.WorkerParameters

class UsageSnapshotWorker(
    appContext: Context,
    workerParams: WorkerParameters,
) : Worker(appContext, workerParams) {
    override fun doWork(): Result {
        if (!FocusTracePermissions.hasUsageAccess(applicationContext)) {
            return Result.success()
        }

        return try {
            val recovery = UsageHistoryRecovery(applicationContext)
            val totals = recovery.snapshotAndRecover()
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
