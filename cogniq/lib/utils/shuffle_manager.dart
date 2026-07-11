import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_info.dart';

class ShuffleManager {
  static const String _key = 'shuffle_mode';

  // Cached state so game screens can read synchronously after first load
  static bool _cachedActive = false;
  static bool _cacheLoaded = false;
  static bool isTransitioning = false;

  static Future<bool> isActive() async {
    if (_cacheLoaded) return _cachedActive;
    final prefs = await SharedPreferences.getInstance();
    _cachedActive = prefs.getBool(_key) ?? false;
    _cacheLoaded = true;
    return _cachedActive;
  }

  /// Synchronous check — only valid after at least one async call has completed.
  static bool get isActiveSync => _cachedActive;

  static Future<bool> toggleShuffle() async {
    final prefs = await SharedPreferences.getInstance();
    final active = prefs.getBool(_key) ?? false;
    final nextState = !active;
    await prefs.setBool(_key, nextState);
    _cachedActive = nextState;
    _cacheLoaded = true;
    return nextState;
  }

  /// Combined check + pick + navigate in a single async chain.
  /// Returns true if shuffle navigation occurred, false otherwise.
  static Future<List<String>> getSelectedGames() async {
    final prefs = await SharedPreferences.getInstance();
    final activeGameIds = kAllGames.where((game) => !game.isStashed).map((g) => g.id).toList();
    final selected = prefs.getStringList('shuffle_enabled_games') ?? activeGameIds;
    return selected.where((id) => activeGameIds.contains(id)).toList();
  }

  static Future<void> setSelectedGames(List<String> gameIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('shuffle_enabled_games', gameIds);
  }

  /// Combined check + pick + navigate in a single async chain.
  /// Returns true if shuffle navigation occurred, false otherwise.
  static Future<bool> tryShuffleNavigate(BuildContext context, String currentGameId) async {
    final prefs = await SharedPreferences.getInstance();
    final active = prefs.getBool(_key) ?? false;
    _cachedActive = active;
    _cacheLoaded = true;

    if (!active) return false;

    // Pick next game using selected games list
    final selectedIds = await getSelectedGames();
    var activeGames = kAllGames.where((game) => !game.isStashed && selectedIds.contains(game.id)).toList();
    if (activeGames.isEmpty) {
      activeGames = kAllGames.where((game) => !game.isStashed).toList();
    }

    final candidates = activeGames.where((game) => game.id != currentGameId).toList();
    if (candidates.isEmpty) return false;

    // Read recently played from same prefs instance
    final recentlyPlayed = prefs.getStringList('recently_played_games') ?? [];

    // Weighted random selection
    final List<double> weights = [];
    double totalWeight = 0.0;
    for (final candidate in candidates) {
      final double weight = recentlyPlayed.contains(candidate.id) ? 1.0 : 2.0;
      weights.add(weight);
      totalWeight += weight;
    }

    final random = Random();
    final double randomVal = random.nextDouble() * totalWeight;
    double runningSum = 0.0;
    GameInfo nextGame = candidates.first;

    for (int i = 0; i < candidates.length; i++) {
      runningSum += weights[i];
      if (randomVal <= runningSum) {
        nextGame = candidates[i];
        break;
      }
    }

    // Navigate
    isTransitioning = true;
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, nextGame.routeName);
    }
    Future.delayed(const Duration(milliseconds: 500), () {
      isTransitioning = false;
    });
    return true;
  }

  /// Legacy methods kept for compatibility
  static Future<GameInfo> pickNextGame(String currentGameId) async {
    final selectedIds = await getSelectedGames();
    var activeGames = kAllGames.where((game) => !game.isStashed && selectedIds.contains(game.id)).toList();
    if (activeGames.isEmpty) {
      activeGames = kAllGames.where((game) => !game.isStashed).toList();
    }

    final candidates = activeGames.where((game) => game.id != currentGameId).toList();
    if (candidates.isEmpty) {
      return kAllGames.firstWhere((game) => game.id == currentGameId);
    }

    final prefs = await SharedPreferences.getInstance();
    final recentlyPlayed = prefs.getStringList('recently_played_games') ?? [];

    final List<double> weights = [];
    double totalWeight = 0.0;
    for (final candidate in candidates) {
      final double weight = recentlyPlayed.contains(candidate.id) ? 1.0 : 2.0;
      weights.add(weight);
      totalWeight += weight;
    }

    final random = Random();
    final double randomVal = random.nextDouble() * totalWeight;
    double runningSum = 0.0;

    for (int i = 0; i < candidates.length; i++) {
      runningSum += weights[i];
      if (randomVal <= runningSum) {
        return candidates[i];
      }
    }

    return candidates.first;
  }

  static void navigateToGame(BuildContext context, GameInfo game) {
    Navigator.pushReplacementNamed(context, game.routeName);
  }

  static Future<void> setInactive() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, false);
    _cachedActive = false;
    _cacheLoaded = true;
  }
}
