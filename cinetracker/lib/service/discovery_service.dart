import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import '../core/network/api_service.dart';
import '../model/movie_model.dart';

/// Service for the backend's DiscoveryController endpoints:
///   GET /discovery/mood-match?mood=...
///   GET /discovery/trending?page=...
class DiscoveryService {
  static final DiscoveryService _instance = DiscoveryService._internal();

  factory DiscoveryService() => _instance;

  DiscoveryService._internal();

  final ApiService _apiService = ApiService();

  Dio get _dio => _apiService.dio;

  /// GET /discovery/mood-match?mood={mood}
  /// Valid moods: ENERGETIC, CHILL, EMOTIONAL, SPOOKY, CURIOUS, FAMILY
  Future<List<Movie>> getMoodMatch(String mood) async {
    final response = await _dio.get(
      "/discovery/mood-match",
      queryParameters: {"mood": mood.toUpperCase()},
    );

    debugPrint("MOOD MATCH RESPONSE: ${response.data}");

    final dynamic raw = response.data;
    if (raw is Map<String, dynamic>) {
      final dynamic data = raw['data'] ?? raw;
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map((e) => Movie.fromBackendJson(e))
            .toList();
      }
    }

    return <Movie>[];
  }

  /// GET /discovery/trending?page={page}
  Future<List<Movie>> getTrending({int page = 1}) async {
    final response = await _dio.get(
      "/discovery/trending",
      queryParameters: {"page": page},
    );

    debugPrint("TRENDING RESPONSE: ${response.data}");

    final dynamic raw = response.data;
    if (raw is Map<String, dynamic>) {
      final dynamic data = raw['data'] ?? raw;
      if (data is Map<String, dynamic>) {
        final List results = (data['results'] as List?) ?? [];
        return results
            .whereType<Map<String, dynamic>>()
            .map((e) => Movie.fromBackendJson(e))
            .toList();
      }
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map((e) => Movie.fromBackendJson(e))
            .toList();
      }
    }

    return <Movie>[];
  }

  /// GET /discovery/recommendations
  Future<List<Movie>> getRecommendations() async {
    final response = await _dio.get("/discovery/recommendations");

    debugPrint("RECOMMENDATIONS RESPONSE: ${response.data}");

    final dynamic raw = response.data;
    if (raw is Map<String, dynamic>) {
      final dynamic data = raw['data'] ?? raw;
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map((e) => Movie.fromBackendJson(e))
            .toList();
      }
    }

    return <Movie>[];
  }
}
