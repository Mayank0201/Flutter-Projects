import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/game_info.dart';
import '../theme/app_theme.dart';
import '../utils/activity_tracker.dart';
import '../utils/recently_played_manager.dart';
import '../utils/seasonal_event_manager.dart';

/// S3 — where the seasonal banner leads (release 2.2).
///
/// Before 2.2 the banner's `onTap` was never supplied by the home screen, so
/// the `InkWell` around it had a null callback and tapping the event did
/// nothing at all. The featured games named in every definition were never
/// rendered anywhere either — `liveFeaturedGames` had no caller outside its own
/// tests. This sheet is the destination: the badge, the night trail, the named
/// stages, and every featured game as something you can actually open.
///
/// It states only what the framework does. It does **not** name
/// `featuredModifierTypes`: those are still metadata, nothing applies them, and
/// `remember.md` §8 forbids advertising them until something does.
Future<void> showSeasonalEventSheet(
  BuildContext context, {
  DateTime? now,
  List<SeasonalEventDefinition>? definitions,
  VoidCallback? onClaim,
  void Function(GameInfo game)? onGameTap,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) => SeasonalEventSheet(
      now: now,
      definitions: definitions,
      onClaim: onClaim,
      onGameTap: onGameTap,
    ),
  );
}

/// The contents of [showSeasonalEventSheet]. Public so a widget test can pump
/// it directly without driving a modal route.
class SeasonalEventSheet extends StatefulWidget {
  const SeasonalEventSheet({
    super.key,
    this.now,
    this.definitions,
    this.onClaim,
    this.onGameTap,
  });

  /// Test/preview hook. Defaults to [SeasonalEventManager.clock].
  final DateTime? now;

  /// Test/preview hook. Defaults to the shipped definitions.
  final List<SeasonalEventDefinition>? definitions;

  /// Tapped on Claim. When null the sheet claims the running event's badge
  /// itself, which is safe: [SeasonalEventManager.claimBadge] gates on
  /// `PrefsKeys.claimedAchievements` and cannot double-award.
  final VoidCallback? onClaim;

  /// Tapped on a featured game. When null the sheet closes and pushes that
  /// game's route, which is why every featured id must be live — a stashed id
  /// has no route registered in `main.dart` and there is no `onUnknownRoute`.
  final void Function(GameInfo game)? onGameTap;

  @override
  State<SeasonalEventSheet> createState() => _SeasonalEventSheetState();
}

class _SeasonalEventSheetState extends State<SeasonalEventSheet> {
  SeasonalEventState? _state;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final SeasonalEventState s = await SeasonalEventManager.currentState(
      now: widget.now,
      definitions: widget.definitions,
    );
    if (!mounted) return;
    setState(() => _state = s);
  }

  Future<void> _claim() async {
    final VoidCallback? external = widget.onClaim;
    if (external != null) {
      external();
      await _load();
      return;
    }
    final SeasonalEventOccurrence? running = SeasonalEventManager.activeEvent(
      now: widget.now,
      definitions: widget.definitions,
    );
    if (running != null) {
      await SeasonalEventManager.claimBadge(running.definition.badge.id);
    }
    await _load();
  }

  void _openGame(GameInfo game) {
    final void Function(GameInfo)? external = widget.onGameTap;
    final NavigatorState navigator = Navigator.of(context);
    if (external != null) {
      external(game);
      return;
    }
    // Same hook the home grid uses. Without it a launch from the event would
    // not count towards the event — see SeasonalEventBanner._openGame.
    ActivityTracker.trackGamePlay(game.id);
    RecentlyPlayedManager.addGame(game.id);
    if (navigator.canPop()) navigator.pop();
    navigator.pushNamed(game.routeName);
  }

  @override
  Widget build(BuildContext context) {
    final SeasonalEventState? s = _state;
    final Color accent = AppTheme.slateBlue;

    // A sheet for an event that is not running would be a lie about the
    // calendar; it collapses instead. Reachable if the clock rolls past the
    // last day while the sheet is open.
    if (s == null || !s.isActive) return const SizedBox.shrink();

    final SeasonalEventOccurrence occurrence = s.occurrence!;
    final SeasonalEventDefinition def = occurrence.definition;
    final double maxHeight = MediaQuery.of(context).size.height * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.textMuted.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _header(context, def, occurrence, accent),
              const SizedBox(height: 16),
              _badgeSection(context, s, def, accent),
              const SizedBox(height: 20),
              _nightsSection(context, s, accent),
              const SizedBox(height: 20),
              _featuredSection(context, s, accent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(
    BuildContext context,
    SeasonalEventDefinition def,
    SeasonalEventOccurrence occurrence,
    Color accent,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(def.emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                def.name,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                def.tagline,
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Day ${occurrence.dayIndex} of ${occurrence.totalDays}',
                style: GoogleFonts.outfit(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _badgeSection(
    BuildContext context,
    SeasonalEventState s,
    SeasonalEventDefinition def,
    Color accent,
  ) {
    final EventBadge badge = def.badge;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.26), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(badge.icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      badge.name,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      badge.description,
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${s.progress}/${s.requiredProgress}',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: s.fraction,
              minHeight: 6,
              backgroundColor: context.textMuted.withValues(alpha: 0.16),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          if (s.hasUnclaimedBadge) ...<Widget>[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _claim,
                style: TextButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Claim ${badge.rewardPoints} points',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ] else if (s.badgeClaimed) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              'Claimed — ${badge.rewardPoints} points collected',
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _nightsSection(
    BuildContext context,
    SeasonalEventState s,
    Color accent,
  ) {
    final EventMilestone? next = s.nextMilestone;
    final EventMilestone? current = s.currentMilestone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionTitle(
          title: 'Nights lit',
          trailing: '${s.nightsLit} of ${s.totalNights}',
          accent: accent,
        ),
        const SizedBox(height: 4),
        Text(
          // Exactly what the code does: a night lights the first time you open
          // any game on that day of the event. Not "clear a level" — progress
          // is recorded from ActivityTracker.trackGamePlay, which fires on
          // launch.
          'A lantern lights on every day of the event you play.',
          style: GoogleFonts.outfit(
            fontSize: 11.5,
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        SeasonalNightTrail(
          totalNights: s.totalNights,
          litNights: s.litNights,
          tonight: s.occurrence?.dayIndex ?? 0,
          accent: accent,
          compact: false,
        ),
        if (s.milestones.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          for (final EventMilestone m in s.milestones)
            _MilestoneRow(
              milestone: m,
              reached: s.nightsLit >= m.nights,
              isNext: next != null && next.nights == m.nights,
              accent: accent,
            ),
          const SizedBox(height: 6),
          Text(
            next == null
                ? (current == null
                    ? 'Play on any day of the event to light your first lantern.'
                    : 'Every stage reached — ${current.name}.')
                : 'Next: ${next.name} at ${next.nights} '
                    '${next.nights == 1 ? 'night' : 'nights'}.',
            style: GoogleFonts.outfit(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _featuredSection(
    BuildContext context,
    SeasonalEventState s,
    Color accent,
  ) {
    final List<GameInfo> games = s.featuredGames;
    // liveFeaturedGames drops anything stashed, so this can be empty in
    // principle. An empty heading over nothing is worse than no heading.
    if (games.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionTitle(
          title: 'Featured this event',
          trailing: '${games.length}',
          accent: accent,
        ),
        const SizedBox(height: 10),
        // Wrap rather than Row: it cannot overflow at any width, and a
        // wide-short window simply fits more per line.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final GameInfo g in games)
              _FeaturedGameCard(game: g, onTap: () => _openGame(g)),
          ],
        ),
      ],
    );
  }
}

/// The night trail: one mark per day of the event, lit for every day the player
/// was active.
///
/// [compact] renders a thin segmented bar for the home banner; the full form
/// numbers each night and wraps. Neither can overflow — the bar's segments are
/// `Expanded` with margins that come out of their own share, and the full form
/// is a [Wrap].
class SeasonalNightTrail extends StatelessWidget {
  const SeasonalNightTrail({
    super.key,
    required this.totalNights,
    required this.litNights,
    required this.tonight,
    required this.accent,
    this.compact = true,
  });

  final int totalNights;
  final Set<int> litNights;

  /// 1-based index of the day being shown; 0 for none.
  final int tonight;

  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (totalNights <= 0) return const SizedBox.shrink();
    final Color unlit = context.textMuted.withValues(alpha: 0.22);

    if (compact) {
      return SizedBox(
        height: 8,
        child: Row(
          children: <Widget>[
            for (int night = 1; night <= totalNights; night++)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: litNights.contains(night) ? accent : unlit,
                    borderRadius: BorderRadius.circular(2),
                    border: night == tonight && !litNights.contains(night)
                        ? Border.all(
                            color: accent.withValues(alpha: 0.75), width: 1)
                        : null,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: <Widget>[
        for (int night = 1; night <= totalNights; night++)
          _NightCell(
            night: night,
            lit: litNights.contains(night),
            isToday: night == tonight,
            accent: accent,
            unlit: unlit,
          ),
      ],
    );
  }
}

class _NightCell extends StatelessWidget {
  const _NightCell({
    required this.night,
    required this.lit,
    required this.isToday,
    required this.accent,
    required this.unlit,
  });

  final int night;
  final bool lit;
  final bool isToday;
  final Color accent;
  final Color unlit;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Night $night${lit ? ', lit' : ', not lit'}',
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: lit ? accent : unlit,
          borderRadius: BorderRadius.circular(7),
          border: isToday && !lit
              ? Border.all(color: accent.withValues(alpha: 0.75), width: 1.2)
              : null,
        ),
        child: Text(
          '$night',
          style: GoogleFonts.outfit(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: lit ? Colors.white : context.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({
    required this.milestone,
    required this.reached,
    required this.isNext,
    required this.accent,
  });

  final EventMilestone milestone;
  final bool reached;
  final bool isNext;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            reached ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 16,
            color: reached
                ? accent
                : (isNext ? accent.withValues(alpha: 0.6) : context.textMuted),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${milestone.name} · ${milestone.nights} '
                  '${milestone.nights == 1 ? 'night' : 'nights'}',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: reached ? FontWeight.w700 : FontWeight.w600,
                    color: reached ? context.textPrimary : context.textSecondary,
                  ),
                ),
                Text(
                  milestone.description,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: context.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedGameCard extends StatelessWidget {
  const _FeaturedGameCard({required this.game, required this.onTap});

  final GameInfo game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = AppTheme.accentFor(game.id);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: accent.withValues(alpha: 0.30), width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (game.emoji.trim().isNotEmpty) ...<Widget>[
                Text(game.emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 7),
              ],
              Text(
                game.name,
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(width: 5),
              Icon(Icons.chevron_right_rounded,
                  size: 15, color: context.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.trailing,
    required this.accent,
  });

  final String title;
  final String trailing;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          trailing,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: accent,
          ),
        ),
      ],
    );
  }
}
