package com.stepandemianenko.focustrace

import android.app.AppOpsManager
import android.app.Application
import android.content.Context
import android.content.Intent
import android.os.Process
import androidx.work.Configuration
import androidx.work.WorkManager
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowSettings

/**
 * The receiver's decision only: which broadcasts restart enforcement, and under
 * which rules and permissions. That Android actually delivers
 * MY_PACKAGE_REPLACED after an in-place upgrade needs a device.
 */
// Pinned to 35 like SyncInstallationMarkerTest: Robolectric 4.15.1's maximum.
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class BootReceiverTest {
    private val context: Application = RuntimeEnvironment.getApplication()

    @Before
    fun setUp() {
        // The receiver also keeps the usage snapshot schedule.
        if (!WorkManager.isInitialized()) {
            WorkManager.initialize(context, Configuration.Builder().build())
        }
        ShadowSettings.setCanDrawOverlays(true)
        usageAccess(AppOpsManager.MODE_ALLOWED)
        rules("""{"rules":[{"appKey":"a","appName":"A","type":"dailyLimit","limitMinutes":5}]}""")
    }

    @Test
    fun theManifestDeliversBootAndOwnUpdateToTheReceiver() {
        for (action in listOf(Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED)) {
            val receivers = context.packageManager.queryBroadcastReceivers(
                Intent(action).setPackage(context.packageName),
                0,
            )
            assertTrue(action, receivers.any { it.activityInfo.name == BootReceiver::class.java.name })
        }
    }

    @Test
    fun anUpdateRestartsEnforcementLikeABoot() {
        for (action in listOf(Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED)) {
            receive(action)
            assertEquals(action, BlockerService::class.java.name, startedService())
        }
    }

    @Test
    fun anUpdateWithoutRulesStartsNothing() {
        rules(null)
        receive(Intent.ACTION_MY_PACKAGE_REPLACED)
        assertNull(startedService())
    }

    @Test
    fun anUpdateWithoutOverlayPermissionStartsNothing() {
        ShadowSettings.setCanDrawOverlays(false)
        receive(Intent.ACTION_MY_PACKAGE_REPLACED)
        assertNull(startedService())
    }

    @Test
    fun anUpdateWithoutUsageAccessStartsNothing() {
        usageAccess(AppOpsManager.MODE_IGNORED)
        receive(Intent.ACTION_MY_PACKAGE_REPLACED)
        assertNull(startedService())
    }

    @Test
    fun otherBroadcastsStartNothing() {
        receive(Intent.ACTION_PACKAGE_REPLACED)
        assertNull(startedService())
    }

    private fun receive(action: String) = BootReceiver().onReceive(context, Intent(action))

    private fun startedService(): String? =
        shadowOf(context).nextStartedService?.component?.className

    private fun rules(json: String?) {
        context.getSharedPreferences(RestrictionRules.PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(RestrictionRules.PREFS_RULES_KEY, json)
            .commit()
    }

    private fun usageAccess(mode: Int) {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        shadowOf(appOps).setMode(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            context.packageName,
            mode,
        )
    }
}
