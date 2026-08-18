package com.stepandemianenko.focustrace

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import java.util.UUID

internal object RestrictionEventStore {
    fun recordBlocked(
        context: Context,
        appKey: String,
        appName: String,
        reason: String,
        occurredAtMs: Long = System.currentTimeMillis(),
    ) {
        val databaseFile = context.getDatabasePath(UsageSnapshotStore.DATABASE_NAME)
        if (!databaseFile.exists()) return
        try {
            SQLiteDatabase.openDatabase(
                databaseFile.path,
                null,
                SQLiteDatabase.OPEN_READWRITE,
            ).use { database ->
                if (!database.hasRestrictionEventsTable()) return
                database.insertWithOnConflict(
                    TABLE_RESTRICTION_EVENTS,
                    null,
                    ContentValues().apply {
                        put("id", UUID.randomUUID().toString())
                        put("app_key", appKey)
                        put("app_name", appName)
                        put("event_type", "blocked")
                        put("reason", reason)
                        put("occurred_at", occurredAtMs)
                    },
                    SQLiteDatabase.CONFLICT_IGNORE,
                )
            }
        } catch (_: Exception) {
            // Blocking remains authoritative if analytics storage is busy.
        }
    }

    private fun SQLiteDatabase.hasRestrictionEventsTable(): Boolean {
        rawQuery(
            "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
            arrayOf(TABLE_RESTRICTION_EVENTS),
        ).use { cursor ->
            return cursor.moveToFirst()
        }
    }

    private const val TABLE_RESTRICTION_EVENTS = "restriction_events"
}
