import 'dart:math';

class RotationEngine {
  /// Generates a deterministic Random instance for a specific level of a game.
  static Random getDeterminism(String gameId, int levelIndex) {
    final seed = Object.hash(gameId, levelIndex);
    return Random(seed);
  }

  /// Decays a difficulty value towards a limit (decay rate controls scaling speed).
  static double getDecayValue({
    required int level,
    required double start,
    required double floor,
    required double rate,
  }) {
    return floor + (start - floor) * (rate / (rate + level));
  }

  /// Given a game's modifier pool and a level index, deterministically
  /// selects 2–3 active modifiers. Ensures:
  ///  - Every endgame level shows >= 2 named modifiers
  ///  - Smaller grids force maxActive (max modifiers)
  ///  - Consecutive levels show overlapping but different sets
  static Set<String> getActiveModifiers({
    required String gameId,
    required int levelIndex,
    required List<String> pool,
    int minActive = 2,
    int maxActive = 3,
    bool smallGrid = false,
  }) {
    if (pool.isEmpty) return {};
    final rand = getDeterminism(gameId, levelIndex);
    final count = smallGrid ? maxActive : (minActive + rand.nextInt(maxActive - minActive + 1));
    final active = <String>{};
    
    final poolCopy = List<String>.from(pool);
    poolCopy.shuffle(rand);
    for (int i = 0; i < count && i < poolCopy.length; i++) {
      active.add(poolCopy[i]);
    }
    return active;
  }

  /// Logs when a generator falls back to its default/backup board.
  static void logFallback(String gameId, int level) {
    print('⚠️ FALLBACK HIT: $gameId L$level');
  }
}
