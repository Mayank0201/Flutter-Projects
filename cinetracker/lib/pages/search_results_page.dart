import 'package:flutter/material.dart';
import '../model/movie_model.dart';
import '../service/omdb_service.dart';
import 'movie_details_page.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:cinetracker/provider/wishlist_provider.dart';

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
    final service = OMDBService();

    return Scaffold(
      appBar: AppBar(title: Text('Results for "$query"')),

      body: ListView.builder(
        itemCount: movies.length,
        itemBuilder: (context, index) {
          final movie = movies[index];
          final posterUrl = movie.poster != 'N/A' ? movie.poster : null;

          return ListTile(
            leading: posterUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      posterUrl,
                      width: 50,
                      height: 75,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _smallPosterPlaceholder(),
                    ),
                  )
                : _smallPosterPlaceholder(),

            title: Text(movie.title),
            subtitle: Text(movie.year),
            trailing: Consumer<WishlistProvider>(
              builder: (context, wishlistProvider, _) {
                final isFavorite = wishlistProvider.isFavorite(movie.imdbId);

                return IconButton(
                  icon: Icon(
                    isFavorite ? Iconsax.heart5 : Iconsax.heart,
                    color: isFavorite ? Colors.red : Colors.grey,
                  ),
                  onPressed: () {
                    wishlistProvider.toggleFavorite(movie);
                  },
                );
              },
            ),
            onTap: () async {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) =>
                    const Center(child: CircularProgressIndicator()),
              );

              try {
                final fullMovie = await service.getMovieById(
                  movie.imdbId,
                  tmdbId: movie.tmdbId,
                );

                if (!context.mounted) return;
                Navigator.pop(context);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MovieDetailsPage(movie: fullMovie),
                  ),
                );
              } catch (_) {
                if (!context.mounted) return;
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('failed to load movie details')),
                );
              }
            },
          );
        },
      ),
    );
  }

  Widget _smallPosterPlaceholder() {
    return const SizedBox(
      width: 50,
      height: 75,
      child: Icon(Icons.movie, color: Colors.grey),
    );
  }
}
