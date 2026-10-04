package com.stepandemianenko.focustrace

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Attach once to each engine, before starting Dart; no Activity is required. */
internal class SyncExecutionGateChannel(
    engine: FlutterEngine,
    private val admit: () -> Boolean = { true },
    private val released: () -> Unit = {},
) : MethodChannel.MethodCallHandler {
    private val main = Handler(Looper.getMainLooper())
    private var client = SyncExecutionGate.client()
    private var destroyed = false
    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "focustrace/sync_execution")

    init {
        channel.setMethodCallHandler(this)
        engine.addEngineLifecycleListener(object : FlutterEngine.EngineLifecycleListener {
            override fun onPreEngineRestart() = retireClient(restart = true)
            override fun onEngineWillDestroy() = retireClient(restart = false)
        })
    }

    private fun retireClient(restart: Boolean) {
        val retired = client
        if (!restart) destroyed = true
        channel.setMethodCallHandler(null)
        // The callback precedes isolate destruction. Do not grant another engine
        // until destroy/restart returns to the platform loop and old Dart is gone.
        main.post {
            SyncExecutionGate.close(retired)
            if (restart && !destroyed) {
                client = SyncExecutionGate.client()
                channel.setMethodCallHandler(this)
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (destroyed) {
            result.error("SYNC_GATE_CLOSED", "Sync coordination unavailable.", null)
            return
        }
        when (call.method) {
            "acquire" -> {
                if (admit()) SyncExecutionGate.acquire(client) { result.success(it) }
                else result.error("SYNC_GATE_CLOSED", "Sync coordination unavailable.", null)
            }
            "release" -> {
                val lease = call.arguments as? String
                if (lease != null && SyncExecutionGate.release(client, lease)) {
                    released()
                    result.success(null)
                } else {
                    result.error("SYNC_GATE_OWNER", "Invalid sync operation ownership.", null)
                }
            }
            else -> result.notImplemented()
        }
    }
}
