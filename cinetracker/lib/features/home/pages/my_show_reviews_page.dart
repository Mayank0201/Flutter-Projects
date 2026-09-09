import 'package:flutter/material.dart';

import '../../../model/show_model.dart';
import '../../../service/show_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/poster_image.dart';
import '../widgets/star_rating.dart';
import 'show_details_page.dart';

// everything you have rated, shows and seasons together
class MyShowReviewsPage extends StatefulWidget {
  const MyShowReviewsPage({super.key});

  @override
  State<MyShowReviewsPage> createState() => _MyShowReviewsPageState();
}

// null type means every rating
const _filters = <({String? type, String label})>[
  (type: null, label: "All"),
  (type: "SHOW", label: "Shows"),
  (type: "SEASON", label: "Seasons"),
];

const _months = <String>[
  "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
];

class _MyShowReviewsPageState extends State<MyShowReviewsPage> {
  final ShowService _service = ShowService();
  final ScrollController _scroll = ScrollController();

  final List<MyRating> _ratings = [];
  String? _type;
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
      final paged = await _service.getMyRatings(targetType: _type, page: 1);
      if (!mounted || request != _request) return;
      setState(() {
        _ratings
          ..clear()
          ..addAll(paged.items);
        _page = 1;
        _last = paged.last;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = "Could not load your ratings";
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
      final paged = await _service.getMyRatings(targetType: _type, page: next);
      if (!mounted || request != _request) return;
      setState(() {
        _ratings.addAll(paged.items);
        _page = next;
        _last = paged.last;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted || request != _request) return;
      setState(() => _loadingMore = false);
    }
  }

  void _selectFilter(String? type) {
    if (type == _type) return;
    setState(() {
      _type = type;
      _ratings.clear();
      _last = false;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _load();
  }

  Future<void> _open(MyRating rating) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShowDetailsPage(
          showTmdbId: rating.showTmdbId!,
          initialTitle: rating.title,
        ),
      ),
    );
    if (!mounted) return;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My ratings")),
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
            selected: _type == filter.type,
            onSelected: (_) => _selectFilter(filter.type),
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

    if (_ratings.isEmpty) {
      return _refreshable(
        EmptyState(
          icon: Icons.star_outline_rounded,
          title: _type == null ? "No ratings yet" : "Nothing here",
          hint: _type == null
              ? "Rate a show and it lands here"
              : "Try another filter",
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _ratings.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          if (i == _ratings.length) {
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
          return _row(_ratings[i]);
        },
      ),
    );
  }

  // an empty list still has to be pullable, or a rating left elsewhere leaves
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
          const SkeletonBox(width: 52, height: 78),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(width: 150, height: 14, radius: 4),
                SizedBox(height: 8),
                SkeletonBox(width: 70, height: 11, radius: 4),
                SizedBox(height: 12),
                SkeletonBox(width: 92, height: 12, radius: 4),
                SizedBox(height: 10),
                SkeletonBox(width: double.infinity, height: 11, radius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(MyRating rating) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PosterImage(url: rating.posterUrl, width: 52, height: 78),
          const SizedBox(width: 12),
          Expanded(child: _details(rating)),
        ],
      ),
    );

    // a row we cannot open should not look like a button
    if (!rating.canOpen) return content;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _open(rating),
      child: content,
    );
  }

  Widget _details(MyRating rating) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final comment = rating.comment;
    final date = _formatDate(rating.createdAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rating.title,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Text(
              rating.subtitle,
              style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            if (date != null) ...[
              const Spacer(),
              Text(
                date,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            StarRating(value: rating.score, size: 15),
            const SizedBox(width: 6),
            Text(
              rating.score.toStringAsFixed(1),
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        if (comment != null && comment.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            comment,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (rating.helpfulCount > 0) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.thumb_up_outlined, size: 12, color: cs.onSurfaceVariant),
              const SizedBox(width: 5),
              Text(
                "${rating.helpfulCount} found this helpful",
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // short date, no intl dependency in this project
  String? _formatDate(DateTime? date) {
    if (date == null) return null;
    return "${date.day} ${_months[date.month - 1]} ${date.year}";
  }
}
