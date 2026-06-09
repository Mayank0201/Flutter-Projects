import 'package:flutter/material.dart';
import '../../../model/review_model.dart';
import '../../../service/rating_service.dart';
import 'public_profile_page.dart';
import 'review_detail_page.dart';

class MovieReviewsPage extends StatefulWidget {
  final int movieId;
  final String movieTitle;

  const MovieReviewsPage({
    super.key,
    required this.movieId,
    required this.movieTitle,
  });

  @override
  State<MovieReviewsPage> createState() => _MovieReviewsPageState();
}

class _MovieReviewsPageState extends State<MovieReviewsPage> {
  final RatingService _ratingService = RatingService();

  final List<Review> _reviews = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  int _page = 1;
  static const int _pageSize = 10;
  bool _hasMore = true;
  String _sortBy = 'newest'; // 'newest' or 'helpful'

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
      final items = await _ratingService.getMovieReviews(
        widget.movieId,
        page: _page,
        size: _pageSize,
        sortBy: _sortBy,
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
      final items = await _ratingService.getMovieReviews(
        widget.movieId,
        page: _page,
        size: _pageSize,
        sortBy: _sortBy,
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

  Future<void> _toggleHelpful(int reviewId) async {
    final index = _reviews.indexWhere((r) => r.id == reviewId);
    if (index == -1) return;

    final review = _reviews[index];
    final bool currentlyHelpful = review.isHelpful;

    // Optimistically update UI
    setState(() {
      _reviews[index] = Review(
        id: review.id,
        movieId: review.movieId,
        userId: review.userId,
        username: review.username,
        rating: review.rating,
        comment: review.comment,
        helpfulCount: currentlyHelpful
            ? (review.helpfulCount - 1).clamp(0, 9999)
            : review.helpfulCount + 1,
        isHelpful: !currentlyHelpful,
        createdAt: review.createdAt,
        updatedAt: review.updatedAt,
      );
    });

    try {
      await _ratingService.toggleReviewHelpful(reviewId);
    } catch (_) {
      if (!mounted) return;
      // Revert on error
      setState(() {
        _reviews[index] = review;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update helpful status.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Reviews', style: TextStyle(fontSize: 18)),
            Text(
              widget.movieTitle,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort reviews',
            onSelected: (value) {
              if (_sortBy != value) {
                setState(() => _sortBy = value);
                _loadReviews(reset: true);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'newest',
                child: Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 20),
                    SizedBox(width: 10),
                    Text('Newest First'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'helpful',
                child: Row(
                  children: [
                    Icon(Icons.thumb_up_rounded, size: 20),
                    SizedBox(width: 10),
                    Text('Most Helpful'),
                  ],
                ),
              ),
            ],
          ),
        ],
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
              'No comments yet, Be the first one',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Be the first to share your thoughts!',
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
          return _ReviewCard(
            review: review,
            onHelpful: () => _toggleHelpful(review.id),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReviewDetailPage(review: review),
                ),
              );
              _loadReviews(reset: true);
            },
          );
        },
      ),
    );
  }
}

// ── Review card ─────────────────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  final Review review;
  final VoidCallback onHelpful;
  final VoidCallback onTap;

  const _ReviewCard({
    required this.review,
    required this.onHelpful,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Format date
    String formattedDate = '';
    try {
      final dt = DateTime.parse(review.createdAt);
      formattedDate =
          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      formattedDate = review.createdAt;
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.15)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (review.userId > 0) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PublicProfilePage(
                                  userId: review.userId,
                                  username: review.username,
                                ),
                              ),
                            );
                          }
                        },
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: colorScheme.primaryContainer,
                              child: Text(
                                review.username.isNotEmpty
                                    ? review.username[0].toUpperCase()
                                    : 'U',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              review.username,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Star display
                      Row(
                        children: List.generate(5, (i) {
                          IconData ic;
                          if (review.rating >= i + 1) {
                            ic = Icons.star_rounded;
                          } else if (review.rating >= i + 0.5) {
                            ic = Icons.star_half_rounded;
                          } else {
                            ic = Icons.star_outline_rounded;
                          }
                          return Icon(
                            ic,
                            size: 16,
                            color: review.rating > i
                                ? const Color(0xFFFFB800)
                                : colorScheme.onSurface.withValues(alpha: 0.2),
                          );
                        }),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        review.rating.toStringAsFixed(1),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (formattedDate.isNotEmpty)
                        Text(
                          formattedDate,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                        ),
                    ],
                  ),

                  // Comment body
                  if (review.comment != null && review.comment!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      review.comment!,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Footer: helpful
                  Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: onHelpful,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                review.isHelpful
                                    ? Icons.thumb_up_rounded
                                    : Icons.thumb_up_outlined,
                                size: 15,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Helpful (${review.helpfulCount})',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: review.isHelpful
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
