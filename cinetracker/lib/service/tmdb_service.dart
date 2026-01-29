import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../model/movie_model.dart';
import '../core/constants/genre_map.dart';

class TMDBService {
  final String tmdbApiKey = dotenv.env['TMDB_API_KEY'] ?? '';
  final String tmdbBaseUrl = "https://api.themoviedb.org/3/discover/movie";

  Future<List<Movie>> getGenreMovies(String genre) async {
    final int? genreId = tmdbGenreMap[genre];

    if (genreId == null) {
      return [];
    }

    final url = Uri.parse(
      '$tmdbBaseUrl'
      '?api_key=$tmdbApiKey'
      '&with_genres=$genreId'
      '&language=en-US'
      '&page=1',
    );

    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception('Failed to load movies');
    }

    final data = json.decode(response.body);
    final List moviesJson = data['results'];

    return moviesJson
        .map((movieJson) => Movie.fromTMDBJson(movieJson))
        .toList();
  }

  Future<String?> getImdbId(int tmdbId) async {
    final url = Uri.parse(
      'https://api.themoviedb.org/3/movie/$tmdbId/external_ids'
      '?api_key=$tmdbApiKey',
    );

    final response = await http.get(url);

    if (response.statusCode != 200) {
      return null;
    }

    final data = json.decode(response.body);

    // TMDB returns imdb_id like "tt0848228"
    return data['imdb_id'];
  }
}
