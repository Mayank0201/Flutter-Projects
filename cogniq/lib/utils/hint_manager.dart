import'package:shared_preferences/shared_preferences.dart';

class HintManager {
  static Future<int> getHints(String gameId) async {
    final prefs = await SharedPreferences.getInstance();
    final key ='hints_$gameId';
    if (!prefs.containsKey(key)) {
      await prefs.setInt(key, 1); // 1 free hint at the start
      return 1;
    }
    return prefs.getInt(key) ?? 1;
  }

  static Future<void> useHint(String gameId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getHints(gameId);
    if (current > 0) {
      await prefs.setInt('hints_$gameId', current - 1);
    }
  }

  static Future<bool> onLevelCleared(String gameId) async {
    final prefs = await SharedPreferences.getInstance();
    final key ='cleared_count_$gameId';
    final count = (prefs.getInt(key) ?? 0) + 1;
    await prefs.setInt(key, count);

    if (count % 4 == 0) {
      final current = await getHints(gameId);
      await prefs.setInt('hints_$gameId', current + 1);
      return true; // Earned a hint!
    }
    return false;
  }
}
