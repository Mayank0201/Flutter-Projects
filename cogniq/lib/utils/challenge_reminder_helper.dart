import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import 'daily_challenge_manager.dart';

class ChallengeReminderHelper {
  /// Shows the "time is running out" reminder when it applies.
  ///
  /// Returns true when the dialog was actually shown (and only resolves once
  /// the player has dismissed it), false on every early exit. Callers use the
  /// result to serialise launch popups: when the reminder shows, the deferred
  /// daily-challenge intro popup must wait for another launch.
  static Future<bool> checkAndShowReminder(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    final startTimeStr = prefs.getString('daily_challenge_start_time') ?? '';
    if (startTimeStr.isEmpty) return false;

    final now = DateTime.now().toUtc();
    final startTime = DateTime.parse(startTimeStr);
    final target = startTime.add(const Duration(hours: 24));

    if (now.isAfter(target)) return false; // expired, next cycle hasn't updated progress day yet

    final diff = target.difference(now);
    if (diff.inHours >= 12 || diff.isNegative) return false; // more than 12 hours left

    // Check completion status for today
    final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final completedCount = await DailyChallengeManager.getCompletedCountForDate(dateStr);

    if (completedCount == 3) return false; // already completed all 3

    // Only show once per challenge cycle
    final lastShown = prefs.getString('daily_challenge_reminder_shown_time') ?? '';
    if (lastShown == startTimeStr) return false; // already shown for this cycle

    // Mark as shown
    await prefs.setString('daily_challenge_reminder_shown_time', startTimeStr);

    if (!context.mounted) return false;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: context.textMuted.withAlpha(40)),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
            const SizedBox(width: 8),
            Text(
              'Time is Running Out!',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary),
            ),
          ],
        ),
        content: Text(
          'You have less than 12 hours left to complete today\'s Daily Challenges and save your streak! ⏳\n\nChallenges Completed: $completedCount/3',
          style: GoogleFonts.outfit(color: context.textSecondary, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/daily');
            },
            child: Text(
              'Start Solving',
              style: GoogleFonts.outfit(color: AppTheme.dustyMauve, fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
    );
    return true;
  }
}
