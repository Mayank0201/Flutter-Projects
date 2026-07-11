import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_info.dart';
import 'point_manager.dart';

class Achievement {
  final String id;
  final String name;
  final String description;
  final String icon; // Emoji icon
  final String category; // 'milestone', 'exploration', 'mastery', 'streak', 'special'
  final int rewardPoints;
  final String? rewardTitle;
  final String? rewardTrailStyle;

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
  static const List<Achievement> allAchievements = [
    // Milestones
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
      description: 'Complete 100 levels total (Unlocks Swipe Trail!)',
      icon: '🏆',
      category: 'milestone',
      rewardPoints: 500,
      rewardTrailStyle: 'accent',
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
      description: 'Play all 15 active games',
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
      description: 'Complete 50 levels in any game (Unlocks Pastel Glow Trail!)',
      icon: '💎',
      category: 'mastery',
      rewardPoints: 500,
      rewardTitle: 'Master',
      rewardTrailStyle: 'pastel',
    ),
    Achievement(
      id: 'obsessed',
      name: 'Obsessed',
      description: 'Complete 100 levels in any game (Unlocks Rainbow Neon Trail!)',
      icon: '☄️',
      category: 'mastery',
      rewardPoints: 1000,
      rewardTitle: 'Obsessed',
      rewardTrailStyle: 'rainbow',
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
      name: 'Monthly Grind',
      description: 'Maintain a 30-day streak (Unlocks Sparkle Stars!)',
      icon: '💎',
      category: 'streak',
      rewardPoints: 750,
      rewardTitle: 'Zen Master',
      rewardTrailStyle: 'sparkle',
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
  ];

  static Future<List<Achievement>> checkAndUnlock(String currentGameId) async {
    final prefs = await SharedPreferences.getInstance();
    final unlocked = prefs.getStringList('unlocked_achievements') ?? [];
    final newlyUnlocked = <Achievement>[];

    // Read current stats
    final globalClears = prefs.getInt('global_level_cleared_count') ?? 0;
    final dailyStreak = prefs.getInt('daily_streak') ?? 0;
    final shuffleClears = prefs.getInt('shuffle_clears') ?? 0;

    // Get per-game stats
    final activeGames = kAllGames.where((g) => !g.isStashed).toList();
    int playedGamesCount = 0;
    int maxLevelReached = 0;

    for (final game in activeGames) {
      final level = prefs.getInt('level_${game.id}') ?? 0;
      if (level > 0) {
        playedGamesCount++;
      }
      if (level > maxLevelReached) {
        maxLevelReached = level;
      }
    }

    final levelChimp = prefs.getInt('level_chimp') ?? 0;

    for (final a in allAchievements) {
      if (unlocked.contains(a.id)) continue;

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
          conditionMet = playedGamesCount >= 15;
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

        // Special
        case 'shuffle_master':
          conditionMet = shuffleClears >= 10;
          break;
        case 'perfect_memory':
          conditionMet = levelChimp >= 15;
          break;
      }

      if (conditionMet) {
        unlocked.add(a.id);
        newlyUnlocked.add(a);

        // Dispatch rewards!
        if (a.rewardPoints > 0) {
          await PointManager.addPoints(a.rewardPoints);
        }
        if (a.rewardTitle != null) {
          final titles = prefs.getStringList('unlocked_titles') ?? [];
          if (!titles.contains(a.rewardTitle!)) {
            titles.add(a.rewardTitle!);
            await prefs.setStringList('unlocked_titles', titles);
          }
        }
        if (a.rewardTrailStyle != null) {
          // Centurion unlocks swipe trail base features
          if (a.id == 'centurion') {
            await prefs.setBool('swipe_trail_unlocked', true);
          }
          final styles = prefs.getStringList('unlocked_trail_styles') ?? ['accent'];
          if (!styles.contains(a.rewardTrailStyle!)) {
            styles.add(a.rewardTrailStyle!);
            await prefs.setStringList('unlocked_trail_styles', styles);
          }
        }
      }
    }

    if (newlyUnlocked.isNotEmpty) {
      await prefs.setStringList('unlocked_achievements', unlocked);
    }

    return newlyUnlocked;
  }

  static Future<List<String>> getUnlockedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('unlocked_achievements') ?? [];
  }

  static Future<double> getProgress(Achievement a) async {
    final prefs = await SharedPreferences.getInstance();
    final globalClears = prefs.getInt('global_level_cleared_count') ?? 0;
    final dailyStreak = prefs.getInt('daily_streak') ?? 0;
    final shuffleClears = prefs.getInt('shuffle_clears') ?? 0;

    final activeGames = kAllGames.where((g) => !g.isStashed).toList();
    int playedGamesCount = 0;
    int maxLevelReached = 0;

    for (final game in activeGames) {
      final level = prefs.getInt('level_${game.id}') ?? 0;
      if (level > 0) playedGamesCount++;
      if (level > maxLevelReached) maxLevelReached = level;
    }

    final levelChimp = prefs.getInt('level_chimp') ?? 0;

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

      // Exploration
      case 'curious_mind':
        return (playedGamesCount / 3.0).clamp(0.0, 1.0);
      case 'well_rounded':
        return (playedGamesCount / 5.0).clamp(0.0, 1.0);
      case 'jack_of_all':
        return (playedGamesCount / 10.0).clamp(0.0, 1.0);
      case 'completionist':
        return (playedGamesCount / 15.0).clamp(0.0, 1.0);

      // Mastery
      case 'apprentice':
        return (maxLevelReached / 10.0).clamp(0.0, 1.0);
      case 'expert':
        return (maxLevelReached / 25.0).clamp(0.0, 1.0);
      case 'master':
        return (maxLevelReached / 50.0).clamp(0.0, 1.0);
      case 'obsessed':
        return (maxLevelReached / 100.0).clamp(0.0, 1.0);

      // Streak
      case 'consistent':
        return (dailyStreak / 3.0).clamp(0.0, 1.0);
      case 'weekly_warrior':
        return (dailyStreak / 7.0).clamp(0.0, 1.0);
      case 'monthly_grind':
        return (dailyStreak / 30.0).clamp(0.0, 1.0);

      // Special
      case 'shuffle_master':
        return (shuffleClears / 10.0).clamp(0.0, 1.0);
      case 'perfect_memory':
        return (levelChimp / 15.0).clamp(0.0, 1.0);
      default:
        return 0.0;
    }
  }
}
