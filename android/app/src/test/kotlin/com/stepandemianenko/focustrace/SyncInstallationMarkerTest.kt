package com.stepandemianenko.focustrace

import android.content.Context
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.xmlpull.v1.XmlPullParser

/**
 * The never-backed-up installation marker, and the rules that keep it - and the
 * sealed refresh token - out of every backup and transfer path. The rules are
 * parsed from the app's real resources; an actual restore needs a device.
 */
// Pinned to 35 like SecureCredentialStoreTest: Robolectric 4.15.1's maximum.
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class SyncInstallationMarkerTest {
    private val context: Context = RuntimeEnvironment.getApplication()

    @Test
    fun readsNullBeforeAnythingIsWritten() {
        assertNull(SyncInstallationMarker.read(context))
    }

    @Test
    fun aWrittenIdSurvivesANewPreferencesInstance() {
        SyncInstallationMarker.write(context, "0f5d2d1c-4e7b-4a3c-9d2e-1b2c3d4e5f60")

        val reread = context
            .getSharedPreferences(SyncInstallationMarker.PREFS_NAME, Context.MODE_PRIVATE)
            .getString("installation_id", null)
        assertEquals("0f5d2d1c-4e7b-4a3c-9d2e-1b2c3d4e5f60", reread)
        assertEquals(reread, SyncInstallationMarker.read(context))
    }

    /** Clearing the credential on sign-out must not take the identity with it. */
    @Test
    fun signingOutLeavesTheMarker() {
        SyncInstallationMarker.write(context, "id")

        SecureCredentialStore.clear(context)

        assertEquals("id", SyncInstallationMarker.read(context))
    }

    @Test
    fun legacyBackupRulesExcludeCredentialAndMarker() {
        assertEquals(
            mapOf("full-backup-content" to EXCLUDED),
            exclusions(R.xml.backup_rules),
        )
    }

    /** Android 12+: cloud backup and device-to-device transfer are configured separately. */
    @Test
    fun dataExtractionRulesExcludeCredentialAndMarkerFromBackupAndTransfer() {
        assertEquals(
            mapOf("cloud-backup" to EXCLUDED, "device-transfer" to EXCLUDED),
            exclusions(R.xml.data_extraction_rules),
        )
    }

    /** Section name -> excluded sharedpref paths; fails on any include or other domain. */
    private fun exclusions(resource: Int): Map<String, Set<String>> {
        val parser = context.resources.getXml(resource)
        val result = mutableMapOf<String, MutableSet<String>>()
        var section: String? = null
        while (parser.next() != XmlPullParser.END_DOCUMENT) {
            if (parser.eventType != XmlPullParser.START_TAG) continue
            when (parser.name) {
                "full-backup-content", "cloud-backup", "device-transfer" -> {
                    section = parser.name
                    result.getOrPut(parser.name) { mutableSetOf() }
                }
                "exclude" -> {
                    assertEquals("sharedpref", parser.getAttributeValue(null, "domain"))
                    result.getValue(section!!).add(parser.getAttributeValue(null, "path"))
                }
                "data-extraction-rules" -> Unit
                else -> assertTrue("unexpected rule <${parser.name}>", false)
            }
        }
        return result
    }

    private companion object {
        val EXCLUDED = setOf(
            "focustrace_sync_credentials.xml",
            "${SyncInstallationMarker.PREFS_NAME}.xml",
        )
    }
}
