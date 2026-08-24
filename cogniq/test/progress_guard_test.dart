import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cogniq/utils/progress_guard.dart';
import 'package:cogniq/utils/prefs_keys.dart';
import 'package:cogniq/utils/zen_mode.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ZenMode.setEnabled(false);
  });

  Future<int?> saved(String gameId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(PrefsKeys.gameLevel(gameId));
  }

  group('progress only moves forward', () {
    test('a higher level is written', () async {
      await ProgressGuard.saveLevel('queens', 12, isDaily: false);
      expect(await saved('queens'), 12);
    });

    // The reported bug: jump back to level 3, clear it, and the saved level 80
    // was overwritten with 4.
    test('replaying an earlier level does not downgrade progress', () async {
      await ProgressGuard.saveLevel('queens', 80, isDaily: false);
      await ProgressGuard.saveLevel('queens', 4, isDaily: false);
      expect(await saved('queens'), 80);
    });

    test('saving the same level again is a no-op', () async {
      await ProgressGuard.saveLevel('sumstrike', 30, isDaily: false);
      await ProgressGuard.saveLevel('sumstrike', 30, isDaily: false);
      expect(await saved('sumstrike'), 30);
    });
  });

  group('daily challenges never touch real progress', () {
    test('a daily clear does not write the challenge level', () async {
      await ProgressGuard.saveLevel('queens', 80, isDaily: false);
      // A daily challenge for this game sits at level 5.
      await ProgressGuard.saveLevel('queens', 6, isDaily: true);
      expect(await saved('queens'), 80);
    });

    test('a daily clear cannot seed progress from nothing', () async {
      await ProgressGuard.saveLevel('colour_link', 6, isDaily: true);
      expect(await saved('colour_link'), isNull);
    });
  });

  group('zen progress is kept separate from challenge progress', () {
    test('zen clears do not advance the challenge level', () async {
      await ProgressGuard.saveLevel('sudoku', 40, isDaily: false);

      await ZenMode.setEnabled(true);
      await ProgressGuard.saveLevel('sudoku', 3, isDaily: false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(PrefsKeys.normalGameLevel('sudoku')), 40);
      expect(prefs.getInt(ZenMode.zenGameLevel('sudoku')), 3);
    });

    test('challenge progress is untouched by a long zen run', () async {
      await ProgressGuard.saveLevel('sudoku', 40, isDaily: false);

      await ZenMode.setEnabled(true);
      for (var i = 1; i <= 60; i++) {
        await ProgressGuard.saveLevel('sudoku', i, isDaily: false);
      }
      await ZenMode.setEnabled(false);

      expect(await saved('sudoku'), 40);
    });

    test('switching back to challenge reads the challenge level', () async {
      await ProgressGuard.saveLevel('queens', 25, isDaily: false);
      await ZenMode.setEnabled(true);
      await ProgressGuard.saveLevel('queens', 2, isDaily: false);
      await ZenMode.setEnabled(false);
      expect(await saved('queens'), 25);
    });
  });
}
