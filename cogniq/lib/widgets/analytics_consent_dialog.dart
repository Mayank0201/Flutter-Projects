import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../utils/analytics/analytics.dart';

/// The first-run analytics consent prompt.
///
/// ---------------------------------------------------------------------------
/// WHY THIS DIALOG IS WRITTEN THE WAY IT IS
/// ---------------------------------------------------------------------------
/// The usual consent sheet is a paragraph of "we use analytics to improve your
/// experience" over a bright **Accept** and a grey **More options**. It is
/// technically a choice and practically a dark pattern, and it is also the
/// thing that gets an app's data-safety declaration challenged.
///
/// This one is built to be the opposite, and the details are the point:
///
/// * **Both answers are equally reachable.** Two plain text buttons, same
///   weight, same size, neither pre-highlighted. Declining is not hidden behind
///   a second screen.
/// * **It states what is NOT collected, by name.** "No personal data" is what
///   every app says. Naming device ids, advertising ids and free text is
///   checkable, and it is the same list the data-safety form declares — see the
///   doc comment at the top of `analytics_event.dart`.
/// * **It is not dismissible by tapping outside.** Not to trap the player, but
///   because a barrier tap is ambiguous, and an ambiguous gesture must never be
///   recorded as agreement.
/// * **Declining is the state the app is already in.** Consent defaults to off
///   in `Analytics`, so nothing has been collected by the time this appears and
///   nothing is collected if it is declined. The dialog grants; it never
///   silently confirms something already switched on.
///
/// ---------------------------------------------------------------------------
/// WIRING IT UP
/// ---------------------------------------------------------------------------
/// `lib/main.dart` belongs to another workstream this release, so nothing calls
/// this yet. To wire it, call [showIfNeeded] once from the home screen's first
/// post-frame callback, after `Analytics.initialize()` has completed:
///
/// ```dart
/// WidgetsBinding.instance.addPostFrameCallback((_) {
///   AnalyticsConsentDialog.showIfNeeded(context);
/// });
/// ```
///
/// [showIfNeeded] is a no-op once the question has been answered either way, so
/// it is safe to call unconditionally on every launch.
class AnalyticsConsentDialog extends StatelessWidget {
  const AnalyticsConsentDialog({super.key});

  /// Shows the prompt only if it has never been answered.
  ///
  /// Returns `true` if the player opted in, `false` otherwise — including when
  /// the dialog was not shown at all, so a caller cannot mistake "already
  /// answered" for "just agreed".
  static Future<bool> showIfNeeded(BuildContext context) async {
    if (!Analytics.needsConsentPrompt) return false;
    final granted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AnalyticsConsentDialog(),
    );
    return granted ?? false;
  }

  /// Shows the prompt unconditionally. For a "review this choice" affordance.
  static Future<bool> show(BuildContext context) async {
    final granted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AnalyticsConsentDialog(),
    );
    return granted ?? false;
  }

  Future<void> _answer(BuildContext context, bool granted) async {
    // Capture the navigator before the await: the element may be gone by the
    // time `setConsent` finishes writing to disk.
    final navigator = Navigator.of(context);
    await Analytics.setConsent(granted);
    navigator.pop(granted);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Help improve CogniQ?',
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.w700,
          color: context.textPrimary,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'CogniQ can send anonymous notes about which puzzles get played '
              'and where people get stuck. It helps us fix difficulty spikes '
              'instead of guessing at them.',
              style: GoogleFonts.outfit(
                color: context.textSecondary,
                fontSize: context.scale(13),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            _ConsentList(
              icon: Icons.check_circle_outline,
              iconColor: AppTheme.positiveGreen,
              title: 'What we send',
              items: const [
                'Which game you opened, and the level number',
                'Whether the level was finished, quit, or left',
                'How long a level or a session lasted',
                'Hints used, and Zen or Challenge mode',
                'Which in-app purchases were started or finished',
              ],
            ),
            const SizedBox(height: 16),
            _ConsentList(
              icon: Icons.block_outlined,
              iconColor: Colors.redAccent,
              title: 'What we never send',
              items: const [
                'Your name, email, or any account — CogniQ has no accounts',
                'Device IDs, advertising IDs, or anything identifying '
                    'your phone',
                'Your location',
                'Anything you type, or the contents of your puzzles',
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'You can turn this off at any time in Settings. Turning it off '
              'also deletes anything still waiting to be sent.',
              style: GoogleFonts.outfit(
                color: context.textMuted,
                fontSize: context.scale(11),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        // Deliberately the same visual weight as "Allow". Declining is a real
        // answer, not an escape hatch.
        TextButton(
          onPressed: () => _answer(context, false),
          child: Text(
            'No thanks',
            style: GoogleFonts.outfit(
              color: context.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          onPressed: () => _answer(context, true),
          child: Text(
            'Allow',
            style: GoogleFonts.outfit(
              color: AppTheme.positiveGreen,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// A titled bullet list. Two of these carry the whole disclosure, so they are
/// laid out identically — the "never" list must not read as a footnote to the
/// "do" list.
class _ConsentList extends StatelessWidget {
  const _ConsentList({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.items,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.outfit(
                color: context.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: context.scale(12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(left: 24, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: GoogleFonts.outfit(
                    color: context.textMuted,
                    fontSize: context.scale(12),
                  ),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: GoogleFonts.outfit(
                      color: context.textSecondary,
                      fontSize: context.scale(12),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
