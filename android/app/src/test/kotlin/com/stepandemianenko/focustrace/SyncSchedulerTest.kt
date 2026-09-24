package com.stepandemianenko.focustrace

import androidx.work.BackoffPolicy
import androidx.work.ListenableWorker
import androidx.work.NetworkType
import androidx.work.Configuration
import androidx.work.WorkManager
import androidx.work.WorkInfo
import org.robolectric.RuntimeEnvironment
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.util.concurrent.TimeUnit

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], manifest = Config.NONE)
class SyncSchedulerTest {
    @Test fun repeatedEnableKeepsOneScheduleAndDisableCancels() {
        val context = RuntimeEnvironment.getApplication()
        WorkManager.initialize(context, Configuration.Builder().build())
        val manager = WorkManager.getInstance(context)
        fun active() = manager.getWorkInfosForUniqueWork(SyncScheduler.UNIQUE_WORK_NAME)
            .get(10, TimeUnit.SECONDS).filter { !it.state.isFinished }
        try {
            SyncScheduler.reconcile(context, true).result.get(10, TimeUnit.SECONDS)
            val id = active().single().id
            SyncScheduler.reconcile(context, true).result.get(10, TimeUnit.SECONDS)
            assertEquals(id, active().single().id)
            SyncScheduler.reconcile(context, false).result.get(10, TimeUnit.SECONDS)
            assertTrue(active().isEmpty())
        } finally {
            manager.cancelAllWork().result.get(10, TimeUnit.SECONDS)
        }
    }

    @Test fun requestRequiresNetworkAndConservativeCadence() {
        val request = SyncScheduler.request()
        val spec = request.workSpec
        assertEquals(TimeUnit.HOURS.toMillis(6), spec.intervalDuration)
        assertEquals(NetworkType.CONNECTED, spec.constraints.requiredNetworkType)
        assertFalse(spec.constraints.requiresCharging())
        assertFalse(spec.constraints.requiresDeviceIdle())
        assertEquals(BackoffPolicy.EXPONENTIAL, spec.backoffPolicy)
        assertEquals(TimeUnit.MINUTES.toMillis(30), spec.backoffDelayDuration)
        assertTrue(spec.input.keyValueMap.isEmpty())
    }

    @Test fun retriesAreTransientAndBounded() {
        assertEquals(ListenableWorker.Result.success(), SyncWorker.resultFor("success", 0))
        for (attempt in 0..2) {
            assertEquals(ListenableWorker.Result.retry(), SyncWorker.resultFor("retry", attempt))
        }
        assertEquals(ListenableWorker.Result.success(), SyncWorker.resultFor("retry", 3))
        assertEquals(ListenableWorker.Result.failure(), SyncWorker.resultFor("failure", 0))
        assertEquals(ListenableWorker.Result.failure(), SyncWorker.resultFor("unknown", 0))
    }
}
