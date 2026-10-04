package com.stepandemianenko.focustrace

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class SyncWorker(context: Context, parameters: WorkerParameters) : CoroutineWorker(context, parameters) {
    override suspend fun doWork(): Result {
        if (isStopped) return Result.success()
        return try {
            resultFor(BackgroundSyncEngine.run(applicationContext), runAttemptCount)
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (_: Exception) {
            // Unknown startup/platform faults are not transient network failures.
            Result.failure()
        }
    }

    internal companion object {
        fun resultFor(outcome: String, attempt: Int): Result = when (outcome) {
            "success" -> Result.success()
            // Three backoff retries per period, then defer to the next cadence.
            "retry" -> if (attempt < 3) Result.retry() else Result.success()
            else -> Result.failure()
        }
    }
}

internal object BackgroundSyncEngine {
    suspend fun run(
        context: Context,
        createEngine: () -> FlutterEngine = { FlutterEngine(context, null, false) },
    ): String = withContext(Dispatchers.Main) {
        val lifecycle = BackgroundSyncLifecycle()
        var engine: FlutterEngine? = null
        var channel: MethodChannel? = null
        lifecycle.run(start = {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(context)
            loader.ensureInitializationCompleteAsync(context, null,
                android.os.Handler(android.os.Looper.getMainLooper())) {
                // Loader callbacks may arrive after cancellation/deadline.
                if (lifecycle.state != BackgroundSyncLifecycle.State.STARTING) return@ensureInitializationCompleteAsync
                try {
                    val created = createEngine()
                    engine = created // Own it before plugin/channel registration can fail.
                    io.flutter.plugins.GeneratedPluginRegistrant.registerWith(created)
                    attachSyncChannels(created, context, lifecycle)
                    channel = MethodChannel(created.dartExecutor.binaryMessenger, "focustrace/background_sync")
                    channel!!.setMethodCallHandler { call, reply ->
                        when (call.method) {
                            "ready" -> lifecycle.onReady { reply.success(it) }
                            "complete" -> {
                                reply.success(null)
                                lifecycle.onComplete(call.arguments as? String ?: "failure")
                            }
                            else -> reply.notImplemented()
                        }
                    }
                    created.dartExecutor.executeDartEntrypoint(
                        DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "backgroundSync"),
                    )
                } catch (_: Exception) {
                    lifecycle.onComplete("failure")
                }
            }
        }, destroy = {
            channel?.setMethodCallHandler(null)
            channel = null
            val retired = engine
            engine = null
            retired?.destroy()
        })
    }
}
