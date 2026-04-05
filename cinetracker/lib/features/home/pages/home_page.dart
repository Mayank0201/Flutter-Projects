import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cinetracker/service/tmdb_service.dart';
import '../../../model/movie_model.dart';
import 'movie_details_page.dart';

import '../../../core/storage/token_storage.dart';
import '../../../provider/wishlist_provider.dart';
import '../../auth/pages/login_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TMDBService _tmdbService = TMDBService();

  List<Movie> movies = [];
  List<Map<String, dynamic>> genres = [];

  String? selectedGenreId;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    final storage = TokenStorage();
    final token = await storage.getToken();
    print(token);
    if (token != null && token.isNotEmpty) {
      _tmdbService.setToken(token);
    } else {
      _tmdbService.clearToken();
    }

    await loadInitialData();
  }

  Future<void> loadInitialData() async {
    try {
      final genreData = await _tmdbService.getGenres();
      final popularMovies = await _tmdbService.getPopularMovies();

      setState(() {
        genres = genreData;
        movies = popularMovies;
        isLoading = false;
      });
    } catch (e) {
      print(e);
    }
  }

  Future<void> loadMoviesByGenre(String genreId) async {
    setState(() => isLoading = true);

    final data = await _tmdbService.getMoviesByGenre(genreId);

    setState(() {
      movies = data;
      selectedGenreId = genreId;
      isLoading = false;
    });
  }

  Future<void> loadPopularMovies() async {
    setState(() => isLoading = true);

    final data = await _tmdbService.getPopularMovies();

    setState(() {
      movies = data;
      selectedGenreId = null;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("CineTracker 🎬"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              context.read<WishlistProvider>().resetForLogout();
              _tmdbService.clearToken();

              final storage = TokenStorage();
              await storage.clearToken();

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<String>(
              hint: const Text("Select Genre"),
              value: selectedGenreId,
              items: genres.map((genre) {
                return DropdownMenuItem<String>(
                  value: genre['id'].toString(),
                  child: Text(genre['name']),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  loadMoviesByGenre(value);
                }
              },
            ),
          ),
          if (selectedGenreId != null)
            TextButton(
              onPressed: loadPopularMovies,
              child: const Text("Show Popular Movies"),
            ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: movies.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.7,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemBuilder: (context, index) {
                      final movie = movies[index];

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MovieDetailsPage(movie: movie),
                            ),
                          );
                        },

                        child: Column(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),

                                child: Image.network(
                                  movie.poster,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.movie),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              movie.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
