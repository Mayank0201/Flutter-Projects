import 'package:flutter/material.dart';

import '../../../model/show_model.dart';
import '../../../service/show_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/poster_image.dart';
import '../widgets/star_rating.dart';

// a show with its seasons. expand a season to tick off episodes.
class ShowDetailsPage extends StatefulWidget {
  final int showTmdbId;
  final String? initialTitle;

  const ShowDetailsPage({
    super.key,
    required this.showTmdbId,
    this.initialTitle,
  });

  @override
  State<ShowDetailsPage> createState() => _ShowDetailsPageState();
}

class _ShowDetailsPageState extends State<ShowDetailsPage> {
  final ShowService _service = ShowService();

  ShowProgress? _progress;
  bool _loading = true;
  String? _error;

  // episodes are only fetched when a season is opened, so we do not pull
  // every season of every show up front
  final Map<int, List<Episode>> _episodesBySeason = {};
  final Set<int> _loadingSeasons = {};
  // episodes mid-flight, so the checkbox can show the new state right away
  final Set<String> _pendingEpisodes = {};
  // seasons mid-flight, so a double tap does not fire two season writes
  final Set<int> _pendingSeasons = {};
  // which season to open once the page has loaded, used by "up next"
  int? _expandSeason;
  double? _myRating;
  String? _myComment;
  double _averageRating = 0;
  int _ratingCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final progress = await _service.getShowProgress(widget.showTmdbId);
      if (!mounted) return;
      setState(() {
        _progress = progress;
        _loading = false;
      });
      _loadRating(progress.showId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Could not load this show";
        _loading = false;
      });
    }
  }

  Future<void> _loadSeason(int seasonNumber) async {
    if (_episodesBySeason.containsKey(seasonNumber) ||
        _loadingSeasons.contains(seasonNumber)) {
      return;
    }
    setState(() => _loadingSeasons.add(seasonNumber));
    try {
      final result = await _service.getSeason(widget.showTmdbId, seasonNumber);
      if (!mounted) return;
      setState(() {
        _episodesBySeason[seasonNumber] = result.episodes;
        _loadingSeasons.remove(seasonNumber);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingSeasons.remove(seasonNumber));
    }
  }

  String _key(int season, int episode) => "$season-$episode";

  Future<void> _toggleEpisode(
      int seasonNumber, int episodeNumber, bool watched) async {
    final key = _key(seasonNumber, episodeNumber);
    if (_pendingEpisodes.contains(key)) return;

    setState(() => _pendingEpisodes.add(key));
    try {
      // the backend returns the show with its totals already redone,
      // so we never recompute progress on this side
      final updated = await _service.markEpisode(
        showTmdbId: widget.showTmdbId,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
        watched: watched,
      );
      if (!mounted) return;
      setState(() {
        _progress = updated;
        _pendingEpisodes.remove(key);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _pendingEpisodes.remove(key));
      _snack("Could not update that episode");
    }
  }

  Future<void> _toggleSeason(int seasonNumber, bool watched) async {
    if (_pendingSeasons.contains(seasonNumber)) return;
    setState(() => _pendingSeasons.add(seasonNumber));
    try {
      final updated = await _service.markSeason(
        showTmdbId: widget.showTmdbId,
        seasonNumber: seasonNumber,
        watched: watched,
      );
      if (!mounted) return;
      setState(() {
        _progress = updated;
        _pendingSeasons.remove(seasonNumber);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _pendingSeasons.remove(seasonNumber));
      _snack("Could not update that season");
    }
  }

  // without this there is no way to add a show you have not started, or to put
  // one on hold, since a UserShow row is otherwise only created by ticking an episode
  Future<void> _setStatus(String status) async {
    try {
      final updated = await _service.setStatus(widget.showTmdbId, status);
      if (!mounted) return;
      setState(() => _progress = updated);
      _snack("Moved to ${_statusLabel(status)}");
    } catch (e) {
      if (!mounted) return;
      _snack("Could not change the status");
    }
  }

  Future<void> _loadRating(int showId) async {
    try {
      final summary = await _service.ratingSummary("SHOW", showId);
      if (!mounted) return;
      setState(() {
        _averageRating = summary.average;
        _ratingCount = summary.count;
        _myRating = summary.mine;
        // pull the review back too, otherwise re-rating overwrites it with nothing
        _myComment = summary.myComment;
      });
    } catch (e) {
      // a missing rating summary should not stop the page rendering
    }
  }

  void _openRatingSheet() {
    final progress = _progress;
    if (progress == null) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => RatingSheet(
        title: progress.title,
        initialScore: _myRating,
        initialComment: _myComment,
        onSubmit: (score, comment) async {
          await _service.rate(
            targetType: "SHOW",
            targetId: progress.showId,
            score: score,
            comment: comment,
          );
          _myComment = comment;
          await _loadRating(progress.showId);
        },
        onClear: () async {
          await _service.deleteRating("SHOW", progress.showId);
          if (!mounted) return;
          setState(() {
            _myRating = null;
            _myComment = null;
          });
          await _loadRating(progress.showId);
        },
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          progress?.title ?? widget.initialTitle ?? "Show",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded),
            tooltip: "Status",
            onSelected: _setStatus,
            itemBuilder: (_) => const [
              PopupMenuItem(value: "WATCHLIST", child: Text("Watchlist")),
              PopupMenuItem(value: "WATCHING", child: Text("Watching")),
              PopupMenuItem(value: "ON_HOLD", child: Text("On hold")),
              PopupMenuItem(value: "COMPLETED", child: Text("Completed")),
              PopupMenuItem(value: "DROPPED", child: Text("Dropped")),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(children: const [_DetailsSkeleton()])
            : progress == null
                ? ListView(
                    children: [
                      const SizedBox(height: 80),
                      EmptyState(
                        icon: Icons.wifi_off_rounded,
                        title: _error ?? "Nothing here",
                        actionLabel: "Try again",
                        onAction: _load,
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 32),
                    children: [
                      _header(progress),
                      const SizedBox(height: 4),
                      ...progress.seasons.map((s) => _seasonTile(s)),
                    ],
                  ),
      ),
    );
  }

  Widget _header(ShowProgress progress) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final meta = [
      if (progress.genre != null && progress.genre!.isNotEmpty) progress.genre!,
      if (progress.tmdbStatus != null) _airingLabel(progress.tmdbStatus!),
    ].join("  ·  ");

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PosterImage(
                url: progress.posterUrl,
                width: 104,
                height: 156,
                radius: 12,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(progress.title, style: theme.textTheme.headlineMedium),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(meta, style: theme.textTheme.bodySmall),
                    ],
                    const SizedBox(height: 12),
                    if (progress.status != null)
                      _statusPill(_statusLabel(progress.status!)),
                    const SizedBox(height: 12),
                    // your own score sits with the title, the way it does on a
                    // shelf. tap the stars to change it
                    InkWell(
                      onTap: _openRatingSheet,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            StarRating(value: _myRating ?? 0, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              _myRating == null
                                  ? "Rate"
                                  : _myRating!.toStringAsFixed(1),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_ratingCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          "$_averageRating average from $_ratingCount",
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                "${progress.episodesWatched} of ${progress.totalEpisodes} episodes",
                style: theme.textTheme.labelLarge,
              ),
              const Spacer(),
              Text("${progress.percentComplete}%",
                  style: theme.textTheme.labelMedium),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress.totalEpisodes == 0
                  ? 0
                  : progress.episodesWatched / progress.totalEpisodes,
              minHeight: 5,
              backgroundColor: cs.onSurfaceVariant.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(height: 16),
          // what to watch next, straight from the backend pointer
          if (progress.hasNext)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _jumpToNext(progress),
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: Text("Up next  ·  ${progress.nextLabel}"),
              ),
            )
          else if (progress.episodesWatched > 0)
            Row(
              children: [
                Icon(Icons.check_rounded, size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Text("All caught up", style: theme.textTheme.bodySmall),
              ],
            ),
          if (progress.overview.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(progress.overview, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 20),
          Divider(color: cs.outline, height: 1),
        ],
      ),
    );
  }

  void _jumpToNext(ShowProgress progress) {
    final season = progress.nextSeasonNumber!;
    _loadSeason(season);
    // ExpansionTile only honours initiallyExpanded on build, so change the key
    // for that season to force it to rebuild open
    setState(() => _expandSeason = season);
  }

  Widget _statusPill(String label) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: cs.primary),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case "WATCHLIST":
        return "Watchlist";
      case "WATCHING":
        return "Watching";
      case "CAUGHT_UP":
        return "Caught up";
      case "COMPLETED":
        return "Completed";
      case "ON_HOLD":
        return "On hold";
      case "DROPPED":
        return "Dropped";
      default:
        return status;
    }
  }

  // tmdb writes these for an api, not for someone reading a screen
  String _airingLabel(String tmdbStatus) {
    switch (tmdbStatus) {
      case "Returning Series":
        return "Airing";
      case "In Production":
      case "Planned":
        return "Coming soon";
      case "Ended":
        return "Ended";
      case "Canceled":
        return "Cancelled";
      default:
        return tmdbStatus;
    }
  }

  // one season. collapsed it is a title and a hairline of progress, expanding
  // loads the episodes.
  Widget _seasonTile(SeasonProgress season) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final episodes = _episodesBySeason[season.seasonNumber];
    final isLoading = _loadingSeasons.contains(season.seasonNumber);
    final shouldOpen = _expandSeason == season.seasonNumber;

    return Column(
      children: [
        Theme(
          // the divider ExpansionTile draws fights the one we already have
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: ValueKey("season-${season.seasonNumber}-$shouldOpen"),
            initiallyExpanded: shouldOpen,
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            onExpansionChanged: (open) {
              if (open) {
                _loadSeason(season.seasonNumber);
                return;
              }
              // forget the up next target when it is closed by hand, so the
              // key changes again on the next tap
              if (_expandSeason == season.seasonNumber) {
                setState(() => _expandSeason = null);
              }
            },
            title: Row(
              children: [
                Expanded(
                  child: Text(season.displayName,
                      style: theme.textTheme.titleMedium),
                ),
                if (season.complete)
                  Icon(Icons.check_circle_rounded, size: 16, color: cs.primary),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 7, right: 4),
              child: Row(
                children: [
                  Text(
                    "${season.watchedCount}/${season.episodeCount}",
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: season.episodeCount == 0
                            ? 0
                            : season.watchedCount / season.episodeCount,
                        minHeight: 3,
                        backgroundColor:
                            cs.onSurfaceVariant.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  // one call marks the whole season, rather than one request per episode
                  child: TextButton.icon(
                    onPressed: _pendingSeasons.contains(season.seasonNumber)
                        ? null
                        : () => _toggleSeason(
                            season.seasonNumber, !season.complete),
                    icon: Icon(
                      season.complete
                          ? Icons.remove_done_rounded
                          : Icons.done_all_rounded,
                      size: 17,
                    ),
                    label: Text(
                        season.complete ? "Clear season" : "Mark all watched"),
                  ),
                ),
              ),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (episodes == null)
                const SizedBox.shrink()
              else if (episodes.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text("No episodes listed",
                      style: theme.textTheme.bodySmall),
                )
              else
                ...episodes.map((e) => _episodeTile(season, e)),
              const SizedBox(height: 8),
            ],
          ),
        ),
        Divider(color: cs.outline, height: 1, indent: 16, endIndent: 16),
      ],
    );
  }

  Widget _episodeTile(SeasonProgress season, Episode episode) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final watched = season.watchedEpisodes.contains(episode.episodeNumber);
    final pending = _pendingEpisodes.contains(
      _key(season.seasonNumber, episode.episodeNumber),
    );

    return InkWell(
      onTap: pending
          ? null
          : () => _toggleEpisode(
              season.seasonNumber, episode.episodeNumber, !watched),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 7, 16, 7),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: pending
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      watched
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      size: 19,
                      color: watched
                          ? cs.primary
                          : cs.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 26,
              child: Text(
                "${episode.episodeNumber}",
                style: theme.textTheme.labelSmall,
              ),
            ),
            Expanded(
              child: Text(
                episode.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: watched ? cs.onSurfaceVariant : cs.onSurface,
                ),
              ),
            ),
            if (episode.airDate != null) ...[
              const SizedBox(width: 8),
              Text(_shortDate(episode.airDate!),
                  style: theme.textTheme.labelSmall),
            ],
          ],
        ),
      ),
    );
  }

  // "2024-03-12" is not something anyone wants to read down a list
  String _shortDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    return "${months[parsed.month - 1]} ${parsed.year}";
  }
}

// keeps the page shaped like the real thing while it loads
class _DetailsSkeleton extends StatelessWidget {
  const _DetailsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 104, height: 156, radius: 12),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 170, height: 20, radius: 6),
                    SizedBox(height: 10),
                    SkeletonBox(width: 110, height: 12, radius: 6),
                    SizedBox(height: 18),
                    SkeletonBox(width: 90, height: 22, radius: 20),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 26),
          SkeletonBox(width: double.infinity, height: 5, radius: 3),
          SizedBox(height: 24),
          SkeletonBox(width: double.infinity, height: 44, radius: 10),
        ],
      ),
    );
  }
}
