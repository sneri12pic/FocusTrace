package com.stepandemianenko.focustrace

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class SyncExecutionGateInstrumentedTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()

    @Test fun separateEngineChannelsShareOwnershipAndSurviveOwnerDestruction() {
        lateinit var a: FlutterEngine
        lateinit var b: FlutterEngine
        lateinit var first: SyncExecutionGateChannel
        lateinit var second: SyncExecutionGateChannel
        val acquiredA = Reply()
        val acquiredB = Reply()
        try {
            instrumentation.runOnMainSync {
                a = FlutterEngine(instrumentation.targetContext)
                b = FlutterEngine(instrumentation.targetContext)
                first = SyncExecutionGateChannel(a)
                second = SyncExecutionGateChannel(b)
                first.onMethodCall(MethodCall("acquire", null), acquiredA)
                second.onMethodCall(MethodCall("acquire", null), acquiredB)
                assertNotNull(acquiredA.value)
                assertFalse(acquiredB.completed)
                val foreign = Reply()
                second.onMethodCall(MethodCall("release", acquiredA.value), foreign)
                assertEquals("SYNC_GATE_OWNER", foreign.errorCode)
                assertFalse(acquiredB.completed)
                a.destroy()
                // Ownership is not handed over inside onEngineWillDestroy.
                assertFalse(acquiredB.completed)
            }
            instrumentation.waitForIdleSync()
            instrumentation.runOnMainSync {
                assertNotNull(acquiredB.value)
                val stale = Reply()
                first.onMethodCall(MethodCall("release", acquiredA.value), stale)
                assertEquals("SYNC_GATE_CLOSED", stale.errorCode)
                val released = Reply()
                second.onMethodCall(MethodCall("release", acquiredB.value), released)
                assertTrue(released.completed)
                assertNull(released.errorCode)
            }
        } finally {
            instrumentation.runOnMainSync { b.destroy() }
            instrumentation.waitForIdleSync()
        }
    }

    private class Reply : MethodChannel.Result {
        var completed = false
        var value: Any? = null
        var errorCode: String? = null
        override fun success(result: Any?) { completed = true; value = result }
        override fun error(code: String, message: String?, details: Any?) {
            completed = true
            errorCode = code
        }
        override fun notImplemented() { fail("Unexpected method") }
    }
}
