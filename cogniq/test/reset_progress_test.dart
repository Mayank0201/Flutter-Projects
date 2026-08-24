import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cogniq/theme/settings_manager.dart';
import 'package:cogniq/utils/prefs_keys.dart';
import 'package:cogniq/utils/zen_mode.dart';

/// "Clear All Saved Progress" is a promise with two halves, and both used to be
/// broken:
///
///  * it must clear *all* progress — Zen keeps a parallel progression, and a
///    half-finished board survives as its own key, so a reset that misses
///    either leaves a stale mid-game board to be restored on top of a level-0
///    counter;
///  * it must clear *only* progress — points, achievements, trail styles and
///    purchases are deliberately kept, so the wipe can never be a wildcard.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Seeds a realistic prefs store: progress in both modes, a saved board in
  /// each mode, and the things a reset must not touch.
  Map<String, Object> seed() => <String, Object>{
        // Challenge progress.
        PrefsKeys.normalGameLevel('sudoku'): 12,
        PrefsKeys.normalClearedCount('sudoku'): 30,
        PrefsKeys.gameHints('sudoku'): 4,
        PrefsKeys.gameStreak('sudoku'): 6,
        PrefsKeys.globalLevelClearedCount: 42,
        PrefsKeys.dailyStreak: 9,
        // Zen progress.
        ZenMode.zenGameLevel('sudoku'): 7,
        ZenMode.zenClearedCount('sudoku'): 15,
        ZenMode.zenClearedCountKey: 21,
        // Mid-game saved boards, one per mode, plus saved Grid Path routes.
        'normal_sudoku_state': '{"board":"partial"}',
        'zen_kakuro_state': '{"board":"partial"}',
        'zip_path_3': '1,2,3',
        'zen_zip_path_3': '4,5,6',
        PrefsKeys.spectrumMidLevelIndex: 5,
        PrefsKeys.spectrumMidLayout: 'abc',
        // Deliberately preserved.
        PrefsKeys.points: 2500,
        PrefsKeys.unlockedAchievements: <String>['first_clear', 'big_board'],
        PrefsKeys.claimedTrailStyles: <String>['comet'],
        PrefsKeys.swipeTrailStyle: 'comet',
        PrefsKeys.adsRemoved: true,
        PrefsKeys.bundleGranted: true,
        PrefsKeys.unlockedTitles: <String>['Novice'],
        PrefsKeys.hapticEnabled: false,
      };

  setUp(() async {
    SharedPreferences.setMockInitialValues(seed());
  });

  test('clears zen progress alongside challenge progress', () async {
    await SettingsNotifier().resetAllProgress();
    final prefs = await SharedPreferences.getInstance();

    expect(prefs.getInt(ZenMode.zenGameLevel('sudoku')), isNull,
        reason: 'zen level survived the reset');
    expect(prefs.getInt(ZenMode.zenClearedCount('sudoku')), isNull);
    expect(prefs.getInt(ZenMode.zenClearedCountKey), isNull);

    expect(prefs.getInt(PrefsKeys.normalGameLevel('sudoku')), isNull);
    expect(prefs.getInt(PrefsKeys.normalClearedCount('sudoku')), isNull);
    expect(prefs.getInt(PrefsKeys.globalLevelClearedCount), isNull);
  });

  test('clears mid-game saved boards in both modes', () async {
    await SettingsNotifier().resetAllProgress();
    final prefs = await SharedPreferences.getInstance();

    // A surviving board here is the actual bug: it would be restored against a
    // level counter that has just been reset to zero.
    expect(prefs.getString('normal_sudoku_state'), isNull);
    expect(prefs.getString('zen_kakuro_state'), isNull);
    expect(prefs.getString('zip_path_3'), isNull);
    expect(prefs.getString('zen_zip_path_3'), isNull);
    expect(prefs.getInt(PrefsKeys.spectrumMidLevelIndex), isNull);
    expect(prefs.getString(PrefsKeys.spectrumMidLayout), isNull);
  });

  test('keeps points, achievements, trails and purchases', () async {
    await SettingsNotifier().resetAllProgress();
    final prefs = await SharedPreferences.getInstance();

    expect(prefs.getInt(PrefsKeys.points), 2500);
    expect(prefs.getStringList(PrefsKeys.unlockedAchievements),
        <String>['first_clear', 'big_board']);
    expect(prefs.getStringList(PrefsKeys.claimedTrailStyles), <String>['comet']);
    expect(prefs.getString(PrefsKeys.swipeTrailStyle), 'comet');
    expect(prefs.getBool(PrefsKeys.adsRemoved), isTrue,
        reason: 'a reset must never revoke a purchase');
    expect(prefs.getBool(PrefsKeys.bundleGranted), isTrue);
    expect(prefs.getStringList(PrefsKeys.unlockedTitles), <String>['Novice']);
    expect(prefs.getBool(PrefsKeys.hapticEnabled), isFalse,
        reason: 'preferences are not progress');
  });
}
