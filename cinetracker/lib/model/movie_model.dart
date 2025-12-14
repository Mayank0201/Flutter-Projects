class Movie {
  final String title;
  final String year;
  final String imdbId;
  final String poster;

  // detailed fields (available only in full fetch)
  final String plot;
  final String genre;
  final String director;
  final String actors;
  final String runtime;
  final String released;
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
