package com.mayank.cogniq

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log
import android.widget.RemoteViews
import androidx.annotation.Keep
import es.antonborri.home_widget.HomeWidgetProvider

@Keep
class StreakWidgetProvider : HomeWidgetProvider() {
    companion object {
        private const val TAG = "StreakWidgetProvider"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        Log.d(TAG, "onUpdate called for ${appWidgetIds.size} widgets")
        try {
            appWidgetIds.forEach { widgetId ->
                Log.d(TAG, "Updating widget ID: $widgetId")
                
                val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                    val streak = widgetData.getInt("daily_streak", 0)
                    val totalSolved = widgetData.getInt("total_solved", 0)
                    val puzzleName = widgetData.getString("todays_puzzle_name", "Word Hive") ?: "Word Hive"
                    val puzzleDesc = widgetData.getString("todays_puzzle_desc", "Form words with honey letters") ?: "Form words with honey letters"
                    
                    val bronze = widgetData.getInt("daily_bronze_stars", 0)
                    val silver = widgetData.getInt("daily_silver_stars", 0)
                    val gold = widgetData.getInt("daily_gold_stars", 0)
                    val diamond = widgetData.getInt("daily_diamond_stars", 0)

                    Log.d(TAG, "Read SharedPreferences -> Streak: $streak, Solved: $totalSolved, Bronze: $bronze, Silver: $silver, Gold: $gold, Diamond: $diamond, Puzzle: $puzzleName")

                    // Header streak badge (short form)
                    val streakLabel = if (streak == 1) " Day" else " Days"
                    setTextViewText(R.id.streak_text, streakLabel)

                    // Stats row
                    setTextViewText(R.id.total_solved_text, totalSolved.toString())
                    setTextViewText(R.id.streak_number_text, streak.toString())

                    // Stars row
                    setTextViewText(R.id.bronze_stars_text, "★ $bronze")
                    setTextViewText(R.id.silver_stars_text, "★ $silver")
                    setTextViewText(R.id.gold_stars_text, "★ $gold")
                    setTextViewText(R.id.diamond_stars_text, "💎 $diamond")

                    // Puzzle card
                    setTextViewText(R.id.puzzle_name_text, puzzleName)
                    setTextViewText(R.id.puzzle_desc_text, puzzleDesc)

                    // Set click intent to open the app
                    val intent = Intent(context, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                                Intent.FLAG_ACTIVITY_SINGLE_TOP
                    }
                    val pendingIntent = PendingIntent.getActivity(
                        context,
                        0,
                        intent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    setOnClickPendingIntent(R.id.widget_root, pendingIntent)
                    setOnClickPendingIntent(R.id.play_button, pendingIntent)
                }
                appWidgetManager.updateAppWidget(widgetId, views)
                Log.d(TAG, "Widget ID $widgetId successfully updated")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Fatal error in onUpdate: ${e.message}", e)
        }
    }
}
