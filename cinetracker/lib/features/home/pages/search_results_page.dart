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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Results for "$query"'),
      ),

      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: movies.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final movie = movies[index];

          return Material(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
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
                              width: 56,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                width: 56,
                                height: 80,
                                color: colorScheme.surface,
                                child: Icon(
                                  Icons.movie_rounded,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : Container(
                              width: 56,
                              height: 80,
                              color: colorScheme.surface,
                              child: Icon(
                                Icons.movie_rounded,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            movie.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium,
                          ),
                          if (movie.releaseYear != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              movie.releaseYear.toString(),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
