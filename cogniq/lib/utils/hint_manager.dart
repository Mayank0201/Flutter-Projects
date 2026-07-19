import 'package:shared_preferences/shared_preferences.dart';
import 'ad_manager.dart';
import 'shuffle_manager.dart';
import 'point_manager.dart';
import 'achievement_manager.dart';
import '../widgets/achievement_toast.dart';
import '../widgets/trail_unlock_toast.dart';
import '../main.dart';
import 'prefs_keys.dart';

class HintManager {
  static Future<int> getHints(String gameId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = PrefsKeys.gameHints(gameId);
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
      await prefs.setInt(PrefsKeys.gameHints(gameId), current - 1);
    }
  }

  static Future<void> addHints(String gameId, int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getHints(gameId);
    await prefs.setInt(PrefsKeys.gameHints(gameId), current + amount);
  }

  static Future<bool> onLevelCleared(String gameId) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Increment shuffle clears if shuffle is active
    if (await ShuffleManager.isActive()) {
      final sc = (prefs.getInt(PrefsKeys.shuffleClears) ?? 0) + 1;
      await prefs.setInt(PrefsKeys.shuffleClears, sc);
    }

    // Increment game-specific clear count
    final key = PrefsKeys.clearedCount(gameId);
    final count = (prefs.getInt(key) ?? 0) + 1;
    await prefs.setInt(key, count);

    // Increment global clear count (retained for reference/statistics)
    final globalKey = PrefsKeys.globalLevelClearedCount;
    final globalCount = (prefs.getInt(globalKey) ?? 0) + 1;
    await prefs.setInt(globalKey, globalCount);

    // Show interstitial ad strictly every 20 levels cleared in the active game mode
    if (count > 0 && count % 20 == 0) {
      AdManager.showInterstitialAd();
    }

    // Check and trigger swipe trail unlock slide-down toast notifications
    if (globalCount == 30 || globalCount == 60 || globalCount == 120 || globalCount == 200 || globalCount == 250 || globalCount == 300) {
      String name = "";
      String emoji = "";
      if (globalCount == 30) { name = "Game Accent"; emoji = "🎯"; }
      else if (globalCount == 60) { name = "Pastel Glow"; emoji = "🌸"; }
      else if (globalCount == 120) { name = "Sparkle Stars"; emoji = "✨"; }
      else if (globalCount == 200) { name = "Neon Glow"; emoji = "⚡"; }
      else if (globalCount == 250) { name = "Rainbow Neon"; emoji = "🌈"; }
      else if (globalCount == 300) { name = "Fire Trail"; emoji = "🔥"; }

      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        TrailUnlockToast.show(context, name, emoji);
      }
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

    // Award 1 hint every 5 levels
    if (count > 0 && count % 5 == 0) {
      final current = await getHints(gameId);
      await prefs.setInt(PrefsKeys.gameHints(gameId), current + 1);
      return true; // Earned a hint!
    }

    return false; // Earned points but no hint
  }
}
