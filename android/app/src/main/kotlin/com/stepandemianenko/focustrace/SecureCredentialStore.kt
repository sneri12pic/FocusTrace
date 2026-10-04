package com.stepandemianenko.focustrace

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * The sync refresh token at rest.
 *
 * Security baseline section 8: a long-lived credential must live in OS-backed
 * storage. The value is sealed with AES-GCM under a key that is generated
 * inside AndroidKeyStore and never leaves it, so the ciphertext in
 * SharedPreferences is useless on its own - including in a cloud backup, which
 * the manifest excludes anyway.
 *
 * Requires API 23 (`KeyGenParameterSpec`, AES in AndroidKeyStore), which is why
 * `minSdk` is pinned to 23 in `build.gradle.kts`.
 *
 * Every failure path fails closed: an unreadable value is deleted and reported
 * as "no credential", which returns the app to an unauthenticated state rather
 * than presenting something the server would reject anyway.
 */
object SecureCredentialStore {
    fun read(context: Context): String? {
        val stored = prefs(context).getString(VALUE_KEY, null) ?: return null
        return try {
            val sealed = Base64.decode(stored, Base64.NO_WRAP)
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(
                Cipher.DECRYPT_MODE,
                existingKey() ?: throw IllegalStateException("key is gone"),
                GCMParameterSpec(TAG_BITS, sealed, 0, IV_BYTES),
            )
            String(
                cipher.doFinal(sealed, IV_BYTES, sealed.size - IV_BYTES),
                Charsets.UTF_8,
            )
        } catch (error: Exception) {
            // Key lost with a factory reset or a restored-from-backup blob,
            // truncated value, tampering. None of them are recoverable and all
            // of them mean the same thing: this installation is signed out.
            clear(context)
            null
        }
    }

    fun write(context: Context, value: String) {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, existingKey() ?: generateKey())
        val sealed = cipher.iv + cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        // commit, not apply: this must be on disk before the call returns.
        // `apply` writes in the background, and the window it opens is not
        // "sign in again" - on a rotation the file still holds the token the
        // server has just consumed, and presenting that one trips replay
        // detection and revokes the whole session chain. The write is small and
        // happens only on sign-in and rotation.
        prefs(context)
            .edit()
            .putString(VALUE_KEY, Base64.encodeToString(sealed, Base64.NO_WRAP))
            .commit()
    }

    fun clear(context: Context) {
        // Also synchronous: a logout that reports success must not leave the
        // credential on disk behind it.
        prefs(context).edit().remove(VALUE_KEY).commit()
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private fun existingKey(): SecretKey? {
        val keyStore = KeyStore.getInstance(PROVIDER).apply { load(null) }
        return keyStore.getKey(KEY_ALIAS, null) as? SecretKey
    }

    private fun generateKey(): SecretKey {
        val generator =
            KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, PROVIDER)
        generator.init(
            KeyGenParameterSpec
                .Builder(
                    KEY_ALIAS,
                    KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
                )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .build(),
        )
        return generator.generateKey()
    }

    private const val PROVIDER = "AndroidKeyStore"
    private const val KEY_ALIAS = "focustrace_sync_credentials"
    private const val PREFS_NAME = "focustrace_sync_credentials"
    private const val VALUE_KEY = "refresh_token"
    private const val TRANSFORMATION = "AES/GCM/NoPadding"

    /** GCM's nonce, written in front of the ciphertext. */
    private const val IV_BYTES = 12
    private const val TAG_BITS = 128
}
