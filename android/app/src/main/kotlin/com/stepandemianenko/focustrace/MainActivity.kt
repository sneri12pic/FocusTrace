package com.stepandemianenko.focustrace

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ApplicationInfo
import android.graphics.Bitmap
import android.graphics.BitmapFactory
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
    private val dataTransferDocumentBridge by lazy {
        DataTransferDocumentBridge(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        UsageSnapshotScheduler.schedule(this)
        dataTransferDocumentBridge.configure(flutterEngine.dartExecutor.binaryMessenger)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasUsageAccess" -> result.success(hasUsageAccess())
                    "hasOverlayPermission" -> result.success(
                        FocusTracePermissions.hasOverlayPermission(this)
                    )
                    "hasNotificationsPermission" -> result.success(
                        hasNotificationsPermission()
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
                        requestNotificationsPermission(result)
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
                        val arguments = call.arguments as? Map<*, *>
                        val packageNames = ((arguments?.get("packageNames") as? List<*>)
                            ?: (call.arguments as? List<*>))
                            ?.filterIsInstance<String>()
                            .orEmpty()
                        val benchmarkRunId = (arguments?.get("benchmarkRunId") as? Number)?.toLong()
                        Thread {
                            try {
                                val apps = measuredAppMetadata(packageNames, benchmarkRunId)
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
                        val arguments = call.arguments as? Map<*, *>
                        val benchmarkRunId =
                            (arguments?.get("benchmarkRunId") as? Number)?.toLong()
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
                                    val stats = measuredTodayUsageStats(
                                        benchmarkRunId = benchmarkRunId,
                                        includeIcons = includeUsageIconsForBenchmark(),
                                    )
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
                    "getUsageIntervals" -> {
                        val arguments = call.arguments as? Map<*, *>
                        val fromMs = (arguments?.get("fromMs") as? Number)?.toLong()
                        val toMs = (arguments?.get("toMs") as? Number)?.toLong()
                        if (!hasUsageAccess()) {
                            result.error(
                                "USAGE_ACCESS_DENIED",
                                FocusTraceLocale.getString(this, R.string.usage_access_denied),
                                null,
                            )
                        } else if (fromMs == null || toMs == null || fromMs >= toMs) {
                            result.error("INVALID_RANGE", "A valid usage range is required.", null)
                        } else {
                            Thread {
                                try {
                                    val intervals = getUsageIntervals(fromMs, toMs)
                                    runOnUiThread { result.success(intervals) }
                                } catch (e: Exception) {
                                    Log.e(LOG_TAG, "getUsageIntervals failed", e)
                                    runOnUiThread {
                                        result.error("USAGE_INTERVALS_FAILED", e.message, null)
                                    }
                                }
                            }.start()
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Android; retained for the Storage Access Framework bridge.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (dataTransferDocumentBridge.onActivityResult(requestCode, resultCode, data)) {
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    @Suppress("DEPRECATION")
    private fun hasUsageAccess(): Boolean {
        return FocusTracePermissions.hasUsageAccess(this)
    }

    private fun openUsageAccessSettings() {
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

    private fun openOverlaySettings() {
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

    private var pendingNotificationPermissionResult: MethodChannel.Result? = null

    private fun hasNotificationsPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun requestNotificationsPermission(result: MethodChannel.Result) {
        if (hasNotificationsPermission()) {
            result.success(true)
            return
        }
        if (pendingNotificationPermissionResult != null) {
            result.error("NOTIFICATION_PERMISSION_PENDING", null, null)
            return
        }
        pendingNotificationPermissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST_CODE
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != NOTIFICATION_PERMISSION_REQUEST_CODE) return
        pendingNotificationPermissionResult?.success(hasNotificationsPermission())
        pendingNotificationPermissionResult = null
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
                    "metadataVersion" to appLastUpdateTimeFor(packageName),
                    "totalTimeInForegroundMs" to usage.totalMs,
                    "launchCount" to usage.launchCount,
                    "firstTimeStampMs" to startOfToday,
                    "lastTimeStampMs" to usage.lastUsedMs,
                    "lastTimeUsedMs" to usage.lastUsedMs
                )
            }
            .sortedByDescending { it["totalTimeInForegroundMs"] as Long }
    }

    private fun measuredTodayUsageStats(
        benchmarkRunId: Long?,
        includeIcons: Boolean,
    ): List<Map<String, Any?>> {
        val request = IconRequestMetrics()
        val startedNs = System.nanoTime()
        val startOfToday = UsageStats.startOfTodayMillis()
        val queryStartedNs = System.nanoTime()
        val totals = UsageStats.todayTotals(this)
        val queryUs = (System.nanoTime() - queryStartedNs) / 1_000
        val metadataStartedNs = System.nanoTime()
        val rows = totals.map { (packageName, usage) ->
            mapOf(
                "packageName" to packageName,
                "appName" to appLabelFor(packageName),
                "iconBytes" to if (includeIcons) appIconFor(packageName, request) else null,
                "metadataVersion" to appLastUpdateTimeFor(packageName),
                "totalTimeInForegroundMs" to usage.totalMs,
                "launchCount" to usage.launchCount,
                "firstTimeStampMs" to startOfToday,
                "lastTimeStampMs" to usage.lastUsedMs,
                "lastTimeUsedMs" to usage.lastUsedMs
            )
        }.sortedByDescending { it["totalTimeInForegroundMs"] as Long }
        val metadataUs = (System.nanoTime() - metadataStartedNs) / 1_000
        logNativeMetrics(
            event = "live_usage_payload",
            benchmarkRunId = benchmarkRunId,
            totalUs = (System.nanoTime() - startedNs) / 1_000,
            queryUs = queryUs,
            metadataUs = metadataUs,
            request = request,
            extra = "include_icons=$includeIcons",
        )
        return rows
    }

    private fun measuredAppMetadata(
        packageNames: List<String>,
        benchmarkRunId: Long?,
    ): List<Map<String, Any?>> {
        val request = IconRequestMetrics()
        val startedNs = System.nanoTime()
        val rows = packageNames.distinct().mapNotNull { pkg ->
            try {
                packageManager.getApplicationInfo(pkg, 0)
                mapOf(
                    "packageName" to pkg,
                    "appName" to appLabelFor(pkg),
                    "iconBytes" to appIconFor(pkg, request),
                    "metadataVersion" to appLastUpdateTimeFor(pkg),
                )
            } catch (_: PackageManager.NameNotFoundException) {
                request.missingPackages++
                null
            }
        }
        logNativeMetrics(
            event = "metadata_payload",
            benchmarkRunId = benchmarkRunId,
            totalUs = (System.nanoTime() - startedNs) / 1_000,
            queryUs = 0,
            metadataUs = (System.nanoTime() - startedNs) / 1_000,
            request = request,
        )
        return rows
    }

    private fun getUsageIntervals(
        fromMs: Long,
        toMs: Long,
    ): List<Map<String, Any?>> {
        val labels = HashMap<String, String>()
        return UsageStats.foregroundIntervals(this, fromMs, toMs).map { interval ->
            mapOf(
                "id" to "${interval.packageName}:${interval.startedAtMs}",
                "appKey" to interval.packageName,
                "appName" to labels.getOrPut(interval.packageName) {
                    appLabelFor(interval.packageName)
                },
                "startedAtMs" to interval.startedAtMs,
                "endedAtMs" to interval.endedAtMs,
            )
        }
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
                    "iconBytes" to appIconFor(pkg),
                    "metadataVersion" to appLastUpdateTimeFor(pkg),
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
                "iconBytes" to appIconFor(pkg),
                "metadataVersion" to appLastUpdateTimeFor(pkg),
            )
        }
    }

    private val iconCache = HashMap<String, ByteArray?>()

    // Called from worker threads (usage stats, installed apps), so the cache
    // access must be synchronized. Encoded icons are also persisted to
    // cacheDir: cold app starts read ~1ms files instead of re-drawing and
    // PNG-encoding every icon (~1s for a day's worth of apps). The package
    // update timestamp versions both memory and disk entries so app updates
    // regenerate once without turning derived icons into permanent user data.
    @Suppress("DEPRECATION")
    private fun appIconFor(
        packageName: String,
        request: IconRequestMetrics? = null,
    ): ByteArray? = synchronized(iconCache) {
        val lastUpdateTime = try {
            packageManager.getPackageInfo(packageName, 0).lastUpdateTime
        } catch (_: PackageManager.NameNotFoundException) {
            request?.missingPackages = request?.missingPackages?.plus(1) ?: 0
            return null
        }
        val memoryKey = "$packageName@$lastUpdateTime"
        if (iconCache.containsKey(memoryKey)) {
            request?.memoryHits = request?.memoryHits?.plus(1) ?: 0
            val bytes = iconCache[memoryKey]
            request?.payloadBytes = request?.payloadBytes?.plus(bytes?.size ?: 0) ?: 0
            return bytes
        }
        val value = run {
            val cacheDirectory = File(cacheDir, "app_icons")
            val cacheFile = File(cacheDirectory, "$packageName-$lastUpdateTime.png")
            try {
                if (cacheFile.exists()) {
                    val bytes = cacheFile.readBytes()
                    if (isPng(bytes)) {
                        request?.diskHits = request?.diskHits?.plus(1) ?: 0
                        request?.payloadBytes = request?.payloadBytes?.plus(bytes.size) ?: 0
                        return@run bytes
                    }
                    try {
                        cacheFile.delete()
                    } catch (_: Exception) {
                        // Best-effort derived-cache repair.
                    }
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
                val encoded = bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
                bitmap.recycle()
                if (!encoded) {
                    request?.failures = request?.failures?.plus(1) ?: 0
                    return@run null
                }
                val bytes = out.toByteArray()
                request?.regenerated = request?.regenerated?.plus(1) ?: 0
                request?.payloadBytes = request?.payloadBytes?.plus(bytes.size) ?: 0
                try {
                    cacheFile.parentFile?.mkdirs()
                    cacheFile.writeBytes(bytes)
                    cleanupObsoleteIconFiles(
                        cacheDirectory = cacheDirectory,
                        packageName = packageName,
                        currentFile = cacheFile,
                    )
                } catch (_: Exception) {
                    // Cache write is best-effort.
                }
                bytes
            } catch (_: Exception) {
                request?.failures = request?.failures?.plus(1) ?: 0
                null
            }
        }
        iconCache.keys.removeAll { key ->
            key.startsWith("$packageName@") && key != memoryKey
        }
        if (value != null) {
            iconCache[memoryKey] = value
        }
        value
    }

    private fun isPng(bytes: ByteArray): Boolean {
        val signature = byteArrayOf(
            0x89.toByte(), 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A
        )
        if (bytes.size < signature.size ||
            !signature.indices.all { index -> bytes[index] == signature[index] }
        ) {
            return false
        }
        return try {
            val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
            options.outWidth > 0 && options.outHeight > 0
        } catch (_: Exception) {
            false
        }
    }

    private fun cleanupObsoleteIconFiles(
        cacheDirectory: File,
        packageName: String,
        currentFile: File,
    ) {
        try {
            cacheDirectory.listFiles()?.forEach { candidate ->
                val isLegacy = candidate.name == "$packageName.png"
                val isOldVersion =
                    candidate.name.startsWith("$packageName-") && candidate != currentFile
                if (isLegacy || isOldVersion) {
                    candidate.delete()
                }
            }
        } catch (_: Exception) {
            // Obsolete derived files can be cleaned on a later regeneration.
        }
    }

    private fun logNativeMetrics(
        event: String,
        benchmarkRunId: Long?,
        totalUs: Long,
        queryUs: Long,
        metadataUs: Long,
        request: IconRequestMetrics,
        extra: String? = null,
    ) {
        // Dart supplies a run id only for debug benchmark runs.
        if (benchmarkRunId == null) return
        Log.i(
            DASHBOARD_NATIVE_PERF_TAG,
            listOf(
                event,
                benchmarkRunId,
                totalUs,
                "query_us=$queryUs",
                "metadata_us=$metadataUs",
                "icon_bytes=${request.payloadBytes}",
                "memory_hits=${request.memoryHits}",
                "disk_hits=${request.diskHits}",
                "regenerated=${request.regenerated}",
                "failures=${request.failures}",
                "missing_packages=${request.missingPackages}",
            ).let { parts ->
                if (extra == null) parts else parts + extra
            }.joinToString(","),
        )
    }

    private fun includeUsageIconsForBenchmark(): Boolean {
        val isDebuggable =
            applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
        if (!isDebuggable || !intent.hasExtra(BENCHMARK_INCLUDE_USAGE_ICONS_EXTRA)) {
            return true
        }
        return intent.getBooleanExtra(BENCHMARK_INCLUDE_USAGE_ICONS_EXTRA, true)
    }

    private data class IconRequestMetrics(
        var memoryHits: Int = 0,
        var diskHits: Int = 0,
        var regenerated: Int = 0,
        var failures: Int = 0,
        var missingPackages: Int = 0,
        var payloadBytes: Int = 0,
    )

    private fun appLabelFor(packageName: String): String {
        return UsageStats.appLabelFor(this, packageName)
    }

    @Suppress("DEPRECATION")
    private fun appLastUpdateTimeFor(packageName: String): Long? {
        return try {
            packageManager.getPackageInfo(packageName, 0).lastUpdateTime
        } catch (_: PackageManager.NameNotFoundException) {
            null
        }
    }

    override fun onPause() {
        super.onPause()
        // The user is heading to the home screen; show them fresh numbers there.
        UsageWidgetProvider.refreshAll(this)
    }

    private companion object {
        const val CHANNEL_NAME = "focustrace/usage"
        const val LOG_TAG = "FocusTrace"
        const val DASHBOARD_NATIVE_PERF_TAG = "FTDashboardNativePerf"
        const val BENCHMARK_INCLUDE_USAGE_ICONS_EXTRA =
            "benchmarkIncludeUsageIcons"
        const val NOTIFICATION_PERMISSION_REQUEST_CODE = 7104
    }
}
