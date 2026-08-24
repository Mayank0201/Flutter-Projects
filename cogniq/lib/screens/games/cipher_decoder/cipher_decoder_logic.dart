/// Pure Cipher Decoder generation logic — no Flutter imports, so it can be
/// unit-tested. Mirrors `kakuro_logic.dart` / `slitherlink_logic.dart`.
///
/// ## Why this file exists
///
/// The stashed screen encrypted a phrase and then asked the player to rebuild a
/// single global `Map<String,String>` from cipher letter to plaintext letter.
/// Two of its three difficulty bands do not produce a *function*: the same
/// cipher letter needs two different answers, so no map can ever satisfy the
/// win check. Exhaustively enumerating every shift the old RNG could produce
/// (25 outcomes for the uniform and progressive bands, 600 for vowel/consonant)
/// measured, on 2026-08-23:
///
/// | band                       | levels shown | outcomes | unsolvable |
/// |----------------------------|--------------|----------|------------|
/// | uniform shift              | 1–5          | 125      | 0.0%       |
/// | vowel/consonant shift      | 6–12         | 4200     | 73.7%      |
/// | progressive per-word shift | 13+          | 350      | 100.0%     |
///
/// The redesign (owner decision, `md/RELEASE_PLAN.md` §4.5 D) drops the letter
/// keyboard and the global map entirely. Each word carries a 0–25 **dial**, like
/// the wheels of a combination suitcase lock; turning it rotates that word's
/// letters. A word is correct at exactly one dial value, so the board is
/// solvable by construction and the win state is decidable at every instant.
///
/// Difficulty is *the number of independent unknowns*, not the amount of
/// scanning — see [CipherMode] and [kHardestFairLevelShown].
library;

import 'dart:math';

/// The hardest level with genuinely new *structure*, as a 1-based shown level.
///
/// Past this the ladder stops adding unknowns and cycles a fixed schedule of the
/// four modes instead. Everything after that has to come from modifiers: once a
/// player understands "free per-word shifts", raising the word count only adds
/// scanning, which is the perception-ceiling trap `md/remember.md` D2 warns
/// about. Asserted in `test/cipher_decoder_logic_test.dart` so it cannot move
/// silently.
///
/// This was 45 in the first 2.3 draft: six bands of six to ten levels each,
/// which measured (see the band table on [CipherLogic.profileFor]) as *one*
/// (mode, words, unknowns) signature per band, so most of a band's levels were
/// new phrases rather than new ideas. The ladder now spends a band's length on
/// how much it teaches, and lands on level 21 — index 20, which is exactly
/// `RotationEngine.modifierStartLevel('cipherdecoder')`, so modifiers pick the
/// curve up on the first level the structure stops climbing rather than
/// stacking on top of a puzzle that is still adding unknowns for another 29
/// levels.
const int kHardestFairLevelShown = 21;

/// Internal (0-based) index of [kHardestFairLevelShown].
const int kHardestFairLevelIndex = kHardestFairLevelShown - 1;

/// No puzzle ever shows more than this many words. Hard cap, asserted by test.
const int kMaxWordsPerPuzzle = 6;

/// No puzzle ever has more than this many independent dial unknowns.
/// Hard cap, asserted by test.
const int kMaxIndependentUnknowns = 4;

/// How the per-word shifts relate to one another. This *is* the difficulty
/// ladder — the count of independent unknowns the player has to pin down.
enum CipherMode {
  /// One shift shared by every word. 1 unknown.
  global,

  /// `shift[w] = base + step*w`, with `step` printed on screen. 1 unknown.
  statedProgressive,

  /// The same arithmetic, but `step` is hidden and must be inferred.
  /// Still 1 unknown, plus the rule.
  unstatedProgressive,

  /// Every word has its own unrelated shift. N unknowns.
  free,
}

/// The knobs the ladder sets for a level. Separated from generation so a test
/// can assert the ladder is capped without generating anything.
class CipherProfile {
  final CipherMode mode;

  /// Exact word count of the phrase this level draws.
  final int words;

  /// Candidate `step` values for the two progressive modes. Empty otherwise.
  final List<int> steps;

  const CipherProfile({
    required this.mode,
    required this.words,
    this.steps = const [],
  });

  @override
  bool operator ==(Object other) =>
      other is CipherProfile &&
      other.mode == mode &&
      other.words == words &&
      other.steps.length == steps.length &&
      _sameSteps(other.steps);

  bool _sameSteps(List<int> o) {
    for (var i = 0; i < steps.length; i++) {
      if (steps[i] != o[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(mode, words, steps.length);

  @override
  String toString() => 'CipherProfile($mode, words: $words, steps: $steps)';
}

/// One generated board.
class CipherBoard {
  final int level;
  final CipherMode mode;

  /// The per-word step, only when the mode *states* it to the player.
  /// Null for [CipherMode.global], [CipherMode.unstatedProgressive] and
  /// [CipherMode.free] — the screen must not leak it.
  final int? statedStep;

  final List<String> plainWords;
  final List<String> cipherWords;

  /// Encryption shift applied to each word. Never 0 — a 0 would render that
  /// word in plaintext on the board.
  final List<int> shifts;

  /// True only if generation had to fall back. Asserted never true by test.
  final bool usedFallback;

  const CipherBoard({
    required this.level,
    required this.mode,
    required this.statedStep,
    required this.plainWords,
    required this.cipherWords,
    required this.shifts,
    this.usedFallback = false,
  });

  String get plainPhrase => plainWords.join(' ');

  String get cipherPhrase => cipherWords.join(' ');

  int get wordCount => plainWords.length;

  /// The dial setting that decodes each word. Dials start at 0; because no
  /// shift is ever 0, no dial answer is ever 0 either, so a fresh board never
  /// starts with a word already solved.
  List<int> get solutionDials =>
      [for (final s in shifts) (26 - s) % 26];

  /// The word as it reads with its dial at [dial].
  String wordAt(int index, int dial) =>
      CipherLogic.rotate(cipherWords[index], dial);

  /// The fewest dial clicks needed from all-zero, counting a click in either
  /// direction. Used to size the `quota` modifier's budget so it can never be
  /// smaller than a perfect solve.
  int get minimumTurns {
    var t = 0;
    for (final d in solutionDials) {
      t += d <= 13 ? d : 26 - d;
    }
    return t;
  }
}

/// What a board actually *is*, recomputed from its cipher/plaintext pair alone.
///
/// Nothing here reads [CipherBoard.mode] or [CipherBoard.shifts]: the dials are
/// found by brute force over the real 26-value dial space. That is what makes
/// this a solver rather than a restatement of the generator's intent, and it is
/// what the generation gate and the difficulty tests measure.
class CipherAnalysis {
  /// Every word has at least one dial value that reproduces its plaintext.
  final bool solvable;

  /// The dial answer per word, found by search. Empty when [solvable] is false.
  final List<int> dials;

  /// Any word already readable with its dial at 0, i.e. shipped in plaintext.
  final bool leaksPlaintext;

  /// The dials fit `dials[w] = dials[0] + step*w (mod 26)` for some step.
  /// Always true for 2 words or fewer, which is why [CipherMode.free] never
  /// draws a phrase shorter than 3 words.
  final bool linearRuleFits;

  /// The rule exists but is not printed on screen.
  final bool ruleHidden;

  final int wordCount;
  final int letterCount;

  const CipherAnalysis({
    required this.solvable,
    required this.dials,
    required this.leaksPlaintext,
    required this.linearRuleFits,
    required this.ruleHidden,
    required this.wordCount,
    required this.letterCount,
  });

  /// How many dials the player must determine independently. One when the
  /// words are tied together by arithmetic — cracking any single word then
  /// hands over all the others.
  int get independentUnknowns => linearRuleFits ? 1 : wordCount;

  /// Measured difficulty of this board. Deliberately dominated by
  /// [independentUnknowns]; an unstated rule is worth a fraction of one extra
  /// unknown, and phrase bulk is the tie-breaker inside a band.
  int get difficultyScore =>
      independentUnknowns * 1000 + (ruleHidden ? 300 : 0) + wordCount * 20 + letterCount;
}

class CipherLogic {
  CipherLogic._();

  // ------------------------------------------------------------------ corpus
  //
  // 107 ordinary English phrases, replacing the 14 the stashed screen shipped.
  // The old corpus cycled with period 14 from level 10 and left 12 of its 21
  // short-phrase entries unreachable — measured, not assumed.
  //
  // Rules the corpus follows, all asserted by test:
  //  * no single-letter words: a one-letter word under a free per-word shift is
  //    a 26-way coin flip, not a deduction;
  //  * tiers A, B and C carry no two-letter words either, because those are the
  //    only tiers [CipherMode.free] draws from, where each word stands alone;
  //  * tier sizes are coprime to 10, which is what makes the plateau schedule
  //    below reach every entry (see _pickPhrase).

  /// Two-word phrases.
  static const List<String> tierA = [
    'OPEN DOOR', 'COLD WATER', 'GREEN LIGHT', 'FRESH BREAD', 'NIGHT SKY',
    'WARM COAT', 'GOOD MORNING', 'SWEET DREAMS', 'FAST TRAIN', 'QUIET ROOM',
    'BLUE OCEAN', 'SUMMER RAIN', 'WINTER SNOW', 'PAPER PLANE', 'COFFEE CUP',
    'GARDEN GATE', 'MOUNTAIN PATH', 'CITY STREET', 'GOLDEN HOUR',
    'BRIGHT STAR', 'SOFT MUSIC', 'LONG JOURNEY', 'WOODEN CHAIR',
  ];

  /// Three-word phrases.
  static const List<String> tierB = [
    'THE OPEN ROAD', 'TIME WILL TELL', 'KEEP THINGS SIMPLE',
    'HOME SWEET HOME', 'RISE AND SHINE', 'PEACE AND QUIET', 'SAFE AND SOUND',
    'LEARN SOMETHING NEW', 'TAKE YOUR TIME', 'SHARE THE LOAD',
    'FOLLOW THE MAP', 'WATCH THE SUNSET', 'COUNT THE STARS',
    'OPEN THE WINDOW', 'CLOSE THE DOOR', 'PACK YOUR BAGS', 'TURN THE PAGE',
    'CATCH THE TRAIN', 'ENJOY THE VIEW', 'MAKE SOME NOISE',
    'SLOW AND STEADY', 'BREAD AND BUTTER', 'SALT AND PEPPER',
    'DAY AND NIGHT', 'BLACK AND WHITE', 'OVER THE MOON', 'UNDER THE STARS',
  ];

  /// Four-word phrases.
  static const List<String> tierC = [
    'BETTER LATE THAN NEVER', 'EASY COME EASY GONE', 'LIVE AND LET LIVE',
    'READ THE FINE PRINT', 'MAKE YOUR OWN LUCK', 'KEEP YOUR CHIN HIGH',
    'TAKE THE LONG WAY', 'SEE YOU NEXT WEEK', 'THE SKY LOOKS BLUE',
    'TURN OFF THE LIGHTS', 'OPEN YOUR EYES WIDE', 'SHARE WHAT YOU HAVE',
    'LISTEN FOR THE RAIN', 'FOLLOW YOUR OWN PATH', 'NEVER STOP ASKING WHY',
    'THINK BEFORE YOU SPEAK', 'LOOK BEFORE YOU LEAP',
    'FIRST COME FIRST SERVED', 'THE MORE THE MERRIER',
    'TIME HEALS ALL WOUNDS', 'MUSIC MAKES THE DAY',
  ];

  /// Five-word phrases. Only ever shown under a shared rule, so the two-letter
  /// words here are still deducible from the rest of the phrase.
  static const List<String> tierD = [
    'THE GRASS IS ALWAYS GREENER', 'MAKE YOUR BED EVERY MORNING',
    'TAKE THE SCENIC ROUTE HOME', 'LEAVE THE PAST BEHIND YOU',
    'KEEP CALM AND CARRY ON', 'NEVER JUDGE BEFORE YOU KNOW',
    'SLOW DOWN AND ENJOY LIFE', 'ACTIONS SPEAK LOUDER THAN WORDS',
    'THE BEST THINGS ARE FREE', 'DO NOT COUNT YOUR CHICKENS',
    'PRACTICE MAKES PROGRESS NOT PERFECTION',
    'GOOD FRIENDS MAKE LIFE BETTER', 'SMALL STEPS STILL MOVE FORWARD',
    'THE MORNING SUN FEELS WARM', 'REST WELL AND START AGAIN',
    'LOOK UP AT THE SKY', 'ONE STEP AFTER THE OTHER',
    'EVERY DAY BRINGS SOMETHING NEW', 'CARRY LESS AND TRAVEL FURTHER',
  ];

  /// Six-word phrases.
  static const List<String> tierE = [
    'THE EARLY BIRD CATCHES THE WORM', 'EVERY CLOUD HAS ITS SILVER LINING',
    'THE PROOF IS IN THE PUDDING', 'ALL THAT GLITTERS IS NOT GOLD',
    'TWO HEADS ARE BETTER THAN ONE', 'THERE IS NO PLACE LIKE HOME',
    'HOME IS WHERE THE HEART IS', 'LIFE IS SHORT SO ENJOY IT',
    'EVERY JOURNEY STARTS WITH ONE STEP', 'FIND THE JOY IN SMALL THINGS',
    'WE ALL NEED SOME QUIET TIME', 'TOMORROW IS ANOTHER BRAND NEW DAY',
    'PEOPLE WHO LIVE IN GLASS HOUSES', 'READING OPENS THE DOOR TO WORLDS',
    'TIME SPENT READING IS NEVER WASTED', 'CHOOSE THE PATH THAT FEELS RIGHT',
    'THE ANSWER WAS THERE ALL ALONG',
  ];

  /// Every phrase, in tier order. Used by the reachability test.
  static List<String> get corpus => [
        ...tierA,
        ...tierB,
        ...tierC,
        ...tierD,
        ...tierE,
      ];

  static List<String> _tierFor(int words) {
    switch (words) {
      case 2:
        return tierA;
      case 3:
        return tierB;
      case 4:
        return tierC;
      case 5:
        return tierD;
      default:
        return tierE;
    }
  }

  // ------------------------------------------------------------------ ladder

  /// Step candidates for a *stated* rule: small and obvious, since the point is
  /// that one word hands you the rest, not that the arithmetic is hard.
  static const List<int> _statedSteps = [1, 2, 3];

  /// Step candidates for a *hidden* rule. Includes the backwards steps (21–25
  /// is −5…−1) so "it goes up by one" is not the only guess worth making.
  /// Only used once the player has met both directions separately.
  static const List<int> _hiddenSteps = [1, 2, 3, 4, 5, 21, 22, 23, 24, 25];

  /// The hidden rule's first band draws forward steps only. The new idea there
  /// is *that there is a rule to infer at all*; making the player also guess the
  /// direction on their first unstated board is two ideas at once, which is the
  /// thing this ladder exists to avoid.
  static const List<int> _hiddenStepsForward = [1, 2, 3, 4, 5];

  /// The second hidden band draws backwards steps only, so the idea "the rule
  /// can run the other way" is *guaranteed* to be taught rather than left to a
  /// lucky draw from the mixed pool. This is what earns that band its levels:
  /// without it the band would be the previous one with one more word, which is
  /// scanning, not deduction. Measured in `cipher_decoder_logic_test.dart` off
  /// the recovered dials, not off this list.
  static const List<int> _hiddenStepsBackward = [21, 22, 23, 24, 25];

  /// The fixed schedule the ladder cycles once it reaches its cap.
  ///
  /// Three jobs.
  ///
  /// It stops difficulty climbing: no entry adds an unknown the ladder has not
  /// already taught, no entry exceeds [kMaxWordsPerPuzzle] or
  /// [kMaxIndependentUnknowns], and the cycle's hardest slot is the ladder's own
  /// hardest rung (free, four words) rather than something past it. What the
  /// cycle *does* recombine is mode against bulk — a stated rule over five
  /// words, a hidden rule over three — which is rearrangement of ideas the
  /// player already has, not a new one.
  ///
  /// It is ordered, and the order is the point. The schedule now runs from the
  /// easiest board the game can draw to the hardest, so every ten levels is the
  /// whole ladder in miniature. Measured on generated boards, each slot scores
  /// strictly above the one before it — asserted over 120 consecutive cycles in
  /// `cipher_decoder_logic_test.dart`, because a schedule that merely *looks*
  /// ordered is the easy way for this to rot. The earlier draft's schedule
  /// interleaved (free/3 at slot 3, free/4 at slot 7) and so ran downhill four
  /// times per cycle. The one descent left is the seam between cycles, and that
  /// is deliberate: past this point the climb belongs to modifiers, which start
  /// on the very level this schedule does.
  ///
  /// And it is what makes the whole corpus reachable: the schedule is 10 long,
  /// every tier size is coprime to 10, and the phrase index is
  /// `level % tier.length`, so each slot walks its entire tier instead of
  /// parking on the handful of indices a short band can reach. That is the fix
  /// for the 12 dead corpus entries measured in the stashed build; with the
  /// ladder compressed to 20 levels the plateau does nearly all of that work,
  /// and every one of the 107 phrases is still drawn by level 240.
  static const List<CipherProfile> _plateau = [
    CipherProfile(mode: CipherMode.global, words: 2),
    CipherProfile(mode: CipherMode.statedProgressive, words: 3, steps: _statedSteps),
    CipherProfile(mode: CipherMode.statedProgressive, words: 4, steps: _statedSteps),
    CipherProfile(mode: CipherMode.statedProgressive, words: 5, steps: _statedSteps),
    CipherProfile(mode: CipherMode.unstatedProgressive, words: 3, steps: _hiddenSteps),
    CipherProfile(mode: CipherMode.unstatedProgressive, words: 4, steps: _hiddenSteps),
    CipherProfile(mode: CipherMode.unstatedProgressive, words: 5, steps: _hiddenSteps),
    CipherProfile(mode: CipherMode.unstatedProgressive, words: 6, steps: _hiddenSteps),
    CipherProfile(mode: CipherMode.free, words: 3),
    CipherProfile(mode: CipherMode.free, words: 4),
  ];

  /// The knobs for [level] (0-based).
  ///
  /// Bands, in order: one global shift; a stated rule; a hidden rule forwards;
  /// the same rule backwards; free per-word shifts; free per-word shifts with a
  /// fourth word. That is the owner's ladder — "difficulty = number of
  /// independent unknowns" — and nothing past [kHardestFairLevelIndex] adds a
  /// new rung.
  ///
  /// ## Why these lengths
  ///
  /// A band is worth exactly as many levels as it has ideas to teach. The first
  /// 2.3 draft ran the same six bands over 45 levels; brute-forcing the
  /// generated boards through [analyze] showed every band collapsing to a single
  /// (mode, words, unknowns) signature, so a band's extra levels bought a new
  /// phrase and nothing else. Measured mean [CipherAnalysis.difficultyScore],
  /// old ladder:
  ///
  /// | band                | levels | mean score | delta |
  /// |---------------------|--------|-----------:|------:|
  /// | global, 2 words     | 6      |     1048.8 |     — |
  /// | stated, 3 words     | 10     |     1072.9 |  +24  |
  /// | hidden, 4 words     | 7      |     1397.6 | +325  |
  /// | hidden, 5 words     | 7      |     1423.4 |  +26  |
  /// | free, 3 words       | 7      |     3073.0 | +1650 |
  /// | free, 4 words       | 7      |     4097.6 | +1025 |
  ///
  /// Ten levels for +24 and seven more for +26 is the tell: those two bands were
  /// paying in player time for phrase bulk, which is scanning. The lengths below
  /// are set against what each band actually introduces:
  ///
  ///  * **0–2, global/2 (3).** One idea: the dial, and that a word has exactly
  ///    one correct setting. Three boards is a demonstration and two repeats.
  ///  * **3–5, stated/3 (3).** One idea: words can differ, and the relation is
  ///    printed. Cracking one word still hands over the rest, so the deduction
  ///    is unchanged — three levels to internalise "apply the printed step".
  ///  * **6–10, hidden/4 (5).** The largest genuinely new idea below `free`:
  ///    infer the step yourself. It gets the longest band on the ladder, and
  ///    [_hiddenStepsForward] keeps the direction fixed so the only new thing is
  ///    the inference.
  ///  * **11–12, hidden/5 (2).** In the old ladder this band was seven levels of
  ///    the previous one plus a word. It now draws [_hiddenStepsBackward], so it
  ///    teaches that the rule can run the other way — one idea, two levels.
  ///  * **13–16, free/3 (4).** The biggest measured jump in the game (1 unknown
  ///    to 3, +1650). A whole new solving habit — every word alone — so four
  ///    levels before the count rises.
  ///  * **17–19, free/4 (3).** Four independent unknowns, i.e.
  ///    [kMaxIndependentUnknowns]. Three levels at the ceiling, then the ladder
  ///    is done and the plateau takes over on level 20 — the same level
  ///    modifiers begin.
  static CipherProfile profileFor(int level) {
    if (level >= kHardestFairLevelIndex) {
      return _plateau[(level - kHardestFairLevelIndex) % _plateau.length];
    }
    if (level < 3) {
      return const CipherProfile(mode: CipherMode.global, words: 2);
    }
    if (level < 6) {
      return const CipherProfile(
          mode: CipherMode.statedProgressive, words: 3, steps: _statedSteps);
    }
    if (level < 11) {
      return const CipherProfile(
          mode: CipherMode.unstatedProgressive,
          words: 4,
          steps: _hiddenStepsForward);
    }
    if (level < 13) {
      return const CipherProfile(
          mode: CipherMode.unstatedProgressive,
          words: 5,
          steps: _hiddenStepsBackward);
    }
    if (level < 17) {
      return const CipherProfile(mode: CipherMode.free, words: 3);
    }
    return const CipherProfile(mode: CipherMode.free, words: 4);
  }

  // -------------------------------------------------------------- primitives

  static bool isLetter(String c) {
    if (c.isEmpty) return false;
    final code = c.codeUnitAt(0);
    return code >= 65 && code <= 90;
  }

  /// Rotates every A–Z character of [word] forward by [amount].
  static String rotate(String word, int amount) {
    final a = ((amount % 26) + 26) % 26;
    if (a == 0) return word;
    final b = StringBuffer();
    for (var i = 0; i < word.length; i++) {
      final ch = word[i];
      if (isLetter(ch)) {
        b.writeCharCode(((ch.codeUnitAt(0) - 65 + a) % 26) + 65);
      } else {
        b.write(ch);
      }
    }
    return b.toString();
  }

  /// True when [dials] sit on an arithmetic progression mod 26 — i.e. one
  /// unknown, not N. Vacuously true for 2 dials or fewer.
  static bool fitsLinearRule(List<int> dials) {
    if (dials.length <= 2) return true;
    final step = ((dials[1] - dials[0]) % 26 + 26) % 26;
    for (var w = 2; w < dials.length; w++) {
      if (dials[w] % 26 != (dials[0] + step * w) % 26) return false;
    }
    return true;
  }

  // ---------------------------------------------------------------- analysis

  /// Recovers what a board really is by searching the dial space. See
  /// [CipherAnalysis].
  static CipherAnalysis analyze(CipherBoard board) {
    final dials = <int>[];
    var letters = 0;
    for (var w = 0; w < board.cipherWords.length; w++) {
      final cipher = board.cipherWords[w];
      final plain = board.plainWords[w];
      letters += plain.length;
      var found = -1;
      for (var d = 0; d < 26; d++) {
        if (rotate(cipher, d) == plain) {
          found = d;
          break;
        }
      }
      if (found < 0) {
        return CipherAnalysis(
          solvable: false,
          dials: const [],
          leaksPlaintext: false,
          linearRuleFits: false,
          ruleHidden: false,
          wordCount: board.plainWords.length,
          letterCount: letters,
        );
      }
      dials.add(found);
    }
    return CipherAnalysis(
      solvable: true,
      dials: dials,
      leaksPlaintext: dials.any((d) => d == 0),
      linearRuleFits: fitsLinearRule(dials),
      ruleHidden: board.mode == CipherMode.unstatedProgressive,
      wordCount: board.plainWords.length,
      letterCount: letters,
    );
  }

  /// The gate every generated board must pass before it is handed to the UI.
  ///
  /// This is a real solver check, not `expect(isWon, false)`: it re-derives the
  /// dials from the ciphertext, insists each one exists, insists none is 0 (a 0
  /// would put that word on screen in plaintext), and insists the number of
  /// independent unknowns is exactly what the ladder asked for. A board that
  /// fails any of those is not shipped.
  static bool verify(CipherBoard board, CipherProfile profile) {
    if (board.plainWords.length != profile.words) return false;
    if (board.plainWords.length != board.cipherWords.length) return false;
    if (board.plainWords.length > kMaxWordsPerPuzzle) return false;

    final a = analyze(board);
    if (!a.solvable) return false;
    if (a.leaksPlaintext) return false;
    if (a.independentUnknowns > kMaxIndependentUnknowns) return false;

    final wantsOneUnknown = profile.mode != CipherMode.free;
    if (wantsOneUnknown && a.independentUnknowns != 1) return false;
    if (!wantsOneUnknown && a.independentUnknowns != board.plainWords.length) {
      return false;
    }

    // A stated step has to be the step the board actually uses, or the banner
    // on screen is a lie.
    if (board.statedStep != null) {
      for (var w = 0; w < board.shifts.length; w++) {
        final expected = (board.shifts[0] + board.statedStep! * w) % 26;
        if (board.shifts[w] % 26 != expected) return false;
      }
    }
    if (profile.mode == CipherMode.statedProgressive && board.statedStep == null) {
      return false;
    }
    if (profile.mode != CipherMode.statedProgressive && board.statedStep != null) {
      return false;
    }
    return true;
  }

  // -------------------------------------------------------------- generation

  /// Deterministic for a given ([level], [rng]) pair — [rng] must come from
  /// `RotationEngine.getDeterminism('cipherdecoder', level)`.
  static CipherBoard generate(int level, Random rng) {
    final profile = profileFor(level);
    final phrase = _pickPhrase(level, profile);
    final words = phrase.split(' ');

    final List<int> shifts;
    int? statedStep;

    switch (profile.mode) {
      case CipherMode.global:
        final s = 1 + rng.nextInt(25);
        shifts = List<int>.filled(words.length, s);
        break;

      case CipherMode.statedProgressive:
      case CipherMode.unstatedProgressive:
        final step = profile.steps[rng.nextInt(profile.steps.length)];
        // Excluding shift 0: a base is only usable if no word lands on it.
        // With W words at most W of the 26 bases are barred, so this list is
        // never empty. The stashed build skipped this and leaked a plaintext
        // word on 4 to 10 of its 25 base shifts (measured).
        final bases = <int>[];
        for (var b = 0; b < 26; b++) {
          var ok = true;
          for (var w = 0; w < words.length; w++) {
            if ((b + step * w) % 26 == 0) {
              ok = false;
              break;
            }
          }
          if (ok) bases.add(b);
        }
        final base = bases[rng.nextInt(bases.length)];
        shifts = [for (var w = 0; w < words.length; w++) (base + step * w) % 26];
        if (profile.mode == CipherMode.statedProgressive) statedStep = step;
        break;

      case CipherMode.free:
        final s = [for (var w = 0; w < words.length; w++) 1 + rng.nextInt(25)];
        // Free means free: if the roll happens to land on an arithmetic
        // progression the board is secretly a one-unknown board, so nudge the
        // last dial until it is not. With the earlier shifts fixed, at most one
        // value of the last makes the sequence linear, so this ends at once.
        var guard = 0;
        while (
            fitsLinearRule([for (final v in s) (26 - v) % 26]) && guard++ < 26) {
          s[s.length - 1] = (s[s.length - 1] % 25) + 1;
        }
        shifts = s;
        break;
    }

    final board = CipherBoard(
      level: level,
      mode: profile.mode,
      statedStep: statedStep,
      plainWords: words,
      cipherWords: [
        for (var w = 0; w < words.length; w++) rotate(words[w], shifts[w])
      ],
      shifts: shifts,
    );

    if (verify(board, profile)) return board;
    return _fallback(level, profile, words);
  }

  /// A board that cannot fail: one global shift, never 0, one unknown.
  /// Reached only if [verify] rejects the generated board, which the test suite
  /// asserts never happens.
  static CipherBoard _fallback(
      int level, CipherProfile profile, List<String> words) {
    final s = 1 + (level % 25);
    return CipherBoard(
      level: level,
      mode: CipherMode.global,
      statedStep: null,
      plainWords: words,
      cipherWords: [for (final w in words) rotate(w, s)],
      shifts: List<int>.filled(words.length, s),
      usedFallback: true,
    );
  }

  /// The dial-turn budget the `quota` modifier may impose on [board].
  ///
  /// Sized from the board itself, never from the level: a full 26-step scan for
  /// every independent unknown, plus the clicks needed to set the remaining
  /// dials once the rule is known, plus slack. A budget a perfect player cannot
  /// meet is a broken level, not a hard one — so this is a floor, and the test
  /// suite asserts it stays above `26 * unknowns + minimumTurns`.
  static int fairTurnBudget(CipherBoard board) {
    final unknowns = analyze(board).independentUnknowns;
    return 26 * unknowns + board.minimumTurns + 8;
  }

  static String _pickPhrase(int level, CipherProfile profile) {
    final tier = _tierFor(profile.words);
    return tier[level % tier.length];
  }

  // ------------------------------------------------------------ presentation

  /// The rule banner. The player is told the structure but never the answer —
  /// [CipherMode.unstatedProgressive] deliberately withholds the step.
  static String ruleLabel(CipherBoard board) {
    switch (board.mode) {
      case CipherMode.global:
        return 'Every word uses the same shift.';
      case CipherMode.statedProgressive:
        final step = board.statedStep!;
        final signed = step <= 13 ? '+$step' : '-${26 - step}';
        return 'Each word shifts $signed from the word before it.';
      case CipherMode.unstatedProgressive:
        return 'The words follow a hidden rule. Crack one, get the rest.';
      case CipherMode.free:
        return 'Every word has its own shift. No rule connects them.';
    }
  }
}
