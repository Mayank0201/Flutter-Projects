import 'package:flutter/material.dart';
import '../../../model/review_model.dart';
import '../../../service/rating_service.dart';
import '../../../service/tmdb_service.dart';
import 'movie_details_page.dart';
import 'movie_reviews_page.dart';

class MyReviewsPage extends StatefulWidget {
  const MyReviewsPage({super.key});

  @override
  State<MyReviewsPage> createState() => _MyReviewsPageState();
}

class _MyReviewsPageState extends State<MyReviewsPage> {
  final RatingService _ratingService = RatingService();
  final TMDBService _tmdbService = TMDBService();

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
        _error = 'Could not load reviews.';
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Review'),
        content: const Text('Are you sure you want to delete this review? This will also remove your rating for this movie.'),
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

    if (confirmed != true) return;

    // Optimistically update UI
    setState(() {
      _reviews.removeWhere((r) => r.id == review.id);
    });

    try {
      await _ratingService.deleteRating(review.movieId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review deleted successfully.')),
      );
    } catch (_) {
      if (!mounted) return;
      // Revert on error
      _loadReviews(reset: true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete review.')),
      );
    }
  }

  void _openMovie(int movieId, String movieTitle) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MovieReviewsPage(
          movieId: movieId,
          movieTitle: movieTitle,
        ),
      ),
    );
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
              'Go rate and review some movies to build your portfolio!',
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
        separatorBuilder: (_, _) => const SizedBox(height: 12),
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
            onTap: () => _openMovie(review.movieId, review.movieTitle ?? 'Movie'),
            onDelete: () => _deleteReview(review),
          );
        },
      ),
    );
  }
}

class _MyReviewCard extends StatelessWidget {
  final Review review;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _MyReviewCard({
    required this.review,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String formattedDate = '';
    try {
      final dt = DateTime.parse(review.createdAt);
      formattedDate =
          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      formattedDate = review.createdAt;
    }

    final hasMovieInfo = review.movieTitle != null && review.movieTitle!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasMovieInfo) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: review.moviePosterUrl != null && review.moviePosterUrl!.isNotEmpty
                          ? Image.network(
                              review.moviePosterUrl!,
                              width: 60,
                              height: 90,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildPosterPlaceholder(colorScheme),
                            )
                          : _buildPosterPlaceholder(colorScheme),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                review.movieTitle ?? 'Unknown Movie',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              onPressed: onDelete,
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                size: 20,
                                color: colorScheme.error.withValues(alpha: 0.8),
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Delete review',
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (review.movieReleaseYear != null) ...[
                              Text(
                                '${review.movieReleaseYear}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (review.movieGenre != null && review.movieGenre!.isNotEmpty)
                              Expanded(
                                child: Text(
                                  review.movieGenre!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Row(
                              children: List.generate(5, (i) {
                                final filled = review.rating >= i + 1;
                                return Icon(
                                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                                  size: 14,
                                  color: filled
                                      ? const Color(0xFFFFB800)
                                      : colorScheme.onSurface.withValues(alpha: 0.2),
                                );
                              }),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              review.rating.toStringAsFixed(1),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            if (formattedDate.isNotEmpty)
                              Text(
                                formattedDate,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                ),
                              ),
                          ],
                        ),
                        if (review.comment != null && review.comment!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            review.comment!,
                            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPosterPlaceholder(ColorScheme cs) {
    return Container(
      width: 60,
      height: 90,
      color: cs.surfaceContainerHighest,
      child: const Icon(Icons.movie_rounded, size: 24),
    );
  }
}
