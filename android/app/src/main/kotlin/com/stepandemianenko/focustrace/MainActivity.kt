package com.stepandemianenko.focustrace

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        UsageSnapshotScheduler.schedule(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasUsageAccess" -> result.success(hasUsageAccess())
                    "hasOverlayPermission" -> result.success(
                        FocusTracePermissions.hasOverlayPermission(this)
                    )
                    "openUsageAccessSettings" -> {
                        openUsageAccessSettings()
                        result.success(null)
                    }
                    "openOverlaySettings" -> {
                        openOverlaySettings()
                        result.success(null)
                    }
                    "requestNotificationsPermission" -> {
                        requestNotificationsPermission()
                        result.success(null)
                    }
                    "setAppLocale" -> {
                        setAppLocale(call.arguments as? String)
                        result.success(null)
                    }
                    "syncRestrictions" -> {
                        syncRestrictions(call.arguments as? String ?: "")
                        result.success(null)
                    }
                    "getAppMetadata" -> {
                        val packageNames = (call.arguments as? List<*>)
                            ?.filterIsInstance<String>()
                            .orEmpty()
                        Thread {
                            try {
                                val apps = getAppMetadata(packageNames)
                                runOnUiThread { result.success(apps) }
                            } catch (e: Exception) {
                                Log.e(LOG_TAG, "getAppMetadata failed", e)
                                runOnUiThread {
                                    result.error(
                                        "APP_METADATA_FAILED",
                                        e.message,
                                        null
                                    )
                                }
                            }
                        }.start()
                    }
                    "getInstalledApps" -> {
                        // Icon encoding for every launchable app is too slow
                        // for the main thread.
                        Thread {
                            try {
                                val apps = getInstalledApps()
                                runOnUiThread { result.success(apps) }
                            } catch (e: Exception) {
                                Log.e(LOG_TAG, "getInstalledApps failed", e)
                                runOnUiThread {
                                    result.error(
                                        "INSTALLED_APPS_FAILED",
                                        e.message,
                                        null
                                    )
                                }
                            }
                        }.start()
                    }
                    "getTodayUsageStats" -> {
                        if (!hasUsageAccess()) {
                            result.error(
                                "USAGE_ACCESS_DENIED",
                                FocusTraceLocale.getString(this, R.string.usage_access_denied),
                                null
                            )
                        } else {
                            // Event parsing plus icon encoding takes ~1s cold;
                            // keep it off the main thread.
                            Thread {
                                try {
                                    val stats = getTodayUsageStats()
                                    runOnUiThread { result.success(stats) }
                                } catch (e: Exception) {
                                    Log.e(LOG_TAG, "getTodayUsageStats failed", e)
                                    runOnUiThread {
                                        result.error("USAGE_STATS_FAILED", e.message, null)
                                    }
                                }
                            }.start()
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Suppress("DEPRECATION")
    private fun hasUsageAccess(): Boolean {
        return FocusTracePermissions.hasUsageAccess(this)
    }

    // The two special-access permissions live on separate system screens with
    // no combined grant. Instead we chain them: after opening one, arm the other
    // so it opens automatically when the user returns (see onResume). One-shot,
    // so backing out without granting just ends the flow.
    private var pendingPermission: String? = null

    private fun openUsageAccessSettings(chainOverlay: Boolean = true) {
        if (chainOverlay && !FocusTracePermissions.hasOverlayPermission(this)) {
            pendingPermission = "overlay"
        }
        val usageSettingsIntent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

        try {
            startActivity(usageSettingsIntent)
        } catch (_: ActivityNotFoundException) {
            startActivity(
                Intent(Settings.ACTION_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        }
    }

    private fun openOverlaySettings(chainUsage: Boolean = true) {
        if (chainUsage && !hasUsageAccess()) {
            pendingPermission = "usage"
        }
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:$packageName")
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

        try {
            startActivity(intent)
        } catch (_: ActivityNotFoundException) {
            startActivity(
                Intent(Settings.ACTION_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        }
    }

    override fun onResume() {
        super.onResume()
        val next = pendingPermission ?: return
        pendingPermission = null
        when (next) {
            "usage" -> if (!hasUsageAccess()) openUsageAccessSettings(chainOverlay = false)
            "overlay" -> if (!FocusTracePermissions.hasOverlayPermission(this)) {
                openOverlaySettings(chainUsage = false)
            }
        }
    }

    private fun requestNotificationsPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATION_PERMISSION_REQUEST_CODE
            )
        }
    }

    private fun setAppLocale(languageTag: String?) {
        if (!FocusTraceLocale.setLanguageTag(this, languageTag)) return

        UsageWidgetProvider.refreshAll(this)

        // Recreate the service so an existing overlay and foreground
        // notification immediately use the newly selected language.
        val json = getSharedPreferences(RestrictionRules.PREFS_NAME, Context.MODE_PRIVATE)
            .getString(RestrictionRules.PREFS_RULES_KEY, null)
            ?: ""
        stopService(Intent(this, BlockerService::class.java))
        syncRestrictions(json)
    }

    private fun syncRestrictions(json: String) {
        getSharedPreferences(RestrictionRules.PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(RestrictionRules.PREFS_RULES_KEY, json)
            .apply()

        val serviceIntent = Intent(this, BlockerService::class.java)
        if (
            RestrictionRules.hasRules(json) &&
            FocusTracePermissions.hasOverlayPermission(this) &&
            hasUsageAccess()
        ) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }
        } else {
            stopService(serviceIntent)
        }
    }

    private fun getTodayUsageStats(): List<Map<String, Any?>> {
        val startOfToday = UsageStats.startOfTodayMillis()
        return UsageStats.todayTotals(this)
            .map { (packageName, usage) ->
                mapOf(
                    "packageName" to packageName,
                    "appName" to appLabelFor(packageName),
                    "iconBytes" to appIconFor(packageName),
                    "totalTimeInForegroundMs" to usage.totalMs,
                    "launchCount" to usage.launchCount,
                    "firstTimeStampMs" to startOfToday,
                    "lastTimeStampMs" to usage.lastUsedMs,
                    "lastTimeUsedMs" to usage.lastUsedMs
                )
            }
            .sortedByDescending { it["totalTimeInForegroundMs"] as Long }
    }

    private fun isUserFacingApp(packageName: String): Boolean {
        return UsageStats.isUserFacingApp(this, packageName)
    }

    @Suppress("DEPRECATION")
    private fun getAppMetadata(
        packageNames: List<String>
    ): List<Map<String, Any?>> {
        return packageNames.distinct().mapNotNull { pkg ->
            try {
                packageManager.getApplicationInfo(pkg, 0)
                mapOf(
                    "packageName" to pkg,
                    "appName" to appLabelFor(pkg),
                    "iconBytes" to appIconFor(pkg)
                )
            } catch (_: PackageManager.NameNotFoundException) {
                null
            }
        }
    }

    /** All launchable apps: popular apps first, then the rest by label. */
    @Suppress("DEPRECATION")
    private fun getInstalledApps(): List<Map<String, Any?>> {
        val popular = listOf(
            "com.zhiliaoapp.musically",
            "com.instagram.android",
            "com.google.android.youtube",
            "com.discord",
            "org.telegram.messenger",
            "com.whatsapp",
            "com.snapchat.android",
            "com.facebook.katana",
            "com.twitter.android",
            "com.reddit.frontpage"
        )
        val launchable = packageManager.getInstalledApplications(0)
            .map { it.packageName }
            .filter { it != packageName && isUserFacingApp(it) }
        val popularFirst = popular.filter(launchable::contains)
        val rest = launchable
            .filterNot(popularFirst::contains)
            .sortedBy { appLabelFor(it).lowercase() }
        return (popularFirst + rest).map { pkg ->
            mapOf(
                "packageName" to pkg,
                "appName" to appLabelFor(pkg),
                "iconBytes" to appIconFor(pkg)
            )
        }
    }

    private val iconCache = HashMap<String, ByteArray?>()

    // Called from worker threads (usage stats, installed apps), so the cache
    // access must be synchronized. Encoded icons are also persisted to
    // cacheDir: cold app starts read ~1ms files instead of re-drawing and
    // PNG-encoding every icon (~1s for a day's worth of apps).
    // ponytail: stale if an app updates its icon; Android clears cacheDir under storage pressure anyway.
    private fun appIconFor(packageName: String): ByteArray? = synchronized(iconCache) {
        return iconCache.getOrPut(packageName) {
            val cacheFile = File(File(cacheDir, "app_icons"), "$packageName.png")
            try {
                if (cacheFile.exists()) {
                    return@getOrPut cacheFile.readBytes()
                }
            } catch (_: Exception) {
                // Unreadable cache entry: fall through and re-encode.
            }
            try {
                val drawable = packageManager.getApplicationIcon(packageName)
                val size = 128
                val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
                drawable.setBounds(0, 0, size, size)
                drawable.draw(Canvas(bitmap))
                val out = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
                bitmap.recycle()
                val bytes = out.toByteArray()
                try {
                    cacheFile.parentFile?.mkdirs()
                    cacheFile.writeBytes(bytes)
                } catch (_: Exception) {
                    // Cache write is best-effort.
                }
                bytes
            } catch (_: Exception) {
                null
            }
        }
    }

    private fun appLabelFor(packageName: String): String {
        return UsageStats.appLabelFor(this, packageName)
    }

    override fun onPause() {
        super.onPause()
        // The user is heading to the home screen; show them fresh numbers there.
        UsageWidgetProvider.refreshAll(this)
    }

    private companion object {
        const val CHANNEL_NAME = "focustrace/usage"
        const val LOG_TAG = "FocusTrace"
        const val NOTIFICATION_PERMISSION_REQUEST_CODE = 7104
    }
}
