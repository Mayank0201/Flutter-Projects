import 'badge_model.dart';
import 'review_model.dart';

/// Represents the user profile data from the backend's
/// SocialController GET /social/profile/{userId} endpoint.
class UserProfile {
  final int id;
  final String username;
  final int xp;
  final int level;
  final int followerCount;
  final int followingCount;
  final bool isFollowing;
  final List<Badge> badges;
  final List<Review> reviews;

  const UserProfile({
    required this.id,
    required this.username,
    this.xp = 0,
    this.level = 1,
    this.followerCount = 0,
    this.followingCount = 0,
    this.isFollowing = false,
    this.badges = const [],
    this.reviews = const [],
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    // Parse badges list
    final badgesRaw = json['badges'];
    final List<Badge> parsedBadges = (badgesRaw is List)
        ? badgesRaw
            .whereType<Map<String, dynamic>>()
            .map(Badge.fromJson)
            .toList()
        : [];

    // Parse reviews from the paginated "reviews" object
    List<Review> parsedReviews = [];
    final reviewsRaw = json['reviews'];
    if (reviewsRaw is Map<String, dynamic>) {
      final content = reviewsRaw['content'];
      if (content is List) {
        parsedReviews = content
            .whereType<Map<String, dynamic>>()
            .map(Review.fromJson)
            .toList();
      }
    } else if (reviewsRaw is List) {
      parsedReviews = reviewsRaw
          .whereType<Map<String, dynamic>>()
          .map(Review.fromJson)
          .toList();
    }

    return UserProfile(
      id: (json['id'] as num?)?.toInt() ?? 0,
      username: (json['username'] ?? '').toString(),
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
      followerCount: (json['followerCount'] as num?)?.toInt() ?? 0,
      followingCount: (json['followingCount'] as num?)?.toInt() ?? 0,
      isFollowing: json['isFollowing'] == true,
      badges: parsedBadges,
      reviews: parsedReviews,
    );
  }
}
