import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_info.dart';
import 'notification_manager.dart';
import 'streak_manager.dart';

class ActivityTracker {
  static const String _kLastActivityKey = 'last_activity_timestamp';
  static const String _kPlayCountPrefix = 'play_count_';

  /// Per-game play-count key. Exposed rather than letting callers rebuild the
  /// string: a duplicated key prefix is how data silently splits across two
  /// keys one day (remember.md 9e). The Stats tab's "Most Played" sort reads
  /// this — it used to sort by level instead, which was simply wrong.
  static String playCountKey(String gameId) => '$_kPlayCountPrefix$gameId';

  // Increments play count and updates activity timestamp
  static Future<void> trackGamePlay(String gameId) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Update last activity timestamp
    await prefs.setInt(_kLastActivityKey, DateTime.now().millisecondsSinceEpoch);
    
    // Increment play count
    final String key = '$_kPlayCountPrefix$gameId';
    final int currentCount = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, currentCount + 1);

    // S1: any game launch — Challenge, Zen or a daily challenge — counts as an
    // active day. Repeat calls on the same calendar day are no-ops.
    await StreakManager.recordActivity();

    // Reschedule inactivity reminders and check daily challenges
    await NotificationManager.updateInactivityReminders();
    await NotificationManager.updateDailyChallengeReminder();
    await NotificationManager.updateStreakReminder();
  }

  // Get the most played game's display name
  static Future<String> getFavoriteGame() async {
    final prefs = await SharedPreferences.getInstance();
    
    String? bestGameName;
    int maxPlays = 0;
    
    for (var game in kAllGames) {
      final int plays = prefs.getInt('$_kPlayCountPrefix${game.id}') ?? 0;
      if (plays > maxPlays) {
        maxPlays = plays;
        bestGameName = game.name;
      }
    }
    
    // Default fallback if no games have been played yet
    return bestGameName ?? 'Grid Path';
  }

  // Gets the last activity timestamp (returns null if never played)
  static Future<DateTime?> getLastActivityTime() async {
    final prefs = await SharedPreferences.getInstance();
    final int? timestamp = prefs.getInt(_kLastActivityKey);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }
}
