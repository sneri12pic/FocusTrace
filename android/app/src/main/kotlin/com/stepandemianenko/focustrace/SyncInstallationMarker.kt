package com.stepandemianenko.focustrace

import android.content.Context

/**
 * This installation's sync identity, kept where no backup or device transfer can
 * carry it (architecture section 3).
 *
 * `sync_installation_id` also lives in the SQLite settings table, which Auto Backup
 * and device-to-device transfer copy to other installations. This file is excluded
 * from both (backup_rules.xml, data_extraction_rules.xml), so it only ever holds a
 * value written on this installation: a database whose id differs from it, or that
 * has an id while this file is empty, came from somewhere else.
 *
 * Not a secret - a random UUID the server already knows - so it is not sealed.
 */
object SyncInstallationMarker {
    fun read(context: Context): String? = prefs(context).getString(VALUE_KEY, null)

    fun write(context: Context, installationId: String) {
        // commit, not apply: the identity must be on disk before the database
        // records it, or a crash could leave a registered id without its marker.
        check(prefs(context).edit().putString(VALUE_KEY, installationId).commit()) {
            "installation marker not written"
        }
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    /** backup_rules.xml and data_extraction_rules.xml exclude "$PREFS_NAME.xml". */
    const val PREFS_NAME = "focustrace_sync_installation"
    private const val VALUE_KEY = "installation_id"
}
