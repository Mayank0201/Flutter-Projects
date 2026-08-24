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
// Every game shipped in 1.9, 2.0 and 2.1 was missing from this file until
// 2026-08-22 -- including Hitori, whose 908px overflow is the reason the
// wide-short viewport above exists. A fixed bug with no regression test is a
// bug waiting to come back.
import 'package:cogniq/screens/games/kakuro/kakuro_screen.dart';
import 'package:cogniq/screens/games/sandsort/sandsort_screen.dart';
import 'package:cogniq/screens/games/lightbeam/lightbeam_screen.dart';
import 'package:cogniq/screens/games/hitori/hitori_screen.dart';
import 'package:cogniq/screens/games/zenslide/zenslide_screen.dart';
import 'package:cogniq/screens/games/untangle/untangle_screen.dart';
import 'package:cogniq/screens/games/slitherlink/slitherlink_screen.dart';
import 'package:cogniq/screens/games/cipher_decoder/cipher_decoder_screen.dart';

/// Renders every live game at real phone sizes and fails on any layout
/// overflow. A "RenderFlex overflowed by N pixels" only throws in debug builds
/// -- release quietly clips instead -- so without a test like this the striped
/// overflow bars are invisible to anyone testing a release build on a device.
///
/// The smallest size here is deliberately cramped: a 320x568 window with a
/// large system font is the worst case a real phone presents.

/// Common phone viewports, from a small older device up to a large modern one,
/// **plus one wide-short window**.
///
/// The wide-short entry is load-bearing and was missing until 2026-08-22. Every
/// other viewport here is taller than it is wide, so a board sized as
/// `width * 0.85` always happened to fit vertically and an entire class of bug
/// was invisible to this file by construction. It cost us twice:
///
///  * **Hitori, 2.0** -- overflowed by **908px**, found by eye in a browser.
///  * **Slitherlink, 2.1** -- the board ran off the bottom with the Reset and
///    Check buttons overlapping it, again found only in a browser.
///
/// Both had a green suite. A landscape phone, a tablet, a desktop window and
/// Android split-screen are all wide-short, so this is a real device shape and
/// not a hypothetical. Do not remove this entry to make a test pass -- fix the
/// screen to size itself from *both* axes, the way `hitori_screen.dart` and
/// `slitherlink_screen.dart` now do.
const viewports = <String, Size>{
  'small phone 320x568': Size(320, 568),
  'typical phone 412x915': Size(412, 915),
  'large phone 480x1000': Size(480, 1000),
  'wide-short 1568x696 (landscape / tablet / split screen)': Size(1568, 696),
};

final screens = <String, Widget Function()>{
  'Grid Path': () => const GridPathScreen(),
  'Odd Color Out': () => const OddColorOutScreen(),
  'Chimp Test': () => const ChimpTestScreen(),
  'Star Battle': () => const StarBattleScreen(),
  'Mine Finder': () => const MineFinderScreen(),
  'Spectrum': () => const SpectrumScreen(),
  'Sudoku': () => const SudokuScreen(),
  'Word Hive': () => const WordHiveScreen(),
  'Pearl Loop': () => const MasyuScreen(),
  'Bridges': () => const BridgesScreen(),
  'Sum Strike': () => const SumStrikeScreen(),
  'Pattern Lock': () => const PatternLockScreen(),
  'Colour Link': () => const ColourLinkScreen(),
  'Color Flood': () => const ColorFloodScreen(),
  'Circuit Guide': () => const CircuitGuideScreen(),
  'Killer Sudoku': () => const KillerSudokuScreen(),
  // 1.9
  'Kakuro': () => const KakuroScreen(),
  'Sand Sort': () => const SandSortScreen(),
  // 2.0
  'Light Beam': () => const LightBeamScreen(),
  'Hitori': () => const HitoriScreen(),
  // 2.1
  // 2.2
  'Untangle': () => const UntangleScreen(),
  'Zen Slide': () => const ZenSlideScreen(),
  'Slitherlink': () => const SlitherlinkScreen(),
  // 2.3
  'Cipher Decoder': () => const CipherDecoderScreen(),
};

/// Games that grew a new modifier chip, meter or caption in 2.2, keyed by the
/// saved-level pref key their screen reads. Rendered again below at a level
/// where the rotation is actually running — see the note at the bottom of
/// `main`.
final modifierLevelScreens =
    <String, ({String key, Widget Function() build})>{
  'Word Hive': (key: 'spellingbee', build: () => const WordHiveScreen()),
  'Sum Strike': (key: 'sumstrike', build: () => const SumStrikeScreen()),
  'Kakuro': (key: 'kakuro', build: () => const KakuroScreen()),
  'Slitherlink': (key: 'slitherlink', build: () => const SlitherlinkScreen()),
  'Sand Sort': (key: 'sandsort', build: () => const SandSortScreen()),
  'Spectrum': (key: 'hue', build: () => const SpectrumScreen()),
  'Cipher Decoder': (key: 'cipherdecoder', build: () => const CipherDecoderScreen()),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Never reach for the network in a test; fall back to the bundled font.
  GoogleFonts.config.allowRuntimeFetching = false;

  for (final entry in screens.entries) {
    final name = entry.key;
    final build = entry.value;

    for (final vp in viewports.entries) {
      testWidgets('$name has no layout overflow at ${vp.key}', (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = vp.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final overflows = <String>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (details) {
          final text = details.exceptionAsString();
          if (text.contains('overflowed by')) {
            // Include the offending widget so a failure points at the code to
            // fix rather than just saying "something overflowed".
            final where = details
                .toString()
                .split('\n')
                .firstWhere(
                  (l) => l.contains('The relevant error-causing widget was'),
                  orElse: () => '',
                );
            final widget = details
                .toString()
                .split('\n')
                .skipWhile((l) => !l.contains('error-causing widget'))
                .skip(1)
                .take(1)
                .join()
                .trim();
            overflows.add(
                '${text.split('\n').first}  ${where.isEmpty ? '' : '($widget)'}');
          } else {
            previous?.call(details);
          }
        };

        try {
          await tester.pumpWidget(MaterialApp(home: build()));
          // Let async level loading and the first animations settle.
          for (var i = 0; i < 6; i++) {
            await tester.pump(const Duration(milliseconds: 120));
          }
        } finally {
          // Replacing the tree disposes the screen, which cancels its timers.
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 50));
          FlutterError.onError = previous;
        }

        expect(
          overflows,
          isEmpty,
          reason: '$name overflows at ${vp.key}:\n${overflows.join('\n')}',
        );
      });
    }
  }

  // --------------------------------------------------------------------------
  // The block above boots every game at level 0, where the modifier rotation is
  // switched off — so it renders no modifier chip, caption or meter at all.
  // That is precisely the gap 2.1 fell into: four new modifier chips overflowed
  // their rows, one by 260px, on exactly the levels the modifiers fire, and the
  // suite was green the whole time. This block boots the games that carry a new
  // chip or caption deep enough into the curve that the rotation is running.
  for (final entry in modifierLevelScreens.entries) {
    final name = entry.key;
    final key = entry.value.key;
    final build = entry.value.build;

    for (final vp in viewports.entries) {
      testWidgets('$name has no layout overflow with modifiers at ${vp.key}',
          (tester) async {
        // Deep into the pairs tier, so a level carries two modifiers at once
        // and their captions share a row.
        SharedPreferences.setMockInitialValues({
          'level_$key': 60,
          'hints_$key': 3,
        });
        tester.view.physicalSize = vp.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final overflows = <String>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (details) {
          final text = details.exceptionAsString();
          if (text.contains('overflowed by')) {
            overflows.add(text.split('\n').first);
          } else {
            previous?.call(details);
          }
        };

        try {
          await tester.pumpWidget(MaterialApp(home: build()));
          // Long enough for `heartbeat` to reach its blank phase and for
          // `momentum`/`decay` captions to be laid out.
          for (var i = 0; i < 24; i++) {
            await tester.pump(const Duration(milliseconds: 250));
          }
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 50));
          FlutterError.onError = previous;
        }

        expect(
          overflows,
          isEmpty,
          reason:
              '$name overflows at ${vp.key} with modifiers running:\n'
              '${overflows.join('\n')}',
        );
      });
    }
  }
}
