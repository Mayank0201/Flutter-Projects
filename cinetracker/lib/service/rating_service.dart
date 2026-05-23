import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import '../core/network/api_service.dart';
import '../model/review_model.dart';

/// rating summary returned by the backend
class RatingSummary {
  final double averageRating;
  final int totalRatings;
  final double? userRating; // null when the user hasn't rated; double for half-star support

  RatingSummary({
    required this.averageRating,
    required this.totalRatings,
    this.userRating,
  });

  factory RatingSummary.fromJson(Map<String, dynamic> json) {
    return RatingSummary(
      // backend field: averageRating
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      // backend field: ratingCount (not 'totalRatings')
      totalRatings: (json['ratingCount'] as num?)?.toInt() ?? 0,
      // backend field: myRating (not 'userRating')
      userRating: (json['myRating'] as num?)?.toDouble(),
    );
  }

  factory RatingSummary.empty() =>
      RatingSummary(averageRating: 0, totalRatings: 0);
}

class RatingService {
  static final RatingService _instance = RatingService._internal();

  factory RatingService() => _instance;

  RatingService._internal();

  final ApiService _apiService = ApiService();

  // reuse the existing api service dio instance (already has base url + auth)
  Dio get _dio => _apiService.dio;

  // ── public api ──────────────────────────────────────────────────────

  /// GET /movie/{movieId}/rating-summary
  Future<RatingSummary> getRatingSummary(int movieId) async {
    final response = await _dio.get("/movie/$movieId/rating-summary");
    debugPrint("RATING SUMMARY RESPONSE: ${response.data}");

    final dynamic raw = response.data;
    if (raw is Map<String, dynamic>) {
      // Unwrap ApiResponse envelope: { success, data: { ...summary } }
      final dynamic data = raw['data'] ?? raw;
      if (data is Map<String, dynamic>) {
        return RatingSummary.fromJson(data);
      }
    }
    return RatingSummary.empty();
  }

  /// PUT /movie/{movieId}/rating  body: { "rating": 1.0-5.0, "comment": "..." }
  Future<void> setRating(int movieId, double rating, {String? comment}) async {
    final Map<String, dynamic> body = {"rating": rating};
    if (comment != null && comment.isNotEmpty) {
      body["comment"] = comment;
    }
    await _dio.put(
      "/movie/$movieId/rating",
      data: body,
    );
    debugPrint("SET RATING: movieId=$movieId rating=$rating comment=$comment");
  }

  /// DELETE /movie/{movieId}/rating
  Future<void> deleteRating(int movieId) async {
    await _dio.delete("/movie/$movieId/rating");
    debugPrint("DELETE RATING: movieId=$movieId");
  }

  /// GET /movie/{movieId}/reviews  — paginated list of reviews
  Future<List<Review>> getMovieReviews(int movieId, {int page = 1, int size = 10, String sortBy = 'newest'}) async {
    final response = await _dio.get(
      "/movie/$movieId/reviews",
      queryParameters: {"page": page, "size": size, "sortBy": sortBy},
    );
    debugPrint("MOVIE REVIEWS RESPONSE: ${response.data}");

    final dynamic raw = response.data;
    if (raw is Map<String, dynamic>) {
      final dynamic data = raw['data'] ?? raw;
      // The backend returns a Spring Page object with a "content" array
      List items;
      if (data is Map<String, dynamic>) {
        items = (data['content'] as List?) ?? [];
      } else if (data is List) {
        items = data;
      } else {
        items = [];
      }
      return items
          .whereType<Map<String, dynamic>>()
          .map(Review.fromJson)
          .toList();
    }

    return <Review>[];
  }

  /// POST /movie/review/{ratingId}/helpful — toggles the helpful status
  Future<void> toggleReviewHelpful(int ratingId) async {
    await _dio.post("/movie/review/$ratingId/helpful");
    debugPrint("TOGGLE HELPFUL: ratingId=$ratingId");
  }

  /// GET /movie/my-reviews — paginated list of reviews for the logged-in user
  Future<List<Review>> getMyReviews({int page = 1, int size = 10}) async {
    final response = await _dio.get(
      "/movie/my-reviews",
      queryParameters: {"page": page, "size": size},
    );
    debugPrint("MY REVIEWS RESPONSE: ${response.data}");

    final dynamic raw = response.data;
    if (raw is Map<String, dynamic>) {
      final dynamic data = raw['data'] ?? raw;
      List items;
      if (data is Map<String, dynamic>) {
        items = (data['content'] as List?) ?? [];
      } else if (data is List) {
        items = data;
      } else {
        items = [];
      }
      return items
          .whereType<Map<String, dynamic>>()
          .map(Review.fromJson)
          .toList();
    }
    return <Review>[];
  }
}
