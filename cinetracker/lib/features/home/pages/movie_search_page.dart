import 'package:flutter/material.dart';
import '../../../service/tmdb_service.dart';
import '../../../core/storage/token_storage.dart';
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
    controller.dispose();
    super.dispose();
  }

  void searchMovie() async {
    final query = controller.text.trim();

    if (query.isEmpty) {
      setState(() {
        errorMessage = "please enter a movie name.";
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final results = await service.searchMovies(query);

      if (!mounted) return;

      if (results.isEmpty) {
        setState(() {
          errorMessage = "no movies found.";
        });
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SearchResultsPage(movies: results, query: query),
          ),
        );
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
                    builder: (_, value, __) {
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

              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : searchMovie,
                  icon: isLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.search_rounded, size: 20),
                  label: Text(isLoading ? "Searching..." : "Search"),
                ),
              ),

              const SizedBox(height: 24),

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

              if (!isLoading && errorMessage == null)
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
}
