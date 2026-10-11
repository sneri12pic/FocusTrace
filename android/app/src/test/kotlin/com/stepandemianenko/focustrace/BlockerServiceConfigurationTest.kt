package com.stepandemianenko.focustrace

import android.content.Context
import android.os.Looper
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.android.controller.ServiceController
import org.robolectric.annotation.Config
import java.time.Duration

/**
 * The service's use of the parsed-rule cache: the stored rules are re-read every
 * tick, and a new service instance starts from what is stored now. Observed
 * through the service stopping itself when no rules remain.
 */
// Pinned to 35 like SyncInstallationMarkerTest: Robolectric 4.15.1's maximum.
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class BlockerServiceConfigurationTest {
    private val context: Context = RuntimeEnvironment.getApplication()

    @Test
    fun removedRulesStopTheServiceOnTheNextTick() {
        store(RULES)
        val service = started()
        tick()
        assertFalse(service.stoppedBySelf())

        store(null)
        tick()

        assertTrue(service.stoppedBySelf())
    }

    @Test
    fun anExpiredBlockNowStopsTheServiceWithoutASettingsChange() {
        val until = System.currentTimeMillis() + 1_500
        store("""{"rules":[{"appKey":"a","appName":"A","type":"blockNow","untilMs":$until}]}""")
        val service = started()
        tick()
        assertFalse(service.stoppedBySelf())

        // The tick reads the real clock, so wait past the block, then tick.
        Thread.sleep(until - System.currentTimeMillis() + 50)
        tick()

        assertTrue(service.stoppedBySelf())
    }

    @Test
    fun aRecreatedServiceLoadsTheCurrentStoredRules() {
        store(RULES)
        val first = started()
        tick()
        first.destroy()

        store(null)
        assertTrue(started().stoppedBySelf())

        store(RULES)
        assertFalse(started().stoppedBySelf())
    }

    private fun started(): ServiceController<BlockerService> =
        Robolectric.buildService(BlockerService::class.java).create().startCommand(0, 1)

    private fun ServiceController<BlockerService>.stoppedBySelf() =
        shadowOf(get()).isStoppedBySelf

    /** One polling interval of the main looper. */
    private fun tick() = shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(1))

    private fun store(json: String?) {
        context.getSharedPreferences(RestrictionRules.PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(RestrictionRules.PREFS_RULES_KEY, json)
            .commit()
    }

    private companion object {
        const val RULES = """{"rules":[{"appKey":"a","appName":"A","type":"dailyLimit","limitMinutes":5}]}"""
    }
}
