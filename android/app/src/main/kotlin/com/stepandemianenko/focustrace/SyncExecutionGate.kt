package com.stepandemianenko.focustrace

import java.util.ArrayDeque
import java.util.UUID

/** One logical sync/session operation per application process. No disk state. */
internal object SyncExecutionGate {
    class Client internal constructor() {
        internal var closed = false
    }

    private data class Request(
        val client: Client,
        val granted: (String) -> Unit,
        val lease: String = UUID.randomUUID().toString(),
    )

    private val waiting = ArrayDeque<Request>()
    private var active: Request? = null

    fun client() = Client()

    @Synchronized
    fun acquire(client: Client, granted: (String) -> Unit) {
        check(!client.closed)
        waiting.addLast(Request(client, granted))
        grantNext()
    }

    @Synchronized
    fun release(client: Client, lease: String): Boolean {
        val current = active ?: return false
        if (current.client !== client || current.lease != lease) return false
        active = null
        grantNext()
        return true
    }

    /** Call only after the engine's Dart execution has been destroyed. */
    @Synchronized
    fun close(client: Client) {
        client.closed = true
        waiting.removeAll { it.client === client }
        if (active?.client === client) active = null
        grantNext()
    }

    private fun grantNext() {
        while (active == null && waiting.isNotEmpty()) {
            val next = waiting.removeFirst()
            active = next
            try {
                next.granted(next.lease)
            } catch (_: RuntimeException) {
                // A dead messenger must not strand ownership or leak its error.
                active = null
            }
        }
    }
}
