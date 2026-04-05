import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../model/movie_model.dart';
import '../model/watchlist_item_model.dart';

class TMDBService {
  static final TMDBService _instance = TMDBService._internal();

  factory TMDBService() => _instance;

  TMDBService._internal();

  final Dio dio = Dio(
    BaseOptions(
      baseUrl: dotenv.env['BASE_URL']!,
      responseType: ResponseType.json,
      headers: {"Content-Type": "application/json"},
    ),
  );

  void setToken(String token) {
    dio.options.headers["Authorization"] = "Bearer $token";
  }

  void clearToken() {
    dio.options.headers.remove("Authorization");
  }

  Future<List<Movie>> getPopularMovies() async {
    final response = await dio.get(
      "/movie/popular",
      queryParameters: {"page": 1},
    );

    print("POPULAR RESPONSE: ${response.data}");

    final List data = response.data["results"] ?? [];

    return data.map((e) => Movie.fromBackendJson(e)).toList();
  }

  Future<List<Map<String, dynamic>>> getGenres() async {
    final response = await dio.get("/movie/genres");

    print("GENRE RESPONSE: ${response.data}");

    return List<Map<String, dynamic>>.from(response.data);
  }

  Future<List<Movie>> getMoviesByGenre(String genreId) async {
    final response = await dio.get(
      "/movie/by-genre",
      queryParameters: {"genreId": genreId, "page": 1},
    );

    print("GENRE MOVIES RESPONSE: ${response.data}");

    final List data = response.data["results"] ?? [];

    return data.map((e) => Movie.fromBackendJson(e)).toList();
  }

  Future<List<Movie>> searchMovies(String query) async {
    final response = await dio.get(
      "/movie/search",
      queryParameters: {"query": query, "page": 1},
    );

    print("SEARCH RESPONSE: ${response.data}");

    final List data = response.data["results"] ?? [];

    return data.map((e) => Movie.fromBackendJson(e)).toList();
  }

  Future<Movie> getMovieDetails(int movieId) async {
    final response = await dio.get(
      "/movie/details",
      queryParameters: {"movieId": movieId},
    );

    print("MOVIE DETAILS RESPONSE: ${response.data}");

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

    print("ADD WATCHLIST RESPONSE: ${response.data}");

    final dynamic raw = response.data;
    if (raw is Map<String, dynamic>) {
      return WatchlistItem.fromJson(raw);
    }

    throw StateError("Invalid watchlist add response format");
  }

  Future<List<WatchlistItem>> getWatchlist() async {
    final response = await dio.get("/watchlist/get");

    print("GET WATCHLIST RESPONSE: ${response.data}");

    final dynamic raw = response.data;
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map(WatchlistItem.fromJson)
          .toList();
    }

    return [];
  }

  Future<bool> removeFromWatchlist(int movieId) async {
    final response = await dio.delete(
      "/watchlist/remove",
      data: {"movieId": movieId},
    );

    print("REMOVE WATCHLIST RESPONSE: ${response.data}");

    final dynamic raw = response.data;
    if (raw == null) {
      return true;
    }

    if (raw is Map<String, dynamic>) {
      final message = raw["message"]?.toString().toLowerCase() ?? "";
      return message.contains("removed") || message.contains("success");
    }

    return true;
  }
}
