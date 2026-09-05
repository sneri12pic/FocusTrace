package com.stepandemianenko.focustrace

import android.content.Context
import android.content.pm.ApplicationInfo
import android.os.SystemClock
import android.util.Log
import android.view.View
import java.util.concurrent.atomic.AtomicLong

internal object BlockerPerformance {
    const val LOG_TAG = "FocusTraceBlockerPerf"

    private val nextTickId = AtomicLong()

    fun startTick(context: Context): Tick? {
        val isDebuggable =
            context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
        return if (isDebuggable) Tick(nextTickId.incrementAndGet()) else null
    }

    class Tick internal constructor(
        val id: Long,
    ) {
        private val startedAtNs = SystemClock.elapsedRealtimeNanos()
        private var decisionAtNs: Long? = null
        private var eventToDecisionMs: Long? = null
        private var decisionDurationNs = 0L
        private var action = Action.None

        fun measureDecision(
            latestForegroundEventMs: Long?,
            decision: () -> Unit,
        ) {
            val startedAtNs = SystemClock.elapsedRealtimeNanos()
            decision()
            decisionAtNs = SystemClock.elapsedRealtimeNanos()
            decisionDurationNs += decisionAtNs!! - startedAtNs
            eventToDecisionMs = latestForegroundEventMs?.let {
                System.currentTimeMillis() - it
            }
        }

        fun presentation(action: Action, latestForegroundEventMs: Long?): Presentation {
            this.action = action
            return Presentation(
                tickId = id,
                action = action,
                decisionAtNs = decisionAtNs,
                foregroundEventMs = latestForegroundEventMs,
            )
        }

        fun finish(query: UsageStats.QueryMetrics?) {
            val finishedAtNs = SystemClock.elapsedRealtimeNanos()
            val latestForegroundEventMs = query?.latestForegroundEventMs
            val latestForegroundAgeMs = latestForegroundEventMs?.let {
                System.currentTimeMillis() - it
            }
            Log.i(
                LOG_TAG,
                listOf(
                    "tick",
                    id,
                    query?.queryCount ?: 0,
                    query?.eventsIterated ?: 0,
                    query?.queryFromMs ?: "",
                    query?.queryToMs ?: "",
                    query?.queryWindowMs ?: "",
                    query?.queryAndIterationNs ?: 0,
                    query?.aggregationNs ?: 0,
                    decisionDurationNs,
                    finishedAtNs - startedAtNs,
                    latestForegroundAgeMs ?: "",
                    eventToDecisionMs ?: "",
                    action.csvValue,
                ).joinToString(","),
            )
        }
    }

    data class Presentation(
        val tickId: Long,
        val action: Action,
        val decisionAtNs: Long?,
        val foregroundEventMs: Long?,
    )

    enum class Action(val csvValue: String) {
        None("none"),
        Overlay("overlay"),
        BlockActivity("block_activity"),
    }

    fun logFirstDraw(view: View, presentation: Presentation?) {
        if (presentation == null) return
        view.viewTreeObserver.addOnDrawListener(object : android.view.ViewTreeObserver.OnDrawListener {
            private var recorded = false

            override fun onDraw() {
                if (recorded) return
                recorded = true
                val presentedAtNs = SystemClock.elapsedRealtimeNanos()
                val decisionToPresentationNs = presentation.decisionAtNs?.let {
                    presentedAtNs - it
                }
                val eventToPresentationMs = presentation.foregroundEventMs?.let {
                    System.currentTimeMillis() - it
                }
                Log.i(
                    LOG_TAG,
                    listOf(
                        "presentation",
                        presentation.tickId,
                        presentation.action.csvValue,
                        decisionToPresentationNs ?: "",
                        eventToPresentationMs ?: "",
                    ).joinToString(","),
                )
                view.post {
                    if (view.viewTreeObserver.isAlive) {
                        view.viewTreeObserver.removeOnDrawListener(this)
                    }
                }
            }
        })
    }
}
