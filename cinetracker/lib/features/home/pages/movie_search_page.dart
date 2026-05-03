import 'dart:async';
import 'package:flutter/material.dart';
import '../../../model/movie_model.dart';
import '../../../service/tmdb_service.dart';
import '../../../core/storage/token_storage.dart';
import 'movie_details_page.dart';
import 'search_results_page.dart';

class MovieSearchPage extends StatefulWidget {
  const MovieSearchPage({super.key});

  @override
  State<MovieSearchPage> createState() => _MovieSearchPageState();
}

class _MovieSearchPageState extends State<MovieSearchPage> {
  final TextEditingController controller = TextEditingController();
  final TMDBService service = TMDBService();

  bool isLoading = false;
  String? errorMessage;
  List<Movie> _results = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _initToken();
  }

  Future<void> _initToken() async {
    final storage = TokenStorage();
    final token = await storage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      service.setToken(token);
    } else {
      service.clearToken();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.trim().isNotEmpty) {
        _performSearch(query.trim(), isLiveSearch: true);
      } else {
        setState(() {
          _results = [];
          errorMessage = null;
        });
      }
    });
  }

  Future<void> _performSearch(String query, {bool isLiveSearch = false}) async {
    if (query.isEmpty) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final results = await service.searchMovies(query);

      if (!mounted) return;

      if (results.isEmpty) {
        setState(() {
          _results = [];
          errorMessage = isLiveSearch ? null : "no movies found.";
        });
      } else {
        if (isLiveSearch) {
          setState(() {
            _results = results;
          });
        } else {
          // If they explicitly hit search, go to the full results page
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SearchResultsPage(movies: results, query: query),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = "something went wrong.";
      });
    }

    if (!mounted) return;
    setState(() => isLoading = false);
  }

  void searchMovie() => _performSearch(controller.text.trim());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Search")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                textInputAction: TextInputAction.search,
                onChanged: _onSearchChanged,
                onSubmitted: (_) => searchMovie(),
                style: theme.textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: "Search for a movie...",
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (_, value, _) {
                      if (value.text.isEmpty) return const SizedBox.shrink();
                      return IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () {
                          controller.clear();
                          setState(() => errorMessage = null);
                        },
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              const SizedBox(height: 12),

              if (errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.error.withValues(alpha: 0.2),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: colorScheme.error,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          errorMessage!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (isLoading && _results.isEmpty)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_results.isNotEmpty)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          "Suggestions",
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: _results.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final movie = _results[index];
                            return _buildMovieTile(context, movie);
                          },
                        ),
                      ),
                    ],
                  ),
                )
              else if (!isLoading && errorMessage == null)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.movie_filter_outlined,
                          size: 56,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Search for a movie to begin",
                          style: theme.textTheme.titleSmall,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMovieTile(BuildContext context, Movie movie) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MovieDetailsPage(movie: movie),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: movie.poster.isNotEmpty
                    ? Image.network(
                        movie.poster,
                        width: 46,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _buildPlaceholderIcon(colorScheme),
                      )
                    : _buildPlaceholderIcon(colorScheme),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (movie.releaseYear != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        movie.releaseYear.toString(),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderIcon(ColorScheme colorScheme) {
    return Container(
      width: 46,
      height: 64,
      color: colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.movie_rounded,
        size: 20,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}
