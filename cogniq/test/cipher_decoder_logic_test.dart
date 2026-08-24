import 'package:flutter_test/flutter_test.dart';
import 'package:cogniq/screens/games/cipher_decoder/cipher_decoder_logic.dart';
import 'package:cogniq/screens/games/cipher_decoder/cipher_decoder_screen.dart'
    show kCipherDecoderModifierPool;
import 'package:cogniq/utils/rotation_engine.dart';

/// Regression tests for the Cipher Decoder redesign (release 2.3, §4.5 D).
///
/// Each group below answers a defect **measured** in the stashed build by
/// exhaustively enumerating every shift its RNG could produce — 25 outcomes for
/// the uniform and progressive bands, 600 for vowel/consonant:
///
///  * uniform shift, levels 1–5      : 0 / 125 unsolvable   (0.0%)
///  * vowel/consonant, levels 6–12   : 3096 / 4200          (73.7%)
///  * progressive per word, level 13+: 350 / 350            (100.0%)
///  * 4–10 of 25 base shifts rendered at least one word in plaintext
///  * 12 of 21 short-phrase corpus entries were unreachable at any level
///
/// The whole point of the dial redesign is that none of those can recur, so
/// every one of them is asserted here rather than described.
void main() {
  /// Straddles every band of the ladder plus a long stretch of the plateau.
  /// Re-pinned when the ladder was compressed from 45 levels to 20: the old
  /// list sampled bands that no longer exist at those indices.
  const levels = [
    0, 1, 2, 3, 4, 5, 6, 8, 10, 11, 12, 13, 15, 16, 17, 18, 19,
    20, 21, 24, 26, 29, 30, 37, 39, 40, 48, 60, 77, 90, 120, 199, 400,
  ];

  CipherBoard build(int level) =>
      CipherLogic.generate(level, RotationEngine.getDeterminism('cipherdecoder', level));

  group('primitives', () {
    test('rotate is a Caesar shift and wraps', () {
      expect(CipherLogic.rotate('ABC', 1), 'BCD');
      expect(CipherLogic.rotate('XYZ', 3), 'ABC');
      expect(CipherLogic.rotate('HELLO', 0), 'HELLO');
      expect(CipherLogic.rotate('HELLO', 26), 'HELLO');
    });

    test('a word is decoded by exactly one dial value', () {
      const plain = 'CIPHER';
      final cipher = CipherLogic.rotate(plain, 7);
      final hits = [
        for (var d = 0; d < 26; d++)
          if (CipherLogic.rotate(cipher, d) == plain) d
      ];
      expect(hits, [19]); // (26 - 7) % 26
    });

    test('fitsLinearRule is vacuous below three dials and real above', () {
      expect(CipherLogic.fitsLinearRule([5]), isTrue);
      expect(CipherLogic.fitsLinearRule([5, 19]), isTrue);
      expect(CipherLogic.fitsLinearRule([5, 7, 9]), isTrue);
      expect(CipherLogic.fitsLinearRule([25, 1, 3]), isTrue); // wraps mod 26
      expect(CipherLogic.fitsLinearRule([5, 7, 12]), isFalse);
    });
  });

  group('corpus', () {
    test('is 100+ phrases, replacing the 14 the stashed build shipped', () {
      expect(CipherLogic.corpus.length, greaterThanOrEqualTo(100));
    });

    test('has no duplicates', () {
      expect(CipherLogic.corpus.toSet().length, CipherLogic.corpus.length);
    });

    test('every tier holds phrases of exactly its word count', () {
      for (final e in {
        2: CipherLogic.tierA,
        3: CipherLogic.tierB,
        4: CipherLogic.tierC,
        5: CipherLogic.tierD,
        6: CipherLogic.tierE,
      }.entries) {
        for (final p in e.value) {
          expect(p.split(' ').length, e.key, reason: '"$p" in tier ${e.key}');
        }
      }
    });

    test('phrases are plain uppercase A-Z and spaces', () {
      final ok = RegExp(r'^[A-Z]+( [A-Z]+)*$');
      for (final p in CipherLogic.corpus) {
        expect(ok.hasMatch(p), isTrue, reason: '"$p"');
      }
    });

    test('no single-letter words anywhere', () {
      // A one-letter word under a free per-word shift is a 26-way coin flip.
      for (final p in CipherLogic.corpus) {
        for (final w in p.split(' ')) {
          expect(w.length, greaterThanOrEqualTo(2), reason: '"$p"');
        }
      }
    });

    test('the tiers free mode draws from carry no two-letter words', () {
      // Under CipherMode.free each word stands alone, so a two-letter word
      // would be guesswork rather than deduction.
      for (final tier in [CipherLogic.tierA, CipherLogic.tierB, CipherLogic.tierC]) {
        for (final p in tier) {
          for (final w in p.split(' ')) {
            expect(w.length, greaterThanOrEqualTo(3), reason: '"$p"');
          }
        }
      }
    });

    test('every corpus entry is reachable — no dead data', () {
      // The stashed build left 12 of its 21 short-phrase entries unreachable at
      // any level, because a six-level band indexed a much longer list.
      final seen = <String>{};
      for (var level = 0; level < 3000; level++) {
        seen.add(build(level).plainPhrase);
      }
      final dead = CipherLogic.corpus.where((p) => !seen.contains(p)).toList();
      expect(dead, isEmpty, reason: 'unreachable phrases: $dead');
      expect(seen.length, CipherLogic.corpus.length);
    });
  });

  group('solvability', () {
    test('every level on the ladder produces a solvable board', () {
      for (var level = 0; level < 600; level++) {
        final a = CipherLogic.analyze(build(level));
        expect(a.solvable, isTrue, reason: 'level $level');
      }
    });

    test('no word is ever rendered in plaintext', () {
      // (base + w) % 26 == 0 put a word on screen already decoded on 4 to 10 of
      // the stashed build's 25 base shifts, on all 14 of its phrases.
      for (var level = 0; level < 600; level++) {
        final board = build(level);
        final a = CipherLogic.analyze(board);
        expect(a.leaksPlaintext, isFalse, reason: 'level $level');
        expect(board.shifts.any((s) => s % 26 == 0), isFalse,
            reason: 'level $level');
        for (var w = 0; w < board.wordCount; w++) {
          expect(board.cipherWords[w], isNot(board.plainWords[w]),
              reason: 'level $level word $w');
        }
      }
    });

    test('a fresh board starts with no dial already correct', () {
      for (final level in levels) {
        expect(build(level).solutionDials.any((d) => d == 0), isFalse,
            reason: 'level $level');
      }
    });

    test('setting every dial to its answer reconstructs the phrase', () {
      for (final level in levels) {
        final board = build(level);
        final dials = board.solutionDials;
        final read = [
          for (var w = 0; w < board.wordCount; w++) board.wordAt(w, dials[w])
        ].join(' ');
        expect(read, board.plainPhrase, reason: 'level $level');
      }
    });

    test('generation never falls back', () {
      for (var level = 0; level < 600; level++) {
        expect(build(level).usedFallback, isFalse, reason: 'level $level');
      }
    });

    test('every board passes its own profile gate', () {
      for (var level = 0; level < 600; level++) {
        expect(CipherLogic.verify(build(level), CipherLogic.profileFor(level)),
            isTrue,
            reason: 'level $level');
      }
    });
  });

  group('determinism', () {
    test('the same level yields the same board every time', () {
      for (final level in levels) {
        final a = build(level);
        final b = build(level);
        expect(a.cipherPhrase, b.cipherPhrase, reason: 'level $level');
        expect(a.plainPhrase, b.plainPhrase);
        expect(a.shifts, b.shifts);
        expect(a.mode, b.mode);
        expect(a.statedStep, b.statedStep);
      }
    });

    test('different levels do not all collapse onto one board', () {
      final seen = <String>{};
      for (var level = 0; level < 60; level++) {
        seen.add(build(level).cipherPhrase);
      }
      expect(seen.length, greaterThan(50));
    });
  });

  group('the rule the banner states is the rule the board uses', () {
    test('a stated step is only present in statedProgressive, and is honest', () {
      for (var level = 0; level < 300; level++) {
        final board = build(level);
        if (board.mode == CipherMode.statedProgressive) {
          expect(board.statedStep, isNotNull, reason: 'level $level');
          for (var w = 0; w < board.wordCount; w++) {
            expect(board.shifts[w],
                (board.shifts[0] + board.statedStep! * w) % 26,
                reason: 'level $level word $w');
          }
        } else {
          expect(board.statedStep, isNull, reason: 'level $level');
        }
      }
    });

    test('a hidden rule is never printed', () {
      for (var level = 0; level < 300; level++) {
        final board = build(level);
        if (board.mode == CipherMode.unstatedProgressive) {
          final label = CipherLogic.ruleLabel(board);
          for (var step = 1; step <= 25; step++) {
            expect(label.contains('$step'), isFalse,
                reason: 'level $level leaks its step in "$label"');
          }
        }
      }
    });

    test('free boards really are free — the dials fit no rule', () {
      for (var level = 0; level < 300; level++) {
        final board = build(level);
        if (board.mode != CipherMode.free) continue;
        final a = CipherLogic.analyze(board);
        expect(a.linearRuleFits, isFalse, reason: 'level $level');
        expect(a.independentUnknowns, board.wordCount, reason: 'level $level');
      }
    });
  });

  group('difficulty, measured on generated boards', () {
    /// The bands of the compressed ladder, as (first, last) 0-based levels.
    /// Re-pinned from the 45-level draft (0-5 / 6-15 / 16-22 / 23-29 / 30-36 /
    /// 37-43); the bands themselves are unchanged in kind, only in length.
    const bands = <String, List<int>>{
      'global, 2 words': [0, 2],
      'stated rule, 3 words': [3, 5],
      'hidden rule forwards, 4 words': [6, 10],
      'hidden rule backwards, 5 words': [11, 12],
      'free shifts, 3 words': [13, 16],
      'free shifts, 4 words': [17, 19],
    };

    /// Mean measured difficulty over a level range. Read off the board by the
    /// brute-force analyzer, never off the knob that produced it.
    double meanScore(int from, int to) {
      var sum = 0;
      for (var l = from; l <= to; l++) {
        sum += CipherLogic.analyze(build(l)).difficultyScore;
      }
      return sum / (to - from + 1);
    }

    test('the bands are exactly the levels below the cap', () {
      expect(bands.values.first.first, 0);
      expect(bands.values.last.last, kHardestFairLevelIndex - 1);
      var next = 0;
      for (final b in bands.values) {
        expect(b.first, next, reason: 'bands must not overlap or gap');
        next = b.last + 1;
      }
    });

    test('each band is measurably harder than the one before it', () {
      double? previous;
      for (final e in bands.entries) {
        final m = meanScore(e.value[0], e.value[1]);
        if (previous != null) {
          expect(m, greaterThan(previous), reason: '${e.key} is not a step up');
        }
        previous = m;
      }
    });

    test('no level in a band is easier than any level in an earlier one', () {
      // Stronger than the means above, and the assertion that actually rules out
      // a curve that runs backwards: a band's *floor* has to clear the previous
      // band's *ceiling*, so difficulty is non-decreasing across every level
      // pair on the ladder, not merely on average. All read off generated
      // boards by the brute-force analyzer.
      int? previousCeiling;
      String? previousName;
      for (final e in bands.entries) {
        final scores = [
          for (var l = e.value[0]; l <= e.value[1]; l++)
            CipherLogic.analyze(build(l)).difficultyScore
        ]..sort();
        if (previousCeiling != null) {
          expect(scores.first, greaterThan(previousCeiling),
              reason: '${e.key} dips below $previousName');
        }
        previousCeiling = scores.last;
        previousName = e.key;
      }
    });

    test('the measured unknown count never falls as levels advance', () {
      var previous = 0;
      for (var l = 0; l < kHardestFairLevelIndex; l++) {
        final u = CipherLogic.analyze(build(l)).independentUnknowns;
        expect(u, greaterThanOrEqualTo(previous), reason: 'level $l');
        previous = u;
      }
    });

    test('unknown counts follow the owner ladder', () {
      // Everything up to the free bands hangs on a single deduction.
      for (var l = 0; l < 13; l++) {
        expect(CipherLogic.analyze(build(l)).independentUnknowns, 1,
            reason: 'level $l should hang on one deduction');
      }
      for (var l = 13; l < kHardestFairLevelIndex; l++) {
        final a = CipherLogic.analyze(build(l));
        expect(a.independentUnknowns, a.wordCount, reason: 'level $l');
        expect(a.independentUnknowns, greaterThanOrEqualTo(3));
      }
    });

    test('word count grows and then stops growing', () {
      expect(build(0).wordCount, 2); // global
      expect(build(4).wordCount, 3); // stated rule
      expect(build(8).wordCount, 4); // hidden rule
      expect(build(12).wordCount, 5); // hidden rule, longer phrase
      // The free bands restart the bulk at 3 words, because going from one
      // unknown to three is the jump; the word count is not.
      expect(build(14).wordCount, 3);
      expect(build(18).wordCount, 4);
    });

    test('the hidden rule teaches one direction, then the other', () {
      // Measured off the dials the analyzer recovers, not off the step list the
      // generator was handed. A dial step of s means a cipher step of 26-s.
      int cipherStep(int level) {
        final d = CipherLogic.analyze(build(level)).dials;
        final dialStep = ((d[1] - d[0]) % 26 + 26) % 26;
        return (26 - dialStep) % 26;
      }

      for (var l = 6; l <= 10; l++) {
        expect(cipherStep(l), inInclusiveRange(1, 5),
            reason: 'level $l must introduce the hidden rule going forwards');
      }
      for (var l = 11; l <= 12; l++) {
        expect(cipherStep(l), inInclusiveRange(21, 25),
            reason: 'level $l must be where the rule first runs backwards');
      }
    });
  });

  group('the ladder cap cannot move silently', () {
    test('the declared caps are the ones this suite was written against', () {
      // Re-pinned from 45/44 when the ladder was compressed. The caps on words
      // and unknowns are unchanged and must stay that way.
      expect(kHardestFairLevelShown, 21);
      expect(kHardestFairLevelIndex, 20);
      expect(kMaxWordsPerPuzzle, 6);
      expect(kMaxIndependentUnknowns, 4);
    });

    test('the ladder plateaus inside the window the project rule allows', () {
      // Every other game in the project plateaus around level 12 and hands the
      // curve to modifiers; difficulty_curve_test.dart holds every game to
      // "something new inside 30 levels". A structural ladder still adding
      // unknowns past that would put modifiers on top of a climbing curve.
      expect(kHardestFairLevelIndex, lessThan(31));
    });

    test('nothing past the cap exceeds the caps', () {
      for (var level = 0; level < 1200; level++) {
        final a = CipherLogic.analyze(build(level));
        expect(a.wordCount, lessThanOrEqualTo(kMaxWordsPerPuzzle),
            reason: 'level $level');
        expect(a.independentUnknowns, lessThanOrEqualTo(kMaxIndependentUnknowns),
            reason: 'level $level');
      }
    });

    test('past the cap the ladder cycles a fixed schedule', () {
      // Difficulty past kHardestFairLevelIndex must come from modifiers, not
      // from more words to scan.
      const period = 10;
      for (var level = kHardestFairLevelIndex; level < 800; level++) {
        expect(CipherLogic.profileFor(level),
            CipherLogic.profileFor(level + period),
            reason: 'level $level');
      }
    });

    test('every mode is still reachable past the cap', () {
      final modes = <CipherMode>{};
      for (var level = kHardestFairLevelIndex; level < kHardestFairLevelIndex + 40; level++) {
        modes.add(build(level).mode);
      }
      expect(modes, CipherMode.values.toSet());
    });

    test('the plateau never gets harder than the ladder it replaces', () {
      final ladderPeak = [
        for (var l = 0; l < kHardestFairLevelIndex; l++)
          CipherLogic.analyze(build(l)).independentUnknowns
      ].reduce((a, b) => a > b ? a : b);
      expect(ladderPeak, kMaxIndependentUnknowns);
      for (var l = kHardestFairLevelIndex; l < 1200; l++) {
        expect(CipherLogic.analyze(build(l)).independentUnknowns,
            lessThanOrEqualTo(ladderPeak),
            reason: 'level $l is past the cap and harder than the ladder ever '
                'got — difficulty there must come from modifiers');
      }
    });

    test('each plateau cycle walks the whole ladder in miniature', () {
      // The schedule is ordered easiest-to-hardest, so difficulty inside a cycle
      // is strictly non-decreasing. Measured on generated boards over 120
      // consecutive cycles, which is what stops the schedule being re-ordered
      // back into something that runs downhill four times per cycle.
      for (var c = 0; c < 120; c++) {
        final base = kHardestFairLevelIndex + c * 10;
        for (var slot = 1; slot < 10; slot++) {
          final previous =
              CipherLogic.analyze(build(base + slot - 1)).difficultyScore;
          final current = CipherLogic.analyze(build(base + slot)).difficultyScore;
          expect(current, greaterThan(previous),
              reason: 'cycle $c slot $slot (level ${base + slot}) is not a step '
                  'up from the slot before it');
        }
      }
    });
  });

  group('hints and quota can never strand a player', () {
    test('every board is hintable, because every board is solvable', () {
      // The stashed build spent a hint (and BuyHintsDialog sold more) on boards
      // that were mathematically impossible. The hint path now refuses to spend
      // on an unsolvable board; this asserts that branch is unreachable.
      for (var level = 0; level < 600; level++) {
        expect(CipherLogic.analyze(build(level)).solvable, isTrue,
            reason: 'level $level');
      }
    });

    test('the quota budget always covers a full scan plus the setup clicks', () {
      for (var level = 0; level < 600; level++) {
        final board = build(level);
        final unknowns = CipherLogic.analyze(board).independentUnknowns;
        expect(CipherLogic.fairTurnBudget(board),
            greaterThan(26 * unknowns + board.minimumTurns),
            reason: 'level $level');
      }
    });

    test('minimumTurns is the shorter way round each dial', () {
      for (final level in levels) {
        final board = build(level);
        var expected = 0;
        for (final d in board.solutionDials) {
          expected += d <= 13 ? d : 26 - d;
        }
        expect(board.minimumTurns, expected);
        expect(board.minimumTurns, lessThanOrEqualTo(13 * board.wordCount));
      }
    });
  });

  group('modifier pool', () {
    test('has enough entries for the rotation to stay varied', () {
      expect(kCipherDecoderModifierPool.length, greaterThanOrEqualTo(4));
      expect(kCipherDecoderModifierPool.toSet().length,
          kCipherDecoderModifierPool.length);
    });

    test('starts within the window difficulty_curve_test allows', () {
      expect(RotationEngine.modifierStartLevel('cipherdecoder'),
          lessThanOrEqualTo(30));
    });

    test('starts on the level the structural ladder stops climbing', () {
      // The whole point of compressing the ladder. Before this level something
      // structural changes every two to five levels, so modifiers would be
      // stacking on a curve that is still adding unknowns; from this level the
      // schedule only cycles, so modifiers are the only climb left. Moving
      // either number without the other fails here.
      expect(RotationEngine.modifierStartLevel('cipherdecoder'),
          kHardestFairLevelIndex);
    });

    test('no level below the cap carries modifiers, every level above does', () {
      for (var l = 0; l < kHardestFairLevelIndex; l++) {
        expect(RotationEngine.hasModifiers('cipherdecoder', l), isFalse,
            reason: 'level $l is still teaching structure');
      }
      for (var l = kHardestFairLevelIndex; l < 200; l++) {
        expect(RotationEngine.hasModifiers('cipherdecoder', l), isTrue,
            reason: 'level $l has no structural climb left to lean on');
      }
    });

    test('never shows the same set twice in a row', () {
      final start = RotationEngine.modifierStartLevel('cipherdecoder');
      String? previous;
      for (var l = start; l <= start + 40; l++) {
        final set = (RotationEngine.getActiveModifiers(
          gameId: 'cipherdecoder',
          levelIndex: l,
          pool: kCipherDecoderModifierPool,
          minActive: 1,
          maxActive: 2,
        ).toList()
              ..sort())
            .join(',');
        expect(set, isNot(previous), reason: 'level $l repeats "$set"');
        previous = set;
      }
    });
  });

  group('performance', () {
    test('a level generates well inside a frame budget', () {
      final sw = Stopwatch()..start();
      for (var level = 0; level < 500; level++) {
        build(level);
      }
      sw.stop();
      // 500 boards; anything approaching a frame each would be a stall.
      expect(sw.elapsedMilliseconds, lessThan(1000),
          reason: '500 boards took ${sw.elapsedMilliseconds}ms');
    });

    test('analysis is cheap enough to run on every generation', () {
      final boards = [for (var l = 0; l < 500; l++) build(l)];
      final sw = Stopwatch()..start();
      for (final b in boards) {
        CipherLogic.analyze(b);
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(500));
    });
  });
}
