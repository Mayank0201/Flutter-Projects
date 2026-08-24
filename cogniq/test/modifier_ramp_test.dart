import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cogniq/utils/rotation_engine.dart';
import 'package:cogniq/utils/zen_mode.dart';

/// The modifier schedule should climb by breadth first, then intensity: show
/// every modifier on its own, then every distinct pair, then every distinct
/// triple. It used to drop two or three at once at level 30 with no ramp, and
/// nothing at all before that.

const bridgesPool = ['hiddenIslands', 'timer', 'zoom', 'fog'];
const spectrumPool = ['monochrome', 'prism', 'timer', 'moveLimit', 'distractors'];

Set<String> modsAt(String id, int level, List<String> pool) =>
    RotationEngine.getActiveModifiers(
      gameId: id,
      levelIndex: level,
      pool: pool,
      smallGrid: false,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ZenMode.setEnabled(false);
  });

  test('no modifiers before a game\'s start level', () {
    final start = RotationEngine.modifierStartLevel('bridges');
    for (var l = 0; l < start; l++) {
      expect(modsAt('bridges', l, bridgesPool), isEmpty, reason: 'level $l');
    }
    expect(modsAt('bridges', start, bridgesPool), isNotEmpty);
  });

  test('bridges starts far earlier than the old flat level 30', () {
    expect(RotationEngine.modifierStartLevel('bridges'), lessThan(30));
    expect(RotationEngine.modifierStartLevel('bridges'), 10);
  });

  test('intensity ramps 1 -> 2 -> 3 rather than jumping', () {
    final start = RotationEngine.modifierStartLevel('spectrum');
    final counts = <int, Set<int>>{};
    for (var l = start; l < start + 120; l++) {
      final n = modsAt('spectrum', l, spectrumPool).length;
      counts.putIfAbsent(n, () => {}).add(l);
    }
    // Every level carries at least one and never more than three.
    expect(counts.keys.every((k) => k >= 1 && k <= 3), isTrue);
    // Singles come before pairs, pairs before triples.
    final firstSingle = counts[1]!.reduce((a, b) => a < b ? a : b);
    final firstPair = counts[2]!.reduce((a, b) => a < b ? a : b);
    final firstTriple = counts[3]!.reduce((a, b) => a < b ? a : b);
    expect(firstSingle, lessThan(firstPair));
    expect(firstPair, lessThan(firstTriple));
  });

  test('every single modifier is shown before pairs begin', () {
    final start = RotationEngine.modifierStartLevel('spectrum');
    final seen = <String>{};
    for (var l = start; l < start + 40; l++) {
      final m = modsAt('spectrum', l, spectrumPool);
      if (m.length > 1) break;
      seen.addAll(m);
    }
    expect(seen.length, spectrumPool.length,
        reason: 'all ${spectrumPool.length} modifiers should appear solo first');
  });

  test('pairs rotate through distinct combinations without repeating early', () {
    final start = RotationEngine.modifierStartLevel('bridges');
    final pairs = <String>{};
    var found = 0;
    for (var l = start; l < start + 200 && found < 6; l++) {
      final m = modsAt('bridges', l, bridgesPool);
      if (m.length != 2) continue;
      final key = (m.toList()..sort()).join('+');
      expect(pairs.contains(key), isFalse,
          reason: 'pair $key repeated before the set was exhausted (level $l)');
      pairs.add(key);
      found++;
    }
    // 4 modifiers give 6 distinct pairs.
    expect(pairs.length, 6);
  });

  test('selection is deterministic for a given level', () {
    for (var l = 10; l < 60; l++) {
      expect(modsAt('bridges', l, bridgesPool),
          modsAt('bridges', l, bridgesPool));
    }
  });

  test('different games do not all lead with the same modifier', () {
    final a = modsAt('bridges', RotationEngine.modifierStartLevel('bridges'), bridgesPool);
    final b = modsAt('sumstrike', RotationEngine.modifierStartLevel('sumstrike'), bridgesPool);
    expect(a.first == b.first, isFalse,
        reason: 'per-game ordering should differ');
  });

  test('zen mode still suppresses every modifier', () async {
    await ZenMode.setEnabled(true);
    for (var l = 0; l < 120; l++) {
      expect(modsAt('bridges', l, bridgesPool), isEmpty);
    }
    await ZenMode.setEnabled(false);
  });
}
