import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_info.dart';
import 'point_manager.dart';
import 'prefs_keys.dart';
import 'streak_manager.dart';
import 'zen_mode.dart';
import 'trail_catalog.dart';

class Achievement {
  final String id;
  final String name;
  final String description;
  final String icon; // Emoji icon
  final String category; // 'milestone', 'exploration', 'mastery', 'streak', 'special'
  final int rewardPoints;
  final String? rewardTitle;
  final String? rewardTrailStyle; // Maintained for model compatibility, always null now

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    this.rewardPoints = 0,
    this.rewardTitle,
    this.rewardTrailStyle,
  });
}

class AchievementManager {
  static final ValueNotifier<String?> titleClaimedNotifier = ValueNotifier<String?>(null);

  static const List<Achievement> allAchievements = [
    // Milestones
    // Zen Mode — scored against zen clears only. Rewards are deliberately
    // modest because zen levels carry no modifiers.
    Achievement(
      id: 'zen_first_breath',
      name: 'First Breath',
      description: 'Clear 1 level in Zen Mode',
      icon: '🌱',
      category: 'zen',
      rewardPoints: 25,
    ),
    Achievement(
      id: 'zen_stillness',
      name: 'Stillness',
      description: 'Clear 25 levels in Zen Mode',
      icon: '🍃',
      category: 'zen',
      rewardPoints: 100,
    ),
    Achievement(
      id: 'zen_ripple',
      name: 'Ripple',
      description: 'Clear 50 levels in Zen Mode — unlocks the Zen Ripple trail',
      icon: '🌿',
      category: 'zen',
      rewardPoints: 200,
    ),
    Achievement(
      id: 'zen_deep_calm',
      name: 'Deep Calm',
      description: 'Clear 150 levels in Zen Mode',
      icon: '🧘',
      category: 'zen',
      rewardPoints: 400,
    ),
    Achievement(
      id: 'zen_master',
      name: 'Still Mind',
      // 'Zen Master' is already the title granted by the 30-day streak
      // achievement, so this one carries its own.
      description: 'Clear 400 levels in Zen Mode',
      icon: '☯️',
      category: 'zen',
      rewardPoints: 800,
      rewardTitle: 'Still Mind',
    ),

    Achievement(
      id: 'first_step',
      name: 'First Step',
      description: 'Complete 1 level total',
      icon: '⚡',
      category: 'milestone',
      rewardPoints: 50,
    ),
    Achievement(
      id: 'getting_started',
      name: 'Getting Started',
      description: 'Complete 10 levels total',
      icon: '⭐',
      category: 'milestone',
      rewardPoints: 150,
    ),
    Achievement(
      id: 'half_century',
      name: 'Half Century',
      description: 'Complete 50 levels total',
      icon: '🎖️',
      category: 'milestone',
      rewardPoints: 250,
    ),
    Achievement(
      id: 'centurion',
      name: 'Centurion',
      description: 'Complete 100 levels total',
      icon: '🏆',
      category: 'milestone',
      rewardPoints: 500,
    ),
    Achievement(
      id: 'dedication',
      name: 'Dedication',
      description: 'Complete 250 levels total',
      icon: '🔥',
      category: 'milestone',
      rewardPoints: 750,
    ),
    Achievement(
      id: 'grandmaster',
      name: 'Grandmaster',
      description: 'Complete 500 levels total',
      icon: '👑',
      category: 'milestone',
      rewardPoints: 1000,
      rewardTitle: 'Grandmaster',
    ),
    Achievement(
      id: 'legend',
      name: 'Legend',
      description: 'Complete 1000 levels total',
      icon: '✨',
      category: 'milestone',
      rewardPoints: 2500,
      rewardTitle: 'Legend',
    ),
    Achievement(
      id: 'marathon',
      name: 'Marathon',
      description: 'Complete 2500 levels total',
      icon: '🏔️',
      category: 'milestone',
      rewardPoints: 5000,
      rewardTitle: 'Ascendant',
    ),

    // Exploration
    Achievement(
      id: 'curious_mind',
      name: 'Curious Mind',
      description: 'Play 3 different games',
      icon: '🧭',
      category: 'exploration',
      rewardPoints: 100,
    ),
    Achievement(
      id: 'well_rounded',
      name: 'Well Rounded',
      description: 'Play 5 different games',
      icon: '🎯',
      category: 'exploration',
      rewardPoints: 200,
    ),
    Achievement(
      id: 'jack_of_all',
      name: 'Jack of All Trades',
      description: 'Play 10 different games',
      icon: '⚙️',
      category: 'exploration',
      rewardPoints: 400,
    ),
    Achievement(
      id: 'completionist',
      name: 'Completionist',
      // Deliberately not a number. The unlock condition is relative
      // (`playedGamesCount >= activeGames.length`), so any hardcoded count goes
      // stale the moment a game is added — it said 15 when there were 12, and 16
      // when Kakuro made it 17.
      description: 'Play every active game',
      icon: '🎒',
      category: 'exploration',
      rewardPoints: 750,
      rewardTitle: 'Completionist',
    ),

    // Mastery
    Achievement(
      id: 'apprentice',
      name: 'Apprentice',
      description: 'Complete 10 levels in any game',
      icon: '⭐',
      category: 'mastery',
      rewardPoints: 150,
      rewardTitle: 'Apprentice',
    ),
    Achievement(
      id: 'expert',
      name: 'Expert',
      description: 'Complete 25 levels in any game',
      icon: '✨',
      category: 'mastery',
      rewardPoints: 250,
      rewardTitle: 'Expert',
    ),
    Achievement(
      id: 'master',
      name: 'Master',
      description: 'Complete 50 levels in any game',
      icon: '💎',
      category: 'mastery',
      rewardPoints: 500,
      rewardTitle: 'Master',
    ),
    Achievement(
      id: 'obsessed',
      name: 'Obsessed',
      description: 'Complete 100 levels in any game',
      icon: '☄️',
      category: 'mastery',
      rewardPoints: 1000,
      rewardTitle: 'Obsessed',
    ),
    Achievement(
      id: 'into_the_deep',
      name: 'Into the Deep',
      description: 'Reach Level 90+ in any game',
      icon: '🌀',
      category: 'mastery',
      rewardPoints: 750,
      rewardTitle: 'Deep Diver',
    ),

    // Seasonal events (S3, release 2.1). Unlocked by SeasonalEventManager and
    // claimed through the normal manual-claim flow. `category: 'seasonal'` is
    // new, and this id deliberately matches no `case` in checkAndUnlock — the
    // event manager owns the unlock condition, so it must never auto-fire here.
    Achievement(
      id: 'event_spring_thaw',
      name: 'Spring Thaw',
      description: 'Clear 5 levels during the Spring Thaw event',
      icon: '🌱',
      category: 'seasonal',
      rewardPoints: 200,
    ),
    Achievement(
      id: 'event_summer_light',
      name: 'Long Light',
      description: 'Clear 5 levels during the Long Light event',
      icon: '☀️',
      category: 'seasonal',
      rewardPoints: 200,
    ),
    Achievement(
      id: 'event_autumn_harvest',
      name: 'Gathering In',
      description: 'Clear 5 levels during the Gathering In event',
      icon: '🍂',
      category: 'seasonal',
      rewardPoints: 200,
    ),
    Achievement(
      id: 'event_winter_lights',
      name: 'Winter Lights',
      description: 'Clear 5 levels during the Winter Lights event',
      icon: '❄️',
      category: 'seasonal',
      rewardPoints: 200,
    ),

    // Streak
    Achievement(
      id: 'consistent',
      name: 'Consistent',
      description: 'Maintain a 3-day daily streak',
      icon: '📅',
      category: 'streak',
      rewardPoints: 100,
    ),
    Achievement(
      id: 'weekly_warrior',
      name: 'Weekly Warrior',
      description: 'Maintain a 7-day daily streak',
      icon: '⚔️',
      category: 'streak',
      rewardPoints: 250,
      rewardTitle: 'Weekly Warrior',
    ),
    Achievement(
      id: 'monthly_grind',
      name: 'Zen Master',
      description: 'Maintain a 30-day daily streak',
      icon: '💎',
      category: 'streak',
      rewardPoints: 750,
      rewardTitle: 'Zen Master',
    ),
    Achievement(
      id: 'unbroken',
      name: 'Unbroken',
      description: 'Maintain a 100-day daily streak',
      icon: '🗓️',
      category: 'streak',
      rewardPoints: 2500,
      rewardTitle: 'Unbroken',
    ),

    // Active-day streak (S1). Scored against StreakManager's parallel
    // "played anything today" streak — Zen counts, so does a daily challenge —
    // rather than the daily-challenge-only streak the four above use.
    Achievement(
      id: 'streak_active_7',
      name: 'In Rhythm',
      description: 'Play something 7 days in a row',
      icon: '📆',
      category: 'streak',
      rewardPoints: 250,
    ),
    Achievement(
      id: 'streak_active_30',
      name: 'Month in Motion',
      description: 'Play something 30 days in a row',
      icon: '🌗',
      category: 'streak',
      rewardPoints: 750,
      rewardTitle: 'Devoted',
    ),
    Achievement(
      id: 'streak_active_100',
      name: 'Hundred Days',
      description: 'Play something 100 days in a row',
      icon: '💯',
      category: 'streak',
      rewardPoints: 2500,
      rewardTitle: 'Relentless',
    ),

    // Special
    Achievement(
      id: 'shuffle_master',
      name: 'Shuffle Master',
      description: 'Clear 10 levels in Shuffle Mode',
      icon: '🔀',
      category: 'special',
      rewardPoints: 250,
      rewardTitle: 'Shuffle Master',
    ),
    Achievement(
      id: 'perfect_memory',
      name: 'Perfect Memory',
      description: 'Reach Level 15 in Chimp Test',
      icon: '🐒',
      category: 'special',
      rewardPoints: 250,
    ),
    Achievement(
      id: 'big_board',
      name: 'Big Board',
      description: 'Clear a max-size grid',
      icon: '🔲',
      category: 'special',
      rewardPoints: 400,
    ),
    Achievement(
      id: 'flawless',
      name: 'Flawless',
      description: 'Clear 25 levels total without using a hint',
      icon: '🎯',
      category: 'special',
      rewardPoints: 400,
      rewardTitle: 'Purist',
    ),
    Achievement(
      id: 'speed_demon',
      name: 'Speed Demon',
      description: 'Clear a hard-timer level with >50% time remaining',
      icon: '⚡',
      category: 'special',
      rewardPoints: 300,
    ),
    Achievement(
      id: 'on_a_roll',
      name: 'On a Roll',
      description: 'Clear 15 levels in a row with no loss/restart',
      icon: '🔥',
      category: 'special',
      rewardPoints: 300,
    ),
    Achievement(
      id: 'stylish',
      name: 'Stylish',
      description: 'Clear 50 levels with a swipe trail active',
      icon: '🌈',
      category: 'special',
      rewardPoints: 250,
    ),
    // Trail Collector is tiered so that the early rungs stay reachable now
    // that star trails exist. Tier I keeps the original `trail_collector` id
    // *and* its original six-trail requirement, so every player who already
    // earned it keeps it and nobody's progress is quietly reset.
    Achievement(
      id: 'trail_collector',
      name: 'Trail Collector I',
      description: 'Own all 6 buyable swipe trail styles',
      icon: '🎨',
      category: 'special',
      rewardPoints: 1000,
      rewardTitle: 'Stylist',
    ),
    Achievement(
      id: 'trail_collector_ii',
      name: 'Trail Collector II',
      description: 'Add the star trails Morning Mist and Tide Line',
      icon: '🖌️',
      category: 'special',
      rewardPoints: 2000,
      rewardTitle: 'Trailblazer',
    ),
    Achievement(
      id: 'welcome_back',
      name: 'Welcome Back',
      description: 'Return and clear a level after 7+ days away',
      icon: '🔁',
      category: 'special',
      rewardPoints: 200,
    ),
  ];

  /// The trail ids a Trail Collector tier requires. Nested by design: II is
  /// I plus two, III is II plus five, so the tiers can only ever be earned in
  /// order. The lists themselves live in [TrailCatalog] with the unlock rules.
  static List<String> _collectorTier(String achievementId) {
    switch (achievementId) {
      case 'trail_collector_ii':
        return TrailCatalog.collectorTierII;
      default:
        return TrailCatalog.collectorTierI;
    }
  }

  static Future<void> resetClearStreak() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(PrefsKeys.clearStreak, 0);
  }

  static Future<void> registerClear(String gameId, bool hintUsed) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. noHintClears
    if (!hintUsed) {
      final nhc = (prefs.getInt(PrefsKeys.noHintClears) ?? 0) + 1;
      await prefs.setInt(PrefsKeys.noHintClears, nhc);
    }

    // 2. clearStreak
    final streak = (prefs.getInt(PrefsKeys.clearStreak) ?? 0) + 1;
    await prefs.setInt(PrefsKeys.clearStreak, streak);

    // 3. trailActiveClears
    final activeStyle = prefs.getString(PrefsKeys.swipeTrailStyle) ?? 'none';
    if (activeStyle != 'none') {
      final tac = (prefs.getInt(PrefsKeys.trailActiveClears) ?? 0) + 1;
      await prefs.setInt(PrefsKeys.trailActiveClears, tac);
    }

    // 4. welcome_back / lastPlayedDate
    final now = DateTime.now();
    final lastPlayedStr = prefs.getString(PrefsKeys.lastPlayedDate);
    if (lastPlayedStr != null) {
      try {
        final lastPlayed = DateTime.parse(lastPlayedStr);
        final difference = now.difference(lastPlayed).inDays;
        if (difference >= 7) {
          await prefs.setBool('welcome_back_earned', true);
        }
      } catch (_) {}
    }
    await prefs.setString(PrefsKeys.lastPlayedDate, now.toIso8601String());
  }

  static Future<List<Achievement>> checkAndUnlock(String currentGameId) async {
    final prefs = await SharedPreferences.getInstance();
    final unlocked = prefs.getStringList(PrefsKeys.unlockedAchievements) ?? [];
    final newlyUnlocked = <Achievement>[];

    // Read current stats
    final globalClears = prefs.getInt(PrefsKeys.globalLevelClearedCount) ?? 0;
    // The live daily system writes dailyV2Streak; dailyStreak is the V1 key
    // and is now only ever read. Using it alone made every streak
    // achievement impossible to unlock. Take whichever is higher so
    // pre-migration progress still counts.
    final dailyStreak = max(
      prefs.getInt(PrefsKeys.dailyV2Streak) ?? 0,
      prefs.getInt(PrefsKeys.dailyStreak) ?? 0,
    );
    final shuffleClears = prefs.getInt(PrefsKeys.shuffleClears) ?? 0;
    // S1's parallel active-day streak. Kept separate from dailyStreak above so
    // that "played anything today" can never satisfy a daily-challenge badge.
    final activeStreak = prefs.getInt(StreakManager.activeStreakKey) ?? 0;

    // Get per-game stats
    final activeGames = kAllGames.where((g) => !g.isStashed).toList();
    int playedGamesCount = 0;
    int maxLevelReached = 0;

    // Challenge achievements must measure Challenge progress explicitly. The
    // plain gameLevel() key follows whichever mode is active, so reading it
    // here would score zen progress against these achievements.
    for (final game in activeGames) {
      final level = prefs.getInt(PrefsKeys.normalGameLevel(game.id)) ?? 0;
      if (level > 0) {
        playedGamesCount++;
      }
      if (level > maxLevelReached) {
        maxLevelReached = level;
      }
    }

    final levelChimp = prefs.getInt(PrefsKeys.normalGameLevel('chimp')) ?? 0;

    for (final a in allAchievements) {
      if (unlocked.contains(a.id)) continue;
      // Zen achievements are scored against zen clears in checkAndUnlockZen.
      if (a.category == 'zen') continue;

      bool conditionMet = false;

      switch (a.id) {
        // Milestones
        case 'first_step':
          conditionMet = globalClears >= 1;
          break;
        case 'getting_started':
          conditionMet = globalClears >= 10;
          break;
        case 'half_century':
          conditionMet = globalClears >= 50;
          break;
        case 'centurion':
          conditionMet = globalClears >= 100;
          break;
        case 'dedication':
          conditionMet = globalClears >= 250;
          break;
        case 'grandmaster':
          conditionMet = globalClears >= 500;
          break;
        case 'legend':
          conditionMet = globalClears >= 1000;
          break;
        case 'marathon':
          conditionMet = globalClears >= 2500;
          break;

        // Exploration
        case 'curious_mind':
          conditionMet = playedGamesCount >= 3;
          break;
        case 'well_rounded':
          conditionMet = playedGamesCount >= 5;
          break;
        case 'jack_of_all':
          conditionMet = playedGamesCount >= 10;
          break;
        case 'completionist':
          conditionMet = playedGamesCount >= activeGames.length;
          break;

        // Mastery
        case 'apprentice':
          conditionMet = maxLevelReached >= 10;
          break;
        case 'expert':
          conditionMet = maxLevelReached >= 25;
          break;
        case 'master':
          conditionMet = maxLevelReached >= 50;
          break;
        case 'obsessed':
          conditionMet = maxLevelReached >= 100;
          break;
        case 'into_the_deep':
          conditionMet = maxLevelReached >= 90;
          break;

        // Streak
        case 'consistent':
          conditionMet = dailyStreak >= 3;
          break;
        case 'weekly_warrior':
          conditionMet = dailyStreak >= 7;
          break;
        case 'monthly_grind':
          conditionMet = dailyStreak >= 30;
          break;
        case 'unbroken':
          conditionMet = dailyStreak >= 100;
          break;
        case 'streak_active_7':
          conditionMet = activeStreak >= 7;
          break;
        case 'streak_active_30':
          conditionMet = activeStreak >= 30;
          break;
        case 'streak_active_100':
          conditionMet = activeStreak >= 100;
          break;

        // Special
        case 'shuffle_master':
          conditionMet = shuffleClears >= 10;
          break;
        case 'perfect_memory':
          conditionMet = levelChimp >= 15;
          break;
        case 'big_board':
          conditionMet = prefs.getBool(PrefsKeys.bigBoardCleared) ?? false;
          break;
        case 'flawless':
          final nhc = prefs.getInt(PrefsKeys.noHintClears) ?? 0;
          conditionMet = nhc >= 25;
          break;
        case 'speed_demon':
          conditionMet = prefs.getBool(PrefsKeys.speedDemonEarned) ?? false;
          break;
        case 'on_a_roll':
          final cs = prefs.getInt(PrefsKeys.clearStreak) ?? 0;
          conditionMet = cs >= 15;
          break;
        case 'stylish':
          final tac = prefs.getInt(PrefsKeys.trailActiveClears) ?? 0;
          conditionMet = tac >= 50;
          break;
        case 'trail_collector':
        case 'trail_collector_ii':
        case 'trail_collector_iii':
          final claimedTrails =
              prefs.getStringList(PrefsKeys.claimedTrailStyles) ?? ['none'];
          conditionMet = _collectorTier(a.id)
              .every((id) => claimedTrails.contains(id));
          break;
        case 'welcome_back':
          conditionMet = prefs.getBool('welcome_back_earned') ?? false;
          break;
      }

      if (conditionMet) {
        unlocked.add(a.id);
        newlyUnlocked.add(a);
      }
    }

    if (newlyUnlocked.isNotEmpty) {
      await prefs.setStringList(PrefsKeys.unlockedAchievements, unlocked);
    }

    return newlyUnlocked;
  }

  /// Zen-only achievements, scored against the separate zen clear tally.
  ///
  /// Kept apart from [checkAndUnlock] so that Challenge achievements can never
  /// be satisfied by zen play, which has no modifiers and is therefore easier.
  static Future<List<Achievement>> checkAndUnlockZen(int zenClears) async {
    final prefs = await SharedPreferences.getInstance();
    final unlocked = prefs.getStringList(PrefsKeys.unlockedAchievements) ?? [];
    final newlyUnlocked = <Achievement>[];

    for (final a in allAchievements) {
      if (a.category != 'zen') continue;
      if (unlocked.contains(a.id)) continue;

      bool conditionMet = false;
      switch (a.id) {
        case 'zen_first_breath':
          conditionMet = zenClears >= 1;
          break;
        case 'zen_stillness':
          conditionMet = zenClears >= 25;
          break;
        case 'zen_ripple':
          conditionMet = zenClears >= kZenTrailRequiredClears;
          break;
        case 'zen_deep_calm':
          conditionMet = zenClears >= 150;
          break;
        case 'zen_master':
          conditionMet = zenClears >= 400;
          break;
      }

      if (conditionMet) {
        unlocked.add(a.id);
        newlyUnlocked.add(a);
      }
    }

    if (newlyUnlocked.isNotEmpty) {
      await prefs.setStringList(PrefsKeys.unlockedAchievements, unlocked);
    }

    return newlyUnlocked;
  }

  static Future<bool> claim(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final unlocked = prefs.getStringList(PrefsKeys.unlockedAchievements) ?? [];
    final claimed = prefs.getStringList(PrefsKeys.claimedAchievements) ?? [];

    if (!unlocked.contains(id) || claimed.contains(id)) {
      return false;
    }

    // Find the achievement
    Achievement? target;
    for (final a in allAchievements) {
      if (a.id == id) {
        target = a;
        break;
      }
    }

    if (target == null) return false;

    // Dispatch rewards
    if (target.rewardPoints > 0) {
      await PointManager.addPoints(target.rewardPoints);
    }
    if (target.rewardTitle != null) {
      final titles = prefs.getStringList(PrefsKeys.unlockedTitles) ?? [];
      if (!titles.contains(target.rewardTitle!)) {
        titles.add(target.rewardTitle!);
        await prefs.setStringList(PrefsKeys.unlockedTitles, titles);
      }
    }

    claimed.add(id);
    await prefs.setStringList(PrefsKeys.claimedAchievements, claimed);
    return true;
  }

  static Future<List<String>> getClaimedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(PrefsKeys.claimedAchievements) ?? [];
  }

  static Future<List<String>> getUnlockedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(PrefsKeys.unlockedAchievements) ?? [];
  }

  static Future<double> getProgress(Achievement a) async {
    final prefs = await SharedPreferences.getInstance();
    final globalClears = prefs.getInt(PrefsKeys.globalLevelClearedCount) ?? 0;
    // The live daily system writes dailyV2Streak; dailyStreak is the V1 key
    // and is now only ever read. Using it alone made every streak
    // achievement impossible to unlock. Take whichever is higher so
    // pre-migration progress still counts.
    final dailyStreak = max(
      prefs.getInt(PrefsKeys.dailyV2Streak) ?? 0,
      prefs.getInt(PrefsKeys.dailyStreak) ?? 0,
    );
    final shuffleClears = prefs.getInt(PrefsKeys.shuffleClears) ?? 0;
    final activeStreak = prefs.getInt(StreakManager.activeStreakKey) ?? 0;

    final activeGames = kAllGames.where((g) => !g.isStashed).toList();
    int playedGamesCount = 0;
    int maxLevelReached = 0;

    for (final game in activeGames) {
      final level = prefs.getInt(PrefsKeys.normalGameLevel(game.id)) ?? 0;
      if (level > 0) playedGamesCount++;
      if (level > maxLevelReached) maxLevelReached = level;
    }

    final levelChimp = prefs.getInt(PrefsKeys.normalGameLevel('chimp')) ?? 0;

    if (a.category == 'zen') {
      final zenClears = prefs.getInt(ZenMode.zenClearedCountKey) ?? 0;
      switch (a.id) {
        case 'zen_first_breath':
          return (zenClears / 1.0).clamp(0.0, 1.0);
        case 'zen_stillness':
          return (zenClears / 25.0).clamp(0.0, 1.0);
        case 'zen_ripple':
          return (zenClears / kZenTrailRequiredClears).clamp(0.0, 1.0);
        case 'zen_deep_calm':
          return (zenClears / 150.0).clamp(0.0, 1.0);
        case 'zen_master':
          return (zenClears / 400.0).clamp(0.0, 1.0);
      }
      return 0.0;
    }

    switch (a.id) {
      // Milestones
      case 'first_step':
        return (globalClears / 1.0).clamp(0.0, 1.0);
      case 'getting_started':
        return (globalClears / 10.0).clamp(0.0, 1.0);
      case 'half_century':
        return (globalClears / 50.0).clamp(0.0, 1.0);
      case 'centurion':
        return (globalClears / 100.0).clamp(0.0, 1.0);
      case 'dedication':
        return (globalClears / 250.0).clamp(0.0, 1.0);
      case 'grandmaster':
        return (globalClears / 500.0).clamp(0.0, 1.0);
      case 'legend':
        return (globalClears / 1000.0).clamp(0.0, 1.0);
      case 'marathon':
        return (globalClears / 2500.0).clamp(0.0, 1.0);

      // Exploration
      case 'curious_mind':
        return (playedGamesCount / 3.0).clamp(0.0, 1.0);
      case 'well_rounded':
        return (playedGamesCount / 5.0).clamp(0.0, 1.0);
      case 'jack_of_all':
        return (playedGamesCount / 10.0).clamp(0.0, 1.0);
      case 'completionist':
        return (playedGamesCount / activeGames.length.toDouble()).clamp(0.0, 1.0);

      // Mastery
      case 'apprentice':
        return (maxLevelReached / 10.0).clamp(0.0, 1.0);
      case 'expert':
        return (maxLevelReached / 25.0).clamp(0.0, 1.0);
      case 'master':
        return (maxLevelReached / 50.0).clamp(0.0, 1.0);
      case 'obsessed':
        return (maxLevelReached / 100.0).clamp(0.0, 1.0);
      case 'into_the_deep':
        return (maxLevelReached / 90.0).clamp(0.0, 1.0);

      // Streak
      case 'consistent':
        return (dailyStreak / 3.0).clamp(0.0, 1.0);
      case 'weekly_warrior':
        return (dailyStreak / 7.0).clamp(0.0, 1.0);
      case 'monthly_grind':
        return (dailyStreak / 30.0).clamp(0.0, 1.0);
      case 'unbroken':
        return (dailyStreak / 100.0).clamp(0.0, 1.0);
      case 'streak_active_7':
        return (activeStreak / 7.0).clamp(0.0, 1.0);
      case 'streak_active_30':
        return (activeStreak / 30.0).clamp(0.0, 1.0);
      case 'streak_active_100':
        return (activeStreak / 100.0).clamp(0.0, 1.0);

      // Special
      case 'shuffle_master':
        return (shuffleClears / 10.0).clamp(0.0, 1.0);
      case 'perfect_memory':
        return (levelChimp / 15.0).clamp(0.0, 1.0);
      case 'big_board':
        return (prefs.getBool(PrefsKeys.bigBoardCleared) ?? false) ? 1.0 : 0.0;
      case 'flawless':
        final nhc = prefs.getInt(PrefsKeys.noHintClears) ?? 0;
        return (nhc / 25.0).clamp(0.0, 1.0);
      case 'speed_demon':
        return (prefs.getBool(PrefsKeys.speedDemonEarned) ?? false) ? 1.0 : 0.0;
      case 'on_a_roll':
        final cs = prefs.getInt(PrefsKeys.clearStreak) ?? 0;
        return (cs / 15.0).clamp(0.0, 1.0);
      case 'stylish':
        final tac = prefs.getInt(PrefsKeys.trailActiveClears) ?? 0;
        return (tac / 50.0).clamp(0.0, 1.0);
      case 'trail_collector':
      case 'trail_collector_ii':
      case 'trail_collector_iii':
        final claimedTrails =
            prefs.getStringList(PrefsKeys.claimedTrailStyles) ?? ['none'];
        final tier = _collectorTier(a.id);
        final count = tier.where((t) => claimedTrails.contains(t)).length;
        return (count / tier.length).clamp(0.0, 1.0);
      case 'welcome_back':
        return (prefs.getBool('welcome_back_earned') ?? false) ? 1.0 : 0.0;
      default:
        return 0.0;
    }
  }
}
