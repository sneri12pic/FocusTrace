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
)

object RestrictionRules {
    const val PREFS_NAME = "focustrace_restrictions"
    const val PREFS_RULES_KEY = "rules_json"

    fun parseRules(json: String?): List<RestrictionRule> {
        if (json.isNullOrBlank()) return emptyList()
        return try {
            val root = JSONObject(json)
            val rules = root.optJSONArray("rules") ?: JSONArray()
            val routineBlocks = root.optJSONArray("routineBlocks") ?: JSONArray()
            buildList {
                for (index in 0 until rules.length()) {
                    parseRule(rules.optJSONObject(index))?.let(::add)
                }
                for (index in 0 until routineBlocks.length()) {
                    parseRoutineBlock(routineBlocks.optJSONObject(index))?.let(::add)
                }
            }
        } catch (_: Exception) {
            emptyList()
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

    fun hasRules(json: String?): Boolean = parseRules(json).isNotEmpty()

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
        )
    }

    private fun parseRoutineBlock(row: JSONObject?): RestrictionRule? {
        if (row == null) return null
        val appKey = row.optString("appKey").takeIf { it.isNotBlank() } ?: return null
        val appName = row.optString("appName").takeIf { it.isNotBlank() } ?: return null
        return RestrictionRule(
            appKey = appKey,
            appName = appName,
            type = RestrictionRuleType.RoutineBlock,
        )
    }

    private fun isScheduleActive(rule: RestrictionRule, nowMs: Long): Boolean {
        val start = rule.startMinute ?: return false
        val end = rule.endMinute ?: return false
        if (start == end) return false
        val calendar = Calendar.getInstance().apply { timeInMillis = nowMs }
        val current = calendar.get(Calendar.HOUR_OF_DAY) * 60 + calendar.get(Calendar.MINUTE)
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
