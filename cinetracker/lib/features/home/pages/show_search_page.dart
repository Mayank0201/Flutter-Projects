import 'dart:async';

import 'package:flutter/material.dart';

import '../../../model/show_model.dart';
import '../../../service/show_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/poster_image.dart';
import 'show_details_page.dart';

// tv search. same debounce shape as the old movie search, pointed at /show/search.
class ShowSearchPage extends StatefulWidget {
  const ShowSearchPage({super.key});

  @override
  State<ShowSearchPage> createState() => _ShowSearchPageState();
}

class _ShowSearchPageState extends State<ShowSearchPage> {
  final ShowService _service = ShowService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();

  Timer? _debounce;
  // bumped per search so a slow earlier reply cannot overwrite a newer one
  int _searchSeq = 0;
  List<Show> _results = [];
  String _activeQuery = "";
  int _page = 1;
  bool _loading = false;
  bool _loadingMore = false;
  bool _exhausted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _loading || _loadingMore || _exhausted) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();

    if (query.isEmpty) {
      // a newer sequence number also cancels any reply still in flight
      _searchSeq++;
      setState(() {
        _results = [];
        _activeQuery = "";
        _loading = false;
        _exhausted = false;
        _error = null;
      });
      return;
    }

    // redraw now so the clear button and the placeholder keep up with typing
    setState(() {});

    // wait for a pause in typing so we do not fire a request per keystroke
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(query));
  }

  Future<void> _search(String query) async {
    final seq = ++_searchSeq;
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
      _exhausted = false;
    });
    try {
      final results = await _service.searchShows(query);
      // a newer search started while this one was in flight, drop this reply
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _results = results;
        _activeQuery = query;
        _exhausted = results.isEmpty;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _error = "Search failed";
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_activeQuery.isEmpty) return;
    final seq = _searchSeq;
    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final more = await _service.searchShows(_activeQuery, page: next);
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _results = [..._results, ...more];
        _page = next;
        _exhausted = more.isEmpty;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted || seq != _searchSeq) return;
      // keep what is already on screen, just stop asking for more
      setState(() {
        _loadingMore = false;
        _exhausted = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Search")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: "Show name",
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _controller.clear();
                          _onChanged("");
                        },
                      ),
              ),
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return _skeletonList();

    if (_error != null) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: _error!,
        actionLabel: "Try again",
        onAction: () => _search(_controller.text.trim()),
      );
    }

    if (_controller.text.trim().isEmpty) {
      return const EmptyState(
        icon: Icons.search_rounded,
        title: "Find a show",
        hint: "Search by name to start tracking it",
      );
    }

    if (_results.isEmpty) {
      return const EmptyState(
        icon: Icons.tv_off_rounded,
        title: "Nothing matched",
        hint: "Check the spelling, or try a shorter name",
      );
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _results.length + (_loadingMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i >= _results.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return _resultRow(_results[i]);
      },
    );
  }

  Widget _resultRow(Show show) {
    final theme = Theme.of(context);

    final meta = [
      if (show.firstAirYear != null) "${show.firstAirYear}",
      if (show.genre.isNotEmpty && show.genre != "N/A") show.genre,
    ].join("  ·  ");

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ShowDetailsPage(
            showTmdbId: show.tmdbId,
            initialTitle: show.title,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PosterImage(url: show.posterUrl, width: 48, height: 72, radius: 8),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 3),
                  Text(
                    show.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(meta, style: theme.textTheme.labelSmall),
                  ],
                  if (show.overview.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      show.overview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _skeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 7,
      itemBuilder: (_, _) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 48, height: 72, radius: 8),
            SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 4),
                  SkeletonBox(width: 150, height: 13, radius: 4),
                  SizedBox(height: 8),
                  SkeletonBox(width: 80, height: 10, radius: 4),
                  SizedBox(height: 10),
                  SkeletonBox(width: double.infinity, height: 9, radius: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
