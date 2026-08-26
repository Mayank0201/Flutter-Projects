import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'prefs_keys.dart';
import 'zen_mode.dart';

/// Manages Google Play In-App Review requests.
class ReviewPromptManager {
  ReviewPromptManager._();

  /// Asks Play to show the in-app review sheet, if now is a good moment.
  ///
  /// Google decides whether the sheet actually appears and gives us no way to
  /// find out, so this is fire-and-forget. Never call it on launch, after a
  /// loss, or during a Daily Challenge.
  // COGNIQ-FIX:review-prompt
  static Future<void> maybeRequestReview({InAppReview? reviewInstance}) async {
    if (ZenMode.isEnabled) return; // Zen is the "don't interrupt me" mode

    final prefs = await SharedPreferences.getInstance();

    // Enough experience to have an opinion?
    final levelsDone = prefs.getInt(PrefsKeys.globalLevelClearedCount) ?? 0;
    if (levelsDone < 20) return;

    final daysOpened = prefs.getInt(PrefsKeys.distinctDaysOpened) ?? 0;
    if (daysOpened < 3) return;

    // Respect Google's quota - don't burn it more than a few times a year.
    final last = prefs.getInt(PrefsKeys.reviewPromptLastShown) ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (last != 0 && nowMs - last < const Duration(days: 90).inMilliseconds) return;

    final review = reviewInstance ?? InAppReview.instance;
    try {
      if (!await review.isAvailable()) return;

      // Stamp BEFORE requesting: if the sheet does show, we must not ask again,
      // and we get no callback telling us it did.
      await prefs.setInt(PrefsKeys.reviewPromptLastShown, nowMs);
      await review.requestReview();
    } catch (e) {
      debugPrint('In-app review request failed: $e');
    }
  }

  /// Counts distinct calendar days the app has been opened.
  // COGNIQ-FIX:review-prompt
  static Future<void> recordAppOpen() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10); // yyyy-MM-dd
    if (prefs.getString(PrefsKeys.lastOpenDate) == today) return;
    await prefs.setString(PrefsKeys.lastOpenDate, today);
    await prefs.setInt(PrefsKeys.distinctDaysOpened,
        (prefs.getInt(PrefsKeys.distinctDaysOpened) ?? 0) + 1);
  }
}
