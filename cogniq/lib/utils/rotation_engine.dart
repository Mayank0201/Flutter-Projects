import 'dart:math';

class RotationEngine {
  /// Generates a deterministic Random instance for a specific level of a game.
  static Random getDeterminism(String gameId, int levelIndex) {
    // Generate a simple hash combining game ID and level index
    final seed = gameId.hashCode ^ levelIndex;
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
}
