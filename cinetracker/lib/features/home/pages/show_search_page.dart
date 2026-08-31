import 'dart:async';

import 'package:flutter/material.dart';

import '../../../model/show_model.dart';
import '../../../service/show_service.dart';
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

  Timer? _debounce;
  // bumped per search so a slow earlier reply cannot overwrite a newer one
  int _searchSeq = 0;
  List<Show> _results = const [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();

    if (query.isEmpty) {
      setState(() {
        _results = const [];
        _loading = false;
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
    });
    try {
      final results = await _service.searchShows(query);
      // a newer search started while this one was in flight, drop this reply
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _error = "Search failed. Try again.";
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Search shows")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: "Search for a show...",
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _controller.clear();
                          _onChanged("");
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
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
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));

    if (_controller.text.trim().isEmpty) {
      return const Center(child: Text("Search for a show to begin"));
    }
    if (_results.isEmpty) return const Center(child: Text("No shows found."));

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final show = _results[i];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: show.posterUrl != null
                ? Image.network(
                    show.posterUrl!,
                    width: 46,
                    height: 68,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _fallback(),
                  )
                : _fallback(),
          ),
          title: Text(show.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            [
              if (show.firstAirYear != null) "${show.firstAirYear}",
              show.genre,
            ].join("  ·  "),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ShowDetailsPage(
                showTmdbId: show.tmdbId,
                initialTitle: show.title,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _fallback() => Container(
        width: 46,
        height: 68,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.tv_rounded, size: 20),
      );
}
