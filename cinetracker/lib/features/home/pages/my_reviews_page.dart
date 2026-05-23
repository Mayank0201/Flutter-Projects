import 'package:flutter/material.dart';
import '../../../model/review_model.dart';
import '../../../service/rating_service.dart';
import '../../../model/movie_model.dart';
import 'movie_details_page.dart';

class MyReviewsPage extends StatefulWidget {
  const MyReviewsPage({super.key});

  @override
  State<MyReviewsPage> createState() => _MyReviewsPageState();
}

class _MyReviewsPageState extends State<MyReviewsPage> {
  final RatingService _ratingService = RatingService();
  final List<Review> _reviews = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  int _page = 1;
  static const int _pageSize = 10;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadReviews();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadReviews({bool reset = false}) async {
    if (reset) {
      _page = 1;
      _reviews.clear();
      _hasMore = true;
    }

    setState(() {
      _isLoading = reset || _reviews.isEmpty;
      _error = null;
    });

    try {
      final items = await _ratingService.getMyReviews(
        page: _page,
        size: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _reviews.addAll(items);
        _hasMore = items.length == _pageSize;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your reviews.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    _page++;
    try {
      final items = await _ratingService.getMyReviews(
        page: _page,
        size: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _reviews.addAll(items);
        _hasMore = items.length == _pageSize;
        _isLoadingMore = false;
      });
    } catch (_) {
      _page--;
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _deleteReview(Review review) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Review'),
        content: const Text('Are you sure you want to delete this review and rating?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _ratingService.deleteRating(review.movieId);
      if (!mounted) return;
      setState(() {
        _reviews.removeWhere((r) => r.id == review.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review deleted successfully.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete review.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reviews'),
      ),
      body: _buildBody(theme, colorScheme),
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme colorScheme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: colorScheme.error.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 14),
            Text(_error!, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _loadReviews(reset: true),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.rate_review_outlined,
              size: 56,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'No reviews yet',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Share your thoughts on movies you have watched!',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadReviews(reset: true),
      color: colorScheme.primary,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _reviews.length + (_isLoadingMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == _reviews.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          final review = _reviews[index];
          return _MyReviewCard(
            review: review,
            onDelete: () => _deleteReview(review),
          );
        },
      ),
    );
  }
}

class _MyReviewCard extends StatelessWidget {
  final Review review;
  final VoidCallback onDelete;

  const _MyReviewCard({required this.review, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final subtitle = [
      if (review.movieReleaseYear != null) review.movieReleaseYear.toString(),
      if (review.movieGenre != null && review.movieGenre!.isNotEmpty) review.movieGenre,
    ].join(' • ');

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MovieDetailsPage(
                movie: Movie(
                  id: review.movieId,
                  title: review.movieTitle ?? 'Unknown Movie',
                  poster: review.moviePosterUrl ?? '',
                  releaseYear: review.movieReleaseYear,
                  genre: review.movieGenre ?? 'N/A',
                ),
              ),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colorScheme.outline.withValues(alpha: 0.15)),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: review.moviePosterUrl != null && review.moviePosterUrl!.isNotEmpty
                    ? Image.network(
                        review.moviePosterUrl!,
                        width: 56,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _posterPlaceholder(colorScheme),
                      )
                    : _posterPlaceholder(colorScheme),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            review.movieTitle ?? 'Unknown Movie',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: onDelete,
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: colorScheme.error.withValues(alpha: 0.7),
                            size: 20,
                          ),
                          tooltip: 'Delete review',
                        ),
                      ],
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    // Rating stars
                    Row(
                      children: [
                        ...List.generate(5, (i) {
                          final filled = review.rating >= i + 1;
                          return Icon(
                            filled ? Icons.star_rounded : Icons.star_outline_rounded,
                            size: 16,
                            color: filled
                                ? const Color(0xFFFFB800)
                                : colorScheme.onSurface.withValues(alpha: 0.2),
                          );
                        }),
                        const SizedBox(width: 6),
                        Text(
                          review.rating.toStringAsFixed(1),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (review.comment != null && review.comment!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        review.comment!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _posterPlaceholder(ColorScheme cs) => Container(
        width: 56,
        height: 80,
        color: cs.surfaceContainerHighest,
        child: Icon(Icons.movie_rounded, color: cs.onSurfaceVariant),
      );
}
