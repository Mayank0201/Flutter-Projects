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
  static final Map<String, bool> _hintUsedThisLevel = {};
  static bool _lastClearWasSuccessful = false;

  static Future<int> getHints(String gameId) async {
    // 1. Reset hint-used flag for the current level
    _hintUsedThisLevel[gameId] = false;

    // 2. Check if we failed/restarted without clearing the last level
    if (!_lastClearWasSuccessful) {
      await AchievementManager.resetClearStreak();
    }
    _lastClearWasSuccessful = false; // Reset clear check for the new level

    final prefs = await SharedPreferences.getInstance();
    final key = PrefsKeys.gameHints(gameId);
    if (!prefs.containsKey(key)) {
      await prefs.setInt(key, 1); // 1 free hint at the start
      return 1;
    }
    return prefs.getInt(key) ?? 1;
  }

  static Future<void> useHint(String gameId) async {
    _hintUsedThisLevel[gameId] = true;

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

  static Future<bool> onLevelCleared(
    String gameId, {
    bool isBigBoard = false,
    bool isSpeedDemon = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final hintUsed = _hintUsedThisLevel[gameId] ?? false;
    _lastClearWasSuccessful = true; // Committed success!

    // Save achievement flags
    if (isBigBoard) {
      await prefs.setBool(PrefsKeys.bigBoardCleared, true);
    }
    if (isSpeedDemon) {
      await prefs.setBool(PrefsKeys.speedDemonEarned, true);
    }

    // Register stats in AchievementManager
    await AchievementManager.registerClear(gameId, hintUsed);

    // Increment shuffle clears if shuffle is active
    if (await ShuffleManager.isActive()) {
      final sc = (prefs.getInt(PrefsKeys.shuffleClears) ?? 0) + 1;
      await prefs.setInt(PrefsKeys.shuffleClears, sc);
    }

    // Increment game-specific clear count
    final key = PrefsKeys.clearedCount(gameId);
    final count = (prefs.getInt(key) ?? 0) + 1;
    await prefs.setInt(key, count);

    // Increment global clear count
    final globalKey = PrefsKeys.globalLevelClearedCount;
    final globalCount = (prefs.getInt(globalKey) ?? 0) + 1;
    await prefs.setInt(globalKey, globalCount);

    // Show interstitial ad strictly every 20 levels cleared
    if (count > 0 && count % 20 == 0) {
      AdManager.showInterstitialAd();
    }

    // Check and trigger swipe trail unlock toasts (milestones ladder: 30, 100, 250)
    if (globalCount == 30 || globalCount == 100 || globalCount == 250) {
      String name = "";
      String emoji = "";
      String styleId = "";
      
      if (globalCount == 30) {
        name = "Game Accent";
        emoji = "🎯";
        styleId = "accent";
      } else if (globalCount == 100) {
        name = "Sparkle Stars";
        emoji = "✨";
        styleId = "sparkle";
      } else if (globalCount == 250) {
        name = "Pastel Glow";
        emoji = "🌸";
        styleId = "pastel";
      }

      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        TrailUnlockToast.show(context, name, emoji, styleId);
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

    return false;
  }
}
