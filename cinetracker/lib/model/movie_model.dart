class Movie {
  final int id;
  final String title;
  final String poster;
  final String overview;
  final double rating;
  final int? releaseYear;
  final String genre;
  final List<String> cast;
  final String director;
  final List<Trailer> trailers;

  Movie({
    required this.id,
    required this.title,
    required this.poster,
    this.overview = "",
    this.rating = 0,
    this.releaseYear,
    this.genre = "N/A",
    this.cast = const [],
    this.director = "Unknown",
    this.trailers = const [],
  });

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static int? _extractReleaseYear(Map<String, dynamic> json) {
    final dynamic explicitYear = json['releaseYear'];
    if (explicitYear != null) {
      final parsed = _toInt(explicitYear);
      return parsed > 0 ? parsed : null;
    }

    final date = (json['releaseDate'] ?? json['release_date'])?.toString();
    if (date != null && date.length >= 4) {
      return int.tryParse(date.substring(0, 4));
    }

    return null;
  }

  factory Movie.fromBackendJson(Map<String, dynamic> json) {
    final posterPath = (json['posterUrl'] ?? json['poster_path'] ?? '')
        .toString();

    String resolvedPoster = posterPath;
    if (posterPath.startsWith('/')) {
      resolvedPoster = 'https://image.tmdb.org/t/p/w500$posterPath';
    }

    final dynamic genresRaw = json['genres'] ?? json['genreNames'];
    String parsedGenre = (json['genre'] ?? '').toString();
    if (parsedGenre.isEmpty && genresRaw is List && genresRaw.isNotEmpty) {
      final names = genresRaw
          .map((e) {
            if (e is Map<String, dynamic>) {
              return e['name']?.toString() ?? '';
            }
            return e.toString();
          })
          .where((e) => e.isNotEmpty)
          .toList();
      parsedGenre = names.join(', ');
    }

    List<String> parsedCast = [];
    final dynamic castRaw = json['cast'];
    if (castRaw is List) {
      parsedCast = castRaw.map((e) {
        if (e is Map<String, dynamic>) {
          return e['name']?.toString() ?? '';
        }
        return e.toString();
      }).where((name) => name.isNotEmpty).toList();
    }


    List<Trailer> parsedTrailers = [];
    final dynamic trailersRaw = json['trailers'];
    if (trailersRaw is List) {
      parsedTrailers = trailersRaw.map((e) => Trailer.fromJson(e)).toList();
    }

    return Movie(
      id: _toInt(
        json['movieId'] ??
            json['movie_id'] ??
            json['tmdbId'] ??
            json['tmdb_id'] ??
            json['id'],
      ),
      title: json['title'] ?? json['name'] ?? "",
      poster: resolvedPoster,
      overview: (json['overview'] ?? json['plot'] ?? '').toString(),
      rating: _toDouble(
        json['voteAverage'] ?? json['vote_average'] ?? json['rating'],
      ),
      releaseYear: _extractReleaseYear(json),
      genre: parsedGenre.isNotEmpty ? parsedGenre : 'N/A',
      cast: parsedCast,
      director: (json['director'] ?? 'Unknown').toString(),
      trailers: parsedTrailers,
    );
  }
}

class Trailer {
  final String id;
  final String name;
  final String key;
  final String site;

  Trailer({
    required this.id,
    required this.name,
    required this.key,
    required this.site,
  });

  factory Trailer.fromJson(Map<String, dynamic> json) {
    return Trailer(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Trailer').toString(),
      key: (json['key'] ?? '').toString(),
      site: (json['site'] ?? 'YouTube').toString(),
    );
  }
}
