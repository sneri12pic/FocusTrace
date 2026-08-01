package com.stepandemianenko.focustrace

import android.content.Context
import android.content.res.Configuration
import java.util.Locale

object FocusTraceLocale {
    private const val PREFS_NAME = "focustrace_locale"
    private const val LANGUAGE_TAG_KEY = "language_tag"

    fun setLanguageTag(context: Context, languageTag: String?): Boolean {
        val normalizedTag = languageTag?.takeIf { it.isNotBlank() }
        val preferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (normalizedTag != null &&
            preferences.getString(LANGUAGE_TAG_KEY, null) == normalizedTag
        ) {
            return false
        }
        preferences.edit()
            .apply {
                if (normalizedTag == null) {
                    remove(LANGUAGE_TAG_KEY)
                } else {
                    putString(LANGUAGE_TAG_KEY, normalizedTag)
                }
            }
            .apply()
        return true
    }

    fun getString(context: Context, resourceId: Int, vararg formatArgs: Any): String {
        return localizedContext(context).getString(resourceId, *formatArgs)
    }

    fun getQuantityString(
        context: Context,
        resourceId: Int,
        quantity: Int,
        vararg formatArgs: Any,
    ): String {
        return localizedContext(context).resources.getQuantityString(
            resourceId,
            quantity,
            *formatArgs,
        )
    }

    private fun localizedContext(context: Context): Context {
        val languageTag = context
            .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(LANGUAGE_TAG_KEY, null)
            ?.takeIf { it.isNotBlank() }
            ?: return context
        val configuration = Configuration(context.resources.configuration)
        configuration.setLocale(Locale.forLanguageTag(languageTag))
        return context.createConfigurationContext(configuration)
    }
}
