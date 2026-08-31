import 'package:dio/dio.dart';
import '../core/network/api_service.dart';
import '../model/show_model.dart';

// calls the backend tv endpoints. /show/* is browse and search, /shows/* is progress.
class ShowService {
  static final ShowService _instance = ShowService._internal();

  factory ShowService() => _instance;

  ShowService._internal();

  final ApiService _apiService = ApiService();

  Dio get dio => _apiService.dio;

  // the /shows/* endpoints wrap the payload in ApiResponse, /show/* does not.
  // unwrap defensively so a change on either side does not silently return nothing.
  static dynamic _unwrap(dynamic raw) {
    if (raw is Map<String, dynamic> && raw.containsKey("data")) {
      return raw["data"];
    }
    return raw;
  }

  static List<Show> _showsFrom(dynamic body) {
    final data = _unwrap(body);
    final List list = (data is Map ? data["results"] : data) as List? ?? const [];
    return list
        .map((e) => Show.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Show>> getPopularShows({int page = 1}) async {
    final response = await dio.get("/show/popular", queryParameters: {"page": page});
    return _showsFrom(response.data);
  }

  Future<List<Show>> searchShows(String query, {int page = 1}) async {
    final response = await dio.get(
      "/show/search",
      queryParameters: {"query": query, "page": page},
    );
    return _showsFrom(response.data);
  }

  Future<List<Show>> getShowsByGenre(int genreId, {int page = 1}) async {
    final response = await dio.get(
      "/show/by-genre",
      queryParameters: {"genreId": genreId, "page": page},
    );
    return _showsFrom(response.data);
  }

  Future<List<Map<String, dynamic>>> getGenres() async {
    final response = await dio.get("/show/genres");
    final data = _unwrap(response.data);
    return List<Map<String, dynamic>>.from(data as List? ?? const []);
  }

  // show detail plus how far this user is through every season
  Future<ShowProgress> getShowProgress(int showTmdbId) async {
    final response = await dio.get("/shows/$showTmdbId/progress");
    return ShowProgress.fromJson(_unwrap(response.data) as Map<String, dynamic>);
  }

  // episodes for one season, with the numbers this user already watched
  Future<({List<Episode> episodes, Set<int> watched})> getSeason(
    int showTmdbId,
    int seasonNumber,
  ) async {
    final response = await dio.get("/shows/$showTmdbId/seasons/$seasonNumber");
    final data = _unwrap(response.data) as Map<String, dynamic>;

    final rawEpisodes = (data["episodes"] as List?) ?? const [];
    final rawWatched = (data["watchedEpisodes"] as List?) ?? const [];

    return (
      episodes: rawEpisodes
          .map((e) => Episode.fromJson(e as Map<String, dynamic>))
          .toList(),
      watched: rawWatched.map((e) => e as int).toSet(),
    );
  }

  Future<List<ShowProgress>> getContinueWatching({int limit = 10}) async {
    final response = await dio.get(
      "/shows/continue-watching",
      queryParameters: {"limit": limit},
    );
    final list = _unwrap(response.data) as List? ?? const [];
    return list
        .map((e) => ShowProgress.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // mark or clear one episode. returns the show with its totals already redone
  Future<ShowProgress> markEpisode({
    required int showTmdbId,
    required int seasonNumber,
    required int episodeNumber,
    required bool watched,
  }) async {
    final response = await dio.put("/shows/episodes/watched", data: {
      "showTmdbId": showTmdbId,
      "seasonNumber": seasonNumber,
      "episodeNumber": episodeNumber,
      "watched": watched,
    });
    return ShowProgress.fromJson(_unwrap(response.data) as Map<String, dynamic>);
  }

  // whole season in one call instead of one request per episode
  Future<ShowProgress> markSeason({
    required int showTmdbId,
    required int seasonNumber,
    required bool watched,
  }) async {
    final response = await dio.put(
      "/shows/$showTmdbId/seasons/$seasonNumber/watched",
      queryParameters: {"watched": watched},
    );
    return ShowProgress.fromJson(_unwrap(response.data) as Map<String, dynamic>);
  }

  Future<ShowProgress> setStatus(int showTmdbId, String status) async {
    final response = await dio.patch(
      "/shows/$showTmdbId/status",
      queryParameters: {"status": status},
    );
    return ShowProgress.fromJson(_unwrap(response.data) as Map<String, dynamic>);
  }

  // ratings go through the polymorphic table. targetId is our own id, not the
  // tmdb one: showId for a show, seasonId for a season, both of which come back
  // in the progress response.
  Future<void> rate({
    required String targetType,
    required int targetId,
    required double score,
    String? comment,
  }) async {
    await dio.put("/ratings", data: {
      "targetType": targetType,
      "targetId": targetId,
      "score": score,
      if (comment != null && comment.isNotEmpty) "comment": comment,
    });
  }

  Future<void> deleteRating(String targetType, int targetId) async {
    await dio.delete("/ratings/$targetType/$targetId");
  }

  // average, count, and this user's own score if they left one
  Future<({double average, int count, double? mine})> ratingSummary(
    String targetType,
    int targetId,
  ) async {
    final response = await dio.get("/ratings/$targetType/$targetId/summary");
    final data = _unwrap(response.data) as Map<String, dynamic>;
    return (
      average: ((data["averageRating"] ?? 0) as num).toDouble(),
      count: ((data["ratingCount"] ?? 0) as num).toInt(),
      mine: (data["myRating"] as num?)?.toDouble(),
    );
  }
}
