import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Detects if the app was restored from an Android Auto Backup (i.e. reinstalled)
/// and resets the daily challenge timer accordingly:
///   - If the user has stars for today → 8 hours remaining
///   - If no stars for today → full 24 hours
///
/// Uses a marker file in Android's noBackupFilesDir (never backed up, deleted on uninstall)
/// to distinguish a normal launch from a restore.
class RestoreManager {
  static const _channel = MethodChannel('com.mayank.cogniq/install_marker');

  static Future<void> checkAndHandleRestore() async {
    // Only relevant on Android — iOS and web don't use this backup mechanism
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    try {
      final hasMarker = await _channel.invokeMethod<bool>('hasMarker') ?? false;

      if (!hasMarker) {
        // Marker is missing — either a fresh install or a restore from backup
        final prefs = await SharedPreferences.getInstance();
        final day = prefs.getInt('daily_user_progress_day');

        if (day != null) {
          // Challenge data exists but marker doesn't → RESTORE detected
          final now = DateTime.now().toUtc();
          final dateStr =
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          final todayStar = prefs.getString('daily_star_for_date_$dateStr');

          if (todayStar != null) {
            // User has stars for today → give them 8 hours to finish
            // Timer formula: remaining = (startTime + 24h) - now
            // For 8h remaining: startTime = now - 16h
            final newStart = now.subtract(const Duration(hours: 16));
            await prefs.setString(
                'daily_challenge_start_time', newStart.toIso8601String());
          } else {
            // No stars for today → give a full fresh 24-hour window
            await prefs.setString(
                'daily_challenge_start_time', now.toIso8601String());
          }
        }

        // Create the marker so future launches are treated as normal
        await _channel.invokeMethod('createMarker');
      }
    } catch (_) {
      // Fail silently — never block app startup over this
    }
  }
}
