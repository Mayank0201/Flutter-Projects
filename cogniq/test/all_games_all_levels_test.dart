import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cogniq/screens/games/grid_path/grid_path_screen.dart';
import 'package:cogniq/screens/games/odd_color_out/odd_color_out_screen.dart';
import 'package:cogniq/screens/games/chimp_test/chimp_test_screen.dart';
import 'package:cogniq/screens/games/star_battle/star_battle_screen.dart';
import 'package:cogniq/screens/games/mine_finder/mine_finder_screen.dart';
import 'package:cogniq/screens/games/spectrum/spectrum_screen.dart';
import 'package:cogniq/screens/games/sudoku/sudoku_screen.dart';
import 'package:cogniq/screens/games/word_hive/word_hive_screen.dart';
import 'package:cogniq/screens/games/masyu/masyu_screen.dart';
import 'package:cogniq/screens/games/bridges/bridges_screen.dart';
import 'package:cogniq/screens/games/sum_strike/sum_strike_screen.dart';
import 'package:cogniq/screens/games/pattern_lock/pattern_lock_screen.dart';
import 'package:cogniq/screens/games/colour_link/colour_link_screen.dart';
import 'package:cogniq/screens/games/color_flood/color_flood_screen.dart';
import 'package:cogniq/screens/games/circuit_guide/circuit_guide_screen.dart';
import 'package:cogniq/screens/games/killer_sudoku/killer_sudoku_screen.dart';
import 'package:cogniq/screens/games/kakuro/kakuro_screen.dart';
import 'package:cogniq/screens/games/sandsort/sandsort_screen.dart';
import 'package:cogniq/screens/games/hitori/hitori_screen.dart';
import 'package:cogniq/screens/games/lightbeam/lightbeam_screen.dart';
import 'package:cogniq/screens/games/slitherlink/slitherlink_screen.dart';
import 'package:cogniq/screens/games/zenslide/zenslide_screen.dart';
import 'package:cogniq/screens/games/untangle/untangle_screen.dart';
import 'package:cogniq/screens/games/cipher_decoder/cipher_decoder_screen.dart';

/// Boots every live game at every stage of its difficulty curve and fails on
/// any crash, failed assertion or layout overflow.
///
/// The level values deliberately straddle the modifier schedule: before
/// modifiers begin, during the one-at-a-time tier, during pairs, and deep into
/// triples. Between them these cases exercise each game's board generation,
/// solver and every modifier its pool can produce.

/// gameId used for the saved-level key -> screen builder.
final games = <String, ({String key, Widget Function() build})>{
  'Grid Path': (key: 'zip', build: () => const GridPathScreen()),
  'Odd Color Out': (key: 'oddcolor', build: () => const OddColorOutScreen()),
  'Chimp Test': (key: 'chimp', build: () => const ChimpTestScreen()),
  'Star Battle': (key: 'queens', build: () => const StarBattleScreen()),
  'Mine Finder': (key: 'minesweeper', build: () => const MineFinderScreen()),
  'Spectrum': (key: 'hue', build: () => const SpectrumScreen()),
  'Sudoku': (key: 'sudoku', build: () => const SudokuScreen()),
  'Word Hive': (key: 'spellingbee', build: () => const WordHiveScreen()),
  'Pearl Loop': (key: 'masyu', build: () => const MasyuScreen()),
  'Bridges': (key: 'bridges', build: () => const BridgesScreen()),
  'Sum Strike': (key: 'sumstrike', build: () => const SumStrikeScreen()),
  'Pattern Lock': (key: 'pattern_lock', build: () => const PatternLockScreen()),
  'Colour Link': (key: 'colour_link', build: () => const ColourLinkScreen()),
  'Color Flood': (key: 'color_flood', build: () => const ColorFloodScreen()),
  'Circuit Guide': (key: 'circuit_guide', build: () => const CircuitGuideScreen()),
  'Killer Sudoku': (key: 'killersudoku', build: () => const KillerSudokuScreen()),
  'Kakuro': (key: 'kakuro', build: () => const KakuroScreen()),
  'Sand Sort': (key: 'sandsort', build: () => const SandSortScreen()),
  'Hitori': (key: 'hitori', build: () => const HitoriScreen()),
  'Light Beam': (key: 'lightbeam', build: () => const LightBeamScreen()),
  'Untangle': (key: 'untangle', build: () => const UntangleScreen()),
  'Zen Slide': (key: 'zenslide', build: () => const ZenSlideScreen()),
  'Slitherlink': (key: 'slitherlink', build: () => const SlitherlinkScreen()),
  // 2.3 revival.
  'Cipher Decoder': (key: 'cipherdecoder', build: () => const CipherDecoderScreen()),
};

/// Straddles every tier of the modifier schedule.
const levels = [0, 5, 11, 14, 20, 30, 45, 60, 90, 120];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  for (final entry in games.entries) {
    final name = entry.key;
    final key = entry.value.key;
    final build = entry.value.build;

    testWidgets('$name runs at every stage of its curve', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final failures = <String>[];

      for (final level in levels) {
        SharedPreferences.setMockInitialValues({
          'level_$key': level,
          'hints_$key': 3,
        });

        final problems = <String>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (details) {
          problems.add(details.exceptionAsString().split('\n').first);
        };

        try {
          await tester.pumpWidget(MaterialApp(home: build()));
          for (var i = 0; i < 8; i++) {
            await tester.pump(const Duration(milliseconds: 120));
          }
        } catch (e) {
          problems.add('threw: $e');
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 50));
          FlutterError.onError = previous;
        }

        for (final p in problems) {
          failures.add('  level $level: $p');
        }
      }

      expect(failures, isEmpty,
          reason: '$name failed at these levels:\n${failures.join('\n')}');
    });
  }
}
