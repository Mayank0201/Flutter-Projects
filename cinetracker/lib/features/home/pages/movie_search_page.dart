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
    final token = await storage.getToken();
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
    return Scaffold(
      appBar: AppBar(title: const Text("CineTracker")),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => searchMovie(),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: "search for a movie...",
                hintStyle: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 16),

            ElevatedButton(onPressed: searchMovie, child: const Text("search")),

            const SizedBox(height: 20),

            if (isLoading) const CircularProgressIndicator(),

            const SizedBox(height: 10),

            if (errorMessage != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),

            const SizedBox(height: 10),

            if (!isLoading && errorMessage == null)
              const Text(
                "search for a movie to begin.",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}
