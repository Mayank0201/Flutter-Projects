import 'package:shared_preferences/shared_preferences.dart';
import 'ad_manager.dart';
import 'shuffle_manager.dart';
import 'point_manager.dart';
import 'achievement_manager.dart';
import '../widgets/achievement_toast.dart';
import '../main.dart';

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
    
    // Increment shuffle clears if shuffle is active
    if (await ShuffleManager.isActive()) {
      final sc = (prefs.getInt('shuffle_clears') ?? 0) + 1;
      await prefs.setInt('shuffle_clears', sc);
    }

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

    // Award 10 points on every level clear
    await PointManager.addPoints(10);

    // Check and unlock achievements
    final newlyUnlocked = await AchievementManager.checkAndUnlock(gameId);
    if (newlyUnlocked.isNotEmpty) {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        for (final a in newlyUnlocked) {
          AchievementToast.show(context, a);
        }
      }
    }

    return true; // Earned points!
  }
}
