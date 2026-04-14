import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cinetracker/service/tmdb_service.dart';
import 'package:cinetracker/core/network/api_service.dart';
import '../../../model/movie_model.dart';
import '../../../provider/theme_provider.dart';
import 'movie_details_page.dart';

import '../../../core/storage/token_storage.dart';
import '../../../provider/wishlist_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TMDBService _tmdbService = TMDBService();
  final ApiService _apiService = ApiService();

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
    final token = await storage.getAccessToken();
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
      debugPrint(e.toString());
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.movie_filter_rounded,
              color: colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text("CineTracker", style: theme.appBarTheme.titleTextStyle),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              themeProvider.isDark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              size: 22,
            ),
            tooltip: themeProvider.isDark ? "Light mode" : "Dark mode",
            onPressed: () => themeProvider.toggleTheme(),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 22),
            tooltip: "Logout",
            onPressed: () async {
              context.read<WishlistProvider>().resetForLogout();
              _apiService.clearToken();
              _tmdbService.clearToken();

              final storage = TokenStorage();
              await storage.clearTokens();

              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              selectedGenreId == null ? "Popular" : "By Genre",
              style: theme.textTheme.headlineMedium,
            ),
          ),

          // genre chips
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: const Text("All"),
                    selected: selectedGenreId == null,
                    onSelected: (_) => loadPopularMovies(),
                    selectedColor: colorScheme.primary.withValues(alpha: 0.2),
                    checkmarkColor: colorScheme.primary,
                    labelStyle: TextStyle(
                      color: selectedGenreId == null
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                      fontWeight: selectedGenreId == null
                          ? FontWeight.w600
                          : FontWeight.w400,
                      fontSize: 13,
                    ),
                    side: BorderSide(
                      color: selectedGenreId == null
                          ? colorScheme.primary.withValues(alpha: 0.4)
                          : colorScheme.outline,
                      width: 0.5,
                    ),
                  ),
                ),
                ...genres.map((genre) {
                  final id = genre['id'].toString();
                  final isSelected = selectedGenreId == id;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text(genre['name']),
                      selected: isSelected,
                      onSelected: (_) => loadMoviesByGenre(id),
                      selectedColor: colorScheme.primary.withValues(alpha: 0.2),
                      checkmarkColor: colorScheme.primary,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        fontSize: 13,
                      ),
                      side: BorderSide(
                        color: isSelected
                            ? colorScheme.primary.withValues(alpha: 0.4)
                            : colorScheme.outline,
                        width: 0.5,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // movies grid
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: movies.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.62,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 16,
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.15,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.network(
                                    movie.poster,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    cacheHeight:
                                        400, // prevents decoding massive images and freezing the UI
                                    errorBuilder: (_, __, ___) => Container(
                                      color: colorScheme.surface,
                                      child: Icon(
                                        Icons.movie_rounded,
                                        size: 40,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              movie.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
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
