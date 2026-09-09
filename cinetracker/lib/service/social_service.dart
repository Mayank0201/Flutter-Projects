import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import '../core/network/api_service.dart';
import '../model/user_profile_model.dart';

/// Matches ChallengeService.Challenge from the backend.
/// Weekly challenges and lifetime quests share this shape: progress counts
/// toward target, and only quests carry a badge.
class Challenge {
  final String id;
  final String title;
  final String description;
  final int rewardXp;
  final bool isCompleted;
  final bool canClaim;
  final int progress;
  final int target;
  final String? badgeName;

  const Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.rewardXp,
    required this.isCompleted,
    required this.canClaim,
    this.progress = 0,
    this.target = 0,
    this.badgeName,
  });

  /// 0..1, safe when the backend sends a target of 0.
  double get fraction {
    if (target <= 0) return 0;
    return (progress / target).clamp(0.0, 1.0);
  }

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      rewardXp: (json['rewardXp'] as num?)?.toInt() ?? 0,
      isCompleted: json['completed'] == true || json['isCompleted'] == true,
      canClaim: json['canClaim'] == true,
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      target: (json['target'] as num?)?.toInt() ?? 0,
      badgeName: json['badgeName']?.toString(),
    );
  }
}

/// Service for the backend's SocialController endpoints:
///   POST   /social/follow/{userId}
///   DELETE /social/unfollow/{userId}
///   GET    /social/profile/{userId}
class SocialService {
  static final SocialService _instance = SocialService._internal();

  factory SocialService() => _instance;

  SocialService._internal();

  final ApiService _apiService = ApiService();

  Dio get _dio => _apiService.dio;

  /// POST /social/follow/{userId}
  Future<void> followUser(int userId) async {
    final response = await _dio.post("/social/follow/$userId");
    debugPrint("FOLLOW USER RESPONSE: ${response.data}");
  }

  /// DELETE /social/unfollow/{userId}
  Future<void> unfollowUser(int userId) async {
    final response = await _dio.delete("/social/unfollow/$userId");
    debugPrint("UNFOLLOW USER RESPONSE: ${response.data}");
  }

  /// GET /social/profile/{userId}?page=&size=
  Future<UserProfile> getUserProfile(int userId, {int page = 1, int size = 10}) async {
    final response = await _dio.get(
      "/social/profile/$userId",
      queryParameters: {"page": page, "size": size},
    );

    debugPrint("USER PROFILE RESPONSE: ${response.data}");

    final dynamic raw = response.data;
    if (raw is Map<String, dynamic>) {
      final dynamic data = raw['data'] ?? raw;
      if (data is Map<String, dynamic>) {
        return UserProfile.fromJson(data);
      }
    }

    throw StateError("Invalid user profile response format");
  }

  /// GET /social/challenges
  Future<List<Challenge>> getDailyChallenges() async {
    final response = await _dio.get("/social/challenges");
    debugPrint("DAILY CHALLENGES RESPONSE: ${response.data}");
    return _parseChallengeList(response.data);
  }

  /// GET /social/quests
  Future<List<Challenge>> getQuests() async {
    final response = await _dio.get("/social/quests");
    debugPrint("QUESTS RESPONSE: ${response.data}");
    return _parseChallengeList(response.data);
  }

  /// POST /social/quests/{questId}/claim
  Future<String> claimQuest(String questId) async {
    final response = await _dio.post("/social/quests/$questId/claim");
    debugPrint("CLAIM QUEST RESPONSE: ${response.data}");
    final dynamic raw = response.data;
    if (raw is Map<String, dynamic>) {
      return (raw['message'] ?? 'Quest claimed!').toString();
    }
    return 'Quest claimed!';
  }

  /// POST /social/challenges/{challengeId}/claim
  Future<String> claimChallenge(String challengeId) async {
    final response = await _dio.post("/social/challenges/$challengeId/claim");
    debugPrint("CLAIM CHALLENGE RESPONSE: ${response.data}");
    final dynamic raw = response.data;
    if (raw is Map<String, dynamic>) {
      return (raw['message'] ?? 'Challenge claimed!').toString();
    }
    return 'Challenge claimed!';
  }

  List<Challenge> _parseChallengeList(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final dynamic data = raw['data'] ?? raw;
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(Challenge.fromJson)
            .toList();
      }
    }
    return [];
  }
}
