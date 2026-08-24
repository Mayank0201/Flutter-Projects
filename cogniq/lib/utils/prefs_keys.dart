import 'zen_mode.dart';

class PrefsKeys {
  PrefsKeys._(); // Private constructor to prevent instantiation

  // General Settings
  static const String soundEnabled = 'settings_sound';
  static const String hapticEnabled = 'settings_haptic';
  static const String musicEnabled = 'settings_music';
  static const String fontScale = 'settings_font_scale';
  static const String adsRemoved = 'settings_ads_removed';

  // IQ & Profile
  static const String points = 'points';
  static const String unlockedTitles = 'user_titles';
  static const String activeTitle = 'active_title';

  // Achievements & Trail Styles
  static const String unlockedAchievements = 'unlocked_achievements';
  static const String claimedAchievements = 'claimed_achievements';
  static const String claimedTrailStyles = 'claimed_trail_styles';
  static const String swipeTrailStyle = 'swipe_trail_style';
  static const String swipeTrailCustomColor = 'swipe_trail_custom_color';

  // New Achievement Tracking Keys
  static const String noHintClears = 'no_hint_clears';
  static const String clearStreak = 'clear_streak';
  static const String trailActiveClears = 'trail_active_clears';
  static const String bigBoardCleared = 'big_board_cleared';
  static const String speedDemonEarned = 'speed_demon_earned';
  static const String lastPlayedDate = 'last_played_date';

  // Daily Challenge V2
  static const String dailyV2Migrated = 'daily_v2_migrated';
  static const String dailyUserProgressDay = 'daily_user_progress_day';
  static const String dailyChallengeStartTime = 'daily_challenge_start_time';
  static const String dailyV2LastDate = 'daily_v2_last_date';
  static const String dailyV2Streak = 'daily_v2_streak';
  static const String dailyV2PerfectDays = 'daily_v2_perfect_days';
  static const String dailyBronzeStars = 'daily_bronze_stars';
  static const String dailySilverStars = 'daily_silver_stars';
  static const String dailyGoldStars = 'daily_gold_stars';
  static const String dailyStreak = 'daily_streak'; // Legacy V1
  static const String dailyLastCompletedDate = 'daily_last_completed_date'; // Legacy V1

  // Weekly / Perfect Week Keys
  static const String weeklyPerfectStreak = 'daily_v2_perfect_streak'; // int 0..7
  static const String weeklyLastPerfectDate = 'daily_v2_last_perfect_date'; // String YYYY-MM-DD
  static const String diamondStars = 'daily_diamond_stars'; // int
  static const String perfectWeekHistory = 'daily_perfect_week_history'; // List<String> dates
  static const String weeklyResetV3Done = 'daily_v3_weekly_reset_completed'; // bool migration flag

  // IAP
  static const String bundleGranted = 'iap_starter_bundle_granted'; // bool
  static const String processedPurchaseIds = 'iap_processed_purchase_ids'; // List<String>

  // Active Daily Challenge Modifiers
  static const String playDailyMode = 'play_daily_mode';
  static const String dailyModifierType = 'daily_modifier_type';
  static const String dailyModifierName = 'daily_modifier_name';
  static const String dailyModifierDesc = 'daily_modifier_desc';
  static const String dailyModifierDifficulty = 'daily_modifier_difficulty';
  static const String dailyModifierExtraParams = 'daily_modifier_extra_params';

  // Game Progress & Stats
  static const String globalLevelClearedCount = 'global_level_cleared_count';

  // ── S1: active-day streak (release 2.0) ──────────────────────────────────
  // Deliberately parallel to the daily-challenge streak rather than replacing
  // it: `dailyV2Streak`/`dailyStreak` still drive the original badges, and this
  // counter tracks "played anything today" so free play sustains a streak too.
  // Streak keys live in StreakManager (activeStreakKey, lastActiveDateKey,
  // longestActiveStreakKey, skipMonthUsedKey) and analytics consent keys in
  // Analytics (prefsKeyConsentGranted, prefsKeyConsentPromptSeen,
  // prefsKeyInstallId). Mirrors of them used to sit here; nothing referenced
  // the mirrors, and an unenforced duplicate of a key string is how data gets
  // silently split across two keys one day (remember.md 9e). Read them from
  // their owners.
  static const String analyticsPendingEvents = 'analytics_pending_events';
  static const String analyticsBufferSchemaVersion = 'analytics_buffer_schema_version';
  static const String shuffleMode = 'shuffle_mode';
  static const String shuffleClears = 'shuffle_clears';
  static const String shuffleEnabledGames = 'shuffle_enabled_games';
  static const String recentlyPlayedGames = 'recently_played_games';

  // Notifications
  static const String testInstallNotificationScheduled = 'test_install_notification_scheduled';

  // Backups
  static const String dailyBackupActiveGame = 'daily_backup_active_game';

  // Spectrum Mid-Game State
  static const String spectrumMidLevelIndex = 'spectrum_mid_levelIndex';
  static const String spectrumMidCTL = 'spectrum_mid_cTL';
  static const String spectrumMidCTR = 'spectrum_mid_cTR';
  static const String spectrumMidCBL = 'spectrum_mid_cBL';
  static const String spectrumMidCBR = 'spectrum_mid_cBR';
  static const String spectrumMidLayout = 'spectrum_mid_layout';

  // Dynamic Key Helpers
  static const String hasSeenShuffleTutorial = 'has_seen_shuffle_tutorial';
  static const String shownDailyChallengePopupV1 = 'shown_daily_challenge_popup_v1';

  // First-run app tour (AppTourDialog). Set as soon as the tour is offered, not
  // when it is finished, so a player who quits mid-tour is not shown it again
  // on every cold start. Versioned so a future rewrite of the tour can be
  // re-offered to existing players without disturbing this one.
  static const String hasSeenAppTour = 'has_seen_app_tour_v1';

  // These four are mode-aware: in Zen Mode they resolve to a parallel set of
  // keys so zen play keeps its own level record, mid-game save and stats, and
  // never overwrites the player's Challenge progress. Anything that must always
  // address Challenge progress regardless of mode (the daily-challenge backup
  // and restore path) has to use the explicit `normal*` variants below.
  static String gameLevel(String gameId) =>
      ZenMode.isEnabled ? ZenMode.zenGameLevel(gameId) : normalGameLevel(gameId);
  static String clearedCount(String gameId) => ZenMode.isEnabled
      ? ZenMode.zenClearedCount(gameId)
      : normalClearedCount(gameId);
  static String normalGameState(String gameId) =>
      ZenMode.isEnabled ? 'zen_${gameId}_state' : 'normal_${gameId}_state';
  // Zen and Challenge number their levels independently, so the saved path for
  // "level 3" must not collide between the two modes.
  static String zipPath(int levelIndex) =>
      ZenMode.isEnabled ? 'zen_zip_path_$levelIndex' : 'zip_path_$levelIndex';

  /// Always the Challenge-mode level key, whatever mode is active.
  static String normalGameLevel(String gameId) => 'level_$gameId';

  /// Always the Challenge-mode clear tally, whatever mode is active.
  static String normalClearedCount(String gameId) => 'cleared_count_$gameId';

  static String gameHints(String gameId) => 'hints_$gameId';
  static String gameStreak(String gameId) => 'streak_$gameId';
  static String dailyV2Completed(String difficulty, String dateStr) =>
      'daily_v2_completed_${difficulty.toLowerCase()}_$dateStr';
  static String dailyV2Perfect(String dateStr) => 'daily_v2_perfect_$dateStr';
  static String dailyBackupGame(String gameId) => 'daily_backup_$gameId';
  static String dailyStarForDate(String dateStr) => 'daily_star_for_date_$dateStr';
}
