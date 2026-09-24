package com.stepandemianenko.focustrace

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executor

/** Shared foreground/headless registration; no Activity, usage tracking or UI. */
internal fun attachSyncChannels(
    engine: FlutterEngine,
    context: Context,
    lifecycle: BackgroundSyncLifecycle? = null,
) {
    SyncExecutionGateChannel(engine,
        admit = { lifecycle?.onAcquire() ?: true },
        released = { lifecycle?.onReleased() },
    )
    val app = context.applicationContext
    val main = Executor { Handler(Looper.getMainLooper()).post(it) }
    val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "focustrace/sync")
    var destroyed = false
    engine.addEngineLifecycleListener(object : FlutterEngine.EngineLifecycleListener {
        override fun onPreEngineRestart() {}
        override fun onEngineWillDestroy() {
            destroyed = true
            channel.setMethodCallHandler(null)
        }
    })
    channel.setMethodCallHandler { call, result ->
            if (destroyed) return@setMethodCallHandler
            try {
                when (call.method) {
                    "readSyncCredential" -> result.success(SecureCredentialStore.read(app))
                    "writeSyncCredential" -> {
                        SecureCredentialStore.write(app, call.arguments as String)
                        result.success(null)
                    }
                    "clearSyncCredential" -> {
                        SecureCredentialStore.clear(app)
                        result.success(null)
                    }
                    "deviceModel" -> result.success(Build.MODEL)
                    "scheduleSync" -> {
                        val completion = SyncScheduler.reconcile(app, call.arguments == true).result
                        completion.addListener({
                            if (destroyed) return@addListener
                            try {
                                completion.get()
                                result.success(null)
                            } catch (_: Exception) {
                                result.error("SYNC_PLATFORM_FAILED", "Sync platform unavailable.", null)
                            }
                        }, main)
                    }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) {
                result.error("SYNC_PLATFORM_FAILED", "Sync platform unavailable.", null)
            }
        }
}
