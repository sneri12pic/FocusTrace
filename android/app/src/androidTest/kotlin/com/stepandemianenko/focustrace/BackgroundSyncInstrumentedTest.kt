package com.stepandemianenko.focustrace

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.work.WorkInfo
import androidx.work.WorkManager
import kotlinx.coroutines.*
import io.flutter.embedding.engine.FlutterEngine
import com.tekartik.sqflite.SqflitePlugin
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.util.concurrent.TimeUnit

@RunWith(AndroidJUnit4::class)
class BackgroundSyncInstrumentedTest {
    private val context get() = InstrumentationRegistry.getInstrumentation().targetContext

    @Test fun repeatedSchedulingKeepsOneRequestAndOptOutCancelsIt() {
        val manager = WorkManager.getInstance(context)
        fun states() = manager.getWorkInfosForUniqueWork(SyncScheduler.UNIQUE_WORK_NAME)
            .get(10, TimeUnit.SECONDS)
        try {
            SyncScheduler.reconcile(context, true).result.get(10, TimeUnit.SECONDS)
            val first = states().filter { !it.state.isFinished }.single().id
            SyncScheduler.reconcile(context, true).result.get(10, TimeUnit.SECONDS)
            assertEquals(first, states().filter { !it.state.isFinished }.single().id)
            SyncScheduler.reconcile(context, false).result.get(10, TimeUnit.SECONDS)
            assertTrue(states().all { it.state == WorkInfo.State.CANCELLED })
        } finally {
            SyncScheduler.reconcile(context, false).result.get(10, TimeUnit.SECONDS)
        }
    }

    @Test fun separateHeadlessEnginesCompleteWithoutAnActivity() = runBlocking {
        repeat(2) {
            lateinit var engine: FlutterEngine
            var destroyed = 0
            assertEquals("success", BackgroundSyncEngine.run(context) {
                FlutterEngine(context, null, false).also {
                    engine = it
                    it.addEngineLifecycleListener(object : FlutterEngine.EngineLifecycleListener {
                        override fun onPreEngineRestart() {}
                        override fun onEngineWillDestroy() { destroyed++ }
                    })
                }
            })
            // Success requires Dart's plugin probe, READY authorization and complete.
            assertEquals(1, destroyed)
            withContext(Dispatchers.Main) {
                assertFalse(engine.plugins.has(SqflitePlugin::class.java))
            }
        }
    }

    @Test fun cancellationDestroysARealEngineThatNeverStartsDart() = runBlocking {
        val created = CompletableDeferred<Unit>()
        var destroyed = 0
        val run = launch(Dispatchers.Main) {
            lateinit var engine: FlutterEngine
            BackgroundSyncLifecycle().run(start = {
                engine = FlutterEngine(context)
                attachSyncChannels(engine, context)
                engine.addEngineLifecycleListener(object : FlutterEngine.EngineLifecycleListener {
                    override fun onPreEngineRestart() {}
                    override fun onEngineWillDestroy() { destroyed++ }
                })
                created.complete(Unit)
                // No entrypoint: exercises actual engine/channel teardown before READY.
            }, destroy = { engine.destroy() })
        }
        created.await()
        run.cancelAndJoin()
        assertEquals(1, destroyed)
    }
}
