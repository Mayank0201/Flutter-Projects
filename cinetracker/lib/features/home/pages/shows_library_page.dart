import 'package:flutter/material.dart';

import '../../../model/show_model.dart';
import '../../../service/show_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/poster_image.dart';
import 'show_details_page.dart';

// the shows you keep, filtered by status. replaces the movie watchlist.
class ShowsLibraryPage extends StatefulWidget {
  const ShowsLibraryPage({super.key});

  @override
  State<ShowsLibraryPage> createState() => _ShowsLibraryPageState();
}

// null status means every show
const _filters = <({String? status, String label})>[
  (status: null, label: "All"),
  (status: "WATCHLIST", label: "Watchlist"),
  (status: "WATCHING", label: "Watching"),
  (status: "CAUGHT_UP", label: "Caught up"),
  (status: "COMPLETED", label: "Completed"),
  (status: "ON_HOLD", label: "On hold"),
  (status: "DROPPED", label: "Dropped"),
];

const _statusLabels = <String, String>{
  "WATCHLIST": "Watchlist",
  "WATCHING": "Watching",
  "CAUGHT_UP": "Caught up",
  "COMPLETED": "Completed",
  "ON_HOLD": "On hold",
  "DROPPED": "Dropped",
};

class _ShowsLibraryPageState extends State<ShowsLibraryPage> {
  final ShowService _service = ShowService();
  final ScrollController _scroll = ScrollController();

  final List<LibraryItem> _items = [];
  String? _status;
  int _page = 1;
  bool _last = false;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  // bumped on every filter change so a slow reply from the old filter is dropped
  int _request = 0;

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
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - 300) _loadMore();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final paged = await _service.getLibrary(status: _status, page: 1);
      if (!mounted || request != _request) return;
      setState(() {
        _items
          ..clear()
          ..addAll(paged.items);
        _page = 1;
        _last = paged.last;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = "Could not load your shows";
        _loading = false;
      });
    }
  }

  // one page at a time, never two at once
  Future<void> _loadMore() async {
    if (_loading || _loadingMore || _last || _error != null) return;
    final request = _request;
    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final paged = await _service.getLibrary(status: _status, page: next);
      if (!mounted || request != _request) return;
      setState(() {
        _items.addAll(paged.items);
        _page = next;
        _last = paged.last;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted || request != _request) return;
      setState(() => _loadingMore = false);
    }
  }

  void _selectFilter(String? status) {
    if (status == _status) return;
    setState(() {
      _status = status;
      _items.clear();
      _last = false;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _load();
  }

  Future<void> _open(LibraryItem item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShowDetailsPage(
          showTmdbId: item.tmdbId,
          initialTitle: item.title,
        ),
      ),
    );
    // progress usually moved while that page was open
    if (!mounted) return;
    _load();
  }

  Future<bool> _confirmRemove(LibraryItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remove show"),
        content: Text("${item.title} and your episode progress will be dropped"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text("Remove"),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _remove(LibraryItem item) async {
    // drop it locally first, the list would jump about otherwise
    final index = _items.indexWhere((e) => e.showId == item.showId);
    if (index >= 0) setState(() => _items.removeAt(index));
    try {
      await _service.removeShow(item.tmdbId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Removed ${item.title}")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not remove that show")),
      );
      _load();
    }
  }

  Future<void> _changeStatus(LibraryItem item) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in _statusLabels.entries)
              ListTile(
                title: Text(entry.value),
                trailing: item.status == entry.key
                    ? Icon(Icons.check_rounded,
                        color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () => Navigator.pop(context, entry.key),
              ),
          ],
        ),
      ),
    );
    if (picked == null || picked == item.status) return;
    try {
      await _service.setStatus(item.tmdbId, picked);
      if (!mounted) return;
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not change the status")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My shows")),
      body: Column(
        children: [
          _filterBar(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _filterBar() {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final filter = _filters[i];
          return FilterChip(
            label: Text(filter.label),
            selected: _status == filter.status,
            onSelected: (_) => _selectFilter(filter.status),
          );
        },
      ),
    );
  }

  Widget _body() {
    if (_loading) return _skeletons();

    if (_error != null) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: _error!,
        actionLabel: "Retry",
        onAction: _load,
      );
    }

    if (_items.isEmpty) {
      return _refreshable(
        EmptyState(
          icon: Icons.live_tv_rounded,
          title: _status == null ? "No shows yet" : "Nothing here",
          hint: _status == null
              ? "Shows you add turn up here"
              : "Try another filter",
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          if (i == _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          return _row(_items[i]);
        },
      ),
    );
  }

  // an empty list still has to be pullable, or adding a show elsewhere leaves
  // this screen stuck on nothing
  Widget _refreshable(Widget child) {
    return RefreshIndicator(
      onRefresh: _load,
      child: LayoutBuilder(
        builder: (_, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _skeletons() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(width: 58, height: 86),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(width: 150, height: 14, radius: 4),
                SizedBox(height: 8),
                SkeletonBox(width: 90, height: 11, radius: 4),
                SizedBox(height: 14),
                SkeletonBox(width: double.infinity, height: 4, radius: 2),
                SizedBox(height: 10),
                SkeletonBox(width: 110, height: 11, radius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(LibraryItem item) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Dismissible(
      key: ValueKey(item.showId),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmRemove(item),
      onDismissed: (_) => _remove(item),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        decoration: BoxDecoration(
          color: cs.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_outline_rounded, color: cs.onErrorContainer),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _open(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PosterImage(url: item.posterUrl, width: 58, height: 86),
              const SizedBox(width: 12),
              Expanded(child: _details(item, theme)),
              _menu(item),
            ],
          ),
        ),
      ),
    );
  }

  Widget _details(LibraryItem item, ThemeData theme) {
    final cs = theme.colorScheme;
    final hasTotal = item.totalEpisodes > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.title,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Text(
              _statusLabels[item.status] ?? item.status,
              style: theme.textTheme.labelSmall?.copyWith(color: cs.primary),
            ),
            if (item.genre != null && item.genre!.isNotEmpty) ...[
              Text(
                "  ·  ",
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              Expanded(
                child: Text(
                  item.genre!,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: (item.percentComplete / 100).clamp(0.0, 1.0),
            minHeight: 4,
            backgroundColor: cs.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              hasTotal
                  ? "${item.episodesWatched} / ${item.totalEpisodes} episodes"
                  : "${item.episodesWatched} episodes",
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            if (item.hasNext) ...[
              const Spacer(),
              Text(
                "Next ${item.nextLabel}",
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: cs.primary, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _menu(LibraryItem item) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, size: 18),
      tooltip: "More",
      padding: EdgeInsets.zero,
      onSelected: (value) async {
        if (value == "status") {
          await _changeStatus(item);
          return;
        }
        final ok = await _confirmRemove(item);
        if (!mounted || !ok) return;
        await _remove(item);
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: "status", child: Text("Change status")),
        PopupMenuItem(value: "remove", child: Text("Remove")),
      ],
    );
  }
}
