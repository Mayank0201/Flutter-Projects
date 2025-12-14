import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../model/movie_model.dart';

class MovieService {
  final String apiKey = dotenv.env['API_KEY'] ?? '';
  final String baseUrl = "https://www.omdbapi.com/";

  // load detailed movie info by imdb id
  Future<Movie> getMovieById(String imdbId) async {
    final url = Uri.parse("$baseUrl?i=$imdbId&apikey=$apiKey");

    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception("Failed to load movie details");
    }

    final data = jsonDecode(response.body);

    if (data["Response"] == "False") {
      throw Exception("Movie not found");
    }

    return Movie.fromJson(data);  // full movie details
  }

  // used by search page to fetch list of movies
  Future<List<Movie>> searchMovies(String query) async {
    final url = Uri.parse("$baseUrl?s=$query&apikey=$apiKey");

    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception("Search request failed");
    }

    final data = jsonDecode(response.body);

    if (data["Response"] == "False") {
      throw Exception("No movies found");
    }

    final List results = data["Search"];

    // convert each item into a lightweight movie object
    return results.map((item) => Movie.fromSearchJson(item)).toList();
  }
}
