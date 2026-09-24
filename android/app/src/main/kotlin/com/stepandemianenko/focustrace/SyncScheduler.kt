package com.stepandemianenko.focustrace

import android.content.Context
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

internal object SyncScheduler {
    const val UNIQUE_WORK_NAME = "focustrace_periodic_sync_v1"
    const val INTERVAL_HOURS = 6L

    fun request() = PeriodicWorkRequestBuilder<SyncWorker>(INTERVAL_HOURS, TimeUnit.HOURS)
        .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
        .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.MINUTES)
        .build()

    fun reconcile(context: Context, enabled: Boolean) =
        WorkManager.getInstance(context.applicationContext).let { manager ->
            if (enabled) manager.enqueueUniquePeriodicWork(
                UNIQUE_WORK_NAME, ExistingPeriodicWorkPolicy.KEEP, request(),
            ) else manager.cancelUniqueWork(UNIQUE_WORK_NAME)
        }
}
