import 'movie_model.dart';

class WatchlistItem {
  final int id;
  final int movieId;
  final String title;
  final String posterUrl;
  final int? releaseYear;
  final String genre;

  const WatchlistItem({
    required this.id,
    required this.movieId,
    required this.title,
    required this.posterUrl,
    required this.releaseYear,
    required this.genre,
  });

  factory WatchlistItem.fromJson(Map<String, dynamic> json) {
    return WatchlistItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      movieId: (json['movieId'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? '').toString(),
      posterUrl: (json['posterUrl'] ?? '').toString(),
      releaseYear: (json['releaseYear'] as num?)?.toInt(),
      genre: (json['genre'] ?? 'N/A').toString(),
    );
  }

  Movie toMovie() {
    return Movie(
      id: movieId,
      title: title,
      poster: posterUrl,
      releaseYear: releaseYear,
      genre: genre,
    );
  }
}
