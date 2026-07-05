import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_info.dart';
import 'notification_manager.dart';

class ActivityTracker {
  static const String _kLastActivityKey = 'last_activity_timestamp';
  static const String _kPlayCountPrefix = 'play_count_';

  // Increments play count and updates activity timestamp
  static Future<void> trackGamePlay(String gameId) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Update last activity timestamp
    await prefs.setInt(_kLastActivityKey, DateTime.now().millisecondsSinceEpoch);
    
    // Increment play count
    final String key = '$_kPlayCountPrefix$gameId';
    final int currentCount = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, currentCount + 1);

    // Reschedule inactivity reminders and check daily challenges
    await NotificationManager.updateInactivityReminders();
    await NotificationManager.updateDailyChallengeReminder();
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
