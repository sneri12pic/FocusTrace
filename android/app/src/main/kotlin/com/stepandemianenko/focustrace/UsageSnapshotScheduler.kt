package com.stepandemianenko.focustrace

import android.content.Context
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

object UsageSnapshotScheduler {
    internal const val REPEAT_INTERVAL_MINUTES = 15L
    internal const val UNIQUE_WORK_NAME = "focustrace_usage_snapshot"

    fun schedule(context: Context) {
        val request = PeriodicWorkRequestBuilder<UsageSnapshotWorker>(
            REPEAT_INTERVAL_MINUTES,
            TimeUnit.MINUTES,
        ).build()

        WorkManager.getInstance(context.applicationContext)
            .enqueueUniquePeriodicWork(
                UNIQUE_WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                request,
            )
    }
}
