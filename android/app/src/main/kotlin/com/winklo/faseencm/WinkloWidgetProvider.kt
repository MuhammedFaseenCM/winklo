package com.winklo.faseencm

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Home-screen widget: today's three daily games, each with a tick (cleared),
 * fire and the streak (still to play), or Play, and "New puzzle at midnight".
 *
 * The app writes the rows for today and for tomorrow (HomeWidgetRepositoryImpl,
 * whose keys these must match) and the copy; this picks the rows by the
 * device's date, so the widget turns over at midnight even when the app is
 * closed. Tapping a game opens it through `winkloapp://play/<game>`, which
 * the app's router maps to the game.
 */
class WinkloWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val today = SimpleDateFormat("yyyyMMdd", Locale.US).format(Date())
        val rows = when (today) {
            widgetData.getString("winklo_day", null) -> "today"
            widgetData.getString("winklo_next_day", null) -> "next"
            else -> null
        }
        val play = widgetData.getString("winklo_play", null)
            ?: context.getString(R.string.winklo_widget_play)

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.winklo_widget)
            views.setTextViewText(
                R.id.winklo_widget_title,
                widgetData.getString("winklo_title", null)
                    ?: context.getString(R.string.winklo_widget_title),
            )
            views.setTextViewText(
                R.id.winklo_widget_footer,
                widgetData.getString("winklo_footer", null)
                    ?: context.getString(R.string.winklo_widget_footer),
            )
            views.setOnClickPendingIntent(
                R.id.winklo_widget_header,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )
            for (game in GAMES) {
                views.setTextViewText(
                    game.titleView,
                    widgetData.getString("winklo_${game.id}_title", null)
                        ?: context.getString(game.titleRes),
                )
                val status = rows?.let {
                    widgetData.getString("winklo_${game.id}_$it", null)
                } ?: play
                views.setTextViewText(game.statusView, status)
                views.setOnClickPendingIntent(
                    game.rowView,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("winkloapp://play/${game.route}"),
                    ),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private data class Game(
        val id: String,
        val route: String,
        val rowView: Int,
        val titleView: Int,
        val statusView: Int,
        val titleRes: Int,
    )

    private companion object {
        val GAMES = listOf(
            Game(
                id = "zip",
                route = "zip",
                rowView = R.id.winklo_widget_zip,
                titleView = R.id.winklo_widget_zip_title,
                statusView = R.id.winklo_widget_zip_status,
                titleRes = R.string.winklo_widget_zip,
            ),
            Game(
                id = "path_words",
                route = "path-words",
                rowView = R.id.winklo_widget_path_words,
                titleView = R.id.winklo_widget_path_words_title,
                statusView = R.id.winklo_widget_path_words_status,
                titleRes = R.string.winklo_widget_path_words,
            ),
            Game(
                id = "sudoku",
                route = "sudoku",
                rowView = R.id.winklo_widget_sudoku,
                titleView = R.id.winklo_widget_sudoku_title,
                statusView = R.id.winklo_widget_sudoku_status,
                titleRes = R.string.winklo_widget_sudoku,
            ),
        )
    }
}
