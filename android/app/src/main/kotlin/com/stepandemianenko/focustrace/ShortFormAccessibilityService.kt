package com.stepandemianenko.focustrace

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.pm.ApplicationInfo
import android.graphics.Rect
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import com.stepandemianenko.focustrace.ShortFormDetector.Surface

/**
 * Blocks YouTube Shorts and Instagram Reels while the rest of each app stays
 * usable. Reads only which views are on screen in those two packages (set in
 * short_form_accessibility_service.xml); nothing is stored or sent anywhere
 * beyond the usual local blocked event.
 */
class ShortFormAccessibilityService : AccessibilityService() {
    private val handler = Handler(Looper.getMainLooper())
    private val configurationCache = RestrictionConfigurationCache()
    private val evaluateRunnable = Runnable {
        evaluationPending = false
        evaluate()
    }
    private var evaluationPending = false
    private var lastEvaluationMs = 0L
    private var actedAtMs = 0L
    private var blockedSurface: Surface? = null
    private var lastLoggedViewIds: String? = null

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            handler.removeCallbacks(evaluateRunnable)
            evaluationPending = false
            evaluate()
            return
        }
        // Content and scroll events arrive in bursts while video plays.
        if (evaluationPending) return
        val wait = THROTTLE_MS - (SystemClock.uptimeMillis() - lastEvaluationMs)
        if (wait <= 0L) {
            evaluate()
        } else {
            evaluationPending = true
            handler.postDelayed(evaluateRunnable, wait)
        }
    }

    override fun onInterrupt() = Unit

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    private fun evaluate() {
        val now = SystemClock.uptimeMillis()
        lastEvaluationMs = now
        if (isDebuggable()) logVisibleViewIds()
        if (now - actedAtMs < DEBOUNCE_MS) return
        val surface = currentSurface()
        val reasons = surface?.let {
            loadConfiguration().surfaceBlockReasons(it.appKey, System.currentTimeMillis())
        }.orEmpty()
        if (surface == null || reasons.isEmpty()) {
            blockedSurface = null
            return
        }

        val appName = reasons.first().rule?.appName ?: surface.displayName
        if (blockedSurface != surface) {
            blockedSurface = surface
            RestrictionEventStore.recordBlocked(
                this,
                appKey = surface.appKey,
                appName = appName,
                reason = reasons.first().eventName,
            )
        }

        actedAtMs = now
        performGlobalAction(GLOBAL_ACTION_BACK)
        // Back usually leaves the player; if the app swallowed it, cover it.
        handler.postDelayed({
            if (currentSurface() != surface) return@postDelayed
            BlockActivity.start(
                this,
                appKey = surface.parentPackage,
                appName = appName,
                reason = reasons.joinToString("\n") { blockReasonText(it) },
                untilMs = if (reasons.any { it.untilMs == null }) null else reasons.maxOf { it.untilMs!! },
                performance = null,
            )
        }, RECHECK_MS)
    }

    private fun currentSurface(): Surface? {
        val root = rootInActiveWindow ?: return null
        try {
            val packageName = root.packageName?.toString() ?: return null
            val metrics = resources.displayMetrics
            val minArea = metrics.widthPixels.toLong() * metrics.heightPixels * MIN_SCREEN_FRACTION
            val bounds = Rect()
            val large = ShortFormDetector.candidateViewIds(packageName).filterTo(mutableSetOf()) { id ->
                val nodes = root.findAccessibilityNodeInfosByViewId(id)
                val hit = nodes.any { node ->
                    node.getBoundsInScreen(bounds)
                    node.isVisibleToUser && bounds.width().toLong() * bounds.height() >= minArea
                }
                nodes.forEach(::recycle)
                hit
            }
            return ShortFormDetector.detect(packageName, large)
        } finally {
            recycle(root)
        }
    }

    private fun loadConfiguration(): RestrictionConfiguration {
        val json = getSharedPreferences(RestrictionRules.PREFS_NAME, Context.MODE_PRIVATE)
            .getString(RestrictionRules.PREFS_RULES_KEY, null)
        return configurationCache.at(json, System.currentTimeMillis())
    }

    private fun isDebuggable(): Boolean =
        applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0

    /**
     * Debug builds only, and only when the screen's ids change: the ids to put
     * in ShortFormDetector when an app update renames them.
     */
    private fun logVisibleViewIds() {
        val root = rootInActiveWindow ?: return
        val bounds = Rect()
        val ids = sortedSetOf<String>()
        fun walk(node: AccessibilityNodeInfo) {
            if (node.isVisibleToUser) {
                node.viewIdResourceName?.let {
                    node.getBoundsInScreen(bounds)
                    ids += "$it ${bounds.toShortString()}"
                }
            }
            for (index in 0 until node.childCount) {
                val child = node.getChild(index) ?: continue
                walk(child)
                recycle(child)
            }
        }
        walk(root)
        val line = "${root.packageName}: ${ids.joinToString()}"
        recycle(root)
        if (line == lastLoggedViewIds) return
        lastLoggedViewIds = line
        Log.d(LOG_TAG, line)
    }

    @Suppress("DEPRECATION")
    private fun recycle(node: AccessibilityNodeInfo) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) node.recycle()
    }

    private companion object {
        const val LOG_TAG = "FocusTraceShortForm"
        const val THROTTLE_MS = 300L
        const val DEBOUNCE_MS = 800L
        const val RECHECK_MS = 400L
        const val MIN_SCREEN_FRACTION = 0.6
    }
}
