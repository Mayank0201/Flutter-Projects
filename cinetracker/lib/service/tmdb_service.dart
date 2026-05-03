import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import '../core/network/api_service.dart';
import '../model/movie_model.dart';
import '../model/watchlist_item_model.dart';

class SessionExpiredException implements Exception {
  final String message;

  SessionExpiredException([
    this.message = "Session expired. Please login again.",
  ]);

  @override
  String toString() => message;
}

class TMDBService {
  static final TMDBService _instance = TMDBService._internal();

  factory TMDBService() => _instance;

  TMDBService._internal();

  final ApiService _apiService = ApiService();

  Dio get dio => _apiService.dio;

  void setToken(String token) {
    _apiService.setToken(token);
  }

  void clearToken() {
    _apiService.clearToken();
  }

  Future<List<Movie>> getPopularMovies() async {
    final response = await dio.get(
      "/movie/popular",
      queryParameters: {"page": 1},
    );

    debugPrint("POPULAR RESPONSE: ${response.data}");

    final List data = response.data["results"] ?? [];

    return data.map((e) => Movie.fromBackendJson(e)).toList();
  }

  Future<List<Map<String, dynamic>>> getGenres() async {
    final response = await dio.get("/movie/genres");

    debugPrint("GENRE RESPONSE: ${response.data}");

    return List<Map<String, dynamic>>.from(response.data);
  }

  Future<List<Movie>> getMoviesByGenre(String genreId) async {
    final response = await dio.get(
      "/movie/by-genre",
      queryParameters: {"genreId": genreId, "page": 1},
    );

    debugPrint("GENRE MOVIES RESPONSE: ${response.data}");

    final List data = response.data["results"] ?? [];

    return data.map((e) => Movie.fromBackendJson(e)).toList();
  }

  Future<List<Movie>> searchMovies(String query) async {
    final response = await dio.get(
      "/movie/search",
      queryParameters: {"query": query, "page": 1},
    );

    debugPrint("SEARCH RESPONSE: ${response.data}");

    final List data = response.data["results"] ?? [];

    return data.map((e) => Movie.fromBackendJson(e)).toList();
  }

  Future<Movie> getMovieDetails(int movieId) async {
    final response = await dio.get(
      "/movie/details",
      queryParameters: {"movieId": movieId},
    );

    debugPrint("MOVIE DETAILS RESPONSE: ${response.data}");

    final dynamic raw = response.data;
    if (raw is Map<String, dynamic>) {
      if (raw['movie'] is Map<String, dynamic>) {
        return Movie.fromBackendJson(raw['movie'] as Map<String, dynamic>);
      }
      if (raw['data'] is Map<String, dynamic>) {
        return Movie.fromBackendJson(raw['data'] as Map<String, dynamic>);
      }
      return Movie.fromBackendJson(raw);
    }

    throw StateError("Invalid movie details response format");
  }

  Future<WatchlistItem> addToWatchlist(int movieId) async {
    final response = await dio.post(
      "/watchlist/add",
      data: {"movieId": movieId},
    );

    debugPrint("ADD WATCHLIST RESPONSE: ${response.data}");

    final dynamic raw = response.data;
    if (raw is Map<String, dynamic>) {
      // Unwrap ApiResponse: { success, data: { ...item } }
      final dynamic data = raw['data'] ?? raw;
      if (data is Map<String, dynamic>) {
        return WatchlistItem.fromJson(data);
      }
    }

    throw StateError("Invalid watchlist add response format");
  }

  Future<List<WatchlistItem>> getWatchlist({String? status}) async {
    final Map<String, dynamic> queryParams = {};
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status.toUpperCase();
    }

    final response = await dio.get(
      "/watchlist/get",
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    debugPrint("GET WATCHLIST RESPONSE: ${response.data}");

    final dynamic raw = response.data;
    if (raw is Map<String, dynamic>) {
      // Unwrap ApiResponse: { success, data: { pages, totalPages, results: [...] } }
      final dynamic data = raw['data'] ?? raw;
      List items;
      if (data is Map<String, dynamic>) {
        items = (data['results'] as List?) ?? [];
      } else if (data is List) {
        items = data;
      } else {
        items = [];
      }
      return items
          .whereType<Map<String, dynamic>>()
          .map(WatchlistItem.fromJson)
          .toList();
    }

    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map(WatchlistItem.fromJson)
          .toList();
    }

    return <WatchlistItem>[];
  }

  /// PATCH /watchlist/{movieId}/status  body: { "status": "ACTIVE" }
  Future<WatchlistItem> updateWatchlistStatus(int movieId, String status) async {
    final response = await dio.patch(
      "/watchlist/$movieId/status",
      data: {"status": status.toUpperCase()},
    );

    debugPrint("UPDATE WATCHLIST STATUS RESPONSE: ${response.data}");

    final dynamic raw = response.data;
    if (raw is Map<String, dynamic>) {
      final dynamic data = raw['data'] ?? raw;
      if (data is Map<String, dynamic>) {
        return WatchlistItem.fromJson(data);
      }
    }

    throw StateError("Invalid watchlist status update response format");
  }

  Future<bool> removeFromWatchlist(int movieId) async {
    final response = await dio.delete(
      "/watchlist/remove",
      data: {"movieId": movieId},
    );

    debugPrint("REMOVE WATCHLIST RESPONSE: ${response.data}");

    final dynamic raw = response.data;
    if (raw == null) return true;

    if (raw is Map<String, dynamic>) {
      // Unwrap ApiResponse: { success: true, ... }
      if (raw['success'] is bool) return raw['success'] as bool;
      final message = raw["message"]?.toString().toLowerCase() ?? "";
      return message.contains("removed") || message.contains("success");
    }

    return true;
  }
}
