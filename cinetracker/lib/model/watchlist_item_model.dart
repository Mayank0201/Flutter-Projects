import 'movie_model.dart';

class WatchlistItem {
  final int id;
  final int movieId;
  final String title;
  final String posterUrl;
  final int? releaseYear;
  final String genre;
  final String status;

  const WatchlistItem({
    required this.id,
    required this.movieId,
    required this.title,
    required this.posterUrl,
    required this.releaseYear,
    required this.genre,
    this.status = 'PENDING',
  });

  factory WatchlistItem.fromJson(Map<String, dynamic> json) {
    return WatchlistItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      movieId: (json['movieId'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? '').toString(),
      posterUrl: (json['posterUrl'] ?? '').toString(),
      releaseYear: (json['releaseYear'] as num?)?.toInt(),
      genre: (json['genre'] ?? 'N/A').toString(),
      status: (json['status'] ?? 'PENDING').toString().toUpperCase(),
    );
  }

  WatchlistItem copyWith({String? status}) {
    return WatchlistItem(
      id: id,
      movieId: movieId,
      title: title,
      posterUrl: posterUrl,
      releaseYear: releaseYear,
      genre: genre,
      status: status ?? this.status,
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
