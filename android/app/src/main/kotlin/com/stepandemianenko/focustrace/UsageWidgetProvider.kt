package com.stepandemianenko.focustrace

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews

/**
 * Home screen widgets. The large one shows today's total screen time above a
 * bubble chart; the small one ([UsageWidgetSmallProvider]) is just the chart.
 */
open class UsageWidgetProvider : AppWidgetProvider() {
    protected open val large: Boolean = true

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (appWidgetId in appWidgetIds) {
            appWidgetManager.updateAppWidget(
                appWidgetId,
                buildViews(context, appWidgetManager, appWidgetId, large),
            )
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        appWidgetManager.updateAppWidget(
            appWidgetId,
            buildViews(context, appWidgetManager, appWidgetId, large),
        )
    }

    companion object {
        private const val MAX_BUBBLES = 8

        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            for (providerClass in listOf(
                UsageWidgetProvider::class.java,
                UsageWidgetSmallProvider::class.java,
            )) {
                val large = providerClass == UsageWidgetProvider::class.java
                val ids = manager.getAppWidgetIds(ComponentName(context, providerClass))
                for (id in ids) {
                    manager.updateAppWidget(id, buildViews(context, manager, id, large))
                }
            }
        }

        private fun buildViews(
            context: Context,
            manager: AppWidgetManager,
            appWidgetId: Int,
            large: Boolean,
        ): RemoteViews {
            val views = RemoteViews(
                context.packageName,
                if (large) R.layout.usage_widget else R.layout.usage_widget_small,
            )

            if (!FocusTracePermissions.hasUsageAccess(context)) {
                views.setViewVisibility(R.id.widget_bubbles, View.GONE)
                views.setViewVisibility(R.id.widget_message, View.VISIBLE)
                views.setTextViewText(
                    R.id.widget_message,
                    FocusTraceLocale.getString(context, R.string.widget_no_access),
                )
                if (large) {
                    views.setTextViewText(R.id.widget_total, "")
                }
            } else {
                val totals = UsageStats.todayTotals(context)
                    .entries
                    .sortedByDescending { it.value.totalMs }
                if (large) {
                    val totalMs = totals.sumOf { it.value.totalMs }
                    views.setTextViewText(R.id.widget_total, formatDuration(context, totalMs))
                }
                views.setViewVisibility(R.id.widget_message, View.GONE)
                views.setViewVisibility(R.id.widget_bubbles, View.VISIBLE)

                val (widthPx, heightPx) = chartSizePx(context, manager, appWidgetId, large)
                views.setImageViewBitmap(
                    R.id.widget_bubbles,
                    BubbleChartRenderer.render(
                        context,
                        widthPx,
                        heightPx,
                        totals.take(MAX_BUBBLES).map { it.key to it.value.totalMs },
                    ),
                )
            }

            if (large) {
                views.setTextViewText(
                    R.id.widget_title,
                    FocusTraceLocale.getString(context, R.string.widget_title),
                )
            }

            views.setOnClickPendingIntent(
                R.id.widget_root,
                PendingIntent.getActivity(
                    context,
                    0,
                    Intent(context, MainActivity::class.java),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
            return views
        }

        /** Chart bitmap size from the widget's current cell size, minus chrome. */
        private fun chartSizePx(
            context: Context,
            manager: AppWidgetManager,
            appWidgetId: Int,
            large: Boolean,
        ): Pair<Int, Int> {
            val options = manager.getAppWidgetOptions(appWidgetId)
            val widthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
                .takeIf { it > 0 } ?: if (large) 250 else 110
            val heightDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
                .takeIf { it > 0 } ?: if (large) 180 else 110
            val chartWidthDp = (widthDp - 28).coerceAtLeast(60)
            // The large layout spends ~52dp on the title and total lines.
            val chartHeightDp = (heightDp - 28 - if (large) 52 else 0).coerceAtLeast(60)
            val density = context.resources.displayMetrics.density
            return (chartWidthDp * density).toInt() to (chartHeightDp * density).toInt()
        }

        private fun formatDuration(context: Context, ms: Long): String {
            val minutes = ms / 60_000
            val hours = minutes / 60
            return if (hours > 0) {
                FocusTraceLocale.getString(
                    context,
                    R.string.widget_hours_minutes,
                    hours,
                    minutes % 60,
                )
            } else {
                FocusTraceLocale.getString(context, R.string.widget_minutes, minutes)
            }
        }
    }
}

class UsageWidgetSmallProvider : UsageWidgetProvider() {
    override val large: Boolean = false
}
