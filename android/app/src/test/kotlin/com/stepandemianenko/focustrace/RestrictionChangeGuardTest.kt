package com.stepandemianenko.focustrace

import android.content.Context
import org.robolectric.RuntimeEnvironment
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.util.Calendar

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class RestrictionChangeGuardTest {
    private val prefs get() = RuntimeEnvironment.getApplication()
        .getSharedPreferences("guard-test", Context.MODE_PRIVATE)
    @Before fun reset() { prefs.edit().clear().commit() }
    private fun rule(mode: String) = RestrictionRule("app", "App",
        RestrictionRuleType.BlockNow, untilMs = 1_000_000L, difficulty = mode)

    @Test fun easyHasNoNativeWaitAfterUiConfirmation() {
        val guard = RestrictionChangeGuard(prefs)
        assertEquals("allowed", guard.check(rule("easy"), 1000L, 0, request = true))
        assertEquals("allowed", guard.check(rule("easy"), 1001L, 0))
    }

    @Test fun cooldownSurvivesNewGuardAndDoesNotRestartOnRepeatedRequests() {
        val rule = rule("moderate")
        assertEquals("cooldown", RestrictionChangeGuard(prefs).check(rule, 1000L, 0, true))
        assertEquals("cooldown", RestrictionChangeGuard(prefs).check(rule, 2000L, 0, true))
        assertEquals("cooldown", RestrictionChangeGuard(prefs).check(rule, 300999L, 0))
        assertEquals("allowed", RestrictionChangeGuard(prefs).check(rule, 301000L, 0))
        assertEquals("cooldown", RestrictionChangeGuard(prefs).check(rule.copy(untilMs = 2_000_000L), 302000L, 0))
    }

    @Test fun hardCannotBeChangedUntilBlockEnds() {
        val guard = RestrictionChangeGuard(prefs)
        assertEquals("hard", guard.check(rule("hard"), 1000L, 0, true))
        assertEquals("allowed", guard.check(rule("hard"), 1_000_000L, 0))
    }

    @Test fun dailyCooldownCannotCarryAcrossMidnight() {
        val rule = RestrictionRule("app", "App", RestrictionRuleType.DailyLimit,
            limitMinutes = 1, difficulty = "moderate")
        val now = Calendar.getInstance().apply { set(2026, 9, 16, 12, 0, 0); set(Calendar.MILLISECOND, 0) }.timeInMillis
        val guard = RestrictionChangeGuard(prefs)
        assertEquals("allowed", guard.check(rule, now, 59))
        assertEquals("cooldown", guard.check(rule, now, 60, true))
        assertEquals("allowed", guard.check(rule, now + 300000, 60))
        assertEquals("cooldown", guard.check(rule, now + 86400000, 60))
    }

    @Test fun overnightTailUsesPreviousSelectedWeekday() {
        val rule = RestrictionRule("app", "App", RestrictionRuleType.Schedule,
            startMinute = 21 * 60, endMinute = 7 * 60, weekdays = listOf(5), difficulty = "hard")
        fun at(day: Int, hour: Int) = Calendar.getInstance().apply {
            set(2026, 9, day, hour, 0, 0); set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        assertFalse(RestrictionRules.isBlocked(rule, at(16, 6), 0))
        assertTrue(RestrictionRules.isBlocked(rule, at(16, 21), 0))
        assertTrue(RestrictionRules.isBlocked(rule, at(17, 6), 0))
        assertFalse(RestrictionRules.isBlocked(rule, at(17, 7), 0))
        assertFalse(RestrictionRules.isBlocked(rule, at(17, 21), 0))
    }
}
