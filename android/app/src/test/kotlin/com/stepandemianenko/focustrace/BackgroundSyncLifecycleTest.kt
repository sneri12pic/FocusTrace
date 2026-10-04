package com.stepandemianenko.focustrace

import android.os.Looper
import kotlinx.coroutines.*
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.LooperMode
import java.time.Duration

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], manifest = Config.NONE)
@LooperMode(LooperMode.Mode.PAUSED)
class BackgroundSyncLifecycleTest {
    private class Invocation {
        val lifecycle = BackgroundSyncLifecycle()
        val events = mutableListOf<String>()
        val client = SyncExecutionGate.client()
        var lease: String? = null
        var destroys = 0
        var terminals = 0
        fun CoroutineScope.start(bootstrap: () -> Unit = {}) = async(start = CoroutineStart.UNDISPATCHED) {
            try {
                lifecycle.run({ events += "created"; bootstrap() }, {
                    assertNull("destroy must follow the owner's release", lease)
                    destroys++
                    events += "destroyed"
                })
            } finally { terminals++ }
        }
        fun ready() = lifecycle.onReady { allowed ->
            if (allowed) {
                events += "authorized"
                assertTrue(lifecycle.onAcquire())
                SyncExecutionGate.acquire(client) { lease = it; events += "acquired" }
            }
        }
        fun complete() {
            lease?.let { assertTrue(SyncExecutionGate.release(client, it)) }
            lease = null
            lifecycle.onReleased()
            events += "released"
            lifecycle.onComplete("success")
        }
        fun assertClosed() {
            assertEquals(BackgroundSyncLifecycle.State.CLOSED, lifecycle.state)
            assertEquals(1, destroys)
            assertEquals(1, terminals)
            assertNull(lease)
            assertFalse(lifecycle.onAcquire())
            val probe = SyncExecutionGate.client()
            var acquired = false
            SyncExecutionGate.acquire(probe) { acquired = true; SyncExecutionGate.release(probe, it) }
            assertTrue("no gate ownership survives", acquired)
            SyncExecutionGate.close(probe)
            SyncExecutionGate.close(client)
        }
    }

    @Test fun normalLifecycleReleasesBeforeOneDestruction() = runBlocking {
        val invocation = Invocation()
        val result = with(invocation) { start() }
        invocation.ready()
        yield()
        invocation.complete()
        assertEquals("success", result.await())
        assertEquals(listOf("created", "authorized", "acquired", "released", "destroyed"), invocation.events)
        invocation.assertClosed()
    }

    @Test fun neverReadyTerminatesAtStartupDeadlineWithNoLease() = runBlocking {
        val invocation = Invocation()
        val result = with(invocation) { start() }
        try {
            shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(59_999))
            yield()
            assertFalse(result.isCompleted)
            shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(1))
            yield()
            // Assert before await, so removing the bound fails instead of hanging.
            assertTrue("startup deadline must terminate the wait", result.isCompleted)
            assertEquals("failure", result.await())
            invocation.assertClosed()
        } finally { result.cancelAndJoin() }
    }

    @Test fun startupExceptionCleansUpWithoutReady() = runBlocking {
        val invocation = Invocation()
        val result = with(invocation) { start {
            // Mirrors the engine bridge's exception-to-failure mapping.
            try { error("bootstrap") } catch (_: Exception) { lifecycle.onComplete("failure") }
        } }
        assertEquals("failure", result.await())
        invocation.assertClosed()
    }

    @Test fun throwingBootstrapStillRunsFinally() = runBlocking {
        supervisorScope {
            val invocation = Invocation()
            val result = with(invocation) { start { error("bootstrap") } }
            assertTrue(runCatching { result.await() }.exceptionOrNull() is IllegalStateException)
            invocation.assertClosed()
        }
    }

    @Test fun cancellationBeforeReadyRejectsLateCallbacks() = runBlocking {
        val invocation = Invocation()
        val result = with(invocation) { start() }
        result.cancelAndJoin()
        invocation.ready()
        invocation.lifecycle.onComplete("success")
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMinutes(2))
        assertEquals(listOf("created", "destroyed"), invocation.events)
        invocation.assertClosed()
    }

    @Test fun cancellationAfterReadyBeforeAuthorizationCannotAcquire() = runBlocking {
        val invocation = Invocation()
        val result = with(invocation) { start() }
        invocation.ready()
        assertEquals(BackgroundSyncLifecycle.State.READY, invocation.lifecycle.state)
        result.cancelAndJoin() // Cancel before the queued continuation authorizes Dart.
        assertEquals(listOf("created", "destroyed"), invocation.events)
        invocation.assertClosed()
    }

    @Test fun activeCancellationDrainsAndIgnoresStartupDeadline() = runBlocking {
        val invocation = Invocation()
        val result = with(invocation) { start() }
        invocation.ready()
        yield()
        assertNotNull(invocation.lease)
        result.cancel()
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMinutes(2))
        yield()
        assertFalse(result.isCompleted)
        assertEquals(0, invocation.destroys)
        invocation.complete()
        result.join()
        invocation.assertClosed()
        assertEquals(listOf("created", "authorized", "acquired", "released", "destroyed"), invocation.events)
    }

    @Test fun resultAndCancellationBothOrderingsCompleteOnce() = runBlocking {
        for (cancelFirst in listOf(false, true)) {
            val invocation = Invocation()
            val result = with(invocation) { start() }
            invocation.ready()
            yield()
            if (cancelFirst) result.cancel()
            invocation.complete()
            if (!cancelFirst) result.cancel()
            result.join()
            invocation.lifecycle.onComplete("retry")
            invocation.assertClosed()
        }
    }

    @Test fun staleEngineCannotCompleteNextInvocation() = runBlocking {
        val old = Invocation()
        val first = with(old) { start() }
        old.ready()
        yield()
        old.complete()
        first.await()
        old.assertClosed()
        val next = Invocation()
        val second = with(next) { start() }
        old.ready()
        old.lifecycle.onComplete("retry")
        yield()
        assertFalse(second.isCompleted)
        assertEquals(BackgroundSyncLifecycle.State.STARTING, next.lifecycle.state)
        second.cancelAndJoin()
        next.assertClosed()
    }

    @Test fun authorizedButNeverAcquiringStillTimesOutAndCannotAcquireLater() = runBlocking {
        val invocation = Invocation()
        val result = with(invocation) { start() }
        invocation.lifecycle.onReady { assertTrue(it) }
        yield()
        assertEquals(BackgroundSyncLifecycle.State.AUTHORIZED, invocation.lifecycle.state)
        try {
            shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMinutes(1))
            yield()
            assertTrue(result.isCompleted)
            assertEquals("failure", result.await())
            invocation.assertClosed()
        } finally { result.cancelAndJoin() }
    }

    @Test fun cancellationAfterAuthorizationBeforeAcquireClosesAdmission() = runBlocking {
        val invocation = Invocation()
        val result = with(invocation) { start() }
        invocation.lifecycle.onReady { assertTrue(it) }
        yield()
        result.cancelAndJoin()
        invocation.assertClosed()
    }

    @Test fun releasedGateWithMissingCompletionHasBoundedCleanup() = runBlocking {
        val invocation = Invocation()
        val result = with(invocation) { start() }
        invocation.ready()
        yield()
        assertTrue(SyncExecutionGate.release(invocation.client, invocation.lease!!))
        invocation.lease = null
        invocation.lifecycle.onReleased()
        assertFalse(invocation.lifecycle.onAcquire())
        try {
            shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMinutes(1))
            yield()
            assertTrue(result.isCompleted)
            assertEquals("failure", result.await())
            invocation.assertClosed()
        } finally { result.cancelAndJoin() }
    }

    @Test fun prematureCompletionCannotDestroyAnActiveOwner() = runBlocking {
        val invocation = Invocation()
        val result = with(invocation) { start() }
        invocation.ready()
        yield()
        invocation.lifecycle.onComplete("failure")
        yield()
        assertFalse(result.isCompleted)
        assertEquals(0, invocation.destroys)
        invocation.complete()
        assertEquals("success", result.await())
        invocation.assertClosed()
    }
}
