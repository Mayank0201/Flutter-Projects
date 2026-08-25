import 'dart:math';
import 'dart:convert';
import 'dart:async';
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
import '../../../widgets/decaying_clue.dart';
import 'kakuro_logic.dart';

/// Kakuro's free-play modifier pool.
///
/// Exported so test/modifier_batch2_test.dart checks the pool the screen really
/// uses rather than a copy that can drift.
///
/// Deliberately NOT included: `clueThinning`. In Sudoku it removes givens, but a
/// Kakuro run with no clue is completely unconstrained — that is precisely the
/// unheaded-run bug fixed in KakuroLogic.normalizeLayout, and adding it here
/// would reintroduce unsolvable boards on purpose.
///
/// `decay` is the opposite of that trap and is why it belongs here: it never
/// removes or alters a clue, it only makes the ink faint, and any clue can be
/// brought back by tapping it. The run stays fully constrained and the board
/// stays solvable at every instant. It is also what lifts this pool from three
/// entries to four — with three, the pairs tier has only three combinations to
/// spread across 35 levels.
const List<String> kKakuroModifierPool = [
  'timer',
  'fog',
  'zoom',
  'decay',
];

class KakuroScreen extends StatefulWidget {
  const KakuroScreen({super.key});

  @override
  State<KakuroScreen> createState() => _KakuroScreenState();
}

class _KakuroScreenState extends State<KakuroScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  bool _playDailyMode = false;
  String _dailyModifierType = '';
  String _dailyModifierName = '';
  String _dailyModifierDesc = '';
  String? _forcedModifier;
  double _dailyRadius = 1.5;
  int _gridSize = 4; // 4, 6, or 8 based on difficulty/level

  // Grid state
  List<int> _grid = []; // player entries (0 for empty)
  List<int> _solution = []; // full solution digits
  List<int> _types = []; // 0: wall, 1: white, 2: clue
  List<int> _hClues = []; // horizontal clues
  List<int> _vClues = []; // vertical clues

  int _selectedIdx = -1;
  int _hintIdx = -1;
  bool _isLoading = true;

  Set<String> _activeModifiers = {};
  Timer? _gameTimer;
  int _timeLeft = -1;
  // Timer value at the moment the hard timer started; 0 when no timer ran.
  // Only used for the Speed Demon achievement check on clear.
  int _initialTime = 0;
  bool _timeBonusEarned = false;

  // COGNIQ-FIX:mod-active-helper
  bool _isModActive(String name) {
    if (_forcedModifier == name) return true;
    if (_playDailyMode) return _dailyModifierType == name;
    return _currentLevel >= RotationEngine.modifierStartLevel('kakuro') &&
        _activeModifiers.contains(name);
  }

  // COGNIQ-FIX:mod-getters
  bool get _isEndgame => _isModActive('timer');
  bool get _isFogActive => _isModActive('fog');
  bool get _isZoomActive => _isModActive('zoom');
  bool get _isDecayActive => _isModActive('decay');

  // COGNIQ-FIX:mod-desc-copy
  String _getModifierDescription(String mod) {
    switch (mod) {
      case 'timer':
        return 'Solve before the timer runs out.';
      case 'fog':
        return 'A dense fog obscures portions of the grid.';
      case 'zoom':
        return 'Grid is magnified with pan-and-scan navigation.';
      case 'decay':
        return 'Clues fade over time. Tap to reveal.';
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

  /// Modifiers now begin at a per-game level chosen in RotationEngine
  /// rather than a flat level 30 for every game.
  bool get _modsOn => !_playDailyMode && RotationEngine.hasModifiers('kakuro', _currentLevel);

  /// `decay`: the fade clock for the level on screen. Started only when the
  /// modifier is active, so a normal level never creates the timer.
  late final DecayController _decay = DecayController(onChanged: () {
    if (mounted) setState(() {});
  });

  @override
  void initState() {
    super.initState();
    _loadProgressAndGenerate();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _decay.dispose();
    super.dispose();
  }

  /// `decay`: bring a faded clue back for a few seconds.
  ///
  /// Costs no points — see the note in widgets/decaying_clue.dart on why the
  /// handbook's 5-point charge is an unbounded sink. On a timed level it costs
  /// two seconds instead, which is a cost the game can actually meter.
  void _tapClue(int idx) {
    if (!_isDecayActive) return;
    if (!_decay.reveal(idx)) return;
    settingsNotifier.hapticTap();
    if (_timeLeft > 0) {
      setState(() {
        _timeLeft = max(0, _timeLeft - kDecayRevealTimeCostSeconds);
      });
    }
  }

  Future<void> _loadProgressAndGenerate() async {
    final prefs = await SharedPreferences.getInstance();
    _playDailyMode = prefs.getBool(PrefsKeys.playDailyMode) ?? false;
    if (_playDailyMode) {
      _dailyModifierType = prefs.getString(PrefsKeys.dailyModifierType) ?? '';
      _dailyModifierName = prefs.getString(PrefsKeys.dailyModifierName) ?? '';
      _dailyModifierDesc = prefs.getString(PrefsKeys.dailyModifierDesc) ?? '';
      final extraParamsStr = prefs.getString(PrefsKeys.dailyModifierExtraParams) ?? '';
      if (extraParamsStr.isNotEmpty) {
        try {
          final extraParams = jsonDecode(extraParamsStr) as Map<String, dynamic>;
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

    int level = prefs.getInt(PrefsKeys.gameLevel('kakuro')) ?? 0;
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
              child: Text('Jump',
                  style: GoogleFonts.outfit(color: AppTheme.dustyMauve)),
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

    if (_modsOn) {
      // A one-entry pool meant every modifier level looked identical.
      //
      // remember.md E2 section 8: everything in a pool must actually change the
      // level and be visible to the player. All four entries are implemented in
      // this file and shown to the player. See kKakuroModifierPool for why
      // `clueThinning` stays out and why `decay` is safe where it is not.
      _activeModifiers = RotationEngine.getActiveModifiers(
        gameId: 'kakuro',
        levelIndex: _currentLevel,
        pool: kKakuroModifierPool,
        minActive: 1,
        maxActive: 2,
        smallGrid: _gridSize <= 4,
      );
      if (_forcedModifier != null) {
        _activeModifiers = {_forcedModifier!};
      }
    } else {
      _activeModifiers = {};
      if (_playDailyMode && _dailyModifierType.isNotEmpty) {
        _activeModifiers.add(_dailyModifierType);
      }
    }

    // Generation lives in kakuro_logic.dart so it can be unit-tested — see
    // test/kakuro_logic_test.dart. Seeded, not random: the same (gameId, level)
    // must produce the same board on every device and every replay, or hints,
    // daily challenges and bug reports stop being reproducible.
    // (remember.md — the seeded-RNG law.)
    //
    // KakuroLogic.generate never returns null and never touches the saved level.
    // The old code reset `_currentLevel = 0` whenever generation failed, and it
    // failed on every level from 5 up, so reaching level 5 wiped the player's
    // progress on every single attempt.
    final board = KakuroLogic.generate(
      _currentLevel,
      RotationEngine.getDeterminism('kakuro', _currentLevel),
    );

    _gridSize = board.size;
    _types = board.types;
    _solution = board.solution;
    _hClues = board.hClues;
    _vClues = board.vClues;
    _grid = List.filled(board.size * board.size, 0);

    setState(() {
      _isSuccess = false;
      _selectedIdx = -1;
      _hintIdx = -1;
      _isLoading = false;
    });

    // `decay`: restart the fade clock for the new board, or make sure it is not
    // running at all. stop() also clears the per-clue reveal times, so a clue
    // re-revealed on the last level does not start this one already faded.
    if (_isDecayActive) {
      _decay.start();
    } else {
      _decay.stop();
    }

    if (_isEndgame) {
      _timeLeft = 60 + (_gridSize * 15);
      _initialTime = _timeLeft;
      _timeBonusEarned = true;
      _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            if (_timeLeft > 0) {
              _timeLeft--;
            } else {
              _timeLeft = 0;
              _timeBonusEarned = false;
              _gameTimer?.cancel();
              AudioManager.playFail();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Time is up! Restarting level...'), duration: Duration(seconds: 1)),
              );
              _generatePuzzle();
            }
          });
        }
      });
    }
  }

  // Returns horizontal segment starting at or before index
  List<int> _getRowSegmentIndices(int idx) {
    List<int> indices = [];
    int r = idx ~/ _gridSize;
    int c = idx % _gridSize;

    // Go left to find start of segment
    int startCol = c;
    while (startCol >= 0 && _types[r * _gridSize + startCol] == 1) {
      startCol--;
    }
    // Now startCol points to the clue cell or wall
    // Go right and collect indices
    int x = startCol + 1;
    while (x < _gridSize && _types[r * _gridSize + x] == 1) {
      indices.add(r * _gridSize + x);
      x++;
    }
    return indices;
  }

  // Returns vertical segment starting at or before index
  List<int> _getColSegmentIndices(int idx) {
    List<int> indices = [];
    int r = idx ~/ _gridSize;
    int c = idx % _gridSize;

    // Go up to find start of segment
    int startRow = r;
    while (startRow >= 0 && _types[startRow * _gridSize + c] == 1) {
      startRow--;
    }
    // Now startRow points to the clue cell or wall
    // Go down and collect indices
    int y = startRow + 1;
    while (y < _gridSize && _types[y * _gridSize + c] == 1) {
      indices.add(y * _gridSize + c);
      y++;
    }
    return indices;
  }







  void _checkSolution() {
    bool isValid = true;
    for (int i = 0; i < _types.length; i++) {
      if (_types[i] == 1 && _grid[i] == 0) {
        isValid = false;
      }
    }

    if (!isValid) {
      settingsNotifier.hapticError();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill all entry cells!')),
      );
      return;
    }

    // Verify all clues
    for (int idx = 0; idx < _types.length; idx++) {
      if (_types[idx] == 2) {
        int hc = _hClues[idx];
        int vc = _vClues[idx];

        if (hc > 0) {
          final run = _getRowSegmentIndices(idx + 1);
          final vals = run.map((i) => _grid[i]).toList();
          if (vals.reduce((a, b) => a + b) != hc || vals.toSet().length != vals.length) {
            isValid = false;
          }
        }

        if (vc > 0) {
          final run = _getColSegmentIndices(idx + _gridSize);
          final vals = run.map((i) => _grid[i]).toList();
          if (vals.reduce((a, b) => a + b) != vc || vals.toSet().length != vals.length) {
            isValid = false;
          }
        }
      }
    }

    if (isValid) {
      settingsNotifier.hapticSuccess();
      _onLevelCleared();
    } else {
      settingsNotifier.hapticError();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incorrect solution! Check clues and make sure digits in a run are unique.'),
        ),
      );
    }
  }

  Future<void> _onLevelCleared() async {
    // Routed through the shared managers rather than writing prefs by hand.
    //
    // This used to bump `globalLevelClearedCount` itself and save to a private
    // `beta_level_kakuro` key. No live game does that any more: the four stashed
    // games were the last holdouts. Doing it manually breaks Zen mode, because
    // `HintManager.onLevelCleared` is what decides whether a clear counts against
    // the Challenge tally or the Zen one — bypassing it let Zen clears (which have
    // no modifiers and half points) farm Challenge-side trails and achievements.
    //
    // ProgressGuard.saveLevel is forward-only and refuses to write during a daily
    // challenge, so a daily run can no longer overwrite free-play progress.
    if (!_playDailyMode) {
      await ProgressGuard.saveLevel('kakuro', _currentLevel + 1, isDaily: false);
      await HintManager.onLevelCleared(
        'kakuro',
        // Speed Demon: cleared a hard-timer level with more than half the
        // clock still left. _initialTime is 0 unless the timer modifier ran.
        isSpeedDemon: _initialTime > 0 && _timeLeft * 2 > _initialTime,
      );
      // The base award is HintManager.onLevelCleared's own 10 points — do not
      // add another flat amount on top. The extra 5 that Grid Path, Star Battle
      // and the rest grant is a SPEED BONUS, gated on beating the timer, not a
      // per-clear payment. Granting it unconditionally would make every Kakuro
      // clear worth more than the same clear in any other game.
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

  void _showHint() async {
    if (_selectedIdx == -1 || _types[_selectedIdx] != 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an empty cell first!')),
      );
      return;
    }

    final hints = await HintManager.getHints('kakuro');
    if (hints > 0) {
      await HintManager.useHint('kakuro');
      setState(() {
        _grid[_selectedIdx] = _solution[_selectedIdx];
      });
    } else {
      BuyHintsDialog.show(context, initialGameId: 'kakuro', onPurchaseComplete: () {
        setState(() {});
      });
    }
  }

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.bgCard,
        title: Text(
          'How to Play Kakuro',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary),
        ),
        content: Text(
          '1. Fill the empty white cells with digits 1-9.\n\n'
          '2. The sum of each horizontal block must equal the clue number to its left.\n\n'
          '3. The sum of each vertical block must equal the clue number above it.\n\n'
          '4. No digit can be repeated within a single run (row or column block).',
          style: GoogleFonts.outfit(color: context.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Got it',
              style: GoogleFonts.outfit(color: AppTheme.dustyMauve, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.bgDark,
        body: const Center(child: CircularProgressIndicator(color: AppTheme.dustyMauve)),
      );
    }

    final double boardSize = MediaQuery.of(context).size.width * 0.85;

    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: const GameTitle('Kakuro'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), tooltip: 'Back', onPressed: () => Navigator.pop(context)),
        // With the `timer` modifier running, back + info + hint + countdown +
        // level chip ran 21px off the right edge of a 320px phone. The layout
        // test never caught it because it only booted level 0, where no timer
        // is on screen. Two default-width IconButtons are 96px of a 320px bar,
        // so they are compact here and the countdown carries no padding of its
        // own. Nothing is hidden — remember.md E2 section 7 keeps the actions
        // list short precisely so it does not come to this.
        actionsIconTheme: const IconThemeData(size: 20),
        actions: [
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            icon: const Icon(Icons.info_outline, color: AppTheme.dustyMauve),
            tooltip: 'Instructions',
            onPressed: _showInstructions,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            icon: const Icon(Icons.lightbulb_outline, color: AppTheme.dustyMauve),
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
                    Icon(
                      Icons.timer,
                      color: _timeLeft <= 10 ? Colors.red : Colors.amber,
                      size: 16,
                    ),
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
          // else on the screen may show the level. See remember.md section E2 §7.
          GameLevelChip(
            level: _currentLevel + 1,
            modeLabel: _playDailyMode ? 'Daily' : null,
            accent: AppTheme.accentFor('kakuro'),
            onTap: kDebugMode ? _showJumpToLevelDialog : null,
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double maxBoardSide = min(
                  constraints.maxWidth * 0.88,
                  max(200.0, constraints.maxHeight - 200.0),
                );

                return Column(
                  children: [
                    Text(
                      'Fill entry cells with digits 1-9 to match clues.',
                      style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    if (_modifierBannerText.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _modifierBannerText,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.warmAmber,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Center(
                        // `zoom`: the board becomes pan/zoomable. Genuinely useful
                        // on an 8x8, where cells and their clue digits get small.
                        // Wrapping rather than replacing keeps every gesture inside
                        // the grid working unchanged.
                        child: _ZoomWrap(
                          enabled: _isZoomActive,
                          child: RepaintBoundary(
                          child: Container(
                            width: maxBoardSide,
                            height: maxBoardSide,
                            decoration: BoxDecoration(
                              color: context.bgCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: context.textMuted.withAlpha(40)),
                            ),
                            child: FogOverlay(
                              enabled: _isFogActive,
                              radius: (maxBoardSide / _gridSize) * _dailyRadius,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: GridView.builder(
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: _gridSize,
                                    crossAxisSpacing: 2,
                                    mainAxisSpacing: 2,
                                  ),
                                  itemCount: _gridSize * _gridSize,
                                  itemBuilder: (context, idx) {
                                    int type = _types[idx];
                                    if (type == 0) {
                                      // Solid slate wall
                                      return Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF181A1F),
                                          border: Border.all(color: Colors.black26, width: 0.5),
                                        ),
                                      );
                                    }

                                    if (type == 2) {
                                      // Clue cell. Under `decay` the ink fades
                                      // on a clock and a tap brings it back —
                                      // the clue values themselves are never
                                      // touched, so validation and the solver
                                      // still see the true board.
                                      return GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () => _tapClue(idx),
                                        child: CustomPaint(
                                          painter: _KakuroCluePainter(
                                            rightSum: _hClues[idx],
                                            downSum: _vClues[idx],
                                            lineColor: AppTheme.dustyMauve,
                                            textColor: Colors.white,
                                            clueOpacity: _decay.opacityFor(idx),
                                          ),
                                        ),
                                      );
                                    }

                                    // Entry cell (type == 1)
                                    bool isSelected = idx == _selectedIdx;
                                    bool isHinted = idx == _hintIdx;
                                    int val = _grid[idx];

                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedIdx = idx;
                                        });
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 150),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppTheme.dustyMauve.withAlpha(40)
                                              : (isHinted ? Colors.amber.withAlpha(40) : context.bgCard),
                                          border: Border.all(
                                            color: isSelected
                                                ? AppTheme.dustyMauve
                                                : (isHinted
                                                    ? Colors.amber
                                                    : context.textMuted.withAlpha(40)),
                                            width: isSelected || isHinted ? 2 : 0.5,
                                          ),
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: AppTheme.dustyMauve.withAlpha(60),
                                                    blurRadius: 6,
                                                  )
                                                ]
                                              : null,
                                        ),
                                        child: Center(
                                          child: Text(
                                            val == 0 ? '' : '$val',
                                            style: GoogleFonts.spaceGrotesk(
                                              fontSize: _gridSize == 4 ? 22 : 18,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected ? AppTheme.dustyMauve : context.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Number keypad
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: context.bgCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.textMuted.withAlpha(30)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              for (int i = 1; i <= 5; i++) _buildKeypadButton(i),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              for (int i = 6; i <= 9; i++) _buildKeypadButton(i),
                              _buildEraseButton(),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.bgCard,
                          foregroundColor: context.textPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          setState(() {
                            _grid = List.filled(_gridSize * _gridSize, 0);
                            _selectedIdx = -1;
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (_isSuccess)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.6),
                child: Center(
                  child: _playDailyMode
                      ? ChallengeClearedOverlay(
                          accentColor: AppTheme.dustyMauve,
                          onComplete: () {
                            Navigator.pop(context, true);
                          },
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
                              const Icon(Icons.emoji_events, color: Colors.amber, size: 64),
                              const SizedBox(height: 16),
                              Text(
                                'Level ${_currentLevel + 1} Cleared!',
                                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              AutoNextCountdown(
                                onNext: _nextLevel,
                                accentColor: AppTheme.dustyMauve,
                              ),
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

  void _tryAutoCheck() {
    bool allFilled = true;
    for (int i = 0; i < _types.length; i++) {
      if (_types[i] == 1 && _grid[i] == 0) {
        allFilled = false;
        break;
      }
    }
    if (allFilled) {
      _checkSolution();
    }
  }

  Widget _buildKeypadButton(int val) {
    return GestureDetector(
      onTap: () {
        if (_selectedIdx != -1 && _types[_selectedIdx] == 1) {
          settingsNotifier.hapticTap();
          setState(() {
            _grid[_selectedIdx] = val;
          });
          _tryAutoCheck();
        }
      },
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppTheme.dustyMauve,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '$val',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEraseButton() {
    return GestureDetector(
      onTap: () {
        if (_selectedIdx != -1 && _types[_selectedIdx] == 1) {
          settingsNotifier.hapticTap();
          setState(() {
            _grid[_selectedIdx] = 0;
          });
        }
      },
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.red.shade800,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.backspace_outlined, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _KakuroCluePainter extends CustomPainter {
  final int rightSum; // horizontal run clue (bottom-left triangle)
  final int downSum;  // vertical run clue (top-right triangle)
  final Color lineColor;
  final Color textColor;

  /// `decay`: how readable this clue currently is, 1.0 down to
  /// [kDecayFloorOpacity]. Only the ink fades — the wall behind it stays solid,
  /// so a faded clue is still visibly a clue cell the player can find and tap.
  /// The clue *values* are never touched.
  final double clueOpacity;

  const _KakuroCluePainter({
    required this.rightSum,
    required this.downSum,
    required this.lineColor,
    required this.textColor,
    this.clueOpacity = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Fill the entire cell with a solid dark grey/slate wall color
    final Paint bgPaint = Paint()
      ..color = const Color(0xFF181A1F)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final bool hasClues = rightSum > 0 || downSum > 0;
    final Color ink = textColor.withValues(alpha: clueOpacity);

    if (hasClues) {
      // Draw slightly darker shading for the bottom-left triangle to give depth split
      final Path path = Path()
        ..moveTo(0, 0)
        ..lineTo(0, size.height)
        ..lineTo(size.width, size.height)
        ..close();
      final Paint fillPaint = Paint()
        ..color = const Color(0xFF111317)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);

      // Draw the diagonal divider line
      final Paint lp = Paint()
        ..color = lineColor.withValues(alpha: 0.6 * clueOpacity)
        ..strokeWidth = 1.5
        ..isAntiAlias = true;
      canvas.drawLine(Offset.zero, Offset(size.width, size.height), lp);

      final double fontSize = size.shortestSide * 0.22;

      // rightSum: horizontal clue (top-right triangle in Kakuro)
      if (rightSum > 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: '$rightSum',
            style: GoogleFonts.spaceGrotesk(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: ink,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final double cx = size.width * 0.75 - tp.width / 2;
        final double cy = size.height * 0.25 - tp.height / 2;
        tp.paint(canvas, Offset(cx, cy));
      }

      // downSum: vertical clue (bottom-left triangle in Kakuro)
      if (downSum > 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: '$downSum',
            style: GoogleFonts.spaceGrotesk(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: ink,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final double cx = size.width * 0.25 - tp.width / 2;
        final double cy = size.height * 0.75 - tp.height / 2;
        tp.paint(canvas, Offset(cx, cy));
      }
    }

    // Draw a subtle border around the clue cell for neat grid alignment
    final Paint borderPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), borderPaint);
  }

  @override
  bool shouldRepaint(covariant _KakuroCluePainter old) =>
      old.rightSum != rightSum ||
      old.downSum != downSum ||
      old.lineColor != lineColor ||
      old.textColor != textColor ||
      old.clueOpacity != clueOpacity;
}

/// Wraps the board in an [InteractiveViewer] only when the `zoom` modifier is
/// active. Kept as a separate widget so the non-zoom path has no extra layers.
class _ZoomWrap extends StatelessWidget {
  final bool enabled;
  final Widget child;

  const _ZoomWrap({required this.enabled, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return InteractiveViewer(
      minScale: 1.0,
      maxScale: 3.0,
      // Clip so a zoomed board cannot paint over the keypad below it.
      clipBehavior: Clip.hardEdge,
      child: child,
    );
  }
}
