import 'package:flutter/material.dart';
import '../../../model/review_model.dart';
import '../../../service/rating_service.dart';
import 'public_profile_page.dart';
import 'movie_reviews_page.dart';
import '../widgets/movie_resolver.dart';

class ReviewDetailPage extends StatefulWidget {
  final Review review;

  const ReviewDetailPage({super.key, required this.review});

  @override
  State<ReviewDetailPage> createState() => _ReviewDetailPageState();
}

class _ReviewDetailPageState extends State<ReviewDetailPage> {
  final RatingService _ratingService = RatingService();
  late bool _isHelpful;
  late int _helpfulCount;
  bool _isToggling = false;

  @override
  void initState() {
    super.initState();
    _isHelpful = widget.review.isHelpful;
    _helpfulCount = widget.review.helpfulCount;
  }

  Future<void> _toggleHelpful() async {
    if (_isToggling) return;

    setState(() {
      _isToggling = true;
      // Optimistic update
      _isHelpful = !_isHelpful;
      if (_isHelpful) {
        _helpfulCount++;
      } else {
        _helpfulCount = (_helpfulCount - 1).clamp(0, 999999);
      }
    });

    try {
      await _ratingService.toggleReviewHelpful(widget.review.id);
    } catch (e) {
      // Revert on failure
      setState(() {
        _isHelpful = !_isHelpful;
        if (_isHelpful) {
          _helpfulCount++;
        } else {
          _helpfulCount = (_helpfulCount - 1).clamp(0, 999999);
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update like status.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isToggling = false;
        });
      }
    }
  }

  void _navigateToAuthor() {
    if (widget.review.userId > 0) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PublicProfilePage(
            userId: widget.review.userId,
            username: widget.review.username,
          ),
        ),
      );
    }
  }

  void _navigateToMovieReviews(String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MovieReviewsPage(
          movieId: widget.review.movieId,
          movieTitle: title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String formattedDate = '';
    try {
      final dt = DateTime.parse(widget.review.createdAt);
      formattedDate =
          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      formattedDate = widget.review.createdAt;
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          // Return the updated helpful state to the calling page
          // This allows lists to update without having to reload everything
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Review Detail'),
          actions: [
            IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: 'Share review',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Share functionality coming soon!')),
                );
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Movie Header Section ───────────────────────────────────────
              MovieResolver(
                movieId: widget.review.movieId,
                initialTitle: widget.review.movieTitle,
                initialPosterUrl: widget.review.moviePosterUrl,
                initialReleaseYear: widget.review.movieReleaseYear,
                initialGenre: widget.review.movieGenre,
                builder: (context, title, posterUrl, releaseYear, genre, isLoading) {
                  final hasPoster = posterUrl != null && posterUrl.isNotEmpty;

                  return Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          colorScheme.surface,
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Movie Poster
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 90,
                            height: 135,
                            color: colorScheme.surfaceContainerHighest,
                            child: hasPoster
                                ? Image.network(
                                    posterUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.movie_rounded,
                                      size: 40,
                                    ),
                                  )
                                : const Icon(
                                    Icons.movie_rounded,
                                    size: 40,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        // Movie Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  if (releaseYear != null) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: colorScheme.surfaceContainerHigh,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: colorScheme.outline.withValues(alpha: 0.15),
                                        ),
                                      ),
                                      child: Text(
                                        '$releaseYear',
                                        style: theme.textTheme.labelMedium?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  if (genre != null && genre.isNotEmpty)
                                    Expanded(
                                      child: Text(
                                        genre,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: colorScheme.primary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => _navigateToMovieReviews(title),
                                icon: const Icon(Icons.reviews_rounded, size: 16),
                                label: const Text('All Movie Reviews'),
                                style: ElevatedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  backgroundColor: colorScheme.primaryContainer,
                                  foregroundColor: colorScheme.onPrimaryContainer,
                                  elevation: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const Divider(height: 1),

              // ── Review Content Section ───────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Author Row
                    InkWell(
                      onTap: _navigateToAuthor,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: colorScheme.primaryContainer,
                              child: Text(
                                widget.review.username.isNotEmpty
                                    ? widget.review.username[0].toUpperCase()
                                    : 'U',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.review.username,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Review author',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Rating and Date
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Row(
                              children: List.generate(5, (i) {
                                final filled = widget.review.rating >= i + 1;
                                return Icon(
                                  filled
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  size: 24,
                                  color: filled
                                      ? const Color(0xFFFFB800)
                                      : colorScheme.onSurface.withValues(alpha: 0.2),
                                );
                              }),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.review.rating.toStringAsFixed(1),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        if (formattedDate.isNotEmpty)
                          Text(
                            formattedDate,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Review text
                    if (widget.review.comment != null &&
                        widget.review.comment!.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colorScheme.outline.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Text(
                          widget.review.comment!,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.6,
                            letterSpacing: 0.2,
                          ),
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'This user rated this movie without leaving a comment.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Interactions/Likes row
                    Row(
                      children: [
                        Material(
                          color: _isHelpful
                              ? colorScheme.primaryContainer
                              : colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: _toggleHelpful,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isHelpful
                                        ? Icons.thumb_up_rounded
                                        : Icons.thumb_up_outlined,
                                    size: 18,
                                    color: _isHelpful
                                        ? colorScheme.primary
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isHelpful ? 'Liked' : 'Like Review',
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: _isHelpful
                                          ? colorScheme.primary
                                          : colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$_helpfulCount',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _helpfulCount == 1 ? 'person found this helpful' : 'people found this helpful',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
