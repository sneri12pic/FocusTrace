package com.stepandemianenko.focustrace

import android.content.Context
import android.content.pm.ApplicationInfo
import android.os.Build
import android.security.keystore.KeyInfo
import android.util.Log
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.xmlpull.v1.XmlPullParser
import java.io.File
import java.security.KeyStore
import javax.crypto.SecretKey
import javax.crypto.SecretKeyFactory

/**
 * The production [SecureCredentialStore] against a real AndroidKeyStore.
 *
 * The JVM unit test can only reach the fail-closed path, because there is no
 * keystore provider off-device. Everything the keystore actually does -
 * generating the key, sealing the token, refusing a blob it did not seal - is
 * proven here and nowhere else.
 */
@RunWith(AndroidJUnit4::class)
class SecureCredentialStoreInstrumentedTest {
    private val context: Context
        get() = InstrumentationRegistry.getInstrumentation().targetContext

    @Before
    fun startClean() {
        SecureCredentialStore.clear(context)
    }

    @After
    fun leaveClean() {
        SecureCredentialStore.clear(context)
    }

    @Test
    fun writesAndReadsBackTheSameCredential() {
        SecureCredentialStore.write(context, REFRESH_TOKEN)

        assertEquals(REFRESH_TOKEN, SecureCredentialStore.read(context))
    }

    /** Regression: `apply()` here left a rotated token unflushed on a crash. */
    @Test
    fun theCredentialIsOnDiskBeforeWriteReturns() {
        SecureCredentialStore.write(context, REFRESH_TOKEN)

        assertNotNull("write returned before the value reached disk", rawStoredValue())
    }

    @Test
    fun readsNullWhenNothingIsStored() {
        assertNull(SecureCredentialStore.read(context))
    }

    @Test
    fun rotationReplacesTheStoredCredential() {
        SecureCredentialStore.write(context, REFRESH_TOKEN)
        SecureCredentialStore.write(context, ROTATED_TOKEN)

        assertEquals(ROTATED_TOKEN, SecureCredentialStore.read(context))
    }

    @Test
    fun clearingRemovesTheCredentialFromDisk() {
        SecureCredentialStore.write(context, REFRESH_TOKEN)

        SecureCredentialStore.clear(context)

        assertNull(SecureCredentialStore.read(context))
        assertNull(rawStoredValue())
    }

    @Test
    fun nothingReadableIsStoredAtRest() {
        SecureCredentialStore.write(context, REFRESH_TOKEN)

        val sealed = rawStoredValue()
        assertNotNull(sealed)
        assertFalse(sealed!!.contains(REFRESH_TOKEN))

        // The same value written twice produces different bytes: the nonce is
        // fresh each time, so the file never reveals that nothing changed.
        SecureCredentialStore.write(context, REFRESH_TOKEN)
        assertNotEquals(sealed, rawStoredValue())
        assertEquals(REFRESH_TOKEN, SecureCredentialStore.read(context))
    }

    @Test
    fun aCorruptedValueFailsClosedAndIsDeleted() {
        SecureCredentialStore.write(context, REFRESH_TOKEN)
        // Valid base64, long enough to carry a nonce, but the GCM tag cannot
        // authenticate it.
        prefs().edit().putString(VALUE_KEY, "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA").commit()

        assertNull(SecureCredentialStore.read(context))
        assertNull(rawStoredValue())
    }

    @Test
    fun aValueSealedByAReplacedKeyFailsClosedAndIsDeleted() {
        SecureCredentialStore.write(context, REFRESH_TOKEN)
        val sealedByTheOldKey = rawStoredValue()

        // What a restored backup or a reset keystore leaves behind: the
        // ciphertext is intact and the key that made it is gone.
        keyStore().deleteEntry(KEY_ALIAS)
        prefs().edit().putString(VALUE_KEY, sealedByTheOldKey).commit()

        assertNull(SecureCredentialStore.read(context))
        assertNull(rawStoredValue())
    }

    @Test
    fun theCredentialFileIsExcludedFromBackupAndDeviceTransfer() {
        // Backup is on - no android:allowBackup="false" anywhere - so without an
        // exclusion Auto Backup would upload the credential file with the rest
        // of shared_prefs. This is what makes the rules below load-bearing.
        assertNotEquals(
            "backup is disabled; this test no longer checks what it claims",
            0,
            context.applicationInfo.flags and ApplicationInfo.FLAG_ALLOW_BACKUP,
        )

        // ApplicationInfo exposes neither fullBackupContent nor
        // dataExtractionRules publicly, so that the manifest names these files
        // is verified in the merged manifest at build time. What is checked
        // here, on the device, is that the resources it names do exclude the
        // credential file.
        for (name in listOf("backup_rules", "data_extraction_rules")) {
            val id = context.resources.getIdentifier("xml/$name", null, context.packageName)
            assertNotEquals("$name.xml is missing from the APK", 0, id)
            assertTrue("$name.xml must exclude $PREFS_NAME.xml", excludesCredentialFile(id))
        }
    }

    @Test
    fun theCredentialFileIsPrivateToTheApp() {
        SecureCredentialStore.write(context, REFRESH_TOKEN)
        val file = File(context.applicationInfo.dataDir, "shared_prefs/$PREFS_NAME.xml")
        assertTrue("expected $file to exist", file.exists())

        val mode = android.system.Os.stat(file.absolutePath).st_mode
        // Only the "other" bits matter. MODE_PRIVATE leaves group-read set, but
        // an app's group is its own uid's group, so that is not reach for
        // anything else; any other-rwx bit would be.
        assertEquals(
            "credential file mode ${Integer.toOctalString(mode)} grants access outside the app",
            0,
            mode and 0x7,
        )
    }

    /**
     * Not an assertion. Storing a key in AndroidKeyStore does not make it
     * hardware-backed, so what this device actually provides is reported rather
     * than required.
     */
    @Test
    fun reportsTheKeySecurityLevel() {
        SecureCredentialStore.write(context, REFRESH_TOKEN)
        val key = keyStore().getKey(KEY_ALIAS, null) as SecretKey
        val info = SecretKeyFactory
            .getInstance(key.algorithm, PROVIDER)
            .getKeySpec(key, KeyInfo::class.java) as KeyInfo

        val level = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            "securityLevel=${info.securityLevel}"
        } else {
            @Suppress("DEPRECATION")
            "isInsideSecureHardware=${info.isInsideSecureHardware}"
        }
        Log.i(
            REPORT_TAG,
            "alias=$KEY_ALIAS algorithm=${key.algorithm} keySize=${info.keySize} " +
                "origin=${info.origin} $level " +
                "model=${Build.MODEL} release=${Build.VERSION.RELEASE} " +
                "api=${Build.VERSION.SDK_INT}",
        )
    }

    private fun excludesCredentialFile(resourceId: Int): Boolean {
        val parser = context.resources.getXml(resourceId)
        try {
            while (parser.next() != XmlPullParser.END_DOCUMENT) {
                if (parser.eventType == XmlPullParser.START_TAG && parser.name == "exclude") {
                    // No namespace: backup rules use plain `domain`/`path`,
                    // and this is the lookup the platform's own parser does, so
                    // an android:-prefixed attribute would fail here exactly as
                    // it would fail to exclude anything on a real backup.
                    val domain = parser.getAttributeValue(null, "domain")
                    val path = parser.getAttributeValue(null, "path")
                    if (domain == "sharedpref" && path == "$PREFS_NAME.xml") {
                        return true
                    }
                }
            }
        } finally {
            parser.close()
        }
        return false
    }

    private fun prefs() = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private fun rawStoredValue(): String? = prefs().getString(VALUE_KEY, null)

    private fun keyStore() = KeyStore.getInstance(PROVIDER).apply { load(null) }

    private companion object {
        const val REFRESH_TOKEN = "refresh-token-instrumented"
        const val ROTATED_TOKEN = "refresh-token-instrumented-rotated"
        const val PROVIDER = "AndroidKeyStore"
        const val KEY_ALIAS = "focustrace_sync_credentials"
        const val PREFS_NAME = "focustrace_sync_credentials"
        const val VALUE_KEY = "refresh_token"
        const val REPORT_TAG = "FocusTraceKeyInfo"
    }
}
