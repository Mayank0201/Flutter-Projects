import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/wishlist_provider.dart';
import 'movie_details_page.dart';
import '../model/movie_model.dart';

class WishlistPage extends StatelessWidget {
  const WishlistPage({super.key});

  @override
  Widget build(BuildContext context) {
    void onPressed(Movie movie) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => MovieDetailsPage(movie: movie)),
      );
    }

    final provider = context.watch<WishlistProvider>();
    final wishlist = provider.getWishlist;
    if (wishlist.isEmpty) {
      return Center(child: Text("No Items Yet, Try Adding Some!"));
    } else {
      return ListView.builder(
        itemCount: wishlist.length,
        itemBuilder: (context, index) {
          final movie = wishlist[index];

          return ListTile(
            title: Text(movie.title),
            subtitle: Text(movie.year),
            onTap: () => onPressed(movie),
          );
        },
      );
    }
  }
}
