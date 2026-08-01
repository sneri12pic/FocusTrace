package com.stepandemianenko.focustrace

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar

class RestrictionRulesTest {
    @Test
    fun blockNowBlocksBeforeExpiryAndNotAtOrAfterExpiry() {
        val until = localMs(2026, 7, 4, 14, 0)
        val rule = RestrictionRule(
            appKey = "app",
            appName = "App",
            type = RestrictionRuleType.BlockNow,
            untilMs = until,
        )

        assertTrue(RestrictionRules.isBlocked(rule, localMs(2026, 7, 4, 13, 59), 0))
        assertFalse(RestrictionRules.isBlocked(rule, until, 0))
        assertFalse(RestrictionRules.isBlocked(rule, localMs(2026, 7, 4, 14, 1), 0))
    }

    @Test
    fun crossingMidnightScheduleBlocksInsideWindow() {
        val rule = RestrictionRule(
            appKey = "app",
            appName = "App",
            type = RestrictionRuleType.Schedule,
            startMinute = 22 * 60,
            endMinute = 7 * 60,
        )

        assertFalse(RestrictionRules.isBlocked(rule, localMs(2026, 7, 4, 21, 59), 0))
        assertTrue(RestrictionRules.isBlocked(rule, localMs(2026, 7, 4, 22, 0), 0))
        assertTrue(RestrictionRules.isBlocked(rule, localMs(2026, 7, 4, 23, 30), 0))
        assertTrue(RestrictionRules.isBlocked(rule, localMs(2026, 7, 5, 3, 0), 0))
        assertTrue(RestrictionRules.isBlocked(rule, localMs(2026, 7, 5, 6, 59), 0))
        assertFalse(RestrictionRules.isBlocked(rule, localMs(2026, 7, 5, 7, 0), 0))
        assertFalse(RestrictionRules.isBlocked(rule, localMs(2026, 7, 5, 12, 0), 0))
    }

    @Test
    fun nonCrossingScheduleBlocksInsideWindowOnly() {
        val rule = RestrictionRule(
            appKey = "app",
            appName = "App",
            type = RestrictionRuleType.Schedule,
            startMinute = 9 * 60,
            endMinute = 17 * 60,
        )

        assertFalse(RestrictionRules.isBlocked(rule, localMs(2026, 7, 4, 8, 59), 0))
        assertTrue(RestrictionRules.isBlocked(rule, localMs(2026, 7, 4, 9, 0), 0))
        assertTrue(RestrictionRules.isBlocked(rule, localMs(2026, 7, 4, 12, 0), 0))
        assertTrue(RestrictionRules.isBlocked(rule, localMs(2026, 7, 4, 16, 59), 0))
        assertFalse(RestrictionRules.isBlocked(rule, localMs(2026, 7, 4, 17, 0), 0))
    }

    @Test
    fun dailyLimitBlocksAtLimitAndNotOneSecondBefore() {
        val rule = RestrictionRule(
            appKey = "app",
            appName = "App",
            type = RestrictionRuleType.DailyLimit,
            limitMinutes = 60,
        )

        assertFalse(RestrictionRules.isBlocked(rule, localMs(2026, 7, 4, 12, 0), 60 * 60L - 1))
        assertTrue(RestrictionRules.isBlocked(rule, localMs(2026, 7, 4, 12, 0), 60 * 60L))
    }

    @Test
    fun jsonRoundTripAndGarbageDecode() {
        val json = """
            {
              "version": 1,
              "rules": [
                {"appKey":"one","appName":"One","type":"blockNow","untilMs":1783188000000},
                {"appKey":"two","appName":"Two","type":"dailyLimit","limitMinutes":45},
                {"appKey":"three","appName":"Three","type":"schedule","startMinute":1320,"endMinute":420}
              ]
            }
        """.trimIndent()

        val rules = RestrictionRules.parseRules(json)

        assertEquals(3, rules.size)
        assertEquals(RestrictionRuleType.BlockNow, rules[0].type)
        assertEquals(RestrictionRuleType.DailyLimit, rules[1].type)
        assertEquals(RestrictionRuleType.Schedule, rules[2].type)
        assertTrue(RestrictionRules.parseRules("not json").isEmpty())
    }

    @Test
    fun enabledRoutinePayloadCreatesAlwaysBlockingRules() {
        val json = """
            {
              "version": 2,
              "rules": [],
              "routineBlocks": [
                {"appKey":"com.example.social","appName":"Social"}
              ]
            }
        """.trimIndent()

        val rules = RestrictionRules.parseRules(json)

        assertEquals(1, rules.size)
        assertEquals(RestrictionRuleType.RoutineBlock, rules.single().type)
        assertTrue(RestrictionRules.isBlocked(rules.single(), localMs(2026, 7, 4, 12, 0), 0))
        assertEquals(null, RestrictionRules.blockedUntilMs(
            rules.single(),
            localMs(2026, 7, 4, 12, 0),
            0,
        ))
    }

    private fun localMs(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
    ): Long {
        return Calendar.getInstance().apply {
            set(Calendar.YEAR, year)
            set(Calendar.MONTH, month - 1)
            set(Calendar.DAY_OF_MONTH, day)
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
    }
}
