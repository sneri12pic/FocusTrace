package com.stepandemianenko.focustrace

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        UsageSnapshotScheduler.schedule(context)

        val json = context
            .getSharedPreferences(RestrictionRules.PREFS_NAME, Context.MODE_PRIVATE)
            .getString(RestrictionRules.PREFS_RULES_KEY, null)
        if (!RestrictionRules.hasRules(json) ||
            !FocusTracePermissions.hasOverlayPermission(context) ||
            !FocusTracePermissions.hasUsageAccess(context)
        ) {
            return
        }

        val serviceIntent = Intent(context, BlockerService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}
