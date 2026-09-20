package com.stepandemianenko.focustrace

import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.RuntimeEnvironment

/**
 * The fail-closed half of the store.
 *
 * There is no `AndroidKeyStore` provider off-device, so the encrypt/decrypt
 * round trip cannot be exercised here and is deliberately not asserted; the
 * store's contract as its callers see it is covered from Dart in
 * `test/sync_repository_test.dart`. What this environment does reproduce
 * exactly is a value that cannot be decrypted - which is also what a restored
 * backup or a wiped keystore leaves behind on a real device - so the recovery
 * path is tested here, where getting it wrong would strand the user signed in
 * with a credential that can never work.
 */
// Pinned to 35: Robolectric 4.15.1 refuses an SDK above its max, and the app
// targets 36. Nothing here is version-sensitive - there is no keystore provider
// at any SDK off-device - and the real API 36 coverage is the instrumented test.
// Drop the pin when Robolectric is next upgraded.
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class SecureCredentialStoreTest {
    private val context: android.content.Context = RuntimeEnvironment.getApplication()

    @Test
    fun readsNullBeforeAnythingIsWritten() {
        assertNull(SecureCredentialStore.read(context))
    }

    @Test
    fun anUnreadableValueFailsClosedAndIsDeleted() {
        prefs().edit().putString("refresh_token", "bm90LWEtcmVhbC1ibG9i").commit()

        assertNull(SecureCredentialStore.read(context))
        // Left in place it would be retried, and fail, on every launch.
        assertNull(prefs().getString("refresh_token", null))
    }

    @Test
    fun clearIsSafeWithNothingStored() {
        SecureCredentialStore.clear(context)

        assertNull(SecureCredentialStore.read(context))
    }

    private fun prefs() =
        context.getSharedPreferences("focustrace_sync_credentials", android.content.Context.MODE_PRIVATE)
}
