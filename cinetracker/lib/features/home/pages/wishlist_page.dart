import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../provider/wishlist_provider.dart';
import 'movie_details_page.dart';

class WishlistPage extends StatefulWidget {
  const WishlistPage({super.key});

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WishlistProvider>().loadWatchlist();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WishlistProvider>();
    final wishlist = provider.getWishlist;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    void onPressed(int index) {
      final movie = wishlist[index].toMovie();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => MovieDetailsPage(movie: movie)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Wishlist"),
      ),
      body: _buildBody(provider, wishlist, theme, colorScheme, onPressed),
    );
  }

  Widget _buildBody(
    WishlistProvider provider,
    List wishlist,
    ThemeData theme,
    ColorScheme colorScheme,
    void Function(int) onPressed,
  ) {
    if (provider.isLoading && wishlist.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null && wishlist.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: colorScheme.error.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 14),
              Text(
                provider.errorMessage!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => provider.loadWatchlist(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    if (wishlist.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_outline_rounded,
              size: 56,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              "No movies yet",
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              "Add movies to your watchlist",
              style: theme.textTheme.titleSmall,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.loadWatchlist,
      color: colorScheme.primary,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: wishlist.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = wishlist[index];
          final subtitle = [
            if (item.releaseYear != null) item.releaseYear.toString(),
            item.genre,
          ].join(" • ");

          return Material(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onPressed(index),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: item.posterUrl.isNotEmpty
                          ? Image.network(
                              item.posterUrl,
                              width: 56,
                              height: 80,
                              fit: BoxFit.cover,
                              cacheHeight: 160,
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
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium,
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                    provider.isPending(item.movieId)
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.primary,
                            ),
                          )
                        : IconButton(
                            onPressed: () async {
                              final success = await provider.removeMovieById(
                                item.movieId,
                              );
                              if (!context.mounted) return;
                              if (!success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Failed to remove movie."),
                                  ),
                                );
                              }
                            },
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              color: colorScheme.error.withValues(alpha: 0.7),
                              size: 22,
                            ),
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
