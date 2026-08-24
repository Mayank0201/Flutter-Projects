import 'package:shared_preferences/shared_preferences.dart';
import 'prefs_keys.dart';

/// Guards writes to a game's saved level.
///
/// Two things kept corrupting progress:
///
///  * Daily challenges temporarily overwrite `level_<gameId>` with the
///    challenge's level, so any save performed while a daily is in flight can
///    leak the challenge's number into the player's real progress.
///  * Replaying an earlier level wrote that lower number straight back over a
///    much higher saved level, silently undoing hours of progress.
///
/// Progress only ever moves forward, and never during a daily challenge.
class ProgressGuard {
  ProgressGuard._();

  /// Saves [level] as the player's progress for [gameId].
  ///
  /// Does nothing when [isDaily] is true, or when [level] is not ahead of what
  /// is already stored.
  static Future<void> saveLevel(
    String gameId,
    int level, {
    required bool isDaily,
  }) async {
    if (isDaily) return;
    final prefs = await SharedPreferences.getInstance();
    final key = PrefsKeys.gameLevel(gameId);
    final current = prefs.getInt(key) ?? 0;
    if (level > current) {
      await prefs.setInt(key, level);
    }
  }
}
