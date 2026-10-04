package com.stepandemianenko.focustrace

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import java.util.Calendar
import java.util.Locale

internal class UsageSnapshotStore(private val context: Context) {
    private fun <T> withDatabase(
        unavailable: (String) -> Unit = {},
        block: (SQLiteDatabase) -> T,
    ): T? {
        val file = context.getDatabasePath(DATABASE_NAME)
        if (!file.exists()) {
            unavailable("database_unavailable")
            return null
        }
        return SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READWRITE).use { db ->
            // Flutter owns migrations. A boot worker can run before the first
            // v5 Flutter open; it must not mutate an old or partially created DB.
            if (db.version != 5 || !listOf(
                    "daily_app_usage", "usage_intervals", "usage_snapshot_days", "settings",
                ).all { db.hasTable(it) }
            ) {
                unavailable("schema_unavailable version=${db.version}")
                return@use null
            }
            block(db)
        }
    }

    fun generation(): String? = withDatabase { generation(it) }

    internal data class AcceptedSnapshot(
        val coveredUntilMs: Long,
        val totals: Map<String, UsageStats.AppUsage>,
        val intervals: List<UsageIntervalRow>,
    )

    fun acceptedSnapshot(window: UsageDayWindow, expectedGeneration: String?): AcceptedSnapshot? = withDatabase { db ->
        db.beginTransaction()
        try {
            if (window.historical || expectedGeneration == null || generation(db) != expectedGeneration) return@withDatabase null
            val until = db.rawQuery(
                "SELECT covered_until_ms FROM usage_snapshot_days WHERE day=? AND start_ms=? AND end_ms=? AND queried_at_ms<=?",
                arrayOf(window.day, window.startMs.toString(), window.endMs.toString(), window.nowMs.toString()),
            ).use { if (it.moveToFirst()) it.getLong(0) else return@withDatabase null }
            if (until <= window.startMs || until > window.nowMs) return@withDatabase null
            val intervals = overlappingIntervals(db, window)
            if (intervals.any { it.startedAtMs < window.startMs || it.endedAtMs > until }) return@withDatabase null
            val intervalMs = intervals.groupBy { it.appKey }.mapValues { (_, rows) -> rows.sumOf { it.endedAtMs - it.startedAtMs } }
            val totals = db.rawQuery("SELECT app_key, duration_seconds, launch_count FROM daily_app_usage WHERE day=?", arrayOf(window.day)).use {
                buildMap {
                    while (it.moveToNext()) put(it.getString(0), UsageStats.AppUsage(
                        maxOf(it.getLong(1) * 1000, intervalMs[it.getString(0)] ?: 0), until, it.getInt(2),
                    ))
                    for ((app, ms) in intervalMs) if (app !in this) put(app, UsageStats.AppUsage(ms, until, 0))
                }
            }
            AcceptedSnapshot(until, totals, intervals)
        } finally {
            db.endTransaction()
        }
    }

    private fun generation(db: SQLiteDatabase): String = db.rawQuery(
        "SELECT value FROM settings WHERE key = 'usage_recovery_generation'", null,
    ).use { if (it.moveToFirst()) it.getString(0) else "" }

    fun needsRecovery(window: UsageDayWindow): Boolean = withDatabase { db ->
        db.rawQuery(
            "SELECT status, queried_at_ms, start_ms, end_ms FROM usage_snapshot_days WHERE day = ?",
            arrayOf(window.day),
        ).use {
            if (!it.moveToFirst()) return@use true
            if (it.getLong(2) != window.startMs || it.getLong(3) != window.endMs) return@use false
            val lastAttempt = it.getLong(1)
            // A snapshot taken before midnight never suppresses the first
            // historical reconciliation, even if the worker runs soon after.
            if (lastAttempt < window.endMs) return@use true
            val delay = if (it.getString(0) == "reconciled") RECHECK_INTERVAL_MS else RETRY_INTERVAL_MS
            window.nowMs - lastAttempt >= delay
        }
    } ?: true

    fun packageNames(window: UsageDayWindow): Set<String> = withDatabase { db ->
        db.rawQuery(
            "SELECT app_key FROM daily_app_usage WHERE day = ? " +
                "UNION SELECT app_key FROM usage_intervals WHERE started_at < ? AND ended_at > ?",
            arrayOf(window.day, window.endMs.toString(), window.startMs.toString()),
        ).use { cursor -> buildSet { while (cursor.moveToNext()) add(cursor.getString(0)) } }
    } ?: emptySet()

    fun markUnavailable(window: UsageDayWindow, expectedGeneration: String?) {
        withDatabase { db ->
            db.beginTransaction()
            try {
                if (canWrite(db, window, expectedGeneration)) {
                    val values = metadata(window, "unavailable", window.startMs)
                    // Preserve the last successful partial snapshot's coverage.
                    db.rawQuery(
                        "SELECT covered_until_ms, status FROM usage_snapshot_days WHERE day = ?",
                        arrayOf(window.day),
                    ).use {
                        if (it.moveToFirst()) {
                            values.put("covered_until_ms", it.getLong(0))
                            if (it.getString(1) == "reconciled") values.put("status", "reconciled")
                        }
                    }
                    db.insertOrThrow("usage_snapshot_days", null, valuesWithoutExistingDay(db, values, window))
                }
                db.setTransactionSuccessful()
            } finally {
                db.endTransaction()
            }
        }
    }

    // Remove only metadata inside the caller's transaction; insertOrThrow makes
    // any failure roll the deletion back instead of silently returning -1.
    private fun valuesWithoutExistingDay(
        db: SQLiteDatabase,
        values: ContentValues,
        window: UsageDayWindow,
    ): ContentValues {
        db.delete("usage_snapshot_days", "day = ?", arrayOf(window.day))
        return values
    }

    fun replaceDay(
        window: UsageDayWindow,
        rows: List<UsageSnapshotRow>,
        intervals: List<UsageIntervalRow>,
        expectedGeneration: String?,
        diagnostic: (String) -> Unit = {},
    ): Boolean {
        val rejected: (String) -> Unit = { reason ->
            // Observability must never change a transaction's outcome.
            runCatching {
                diagnostic("day=${window.day} rejected=$reason now=${window.nowMs} " +
                    "window=${window.startMs}..${window.endMs} zone=${window.timezoneId}")
            }
            Unit
        }
        return withDatabase(rejected) { db ->
            db.beginTransaction()
            try {
                if (!canWrite(db, window, expectedGeneration, rejected) || !preservesTotals(db, window, rows, rejected)) return@withDatabase false
                val overlapping = overlappingIntervals(db, window)
                val previousCoverage = db.rawQuery(
                    "SELECT covered_until_ms FROM usage_snapshot_days WHERE day = ?", arrayOf(window.day),
                ).use { if (it.moveToFirst()) it.getLong(0) else null }
                if (!preservesIntervals(window, overlapping, intervals, previousCoverage, rejected)) return@withDatabase false

                db.delete("daily_app_usage", "day = ?", arrayOf(window.day))
                for (row in rows) {
                    db.insertOrThrow("daily_app_usage", null, ContentValues().apply {
                        put("day", window.day)
                        put("app_key", row.appKey)
                        put("app_name", row.appName)
                        put("package_name", row.appKey)
                        putNull("process_name")
                        put("duration_seconds", row.durationSeconds)
                        put("launch_count", row.launchCount)
                    })
                }
                // Legacy report imports can cross midnight. Replace only the part
                // belonging to this day, preserving neighboring-day fragments.
                for (old in overlapping) {
                    db.delete("usage_intervals", "id = ?", arrayOf(old.id))
                    if (old.startedAtMs < window.startMs) insertInterval(
                        db, old.copy(endedAtMs = window.startMs),
                    )
                    if (old.endedAtMs > window.endMs) insertInterval(
                        db, old.copy(
                            id = "${old.appKey}:${window.endMs}",
                            startedAtMs = window.endMs,
                        ),
                    )
                }
                for (interval in intervals) insertInterval(db, interval)
                val values = metadata(
                    window,
                    if (window.historical) "reconciled" else "partial",
                    window.queryEndMs,
                )
                db.insertOrThrow("usage_snapshot_days", null, valuesWithoutExistingDay(db, values, window))
                db.setTransactionSuccessful()
                true
            } finally {
                db.endTransaction()
            }
        } ?: false
    }

    private fun canWrite(
        db: SQLiteDatabase,
        window: UsageDayWindow,
        expectedGeneration: String?,
        rejected: (String) -> Unit = {},
    ): Boolean {
        // Clear/import can happen in Flutter while the OS query is running.
        // Their transaction rotates this token so an in-flight result cannot
        // repopulate cleared data or overwrite an imported backup.
        if (expectedGeneration == null || generation(db) != expectedGeneration) {
            rejected(if (expectedGeneration == null) "generation_unavailable" else "generation_mismatch")
            return false
        }
        return db.rawQuery(
            "SELECT start_ms, end_ms, queried_at_ms, status FROM usage_snapshot_days WHERE day = ?",
            arrayOf(window.day),
        ).use {
            if (!it.moveToFirst()) return@use true
            val reason = when {
                it.getLong(0) != window.startMs || it.getLong(1) != window.endMs -> "boundary_mismatch"
                it.getLong(2) > window.nowMs -> "stale_result"
                it.getString(3) == "reconciled" &&
                    (!window.historical || window.nowMs - it.getLong(2) < RECHECK_INTERVAL_MS) -> "reconciliation_cooldown"
                else -> null
            }
            if (reason != null) rejected("$reason stored_window=${it.getLong(0)}..${it.getLong(1)} " +
                "stored_queried_at=${it.getLong(2)} status=${it.getString(3)}")
            reason == null
        }
    }

    private fun preservesTotals(
        db: SQLiteDatabase,
        window: UsageDayWindow,
        rows: List<UsageSnapshotRow>,
        rejected: (String) -> Unit,
    ): Boolean {
        val totals = rows.associate { it.appKey to it.durationSeconds }
        return db.rawQuery(
            "SELECT app_key, duration_seconds FROM daily_app_usage WHERE day = ?",
            arrayOf(window.day),
        ).use {
            while (it.moveToNext()) {
                if ((totals[it.getString(0)] ?: 0L) < it.getLong(1)) {
                    rejected("duration_decrease package=${it.getString(0)} stored_seconds=${it.getLong(1)} " +
                        "candidate_seconds=${totals[it.getString(0)] ?: 0L}")
                    return@use false
                }
            }
            true
        }
    }

    private fun overlappingIntervals(db: SQLiteDatabase, window: UsageDayWindow): List<UsageIntervalRow> =
        db.rawQuery(
            "SELECT id, app_key, app_name, started_at, ended_at FROM usage_intervals " +
                "WHERE started_at < ? AND ended_at > ?",
            arrayOf(window.endMs.toString(), window.startMs.toString()),
        ).use { cursor ->
            buildList {
                while (cursor.moveToNext()) add(UsageIntervalRow(
                    cursor.getString(0), cursor.getString(1), cursor.getString(2),
                    cursor.getLong(3), cursor.getLong(4),
                ))
            }
        }

    private fun preservesIntervals(
        window: UsageDayWindow,
        previous: List<UsageIntervalRow>,
        replacement: List<UsageIntervalRow>,
        previousCoverage: Long?,
        rejected: (String) -> Unit,
    ): Boolean {
        val candidatesByApp = replacement.groupBy { it.appKey }.mapValues { (_, rows) -> rows.sortedBy { it.startedAtMs } }
        val usedByStrictCoverage = mutableSetOf<UsageIntervalRow>()
        val coverage = previous.associateWith { old ->
            var coveredTo = maxOf(old.startedAtMs, window.startMs)
            val requiredEnd = minOf(old.endedAtMs, window.endMs)
            val contributors = mutableListOf<UsageIntervalRow>()
            for (fresh in candidatesByApp[old.appKey].orEmpty()) {
                if (coveredTo >= requiredEnd || fresh.startedAtMs > coveredTo) break
                if (fresh.endedAtMs > coveredTo) {
                    coveredTo = fresh.endedAtMs
                    contributors.add(fresh)
                }
            }
            if (coveredTo >= requiredEnd) usedByStrictCoverage.addAll(contributors)
            coveredTo
        }
        fun translates(old: UsageIntervalRow, fresh: UsageIntervalRow): Boolean {
            val shift = fresh.startedAtMs - old.startedAtMs
            val oldDuration = old.endedAtMs - old.startedAtMs
            val freshDuration = fresh.endedAtMs - fresh.startedAtMs
            return old.appKey == fresh.appKey && oldDuration > 0 &&
                old.startedAtMs >= window.startMs && old.endedAtMs <= window.queryEndMs &&
                fresh.startedAtMs >= window.startMs && fresh.endedAtMs <= window.queryEndMs &&
                shift in -MAX_INTERVAL_TRANSLATION_MS..MAX_INTERVAL_TRANSLATION_MS &&
                (freshDuration == oldDuration ||
                    (old.endedAtMs == previousCoverage && freshDuration >= oldDuration))
        }
        // Preserve the complete sequence under one unique shift, including tiny
        // sessions that no longer overlap. At least one session must overlap.
        // ponytail: bounded per-day scans; index candidates if profiling warrants it.
        val translatedPackages = previous.groupBy { it.appKey }.filter { (app, rows) ->
            val oldRows = rows.sortedBy { it.startedAtMs }
            if (oldRows.size < 2 || oldRows.zipWithNext().any { (a, b) -> a.endedAtMs > b.startedAtMs }) {
                return@filter false
            }
            val candidates = candidatesByApp[app].orEmpty()
            val first = oldRows.first()
            val shifts = candidates.filter { translates(first, it) }
                .map { it.startedAtMs - first.startedAtMs }.distinct()
            shifts.count { shift ->
                oldRows.any { it.endedAtMs - it.startedAtMs > kotlin.math.abs(shift) } &&
                    oldRows.all { old ->
                        candidates.singleOrNull { it.startedAtMs == old.startedAtMs + shift }
                            ?.let { translates(old, it) } == true
                    }
            } == 1
        }.keys
        return previous.all { old ->
            if (old.appKey in translatedPackages) return@all true
            val coveredTo = coverage.getValue(old)
            val requiredEnd = minOf(old.endedAtMs, window.endMs)
            if (coveredTo >= requiredEnd) return@all true
            val candidates = candidatesByApp[old.appKey].orEmpty()
            // ponytail: bounded per-day matching is quadratic; index by start if profiling warrants it.
            val translated = candidates.filter {
                translates(old, it) && it.startedAtMs < old.endedAtMs && it.endedAtMs > old.startedAtMs
            }.singleOrNull()
            if (translated != null && translated !in usedByStrictCoverage &&
                previous.count { translates(it, translated) } == 1
            ) return@all true
            val neighbors = listOfNotNull(
                candidates.lastOrNull { it.startedAtMs <= coveredTo },
                candidates.firstOrNull { it.startedAtMs > coveredTo },
            ).joinToString { "${it.startedAtMs}..${it.endedAtMs}" }
            val gapEnd = minOf(requiredEnd, candidates.firstOrNull { it.startedAtMs > coveredTo }?.startedAtMs ?: requiredEnd)
            rejected("interval_gap package=${old.appKey} stored=${old.startedAtMs}..${old.endedAtMs} " +
                "uncovered=$coveredTo..$gapEnd candidate_neighbors=[$neighbors]")
            false
        }
    }

    private fun insertInterval(db: SQLiteDatabase, row: UsageIntervalRow) {
        db.insertOrThrow("usage_intervals", null, ContentValues().apply {
            put("id", row.id)
            put("app_key", row.appKey)
            put("app_name", row.appName)
            put("started_at", row.startedAtMs)
            put("ended_at", row.endedAtMs)
        })
    }

    private fun metadata(window: UsageDayWindow, status: String, coveredUntilMs: Long) = ContentValues().apply {
        put("day", window.day)
        put("start_ms", window.startMs)
        put("end_ms", window.endMs)
        put("timezone_id", window.timezoneId)
        put("queried_at_ms", window.nowMs)
        put("covered_until_ms", coveredUntilMs)
        put("status", status)
    }

    private fun SQLiteDatabase.hasTable(name: String): Boolean = rawQuery(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?", arrayOf(name),
    ).use { it.moveToFirst() }

    companion object {
        // Engineering policies, not Android event-delivery guarantees. Persisted
        // timestamps coalesce serial/concurrent readers across process restart.
        // Engineering bound for observed 140–387ms endpoint shifts, not an Android guarantee.
        // Match whole sessions with overlap evidence; never waive missing sessions or shorter durations.
        internal const val MAX_INTERVAL_TRANSLATION_MS = 1_000L
        internal const val RETRY_INTERVAL_MS = 15L * 60 * 1_000
        internal const val RECHECK_INTERVAL_MS = 6L * 60 * 60 * 1_000
        internal const val DATABASE_NAME = "focus_trace.db"
        internal fun dayKey(calendar: Calendar): String = String.format(
            Locale.ROOT, "%04d-%02d-%02d", calendar.get(Calendar.YEAR),
            calendar.get(Calendar.MONTH) + 1, calendar.get(Calendar.DAY_OF_MONTH),
        )
    }
}
