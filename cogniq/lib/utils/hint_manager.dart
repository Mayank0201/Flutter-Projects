import 'package:shared_preferences/shared_preferences.dart';
import 'ad_manager.dart';
import 'shuffle_manager.dart';
import 'point_manager.dart';
import 'achievement_manager.dart';
import '../widgets/achievement_toast.dart';
import '../widgets/trail_unlock_toast.dart';
import '../main.dart';
import 'prefs_keys.dart';
import 'seasonal_event_manager.dart';
import 'zen_mode.dart';
import 'trail_catalog.dart';

class HintManager {
  static final Map<String, bool> _hintUsedThisLevel = {};
  static bool _lastClearWasSuccessful = false;

  /// First 0-based level index at which each game's board reaches its maximum
  /// size and stays there. Drives the `big_board` achievement centrally —
  /// screens do not need to pass `isBigBoard` (the parameter survives only for
  /// compatibility). Each number is read off the game's own size function, so
  /// a rebalance that moves a plateau must update this table (the thresholds
  /// are asserted in test/big_board_achievement_test.dart).
  ///
  ///  * kakuro       — KakuroLogic.sizeFor: 8x8 from level 12
  ///  * hitori       — HitoriLogic.sizeFor: 8x8 from level 12
  ///  * slitherlink  — SlitherlinkLogic.sizeFor: 5x5 from level 12
  ///  * sandsort     — SandSortLogic.colorsFor: 6 colours / 8 tubes from
  ///                   level 54 ("the last step lands at level 54")
  ///  * untangle     — UntangleLogic.sideFor: 5x5 from level 14
  ///  * zenslide     — ZenSlideLogic.rowsFor/colsFor: 8x7 from level 66
  ///  * lightbeam    — LightBeamLogic.gridSizeFor: 8x8 from level 66
  ///  * cipherdecoder— kHardestFairLevelIndex: the ladder's hardest fair
  ///                   profile, plateau from index 20
  ///  * minesweeper  — mine_finder_screen._loadLevel: 16x16 from level 54
  ///
  /// Games whose board never grows (sudoku 4x4, chimp, word hive, ...) or
  /// whose size cycles rather than plateaus (killer sudoku 4/6, grid path
  /// 8/9, colour link 6..8) are deliberately absent.
  static const Map<String, int> _bigBoardFromLevel = {
    'kakuro': 12,
    'hitori': 12,
    'slitherlink': 12,
    'sandsort': 54,
    'untangle': 14,
    'zenslide': 66,
    'lightbeam': 66,
    'cipherdecoder': 20,
    'minesweeper': 54,
  };

  // Call this exactly ONCE per level load — this is the ONLY place that resets the
  // no-hint-used flag and checks/resets the clear streak. Every game already calls this
  // at the top of its level-init function (_loadLevel / _initLevel / _loadPersistedLevel).
  static Future<int> startLevel(String gameId) async {
    _hintUsedThisLevel[gameId] = false;

    if (!_lastClearWasSuccessful) {
      await AchievementManager.resetClearStreak();
    }
    _lastClearWasSuccessful = false;

    return getHints(gameId);
  }

  // Pure read of the current hint count. Safe to call any number of times per level
  // (after buying hints, after using a hint, on UI rebuilds, etc.) — it must NEVER
  // mutate _hintUsedThisLevel or the clear streak. That mutation belongs ONLY in
  // startLevel above. Do not add any side effects to this function.
  /// Whether a hint has been used since the last [startLevel] for [gameId].
  ///
  /// Pure read — no side effects, deliberately. The daily path needs this
  /// because every daily game skips [onLevelCleared] (it would double-pay), so
  /// the flag is set during a daily but nothing ever reads it.
  static bool wasHintUsedThisLevel(String gameId) =>
      _hintUsedThisLevel[gameId] ?? false;

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
    _hintUsedThisLevel[gameId] = true;

    final prefs = await SharedPreferences.getInstance();
    final current = await getHints(gameId); // non-mutating now — flag set above survives
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

    if (ZenMode.isEnabled) {
      await _onZenLevelCleared(prefs, gameId);
      return false;
    }

    // S3: a cleared *Challenge* level is what the seasonal badge claims to
    // count. This was wired to ActivityTracker.trackGamePlay in 2.1, which
    // fires on game LAUNCH — so "Clear 5 levels during the event" was earned by
    // opening a game five times and quitting each time. That shipped in
    // 2.1.0+53. No-op outside an event window; placed after the Zen guard so
    // Zen clears cannot farm event badges, matching the split this method
    // already makes everywhere else.
    await SeasonalEventManager.recordProgress();

    // Save achievement flags.
    //
    // Big Board is decided HERE, not by the caller: every screen in
    // [_bigBoardFromLevel] saves `level_<id> = cleared + 1` (forward-only, via
    // ProgressGuard or an equivalent write) BEFORE calling this method, so the
    // stored Challenge level minus one is the level the player has just — or
    // at some point — cleared. Because ProgressGuard never lowers the level, a
    // stored value past the plateau proves a max-size board was cleared even
    // when the player is currently replaying an early level. The `isBigBoard`
    // parameter is kept for compatibility but nothing needs to pass it.
    final bigBoardAt = _bigBoardFromLevel[gameId];
    if (bigBoardAt != null) {
      final storedLevel = prefs.getInt(PrefsKeys.normalGameLevel(gameId)) ?? 0;
      if (storedLevel - 1 >= bigBoardAt) {
        await prefs.setBool(PrefsKeys.bigBoardCleared, true);
      }
    }
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

    // COGNIQ-FIX:trail-toast
    // Was two mechanisms. This one tested `globalCount == 30 || == 100 || == 250`
    // with no "already notified" flag, so a milestone that ticked past while the
    // app was being killed -- or a count that ever advanced by more than one --
    // was gone for good; the player kept the trail (isEarnedByClears is a `>=`)
    // and was simply never told. There is now a single call, and TrailCatalog
    // answers it with a threshold test plus a per-style
    // `trail_unlocked_toast_<id>` flag, so nothing can be missed by arriving
    // late and nothing can be announced twice.
    final newTrails = await TrailCatalog.checkTrailUnlocks();
    if (newTrails.isNotEmpty) {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        for (final t in newTrails) {
          TrailUnlockToast.show(context, t.name, t.emoji, t.id);
        }
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

  /// Zen clears are tallied separately from Challenge clears on purpose: Zen
  /// strips the modifiers that make late levels hard, so letting zen play feed
  /// the Challenge-side counters would turn every trail and achievement into a
  /// farming exercise. Zen gets half points and its own unlock track instead.
  static Future<void> _onZenLevelCleared(
    SharedPreferences prefs,
    String gameId,
  ) async {
    final perGameKey = ZenMode.zenClearedCount(gameId);
    final perGame = (prefs.getInt(perGameKey) ?? 0) + 1;
    await prefs.setInt(perGameKey, perGame);

    final totalKey = ZenMode.zenClearedCountKey;
    final total = (prefs.getInt(totalKey) ?? 0) + 1;
    await prefs.setInt(totalKey, total);

    if (perGame > 0 && perGame % 20 == 0) {
      AdManager.showInterstitialAd();
    }

    if (total == kZenTrailRequiredClears) {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        TrailUnlockToast.show(context, 'Zen Ripple', '🌿', 'zen');
      }
    }

    // Half of the Challenge-mode reward.
    await PointManager.addPoints(5);

    final newlyUnlocked = await AchievementManager.checkAndUnlockZen(total);
    if (newlyUnlocked.isNotEmpty) {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        for (final a in newlyUnlocked) {
          AchievementToast.show(context, a);
        }
      }
    }
  }
}
