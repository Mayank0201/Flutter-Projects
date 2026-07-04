import 'package:shared_preferences/shared_preferences.dart';
import 'ad_manager.dart';

class HintManager {
  static Future<int> getHints(String gameId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'hints_$gameId';
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

  static Future<void> addHints(String gameId, int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getHints(gameId);
    await prefs.setInt('hints_$gameId', current + amount);
  }

  static Future<bool> onLevelCleared(String gameId) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Increment game-specific clear count
    final key = 'cleared_count_$gameId';
    final count = (prefs.getInt(key) ?? 0) + 1;
    await prefs.setInt(key, count);

    // Increment global clear count (retained for reference/statistics)
    final globalKey = 'global_level_cleared_count';
    final globalCount = (prefs.getInt(globalKey) ?? 0) + 1;
    await prefs.setInt(globalKey, globalCount);

    // Show interstitial ad according to progression rules:
    // Ads shown at level clears of 15, 30, 40, 50, 60, 70...
    if (count == 15 || (count >= 30 && count % 10 == 0)) {
      AdManager.showInterstitialAd();
    }

    if (count % 5 == 0) {
      final current = await getHints(gameId);
      await prefs.setInt('hints_$gameId', current + 1);
      return true; // Earned a hint!
    }
    return false;
  }
}
