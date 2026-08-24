import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../utils/zen_mode.dart';

/// The level indicator that sits at the end of every game's app bar.
///
/// Each game used to build its own version of this, which is why the header
/// looked subtly different from game to game -- some said "Level 7", some
/// "L. 7", some used a different font or colour, and a few put it in the body
/// instead of the app bar. They also each overflowed at their own threshold,
/// because a three-digit level plus an edit icon is wider than a one-digit one.
///
/// This renders identically everywhere and scales down instead of overflowing.
///
/// It also shows **Zen** when Zen mode is on. That is read from [ZenMode] here
/// rather than passed in by each screen, so all 24 games get the indicator from
/// one change and none can forget it.
///
/// Why it matters: Zen is a *separate progression* with its own saved levels and
/// no modifiers, and until 2.4 nothing on any game screen said so. A player who
/// toggled Zen by accident saw their level numbers change and had no way to
/// know why — the app altering its behaviour without telling anyone, which is
/// the same class of defect as Star Battle's invisible timer (remember.md 8).
/// The level number is kept alongside the word, because in Zen the level is
/// still real and still the player's progress.
class GameLevelChip extends StatelessWidget {
  /// One-based level number. Null when the screen is a tutorial or a daily
  /// challenge, where a campaign level makes no sense.
  final int? level;

  /// Shown instead of the level, e.g. 'Tutorial' or 'Daily'.
  final String? modeLabel;

  final Color accent;

  /// Opening the jump-to-level dialog. Null outside debug builds, which also
  /// hides the pencil.
  final VoidCallback? onTap;

  const GameLevelChip({
    super.key,
    this.level,
    this.modeLabel,
    required this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // A daily challenge overrides everything -- there is no campaign level to
    // show, and a daily is never played in Zen.
    final bool showZen = modeLabel == null && ZenMode.isEnabled;
    final label = modeLabel ??
        (showZen ? 'Zen  Level ${level ?? 1}' : 'Level ${level ?? 1}');
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(right: 12, left: 4),
        child: Center(
          // Never pushes the app bar past the edge: a long label shrinks.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showZen) ...[
                  Icon(Icons.spa_rounded, size: 12, color: accent),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: AppTheme.numberStyle(
                    color: accent,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (onTap != null && modeLabel == null) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.edit, size: 12, color: accent),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The app-bar title used by every game: the game's name, nothing else.
///
/// Scales down on a narrow screen rather than eliding, so the name stays
/// readable on a small phone.
class GameTitle extends StatelessWidget {
  final String name;
  const GameTitle(this.name, {super.key});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        name,
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: context.textPrimary,
        ),
      ),
    );
  }
}
