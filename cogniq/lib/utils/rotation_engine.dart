import 'dart:math';
import 'package:flutter/foundation.dart';
import 'zen_mode.dart';

class RotationEngine {
  static int _stableHash(String s) {
    int h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h = (h ^ c) * 0x01000193 & 0x7fffffff;
    }
    return h;
  }

  /// Generates a deterministic Random instance for a specific level of a game.
  static Random getDeterminism(String gameId, int levelIndex) {
    final seed = _stableHash(gameId) ^ (levelIndex * 2654435761 & 0x7fffffff);
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

  // COGNIQ-FIX:mod-start-map
  /// Level at which each game's modifier layer switches on.
  ///
  /// Tuned to each game's board ramp: modifiers begin once the board has taken
  /// its first size step, so fog/zoom/timer have something to act on, and long
  /// before the old global 30 -- which left every game static for the ten
  /// levels between "board stops growing" and "modifiers start".
  ///
  /// Challenge mode ignores this entirely: see _isModActive. Dailies run at
  /// level 1..19 and must still get their rule.
  static const Map<String, int> _modifierStartLevel = {
    // ================= grid puzzles =================
    'bridges': 10,
    'masyu': 10,
    'sumstrike': 12,
    'killersudoku': 12,
    'spellingbee': 12,
    'slitherlink': 12,
    'hitori': 12,
    'kakuro': 12,
    'oddcolorout': 20,
    'oddcolor': 20,
    'sudoku': 20,
    'mines': 30,
    'minesweeper': 30,
    'patternlock': 30,
    'pattern_lock': 30,
    'queens': 30,
    'zip': 30,
    'colorflood': 30,
    'color_flood': 30,
    // Chimp's 30-entry table reaches its hardest board (9 wide, 15 numbers)
    // at index 24 and holds it through 29, so modifiers begin at 24 to avoid
    // 6 dead levels.
    'chimp': 24,
    'circuitguide': 14,
    'circuit_guide': 14,
    'cipherdecoder': 20,
    'sandsort': 15,
    'lightbeam': 15,
    'untangle': 15,
    'zenslide': 15,
    'hue': 15,
    'spectrum': 15,
    'colourlink': 15,
    'colour_link': 15,
    'nurikabe': 15,
    'skyscrapers': 15,
    'sequence': 3,
    'numbermemory': 3,
    'memory': 5,
    'orbit': 5,
    'onestroke': 5,
    'wordle': 8,
    'weaver': 8,
    'crossclimb': 8,
    'wordbuilder': 8,
    'hangman': 8,
    'flagle': 8,
  };

  /// Ids that intentionally have no modifier layer.
  static const Set<String> kNoModifierGames = {'reaction'};

  static int? modifierStartLevelRaw(String gameId) => _modifierStartLevel[gameId];

  /// The level at which a game starts showing modifiers.
  static int modifierStartLevel(String gameId) => _modifierStartLevel[gameId] ?? 15;

  /// Whether [levelIndex] of [gameId] should carry modifiers at all.
  static bool hasModifiers(String gameId, int levelIndex) =>
      !ZenMode.isEnabled && levelIndex >= modifierStartLevel(gameId);

  static int _binomial(int n, int k) {
    if (k < 0 || k > n) return 0;
    var r = 1;
    for (var i = 1; i <= k; i++) {
      r = r * (n - k + i) ~/ i;
    }
    return r;
  }

  /// All [k]-sized combinations of [n] indices, in lexicographic order.
  static List<List<int>> _combinations(int n, int k) {
    final out = <List<int>>[];
    final cur = List<int>.filled(k, 0);
    void rec(int start, int depth) {
      if (depth == k) {
        out.add(List<int>.from(cur));
        return;
      }
      for (var i = start; i < n; i++) {
        cur[depth] = i;
        rec(i + 1, depth + 1);
      }
    }

    if (k > 0 && k <= n) rec(0, 0);
    return out;
  }

  /// Deterministically selects the modifiers active on a level.
  ///
  /// Difficulty climbs by *breadth first, then intensity*: the game shows one
  /// modifier at a time until every one has been seen, then works through every
  /// distinct pair, then every distinct triple. Combinations are enumerated
  /// rather than sampled, so a player never sees the same pairing twice until
  /// the whole set has been used, and the step from one modifier to two to
  /// three is gradual instead of a jump from none to three at level 30.
  static Set<String> getActiveModifiers({
    required String gameId,
    required int levelIndex,
    required List<String> pool,
    int minActive = 2,
    int maxActive = 3,
    bool smallGrid = false,
  }) {
    // Zen Mode is defined as "the puzzle, nothing else". Every game routes its
    // endgame modifiers through here, so suppressing them at this one point
    // covers the whole catalogue.
    if (ZenMode.isEnabled) return {};
    if (pool.isEmpty) return {};

    final start = modifierStartLevel(gameId);
    if (levelIndex < start) return {};

    final p = pool.length;

    // Give each game its own stable ordering so they do not all lead with the
    // same modifier.
    final ordered = List<String>.from(pool)
      ..shuffle(Random(_stableHash(gameId)));

    // Each tier runs long enough to feel like a phase, but never shorter than
    // the number of distinct combinations it has to get through.
    final singlesSpan = max(p, 10);
    final pairsSpan = max(_binomial(p, 2), 35);

    var offset = levelIndex - start;
    int k;
    if (offset < singlesSpan) {
      k = 1;
    } else {
      offset -= singlesSpan;
      if (offset < pairsSpan) {
        k = 2;
      } else {
        offset -= pairsSpan;
        k = 3;
      }
    }

    // `smallGrid` used to force the maximum number of modifiers, on the logic
    // that a small board late in the game is too easy. That reasoning does not
    // hold now that modifiers begin around level 10-12, where a small board
    // simply means an early level -- piling three modifiers onto a 4x4 makes
    // the first taste of them far harsher than the last. Intensity is governed
    // by the level ramp alone.
    k = k.clamp(1, min(maxActive, p));
    if (k < minActive && levelIndex >= start + singlesSpan + pairsSpan) {
      k = min(minActive, p);
    }

    final combos = _combinations(p, k);
    if (combos.isEmpty) return {ordered.first};

    final combo = combos[offset % combos.length];
    return {for (final i in combo) ordered[i]};
  }

  /// Logs when a generator falls back to its default/backup board.
  static void logFallback(String gameId, int level) {
    debugPrint('⚠️ FALLBACK HIT: $gameId L$level');
  }
}
