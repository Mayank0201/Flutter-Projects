import 'package:flutter/material.dart';

import '../../../model/show_model.dart';
import '../../../service/show_service.dart';
import '../widgets/continue_watching_row.dart';
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

  List<Map<String, dynamic>> _genres = const [];
  List<Show> _shows = const [];
  int? _selectedGenreId;
  bool _loading = true;
  String? _error;

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
      // tv genre ids are their own set, not the movie ones
      final results = await Future.wait([
        _service.getGenres(),
        _service.getPopularShows(),
      ]);
      if (!mounted) return;
      setState(() {
        _genres = results[0] as List<Map<String, dynamic>>;
        _shows = results[1] as List<Show>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Could not load shows. Pull down to retry.";
        _loading = false;
      });
    }
  }

  Future<void> _selectGenre(int? genreId) async {
    setState(() {
      _selectedGenreId = genreId;
      _loading = true;
      // clear the old error too, otherwise one failure sticks around forever
      _error = null;
    });
    try {
      final shows = genreId == null
          ? await _service.getPopularShows()
          : await _service.getShowsByGenre(genreId);
      if (!mounted) return;
      setState(() {
        _shows = shows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Could not load that genre.";
        _loading = false;
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
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.live_tv_rounded, size: 22),
            SizedBox(width: 8),
            Text("Shows"),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: ContinueWatchingRow(key: _continueKey)),
            SliverToBoxAdapter(child: _genreBar()),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text(_error!)),
              )
            else if (_shows.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text("No shows found.")),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.56,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _showCard(_shows[i]),
                    childCount: _shows.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _genreBar() {
    if (_genres.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _genres.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (i == 0) {
            return FilterChip(
              label: const Text("All"),
              selected: _selectedGenreId == null,
              onSelected: (_) => _selectGenre(null),
            );
          }
          final genre = _genres[i - 1];
          final id = genre["id"] as int;
          return FilterChip(
            label: Text(genre["name"] as String),
            selected: _selectedGenreId == id,
            onSelected: (_) => _selectGenre(id),
          );
        },
      ),
    );
  }

  Widget _showCard(Show show) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: show.posterUrl != null
                  ? Image.network(
                      show.posterUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallback(),
                    )
                  : _fallback(),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            show.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          Text(
            show.firstAirYear?.toString() ?? show.genre,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _fallback() => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.tv_rounded, size: 34)),
      );
}
