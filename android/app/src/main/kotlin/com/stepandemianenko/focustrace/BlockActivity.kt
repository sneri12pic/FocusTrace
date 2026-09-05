package com.stepandemianenko.focustrace

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import java.text.SimpleDateFormat
import java.util.Locale

/**
 * Full-screen block shown in place of the WindowManager overlay. Being a real
 * foreground activity, it pauses the blocked app (stopping autoplaying media)
 * and colors the status and navigation bars to match, which an overlay cannot.
 */
class BlockActivity : Activity() {
    @Suppress("DEPRECATION")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)
        window.statusBarColor = BACKGROUND_COLOR
        window.navigationBarColor = BACKGROUND_COLOR
        render()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        render()
    }

    // Back must not drop the user straight back into the blocked app.
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() = goHome()

    private fun render() {
        val appKey = intent.getStringExtra(EXTRA_APP_KEY).orEmpty()
        val appName = intent.getStringExtra(EXTRA_APP_NAME) ?: appKey
        val reason = intent.getStringExtra(EXTRA_REASON).orEmpty()
        val untilMs = intent.getLongExtra(EXTRA_UNTIL_MS, -1L).takeIf { it > 0L }

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(48, 48, 48, 48)
            setBackgroundColor(BACKGROUND_COLOR)
            fitsSystemWindows = true
        }

        root.addView(ImageView(this).apply {
            try {
                setImageDrawable(packageManager.getApplicationIcon(appKey))
            } catch (_: Exception) {
                setImageResource(R.drawable.ic_launcher)
            }
            adjustViewBounds = true
            maxWidth = 128
            maxHeight = 128
        })
        root.addView(TextView(this).apply {
            text = appName
            setTextColor(Color.WHITE)
            textSize = 24f
            gravity = Gravity.CENTER
            setPadding(0, 24, 0, 8)
        })
        root.addView(TextView(this).apply {
            text = reason
            setTextColor(Color.rgb(219, 226, 239))
            textSize = 16f
            gravity = Gravity.CENTER
        })
        if (untilMs != null) {
            root.addView(TextView(this).apply {
                text = FocusTraceLocale.getString(
                    this@BlockActivity,
                    R.string.restriction_until,
                    SimpleDateFormat("HH:mm", Locale.getDefault()).format(untilMs),
                )
                setTextColor(Color.rgb(156, 169, 190))
                textSize = 14f
                gravity = Gravity.CENTER
                setPadding(0, 8, 0, 24)
            })
        }
        root.addView(
            Button(this).apply {
                text = FocusTraceLocale.getString(this@BlockActivity, R.string.restriction_leave)
                setOnClickListener { goHome() }
            },
            LinearLayout.LayoutParams(
                resources.displayMetrics.widthPixels / 2,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply { gravity = Gravity.CENTER_HORIZONTAL },
        )

        setContentView(root)
        BlockerPerformance.logFirstDraw(root, performancePresentation())
    }

    private fun performancePresentation(): BlockerPerformance.Presentation? {
        val tickId = intent.getLongExtra(EXTRA_PERFORMANCE_TICK_ID, -1L)
        if (tickId < 0L) return null
        return BlockerPerformance.Presentation(
            tickId = tickId,
            action = BlockerPerformance.Action.BlockActivity,
            decisionAtNs = intent.getLongExtra(EXTRA_PERFORMANCE_DECISION_NS, -1L)
                .takeIf { it >= 0L },
            foregroundEventMs = intent.getLongExtra(EXTRA_PERFORMANCE_EVENT_MS, -1L)
                .takeIf { it >= 0L },
        )
    }

    private fun goHome() {
        startActivity(
            Intent(Intent.ACTION_MAIN)
                .addCategory(Intent.CATEGORY_HOME)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
        finish()
    }

    companion object {
        private const val EXTRA_APP_KEY = "app_key"
        private const val EXTRA_APP_NAME = "app_name"
        private const val EXTRA_REASON = "reason"
        private const val EXTRA_UNTIL_MS = "until_ms"
        private const val EXTRA_PERFORMANCE_TICK_ID = "performance_tick_id"
        private const val EXTRA_PERFORMANCE_DECISION_NS = "performance_decision_ns"
        private const val EXTRA_PERFORMANCE_EVENT_MS = "performance_event_ms"
        private const val BACKGROUND_COLOR = 0xFF070A10.toInt()

        internal fun start(
            context: Context,
            appKey: String,
            appName: String,
            reason: String,
            untilMs: Long?,
            performance: BlockerPerformance.Presentation?,
        ) {
            val intent = Intent(context, BlockActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                .putExtra(EXTRA_APP_KEY, appKey)
                .putExtra(EXTRA_APP_NAME, appName)
                .putExtra(EXTRA_REASON, reason)
                .putExtra(EXTRA_UNTIL_MS, untilMs ?: -1L)
            if (performance != null) {
                intent.putExtra(EXTRA_PERFORMANCE_TICK_ID, performance.tickId)
                    .putExtra(EXTRA_PERFORMANCE_DECISION_NS, performance.decisionAtNs ?: -1L)
                    .putExtra(EXTRA_PERFORMANCE_EVENT_MS, performance.foregroundEventMs ?: -1L)
            }
            context.startActivity(intent)
        }
    }
}
