import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../model/movie_model.dart';
import '../../../provider/wishlist_provider.dart';
import '../../../service/tmdb_service.dart';
import '../../../service/rating_service.dart';

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

  Future<void> _onStarTapped(double rating) async {
    if (_isRatingLoading) return;

    setState(() => _isRatingLoading = true);

    try {
      if (_userRating != null && _userRating == rating) {
        // tapping the same rating again removes the rating
        await ratingService.deleteRating(widget.movie.id);
        if (!mounted) return;
        setState(() => _userRating = null);
      } else {
        // set new rating — send as double
        await ratingService.setRating(widget.movie.id, rating);
        if (!mounted) return;
        setState(() => _userRating = rating);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to update rating")),
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

                        if (!mounted) return;

                        setState(() => _isWatchlistUpdating = false);

                        if (!mounted) return;
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
                  errorBuilder: (_, __, ___) => Container(color: Colors.black),
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
                          errorBuilder: (_, __, ___) => Container(
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

                  const SizedBox(height: 24),
                ],
              ),
            ),
        ],
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
            _userRating != null ? "Your Rating" : "Rate this Movie",
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
