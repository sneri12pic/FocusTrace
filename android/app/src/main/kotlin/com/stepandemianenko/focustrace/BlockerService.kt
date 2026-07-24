package com.stepandemianenko.focustrace

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import kotlin.math.absoluteValue

class BlockerService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private val tickRunnable = object : Runnable {
        override fun run() {
            tick()
            handler.postDelayed(this, POLL_INTERVAL_MS)
        }
    }

    private lateinit var windowManager: WindowManager
    private var rules: List<RestrictionRule> = emptyList()
    private var overlayView: View? = null
    private var overlayAppKey: String? = null
    private var dayKey: String = ""
    private val warnedDailyLimitKeys = mutableSetOf<String>()

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        createNotificationChannels()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        rules = loadRules()
        if (rules.isEmpty()) {
            stopSelf()
            return START_NOT_STICKY
        }
        dayKey = currentDayKey()
        startForegroundCompat()
        handler.removeCallbacks(tickRunnable)
        handler.post(tickRunnable)
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(tickRunnable)
        removeOverlay()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun tick() {
        val latestRules = loadRules()
        if (latestRules.isEmpty()) {
            stopSelf()
            return
        }
        rules = latestRules

        val currentDay = currentDayKey()
        if (currentDay != dayKey) {
            dayKey = currentDay
            warnedDailyLimitKeys.clear()
        }

        if (!FocusTracePermissions.hasOverlayPermission(this) ||
            !FocusTracePermissions.hasUsageAccess(this)
        ) {
            removeOverlay()
            return
        }

        val packageNames = rules.map { it.appKey }.toSet()
        val now = System.currentTimeMillis()
        val usageSeconds = todayUsageSeconds(packageNames, now)
        maybeNotifyDailyLimitWarnings(usageSeconds, now)

        val foregroundPackage = currentForegroundPackage(now)

        // Our own block screen (TikTok path) is foreground while active.
        if (foregroundPackage == null || foregroundPackage == packageName) {
            removeOverlay()
            return
        }

        val appRules = rules.filter { it.appKey == foregroundPackage }
        val blockingRule = appRules.firstOrNull {
            RestrictionRules.isBlocked(
                it,
                now,
                usageSeconds[it.appKey] ?: 0L,
            )
        }
        if (blockingRule == null) {
            removeOverlay()
            return
        }

        val untilMs = RestrictionRules.blockedUntilMs(
            blockingRule,
            now,
            usageSeconds[blockingRule.appKey] ?: 0L,
        )
        if (foregroundPackage in TIKTOK_PACKAGES) {
            // TikTok autoplays video; only a real foreground activity pauses it.
            removeOverlay()
            BlockActivity.start(
                this,
                appKey = foregroundPackage,
                appName = blockingRule.appName,
                reason = reasonFor(blockingRule),
                untilMs = untilMs,
            )
        } else {
            showOverlay(
                appKey = foregroundPackage,
                appName = blockingRule.appName,
                reason = reasonFor(blockingRule),
                untilMs = untilMs,
            )
        }
    }

    private fun loadRules(): List<RestrictionRule> {
        val json = getSharedPreferences(RestrictionRules.PREFS_NAME, Context.MODE_PRIVATE)
            .getString(RestrictionRules.PREFS_RULES_KEY, null)
        val now = System.currentTimeMillis()
        return RestrictionRules.parseRules(json).filter {
            it.type != RestrictionRuleType.BlockNow ||
                (it.untilMs != null && it.untilMs > now)
        }
    }

    @Suppress("DEPRECATION")
    private fun todayUsageSeconds(packageNames: Set<String>, now: Long): Map<String, Long> {
        if (packageNames.isEmpty()) return emptyMap()
        return UsageStats.foregroundTotals(
            this,
            UsageStats.startOfTodayMillis(),
            now,
            packageNames,
        ).mapValues { it.value.totalMs / 1000L }
    }

    private fun currentForegroundPackage(now: Long): String? {
        return UsageStats.currentForegroundPackage(
            this,
            UsageStats.startOfTodayMillis(),
            now,
        )
    }

    private fun maybeNotifyDailyLimitWarnings(
        usageSeconds: Map<String, Long>,
        now: Long,
    ) {
        for (rule in rules) {
            if (rule.type != RestrictionRuleType.DailyLimit) continue
            val limitSeconds = (rule.limitMinutes ?: continue) * 60L
            val usedSeconds = usageSeconds[rule.appKey] ?: 0L
            val remainingSeconds = limitSeconds - usedSeconds
            val key = "${dayKey}:${rule.appKey}:${rule.limitMinutes}"
            if (remainingSeconds in 1..WARNING_LEAD_SECONDS &&
                !warnedDailyLimitKeys.contains(key)
            ) {
                warnedDailyLimitKeys.add(key)
                showWarningNotification(rule, remainingSeconds, now)
            }
        }
    }

    private fun showWarningNotification(
        rule: RestrictionRule,
        remainingSeconds: Long,
        now: Long,
    ) {
        val minutes = (remainingSeconds / 60L).coerceAtLeast(1L)
        val notification = notificationBuilder(WARNING_CHANNEL_ID)
            .setContentTitle(
                FocusTraceLocale.getString(
                    this,
                    R.string.restriction_warning_title,
                    rule.appName,
                )
            )
            .setContentText(
                FocusTraceLocale.getQuantityString(
                    this,
                    R.plurals.restriction_warning_minutes,
                    minutes.toInt(),
                    minutes,
                )
            )
            .setSmallIcon(R.drawable.ic_launcher)
            .setWhen(now)
            .setAutoCancel(true)
            .build()

        try {
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .notify(WARNING_NOTIFICATION_BASE_ID + rule.appKey.hashCode().absoluteValue, notification)
        } catch (_: SecurityException) {
            // Android 13+ may deny POST_NOTIFICATIONS; blocking still works.
        }
    }

    private fun showOverlay(
        appKey: String,
        appName: String,
        reason: String,
        untilMs: Long?,
    ) {
        if (overlayView != null && overlayAppKey == appKey) return
        removeOverlay()
        if (!FocusTracePermissions.hasOverlayPermission(this)) return

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(48, 48, 48, 48)
            setBackgroundColor(Color.argb(244, 7, 10, 16))
        }

        val icon = ImageView(this).apply {
            try {
                setImageDrawable(packageManager.getApplicationIcon(appKey))
            } catch (_: Exception) {
                setImageResource(R.drawable.ic_launcher)
            }
            adjustViewBounds = true
            maxWidth = 128
            maxHeight = 128
        }
        root.addView(icon)

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
                    this@BlockerService,
                    R.string.restriction_until,
                    clock(untilMs),
                )
                setTextColor(Color.rgb(156, 169, 190))
                textSize = 14f
                gravity = Gravity.CENTER
                setPadding(0, 8, 0, 24)
            })
        }
        root.addView(
            Button(this).apply {
                text = FocusTraceLocale.getString(
                    this@BlockerService,
                    R.string.restriction_leave,
                )
                setOnClickListener {
                    startActivity(
                        Intent(Intent.ACTION_MAIN)
                            .addCategory(Intent.CATEGORY_HOME)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                    removeOverlay()
                }
            },
            LinearLayout.LayoutParams(
                resources.displayMetrics.widthPixels / 2,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply { gravity = Gravity.CENTER_HORIZONTAL },
        )

        val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            overlayType,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.CENTER
        }

        try {
            windowManager.addView(root, params)
            overlayView = root
            overlayAppKey = appKey
        } catch (_: Exception) {
            overlayView = null
            overlayAppKey = null
        }
    }

    private fun removeOverlay() {
        val view = overlayView ?: return
        try {
            windowManager.removeView(view)
        } catch (_: Exception) {
        } finally {
            overlayView = null
            overlayAppKey = null
        }
    }

    private fun startForegroundCompat() {
        val notification = notificationBuilder(SERVICE_CHANNEL_ID)
            .setContentTitle(
                FocusTraceLocale.getString(
                    this,
                    R.string.restriction_service_notification_title,
                )
            )
            .setContentText(
                FocusTraceLocale.getString(
                    this,
                    R.string.restriction_service_notification_body,
                )
            )
            .setSmallIcon(R.drawable.ic_launcher)
            .setOngoing(true)
            .build()

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(
                    SERVICE_NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
                )
            } else {
                startForeground(SERVICE_NOTIFICATION_ID, notification)
            }
        } catch (_: SecurityException) {
            stopSelf()
        }
    }

    private fun notificationBuilder(channelId: String): Notification.Builder {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val notificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.createNotificationChannel(
            NotificationChannel(
                SERVICE_CHANNEL_ID,
                FocusTraceLocale.getString(
                    this,
                    R.string.restriction_service_channel_name,
                ),
                NotificationManager.IMPORTANCE_MIN,
            ).apply {
                setShowBadge(false)
            }
        )
        notificationManager.createNotificationChannel(
            NotificationChannel(
                WARNING_CHANNEL_ID,
                FocusTraceLocale.getString(
                    this,
                    R.string.restriction_warning_channel_name,
                ),
                NotificationManager.IMPORTANCE_DEFAULT,
            )
        )
    }

    private fun reasonFor(rule: RestrictionRule): String {
        return when (rule.type) {
            RestrictionRuleType.BlockNow -> FocusTraceLocale.getString(
                this,
                R.string.restriction_reason_block_now,
            )
            RestrictionRuleType.DailyLimit -> FocusTraceLocale.getString(
                this,
                R.string.restriction_reason_daily_limit,
            )
            RestrictionRuleType.Schedule -> FocusTraceLocale.getString(
                this,
                R.string.restriction_reason_schedule,
            )
            RestrictionRuleType.RoutineBlock -> FocusTraceLocale.getString(
                this,
                R.string.restriction_reason_routine,
            )
        }
    }

    private fun clock(ms: Long): String {
        return SimpleDateFormat("HH:mm", Locale.getDefault()).format(ms)
    }

    private fun currentDayKey(): String {
        val calendar = Calendar.getInstance()
        return "${calendar.get(Calendar.YEAR)}-${calendar.get(Calendar.DAY_OF_YEAR)}"
    }

    private companion object {
        const val POLL_INTERVAL_MS = 1000L
        const val WARNING_LEAD_SECONDS = 5 * 60L
        const val SERVICE_CHANNEL_ID = "focustrace_restriction_service"
        const val WARNING_CHANNEL_ID = "focustrace_restriction_warnings"
        const val SERVICE_NOTIFICATION_ID = 7301
        const val WARNING_NOTIFICATION_BASE_ID = 7400
        val TIKTOK_PACKAGES = setOf(
            "com.zhiliaoapp.musically",
            "com.ss.android.ugc.trill",
        )
    }
}
