import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import '../utils/prefs_keys.dart';
import 'game_tutorial_dialog.dart' show TutorialStep;

/// The first-run tour of the whole app.
///
/// [GameTutorialDialog] explains one game; this explains CogniQ itself — the
/// header buttons, the two play modes, the daily challenge, points and hints.
/// It deliberately reuses that file's [TutorialStep] and its visual language
/// (card background, muted hairline border, Outfit type, dusty-mauve accent)
/// so the two read as the same app talking, not two different dialogs.
///
/// Shown once, on first launch, keyed by [PrefsKeys.hasSeenAppTour]. The flag
/// is written the moment the tour is *offered* rather than when it finishes:
/// a player who force-quits halfway would otherwise meet the same nine steps
/// on every cold start. "Skip" and "Finish" are therefore the same outcome as
/// far as persistence goes, which is also why Skip is safe to offer.
class AppTourDialog extends StatefulWidget {
  const AppTourDialog({super.key});

  /// Plain, short sentences on purpose — this is the first English many
  /// players read in the app, and it matches the reading level of the
  /// per-game tutorials.
  static const List<TutorialStep> steps = <TutorialStep>[
    TutorialStep(
      title: 'Welcome to CogniQ',
      illustrationEmoji: '👋',
      description:
          'CogniQ is a calm place to train your brain. Tap any game card on '
          'the home screen to start playing.\n\n'
          'This short tour shows what each part does. Press Next to continue, '
          'or Skip if you want to start playing now.',
    ),
    TutorialStep(
      // The single most important step. A player who taps the leaf by
      // accident sees every level number reset to 1 and thinks the app ate
      // their progress, so this says out loud that nothing was lost.
      title: 'Zen or Challenge',
      illustrationEmoji: '🌿',
      description:
          'The leaf button at the top right opens the two play modes.\n\n'
          'Challenge is the normal game. Levels get harder, and after a while '
          'they add timers and other twists. You earn full points.\n\n'
          'Zen is quiet play. No timers, no twists, nothing to lose. You earn '
          'half points.\n\n'
          'Zen keeps its own levels, separate from Challenge. Nothing is '
          'deleted when you switch. Turn Zen off again and your Challenge '
          'levels come back exactly where you left them.',
    ),
    TutorialStep(
      title: 'Shuffle',
      illustrationEmoji: '🔀',
      description:
          'Tap Shuffle at the top and CogniQ picks a random game for you. '
          'While it is on, a new game opens after every level you finish.\n\n'
          'Tap the small slider icon next to it to choose which games are '
          'included.',
    ),
    TutorialStep(
      title: 'Daily Challenge',
      illustrationEmoji: '⚡',
      description:
          'Every day you get three challenges: one easy, one medium, one '
          'hard. Finish them to earn stars.\n\n'
          'Play a little every day and your streak grows. Miss a day and it '
          'starts again.\n\n'
          'Daily challenges always use Challenge rules, even when Zen is on.',
    ),
    TutorialStep(
      title: 'Achievements and Trails',
      illustrationEmoji: '🏆',
      description:
          'The two cards on the home screen show what you have earned.\n\n'
          'Achievements unlock as you play more and solve more. Trails are '
          'the pretty effects your finger leaves on the board.\n\n'
          'When a small badge appears on a card, something is waiting for '
          'you. Tap the card and claim it.',
    ),
    TutorialStep(
      title: 'IQ Points',
      illustrationEmoji: '🧠',
      description:
          'IQ Points are the coins of CogniQ. Your balance is the amber chip '
          'at the top of the home screen.\n\n'
          'You earn 10 points for every level you clear in Challenge, and 5 '
          'in Zen. Points buy hints.\n\n'
          'If you ever want more, the shop in the bottom bar sells point '
          'packs and a one-time ad-free upgrade.',
    ),
    TutorialStep(
      title: 'Hints',
      illustrationEmoji: '💡',
      description:
          'Stuck on a puzzle? A hint gives you a push forward.\n\n'
          'Every game starts you with 1 free hint. After that, 1 hint costs '
          '100 IQ Points.\n\n'
          'Tap your points chip at the top to buy hints for any game.',
    ),
    TutorialStep(
      title: 'Your Progress',
      illustrationEmoji: '📊',
      description:
          'The report card on the home screen shows your streak, how many '
          'puzzles you have cleared, and whether today is done.\n\n'
          'The Stats tab at the bottom shows more detail for each game.\n\n'
          'Everything saves by itself, so you can stop whenever you like.',
    ),
    TutorialStep(
      title: 'You are ready',
      illustrationEmoji: '✅',
      description:
          'That is everything. Pick a puzzle and enjoy.\n\n'
          'Want to read this again? Open the Profile tab and tap "App Tour" '
          'under Help.',
    ),
  ];

  static void show(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AppTourDialog(),
    );
  }

  /// Shows the tour only on a first run, and completes when it closes.
  ///
  /// Returns true when the tour was actually shown, so the caller can hold
  /// back any other launch-time prompt instead of stacking one dialog on top
  /// of another.
  static Future<bool> showIfFirstRun(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(PrefsKeys.hasSeenAppTour) ?? false) return false;
    await prefs.setBool(PrefsKeys.hasSeenAppTour, true);
    if (!context.mounted) return false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AppTourDialog(),
    );
    return true;
  }

  @override
  State<AppTourDialog> createState() => _AppTourDialogState();
}

class _AppTourDialogState extends State<AppTourDialog> {
  int _index = 0;

  bool get _isLast => _index == AppTourDialog.steps.length - 1;

  void _next() {
    if (_isLast) {
      Navigator.of(context).pop();
    } else {
      setState(() => _index++);
    }
  }

  void _back() {
    if (_index > 0) setState(() => _index--);
  }

  @override
  Widget build(BuildContext context) {
    final steps = AppTourDialog.steps;
    final step = steps[_index];
    const accent = AppTheme.dustyMauve;

    return Dialog(
      backgroundColor: context.bgCard,
      // Narrow on purpose. Left to itself a dialog on a 1568px-wide landscape
      // window stretches into an unreadable line of text.
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: context.textMuted.withValues(alpha: 0.16)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          // Sized to its content, with only the middle section allowed to
          // grow — so a long step scrolls instead of overflowing a short
          // window.
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      'Step ${_index + 1} of ${steps.length}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: context.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Skip',
                      maxLines: 1,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (step.customIllustration != null)
                      step.customIllustration!
                    else
                      Container(
                        width: 62,
                        height: 62,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          step.illustrationEmoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    const SizedBox(height: 14),
                    Text(
                      step.title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      step.description,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        height: 1.5,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Step dots. Wrap, not Row: nine dots plus a large system font
            // still fit on a 320px phone, but the widget should bend rather
            // than draw a yellow bar if a tenth step is ever added.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: List<Widget>.generate(steps.length, (i) {
                  final active = i == _index;
                  return Container(
                    width: active ? 18 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: active
                          ? accent
                          : context.textMuted.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
            // Both buttons take a share of the row rather than their natural
            // width. Natural width overflowed a 320px phone by 56px, and any
            // label that is sized by the font — a longer word, a bigger system
            // font — would put it straight back. A share plus a scale-down
            // label cannot overflow whatever the text measures.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  if (_index > 0) ...[
                    Expanded(
                      child: TextButton(
                        onPressed: _back,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 42),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Back',
                            maxLines: 1,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              color: context.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: _index > 0 ? 2 : 1,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _isLast ? 'Done' : 'Next',
                          maxLines: 1,
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
