import 'dart:ui';
import 'package:flutter/material.dart';

import '../model/movie_model.dart';
import '../service/omdb_service.dart';
import '../service/tmdb_service.dart';

class MovieDetailsPage extends StatefulWidget {
  final Movie movie; // tmdb movie (has tmdbId)

  const MovieDetailsPage({super.key, required this.movie});

  @override
  State<MovieDetailsPage> createState() => _MovieDetailsPageState();
}

class _MovieDetailsPageState extends State<MovieDetailsPage> {
  final OMDBService omdbService = OMDBService();
  final TMDBService tmdbService = TMDBService();

  Movie? fullMovie;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchFullDetails();
  }

  // tmdb -> imdb -> omdb
  Future<void> fetchFullDetails() async {
    try {
      // step 1: get imdb id from tmdb
      final imdbId = await tmdbService.getImdbId(widget.movie.tmdbId);

      if (imdbId == null || imdbId.isEmpty) {
        throw Exception('imdb id not found');
      }

      // step 2: fetch full movie details from omdb
      final result = await omdbService.getMovieById(
        imdbId,
        tmdbId: widget.movie.tmdbId,
      );

      setState(() {
        fullMovie = result;
      });
    } catch (e) {
      setState(() {
        errorMessage = "failed to load movie details.";
      });
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final posterUrl = widget.movie.poster.isNotEmpty
        ? widget.movie.poster
        : null;

    return Scaffold(
      extendBodyBehindAppBar: true,

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.movie.title),
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
          if (!isLoading && errorMessage != null)
            Center(
              child: Text(
                errorMessage!,
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),

          // content
          if (!isLoading && fullMovie != null)
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
                    "${fullMovie!.title} (${fullMovie!.year})",
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
                    "imdb rating: ${fullMovie!.imdbRating}",
                    style: const TextStyle(fontSize: 18, color: Colors.white70),
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
                    fullMovie!.plot,
                    style: const TextStyle(fontSize: 16, color: Colors.white70),
                  ),

                  const SizedBox(height: 24),

                  _infoRow("Released", fullMovie!.released),
                  _infoRow("Runtime", fullMovie!.runtime),
                  _infoRow("Genre", fullMovie!.genre),
                  _infoRow("Director", fullMovie!.director),
                  _infoRow("Actors", fullMovie!.actors),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // reusable info row
  Widget _infoRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label: ",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}
