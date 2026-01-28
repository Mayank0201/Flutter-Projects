import 'package:flutter/material.dart';
import '../model/movie_model.dart';

class WishlistProvider extends ChangeNotifier {
  final List<Movie> _wishlist = [];

  List<Movie> get getWishlist => _wishlist;

  void toggleFavorite(Movie movie) {
    if (_wishlist.any((m) => m.imdbId == movie.imdbId)) {
      _wishlist.removeWhere((m) => m.imdbId == movie.imdbId);
    } else {
      _wishlist.add(movie);
    }
    notifyListeners();
  }

  bool isFavorite(String imdbId) {
    return _wishlist.any((m) => m.imdbId == imdbId);
  }
}
