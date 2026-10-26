package com.stepandemianenko.focustrace

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Bundle

/**
 * Opened by Health Connect when the user asks why FocusTrace wants access.
 * Shows the same privacy policy as the Play listing, then gets out of the way.
 */
class HealthConnectRationaleActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(PRIVACY_POLICY_URL)))
        } catch (_: ActivityNotFoundException) {
            // No browser: nothing else to show.
        }
        finish()
    }

    companion object {
        const val PRIVACY_POLICY_URL = "https://sneri12pic.github.io/FocusTrace/privacy.html"
    }
}
