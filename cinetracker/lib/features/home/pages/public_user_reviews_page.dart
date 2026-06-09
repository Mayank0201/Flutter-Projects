import 'package:flutter/material.dart';
import '../../../model/review_model.dart';
import '../../../service/social_service.dart';
import 'review_detail_page.dart';
import '../widgets/movie_resolver.dart';

class PublicUserReviewsPage extends StatefulWidget {
  final int userId;
  final String username;

  const PublicUserReviewsPage({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<PublicUserReviewsPage> createState() => _PublicUserReviewsPageState();
}

class _PublicUserReviewsPageState extends State<PublicUserReviewsPage> {
  final SocialService _socialService = SocialService();

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
      final profile = await _socialService.getUserProfile(
        widget.userId,
        page: _page,
        size: _pageSize,
      );
      if (!mounted) return;

      setState(() {
        _reviews.addAll(profile.reviews);
        _hasMore = profile.reviews.length == _pageSize;
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
    try {
      _page++;
      final profile = await _socialService.getUserProfile(
        widget.userId,
        page: _page,
        size: _pageSize,
      );
      if (!mounted) return;

      setState(() {
        _reviews.addAll(profile.reviews);
        _hasMore = profile.reviews.length == _pageSize;
        _isLoadingMore = false;
      });
    } catch (_) {
      _page--;
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.username}'s Reviews"),
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
          return _PublicReviewCard(
            review: review,
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

class _PublicReviewCard extends StatelessWidget {
  final Review review;
  final VoidCallback onTap;

  const _PublicReviewCard({
    required this.review,
    required this.onTap,
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

    return MovieResolver(
      movieId: review.movieId,
      initialTitle: review.movieTitle,
      initialPosterUrl: review.moviePosterUrl,
      initialReleaseYear: review.movieReleaseYear,
      initialGenre: review.movieGenre,
      builder: (context, title, posterUrl, releaseYear, genre, isLoading) {
        final hasPoster = posterUrl != null && posterUrl.isNotEmpty;

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
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: hasPoster
                            ? Image.network(
                                posterUrl,
                                width: 60,
                                height: 90,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildPosterPlaceholder(colorScheme),
                              )
                            : _buildPosterPlaceholder(colorScheme),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                if (releaseYear != null) ...[
                                  Text(
                                    '$releaseYear',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                if (genre != null && genre.isNotEmpty)
                                  Expanded(
                                    child: Text(
                                      genre,
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
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
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
      },
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
