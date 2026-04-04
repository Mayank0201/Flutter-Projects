import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../model/movie_model.dart';

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
}
