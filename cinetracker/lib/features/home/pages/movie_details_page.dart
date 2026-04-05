import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../model/movie_model.dart';
import '../../../provider/wishlist_provider.dart';
import '../../../service/tmdb_service.dart';

class MovieDetailsPage extends StatefulWidget {
  final Movie movie; // tmdb movie (has tmdb id)

  const MovieDetailsPage({super.key, required this.movie});

  @override
  State<MovieDetailsPage> createState() => _MovieDetailsPageState();
}

class _MovieDetailsPageState extends State<MovieDetailsPage> {
  final TMDBService tmdbService = TMDBService();
  Movie? fullMovie;
  bool isLoading = true;
  String? errorMessage;
  bool _isWatchlistUpdating = false;

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
      final movie = await tmdbService.getMovieDetails(widget.movie.id);
      if (!mounted) return;
      setState(() {
        fullMovie = movie;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        errorMessage = "Could not load full details.";
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  // fetch details using either existing imdb id or from tmdb

  @override
  Widget build(BuildContext context) {
    final activeMovie = fullMovie ?? widget.movie;
    final wishlistProvider = context.watch<WishlistProvider>();
    final isFavorite = wishlistProvider.isFavorite(activeMovie.id);

    final posterUrl = activeMovie.poster.isNotEmpty ? activeMovie.poster : null;

    return Scaffold(
      extendBodyBehindAppBar: true,

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(activeMovie.title),
        actions: [
          IconButton(
            onPressed: _isWatchlistUpdating
                ? null
                : () async {
                    setState(() => _isWatchlistUpdating = true);

                    final success = await wishlistProvider.toggleFavorite(
                      activeMovie,
                    );

                    if (!mounted) return;

                    setState(() => _isWatchlistUpdating = false);

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
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
          ),
        ],
      ),

      body: Stack(
        children: [
          // background poster
          if (posterUrl != null)
            Positioned.fill(
              child: Image.network(
                posterUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Colors.black),
              ),
            ),

          // blur layer
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(color: Colors.transparent),
            ),
          ),

          // gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.85),
                    Colors.black.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.85),
                  ],
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
              padding: const EdgeInsets.fromLTRB(16, 100, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // poster
                  if (posterUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        posterUrl,
                        width: 220,
                        height: 330,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 220,
                          height: 330,
                          color: Colors.grey.shade800,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.movie,
                            size: 48,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // title
                  Text(
                    "${fullMovie!.title}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // rating
                  Text(
                    fullMovie!.rating > 0
                        ? "Rating: ${fullMovie!.rating.toStringAsFixed(1)}"
                        : "Rating: Not available",
                    style: const TextStyle(fontSize: 18, color: Colors.white70),
                  ),

                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _metaChip(
                        fullMovie!.releaseYear != null
                            ? "Year: ${fullMovie!.releaseYear}"
                            : "Year: N/A",
                      ),
                      _metaChip("Genre: ${fullMovie!.genre}"),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // plot section
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Plot",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    fullMovie!.overview.isNotEmpty
                        ? fullMovie!.overview
                        : "Plot is not available for this title.",
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.left,
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    "This product uses the TMDB API but is not endorsed or certified by TMDB.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _metaChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
    );
  }
}
