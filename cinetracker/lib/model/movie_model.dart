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

  // detailed fields (available only in full fetch)
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
  });

  // used when fetching full movie details with ?i=ID
  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      title: json["Title"] ?? "",
      year: json["Year"] ?? "",
      imdbId: json["imdbID"] ?? "",
      poster: json["Poster"] ?? "N/A",
      plot: json["Plot"] ?? "",
      genre: json["Genre"] ?? "",
      director: json["Director"] ?? "",
      actors: json["Actors"] ?? "",
      runtime: json["Runtime"] ?? "",
      released: json["Released"] ?? "",
      imdbRating: json["imdbRating"] ?? "",
    );
  }

  // used for search results (lightweight)
  factory Movie.fromSearchJson(Map<String, dynamic> json) {
    return Movie(
      title: json["Title"] ?? "",
      year: json["Year"] ?? "",
      imdbId: json["imdbID"] ?? "",
      poster: json["Poster"] ?? "N/A",

      // empty placeholders (details loaded later)
      plot: "",
      genre: "",
      director: "",
      actors: "",
      runtime: "",
      released: "",
      imdbRating: "",
    );
  }
}
