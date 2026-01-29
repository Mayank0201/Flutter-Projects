import 'package:hive/hive.dart';

part 'movie_model.g.dart';

@HiveType(typeId: 0)
class Movie {
  @HiveField(0)
  final String title;
  @HiveField(1)
  final String year;
  @HiveField(2)
  final String imdbId;
  @HiveField(3)
  final String poster;

  // detailed fields
  @HiveField(4)
  final String plot;
  @HiveField(5)
  final String genre;
  @HiveField(6)
  final String director;
  @HiveField(7)
  final String actors;
  @HiveField(8)
  final String runtime;
  @HiveField(9)
  final String released;
  @HiveField(10)
  final String imdbRating;

  // tmdb id (used as bridge)
  @HiveField(11)
  final int tmdbId;

  Movie({
    required this.title,
    required this.year,
    required this.imdbId,
    required this.poster,
    required this.plot,
    required this.genre,
    required this.director,
    required this.actors,
    required this.runtime,
    required this.released,
    required this.imdbRating,
    required this.tmdbId,
  });

  // full movie from omdb (tmdbId passed manually)
  factory Movie.fromJson(Map<String, dynamic> json, {required int tmdbId}) {
    return Movie(
      title: json["Title"] ?? "",
      year: json["Year"] ?? "",
      imdbId: json["imdbID"] ?? "",
      poster: json["Poster"] ?? "",
      plot: json["Plot"] ?? "",
      genre: json["Genre"] ?? "",
      director: json["Director"] ?? "",
      actors: json["Actors"] ?? "",
      runtime: json["Runtime"] ?? "",
      released: json["Released"] ?? "",
      imdbRating: json["imdbRating"] ?? "",
      tmdbId: tmdbId,
    );
  }

  // omdb search result (no tmdb id available)
  factory Movie.fromSearchJson(Map<String, dynamic> json) {
    return Movie(
      title: json["Title"] ?? "",
      year: json["Year"] ?? "",
      imdbId: json["imdbID"] ?? "",
      poster: json["Poster"] ?? "",

      plot: "",
      genre: "",
      director: "",
      actors: "",
      runtime: "",
      released: "",
      imdbRating: "",

      tmdbId: 0, // ✅ safe placeholder
    );
  }

  // tmdb discover result
  factory Movie.fromTMDBJson(Map<String, dynamic> json) {
    return Movie(
      title: json['title'] ?? "",
      year: json['release_date']?.substring(0, 4) ?? "",
      poster: json['poster_path'] != null
          ? 'https://image.tmdb.org/t/p/w500${json['poster_path']}'
          : "",
      imdbId: "",

      plot: "",
      genre: "",
      director: "",
      actors: "",
      runtime: "",
      released: "",
      imdbRating: "",

      tmdbId: json['id'], // ✅ tmdb id comes from tmdb only
    );
  }
}
