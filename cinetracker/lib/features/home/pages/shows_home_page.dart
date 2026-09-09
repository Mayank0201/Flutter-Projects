import 'package:flutter/material.dart';

import '../../../model/show_model.dart';
import '../../../service/show_service.dart';
import '../widgets/continue_watching_row.dart';
import '../widgets/empty_state.dart';
import '../widgets/poster_image.dart';
import 'show_details_page.dart';

// the tv home tab. continue watching on top, then popular shows by genre.
// replaces the movie home tab, which stays in the codebase but is no longer routed to.
class ShowsHomePage extends StatefulWidget {
  const ShowsHomePage({super.key});

  @override
  State<ShowsHomePage> createState() => _ShowsHomePageState();
}

class _ShowsHomePageState extends State<ShowsHomePage> {
  final ShowService _service = ShowService();
  final GlobalKey<ContinueWatchingRowState> _continueKey = GlobalKey();
  final ScrollController _scroll = ScrollController();

  List<Map<String, dynamic>> _genres = const [];
  List<Show> _shows = [];
  int? _selectedGenreId;
  bool _loading = true;
  bool _loadingMore = false;
  bool _exhausted = false;
  int _page = 1;
  // bumped on every genre change so a slow reply from the old genre is dropped
  int _request = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _loading || _loadingMore || _exhausted) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // tv genre ids are their own set, not the movie ones
      final results = await Future.wait([
        _service.getGenres(),
        _service.getPopularShows(),
      ]);
      if (!mounted) return;
      final shows = results[1] as List<Show>;
      setState(() {
        _genres = results[0] as List<Map<String, dynamic>>;
        _shows = shows;
        _page = 1;
        _exhausted = shows.isEmpty;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Could not load shows";
        _loading = false;
      });
    }
  }

  Future<void> _selectGenre(int? genreId) async {
    final seq = ++_request;
    setState(() {
      _selectedGenreId = genreId;
      _loading = true;
      _page = 1;
      _exhausted = false;
      // clear the old error too, otherwise one failure sticks around forever
      _error = null;
    });
    try {
      final shows = genreId == null
          ? await _service.getPopularShows()
          : await _service.getShowsByGenre(genreId);
      if (!mounted || seq != _request) return;
      setState(() {
        _shows = shows;
        _exhausted = shows.isEmpty;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _request) return;
      setState(() {
        _error = "Could not load that genre";
        _loading = false;
      });
    }
  }

  // next page of whatever is on screen, appended
  Future<void> _loadMore() async {
    final seq = _request;
    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final more = _selectedGenreId == null
          ? await _service.getPopularShows(page: next)
          : await _service.getShowsByGenre(_selectedGenreId!, page: next);
      if (!mounted || seq != _request) return;
      setState(() {
        _shows = [..._shows, ...more];
        _page = next;
        _exhausted = more.isEmpty;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted || seq != _request) return;
      // a failed page should not kill the list already on screen
      setState(() {
        _loadingMore = false;
        _exhausted = true;
      });
    }
  }

  Future<void> _refresh() async {
    await _continueKey.currentState?.reload();
    await _selectGenre(_selectedGenreId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Shows")),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverToBoxAdapter(child: ContinueWatchingRow(key: _continueKey)),
            SliverToBoxAdapter(child: _genreBar()),
            if (_loading)
              _skeletonGrid()
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.wifi_off_rounded,
                  title: _error!,
                  actionLabel: "Try again",
                  onAction: () => _selectGenre(_selectedGenreId),
                ),
              )
            else if (_shows.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.tv_off_rounded,
                  title: "Nothing here",
                  hint: "Try another genre",
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _showCard(_shows[i]),
                    childCount: _shows.length,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: _loadingMore ? 56 : 24,
                  child: _loadingMore
                      ? const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _genreBar() {
    if (_genres.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: _genres.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (_, i) {
          if (i == 0) {
            return _genreChip("All", _selectedGenreId == null,
                () => _selectGenre(null));
          }
          final genre = _genres[i - 1];
          final id = genre["id"] as int;
          return _genreChip(genre["name"] as String, _selectedGenreId == id,
              () => _selectGenre(id));
        },
      ),
    );
  }

  // a pill that fills in when it is picked, rather than the default chip tick
  Widget _genreChip(String label, bool selected, VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? cs.primary : cs.outline,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? cs.onPrimary : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _skeletonGrid() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.5,
          crossAxisSpacing: 10,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Expanded(
                child: SkeletonBox(
                    width: double.infinity, height: double.infinity, radius: 10),
              ),
              SizedBox(height: 7),
              SkeletonBox(width: 70, height: 10, radius: 4),
              SizedBox(height: 5),
              SkeletonBox(width: 40, height: 9, radius: 4),
            ],
          ),
          childCount: 9,
        ),
      ),
    );
  }

  Widget _showCard(Show show) {
    final theme = Theme.of(context);

    final meta = [
      if (show.firstAirYear != null) "${show.firstAirYear}",
      if (show.genre.isNotEmpty && show.genre != "N/A") show.genre,
    ].join("  ·  ");

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ShowDetailsPage(
              showTmdbId: show.tmdbId,
              initialTitle: show.title,
            ),
          ),
        );
        _continueKey.currentState?.reload();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (_, box) => PosterImage(
                url: show.posterUrl,
                width: box.maxWidth,
                height: box.maxHeight,
                radius: 10,
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            show.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (meta.isNotEmpty)
            Text(
              meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall,
            ),
        ],
      ),
    );
  }
}
