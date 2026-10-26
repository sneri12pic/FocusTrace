package com.stepandemianenko.focustrace

import android.content.SharedPreferences

/** Durable, occurrence-scoped permission to change an actively blocking rule. */
internal class RestrictionChangeGuard(private val prefs: SharedPreferences) {
    fun check(
        rule: RestrictionRule, now: Long, usageSeconds: Long,
        request: Boolean = false,
    ): String {
        val end = RestrictionRules.blockedUntilMs(rule, now, usageSeconds) ?: return "allowed"
        if (rule.difficulty == "hard") return "hard"
        val key = "change:${rule.appKey}:${rule.type.jsonName}"
        val signature = "$rule:$end"
        val matches = prefs.getString("$key:rule", null) == signature
        if (rule.difficulty == "moderate") {
            if (!matches && request) {
                check(prefs.edit().putString("$key:rule", signature)
                    .putLong("$key:ready", now + 300_000L).commit())
            }
            val ready = prefs.getLong("$key:ready", Long.MAX_VALUE)
            return if ((matches || request) && now >= ready) "allowed" else "cooldown"
        }
        // Easy changes are confirmed in Flutter, including the existing import
        // and clear-data confirmation sheets. They require no native timer.
        return "allowed"
    }

    fun clear(rule: RestrictionRule) {
        val key = "change:${rule.appKey}:${rule.type.jsonName}"
        check(prefs.edit().remove("$key:rule").remove("$key:ready").commit())
    }
}
