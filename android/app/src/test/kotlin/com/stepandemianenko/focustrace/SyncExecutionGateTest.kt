package com.stepandemianenko.focustrace

import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference
import org.junit.After
import org.junit.Assert.*
import org.junit.Test

class SyncExecutionGateTest {
    private val a = SyncExecutionGate.client()
    private val b = SyncExecutionGate.client()

    @After fun cleanUp() {
        SyncExecutionGate.close(a)
        SyncExecutionGate.close(b)
    }

    @Test fun anotherThreadQueuesWithoutEnteringUntilRelease() {
        var first = ""
        SyncExecutionGate.acquire(a) { first = it }
        val second = AtomicReference<String>()
        val queued = CountDownLatch(1)
        val contender = Thread {
            SyncExecutionGate.acquire(b) { second.set(it) }
            queued.countDown()
        }
        contender.start()
        assertTrue(queued.await(5, TimeUnit.SECONDS))
        assertNull(second.get())
        assertTrue(SyncExecutionGate.release(a, first))
        assertNotNull(second.get())
        contender.join()
    }

    @Test fun foreignOwnerCannotReleaseEvenWithTheCorrectLease() {
        var lease = ""
        var entered = false
        SyncExecutionGate.acquire(a) { lease = it }
        SyncExecutionGate.acquire(b) { entered = true }
        assertFalse(SyncExecutionGate.release(b, lease))
        assertFalse(entered)
        assertTrue(SyncExecutionGate.release(a, lease))
        assertTrue(entered)
    }

    @Test fun duplicateAndStaleReleaseCannotUnlockNewOwner() {
        var old = ""
        var current = ""
        SyncExecutionGate.acquire(a) { old = it }
        SyncExecutionGate.acquire(a) { current = it }
        assertTrue(SyncExecutionGate.release(a, old))
        assertNotEquals(old, current)
        assertFalse(SyncExecutionGate.release(a, old))
        var entered = false
        SyncExecutionGate.acquire(b) { entered = true }
        assertFalse(entered)
        assertTrue(SyncExecutionGate.release(a, current))
        assertTrue(entered)
    }

    @Test fun teardownDropsOwnersPendingRequestsAndGrantsNextClient() {
        SyncExecutionGate.acquire(a) { }
        var abandoned = false
        var next = false
        SyncExecutionGate.acquire(a) { abandoned = true }
        SyncExecutionGate.acquire(b) { next = true }
        SyncExecutionGate.close(a)
        assertFalse(abandoned)
        assertTrue(next)
        SyncExecutionGate.close(a)
        assertFalse(SyncExecutionGate.release(a, "stale"))
    }

    @Test fun queuedClientTeardownDoesNotReleaseActiveOwner() {
        var lease = ""
        SyncExecutionGate.acquire(a) { lease = it }
        SyncExecutionGate.acquire(b) { fail("destroyed waiter entered") }
        SyncExecutionGate.close(b)
        assertTrue(SyncExecutionGate.release(a, lease))
    }

    @Test fun failedGrantDoesNotWedgeGate() {
        SyncExecutionGate.acquire(a) { throw IllegalStateException() }
        var entered = false
        SyncExecutionGate.acquire(b) { entered = true }
        assertTrue(entered)
    }
}
