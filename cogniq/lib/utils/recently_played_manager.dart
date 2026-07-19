import 'package:shared_preferences/shared_preferences.dart';
import 'prefs_keys.dart';

class RecentlyPlayedManager {
  static const String _key = PrefsKeys.recentlyPlayedGames;

  static Future<List<String>> getRecentlyPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }

  static Future<void> addGame(String gameId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    
    // Remove if exists to move to top
    list.remove(gameId);
    
    // Insert at front
    list.insert(0, gameId);
    
    // Keep top 5
    if (list.length > 5) {
      list.removeRange(5, list.length);
    }
    
    await prefs.setStringList(_key, list);
  }
}
