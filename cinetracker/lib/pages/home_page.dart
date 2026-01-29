import 'package:flutter/material.dart';
import 'package:cinetracker/service/tmdb_service.dart';
import 'package:cinetracker/service/omdb_service.dart';
import '../model/movie_model.dart';
import 'movie_details_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // Genres supported by TMDB genre map
  static const List<String> genres = ['Action', 'Thriller', 'Comedy', 'Drama'];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: genres.length + 1, // footer included
      itemBuilder: (context, index) {
        // footer item
        if (index == genres.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                "Movie data provided by TMDB",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          );
        }

        // normal genre sections
        final genre = genres[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _GenreSection(genre: genre),
        );
      },
    );
  }
}

class _GenreSection extends StatefulWidget {
  final String genre;

  const _GenreSection({required this.genre});

  @override
  State<_GenreSection> createState() => _GenreSectionState();
}

class _GenreSectionState extends State<_GenreSection> {
  late Future<List<Movie>> _future;

  // TMDB service for genre-based discovery
  final TMDBService _tmdbService = TMDBService();

  @override
  void initState() {
    super.initState();

    // Fetch movies for the given genre using TMDB
    _future = _tmdbService.getGenreMovies(widget.genre);
  }

  // Retry API call on error
  void _retry() {
    setState(() {
      _future = _tmdbService.getGenreMovies(widget.genre);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Guard in case TMDB API key is missing
    if (_tmdbService.tmdbApiKey.isEmpty) {
      return _sectionTitle(
        'Latest ${widget.genre} Movies',
        const Center(child: Text('API key not configured')),
      );
    }

    return _sectionTitle(
      'Latest ${widget.genre} Movies',
      SizedBox(
        height: 240, // Fixed height for horizontal list
        child: FutureBuilder<List<Movie>>(
          future: _future,
          builder: (context, snapshot) {
            // Loading state
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // Error state
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Unable to load ${widget.genre.toLowerCase()} movies',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    TextButton(onPressed: _retry, child: const Text('Retry')),
                  ],
                ),
              );
            }

            final movies = snapshot.data ?? [];

            // Empty state
            if (movies.isEmpty) {
              return const Center(child: Text('No movies found'));
            }

            // Horizontal movie list
            return ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: movies.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final movie = movies[index];

                // TMDB poster is empty string if unavailable
                final posterUrl = movie.poster.isNotEmpty ? movie.poster : null;

                return GestureDetector(
                  onTap: () {
                    // Navigate to details page (OMDb fetch happens there)
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MovieDetailsPage(movie: movie),
                      ),
                    );
                  },
                  child: SizedBox(
                    width: 140,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: posterUrl != null
                              ? Image.network(
                                  posterUrl,
                                  width: 140,
                                  height: 160,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _posterPlaceholder(),
                                )
                              : _posterPlaceholder(),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          movie.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          movie.year,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // Section title + content wrapper
  Widget _sectionTitle(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  // Fallback UI when poster image is missing
  Widget _posterPlaceholder() {
    return Container(
      width: 140,
      height: 160,
      color: Colors.grey.shade800,
      alignment: Alignment.center,
      child: const Icon(Icons.movie, color: Colors.white70),
    );
  }
}
