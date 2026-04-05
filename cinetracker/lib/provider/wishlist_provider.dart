import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/storage/token_storage.dart';
import '../model/movie_model.dart';
import '../model/watchlist_item_model.dart';
import '../service/tmdb_service.dart';

class WishlistProvider extends ChangeNotifier {
  final TMDBService _service = TMDBService();
  final List<WatchlistItem> _wishlist = [];
  bool _isLoading = false;
  String? _errorMessage;
  final Set<int> _pendingMovieIds = <int>{};

  List<WatchlistItem> get getWishlist => List.unmodifiable(_wishlist);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool isPending(int movieId) => _pendingMovieIds.contains(movieId);

  bool isFavorite(int movieId) {
    return _wishlist.any((m) => m.movieId == movieId);
  }

  Future<void> _ensureToken() async {
    final storage = TokenStorage();
    final token = await storage.getToken();
    if (token == null || token.isEmpty) {
      _service.clearToken();
      return;
    }
    _service.setToken(token);
  }

  void resetForLogout() {
    _wishlist.clear();
    _pendingMovieIds.clear();
    _errorMessage = null;
    _isLoading = false;
    _service.clearToken();
    notifyListeners();
  }

  Future<void> loadWatchlist() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _ensureToken();
      final items = await _service.getWatchlist();
      _wishlist
        ..clear()
        ..addAll(items);
    } catch (_) {
      _errorMessage = "failed to load watchlist.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addMovie(Movie movie) async {
    if (movie.id <= 0) {
      _errorMessage = "invalid movie id for watchlist.";
      notifyListeners();
      return false;
    }

    if (_pendingMovieIds.contains(movie.id)) return false;
    _pendingMovieIds.add(movie.id);
    notifyListeners();

    try {
      await _ensureToken();
      final item = await _service.addToWatchlist(movie.id);

      final exists = _wishlist.any((m) => m.movieId == item.movieId);
      if (!exists) {
        _wishlist.add(item);
      }

      _errorMessage = null;
      return true;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final responseData = e.response?.data;
      final serverMessage = _extractServerMessage(responseData).toLowerCase();

      // some backends return 409/400/500 with duplicate-key style errors.
      final isDuplicate =
          statusCode == 409 ||
          serverMessage.contains('already') ||
          serverMessage.contains('duplicate') ||
          serverMessage.contains('exists');

      if (isDuplicate) {
        final exists = isFavorite(movie.id);
        if (!exists) {
          _wishlist.add(
            WatchlistItem(
              id: 0,
              movieId: movie.id,
              title: movie.title,
              posterUrl: movie.poster,
              releaseYear: movie.releaseYear,
              genre: movie.genre,
            ),
          );
        }
        _errorMessage = null;
        return true;
      }

      final isValueTooLong =
          serverMessage.contains('value too long') ||
          serverMessage.contains('character varying(255)');

      final isUnauthorized =
          statusCode == 401 ||
          statusCode == 403 ||
          serverMessage.contains('unauthorized') ||
          serverMessage.contains('forbidden');

      _errorMessage = (isValueTooLong || isUnauthorized)
          ? "Movie can't be added right now."
          : (_extractServerMessage(responseData).isNotEmpty
                ? _extractServerMessage(responseData)
                : "Movie can't be added right now.");
      return false;
    } catch (_) {
      _errorMessage = "Movie can't be added right now.";
      return false;
    } finally {
      _pendingMovieIds.remove(movie.id);
      notifyListeners();
    }
  }

  Future<bool> removeMovieById(int movieId) async {
    if (_pendingMovieIds.contains(movieId)) return false;
    _pendingMovieIds.add(movieId);
    notifyListeners();

    try {
      await _ensureToken();
      final success = await _service.removeFromWatchlist(movieId);
      if (success) {
        _wishlist.removeWhere((m) => m.movieId == movieId);
        _errorMessage = null;
      }
      return success;
    } catch (_) {
      _errorMessage = "failed to remove movie.";
      return false;
    } finally {
      _pendingMovieIds.remove(movieId);
      notifyListeners();
    }
  }

  Future<bool> toggleFavorite(Movie movie) async {
    if (isFavorite(movie.id)) {
      return removeMovieById(movie.id);
    }
    return addMovie(movie);
  }

  String _extractServerMessage(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      return (responseData['message'] ??
              responseData['error'] ??
              responseData['details'] ??
              '')
          .toString();
    }
    if (responseData is String) {
      return responseData;
    }
    return '';
  }
}
