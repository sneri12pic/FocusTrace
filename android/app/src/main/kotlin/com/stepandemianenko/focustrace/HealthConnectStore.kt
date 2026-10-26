package com.stepandemianenko.focustrace

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

/** One exercise session read from Health Connect. Times are epoch millis. */
data class ImportedWorkout(
    val id: String,
    val sourcePackage: String,
    val exerciseType: Int,
    val title: String?,
    val startMillis: Long,
    val endMillis: Long,
    val startZoneOffsetSeconds: Int?,
    val lastModifiedMillis: Long,
)

/**
 * Health Connect settings, sync state and imported workouts.
 *
 * Kept apart from the Flutter database on purpose: nothing here enters cloud
 * sync, the portable backup, or Android Auto Backup (see backup_rules.xml).
 * The worker reads the same preferences, so a setting changed in the UI is
 * seen by the next run without any Flutter engine.
 */
class HealthConnectStore(context: Context) {
    private val app = context.applicationContext
    private val prefs = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private val db by lazy { Helper(app).writableDatabase }

    var enabled: Boolean
        get() = prefs.getBoolean(KEY_ENABLED, false)
        set(value) = prefs.edit().putBoolean(KEY_ENABLED, value).apply()

    var autoImport: Boolean
        get() = prefs.getBoolean(KEY_AUTO, false)
        set(value) = prefs.edit().putBoolean(KEY_AUTO, value).apply()

    var changesToken: String?
        get() = prefs.getString(KEY_TOKEN, null)
        set(value) = prefs.edit().putString(KEY_TOKEN, value).apply()

    val lastSuccessMillis: Long get() = prefs.getLong(KEY_LAST_SUCCESS, 0L)
    val lastAttemptMillis: Long get() = prefs.getLong(KEY_LAST_ATTEMPT, 0L)
    /** "imported", "noNew" or an error code from [HealthConnectImporter]. */
    val lastOutcome: String? get() = prefs.getString(KEY_OUTCOME, null)
    val lastImportedCount: Int get() = prefs.getInt(KEY_COUNT, 0)

    fun recordAttempt(outcome: String, importedCount: Int, now: Long) {
        val edit = prefs.edit()
            .putLong(KEY_LAST_ATTEMPT, now)
            .putString(KEY_OUTCOME, outcome)
            .putInt(KEY_COUNT, importedCount)
        if (outcome == OUTCOME_IMPORTED || outcome == OUTCOME_NO_NEW) {
            edit.putLong(KEY_LAST_SUCCESS, now)
        }
        edit.apply()
    }

    /** Insert or replace by Health Connect id; returns true if new or changed. */
    fun upsert(workout: ImportedWorkout): Boolean {
        val existing = db.rawQuery(
            "SELECT last_modified FROM workouts WHERE id = ?",
            arrayOf(workout.id),
        ).use { if (it.moveToFirst()) it.getLong(0) else null }
        if (existing == workout.lastModifiedMillis) return false
        db.insertWithOnConflict(
            "workouts",
            null,
            ContentValues().apply {
                put("id", workout.id)
                put("source_package", workout.sourcePackage)
                put("exercise_type", workout.exerciseType)
                put("title", workout.title)
                put("start_millis", workout.startMillis)
                put("end_millis", workout.endMillis)
                put("start_zone_offset", workout.startZoneOffsetSeconds)
                put("last_modified", workout.lastModifiedMillis)
            },
            SQLiteDatabase.CONFLICT_REPLACE,
        )
        return true
    }

    fun delete(id: String): Boolean =
        db.delete("workouts", "id = ?", arrayOf(id)) > 0

    /** Removes local rows starting in [fromMillis, toMillis) whose ids are not in [keep]. */
    fun deleteMissingBetween(fromMillis: Long, toMillis: Long, keep: Set<String>): Int {
        val stale = db.rawQuery(
            "SELECT id FROM workouts WHERE start_millis >= ? AND start_millis < ?",
            arrayOf(fromMillis.toString(), toMillis.toString()),
        ).use { cursor ->
            buildList { while (cursor.moveToNext()) add(cursor.getString(0)) }
        }.filterNot(keep::contains)
        stale.forEach(::delete)
        return stale.size
    }

    fun workouts(limit: Int = 200): List<ImportedWorkout> =
        db.rawQuery(
            "SELECT id, source_package, exercise_type, title, start_millis, " +
                "end_millis, start_zone_offset, last_modified FROM workouts " +
                "ORDER BY start_millis DESC LIMIT ?",
            arrayOf(limit.toString()),
        ).use { cursor ->
            buildList {
                while (cursor.moveToNext()) {
                    add(
                        ImportedWorkout(
                            id = cursor.getString(0),
                            sourcePackage = cursor.getString(1),
                            exerciseType = cursor.getInt(2),
                            title = cursor.getString(3),
                            startMillis = cursor.getLong(4),
                            endMillis = cursor.getLong(5),
                            startZoneOffsetSeconds =
                                if (cursor.isNull(6)) null else cursor.getInt(6),
                            lastModifiedMillis = cursor.getLong(7),
                        ),
                    )
                }
            }
        }

    fun workoutCount(): Int =
        db.rawQuery("SELECT COUNT(*) FROM workouts", null)
            .use { if (it.moveToFirst()) it.getInt(0) else 0 }

    /** Deletes imported workouts and sync state; settings stay as they are. */
    fun clearImported() {
        db.delete("workouts", null, null)
        prefs.edit()
            .remove(KEY_TOKEN)
            .remove(KEY_LAST_SUCCESS)
            .remove(KEY_LAST_ATTEMPT)
            .remove(KEY_OUTCOME)
            .remove(KEY_COUNT)
            .apply()
    }

    private class Helper(context: Context) :
        SQLiteOpenHelper(context, DB_NAME, null, 1) {
        override fun onCreate(db: SQLiteDatabase) {
            db.execSQL(
                "CREATE TABLE workouts (" +
                    "id TEXT PRIMARY KEY NOT NULL, " +
                    "source_package TEXT NOT NULL, " +
                    "exercise_type INTEGER NOT NULL, " +
                    "title TEXT, " +
                    "start_millis INTEGER NOT NULL, " +
                    "end_millis INTEGER NOT NULL, " +
                    "start_zone_offset INTEGER, " +
                    "last_modified INTEGER NOT NULL)",
            )
            db.execSQL("CREATE INDEX workouts_start ON workouts(start_millis)")
        }

        override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {}
    }

    companion object {
        const val PREFS = "focustrace_health_connect"
        const val DB_NAME = "focustrace_health_connect.db"
        const val OUTCOME_IMPORTED = "imported"
        const val OUTCOME_NO_NEW = "noNew"
        private const val KEY_ENABLED = "enabled"
        private const val KEY_AUTO = "auto_import"
        private const val KEY_TOKEN = "exercise_changes_token"
        private const val KEY_LAST_SUCCESS = "last_success_millis"
        private const val KEY_LAST_ATTEMPT = "last_attempt_millis"
        private const val KEY_OUTCOME = "last_outcome"
        private const val KEY_COUNT = "last_imported_count"
    }
}
