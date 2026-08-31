import 'package:flutter/material.dart';

import '../../../model/show_model.dart';
import '../../../service/show_service.dart';

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
        _error = "Could not load this show. Pull to retry.";
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

  Future<void> _toggleEpisode(int seasonNumber, int episodeNumber, bool watched) async {
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
      _snack("Could not update that episode.");
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
      _snack("Could not update that season.");
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
      _snack("Could not change the status.");
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
      });
    } catch (e) {
      // a missing rating summary should not stop the page rendering
    }
  }

  Future<void> _rate(double score) async {
    final progress = _progress;
    if (progress == null) return;
    try {
      await _service.rate(
        targetType: "SHOW",
        targetId: progress.showId,
        score: score,
      );
      await _loadRating(progress.showId);
      if (!mounted) return;
      _snack("Rated $score");
    } catch (e) {
      if (!mounted) return;
      _snack("Could not save that rating.");
    }
  }

  // half stars, same 0.5 steps the backend enforces
  void _openRatingSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Rate this show",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                children: List.generate(10, (i) {
                  final score = (i + 1) * 0.5;
                  return ChoiceChip(
                    label: Text(score.toString()),
                    selected: _myRating == score,
                    onSelected: (_) {
                      Navigator.pop(sheetContext);
                      _rate(score);
                    },
                  );
                }),
              ),
            ],
          ),
        ),
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
        title: Text(progress?.title ?? widget.initialTitle ?? "Show"),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.bookmark_border_rounded),
            tooltip: "Set status",
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
            ? ListView(children: const [
                SizedBox(height: 160),
                Center(child: CircularProgressIndicator()),
              ])
            : progress == null
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      Center(child: Text(_error ?? "Nothing here.")),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 32),
                    children: [
                      _header(progress),
                      const SizedBox(height: 8),
                      ...progress.seasons.map((s) => _seasonTile(s)),
                    ],
                  ),
      ),
    );
  }

  Widget _header(ShowProgress progress) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: progress.posterUrl != null
                    ? Image.network(
                        progress.posterUrl!,
                        width: 110,
                        height: 165,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _posterFallback(),
                      )
                    : _posterFallback(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(progress.title,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    if (progress.genre != null)
                      Text(progress.genre!, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (progress.status != null) _chip(_statusLabel(progress.status!)),
                        if (progress.tmdbStatus != null) _chip(progress.tmdbStatus!),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // overall progress across every season
          Text(
            "${progress.episodesWatched} of ${progress.totalEpisodes} episodes",
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.totalEpisodes == 0
                  ? 0
                  : progress.episodesWatched / progress.totalEpisodes,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 14),
          // what to watch next, straight from the backend pointer
          if (progress.hasNext)
            FilledButton.icon(
              onPressed: () => _jumpToNext(progress),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text("Up next  ${progress.nextLabel}"),
            )
          else if (progress.episodesWatched > 0)
            const Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 18),
                SizedBox(width: 6),
                Text("All caught up"),
              ],
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _openRatingSheet,
                icon: Icon(
                  _myRating == null ? Icons.star_border_rounded : Icons.star_rounded,
                  size: 18,
                ),
                label: Text(_myRating == null ? "Rate" : "Your rating  $_myRating"),
              ),
              const SizedBox(width: 12),
              if (_ratingCount > 0)
                Text(
                  "$_averageRating  ($_ratingCount)",
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
          if (progress.overview.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text("Overview", style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(progress.overview, style: theme.textTheme.bodySmall),
          ],
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

  Widget _posterFallback() => Container(
        width: 110,
        height: 165,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.tv_rounded, size: 36),
      );

  Widget _chip(String label) => Chip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );

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

  // one season. collapsed it is just a progress row, expanding loads the episodes.
  Widget _seasonTile(SeasonProgress season) {
    final episodes = _episodesBySeason[season.seasonNumber];
    final isLoading = _loadingSeasons.contains(season.seasonNumber);

    final shouldOpen = _expandSeason == season.seasonNumber;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: ValueKey("season-${season.seasonNumber}-$shouldOpen"),
        initiallyExpanded: shouldOpen,
        onExpansionChanged: (open) {
          if (open) _loadSeason(season.seasonNumber);
        },
        title: Text(
          season.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("${season.watchedCount} / ${season.episodeCount} episodes"),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: season.episodeCount == 0
                      ? 0
                      : season.watchedCount / season.episodeCount,
                  minHeight: 5,
                ),
              ),
            ],
          ),
        ),
        // only override the chevron when the season is done, otherwise let
        // ExpansionTile keep its rotating one
        trailing: season.complete ? const Icon(Icons.check_circle_rounded) : null,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                // one call marks the whole season, rather than one request per episode
                TextButton.icon(
                  onPressed: _pendingSeasons.contains(season.seasonNumber)
                      ? null
                      : () => _toggleSeason(season.seasonNumber, !season.complete),
                  icon: Icon(
                    season.complete
                        ? Icons.remove_done_rounded
                        : Icons.done_all_rounded,
                    size: 18,
                  ),
                  label: Text(season.complete ? "Clear season" : "Mark season watched"),
                ),
              ],
            ),
          ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (episodes == null)
            const SizedBox.shrink()
          else if (episodes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text("No episode details available."),
            )
          else
            ...episodes.map((e) => _episodeTile(season, e)),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _episodeTile(SeasonProgress season, Episode episode) {
    final watched = season.watchedEpisodes.contains(episode.episodeNumber);
    final pending = _pendingEpisodes.contains(
      _key(season.seasonNumber, episode.episodeNumber),
    );

    return CheckboxListTile(
      value: watched,
      onChanged: pending
          ? null
          : (value) => _toggleEpisode(
                season.seasonNumber,
                episode.episodeNumber,
                value ?? false,
              ),
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(
        "${episode.episodeNumber}. ${episode.name}",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          decoration: watched ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: episode.airDate != null
          ? Text(episode.airDate!, style: const TextStyle(fontSize: 11))
          : null,
      secondary: pending
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
    );
  }
}
