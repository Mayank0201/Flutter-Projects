import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../utils/audio_manager.dart';
import '../../../utils/hint_manager.dart';
import '../../../utils/point_manager.dart';
import '../../../utils/prefs_keys.dart';
import '../../../utils/progress_guard.dart';
import '../../../utils/rotation_engine.dart';
import '../../../widgets/auto_next_countdown.dart';
import '../../../widgets/buy_hints_dialog.dart';
import '../../../widgets/challenge_cleared_overlay.dart';
import '../../../widgets/game_level_chip.dart';
import 'untangle_logic.dart';

/// Untangle — drag nodes until no two lines cross.
///
/// The project's first `CustomPainter`, and deliberately the gentlest possible
/// one: [_WebPainter] is a `drawLine` loop and nothing more. Nodes stay ordinary
/// widgets so dragging is plain `GestureDetector`, not hit-testing inside a
/// canvas. One Stroke in 2.4 builds on these patterns.
class UntangleScreen extends StatefulWidget {
  const UntangleScreen({super.key});

  @override
  State<UntangleScreen> createState() => _UntangleScreenState();
}

class _UntangleScreenState extends State<UntangleScreen> {
  static const String _gameId = 'untangle';

  int _currentLevel = 0;
  bool _isLoading = true;
  bool _isSuccess = false;

  bool _playDailyMode = false;
  String _dailyModifierType = '';
  Set<String> _activeModifiers = {};

  UntangleBoard? _board;

  /// Live node positions in 0..1 space. Starts as the board's dealt scramble and
  /// is what the player actually moves.
  List<Point<double>> _live = const [];

  /// Cached crossing state. Recomputed only when a node moves, never inside
  /// `build` — the scan is O(E^2) and at the largest board that is 1,326 pair
  /// tests, which is nothing once per drag update and wasteful every frame.
  Set<int> _badEdges = const {};
  int _crossings = 0;

  int _draggingNode = -1;

  Timer? _gameTimer;
  int _timeLeft = -1;
  // Timer value at the moment the hard timer started; 0 when no timer ran.
  // Only used for the Speed Demon achievement check on clear.
  int _initialTime = 0;

  /// True when modifier [name] applies, in daily or free play.
  ///
  /// One choke point, so a pooled modifier can never be selected and then
  /// silently do nothing, and so nothing is daily-only (remember.md §8).
  bool _isModActive(String name) {
    if (_playDailyMode) return _dailyModifierType == name;
    return _modsOn && _activeModifiers.contains(name);
  }

  bool get _modsOn =>
      !_playDailyMode && RotationEngine.hasModifiers(_gameId, _currentLevel);

  @override
  void initState() {
    super.initState();
    _loadProgressAndGenerate();
  }

  @override
  void dispose() {
    // The `timer` modifier's tick calls setState. Without this it keeps firing
    // after the player leaves and setStates a disposed widget every second.
    _gameTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProgressAndGenerate() async {
    final prefs = await SharedPreferences.getInstance();
    _playDailyMode = prefs.getBool(PrefsKeys.playDailyMode) ?? false;
    _dailyModifierType =
        _playDailyMode ? (prefs.getString(PrefsKeys.dailyModifierType) ?? '') : '';

    final level = prefs.getInt(PrefsKeys.gameLevel(_gameId)) ?? 0;
    if (!mounted) return;
    setState(() {
      _currentLevel = level;
      _isLoading = true;
    });
    _generatePuzzle();
  }

  void _generatePuzzle() {
    _gameTimer?.cancel();

    _activeModifiers = _modsOn
        ? RotationEngine.getActiveModifiers(
            gameId: _gameId,
            levelIndex: _currentLevel,
            pool: const ['timer', 'fog', 'shy', 'mirror'],
            minActive: 1,
            maxActive: 2,
            smallGrid: UntangleLogic.sideFor(_currentLevel) <= 3,
          )
        : {};

    final board = UntangleLogic.generate(
      RotationEngine.getDeterminism(_gameId, _currentLevel),
      _currentLevel,
    );

    _board = board;
    _live = List<Point<double>>.from(board.nodes);
    _recomputeCrossings();

    setState(() {
      _isSuccess = false;
      _isLoading = false;
    });

    // `timer`: pure time pressure. It cannot make a board unsolvable, which is
    // why it is safe on a game whose difficulty is already geometric.
    if (_isModActive('timer')) {
      _timeLeft = 45 + board.nodeCount * 3;
      _initialTime = _timeLeft;
      _gameTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() {
          if (_timeLeft > 0) {
            _timeLeft--;
          } else {
            t.cancel();
            _restartLevel();
          }
        });
      });
    } else {
      _timeLeft = -1;
    }
  }

  void _recomputeCrossings() {
    final board = _board;
    if (board == null) return;
    _badEdges = UntangleLogic.crossingEdges(board.edges, _live);
    _crossings = UntangleLogic.crossingCount(board.edges, _live);
  }

  void _restartLevel() {
    final board = _board;
    if (board == null) return;
    setState(() {
      _live = List<Point<double>>.from(board.nodes);
      _recomputeCrossings();
      _isSuccess = false;
    });
  }

  Future<void> _onSolved() async {
    _gameTimer?.cancel();
    settingsNotifier.hapticSuccess();
    AudioManager.playSuccess();

    if (!_playDailyMode) {
      await ProgressGuard.saveLevel(_gameId, _currentLevel + 1, isDaily: false);
      await HintManager.onLevelCleared(
        _gameId,
        // Speed Demon: cleared a hard-timer level with more than half the
        // clock still left. _initialTime is 0 unless the timer modifier ran.
        isSpeedDemon: _initialTime > 0 && _timeLeft * 2 > _initialTime,
      );
      // HintManager.onLevelCleared already pays the base 10. The extra 5 is a
      // SPEED BONUS for beating the timer, not a flat per-clear payment — so it
      // is gated. Paying it unconditionally is what over-rewarded two games in
      // an earlier release.
      if (_timeLeft > 0) {
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

  Future<void> _useHint() async {
    final board = _board;
    if (board == null || _isSuccess) return;

    final hints = await HintManager.getHints(_gameId);
    if (hints <= 0) {
      if (mounted) {
        await BuyHintsDialog.show(context,
            initialGameId: _gameId, isFromGameScreen: true);
      }
      return;
    }

    // Move one node that is currently in a crossing to its solved position.
    // Never a node that is already correct — a hint the player paid for must
    // change something.
    final candidates = <int>{};
    for (final index in _badEdges) {
      candidates..add(board.edges[index].a)..add(board.edges[index].b);
    }
    final target = candidates.firstWhere(
      (i) => _live[i] != board.solved[i],
      orElse: () => -1,
    );
    if (target < 0) return;

    await HintManager.useHint(_gameId);
    settingsNotifier.hapticTap();
    setState(() {
      _live[target] = board.solved[target];
      _recomputeCrossings();
    });
    if (_crossings == 0) _onSolved();
  }

  /// Debug-only level jump; `GameLevelChip` only wires it up under `kDebugMode`.
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
            onChanged: (v) => target = int.tryParse(v) ?? target,
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

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.bgCard,
        title: Text('How to play',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, color: context.textPrimary)),
        content: Text(
          'Drag the dots until no two lines cross.\n\n'
          'Crossing lines are shown in terracotta; clean lines in sage. '
          'Every board can always be untangled — the layout it was built from '
          'has no crossings at all.',
          style: GoogleFonts.outfit(color: context.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it',
                style: GoogleFonts.outfit(color: AppTheme.dustyMauve)),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final board = _board;
    if (_isLoading || board == null) {
      return Scaffold(
        backgroundColor: context.bgDark,
        body: const Center(
            child: CircularProgressIndicator(color: AppTheme.dustyMauve)),
      );
    }

    final accent = AppTheme.accentFor(_gameId);

    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: const GameTitle('Untangle'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'How to play',
            icon: const Icon(Icons.info_outline, color: AppTheme.dustyMauve),
            onPressed: _showInstructions,
          ),
          IconButton(
            tooltip: 'Hint',
            icon: const Icon(Icons.lightbulb_outline,
                color: AppTheme.dustyMauve),
            onPressed: _useHint,
          ),
          // Standard level indicator, last in actions. Nothing else on screen
          // shows the level (remember.md §7).
          GameLevelChip(
            level: _currentLevel + 1,
            modeLabel: _playDailyMode ? 'Daily' : null,
            accent: accent,
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
                _buildStatusRow(accent),
                const SizedBox(height: 12),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      // Square board sized from BOTH axes. Sizing from width
                      // alone is what overflowed Hitori by 908px and Slitherlink
                      // off the bottom of the screen; the layout harness cannot
                      // see it on a portrait viewport.
                      final side = min(box.maxWidth, box.maxHeight);
                      return Center(
                        child: SizedBox(
                          width: side,
                          height: side,
                          child: _buildBoard(board, side, accent),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.spaceEvenly,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _restartLevel,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Restart'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isSuccess)
            Positioned.fill(
              child: Container(
                color: Colors.black.withAlpha(150),
                child: Center(
                  child: _playDailyMode
                      ? ChallengeClearedOverlay(
                          accentColor: accent,
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
                                  color: AppTheme.warmAmber, size: 56),
                              const SizedBox(height: 12),
                              Text(
                                'Untangled!',
                                style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: context.textPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              AutoNextCountdown(
                                onNext: _nextLevel,
                                accentColor: accent,
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

  /// Crossing counter plus a chip for every modifier that is actually running.
  ///
  /// A `Wrap`, not a `Row`: four separate modifier chips overflowed their rows
  /// in the previous release, one by 260px, and every one had passed its own
  /// unit tests.
  Widget _buildStatusRow(Color accent) {
    final chips = <Widget>[
      _chip(
        _crossings == 0 ? 'No crossings' : '$_crossings crossing'
            '${_crossings == 1 ? '' : 's'}',
        _crossings == 0 ? AppTheme.softSage : AppTheme.terracotta,
      ),
      if (_isModActive('timer'))
        _chip('Timer ${_timeLeft}s',
            _timeLeft <= 10 ? AppTheme.terracotta : accent),
      if (_isModActive('fog')) _chip('Fog', accent),
      if (_isModActive('shy')) _chip('Shy Lines', accent),
      if (_isModActive('mirror')) _chip('Mirrored', accent),
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: chips,
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
              fontSize: 12, fontWeight: FontWeight.w600, color: color),
        ),
      );

  Widget _buildBoard(UntangleBoard board, double side, Color accent) {
    const nodeSize = 26.0;

    // `fog`: only lines touching the node being dragged are drawn. `shy`: lines
    // fade unless they are crossing. Both are render-only — the geometry and the
    // win condition are untouched, so neither can make a board unwinnable.
    final fog = _isModActive('fog');
    final shy = _isModActive('shy');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.textMuted.withValues(alpha: 0.16)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _WebPainter(
                  edges: board.edges,
                  points: _live,
                  badEdges: _badEdges,
                  clean: AppTheme.softSage,
                  crossing: AppTheme.terracotta,
                  fogAround: fog ? _draggingNode : -2,
                  shy: shy,
                ),
              ),
            ),
          ),
          for (var i = 0; i < _live.length; i++)
            Positioned(
              left: _live[i].x * side - nodeSize / 2,
              top: _live[i].y * side - nodeSize / 2,
              width: nodeSize,
              height: nodeSize,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => setState(() => _draggingNode = i),
                onPanUpdate: (d) => _onDrag(i, d.delta, side),
                onPanEnd: (_) => _onDragEnd(),
                onPanCancel: _onDragEnd,
                child: Center(
                  child: Container(
                    width: _draggingNode == i ? 20 : 16,
                    height: _draggingNode == i ? 20 : 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent,
                      border: Border.all(color: context.bgCard, width: 2),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _onDrag(int index, Offset delta, double side) {
    if (_isSuccess) return;
    // `mirror`: the drag is negated. The board is untouched, so solvability is
    // provably unchanged — only the control is inverted.
    final sign = _isModActive('mirror') ? -1.0 : 1.0;
    final next = Point<double>(
      (_live[index].x + sign * delta.dx / side).clamp(0.03, 0.97),
      (_live[index].y + sign * delta.dy / side).clamp(0.03, 0.97),
    );
    setState(() {
      _live[index] = next;
      _recomputeCrossings();
    });
  }

  void _onDragEnd() {
    setState(() => _draggingNode = -1);
    if (!_isSuccess && _crossings == 0) _onSolved();
  }
}

/// The whole painter. A `drawLine` loop — deliberately the gentlest possible
/// introduction to `CustomPaint`, since One Stroke in 2.4 needs these patterns.
class _WebPainter extends CustomPainter {
  final List<Edge> edges;
  final List<Point<double>> points;
  final Set<int> badEdges;
  final Color clean;
  final Color crossing;

  /// When >= -1, only edges touching this node are drawn (the `fog` modifier);
  /// -1 means "dragging nothing", so nothing is drawn. -2 disables fog.
  final int fogAround;

  /// Fade non-crossing edges (the `shy` modifier).
  final bool shy;

  _WebPainter({
    required this.edges,
    required this.points,
    required this.badEdges,
    required this.clean,
    required this.crossing,
    required this.fogAround,
    required this.shy,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < edges.length; i++) {
      final isBad = badEdges.contains(i);

      if (fogAround != -2) {
        final e = edges[i];
        if (e.a != fogAround && e.b != fogAround) continue;
      }

      paint.color = isBad
          ? crossing
          : (shy ? clean.withValues(alpha: 0.18) : clean);

      final a = points[edges[i].a];
      final b = points[edges[i].b];
      canvas.drawLine(
        Offset(a.x * size.width, a.y * size.height),
        Offset(b.x * size.width, b.y * size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WebPainter old) =>
      old.points != points ||
      old.badEdges != badEdges ||
      old.fogAround != fogAround ||
      old.shy != shy;
}
