package com.stepandemianenko.focustrace

import android.os.Handler
import android.os.Looper
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withContext

/** One invocation, confined to the main thread just like Flutter's messenger. */
internal class BackgroundSyncLifecycle {
    enum class State { STARTING, READY, AUTHORIZED, RUNNING, DRAINED, COMPLETED, CLOSED }
    var state = State.STARTING
        private set
    private val ready = CompletableDeferred<Boolean>()
    private val finished = CompletableDeferred<String>()
    private var authorize: ((Boolean) -> Unit)? = null
    private val main = Handler(Looper.getMainLooper())
    private val deadline = Runnable {
        if (state != State.RUNNING && state != State.COMPLETED && state != State.CLOSED) {
            state = State.COMPLETED
            ready.complete(false)
            finished.complete("failure")
        }
    }

    // Cold VM + generated plugin registration + Dart provider/channel setup.
    // This is deliberately generous and never applies to protected sync work.
    companion object { const val STARTUP_TIMEOUT_MS = 60_000L }

    /** Called before the native gate can queue/grant this engine's only run. */
    fun onAcquire(): Boolean {
        if (state != State.AUTHORIZED) return false
        state = State.RUNNING
        main.removeCallbacks(deadline)
        return true
    }

    /** The validated owner has released; reject all subsequent acquisitions. */
    fun onReleased() {
        if (state != State.RUNNING) return
        state = State.DRAINED
        // Bound plugin disposal / a lost final completion without ever timing
        // out credential mutation. The gate can no longer be entered here.
        main.postDelayed(deadline, STARTUP_TIMEOUT_MS)
    }

    fun onReady(reply: (Boolean) -> Unit) {
        if (state != State.STARTING || ready.isCompleted) {
            reply(false)
            return
        }
        state = State.READY
        authorize = reply
        ready.complete(true)
    }

    fun onComplete(outcome: String) {
        if (state == State.CLOSED || state == State.COMPLETED || state == State.RUNNING) return
        state = State.COMPLETED
        ready.complete(false) // Initialization failure can precede READY.
        finished.complete(outcome)
    }

    suspend fun run(start: () -> Unit, destroy: () -> Unit): String {
        main.postDelayed(deadline, STARTUP_TIMEOUT_MS)
        try {
            start()
            val canStart = ready.await()
            currentCoroutineContext().ensureActive()
            if (!canStart || finished.isCompleted) return finished.await()
            state = State.AUTHORIZED
            val reply = authorize
            authorize = null
            reply!!(true)
            return try {
                finished.await()
            } catch (cancelled: CancellationException) {
                if (state == State.RUNNING || state == State.DRAINED) {
                    // Preserve the established drain. Native observes release,
                    // but never forges/releases Dart's lease itself.
                    withContext(NonCancellable) { finished.await() }
                }
                throw cancelled
            }
        } finally {
            state = State.CLOSED
            main.removeCallbacks(deadline)
            authorize = null
            ready.cancel()
            finished.cancel()
            destroy()
        }
    }
}
