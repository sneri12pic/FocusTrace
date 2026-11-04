package com.stepandemianenko.focustrace

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
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
    fun nudgeZonesUseMinutesLeftOnTheTightestLimit() {
        val configuration = RestrictionRules.parseConfiguration(
            """{"preferredLimits":[
                {"limitMinutes":30,"apps":["a","b"]},
                {"limitMinutes":20,"apps":["a"]},
                {"limitMinutes":0,"apps":["ignored"]},
                {"limitMinutes":5,"apps":[]}
            ]}""",
        )

        assertEquals(2, configuration.preferredLimits.size)
        assertFalse(configuration.isEmpty)
        assertEquals(setOf("a", "b"), configuration.appKeys)
        // More than 5 minutes left on every limit: nothing yet.
        assertNull(configuration.preferredNudge("a", mapOf("a" to 14 * 60L + 59)))
        // Amber at exactly 5 minutes left on a's own 20-minute limit.
        val amber = configuration.preferredNudge("a", mapOf("a" to 15 * 60L))!!
        assertEquals(PreferredNudge("a", 5), amber)
        assertFalse(amber.red)
        assertEquals(PreferredNudge("a", 2), configuration.preferredNudge("a", mapOf("a" to 18 * 60L)))
        // Red from 1 minute left: "1 minute left", then reached, then over.
        assertTrue(configuration.preferredNudge("a", mapOf("a" to 19 * 60L))!!.red)
        assertEquals(PreferredNudge("a", 1), configuration.preferredNudge("a", mapOf("a" to 19 * 60L + 30)))
        assertEquals(PreferredNudge("a", 0), configuration.preferredNudge("a", mapOf("a" to 20 * 60L + 59)))
        assertEquals(PreferredNudge("a", -3), configuration.preferredNudge("a", mapOf("a" to 23 * 60L)))
        // A category limit counts every app in it, whichever one is open.
        assertEquals(
            PreferredNudge("b", 4),
            configuration.preferredNudge("b", mapOf("a" to 6 * 60L, "b" to 20 * 60L)),
        )
        assertEquals(
            PreferredNudge("a", 4),
            configuration.preferredNudge("a", mapOf("a" to 6 * 60L, "b" to 20 * 60L)),
        )
        assertNull(configuration.preferredNudge("c", mapOf("a" to 600L)))
        assertTrue(configuration.blockReasons("a", 0L, mapOf("a" to 6000L)).isEmpty())
    }

    @Test
    fun nudgeShowsLiveOnceWhenCrossingIntoAmberAndNotAgainWhileStaying() {
        val schedule = NudgeSchedule()
        assertFalse(schedule.isDue("a", null, 0L))
        assertTrue(schedule.isDue("a", PreferredNudge("a", 5), 1_000L))
        assertFalse(schedule.isDue("a", PreferredNudge("a", 4), 61_000L))
        assertFalse(schedule.isDue("a", PreferredNudge("a", 2), 20 * 60_000L))
    }

    @Test
    fun nudgeShowsAgainOnEveryReturnInAmberOrRed() {
        val schedule = NudgeSchedule()
        assertTrue(schedule.isDue("a", PreferredNudge("a", 5), 0L))
        assertFalse(schedule.isDue("launcher", null, 1_000L))
        // Back 3 minutes later and still amber: shows again.
        assertTrue(schedule.isDue("a", PreferredNudge("a", 4), 181_000L))
        assertFalse(schedule.isDue("a", PreferredNudge("a", 4), 182_000L))
        // Another app in front for a single tick still counts as a return.
        assertFalse(schedule.isDue("b", null, 183_000L))
        assertTrue(schedule.isDue("a", PreferredNudge("a", -2), 184_000L))
        assertFalse(schedule.isDue("other", null, 185_000L))
        assertTrue(schedule.isDue("a", PreferredNudge("a", -2), 186_000L))
    }

    @Test
    fun nudgeShowsLiveWhenCrossingIntoRedThenRepeatsEveryTenMinutes() {
        val schedule = NudgeSchedule()
        val repeat = RestrictionRules.NUDGE_RED_REPEAT_MS
        assertTrue(schedule.isDue("a", PreferredNudge("a", 2), 0L))
        assertTrue(schedule.isDue("a", PreferredNudge("a", 1), 60_000L))
        assertFalse(schedule.isDue("a", PreferredNudge("a", 0), 120_000L))
        assertFalse(schedule.isDue("a", PreferredNudge("a", -8), 60_000L + repeat - 1))
        assertTrue(schedule.isDue("a", PreferredNudge("a", -9), 60_000L + repeat))
        assertFalse(schedule.isDue("a", PreferredNudge("a", -10), 120_000L + repeat))
    }

    @Test
    fun nudgeIgnoresSystemUiAndUnknownForegroundFlicker() {
        val schedule = NudgeSchedule()
        assertTrue(schedule.isDue("a", PreferredNudge("a", 3), 0L))
        assertFalse(schedule.isDue("com.android.systemui", null, 1_000L))
        assertFalse(schedule.isDue("a", PreferredNudge("a", 3), 2_000L))
        assertFalse(schedule.isDue(null, null, 3_000L))
        assertFalse(schedule.isDue("a", PreferredNudge("a", 3), 4_000L))
    }

    @Test
    fun nudgeShowsAgainAfterUsageDropsBelowTheZone() {
        // For example a raised limit, then crossing into the zone again later.
        val schedule = NudgeSchedule()
        assertTrue(schedule.isDue("a", PreferredNudge("a", 1), 0L))
        assertFalse(schedule.isDue("a", null, 1_000L))
        assertTrue(schedule.isDue("a", PreferredNudge("a", 5), 2_000L))
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
