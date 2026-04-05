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

    void onPressed(int index) {
      final movie = wishlist[index].toMovie();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => MovieDetailsPage(movie: movie)),
      );
    }

    if (provider.isLoading && wishlist.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null && wishlist.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(provider.errorMessage!),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => provider.loadWatchlist(),
              child: const Text("Retry"),
            ),
          ],
        ),
      );
    }

    if (wishlist.isEmpty) {
      return const Center(
        child: Text("No items yet. Add movies to your watchlist."),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.loadWatchlist,
      child: ListView.separated(
        itemCount: wishlist.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = wishlist[index];
          final subtitle = [
            if (item.releaseYear != null) item.releaseYear.toString(),
            item.genre,
          ].join(" • ");

          return ListTile(
            leading: item.posterUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      item.posterUrl,
                      width: 50,
                      height: 75,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.movie),
                    ),
                  )
                : const Icon(Icons.movie),
            title: Text(item.title),
            subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
            trailing: IconButton(
              onPressed: provider.isPending(item.movieId)
                  ? null
                  : () async {
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
              icon: provider.isPending(item.movieId)
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
            ),
            onTap: () => onPressed(index),
          );
        },
      ),
    );
  }
}
