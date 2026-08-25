import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../widgets/auto_next_countdown.dart';
import '../../../widgets/buy_hints_dialog.dart';
import '../../../widgets/fog_overlay.dart';
import '../../../widgets/challenge_cleared_overlay.dart';
import '../../../widgets/game_level_chip.dart';
import '../../../utils/prefs_keys.dart';
import '../../../utils/hint_manager.dart';
import '../../../utils/point_manager.dart';
import '../../../utils/progress_guard.dart';
import '../../../utils/audio_manager.dart';
import '../../../utils/rotation_engine.dart';
import 'cipher_decoder_logic.dart';

/// Cipher Decoder's free-play modifier pool.
///
/// This game had **no pool at all** before 2.3 — its only modifier hook was a
/// `fog` overlay that nothing ever scheduled, because the game was stashed. All
/// five entries below are implemented in this file and each one is announced to
/// the player in the banner under the rule line, which is what `md/remember.md`
/// §8 requires: a pooled modifier that is not implemented, or is implemented but
/// invisible, is a defect.
///
///  * `timer`   — countdown in the app bar; expiry restarts the level.
///  * `fog`     — the phrase is dark except around the pointer.
///  * `whisper` — the small cipher letters under each tile are hidden. Costs
///                information but not solvability: the decoded letters and the
///                dial reading are both still on screen.
///  * `quota`   — a dial-turn budget, sized by
///                [CipherLogic.fairTurnBudget] from the board itself so it is
///                always enough for a full scan of every unknown plus the
///                clicks to set the remaining dials. A budget a perfect player
///                cannot meet is a broken level, not a hard one.
///  * `retro`   — green-on-black terminal skin.
///
/// Deliberately NOT included: `zoom`. The board here is a short column of word
/// cards, not a dense grid, and an InteractiveViewer would fight the vertical
/// scroll the long six-word phrases need.
const List<String> kCipherDecoderModifierPool = [
  'timer',
  'fog',
  'whisper',
  'quota',
  'retro',
];

const String _kGameId = 'cipherdecoder';

class CipherDecoderScreen extends StatefulWidget {
  const CipherDecoderScreen({super.key});

  @override
  State<CipherDecoderScreen> createState() => _CipherDecoderScreenState();
}

class _CipherDecoderScreenState extends State<CipherDecoderScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  bool _playDailyMode = false;
  String _dailyModifierType = '';
  String _dailyModifierName = '';
  String _dailyModifierDesc = '';
  String? _forcedModifier;
  double _dailyRadius = 1.5;
  bool _isLoading = true;

  CipherBoard? _board;

  /// One dial per word, 0–25. All start at 0, which shows the raw ciphertext —
  /// generation guarantees no word's answer is 0, so nothing is pre-solved.
  List<int> _dials = [];

  /// Words whose dial a hint has already given away.
  final Set<int> _revealed = {};

  Set<String> _activeModifiers = {};
  Timer? _gameTimer;
  int _timeLeft = -1;
  // Timer value at the moment the hard timer started; 0 when no timer ran.
  // Only used for the Speed Demon achievement check on clear.
  int _initialTime = 0;
  bool _timeBonusEarned = false;

  /// `quota`: turns left, and the budget to restore on reset. -1 when inactive.
  int _turnsLeft = -1;
  int _turnBudget = -1;

  Color get _accent => AppTheme.accentFor(_kGameId);

  // COGNIQ-FIX:mod-active-helper
  bool _isModActive(String name) {
    if (_forcedModifier == name) return true;
    if (_playDailyMode) return _dailyModifierType == name;
    return _currentLevel >= RotationEngine.modifierStartLevel(_kGameId) &&
        _activeModifiers.contains(name);
  }

  // COGNIQ-FIX:mod-getters
  bool get _isEndgame => _isModActive('timer');

  bool get _modsOn =>
      !_playDailyMode && RotationEngine.hasModifiers(_kGameId, _currentLevel);

  @override
  void initState() {
    super.initState();
    _loadProgressAndGenerate();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProgressAndGenerate() async {
    final prefs = await SharedPreferences.getInstance();
    _playDailyMode = prefs.getBool(PrefsKeys.playDailyMode) ?? false;
    if (_playDailyMode) {
      _dailyModifierType = prefs.getString(PrefsKeys.dailyModifierType) ?? '';
      _dailyModifierName = prefs.getString(PrefsKeys.dailyModifierName) ?? '';
      _dailyModifierDesc = prefs.getString(PrefsKeys.dailyModifierDesc) ?? '';
      final extraParamsStr =
          prefs.getString(PrefsKeys.dailyModifierExtraParams) ?? '';
      if (extraParamsStr.isNotEmpty) {
        try {
          final extraParams =
              jsonDecode(extraParamsStr) as Map<String, dynamic>;
          if (extraParams.containsKey('radius')) {
            _dailyRadius = (extraParams['radius'] as num).toDouble();
          } else {
            _dailyRadius = 1.5;
          }
        } catch (_) {
          _dailyRadius = 1.5;
        }
      } else {
        _dailyRadius = 1.5;
      }
    } else {
      _dailyModifierType = '';
      _dailyModifierName = '';
      _dailyModifierDesc = '';
      _dailyRadius = 1.5;
    }

    final level = prefs.getInt(PrefsKeys.gameLevel(_kGameId)) ?? 0;
    if (mounted) {
      setState(() {
        _currentLevel = level;
        _isLoading = true;
      });
      _generatePuzzle();
    }
  }

  /// Debug-only level jump. `GameLevelChip` only wires this up when `kDebugMode`
  /// is true, so it is compiled out of release builds.
  void _showJumpToLevelDialog() {
    showDialog(
      context: context,
      builder: (context) {
        int target = _currentLevel + 1;
        return AlertDialog(
          backgroundColor: context.bgCard,
          title: Text('Jump to Level',
              style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold, color: context.textPrimary)),
          content: TextField(
            autofocus: true,
            keyboardType: TextInputType.number,
            style: GoogleFonts.outfit(color: context.textPrimary),
            decoration: InputDecoration(
              labelText: 'Level Number (1+)',
              labelStyle: GoogleFonts.outfit(color: context.textSecondary),
            ),
            onChanged: (val) => target = int.tryParse(val) ?? target,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: GoogleFonts.outfit(color: context.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (target > 0) {
                  setState(() {
                    _currentLevel = target - 1;
                    _isLoading = true;
                  });
                  _generatePuzzle();
                }
              },
              child: Text('Jump', style: GoogleFonts.outfit(color: _accent)),
            ),
          ],
        );
      },
    );
  }

  void _generatePuzzle() {
    _gameTimer?.cancel();
    _timeLeft = -1;
    _timeBonusEarned = false;
    _turnsLeft = -1;
    _turnBudget = -1;
    _revealed.clear();

    if (_modsOn) {
      _activeModifiers = RotationEngine.getActiveModifiers(
        gameId: _kGameId,
        levelIndex: _currentLevel,
        pool: kCipherDecoderModifierPool,
        minActive: 1,
        maxActive: 2,
      );
    } else {
      _activeModifiers = {};
    }

    // Seeded, not random: the same (gameId, level) must produce the same board
    // on every device and every replay, or hints, daily challenges and bug
    // reports stop being reproducible (remember.md — the seeded-RNG law). The
    // stashed build used a bare `Random()` and never imported RotationEngine at
    // all. Generation itself lives in cipher_decoder_logic.dart, gated on a
    // brute-force dial solver — see CipherLogic.verify.
    final board = CipherLogic.generate(
      _currentLevel,
      RotationEngine.getDeterminism(_kGameId, _currentLevel),
    );
    _board = board;
    _dials = List<int>.filled(board.wordCount, 0);

    if (_isModActive('quota')) {
      _turnBudget = CipherLogic.fairTurnBudget(board);
      _turnsLeft = _turnBudget;
    }

    // The one place per level load that resets the no-hint-used flag.
    unawaited(HintManager.startLevel(_kGameId));

    setState(() {
      _isSuccess = false;
      _isLoading = false;
    });

    if (_isEndgame) {
      _timeLeft = 45 + board.wordCount * 20;
      _initialTime = _timeLeft;
      _timeBonusEarned = true;
      _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          if (_timeLeft > 0) {
            _timeLeft--;
          } else {
            _timeLeft = 0;
            _timeBonusEarned = false;
            _gameTimer?.cancel();
            AudioManager.playFail();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Time is up! Restarting level...'),
                duration: Duration(seconds: 1),
              ),
            );
            _generatePuzzle();
          }
        });
      });
    }
  }

  // ------------------------------------------------------------------- dials

  void _turn(int wordIndex, int delta) {
    if (_isSuccess || _board == null) return;
    if (_turnsLeft == 0) return;

    settingsNotifier.hapticTap();
    setState(() {
      _dials[wordIndex] = (_dials[wordIndex] + delta) % 26;
      if (_dials[wordIndex] < 0) _dials[wordIndex] += 26;
      if (_turnsLeft > 0) _turnsLeft--;
    });

    if (_isWon()) {
      settingsNotifier.hapticSuccess();
      _onLevelCleared();
      return;
    }

    // `quota`: the budget is sized so a full scan of every unknown fits, so
    // running out means the turns were spent elsewhere. Restart rather than
    // strand the player on a board they can no longer touch.
    if (_turnsLeft == 0) {
      AudioManager.playFail();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Out of turns! Restarting level...'),
          duration: Duration(seconds: 1),
        ),
      );
      _generatePuzzle();
    }
  }

  bool _isWon() {
    final board = _board;
    if (board == null) return false;
    final want = board.solutionDials;
    for (var w = 0; w < want.length; w++) {
      if (_dials[w] != want[w]) return false;
    }
    return true;
  }

  /// Reset means "zero all dials" — the board itself is untouched, so the
  /// `quota` budget deliberately keeps running.
  void _resetDials() {
    if (_isSuccess || _board == null) return;
    settingsNotifier.hapticTap();
    setState(() {
      _dials = List<int>.filled(_board!.wordCount, 0);
    });
  }

  // ------------------------------------------------------------------- hints

  /// Reveals one word's dial.
  ///
  /// The stashed build spent a hint (and `BuyHintsDialog` sold more) on boards
  /// that were mathematically impossible, then wrote a mapping that broke
  /// another position. Two guards now stand between a hint and the player's
  /// balance: the board must pass the solver, and there must be a word left to
  /// reveal. After the redesign no board is unsolvable at all — asserted in
  /// test/cipher_decoder_logic_test.dart — so the first guard should never
  /// fire, which is exactly why it is cheap to keep.
  Future<void> _showHint() async {
    final board = _board;
    if (board == null || _isSuccess) return;

    if (!CipherLogic.analyze(board).solvable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This board cannot be hinted.')),
      );
      return;
    }

    final want = board.solutionDials;
    int target = -1;
    for (var w = 0; w < want.length; w++) {
      if (_dials[w] != want[w]) {
        target = w;
        break;
      }
    }
    if (target == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Every dial is already set.')),
      );
      return;
    }

    final hints = await HintManager.getHints(_kGameId);
    if (!mounted) return;
    if (hints > 0) {
      await HintManager.useHint(_kGameId);
      if (!mounted) return;
      setState(() {
        _dials[target] = want[target];
        _revealed.add(target);
      });
      if (_isWon()) {
        settingsNotifier.hapticSuccess();
        _onLevelCleared();
      }
    } else {
      BuyHintsDialog.show(context, initialGameId: _kGameId,
          onPurchaseComplete: () {
        setState(() {});
      });
    }
  }

  // ----------------------------------------------------------- level clearing

  Future<void> _onLevelCleared() async {
    _gameTimer?.cancel();

    // Routed through the shared managers. The stashed build wrote its own
    // `beta_level_cipherdecoder` key and bumped `globalLevelClearedCount` by
    // hand, which bypasses the Zen/Challenge split HintManager.onLevelCleared
    // owns and lets a daily run overwrite free-play progress.
    if (!_playDailyMode) {
      await ProgressGuard.saveLevel(_kGameId, _currentLevel + 1, isDaily: false);
      await HintManager.onLevelCleared(
        _kGameId,
        // Speed Demon: cleared a hard-timer level with more than half the
        // clock still left. _initialTime is 0 unless the timer modifier ran.
        isSpeedDemon: _initialTime > 0 && _timeLeft * 2 > _initialTime,
      );
      // The base award is HintManager.onLevelCleared's own 10 points — do NOT
      // add another flat amount on top. The extra 5 is a SPEED BONUS, gated on
      // beating the timer, not a per-clear payment.
      if (_timeLeft > 0 && _timeBonusEarned) {
        await PointManager.addPoints(5);
      }
    }

    if (mounted) setState(() => _isSuccess = true);
  }

  void _nextLevel() {
    setState(() {
      _currentLevel++;
      _isLoading = true;
    });
    _generatePuzzle();
  }

  // --------------------------------------------------------------- modifiers

  // COGNIQ-FIX:mod-desc-copy
  String _getModifierDescription(String id) {
    switch (id) {
      case 'timer':
        return 'Decode the phrase before time expires.';
      case 'fog':
        return 'A dense fog obscures portions of the grid.';
      case 'whisper':
        return 'The small cipher hints below tiles are hidden.';
      case 'quota':
        return 'Limited turns available to rotate dials.';
      case 'retro':
        return 'Terminal monochrome visual theme.';
      default:
        return '';
    }
  }

  String get _modifierBannerText {
    if (_isSuccess) return '';
    if (_playDailyMode) {
      if (_dailyModifierDesc.isNotEmpty) return _dailyModifierDesc;
      if (_dailyModifierName.isNotEmpty) return _dailyModifierName;
      return '';
    }
    return _activeModifiers
        .map(_getModifierDescription)
        .where((d) => d.isNotEmpty)
        .join(' · ');
  }

  List<String> get _visibleModifiers {
    if (_playDailyMode) {
      return kCipherDecoderModifierPool.contains(_dailyModifierType)
          ? [_dailyModifierType]
          : const [];
    }
    if (!_modsOn) return const [];
    return kCipherDecoderModifierPool
        .where(_activeModifiers.contains)
        .toList();
  }

  // ----------------------------------------------------------------- theming

  bool get _retro => _isModActive('retro');
  Color _cardColor(BuildContext ctx) =>
      _retro ? const Color(0xFF04170A) : ctx.bgCard;
  Color _inkColor(BuildContext ctx) =>
      _retro ? const Color(0xFF7CFC9B) : ctx.textPrimary;
  Color _mutedColor(BuildContext ctx) =>
      _retro ? const Color(0xFF3E8B57) : ctx.textMuted;

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.bgCard,
        title: Text(
          'How to Play Cipher Decoder',
          style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold, color: context.textPrimary),
        ),
        content: Text(
          '1. Every word sits on its own dial, like the wheels of a '
          'combination lock.\n\n'
          '2. Turn a dial and that word\'s letters rotate through the '
          'alphabet with it.\n\n'
          '3. Set every dial so the whole phrase reads as plain English. '
          'The level clears the moment it does.\n\n'
          '4. Read the rule at the top: early on all the words share one '
          'shift, later each word steps on from the one before it, and later '
          'still that step is yours to work out. Crack a single word and the '
          'rule hands you the rest.\n\n'
          '5. A hint reveals one word\'s dial. Reset returns every dial to '
          'zero.',
          style: GoogleFonts.outfit(color: context.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Got it',
              style:
                  GoogleFonts.outfit(color: _accent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final board = _board;
    if (_isLoading || board == null) {
      return Scaffold(
        backgroundColor: context.bgDark,
        body: Center(child: CircularProgressIndicator(color: _accent)),
      );
    }

    final mods = _visibleModifiers;

    return Scaffold(
      backgroundColor: _retro ? const Color(0xFF020A05) : context.bgDark,
      appBar: AppBar(
        title: const GameTitle('Cipher Decoder'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        // Back + info + hint + countdown + level chip is more than a 320px bar
        // can hold at default icon metrics, so the two action icons are compact
        // and the countdown carries no padding of its own.
        actionsIconTheme: const IconThemeData(size: 20),
        actions: [
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            icon: Icon(Icons.info_outline, color: _accent),
            tooltip: 'Instructions',
            onPressed: _showInstructions,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            icon: Icon(Icons.lightbulb_outline, color: _accent),
            tooltip: 'Hint',
            onPressed: _showHint,
          ),
          if (_timeLeft >= 0)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer,
                        color: _timeLeft <= 10 ? Colors.red : Colors.amber,
                        size: 16),
                    const SizedBox(width: 2),
                    Text(
                      '${_timeLeft}s',
                      style: GoogleFonts.spaceGrotesk(
                        color: _timeLeft <= 10 ? Colors.red : Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // The standard level indicator — must be the LAST action, and nothing
          // else on the screen may show the level. See remember.md E2 §7.
          GameLevelChip(
            level: _currentLevel + 1,
            modeLabel: _playDailyMode ? 'Daily' : null,
            accent: _accent,
            onTap: kDebugMode ? _showJumpToLevelDialog : null,
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    CipherLogic.ruleLabel(board),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _accent,
                    ),
                  ),
                  if (_modifierBannerText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        _modifierBannerText,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.warmAmber,
                        ),
                      ),
                    ),
                  if (_turnsLeft >= 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        'Turns left: $_turnsLeft / $_turnBudget',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _turnsLeft <= 5 ? Colors.red : Colors.amber,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Sized from BOTH axes. Width alone put a six-word
                        // phrase off the bottom of a 320x568 phone; height
                        // alone made a 1568x696 landscape board absurd.
                        var longest = 1;
                        for (final w in board.plainWords) {
                          longest = max(longest, w.length);
                        }
                        final byWidth =
                            (constraints.maxWidth - 40) / longest;
                        final byHeight = constraints.maxHeight /
                            (board.wordCount * 3.6 + 1);
                        final tile =
                            min(byWidth, byHeight).clamp(15.0, 34.0).toDouble();

                        return FogOverlay(
                          enabled: _isModActive('fog'),
                          radius: max(80.0, tile * 3.5) * _dailyRadius,
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                for (var w = 0; w < board.wordCount; w++)
                                  _buildWordCard(board, w, tile),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.center,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _cardColor(context),
                        foregroundColor: _inkColor(context),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 10),
                      ),
                      onPressed: _resetDials,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Reset dials'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isSuccess)
            Positioned.fill(
              child: Container(
                color: Colors.black.withAlpha(153),
                child: Center(
                  child: _playDailyMode
                      ? ChallengeClearedOverlay(
                          accentColor: _accent,
                          onComplete: () => Navigator.pop(context, true),
                        )
                      : Container(
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: context.bgCard,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.emoji_events,
                                  color: Colors.amber, size: 56),
                              const SizedBox(height: 12),
                              Text(
                                'Level ${_currentLevel + 1} Cleared!',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                board.plainPhrase,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.spaceGrotesk(
                                    fontSize: 13, color: context.textSecondary),
                              ),
                              const SizedBox(height: 12),
                              AutoNextCountdown(
                                  onNext: _nextLevel, accentColor: _accent),
                            ],
                          ),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWordCard(CipherBoard board, int w, double tile) {
    final dial = _dials[w];
    final shown = board.wordAt(w, dial);
    final cipher = board.cipherWords[w];
    final revealed = _revealed.contains(w);
    final hideCipher = _isModActive('whisper');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: _cardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: revealed ? _accent : _mutedColor(context).withAlpha(60),
          width: revealed ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // A horizontal drag spins the wheel, which is what a suitcase lock
          // feels like; the buttons below are the accessible path to the same
          // thing.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragEnd: (details) {
              final v = details.primaryVelocity ?? 0;
              if (v > 100) {
                _turn(w, 1);
              } else if (v < -100) {
                _turn(w, -1);
              }
            },
            child: Semantics(
              label: 'Word ${w + 1}, dial $dial, currently reads $shown',
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 2,
                runSpacing: 2,
                children: [
                  for (var i = 0; i < shown.length; i++)
                    SizedBox(
                      width: tile,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            shown[i],
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: tile * 0.62,
                              fontWeight: FontWeight.bold,
                              color: _inkColor(context),
                            ),
                          ),
                          if (!hideCipher)
                            Text(
                              cipher[i],
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: tile * 0.36,
                                color: _mutedColor(context),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _DialButton(
                icon: Icons.remove,
                accent: _accent,
                tooltip: 'Turn word ${w + 1} back',
                onPressed: () => _turn(w, -1),
              ),
              Container(
                width: 54,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  color: _accent.withAlpha(36),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _accent.withAlpha(110)),
                ),
                child: Text(
                  dial.toString().padLeft(2, '0'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _accent,
                  ),
                ),
              ),
              _DialButton(
                icon: Icons.add,
                accent: _accent,
                tooltip: 'Turn word ${w + 1} forward',
                onPressed: () => _turn(w, 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DialButton extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String tooltip;
  final VoidCallback onPressed;

  const _DialButton({
    required this.icon,
    required this.accent,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 38,
          height: 30,
          decoration: BoxDecoration(
            color: accent.withAlpha(30),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent.withAlpha(90)),
          ),
          child: Icon(icon, size: 18, color: accent),
        ),
      ),
    );
  }
}
