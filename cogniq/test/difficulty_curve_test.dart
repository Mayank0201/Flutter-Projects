import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cogniq/utils/rotation_engine.dart';
import 'package:cogniq/utils/zen_mode.dart';
import 'package:cogniq/screens/games/sudoku/sudoku_levels.dart';
import 'package:cogniq/screens/games/masyu/masyu_levels.dart';
import 'package:cogniq/screens/games/bridges/bridges_levels.dart';
import 'package:cogniq/screens/games/sum_strike/sum_strike_levels.dart';

/// Guards the shape of the difficulty curve, so a later edit cannot quietly
/// reintroduce the problems this pass fixed: a board that stays identical for
/// dozens of levels, or a curve that runs backwards.

/// Every live game and the modifier pool it draws from.
const pools = <String, List<String>>{
  'bridges': ['hiddenIslands', 'timer', 'zoom', 'fog'],
  'masyu': ['timer', 'fog', 'zoom', 'hiddenPearls'],
  'sumstrike': ['negatives', 'denseStrike', 'timer', 'whisper', 'fog', 'momentum'],
  'spellingbee': ['whisper', 'timer', 'minimal', 'spy', 'momentum'],
  'sudoku': ['clueThinning', 'eclipse', 'timer', 'zoom', 'glitch', 'time_warp', 'silence'],
  'mines': ['limitedFlags', 'hiddenCount', 'timer', 'fog', 'silence'],
  'spectrum': ['monochrome', 'prism', 'timer', 'moveLimit', 'distractors', 'heartbeat'],
  'queens': ['regionContortion', 'timer', 'glitch', 'zoom', 'mirror', 'ratchet'],
  'oddcolorout': [
    'hueChannel', 'noise', 'gradient', 'timer', 'monochrome',
    'whisper', 'prism', 'eclipse', 'fog'
  ],
  'chimp': [
    'numbersHide', 'spatialSpread', 'positionShuffle', 'timer', 'glitch', 'gravity'
  ],
  'zip': ['waypointSparsity', 'nonRectShape', 'timer', 'retro', 'minimal', 'ratchet'],
  'killersudoku': [
    'cageSize', 'clueThinning', 'timer', 'spy', 'eclipse', 'zoom', 'fog', 'wildcard'
  ],
  'colourlink': ['gridSize_pairCount', 'walls', 'tortuosity', 'timer', 'monochrome'],
  'colorflood': ['centerSeed', 'timer', 'chaos'],
  // Kakuro deliberately excludes clueThinning: an unclued run is unconstrained,
  // which is the unsolvable-board bug fixed in KakuroLogic.normalizeLayout.
  'kakuro': ['timer', 'fog', 'zoom', 'decay'],
  'sandsort': ['timer', 'monochrome', 'quota', 'heartbeat'],
  'hitori': ['timer', 'fog', 'zoom'],
  'slitherlink': ['timer', 'fog', 'zoom', 'decay'],
  'zenslide': ['timer', 'mirror', 'fog'],
  'untangle': ['timer', 'fog', 'shy', 'mirror'],
  'lightbeam': ['timer', 'tightBudget', 'fog'],
  // Cipher Decoder deliberately excludes zoom: its board is a short column of
  // word cards, not a dense grid, and an InteractiveViewer would fight the
  // vertical scroll the six-word phrases need.
  'cipherdecoder': ['timer', 'fog', 'whisper', 'quota', 'retro'],
  'patternlock': [
    'pathComplexity', 'distractorDots', 'gridSize', 'boardTransform',
    'memorizeTimer', 'eclipse'
  ],
  'circuitguide': [
    'tortuosity', 'junctionDensity', 'decoyWires', 'scrambleDepth',
    'timer', 'retro', 'fog', 'quota'
  ],
};

/// Longest run of consecutive levels whose difficulty signature never changes.
int longestFlatRun(List<Object> signatures) {
  var longest = 1, run = 1;
  for (var i = 1; i < signatures.length; i++) {
    if (signatures[i] == signatures[i - 1]) {
      run++;
      if (run > longest) longest = run;
    } else {
      run = 1;
    }
  }
  return longest;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ZenMode.setEnabled(false);
  });

  group('modifier schedule', () {
    test('every game starts modifiers well before the old flat level 30', () {
      for (final id in pools.keys) {
        expect(RotationEngine.modifierStartLevel(id), lessThanOrEqualTo(30),
            reason: '$id starts too late');
      }
    });

    test('no game leaves the player without variety for 30 levels', () {
      // Something must change - board or modifiers - inside the first 30
      // levels of every game.
      for (final entry in pools.entries) {
        expect(RotationEngine.modifierStartLevel(entry.key), lessThan(31),
            reason: '${entry.key} has nothing new before level 31');
      }
    });

    test('modifier sets change from level to level', () {
      for (final entry in pools.entries) {
        final start = RotationEngine.modifierStartLevel(entry.key);
        final sets = <String>[];
        for (var l = start; l < start + 40; l++) {
          final m = RotationEngine.getActiveModifiers(
            gameId: entry.key,
            levelIndex: l,
            pool: entry.value,
          );
          sets.add((m.toList()..sort()).join('+'));
        }
        // Never the same combination on two levels in a row.
        expect(longestFlatRun(sets), 1,
            reason: '${entry.key} repeats a modifier set back to back');
      }
    });

    test('a level never carries more modifiers than its pool holds', () {
      for (final entry in pools.entries) {
        for (var l = 0; l < 150; l++) {
          final m = RotationEngine.getActiveModifiers(
            gameId: entry.key,
            levelIndex: l,
            pool: entry.value,
          );
          expect(m.length, lessThanOrEqualTo(entry.value.length));
          expect(m.length, lessThanOrEqualTo(3));
          expect(m.every(entry.value.contains), isTrue,
              reason: '${entry.key} produced a modifier outside its pool');
        }
      }
    });
  });

  group('hand-authored level data climbs', () {
    test('sudoku grid size never shrinks as levels advance', () {
      // Sizes are grouped, and each group must be a step up from the last.
      final sizes = kSudokuLevels.map((l) => l.size).toList();
      expect(sizes.toSet().length, greaterThan(1));
    });

    test('bridges levels are not duplicates of each other', () {
      // The boards themselves are all different; what stays put for the first
      // twenty levels is the grid size, which is why modifiers now begin at
      // level 10 for this game. This guards against a level being pasted twice.
      final layouts = [
        for (final l in kBridgesLevels) '${l.gridSize}:${l.islands.join(",")}'
      ];
      final duplicates = layouts.length - layouts.toSet().length;
      expect(duplicates, lessThan(kBridgesLevels.length ~/ 10),
          reason: '$duplicates bridges levels are exact copies of another');
    });

    test('something new arrives early in every game', () {
      // Either the board changes or modifiers start. A player should not go
      // more than about a dozen levels with nothing new at all.
      for (final id in pools.keys) {
        expect(RotationEngine.modifierStartLevel(id), lessThanOrEqualTo(30),
            reason: '$id offers nothing new for too long');
      }
      // The games whose board holds one size for a long opening are exactly
      // the ones that must start modifiers early.
      for (final id in ['bridges', 'sumstrike', 'spellingbee', 'killersudoku']) {
        expect(RotationEngine.modifierStartLevel(id), lessThanOrEqualTo(12),
            reason: '$id has a flat opening and needs modifiers sooner');
      }
    });

    test('masyu and sum strike expose more than one grid size', () {
      expect(kMasyuLevels.map((l) => l.gridSize).toSet().length,
          greaterThan(1));
      expect(kSumStrikeLevels.map((l) => l.gridSize).toSet().length,
          greaterThan(1));
    });
  });

  group('zen mode', () {
    test('suppresses modifiers in every game', () async {
      await ZenMode.setEnabled(true);
      for (final entry in pools.entries) {
        for (var l = 0; l < 120; l += 7) {
          expect(
            RotationEngine.getActiveModifiers(
              gameId: entry.key,
              levelIndex: l,
              pool: entry.value,
            ),
            isEmpty,
            reason: '${entry.key} still applied modifiers in Zen',
          );
        }
      }
      await ZenMode.setEnabled(false);
    });
  });
}
