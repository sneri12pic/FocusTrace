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
    fun routinePayloadPreservesGroupingAndExcludesOptedOutApps() {
        val json = """
            {
              "version": 3,
              "rules": [],
              "routines": [
                {
                  "id":"focus",
                  "name":"Focus",
                  "isEnabled":true,
                  "dailyLimitMinutes":60,
                  "apps":[
                    {"appKey":"social","appName":"Social","isIncludedInLimit":true},
                    {"appKey":"music","appName":"Music","isIncludedInLimit":false}
                  ]
                }
              ]
            }
        """.trimIndent()

        val configuration = RestrictionRules.parseConfiguration(json)
        val routine = configuration.routines.single()

        assertEquals(setOf("social"), configuration.appKeys)
        assertFalse(routine.isReached(mapOf("social" to 3599L, "music" to 99999L)))
        assertTrue(routine.isReached(mapOf("social" to 3600L)))
        assertEquals(routine, configuration.blockingRoutine("social", mapOf("social" to 3600L)))
        assertEquals(null, configuration.blockingRoutine("music", mapOf("social" to 3600L)))
    }

    @Test
    fun appCapsAreCapsInsideTheSharedAllowance() {
        // Shared 2h; A capped at 45m, B at 1h, C uncapped.
        val json = """
            {"version":3,"rules":[],"routines":[{
              "id":"study","name":"Study time","isEnabled":true,"dailyLimitMinutes":120,
              "apps":[
                {"appKey":"a","appName":"A","limitMinutes":45},
                {"appKey":"b","appName":"B","limitMinutes":60},
                {"appKey":"c","appName":"C"}
              ]}]}
        """.trimIndent()
        val configuration = RestrictionRules.parseConfiguration(json)
        val now = localMs(2026, 10, 23, 15, 0)
        fun kinds(app: String, usage: Map<String, Long>) =
            configuration.blockReasons(app, now, usage).map { it.kind }

        // A reaches its cap: only A is blocked, shared time remains.
        val capped = mapOf("a" to 45 * 60L, "b" to 10 * 60L, "c" to 10 * 60L)
        assertEquals(listOf(BlockReason.Kind.RoutineApp), kinds("a", capped))
        assertTrue(kinds("b", capped).isEmpty())
        assertTrue(kinds("c", capped).isEmpty())

        // Caps do not reserve time: 30m + 40m + 50m exhausts the 2h share,
        // blocking every app although A and B are under their caps.
        val shared = mapOf("a" to 30 * 60L, "b" to 40 * 60L, "c" to 50 * 60L)
        assertEquals(listOf(BlockReason.Kind.RoutineShared), kinds("a", shared))
        assertEquals(listOf(BlockReason.Kind.RoutineShared), kinds("b", shared))
        assertEquals(listOf(BlockReason.Kind.RoutineShared), kinds("c", shared))
        assertEquals(120 * 60L, configuration.routines.single().usageSeconds(shared))
        assertEquals(RestrictionRules.startOfTomorrowMs(now), configuration.blockReasons("a", now, shared).single().untilMs)
    }

    @Test
    fun everyApplicableRestrictionIsReported() {
        val json = """
            {"version":3,
             "rules":[
               {"appKey":"a","appName":"A","type":"dailyLimit","limitMinutes":30},
               {"appKey":"a","appName":"A","type":"schedule","startMinute":840,"endMinute":960}
             ],
             "routines":[
               {"id":"r1","name":"One","isEnabled":true,"dailyLimitMinutes":20,
                "apps":[{"appKey":"a","appName":"A"}]},
               {"id":"r2","name":"Two","isEnabled":true,"dailyLimitMinutes":600,
                "apps":[{"appKey":"a","appName":"A","limitMinutes":10}]}
             ]}
        """.trimIndent()
        val configuration = RestrictionRules.parseConfiguration(json)
        val now = localMs(2026, 10, 23, 15, 0)
        val reasons = configuration.blockReasons("a", now, mapOf("a" to 40 * 60L))
        assertEquals(
            listOf(
                BlockReason.Kind.DailyLimit,
                BlockReason.Kind.Schedule,
                BlockReason.Kind.RoutineShared,
                BlockReason.Kind.RoutineApp,
            ),
            reasons.map { it.kind },
        )
        assertEquals(listOf("r1", "r2"), reasons.mapNotNull { it.routine?.id })
        assertEquals(localMs(2026, 10, 23, 16, 0), reasons[1].untilMs)
        // Under every limit and outside the schedule: nothing blocks.
        assertTrue(
            configuration.blockReasons("a", localMs(2026, 10, 23, 17, 0), mapOf("a" to 60L))
                .isEmpty()
        )
    }

    @Test
    fun legacyRoutineMembersHaveNoCap() {
        val json = """
            {"version":3,"rules":[],"routines":[{"id":"r","name":"R","isEnabled":true,
              "dailyLimitMinutes":60,"apps":[{"appKey":"a","appName":"A"}]}]}
        """.trimIndent()
        val routine = RestrictionRules.parseConfiguration(json).routines.single()
        assertEquals(null, routine.apps.single().limitMinutes)
        assertFalse(routine.isAppCapReached("a", mapOf("a" to 99_999L)))
    }

    @Test
    fun legacyFlatRoutineBlocksAreIgnored() {
        val json = """
            {"version":2,"rules":[],"routineBlocks":[
              {"appKey":"social","appName":"Social"}
            ]}
        """.trimIndent()

        assertTrue(RestrictionRules.parseConfiguration(json).isEmpty)
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
