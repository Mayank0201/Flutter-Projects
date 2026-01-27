import 'package:flutter/material.dart';
import '../service/movie_service.dart';
import '../model/movie_model.dart';
import 'movie_details_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const List<String> genres = ['Action', 'Thriller', 'Comedy', 'Drama'];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: genres.length,
      itemBuilder: (context, index) {
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
  final MovieService _service = MovieService();

  // curated keywords since omdb does not support genre discovery
  String get _query {
    switch (widget.genre) {
      case 'Action':
        return 'Avengers';
      case 'Thriller':
        return 'Batman';
      case 'Comedy':
        return 'Hangover';
      case 'Drama':
        return 'Inception';
      default:
        return widget.genre;
    }
  }

  @override
  void initState() {
    super.initState();
    _future = _service.searchMovies(_query);
  }

  void _retry() {
    setState(() {
      _future = _service.searchMovies(_query);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_service.apiKey.isEmpty) {
      return _sectionTitle(
        'Latest ${widget.genre} Movies',
        const Center(child: Text('api key not configured')),
      );
    }

    return _sectionTitle(
      'Latest ${widget.genre} Movies',
      SizedBox(
        height: 240, // increased to prevent overflow
        child: FutureBuilder<List<Movie>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'unable to load ${widget.genre.toLowerCase()} movies',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    TextButton(onPressed: _retry, child: const Text('retry')),
                  ],
                ),
              );
            }

            final movies = snapshot.data ?? [];

            if (movies.isEmpty) {
              return const Center(child: Text('no movies found'));
            }

            return ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: movies.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final movie = movies[index];
                final posterUrl = movie.poster != 'N/A' ? movie.poster : null;

                return GestureDetector(
                  onTap: () {
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
                      mainAxisSize: MainAxisSize.min, // prevents overflow
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
