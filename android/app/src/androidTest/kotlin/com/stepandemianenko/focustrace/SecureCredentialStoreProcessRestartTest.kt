package com.stepandemianenko.focustrace

import android.content.Context
import android.os.Process
import android.util.Log
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.FixMethodOrder
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.MethodSorters

/**
 * Persistence across a real process death, not across two Kotlin objects.
 *
 * `SecureCredentialStore` is an object with no state of its own, so
 * constructing it twice proves nothing. Each step below is written to be
 * runnable on its own, because the proof is running them in separate
 * instrumentation invocations: every `am instrument` starts a fresh app
 * process, so step 2 in its own run reads what a process that no longer exists
 * wrote. Running the class in one go instead is still a valid ordered check.
 *
 * ```bash
 * RUNNER=com.stepandemianenko.focustrace.dev.test/androidx.test.runner.AndroidJUnitRunner
 * CLASS=com.stepandemianenko.focustrace.SecureCredentialStoreProcessRestartTest
 * adb shell am instrument -w -e class $CLASS#step1_writeTheCredential   $RUNNER
 * adb shell am instrument -w -e class $CLASS#step2_readItInANewProcess  $RUNNER
 * adb shell am instrument -w -e class $CLASS#step3_clearIsAlsoDurable   $RUNNER
 * ```
 */
@RunWith(AndroidJUnit4::class)
@FixMethodOrder(MethodSorters.NAME_ASCENDING)
class SecureCredentialStoreProcessRestartTest {
    private val context: Context
        get() = InstrumentationRegistry.getInstrumentation().targetContext

    @Test
    fun step1_writeTheCredential() {
        Log.i(TAG, "step1 pid=${Process.myPid()}")
        SecureCredentialStore.write(context, SURVIVING_TOKEN)

        assertEquals(SURVIVING_TOKEN, SecureCredentialStore.read(context))
    }

    @Test
    fun step2_readItInANewProcess() {
        Log.i(TAG, "step2 pid=${Process.myPid()}")
        assertEquals(
            "the credential did not survive the process that wrote it",
            SURVIVING_TOKEN,
            SecureCredentialStore.read(context),
        )
    }

    @Test
    fun step3_clearIsAlsoDurable() {
        SecureCredentialStore.clear(context)

        assertNull(SecureCredentialStore.read(context))
    }

    private companion object {
        const val SURVIVING_TOKEN = "refresh-token-across-processes"
        const val TAG = "FocusTraceRestart"
    }
}
