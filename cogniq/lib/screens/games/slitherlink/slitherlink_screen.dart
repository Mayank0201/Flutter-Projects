import 'dart:async';
import 'dart:math';
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
import '../../../utils/prefs_keys.dart';
import '../../../utils/hint_manager.dart';
import '../../../utils/progress_guard.dart';
import '../../../utils/rotation_engine.dart';
import '../../../widgets/game_level_chip.dart';
import '../../../widgets/decaying_clue.dart';
import 'slitherlink_logic.dart';

/// Slitherlink's free-play modifier pool.
///
/// Exported so test/modifier_batch2_test.dart checks the pool the screen really
/// uses rather than a copy that can drift.
///
/// `decay` is the fourth entry, and the reason the pool is no longer three:
/// with three, the pairs tier has only three combinations to spread over its
/// 35-level span. It is also a natural fit — the numbers in these cells are
/// literally the clues, and `decay` never removes one. Half the clues are
/// already hidden at generation time; `decay` does not touch that set and does
/// not hide any more, it only makes the surviving ink faint until it is tapped,
/// so the board's clue count — which is load-bearing here — is unchanged.
const List<String> kSlitherlinkModifierPool = [
  'timer',
  'fog',
  'zoom',
  'decay',
];

class SlitherlinkScreen extends StatefulWidget {
  const SlitherlinkScreen({super.key});

  @override
  State<SlitherlinkScreen> createState() => _SlitherlinkScreenState();
}

class _SlitherlinkScreenState extends State<SlitherlinkScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  bool _playDailyMode = false;
  String _dailyModifierType = '';
  Set<String> _activeModifiers = {};
  Timer? _gameTimer;
  int _timeLeft = -1;

  /// True when modifier [name] applies, in daily or free play. One choke point,
  /// so a pooled modifier can never be selected yet silently do nothing
  /// (remember.md E2 section 8).
  bool _isModActive(String name) {
    if (_playDailyMode) return _dailyModifierType == name;
    return _modsOn && _activeModifiers.contains(name);
  }

  bool get _modsOn =>
      !_playDailyMode &&
      RotationEngine.hasModifiers('slitherlink', _currentLevel);
  double _dailyRadius = 1.5;
  int _gridSize = 3; // 3, 4, or 5 cells

  List<int> _clues = []; // -1 for empty/hidden clue
  List<int> _edges = []; // 0: none, 1: line, 2: X
  List<bool> _solution = []; // Correct solution edge mask (true = line)

  bool _isLoading = true;

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
    // The `timer` modifier's periodic tick calls setState. Without this it keeps
    // firing after the player leaves the screen, so it setStates a disposed
    // widget every second for the rest of the session. The same is true of the
    // `decay` clock.
    _gameTimer?.cancel();
    _decay.dispose();
    super.dispose();
  }

  /// `decay`: bring a faded clue back for a few seconds. Free on an untimed
  /// level, two seconds off the clock on a timed one — never points. See the
  /// note in widgets/decaying_clue.dart.
  void _tapClue(int cellIdx) {
    if (!_isModActive('decay')) return;
    if (!_decay.reveal(cellIdx)) return;
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
      _dailyRadius = 1.5;
    }

    int level = prefs.getInt(PrefsKeys.gameLevel('slitherlink')) ?? 0;
    if (mounted) {
      setState(() {
        _currentLevel = level;
        _isLoading = true;
      });
      _generatePuzzle();
    }
  }

  /// Debug-only level jump; `GameLevelChip` only wires it up under `kDebugMode`.
  void _showJumpToLevelDialog() {
    showDialog(
      context: context,
      builder: (context) {
        int target = _currentLevel + 1;
        return AlertDialog(
          backgroundColor: context.bgCard,
          title: Text(
            'Jump to Level',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
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
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(color: context.textSecondary),
              ),
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
              child: Text(
                'Jump',
                style: GoogleFonts.outfit(color: AppTheme.dustyMauve),
              ),
            ),
          ],
        );
      },
    );
  }

  void _generatePuzzle() {
    // Generation lives in slitherlink_logic.dart so it can be unit-tested — see
    // test/slitherlink_logic_test.dart.
    //
    // The defect recorded in the release plan was WRONG. It blamed a
    // "stuck-growth fallback that force-adds a hole". That branch exists, but
    // simulating the original generator over 9,000 boards it never once fired.
    //
    // The real defect was a DIAGONAL PINCH: two cells touching only at a corner
    // pass the edge-connectivity test while making the boundary cross itself,
    // giving a degree-4 vertex. This screen's own win check rejects any vertex
    // whose degree is not 0 or 2 — so those boards stored a solution the game
    // itself would refuse. Measured: 0% at 3x3, 0.7% at 4x4, 2.4% at 5x5.
    //
    // Filtering pinches during growth cuts it to 0.43%; gating on the derived
    // edges actually passing isSingleLoop takes it to zero, which is what the
    // logic file does.
    if (_modsOn) {
      _activeModifiers = RotationEngine.getActiveModifiers(
        gameId: 'slitherlink',
        levelIndex: _currentLevel,
        pool: kSlitherlinkModifierPool,
        minActive: 1,
        maxActive: 2,
        smallGrid: _gridSize <= 3,
      );
    } else {
      _activeModifiers = {};
    }

    final board = SlitherlinkLogic.generate(
      RotationEngine.getDeterminism('slitherlink', _currentLevel),
      _currentLevel,
    );

    _gridSize = board.size;
    _solution = board.solution;
    _edges = List.filled(board.solution.length, 0);
    _clues = List<int>.from(board.clues);

    // Hide roughly half the clues. Salted so the hidden set is independent of
    // the board draw, and seeded so a level always hides the same clues.
    final hideRng = RotationEngine.getDeterminism(
      'slitherlink_clues',
      _currentLevel,
    );
    final hideCount = (_gridSize * _gridSize) ~/ 2;
    final indices = List<int>.generate(_gridSize * _gridSize, (i) => i)
      ..shuffle(hideRng);
    for (var i = 0; i < hideCount; i++) {
      _clues[indices[i]] = -1;
    }

    setState(() {
      _isSuccess = false;
      _isLoading = false;
    });

    // `decay`: restart the fade clock, or make sure it is not running. stop()
    // also clears the per-clue reveal times, so a clue re-revealed on the last
    // level does not start this one already faded.
    if (_isModActive('decay')) {
      _decay.start();
    } else {
      _decay.stop();
    }

    // `timer`: a countdown that restarts the level at zero. Pure time pressure —
    // it cannot make a board unsolvable, which is why it is the safe third pool
    // entry for a game whose clue count is load-bearing.
    _gameTimer?.cancel();
    _timeLeft = -1;
    if (_isModActive('timer')) {
      _timeLeft = 45 + _gridSize * 20;
      _gameTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() {
          if (_timeLeft > 0) {
            _timeLeft--;
          } else {
            t.cancel();
            _generatePuzzle();
          }
        });
      });
    }
  }

  int _countCellEdgesInPlayerGrid(int cellIdx) {
    int r = cellIdx ~/ _gridSize;
    int c = cellIdx % _gridSize;
    final numH = (_gridSize + 1) * _gridSize;

    int topEdge = r * _gridSize + c;
    int bottomEdge = (r + 1) * _gridSize + c;
    int leftEdge = numH + r * (_gridSize + 1) + c;
    int rightEdge = numH + r * (_gridSize + 1) + c + 1;

    int count = 0;
    if (_edges[topEdge] == 1) count++;
    if (_edges[bottomEdge] == 1) count++;
    if (_edges[leftEdge] == 1) count++;
    if (_edges[rightEdge] == 1) count++;
    return count;
  }

  bool _validateLoop() {
    final numVertices = (_gridSize + 1) * (_gridSize + 1);
    final numH = (_gridSize + 1) * _gridSize;

    // 1. Build adjacency list of vertices
    Map<int, List<int>> adj = {};
    for (int i = 0; i < numVertices; i++) adj[i] = [];

    // Horizontal edges
    for (int r = 0; r <= _gridSize; r++) {
      for (int c = 0; c < _gridSize; c++) {
        int idx = r * _gridSize + c;
        if (_edges[idx] == 1) {
          int u = r * (_gridSize + 1) + c;
          int v = r * (_gridSize + 1) + c + 1;
          adj[u]!.add(v);
          adj[v]!.add(u);
        }
      }
    }

    // Vertical edges
    for (int r = 0; r < _gridSize; r++) {
      for (int c = 0; c <= _gridSize; c++) {
        int idx = numH + r * (_gridSize + 1) + c;
        if (_edges[idx] == 1) {
          int u = r * (_gridSize + 1) + c;
          int v = (r + 1) * (_gridSize + 1) + c;
          adj[u]!.add(v);
          adj[v]!.add(u);
        }
      }
    }

    int activeCount = 0;
    int startVertex = -1;
    for (int i = 0; i < numVertices; i++) {
      int deg = adj[i]!.length;
      if (deg != 0 && deg != 2) return false;
      if (deg == 2) {
        activeCount++;
        if (startVertex == -1) startVertex = i;
      }
    }

    if (activeCount == 0) return false;

    // Trace components to ensure it's a single closed loop
    List<bool> visited = List.filled(numVertices, false);
    int curr = startVertex;
    int prev = -1;
    int visitedCount = 0;

    while (curr != -1 && !visited[curr]) {
      visited[curr] = true;
      visitedCount++;
      int next = -1;
      for (int neighbor in adj[curr]!) {
        if (neighbor != prev) {
          next = neighbor;
          break;
        }
      }
      prev = curr;
      curr = next;
    }

    return visitedCount == activeCount && curr == startVertex;
  }

  void _checkSolution() {
    bool isValid = true;

    // Check cell clue counts
    for (int i = 0; i < _gridSize * _gridSize; i++) {
      int clue = _clues[i];
      if (clue >= 0) {
        if (_countCellEdgesInPlayerGrid(i) != clue) {
          isValid = false;
          break;
        }
      }
    }

    if (isValid && _validateLoop()) {
      settingsNotifier.hapticSuccess();
      _onLevelCleared();
    } else {
      settingsNotifier.hapticError();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Edges must match clue counts AND form a single continuous closed loop!',
          ),
        ),
      );
    }
  }

  Future<void> _onLevelCleared() async {
    // Through the shared managers rather than hand-written prefs writes. The old
    // code kept a private `beta_level_slitherlink` key and incremented
    // `globalLevelClearedCount` itself, which bypasses the Zen split inside
    // HintManager.onLevelCleared and lets Zen clears farm Challenge-side trails.
    if (!_playDailyMode) {
      await ProgressGuard.saveLevel(
        'slitherlink',
        _currentLevel + 1,
        isDaily: false,
      );
      await HintManager.onLevelCleared('slitherlink');
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
    int hintCell = -1;
    for (int i = 0; i < _edges.length; i++) {
      int solVal = _solution[i] ? 1 : 0;
      if (_edges[i] != solVal) {
        hintCell = i;
        break;
      }
    }

    if (hintCell != -1) {
      final hints = await HintManager.getHints('slitherlink');
      if (hints > 0) {
        await HintManager.useHint('slitherlink');
        setState(() {
          _edges[hintCell] = _solution[hintCell] ? 1 : 0;
        });
      } else {
        BuyHintsDialog.show(
          context,
          initialGameId: 'slitherlink',
          onPurchaseComplete: () {
            setState(() {});
          },
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The board is already correctly solved!')),
      );
    }
  }

  void _toggleEdge(int idx) {
    settingsNotifier.hapticTap();
    setState(() {
      // Cycle: none (0) -> line (1) -> cross (2) -> none (0)
      _edges[idx] = (_edges[idx] + 1) % 3;
    });
  }

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.bgCard,
        title: Text(
          'How to Play Slitherlink',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
        content: Text(
          '1. Draw a single, continuous, closed loop by connecting adjacent dots with lines.\n\n'
          '2. The loop must NOT cross itself, branch off, or form separate loops.\n\n'
          '3. The numbers inside cells indicate exactly how many of its 4 boundary edges are part of the loop.\n\n'
          '4. Empty cells (without numbers) can have any number of active boundary edges.',
          style: GoogleFonts.outfit(color: context.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Got it',
              style: GoogleFonts.outfit(
                color: AppTheme.dustyMauve,
                fontWeight: FontWeight.bold,
              ),
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
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.dustyMauve),
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: const GameTitle('Slitherlink'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: AppTheme.dustyMauve),
            tooltip: 'Instructions',
            onPressed: _showInstructions,
          ),
          IconButton(
            icon: const Icon(
              Icons.lightbulb_outline,
              color: AppTheme.dustyMauve,
            ),
            tooltip: 'Hint',
            onPressed: _showHint,
          ),
          // Standard level indicator, last in actions. Nothing else on screen
          // shows the level (remember.md E2 section 7).
          GameLevelChip(
            level: _currentLevel + 1,
            modeLabel: _playDailyMode ? 'Daily' : null,
            accent: AppTheme.accentFor('slitherlink'),
            onTap: kDebugMode ? _showJumpToLevelDialog : null,
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      // A proportion of the height it was handed, not a pixel
                      // reserve. A reserve has to predict how many rows the hint
                      // line and the guide card wrap to, and that changes with
                      // width, font scale, locale and whether a modifier chip is
                      // showing — mispredicting it by 72px is exactly how Hitori
                      // shipped a 106px overflow. A ratio cannot drift that way.
                      //
                      // The scroll view below is what makes overflow structurally
                      // impossible; this only decides how much of the guide card
                      // you can read before scrolling.
                      final double boardSize = min(
                        box.maxWidth,
                        box.maxHeight * 0.7,
                      );
                      // Centre when there is room, scroll when there is not.
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: box.maxHeight),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Tap between dots to toggle: Line ➔ Cross (X) ➔ Empty.',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    color: context.textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                // `decay` is announced as well as applied. Its
                                // own wrapping Text row inside the scroll view,
                                // so it cannot overflow at any viewport.
                                if (_isModActive('decay'))
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Fading Clues: clues dim over time — tap '
                                      'one to read it again',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.warmAmber,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                const SizedBox(height: 24),
                                RepaintBoundary(
                                  child: _ZoomWrap(
                                    enabled: _isModActive('zoom'),
                                    child: Container(
                                      width: boardSize,
                                      height: boardSize,
                                      decoration: BoxDecoration(
                                        color: context.bgCard,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: context.textMuted.withAlpha(
                                            40,
                                          ),
                                        ),
                                      ),
                                      child: FogOverlay(
                                        enabled: _isModActive('fog'),
                                        radius:
                                            (boardSize / _gridSize) *
                                            _dailyRadius,
                                        child: LayoutBuilder(
                                          builder: (context, constraints) {
                                            final double cellSpacing =
                                                constraints.maxWidth /
                                                _gridSize;
                                            final numH =
                                                (_gridSize + 1) * _gridSize;

                                            return Stack(
                                              clipBehavior: Clip.none,
                                              children: [
                                                // 1. Clue Numbers Inside Cells
                                                for (
                                                  int i = 0;
                                                  i < _gridSize * _gridSize;
                                                  i++
                                                ) ...[
                                                  if (_clues[i] >= 0)
                                                    Positioned(
                                                      left:
                                                          (i % _gridSize) *
                                                          cellSpacing,
                                                      top:
                                                          (i ~/ _gridSize) *
                                                          cellSpacing,
                                                      width: cellSpacing,
                                                      height: cellSpacing,
                                                      // Under `decay` the clue
                                                      // ink fades on a clock and
                                                      // a tap in the middle of
                                                      // the cell brings it back.
                                                      // `_clues` itself is never
                                                      // touched, so the win check
                                                      // still reads true values.
                                                      child: GestureDetector(
                                                        onTap: () => _tapClue(i),
                                                        child: Center(
                                                          child: AnimatedOpacity(
                                                            opacity: _decay
                                                                .opacityFor(i),
                                                            duration:
                                                                const Duration(
                                                                    milliseconds:
                                                                        400),
                                                            child: Text(
                                                          '${_clues[i]}',
                                                          style:
                                                              GoogleFonts.spaceGrotesk(
                                                                fontSize:
                                                                    _gridSize ==
                                                                        3
                                                                    ? 20
                                                                    : 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: AppTheme
                                                                    .dustyMauve,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                ],

                                                // 2. Horizontal Interactive Edges
                                                for (
                                                  int r = 0;
                                                  r <= _gridSize;
                                                  r++
                                                )
                                                  for (
                                                    int c = 0;
                                                    c < _gridSize;
                                                    c++
                                                  )
                                                    Positioned(
                                                      left: c * cellSpacing + 6,
                                                      top: r * cellSpacing - 12,
                                                      width: cellSpacing - 12,
                                                      height: 24,
                                                      child: GestureDetector(
                                                        behavior:
                                                            HitTestBehavior
                                                                .opaque,
                                                        onTap: () =>
                                                            _toggleEdge(
                                                              r * _gridSize + c,
                                                            ),
                                                        child: _buildEdgeVisual(
                                                          r * _gridSize + c,
                                                          isHorizontal: true,
                                                        ),
                                                      ),
                                                    ),

                                                // 3. Vertical Interactive Edges
                                                for (
                                                  int r = 0;
                                                  r < _gridSize;
                                                  r++
                                                )
                                                  for (
                                                    int c = 0;
                                                    c <= _gridSize;
                                                    c++
                                                  )
                                                    Positioned(
                                                      left:
                                                          c * cellSpacing - 12,
                                                      top: r * cellSpacing + 6,
                                                      width: 24,
                                                      height: cellSpacing - 12,
                                                      child: GestureDetector(
                                                        behavior:
                                                            HitTestBehavior
                                                                .opaque,
                                                        onTap: () => _toggleEdge(
                                                          numH +
                                                              r *
                                                                  (_gridSize +
                                                                      1) +
                                                              c,
                                                        ),
                                                        child: _buildEdgeVisual(
                                                          numH +
                                                              r *
                                                                  (_gridSize +
                                                                      1) +
                                                              c,
                                                          isHorizontal: false,
                                                        ),
                                                      ),
                                                    ),

                                                // 4. Dot Grid Vertices
                                                for (
                                                  int r = 0;
                                                  r <= _gridSize;
                                                  r++
                                                )
                                                  for (
                                                    int c = 0;
                                                    c <= _gridSize;
                                                    c++
                                                  )
                                                    Positioned(
                                                      left: c * cellSpacing - 4,
                                                      top: r * cellSpacing - 4,
                                                      width: 8,
                                                      height: 8,
                                                      child: Container(
                                                        decoration:
                                                            const BoxDecoration(
                                                              color:
                                                                  Colors.white,
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                      ),
                                                    ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: context.bgCard,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: context.textMuted.withAlpha(20),
                                    ),
                                  ),
                                  child: Text(
                                    '💡 Click cycle:\n'
                                    '• One Tap: Places a line boundary.\n'
                                    '• Two Taps: Places an X (indicating no loop line here).\n'
                                    '• Three Taps: Resets back to empty.',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      color: context.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Wrap, not Row: at 320px the two buttons are 1px too wide
                // together and a Row clips instead of reflowing. 1px still
                // paints a striped bar in debug and silently clips in release.
                Wrap(
                  alignment: WrapAlignment.spaceEvenly,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.bgCard,
                        foregroundColor: context.textPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _edges = List.filled(_edges.length, 0);
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset'),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.dustyMauve,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      onPressed: _checkSolution,
                      icon: const Icon(Icons.check),
                      label: const Text('Check'),
                    ),
                  ],
                ),
              ],
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
                              const Icon(
                                Icons.emoji_events,
                                color: Colors.amber,
                                size: 64,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Level ${_currentLevel + 1} Cleared!',
                                style: GoogleFonts.outfit(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
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

  Widget _buildEdgeVisual(int idx, {required bool isHorizontal}) {
    final edgeState = _edges[idx];
    Color lineColor = Colors.transparent;
    if (edgeState == 1) {
      lineColor = Colors.amber;
    } else if (edgeState == 0) {
      lineColor = Colors.grey.shade800.withAlpha(80);
    }

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: isHorizontal ? double.infinity : 4,
            height: isHorizontal ? 4 : double.infinity,
            color: lineColor,
          ),
          if (edgeState == 2)
            Text(
              '✕',
              style: TextStyle(
                color: Colors.red.shade400,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}

/// Wraps the board in an [InteractiveViewer] only while `zoom` is active, so the
/// ordinary path carries no extra layers. Earns its place at 5x5, where the
/// edge-tap targets between cells get small.
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
      clipBehavior: Clip.hardEdge,
      child: child,
    );
  }
}
