/// Represents a movie review from the backend's MovieRating entity.
class Review {
  final int id;
  final int movieId;
  final int userId;
  final String username;
  final double rating;
  final String? comment;
  final int helpfulCount;
  final bool isHelpful;
  final String createdAt;
  final String updatedAt;

  const Review({
    required this.id,
    required this.movieId,
    this.userId = 0,
    this.username = 'User',
    required this.rating,
    this.comment,
    this.helpfulCount = 0,
    this.isHelpful = false,
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: (json['id'] as num?)?.toInt() ?? 0,
      movieId: (json['movieId'] as num?)?.toInt() ?? 0,
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      username: json['username']?.toString() ?? 'User',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      comment: json['comment']?.toString(),
      helpfulCount: (json['helpfulCount'] as num?)?.toInt() ?? 0,
      isHelpful: json['isHelpful'] == true,
      createdAt: (json['createdAt'] ?? '').toString(),
      updatedAt: (json['updatedAt'] ?? '').toString(),
    );
  }
}
