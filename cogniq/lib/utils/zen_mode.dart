import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Zen Mode: a separate, calmer way to play.
///
/// Zen strips every endgame modifier (fog, timers, eclipse, chaos, ...) so the
/// player just gets the puzzle. It is deliberately a *parallel* progression
/// rather than a difficulty switch:
///
///  * Each game keeps its own zen level record, so relaxing in Zen never
///    touches the Challenge progress the player has built up.
///  * Clears award half points, and count toward zen-only totals, so easy zen
///    levels cannot be farmed for Challenge-side trails and achievements.
///  * Zen has its own achievements and its own unlockable trail.
///
/// The enabled flag is mirrored into [isEnabled] so it can be read
/// synchronously from hot paths like level-key lookup and modifier selection,
/// which have no opportunity to await.
class ZenMode {
  ZenMode._();

  static const String enabledKey = 'zen_mode_enabled';

  /// Lifetime zen level clears. Drives zen achievements and the zen trail.
  static const String zenClearedCountKey = 'zen_level_cleared_count';

  /// Per-game zen level record, kept apart from `level_<gameId>`.
  static String zenGameLevel(String gameId) => 'zen_level_$gameId';

  /// Per-game zen clear tally.
  static String zenClearedCount(String gameId) => 'zen_cleared_count_$gameId';

  static bool _enabled = false;

  /// Synchronous view of the toggle, safe to read from build methods and from
  /// key builders. Kept in sync by [initialize] and [setEnabled].
  static bool get isEnabled => _enabled;

  static final ValueNotifier<bool> enabledNotifier = ValueNotifier<bool>(false);

  /// Loads the persisted toggle. Call once during app startup, before any
  /// screen reads a level key.
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(enabledKey) ?? false;
    enabledNotifier.value = _enabled;
  }

  static Future<void> setEnabled(bool value) async {
    _enabled = value;
    enabledNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(enabledKey, value);
  }

  static Future<void> toggle() => setEnabled(!_enabled);

  /// Daily challenges must always run under Challenge rules so that stars,
  /// streaks and the shared difficulty curve keep their meaning. Call this
  /// before launching a daily challenge.
  static Future<void> suspendForDaily() async {
    if (_enabled) await setEnabled(false);
  }

  static Future<int> getZenClears() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(zenClearedCountKey) ?? 0;
  }
}
