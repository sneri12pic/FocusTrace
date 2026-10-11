package com.stepandemianenko.focustrace

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar

class RestrictionConfigurationCacheTest {
    private var parses = 0
    private val cache = RestrictionConfigurationCache { json ->
        parses++
        RestrictionRules.parseConfiguration(json)
    }

    @Test
    fun unchangedJsonIsParsedOnce() {
        val first = cache.at(DAILY_LIMIT, localMs(2026, 7, 4, 12, 0))
        val second = cache.at(DAILY_LIMIT, localMs(2026, 7, 4, 12, 1))

        assertEquals(1, parses)
        assertEquals(first, second)
        assertEquals(listOf("a"), second.rules.map { it.appKey })
    }

    @Test
    fun changedJsonIsUsedOnTheNextCall() {
        cache.at(DAILY_LIMIT, NOON)

        val changed = cache.at(DAILY_LIMIT.replace("\"a\"", "\"b\""), NOON)

        assertEquals(2, parses)
        assertEquals(listOf("b"), changed.rules.map { it.appKey })
    }

    @Test
    fun removedRulesAreEmptyOnTheNextCall() {
        cache.at(DAILY_LIMIT, NOON)

        assertTrue(cache.at(null, NOON).isEmpty)
        assertTrue(cache.at("", NOON).isEmpty)
    }

    @Test
    fun blockNowExpiresWithoutASettingsChange() {
        val until = localMs(2026, 7, 4, 14, 0)
        val json = rules("""{"appKey":"a","appName":"A","type":"blockNow","untilMs":$until}""")

        assertEquals(1, cache.at(json, until - 1).rules.size)
        assertTrue(cache.at(json, until).isEmpty)
        assertTrue(cache.at(json, until + 60_000).isEmpty)
        assertEquals(1, parses)
    }

    @Test
    fun schedulesAcrossMidnightFollowTheClockOnACachedConfiguration() {
        val json = rules(
            """{"appKey":"a","appName":"A","type":"schedule","startMinute":${22 * 60},"endMinute":${7 * 60}}""",
        )
        fun blockedAt(nowMs: Long) =
            RestrictionRules.isBlocked(cache.at(json, nowMs).rules.single(), nowMs, 0)

        assertFalse(blockedAt(localMs(2026, 7, 4, 21, 59)))
        assertTrue(blockedAt(localMs(2026, 7, 4, 23, 30)))
        assertTrue(blockedAt(localMs(2026, 7, 5, 6, 59)))
        assertFalse(blockedAt(localMs(2026, 7, 5, 7, 0)))
        assertEquals(1, parses)
    }

    @Test
    fun aDailyLimitRollsOverAtMidnightOnACachedConfiguration() {
        val beforeMidnight = localMs(2026, 7, 4, 23, 59)
        val afterMidnight = localMs(2026, 7, 5, 0, 1)
        val beforeRule = cache.at(DAILY_LIMIT, beforeMidnight).rules.single()
        val afterRule = cache.at(DAILY_LIMIT, afterMidnight).rules.single()

        assertEquals(
            localMs(2026, 7, 5, 0, 0),
            RestrictionRules.blockedUntilMs(beforeRule, beforeMidnight, 5 * 60L),
        )
        // The new day's usage (kept by the blocker's incremental state) starts at 0.
        assertFalse(RestrictionRules.isBlocked(afterRule, afterMidnight, 0))
        assertEquals(
            localMs(2026, 7, 6, 0, 0),
            RestrictionRules.blockedUntilMs(afterRule, afterMidnight, 5 * 60L),
        )
        assertEquals(1, parses)
    }

    private companion object {
        val NOON = localMs(2026, 7, 4, 12, 0)
        val DAILY_LIMIT = rules("""{"appKey":"a","appName":"A","type":"dailyLimit","limitMinutes":5}""")

        fun rules(vararg rows: String) = """{"version":3,"rules":[${rows.joinToString(",")}],"routines":[]}"""

        fun localMs(year: Int, month: Int, day: Int, hour: Int, minute: Int): Long =
            Calendar.getInstance().apply {
                clear()
                set(year, month - 1, day, hour, minute)
            }.timeInMillis
    }
}
