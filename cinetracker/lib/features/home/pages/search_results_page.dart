import 'package:flutter/material.dart';
import '../../../model/movie_model.dart';
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
    return Scaffold(
      appBar: AppBar(title: Text('Results for "$query"')),

      body: ListView.builder(
        itemCount: movies.length,
        itemBuilder: (context, index) {
          final movie = movies[index];

          return ListTile(
            leading: movie.poster.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      movie.poster,
                      width: 50,
                      height: 75,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.movie),
                    ),
                  )
                : const Icon(Icons.movie),

            title: Text(movie.title),

            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MovieDetailsPage(movie: movie),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: const SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Text(
            "This product uses the TMDB API but is not endorsed or certified by TMDB.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}
