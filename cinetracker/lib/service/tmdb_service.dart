import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/widgets.dart';
import '../core/network/api_service.dart';
import '../core/navigation/app_navigator.dart';
import '../core/storage/token_storage.dart';
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

  final TokenStorage _tokenStorage = TokenStorage();
  final ApiService _apiService = ApiService();
  bool _isForcingLogout = false;
  Future<bool>? _refreshInFlight;

  final Dio dio = Dio(
    BaseOptions(
      baseUrl: dotenv.env['BASE_URL']!,
      responseType: ResponseType.json,
      headers: {"Content-Type": "application/json"},
    ),
  );

  late final Dio _refreshDio = Dio(
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

  Future<T> _withAutoRefresh<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      if (e.response?.statusCode != 401) {
        rethrow;
      }

      final refreshed = await _refreshAccessToken();
      if (!refreshed) {
        await _forceLogout();
        throw SessionExpiredException();
      }

      return await request();
    }
  }

  Future<bool> _refreshAccessToken() async {
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _performRefresh();
    _refreshInFlight = future;

    try {
      return await future;
    } finally {
      if (identical(_refreshInFlight, future)) {
        _refreshInFlight = null;
      }
    }
  }

  Future<bool> _performRefresh() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    try {
      final response = await _refreshDio.post(
        "/auth/refresh",
        data: {"refreshToken": refreshToken},
      );

      final accessToken = _extractAccessToken(response.data);
      if (accessToken == null || accessToken.isEmpty) {
        return false;
      }

      final nextRefreshToken = _extractRefreshToken(response.data);

      await _tokenStorage.saveAccessToken(accessToken);
      if (nextRefreshToken != null && nextRefreshToken.isNotEmpty) {
        await _tokenStorage.saveRefreshToken(nextRefreshToken);
      }

      setToken(accessToken);
      _apiService.setToken(accessToken);
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return false;
      }
      rethrow;
    }
  }

  String? _extractAccessToken(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw["accessToken"]?.toString() ??
          raw["token"]?.toString() ??
          raw["access_token"]?.toString();
    }
    if (raw is String && raw.isNotEmpty) {
      return raw;
    }
    return null;
  }

  String? _extractRefreshToken(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw["refreshToken"]?.toString() ??
          raw["refresh_token"]?.toString();
    }
    return null;
  }

  Future<void> _forceLogout() async {
    if (_isForcingLogout) {
      return;
    }

    _isForcingLogout = true;
    try {
      clearToken();
      _apiService.clearToken();
      await _tokenStorage.clearTokens();
      _navigateToLogin();
    } finally {
      _isForcingLogout = false;
    }
  }

  void _navigateToLogin() {
    final navigator = appNavigatorKey.currentState;
    if (navigator != null) {
      navigator.pushNamedAndRemoveUntil('/login', (route) => false);
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      appNavigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    });
  }

  Future<List<Movie>> getPopularMovies() async {
    return _withAutoRefresh(() async {
      final response = await dio.get(
        "/movie/popular",
        queryParameters: {"page": 1},
      );

      debugPrint("POPULAR RESPONSE: ${response.data}");

      final List data = response.data["results"] ?? [];

      return data.map((e) => Movie.fromBackendJson(e)).toList();
    });
  }

  Future<List<Map<String, dynamic>>> getGenres() async {
    return _withAutoRefresh(() async {
      final response = await dio.get("/movie/genres");

      debugPrint("GENRE RESPONSE: ${response.data}");

      return List<Map<String, dynamic>>.from(response.data);
    });
  }

  Future<List<Movie>> getMoviesByGenre(String genreId) async {
    return _withAutoRefresh(() async {
      final response = await dio.get(
        "/movie/by-genre",
        queryParameters: {"genreId": genreId, "page": 1},
      );

      debugPrint("GENRE MOVIES RESPONSE: ${response.data}");

      final List data = response.data["results"] ?? [];

      return data.map((e) => Movie.fromBackendJson(e)).toList();
    });
  }

  Future<List<Movie>> searchMovies(String query) async {
    return _withAutoRefresh(() async {
      final response = await dio.get(
        "/movie/search",
        queryParameters: {"query": query, "page": 1},
      );

      debugPrint("SEARCH RESPONSE: ${response.data}");

      final List data = response.data["results"] ?? [];

      return data.map((e) => Movie.fromBackendJson(e)).toList();
    });
  }

  Future<Movie> getMovieDetails(int movieId) async {
    return _withAutoRefresh(() async {
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
    });
  }

  Future<WatchlistItem> addToWatchlist(int movieId) async {
    return _withAutoRefresh(() async {
      final response = await dio.post(
        "/watchlist/add",
        data: {"movieId": movieId},
      );

      debugPrint("ADD WATCHLIST RESPONSE: ${response.data}");

      final dynamic raw = response.data;
      if (raw is Map<String, dynamic>) {
        return WatchlistItem.fromJson(raw);
      }

      throw StateError("Invalid watchlist add response format");
    });
  }

  Future<List<WatchlistItem>> getWatchlist() async {
    return _withAutoRefresh(() async {
      final response = await dio.get("/watchlist/get");

      debugPrint("GET WATCHLIST RESPONSE: ${response.data}");

      final dynamic raw = response.data;
      if (raw is List) {
        return raw
            .whereType<Map<String, dynamic>>()
            .map(WatchlistItem.fromJson)
            .toList();
      }

      return <WatchlistItem>[];
    });
  }

  Future<bool> removeFromWatchlist(int movieId) async {
    return _withAutoRefresh(() async {
      final response = await dio.delete(
        "/watchlist/remove",
        data: {"movieId": movieId},
      );

      debugPrint("REMOVE WATCHLIST RESPONSE: ${response.data}");

      final dynamic raw = response.data;
      if (raw == null) {
        return true;
      }

      if (raw is Map<String, dynamic>) {
        final message = raw["message"]?.toString().toLowerCase() ?? "";
        return message.contains("removed") || message.contains("success");
      }

      return true;
    });
  }
}
