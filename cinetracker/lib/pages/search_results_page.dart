import 'package:flutter/material.dart';
import '../model/movie_model.dart';
import '../service/movie_service.dart';
import 'movie_details_page.dart';

class SearchResultsPage extends StatelessWidget {
  final List<Movie> movies;
  final String query;

  const SearchResultsPage({
    super.key,
    required this.movies,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    final service = MovieService();

    return Scaffold(
      appBar: AppBar(
        title: Text("Results for \"$query\""),
      ),

      body: ListView.builder(
        itemCount: movies.length,
        itemBuilder: (context, index) {
          final movie = movies[index];

          return ListTile(
            leading: movie.poster != "N/A"
                ? ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                movie.poster,
                width: 50,
                fit: BoxFit.cover,
              ),
            )
                : const Icon(Icons.movie),

            title: Text(movie.title),
            subtitle: Text(movie.year),

            onTap: () async {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );

              try {
                final fullMovie = await service.getMovieById(movie.imdbId);
                Navigator.pop(context);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MovieDetailsPage(movie: fullMovie),
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Failed to load movie details."),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}
