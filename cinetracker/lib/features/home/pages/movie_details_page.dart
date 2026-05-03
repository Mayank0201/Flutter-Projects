import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../model/movie_model.dart';
import '../../../provider/wishlist_provider.dart';
import '../../../service/tmdb_service.dart';
import '../../../service/rating_service.dart';
import 'package:cinetracker/core/utils/content_moderator.dart';
import '../widgets/status_picker_sheet.dart';
import 'movie_reviews_page.dart';

class MovieDetailsPage extends StatefulWidget {
  final Movie movie;

  const MovieDetailsPage({super.key, required this.movie});

  @override
  State<MovieDetailsPage> createState() => _MovieDetailsPageState();
}

class _MovieDetailsPageState extends State<MovieDetailsPage> {
  final TMDBService tmdbService = TMDBService();
  final RatingService ratingService = RatingService();
  Movie? fullMovie;
  bool isLoading = true;
  String? errorMessage;
  bool _isWatchlistUpdating = false;

  // rating state
  double _averageRating = 0.0;
  int _totalRatings = 0;
  double? _userRating; // null = not rated; double for half-star support
  bool _isRatingLoading = false;

  @override
  void initState() {
    super.initState();
    fullMovie = widget.movie;
    _loadMovieDetails();
  }

  Future<void> _loadMovieDetails() async {
    if (widget.movie.id <= 0) {
      setState(() {
        isLoading = false;
        errorMessage = "Movie details unavailable.";
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // fetch movie details and rating summary in parallel
      final results = await Future.wait([
        tmdbService.getMovieDetails(widget.movie.id),
        ratingService.getRatingSummary(widget.movie.id).catchError((_) => RatingSummary.empty()),
      ]);

      if (!mounted) return;

      final movie = results[0] as Movie;
      final summary = results[1] as RatingSummary;

      setState(() {
        fullMovie = movie;
        _averageRating = summary.averageRating;
        _totalRatings = summary.totalRatings;
        _userRating = summary.userRating;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        errorMessage = "Could not load full details.";
        isLoading = false;
      });
    }
  }

  Future<void> _onStarTapped(double initialRating) async {
    if (_isRatingLoading) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        double currentRating = initialRating;
        final TextEditingController commentController = TextEditingController();

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            String? errorText;
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: const Text('Rate & Review'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      IconData icon;
                      if (currentRating >= index + 1) {
                        icon = Icons.star_rounded;
                      } else if (currentRating >= index + 0.5) {
                        icon = Icons.star_half_rounded;
                      } else {
                        icon = Icons.star_outline_rounded;
                      }
                      return GestureDetector(
                        onTapDown: (details) {
                          final localX = details.localPosition.dx;
                          setDialogState(() {
                            currentRating = index + (localX < 24 ? 0.5 : 1.0);
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            icon,
                            color: const Color(0xFFFFB800),
                            size: 40,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: commentController,
                    decoration: InputDecoration(
                      hintText: 'Optional comment...',
                      border: const OutlineInputBorder(),
                      errorText: errorText,
                    ),
                    maxLines: 3,
                    onChanged: (val) {
                      setDialogState(() => errorText = ContentModerator.validateReview(val));
                    },
                  ),
                ],
              ),
              actions: [
                if (_userRating != null)
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, {'delete': true}),
                    child: const Text('Remove Rating', style: TextStyle(color: Colors.red)),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final validationError = ContentModerator.validateReview(commentController.text.trim());
                    if (validationError != null) {
                      setDialogState(() => errorText = validationError);
                      // Use the page's context to show the snackbar
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(validationError)),
                      );
                    } else {
                      Navigator.pop(dialogContext, {
                        'rating': currentRating,
                        'comment': commentController.text.trim(),
                      });
                    }
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return; // Dialog dismissed

    setState(() => _isRatingLoading = true);

    try {
      if (result['delete'] == true) {
        await ratingService.deleteRating(widget.movie.id);
        if (!mounted) return;
        setState(() => _userRating = null);
      } else {
        final newRating = result['rating'] as double;
        final comment = result['comment'] as String;
        await ratingService.setRating(widget.movie.id, newRating, comment: comment);
        if (!mounted) return;
        setState(() => _userRating = newRating);
      }

      // refresh the summary to get the updated average
      final summary = await ratingService.getRatingSummary(widget.movie.id);
      if (!mounted) return;
      setState(() {
        _averageRating = summary.averageRating;
        _totalRatings = summary.totalRatings;
        _userRating = summary.userRating;
      });
    } catch (e) {
      if (!mounted) return;
      String message = "Failed to update rating";
      if (e is DioException) {
        final responseData = e.response?.data;
        if (responseData is Map && responseData['message'] != null) {
          message = responseData['message'].toString();
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _isRatingLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeMovie = fullMovie ?? widget.movie;
    final wishlistProvider = context.watch<WishlistProvider>();
    final isFavorite = wishlistProvider.isFavorite(activeMovie.id);

    final posterUrl = activeMovie.poster.isNotEmpty ? activeMovie.poster : null;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      extendBodyBehindAppBar: true,

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _isWatchlistUpdating
                    ? null
                    : () async {
                        setState(() => _isWatchlistUpdating = true);

                        final success = await wishlistProvider.toggleFavorite(
                          activeMovie,
                        );

                        if (!context.mounted) return;

                        setState(() => _isWatchlistUpdating = false);

                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? (isFavorite
                                        ? "Removed from watchlist"
                                        : "Added to watchlist")
                                  : (wishlistProvider.errorMessage ??
                                        "Watchlist update failed"),
                            ),
                          ),
                        );
                      },
                icon: _isWatchlistUpdating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_outline_rounded,
                        color: isFavorite ? const Color(0xFFFF6B6B) : Colors.white,
                        size: 22,
                      ),
              ),
            ),
          ),
        ],
      ),

      body: Stack(
        children: [
          // background poster — sized taller than screen so bottom never cuts off
          if (posterUrl != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: screenHeight * 1.15,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Image.network(
                  posterUrl,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  // caching decoded image size drastically reduces RAM and jank
                  cacheHeight: (screenHeight * 1.15).toInt() ~/ 2, 
                  errorBuilder: (_, _, _) => Container(color: Colors.black),
                ),
              ),
            ),

          // no-poster fallback
          if (posterUrl == null)
            Positioned.fill(
              child: Container(color: Colors.black),
            ),

          // gradient overlay — more gradual so nothing feels chopped
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.35),
                    Colors.black.withValues(alpha: 0.65),
                    Colors.black.withValues(alpha: 0.92),
                  ],
                  stops: const [0.0, 0.25, 0.6, 1.0],
                ),
              ),
            ),
          ),

          // loading state
          if (isLoading) const Center(child: CircularProgressIndicator()),

          // error state
          if (!isLoading && errorMessage != null && fullMovie == null)
            Center(
              child: Text(
                errorMessage!,
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),

          // content
          if (fullMovie != null)
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 60, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // poster
                  if (posterUrl != null)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.2),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          posterUrl,
                          width: (MediaQuery.of(context).size.width * 0.5).clamp(160, 220),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: (MediaQuery.of(context).size.width * 0.5).clamp(160, 220),
                            height: (MediaQuery.of(context).size.width * 0.5).clamp(160, 220) * 1.5,
                            color: Colors.grey.shade800,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.movie_rounded,
                              size: 48,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // title
                  Text(
                    fullMovie!.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.3,
                      height: 1.2,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // tmdb rating row
                  if (fullMovie!.rating > 0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 22),
                        const SizedBox(width: 4),
                        Text(
                          fullMovie!.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const Text(
                          " / 10",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),

                  if (fullMovie!.rating <= 0)
                    const Text(
                      "Rating not available",
                      style: TextStyle(fontSize: 14, color: Colors.white54),
                    ),

                  const SizedBox(height: 16),

                  // ── user star rating ────────────────────────────
                  _buildStarRatingSection(),

                  const SizedBox(height: 12),

                  // ── See reviews button ───────────────────────────
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MovieReviewsPage(
                          movieId: activeMovie.id,
                          movieTitle: activeMovie.title,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.rate_review_outlined, size: 18),
                    label: const Text('See Reviews'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.3)),
                      foregroundColor: Colors.white70,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Watchlist status action ────────────────────────
                  _buildStatusAction(context, activeMovie, wishlistProvider),

                  const SizedBox(height: 16),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _metaChip(
                        fullMovie!.releaseYear != null
                            ? fullMovie!.releaseYear.toString()
                            : "N/A",
                        Icons.calendar_today_rounded,
                      ),
                      _metaChip(
                        fullMovie!.genre,
                        Icons.local_movies_rounded,
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // plot section
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Overview",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    fullMovie!.overview.isNotEmpty
                        ? fullMovie!.overview
                        : "Plot is not available for this title.",
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.left,
                  ),

                  const SizedBox(height: 24),

                  if (fullMovie!.director.isNotEmpty && fullMovie!.director != "Unknown") ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Director",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        fullMovie!.director,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  if (fullMovie!.cast.isNotEmpty) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Top Cast",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 110,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: fullMovie!.cast.length > 10 ? 10 : fullMovie!.cast.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemBuilder: (context, index) {
                          return Column(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.white.withValues(alpha: 0.1),
                                child: Text(
                                  fullMovie!.cast[index][0],
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: 70,
                                child: Text(
                                  fullMovie!.cast[index],
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white60,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],


                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusAction(BuildContext context, Movie movie, WishlistProvider provider) {
    final status = provider.getMovieStatus(movie.id);
    
    // If not in watchlist, show an "Add to List" button
    if (status == null) {
      return OutlinedButton.icon(
        onPressed: () => showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => StatusPickerSheet(
            movie: movie,
            provider: provider,
            currentStatus: null,
          ),
        ),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Set Status'),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      );
    }

    const statusColors = {
      'PENDING': Colors.amber,
      'ACTIVE': Colors.blue,
      'COMPLETED': Colors.green,
    };
    const statusIcons = {
      'PENDING': Icons.bookmark_outline_rounded,
      'ACTIVE': Icons.play_circle_outline_rounded,
      'COMPLETED': Icons.check_circle_outline_rounded,
    };
    const statusLabels = {
      'PENDING': 'Pending',
      'ACTIVE': 'Watching',
      'COMPLETED': 'Completed',
    };
    final color = statusColors[status] ?? Colors.grey;
    final icon = statusIcons[status] ?? Icons.bookmark_outline_rounded;
    final label = statusLabels[status] ?? status;

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => StatusPickerSheet(
          movie: movie,
          provider: provider,
          currentStatus: status,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.edit_rounded, size: 12, color: color.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }

  /// interactive 1–5 star rating row with community average
  Widget _buildStarRatingSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          // label
          Text(
            _userRating != null ? "Your Rating" : "Rate and Add a Review",
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),

          // stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final starIndex = i;
              
              // determine which icon to show
              IconData icon;
              if (_userRating != null) {
                if (_userRating! >= starIndex + 1) {
                  icon = Icons.star_rounded;
                } else if (_userRating! >= starIndex + 0.5) {
                  icon = Icons.star_half_rounded;
                } else {
                  icon = Icons.star_outline_rounded;
                }
              } else {
                icon = Icons.star_outline_rounded;
              }

              final isSelected = _userRating != null && _userRating! > starIndex;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  final localX = details.localPosition.dx;
                  // total width of star hit area is 48 (36 icon + 12 padding)
                  // center point is 24
                  final rating = starIndex + (localX < 24 ? 0.5 : 1.0);
                  _onStarTapped(rating);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    icon,
                    color: isSelected
                        ? const Color(0xFFFFB800)
                        : Colors.white38,
                    size: 36,
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 8),

          // loading indicator or community stats
          if (_isRatingLoading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Colors.white54,
              ),
            )
          else
            Text(
              _totalRatings > 0
                  ? "${_averageRating.toStringAsFixed(1)} avg · $_totalRatings ${_totalRatings == 1 ? 'rating' : 'ratings'}"
                  : "Be the first to rate!",
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white54,
              ),
            ),
        ],
      ),
    );
  }

  Widget _metaChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
