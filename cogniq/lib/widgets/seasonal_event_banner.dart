import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/game_info.dart';
import '../theme/app_theme.dart';
import '../utils/activity_tracker.dart';
import '../utils/recently_played_manager.dart';
import '../utils/seasonal_event_manager.dart';
import 'seasonal_event_sheet.dart';

/// S3 — the home-screen banner for a running seasonal event.
///
/// Renders nothing at all when no event is running, so it is safe to place
/// unconditionally in the home list: outside an event window it costs one
/// `SizedBox.shrink()`.
///
/// The widget owns no scheduling logic. It asks [SeasonalEventManager] what is
/// running and paints the answer, which keeps every date rule testable without
/// a widget test.
class SeasonalEventBanner extends StatefulWidget {
  const SeasonalEventBanner({
    super.key,
    this.onTap,
    this.onClaim,
    this.onGameTap,
    this.now,
    this.definitions,
    this.respectDismissal = true,
  });

  /// Tapped anywhere on the banner that is not a control.
  ///
  /// Leave null — the default opens the event sheet
  /// ([showSeasonalEventSheet]), which is the whole event: the badge, the night
  /// trail, the named stages and every featured game. Until 2.2 the home screen
  /// passed nothing here and there was no default, so the banner's `InkWell`
  /// had a null callback and tapping the event did nothing whatsoever.
  final VoidCallback? onTap;

  /// Tapped on a featured game chip. When null the banner pushes that game's
  /// route directly.
  ///
  /// Every featured id is a live game, so the route is registered in
  /// `main.dart`. A stashed id would not be — `MaterialApp` declares no
  /// `onUnknownRoute`, so that is a crash, which is why
  /// [SeasonalEventManager.liveFeaturedGames] filters and why `validate()` and
  /// two tests check the declared ids.
  final void Function(GameInfo game)? onGameTap;

  /// Tapped on the Claim chip, shown only once the badge is
  /// unlocked-but-unclaimed. Leave null to route the player to the achievements
  /// screen instead of claiming inline.
  final VoidCallback? onClaim;

  /// Test/preview hook. Defaults to [SeasonalEventManager.clock].
  final DateTime? now;

  /// Test/preview hook. Defaults to the shipped definitions.
  final List<SeasonalEventDefinition>? definitions;

  /// When true (the default) a dismissed banner stays hidden for the rest of
  /// that occurrence.
  final bool respectDismissal;

  @override
  State<SeasonalEventBanner> createState() => SeasonalEventBannerState();
}

class SeasonalEventBannerState extends State<SeasonalEventBanner>
    with WidgetsBindingObserver {
  SeasonalEventState? _state;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-reads on resume, so a banner left on screen overnight shows the new
  /// day rather than yesterday's trail.
  ///
  /// This does *not* cover returning from a game — that is a route pop, not a
  /// lifecycle change, and the home screen owns it. See the report for the
  /// one-line `home_screen.dart` edit that closes that gap.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  /// Re-reads event state. The home screen can call this after a level clear
  /// via a `GlobalKey<SeasonalEventBannerState>`.
  Future<void> refresh() => _load();

  Future<void> _load() async {
    final SeasonalEventState s = await SeasonalEventManager.currentState(
      now: widget.now,
      definitions: widget.definitions,
    );
    if (!mounted) return;
    setState(() => _state = s);
  }

  Future<void> _dismiss() async {
    await SeasonalEventManager.dismissBanner(
      now: widget.now,
      definitions: widget.definitions,
    );
    await _load();
  }

  Future<void> _openSheet() async {
    final VoidCallback? external = widget.onTap;
    if (external != null) {
      external();
      return;
    }
    await showSeasonalEventSheet(
      context,
      now: widget.now,
      definitions: widget.definitions,
      onClaim: widget.onClaim,
      onGameTap: widget.onGameTap,
    );
    // Claiming or playing from the sheet moves the numbers the banner shows.
    await _load();
  }

  void _openGame(GameInfo game) {
    final void Function(GameInfo)? external = widget.onGameTap;
    if (external != null) {
      external(game);
      return;
    }
    // A launch from here has to go through the same hook a launch from the home
    // grid does. `ActivityTracker.trackGamePlay` is what records the play count,
    // the daily streak *and* seasonal progress — pushing the route on its own
    // would mean a player who only ever plays from the event banner never lights
    // a single lantern and never moves the badge they are being shown.
    ActivityTracker.trackGamePlay(game.id);
    RecentlyPlayedManager.addGame(game.id);
    Navigator.of(context).pushNamed(game.routeName);
  }

  @override
  Widget build(BuildContext context) {
    final SeasonalEventState? s = _state;
    if (s == null || !s.isActive) return const SizedBox.shrink();
    if (widget.respectDismissal && s.bannerDismissed && !s.hasUnclaimedBadge) {
      return const SizedBox.shrink();
    }

    final SeasonalEventOccurrence occurrence = s.occurrence!;
    final SeasonalEventDefinition def = occurrence.definition;
    // Slate blue reads as cold without competing with the warm-amber IQ chip
    // beside it in the header.
    final Color accent = AppTheme.slateBlue;
    final bool isSmall = MediaQuery.of(context).size.width < 360;

    final List<GameInfo> featured = s.featuredGames;

    return Semantics(
      button: true,
      label: '${def.name}. ${_remainingLabel(occurrence)}. '
          'Progress ${s.progress} of ${s.requiredProgress}. '
          '${s.nightsLit} of ${s.totalNights} nights lit.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openSheet,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: EdgeInsets.all(isSmall ? 12 : 14),
            decoration: BoxDecoration(
              color: accent.withAlpha((255 * 0.10).round()),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: accent.withAlpha((255 * 0.28).round()),
                width: 0.8,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(def.emoji, style: TextStyle(fontSize: isSmall ? 20 : 24)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            def.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: isSmall ? 14 : 15,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            def.tagline,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: isSmall ? 11 : 12,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _DaysChip(
                      label: _remainingLabel(occurrence),
                      accent: accent,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _ProgressBar(fraction: s.fraction, accent: accent),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        s.badgeClaimed
                            ? '${def.badge.icon} ${def.badge.name} claimed'
                            : s.hasUnclaimedBadge
                                ? '${def.badge.icon} Badge earned — ready to claim'
                                : '${s.progress} / ${s.requiredProgress} — ${def.badge.description}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: isSmall ? 10.5 : 11.5,
                          fontWeight: s.hasUnclaimedBadge
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: s.hasUnclaimedBadge
                              ? accent
                              : context.textSecondary,
                        ),
                      ),
                    ),
                    if (s.hasUnclaimedBadge && widget.onClaim != null)
                      _ClaimChip(accent: accent, onTap: widget.onClaim!)
                    else if (!s.hasUnclaimedBadge)
                      _DismissButton(onTap: _dismiss),
                  ],
                ),
                // The nineteen-night trail. The badge above is a first-week
                // goal; this is the part that has something to say on day 14.
                if (s.totalNights > 0) ...<Widget>[
                  SizedBox(height: isSmall ? 10 : 12),
                  SeasonalNightTrail(
                    totalNights: s.totalNights,
                    litNights: s.litNights,
                    tonight: occurrence.dayIndex,
                    accent: accent,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _nightsLabel(s),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: isSmall ? 10.5 : 11.5,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondary,
                    ),
                  ),
                ],
                // Featured games, finally rendered. Before 2.2 every definition
                // named five and no surface showed any of them.
                if (featured.isNotEmpty) ...<Widget>[
                  SizedBox(height: isSmall ? 10 : 12),
                  _FeaturedRail(
                    games: featured,
                    onGameTap: _openGame,
                    isSmall: isSmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Says only what is stored: nights lit, and the next named stage when the
  /// event has one.
  static String _nightsLabel(SeasonalEventState s) {
    final String lit = '${s.nightsLit} of ${s.totalNights} nights lit';
    final EventMilestone? next = s.nextMilestone;
    if (next == null) {
      final EventMilestone? current = s.currentMilestone;
      return current == null ? lit : '$lit — ${current.name}';
    }
    return '$lit — next: ${next.name}';
  }

  static String _remainingLabel(SeasonalEventOccurrence o) {
    if (o.isLastDay) return 'Last day';
    if (o.daysRemaining == 1) return '1 day left';
    return '${o.daysRemaining} days left';
  }
}

/// The event's featured games, as chips that open them.
///
/// A horizontal list rather than a [Wrap]: the banner sits in the home feed and
/// must keep a predictable height, and a scrolling row cannot overflow however
/// many games an event names or however long their titles are.
class _FeaturedRail extends StatelessWidget {
  const _FeaturedRail({
    required this.games,
    required this.onGameTap,
    required this.isSmall,
  });

  final List<GameInfo> games;
  final void Function(GameInfo game) onGameTap;
  final bool isSmall;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: isSmall ? 30 : 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: games.length,
        separatorBuilder: (BuildContext context, int i) =>
            const SizedBox(width: 6),
        itemBuilder: (BuildContext context, int i) {
          final GameInfo g = games[i];
          final Color tone = AppTheme.accentFor(g.id);
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onGameTap(g),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: isSmall ? 8 : 10, vertical: 6),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: tone.withValues(alpha: 0.30),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (g.emoji.trim().isNotEmpty) ...<Widget>[
                      Text(g.emoji,
                          style: TextStyle(fontSize: isSmall ? 11 : 12)),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      g.name,
                      style: GoogleFonts.outfit(
                        fontSize: isSmall ? 10.5 : 11.5,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DaysChip extends StatelessWidget {
  const _DaysChip({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withAlpha((255 * 0.16).round()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: accent,
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.fraction, required this.accent});

  final double fraction;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: fraction,
        minHeight: 6,
        backgroundColor: context.textMuted.withAlpha(40),
        valueColor: AlwaysStoppedAnimation<Color>(accent),
      ),
    );
  }
}

class _ClaimChip extends StatelessWidget {
  const _ClaimChip({required this.accent, required this.onTap});

  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          'Claim',
          style: GoogleFonts.outfit(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _DismissButton extends StatelessWidget {
  const _DismissButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: const Icon(Icons.close_rounded, size: 16),
      color: context.textMuted,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      tooltip: 'Hide this event banner',
    );
  }
}
