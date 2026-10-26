package com.stepandemianenko.focustrace

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

/**
 * Automatic workout import. WorkManager decides when it actually runs, and
 * source apps sync to Health Connect on their own schedule, so imports can lag
 * by hours. Settings and permissions are rechecked by the importer on every
 * run; a run that finds the integration off does nothing.
 */
class HealthConnectWorker(
    context: Context,
    params: WorkerParameters,
) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        val store = HealthConnectStore(applicationContext)
        if (!store.enabled || !store.autoImport) {
            HealthConnectScheduler.cancel(applicationContext)
            return Result.success()
        }
        HealthConnectImporter(applicationContext, store).run(inBackground = true)
        // Failures are shown in Settings and retried on the next period.
        return Result.success()
    }
}

object HealthConnectScheduler {
    internal const val UNIQUE_WORK_NAME = "focustrace_health_connect_import"
    internal const val REPEAT_INTERVAL_HOURS = 6L

    /** Schedules or cancels the periodic import to match the stored settings. */
    fun reconcile(context: Context) {
        val store = HealthConnectStore(context)
        if (store.enabled && store.autoImport) schedule(context) else cancel(context)
    }

    private fun schedule(context: Context) {
        val request = PeriodicWorkRequestBuilder<HealthConnectWorker>(
            REPEAT_INTERVAL_HOURS,
            TimeUnit.HOURS,
        ).build()
        WorkManager.getInstance(context.applicationContext).enqueueUniquePeriodicWork(
            UNIQUE_WORK_NAME,
            ExistingPeriodicWorkPolicy.KEEP,
            request,
        )
    }

    fun cancel(context: Context) {
        WorkManager.getInstance(context.applicationContext).cancelUniqueWork(UNIQUE_WORK_NAME)
    }
}
