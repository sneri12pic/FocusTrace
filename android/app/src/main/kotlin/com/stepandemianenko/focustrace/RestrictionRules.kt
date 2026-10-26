package com.stepandemianenko.focustrace

import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

enum class RestrictionRuleType(val jsonName: String) {
    BlockNow("blockNow"),
    DailyLimit("dailyLimit"),
    Schedule("schedule"),
    RoutineBlock("routineBlock");

    companion object {
        fun fromJsonName(value: String?): RestrictionRuleType? {
            return values().firstOrNull { it.jsonName == value }
        }
    }
}

data class RestrictionRule(
    val appKey: String,
    val appName: String,
    val type: RestrictionRuleType,
    val untilMs: Long? = null,
    val limitMinutes: Int? = null,
    val startMinute: Int? = null,
    val endMinute: Int? = null,
    val difficulty: String = "easy",
    val weekdays: List<Int> = (1..7).toList(),
)

data class RoutineMember(
    val appKey: String,
    val appName: String,
    val isIncludedInLimit: Boolean,
    /** Optional cap for this app alone; it never reserves shared time. */
    val limitMinutes: Int? = null,
)

data class RoutineLimit(
    val id: String,
    val name: String,
    val limitMinutes: Int,
    val apps: List<RoutineMember>,
) {
    val includedApps: List<RoutineMember>
        get() = apps.filter { it.isIncludedInLimit }

    /** Each member counted once, whatever its cap. */
    fun usageSeconds(usageByAppKey: Map<String, Long>): Long =
        includedApps.sumOf { usageByAppKey[it.appKey] ?: 0L }

    fun isReached(usageByAppKey: Map<String, Long>): Boolean =
        usageSeconds(usageByAppKey) >= limitMinutes * 60L

    fun isAppCapReached(appKey: String, usageByAppKey: Map<String, Long>): Boolean {
        val cap = apps.firstOrNull { it.appKey == appKey }?.limitMinutes ?: return false
        return (usageByAppKey[appKey] ?: 0L) >= cap * 60L
    }
}

/** One active reason an app is blocked. An app may have several at once. */
data class BlockReason(
    val kind: Kind,
    val untilMs: Long?,
    val rule: RestrictionRule? = null,
    val routine: RoutineLimit? = null,
) {
    enum class Kind { BlockNow, DailyLimit, Schedule, RoutineBlock, RoutineShared, RoutineApp }

    val eventName: String
        get() = when (kind) {
            Kind.RoutineShared -> "routineLimit:${routine?.id}"
            Kind.RoutineApp -> "routineAppLimit:${routine?.id}"
            else -> rule?.type?.jsonName ?: kind.name
        }
}

data class RestrictionConfiguration(
    val rules: List<RestrictionRule> = emptyList(),
    val routines: List<RoutineLimit> = emptyList(),
) {
    val isEmpty: Boolean
        get() = rules.isEmpty() && routines.isEmpty()

    /** Package names BlockerService watches; surface rules belong to the accessibility service. */
    val appKeys: Set<String>
        get() = buildSet {
            addAll(rules.map { it.appKey })
            routines.forEach { routine ->
                addAll(routine.includedApps.map { it.appKey })
                addAll(routine.apps.filter { it.limitMinutes != null }.map { it.appKey })
            }
        }.filterNotTo(mutableSetOf(), RestrictionRules::isSurfaceKey)

    // ponytail: no usage is measured inside a surface, so daily limits and
    // routine allowances never trip for one; pass surface usage here once tracked.
    fun surfaceBlockReasons(surfaceKey: String, nowMs: Long): List<BlockReason> =
        blockReasons(surfaceKey, nowMs, emptyMap())

    fun blockingRoutine(
        appKey: String,
        usageByAppKey: Map<String, Long>,
    ): RoutineLimit? = routines.firstOrNull { routine ->
        routine.includedApps.any { it.appKey == appKey } &&
            routine.isReached(usageByAppKey)
    }

    /**
     * Every restriction blocking [appKey] now. Any one is enough to block;
     * removing one never unblocks the app while another remains.
     */
    fun blockReasons(
        appKey: String,
        nowMs: Long,
        usageByAppKey: Map<String, Long>,
    ): List<BlockReason> = buildList {
        val usage = usageByAppKey[appKey] ?: 0L
        for (rule in rules) {
            if (rule.appKey != appKey || !RestrictionRules.isBlocked(rule, nowMs, usage)) continue
            val kind = when (rule.type) {
                RestrictionRuleType.BlockNow -> BlockReason.Kind.BlockNow
                RestrictionRuleType.DailyLimit -> BlockReason.Kind.DailyLimit
                RestrictionRuleType.Schedule -> BlockReason.Kind.Schedule
                RestrictionRuleType.RoutineBlock -> BlockReason.Kind.RoutineBlock
            }
            add(BlockReason(kind, RestrictionRules.blockedUntilMs(rule, nowMs, usage), rule = rule))
        }
        val midnight = RestrictionRules.startOfTomorrowMs(nowMs)
        for (routine in routines) {
            val member = routine.apps.firstOrNull { it.appKey == appKey } ?: continue
            if (member.isIncludedInLimit && routine.isReached(usageByAppKey)) {
                add(BlockReason(BlockReason.Kind.RoutineShared, midnight, routine = routine))
            }
            if (routine.isAppCapReached(appKey, usageByAppKey)) {
                add(BlockReason(BlockReason.Kind.RoutineApp, midnight, routine = routine))
            }
        }
    }
}

/**
 * The blocker reads the stored rules every tick, but they change only when the
 * user edits them. Parses only when the stored JSON differs from the last one;
 * block-now expiry is still decided against [nowMs] on every call, and
 * schedules and limits stay time-dependent in [RestrictionRules.isBlocked].
 */
internal class RestrictionConfigurationCache(
    private val parse: (String?) -> RestrictionConfiguration = RestrictionRules::parseConfiguration,
) {
    private var json: String? = null
    private var parsed: RestrictionConfiguration? = null

    fun at(json: String?, nowMs: Long): RestrictionConfiguration {
        val configuration = parsed?.takeIf { json == this.json }
            ?: parse(json).also {
                this.json = json
                parsed = it
            }
        return configuration.copy(
            rules = configuration.rules.filter {
                it.type != RestrictionRuleType.BlockNow ||
                    (it.untilMs != null && it.untilMs > nowMs)
            },
        )
    }
}

object RestrictionRules {
    const val PREFS_NAME = "focustrace_restrictions"
    const val PREFS_RULES_KEY = "rules_json"
    const val SURFACE_KEY_PREFIX = "surface:"

    fun isSurfaceKey(appKey: String): Boolean = appKey.startsWith(SURFACE_KEY_PREFIX)

    fun parseRules(json: String?): List<RestrictionRule> {
        return parseConfiguration(json).rules
    }

    fun parseConfiguration(json: String?): RestrictionConfiguration {
        if (json.isNullOrBlank()) return RestrictionConfiguration()
        return try {
            val root = JSONObject(json)
            val rules = root.optJSONArray("rules") ?: JSONArray()
            val routines = root.optJSONArray("routines") ?: JSONArray()
            RestrictionConfiguration(
                rules = buildList {
                    for (index in 0 until rules.length()) {
                        parseRule(rules.optJSONObject(index))?.let(::add)
                    }
                },
                routines = buildList {
                    for (index in 0 until routines.length()) {
                        parseRoutine(routines.optJSONObject(index))?.let(::add)
                    }
                },
            )
        } catch (_: Exception) {
            RestrictionConfiguration()
        }
    }

    fun isBlocked(rule: RestrictionRule, nowMs: Long, usageSecondsToday: Long): Boolean {
        return when (rule.type) {
            RestrictionRuleType.BlockNow -> {
                val until = rule.untilMs ?: return false
                nowMs < until
            }
            RestrictionRuleType.DailyLimit -> {
                val limit = rule.limitMinutes ?: return false
                usageSecondsToday >= limit * 60L
            }
            RestrictionRuleType.Schedule -> isScheduleActive(rule, nowMs)
            RestrictionRuleType.RoutineBlock -> true
        }
    }

    fun blockedUntilMs(
        rule: RestrictionRule,
        nowMs: Long,
        usageSecondsToday: Long,
    ): Long? {
        if (!isBlocked(rule, nowMs, usageSecondsToday)) return null
        return when (rule.type) {
            RestrictionRuleType.BlockNow -> rule.untilMs
            RestrictionRuleType.DailyLimit -> startOfTomorrow(nowMs)
            RestrictionRuleType.Schedule -> scheduleEndMs(rule, nowMs)
            RestrictionRuleType.RoutineBlock -> null
        }
    }

    fun hasRules(json: String?): Boolean = !parseConfiguration(json).isEmpty

    /** Whether BlockerService has anything to watch; surface-only rules need no polling. */
    fun hasPackageRules(json: String?): Boolean = parseConfiguration(json).appKeys.isNotEmpty()

    private fun parseRule(row: JSONObject?): RestrictionRule? {
        if (row == null) return null
        val appKey = row.optString("appKey").takeIf { it.isNotBlank() } ?: return null
        val appName = row.optString("appName").takeIf { it.isNotBlank() } ?: return null
        val type = RestrictionRuleType.fromJsonName(row.optString("type")) ?: return null
        val untilMs = optionalLong(row, "untilMs")
        val limitMinutes = optionalInt(row, "limitMinutes")
        val startMinute = optionalMinute(row, "startMinute")
        val endMinute = optionalMinute(row, "endMinute")

        when (type) {
            RestrictionRuleType.BlockNow -> if (untilMs == null) return null
            RestrictionRuleType.DailyLimit -> if (limitMinutes == null || limitMinutes <= 0) return null
            RestrictionRuleType.Schedule -> {
                if (startMinute == null || endMinute == null || startMinute == endMinute) {
                    return null
                }
            }
            RestrictionRuleType.RoutineBlock -> Unit
        }

        return RestrictionRule(
            appKey = appKey,
            appName = appName,
            type = type,
            untilMs = untilMs,
            limitMinutes = limitMinutes,
            startMinute = startMinute,
            endMinute = endMinute,
            difficulty = row.optString("difficulty", "easy"),
            weekdays = row.optJSONArray("weekdays")?.let { days ->
                (0 until days.length()).map { days.optInt(it) }.filter { it in 1..7 }.distinct()
            } ?: (1..7).toList(),
        )
    }

    private fun parseRoutine(row: JSONObject?): RoutineLimit? {
        if (row == null) return null
        if (!row.optBoolean("isEnabled", true)) return null
        val id = row.optString("id").takeIf { it.isNotBlank() } ?: return null
        val name = row.optString("name").takeIf { it.isNotBlank() } ?: return null
        val limitMinutes = optionalInt(row, "dailyLimitMinutes")
            ?.takeIf { it > 0 } ?: return null
        val rawApps = row.optJSONArray("apps") ?: return null
        val apps = buildList {
            for (index in 0 until rawApps.length()) {
                val app = rawApps.optJSONObject(index) ?: continue
                val appKey = app.optString("appKey").takeIf { it.isNotBlank() } ?: continue
                val appName = app.optString("appName").takeIf { it.isNotBlank() } ?: continue
                add(
                    RoutineMember(
                        appKey = appKey,
                        appName = appName,
                        isIncludedInLimit = app.optBoolean("isIncludedInLimit", true),
                        limitMinutes = optionalInt(app, "limitMinutes")?.takeIf { it > 0 },
                    )
                )
            }
        }.distinctBy { it.appKey }
        if (apps.none { it.isIncludedInLimit }) return null
        return RoutineLimit(
            id = id,
            name = name,
            limitMinutes = limitMinutes,
            apps = apps,
        )
    }

    fun startOfTomorrowMs(nowMs: Long): Long = startOfTomorrow(nowMs)

    private fun isScheduleActive(rule: RestrictionRule, nowMs: Long): Boolean {
        val start = rule.startMinute ?: return false
        val end = rule.endMinute ?: return false
        if (start == end) return false
        val calendar = Calendar.getInstance().apply { timeInMillis = nowMs }
        val current = calendar.get(Calendar.HOUR_OF_DAY) * 60 + calendar.get(Calendar.MINUTE)
        if (end < start && current < end) calendar.add(Calendar.DAY_OF_YEAR, -1)
        val isoDay = (calendar.get(Calendar.DAY_OF_WEEK) + 5) % 7 + 1
        if (isoDay !in rule.weekdays) return false
        return if (end < start) {
            current >= start || current < end
        } else {
            current >= start && current < end
        }
    }

    private fun scheduleEndMs(rule: RestrictionRule, nowMs: Long): Long? {
        val end = rule.endMinute ?: return null
        val calendar = Calendar.getInstance().apply {
            timeInMillis = nowMs
            set(Calendar.HOUR_OF_DAY, end / 60)
            set(Calendar.MINUTE, end % 60)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (calendar.timeInMillis <= nowMs) {
            calendar.add(Calendar.DAY_OF_YEAR, 1)
        }
        return calendar.timeInMillis
    }

    private fun startOfTomorrow(nowMs: Long): Long {
        return Calendar.getInstance().apply {
            timeInMillis = nowMs
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            add(Calendar.DAY_OF_YEAR, 1)
        }.timeInMillis
    }

    private fun optionalLong(row: JSONObject, key: String): Long? {
        return if (row.has(key) && !row.isNull(key)) row.optLong(key) else null
    }

    private fun optionalInt(row: JSONObject, key: String): Int? {
        return if (row.has(key) && !row.isNull(key)) row.optInt(key) else null
    }

    private fun optionalMinute(row: JSONObject, key: String): Int? {
        val value = optionalInt(row, key) ?: return null
        return value.takeIf { it in 0 until 24 * 60 }
    }
}
