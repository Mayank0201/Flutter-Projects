import 'dart:math';
import 'dart:async';
import '../../../utils/rotation_engine.dart';
import '../../../utils/point_manager.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import'../../../theme/app_theme.dart';
import'../../../utils/prefs_keys.dart';
import'../../../utils/hint_manager.dart';
import'../../../utils/audio_manager.dart';
import'../../../widgets/challenge_cleared_overlay.dart';
import'../../../widgets/auto_next_countdown.dart';
import'../../../widgets/buy_hints_dialog.dart';
import'../../../widgets/game_tutorial_dialog.dart';
// Chimp Test: numbers appear, tap 1 to hide them, then tap in order from memory.
// Grid and number count grow each level.
import '../../../utils/shuffle_manager.dart';

class ChimpTestScreen extends StatefulWidget {
  const ChimpTestScreen({super.key});
  @override
  State<ChimpTestScreen> createState() => _ChimpTestScreenState();
}

class _ChimpTestScreenState extends State<ChimpTestScreen> {
  // Level config: (gridSize, numCount)
  static const List<(int, int)> _levels = [
    (3, 4), (3, 5), (3, 6),
    (4, 7), (4, 8), (4, 10),
    (5, 12), (5, 14), (5, 16), (5, 18),
    (5, 20), (6, 22), (6, 24), (6, 26), (6, 28),
    (6, 30), (6, 32), (7, 34), (7, 36), (7, 38),
    (7, 40), (8, 42), (8, 44), (8, 46), (8, 48),
    (8, 50), (9, 52), (9, 54), (9, 56), (9, 60),
  ];

  int _levelIndex = 0;
  late int _gridSize;
  late int _n;
  late Map<int, (int,int)> _positions;
  bool _started = false;   // user tapped 1 → numbers hide
  int _nextToTap = 1;
  bool _won = false;
  bool _failed = false;
  final Set<(int, int)> _glowingCells = {};

  bool _playDailyMode = false;
  String _dailyModifierType = '';
  int _correctTapCount = 0;
  bool _chaosShuffleDone = false;
  bool _exposureTimerFired = false;
  final Set<(int, int)> _decoyCells = {};

  Set<String> _activeModifiers = {};

  int get _chimpCycle => (_levelIndex < _levels.length) ? 0 : ((_levelIndex - _levels.length) ~/ 11);
  bool get _hasTimedExposure {
    if (_playDailyMode) return false;
    if (_levelIndex >= 30) {
      return _activeModifiers.contains('numbersHide') && _levelIndex >= 45;
    }
    return _chimpCycle >= 1;
  }
  bool get _hasPositionShuffle {
    if (_playDailyMode) return false;
    if (_levelIndex >= 30) {
      return _activeModifiers.contains('positionShuffle');
    }
    return _chimpCycle >= 3;
  }
  bool get _hasDecoyTiles => !_playDailyMode && _chimpCycle >= 4;

  bool get _isEndgame {
    if (_playDailyMode) return false;
    if (_levelIndex >= 30) {
      return _activeModifiers.contains('timer');
    }
    return false;
  }
  Timer? _gameTimer;
  int _timeLeft = -1;
  bool _timeBonusEarned = false;

  bool _isHintShowing = false;
  bool _shuffleActive = false;
  int _hintCount = 0;
  bool _isTutorialMode = false;
  bool _tutorialCompleted = false;

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadLevel();
    _loadPersistedLevel();
  }

  Future<void> _loadPersistedLevel() async {
    _hintCount = await HintManager.getHints('chimp');
    final prefs = await SharedPreferences.getInstance();
    _playDailyMode = prefs.getBool(PrefsKeys.playDailyMode) ?? false;
    if (_playDailyMode) {
      _dailyModifierType = prefs.getString(PrefsKeys.dailyModifierType) ?? '';
    } else {
      _dailyModifierType = '';
    }
    final savedLevel = prefs.getInt(PrefsKeys.gameLevel('chimp')) ?? 0;
    final active = await ShuffleManager.isActive();

    _isTutorialMode = false;
    _levelIndex = savedLevel;

    if (mounted) {
      setState(() {
        _shuffleActive = active;
        _loadLevel();
      });
    }
  }

  Future<void> _savePersistedLevel(int lvl) async {
    if (_playDailyMode) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(PrefsKeys.gameLevel('chimp'), lvl);
    final earned = await HintManager.onLevelCleared('chimp');
    final newCount = await HintManager.getHints('chimp');
    setState(() {
      _hintCount = newCount;
    });
    
  }

  Future<void> _useHint() async {
    if (_won || _failed || _hintCount <= 0 || !_started) return;

    await HintManager.useHint('chimp');
    final newCount = await HintManager.getHints('chimp');

    setState(() {
      _hintCount = newCount;
      _isHintShowing = true;
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _isHintShowing = false;
        });
      }
    });
  }

  (int, int) _getChimpConfig(int index) {
    if (index < _levels.length) {
      return _levels[index];
    }
    final cycleLevel = index - _levels.length;       // 0-based past hardcoded
    final cycle = cycleLevel ~/ 11;                   // cycle index
    final posInCycle = cycleLevel % 11;               // position within cycle
    final numCount = (5 + posInCycle).clamp(5, 15);   // count goes 5 to 15
    int gridSize;
    if (cycle >= 2) {
      gridSize = (numCount <= 6) ? 4 : (numCount <= 9 ? 5 : (numCount <= 12 ? 6 : 7));
    } else {
      gridSize = (numCount <= 6) ? 3 : (numCount <= 9 ? 4 : (numCount <= 12 ? 5 : 6));
    }
    return (gridSize, numCount);
  }

  void _loadLevel() {
    _gameTimer?.cancel();
    _timeLeft = -1;
    _timeBonusEarned = false;
    _exposureTimerFired = false;
    _decoyCells.clear();

    final cfg = _getChimpConfig(_levelIndex);
    _gridSize = cfg.$1; _n = cfg.$2;

    if (!_playDailyMode && _levelIndex >= 30) {
      _activeModifiers = RotationEngine.getActiveModifiers(
        gameId: 'chimp',
        levelIndex: _levelIndex,
        pool: ['numbersHide', 'spatialSpread', 'positionShuffle', 'timer'],
        minActive: 2,
        maxActive: 3,
        smallGrid: _gridSize <= 4,
      );
    } else {
      _activeModifiers = {};
    }

    _positions = _randomPositions();
    _started = false;
    _nextToTap = 1; _won = false; _failed = false;
    _correctTapCount = 0;
    _chaosShuffleDone = false;
    _glowingCells.clear();

    if (_hasTimedExposure) {
      final double exposureSecs = max(2.0, 6.0 - _chimpCycle * 0.5);
      Timer(Duration(milliseconds: (exposureSecs * 1000).toInt()), () {
        if (mounted && !_started && !_failed && !_won) {
          setState(() {
            _exposureTimerFired = true;
          });
        }
      });
    }

    if (_isEndgame) {
      _timeLeft = 5 * _n;
      _timeBonusEarned = true;
      _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          if (_timeLeft > 0) {
            setState(() {
              _timeLeft--;
            });
          } else {
            _gameTimer?.cancel();
            AudioManager.playFail();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Time is up! Restarting level...'), duration: Duration(seconds: 1)),
            );
            _loadLevel();
          }
        }
      });
    }
  }

  void _showJumpToLevelDialog() {
    final controller = TextEditingController(text: '${_levelIndex + 1}');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.bgCard,
        title: Text('Jump to Level', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter level number (1 - 150):', style: GoogleFonts.outfit(color: context.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: GoogleFonts.outfit(color: context.textPrimary),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'e.g. 50',
                hintStyle: GoogleFonts.outfit(color: context.textMuted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.outfit(color: context.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.patchesTeal),
            onPressed: () {
              final val = int.tryParse(controller.text.trim());
              if (val != null && val >= 1) {
                Navigator.pop(context);
                setState(() {
                  _levelIndex = val - 1;
                  _loadLevel();
                });
              }
            },
            child: Text('Go', style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Map<int,(int,int)> _randomPositions() {
    final rng = _playDailyMode
        ? Random()
        : RotationEngine.getDeterminism('chimp', _levelIndex);
    final used = <(int,int)>{};
    final map = <int,(int,int)>{};
    int num = 1;
    while (num <= _n) {
      final r = rng.nextInt(_gridSize);
      final c = rng.nextInt(_gridSize);
      if (!used.contains((r,c))) {
        used.add((r,c));
        map[num] = (r,c);
        num++;
      }
    }
    return map;
  }

  void _reset() => setState(() => _loadLevel());

  int? _numberAt(int r, int c) {
    for (final e in _positions.entries) { if (e.value.$1 == r && e.value.$2 == c) { return e.key; } }
    return null;
  }

  void _onTap(int r, int c) {
    if (_won || _failed) return;
    final num = _numberAt(r, c);

    setState(() {
      _glowingCells.add((r, c));
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _glowingCells.remove((r, c));
        });
      }
    });

    if (num == null) {
      if (_started || _decoyCells.contains((r, c))) {
        AudioManager.playFail();
        setState(() {
          _failed = true;
          _gameTimer?.cancel();
        });
      }
      return;
    }

    if (!_started && num == 1) {
      AudioManager.playClick();
      setState(() {
        _started = true;
        _nextToTap = 2;
        _correctTapCount = 1;
        _applyDailyPositionModifier();
      });
      return;
    }
    if (!_started) {
      AudioManager.playFail();
      setState(() {
        _failed = true;
        _gameTimer?.cancel();
      });
      return;
    }

    if (num == _nextToTap) {
      setState(() {
        _nextToTap++;
        _correctTapCount++;
        if (_nextToTap > _n) {
          _gameTimer?.cancel();
          if (_isTutorialMode) {
            _tutorialCompleted = true;
            AudioManager.playSuccess();
          } else {
            _won = true;
            AudioManager.playSuccess();
            _savePersistedLevel(_levelIndex + 1);

            if (_timeLeft > 0 && _timeBonusEarned) {
              PointManager.addPoints(5);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Speed Bonus! Earned +5 Points!', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black)),
                  backgroundColor: Colors.amber,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
        } else {
          _applyDailyPositionModifier();
          AudioManager.playClick();
        }
      });
    } else {
      AudioManager.playFail();
      setState(() {
        _failed = true;
        _gameTimer?.cancel();
      });
    }
  }

  void _applyDailyPositionModifier() {
    if (_playDailyMode) {
      if (_dailyModifierType == 'chaos' &&
          _correctTapCount >= 3 &&
          !_chaosShuffleDone) {
        _shuffleUntappedNumbers();
        _chaosShuffleDone = true;
      } else if (_dailyModifierType == 'gravity') {
        _sinkUntappedNumbers();
      }
    } else {
      if (_hasPositionShuffle && _correctTapCount >= 3 && !_chaosShuffleDone) {
        _shuffleUntappedNumbers();
        _chaosShuffleDone = true;
      }
      if (_hasDecoyTiles) {
        // Apply gravity to move things around as an extra challenge
        _sinkUntappedNumbers();
      }
    }
  }

  void _shuffleUntappedNumbers() {
    final rng = Random();
    final remainingNumbers = _positions.keys
        .where((nVal) => nVal >= _nextToTap)
        .toList()
      ..shuffle(rng);
    final remainingCells = _positions.entries
        .where((entry) => entry.key >= _nextToTap)
        .map((entry) => entry.value)
        .toList()
      ..shuffle(rng);

    for (int i = 0; i < remainingNumbers.length; i++) {
      _positions[remainingNumbers[i]] = remainingCells[i];
    }
  }

  void _sinkUntappedNumbers() {
    final occupiedByTapped = _positions.entries
        .where((entry) => entry.key < _nextToTap)
        .map((entry) => entry.value)
        .toSet();
    final remaining = _positions.entries
        .where((entry) => entry.key >= _nextToTap)
        .toList()
      ..sort((a, b) => b.value.$1.compareTo(a.value.$1));

    final occupied = <(int, int)>{...occupiedByTapped};
    for (final entry in remaining) {
      var row = entry.value.$1;
      final col = entry.value.$2;
      while (row + 1 < _gridSize && !occupied.contains((row + 1, col))) {
        row++;
      }
      final newPos = (row, col);
      _positions[entry.key] = newPos;
      occupied.add(newPos);
    }
  }

  bool _isCellVisible(int r, int c) {
    final num = _numberAt(r, c);
    if (num == null) return false;
    if (_exposureTimerFired) {
      if (_isHintShowing && num == _nextToTap) return true;
      return false;
    }
    if (!_started) return true;          // show all before first tap
    if (_isHintShowing && num == _nextToTap) return true;
    return false;                        // hide all numbers after first tap
  }

  void _nextLevel() async {
    if (!_won) return;
    if (_playDailyMode) {
      Navigator.pop(context, true);
      return;
    }
    if (await ShuffleManager.tryShuffleNavigate(context, 'chimp')) return;

    setState(() {
      _levelIndex = _levelIndex + 1;
      _loadLevel();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        backgroundColor: context.bgDark, foregroundColor: context.textPrimary,
        title: Text(_isTutorialMode ? 'Tutorial' : 'Chimp Test', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: context.textPrimary)),
        centerTitle: true,
        actions: [
          if (_shuffleActive && !_isTutorialMode)
            IconButton(
              icon: const Icon(Icons.skip_next_rounded),
              tooltip: 'Skip Game',
              onPressed: () => ShuffleManager.tryShuffleNavigate(context, 'chimp'),
            ),
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.lightbulb_outline, size: 20, color: context.textMuted),
                Positioned(
                  right: -4,
                  top: -4,
                  child: CircleAvatar(
                    radius: 6,
                    backgroundColor: Colors.amber,
                    child: Text(
                      _hintCount == 0 ? '+' : '$_hintCount',
                      style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
            onPressed: !_won && !_failed && !_isHintShowing && !_isTutorialMode
                ? () async {
                    if (_hintCount > 0) {
                      _useHint();
                    } else {
                      await BuyHintsDialog.show(
                        context,
                        initialGameId: 'chimp',
                        onPurchaseComplete: () async {
                          final newCount = await HintManager.getHints('chimp');
                          if (mounted) setState(() => _hintCount = newCount);
                        },
                      );
                    }
                  }
                : null,
          ),
          if (_timeLeft >= 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Row(
                  children: [
                    Icon(
                      Icons.timer,
                      color: _timeLeft <= 10 ? Colors.red : Colors.amber,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_timeLeft s',
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
          IconButton(
            icon: const Icon(Icons.help_outline, size: 20),
            color: context.textMuted,
            onPressed: () => GameTutorialDialog.show(context, 'chimp', 'Chimp Test'),
          ),
          GestureDetector(
            onTap: (_isTutorialMode || _playDailyMode) ? null : _showJumpToLevelDialog,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isTutorialMode
                          ? 'Tutorial'
                          : (_playDailyMode ? 'Daily' : 'Level ${_levelIndex + 1}'),
                      style: AppTheme.numberStyle(
                        color: AppTheme.patchesTeal,
                        fontSize: context.scale(13),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!_isTutorialMode && !_playDailyMode) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.edit, size: 12, color: AppTheme.patchesTeal),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: LayoutBuilder(builder: (ctx, constraints) {
              final available = constraints.maxWidth - 40;
              final cellSize = available / _gridSize;
              // Clamp cell size so grid doesn't overflow vertically
              final maxCellH = (constraints.maxHeight - 130) / _gridSize;
              final cs = min(cellSize, maxCellH);
              final gridW = cs * _gridSize;

              return Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Status
                      if (!_started && !_won && !_failed)
                        Text('Memorize 1 → $_n, then tap 1 to begin',
                          style: GoogleFonts.outfit(color: context.textSecondary, fontSize: context.scale(13)), textAlign: TextAlign.center)
                      else if (_started && !_won && !_failed)
                        Text('Tap 1 → $_n in order',
                          style: GoogleFonts.outfit(color: context.textSecondary, fontSize: context.scale(13)))
                      else
                        Text(_won ? (_playDailyMode ? '✓  Cleared!' : '✓  Level ${_levelIndex+1} cleared!') : '✗  Wrong! Try again.',
                          style: GoogleFonts.outfit(fontSize: context.scale(17), fontWeight: FontWeight.w700,
                            color: _won ? AppTheme.patchesTeal : Colors.redAccent)),
                      const SizedBox(height: 16),
                      // Grid
                      SizedBox(
                        width: gridW,
                        height: cs * _gridSize,
                        child: Stack(
                          children: [
                            // Background Grid
                            ...List.generate(_gridSize, (r) =>
                              List.generate(_gridSize, (c) {
                                final isDecoy = _decoyCells.contains((r, c));
                                final showDecoy = isDecoy && !_started && !_exposureTimerFired;
                                return Positioned(
                                  left: c * cs,
                                  top: r * cs,
                                  width: cs,
                                  height: cs,
                                  child: GestureDetector(
                                    onTap: () => _onTap(r, c),
                                    child: Container(
                                      margin: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: context.bgCard,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: showDecoy
                                              ? Colors.redAccent.withAlpha(120)
                                              : context.textMuted.withAlpha(75),
                                          width: showDecoy ? 2.0 : 1.2,
                                        ),
                                        boxShadow: AppTheme.cardShadow,
                                      ),
                                      child: showDecoy
                                          ? Center(
                                              child: Text(
                                                '✕',
                                                style: GoogleFonts.outfit(
                                                  fontSize: cs * 0.36,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.redAccent.withAlpha(180),
                                                ),
                                              ),
                                            )
                                          : null,
                                    ),
                                  ),
                                );
                              })
                            ).expand((x) => x).toList(),
                            // Number Cells (Animated)
                            ..._positions.entries.map((entry) {
                              final num = entry.key;
                              final r = entry.value.$1;
                              final c = entry.value.$2;
                              final visible = _isCellVisible(r, c);
                              final isTapped = num < _nextToTap && _started;
                              final isHintHighlighted = _isHintShowing && num == _nextToTap;
                              final isGlowing = _glowingCells.contains((r, c));

                              return AnimatedPositioned(
                                key: ValueKey('patch_$num'),
                                duration: const Duration(milliseconds: 800),
                                curve: Curves.fastOutSlowIn,
                                left: c * cs,
                                top: r * cs,
                                width: cs,
                                height: cs,
                                child: GestureDetector(
                                  onTap: () => _onTap(r, c),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    width: cs - 6,
                                    height: cs - 6,
                                    margin: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: isTapped
                                          ? Colors.transparent
                                          : (isGlowing
                                              ? AppTheme.patchesTeal.withAlpha(80)
                                              : (isHintHighlighted ? Colors.amber.withOpacity(0.2) : context.bgCard)),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isGlowing
                                            ? AppTheme.patchesTeal
                                            : (isHintHighlighted
                                                ? Colors.amber
                                                : (isTapped
                                                    ? Colors.transparent
                                                    : context.textMuted.withAlpha(75))),
                                        width: (isHintHighlighted || isGlowing) ? 2.5 : 1.2,
                                      ),
                                      boxShadow: isGlowing
                                          ? [BoxShadow(color: AppTheme.patchesTeal.withAlpha(120), blurRadius: 10, spreadRadius: 1)]
                                          : (isTapped ? null : AppTheme.cardShadow),
                                    ),
                                    child: Center(
                                      child: AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 150),
                                        transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                                        child: visible && !isTapped
                                            ? Text(
                                                '$num',
                                                key: ValueKey('num_$num'),
                                                style: GoogleFonts.outfit(
                                                  fontSize: cs * 0.36,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppTheme.patchesTeal,
                                                ),
                                              )
                                            : const SizedBox(key: ValueKey('empty')),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_won && !_playDailyMode && !_isTutorialMode) 
                        AutoNextCountdown(
                          onNext: _nextLevel,
                          accentColor: AppTheme.patchesTeal,
                        ),
                      if (_failed) TextButton(onPressed: _reset,
                        child: Text('Retry', style: GoogleFonts.outfit(color: context.textSecondary, fontSize: context.scale(15)))),
                    ],
                  ),
                ),
              );
            }),
          ),
          if (_won && _playDailyMode)
            ChallengeClearedOverlay(
              accentColor: AppTheme.patchesTeal,
              onComplete: () {
                Navigator.pop(context, true);
              },
            ),
          // if (_isTutorialMode)
          //   InteractiveTutorialOverlay(
          //     instruction: _tutorialCompleted
          //         ? "Nice! You successfully memorized and tapped all numbers."
          //         : "Watch the numbers closely. Tapping 1 will hide them, then you must tap the remaining tiles in order from memory!",
          //     isCompleted: _tutorialCompleted,
          //     onSkip: _finishTutorial,
          //     onStartGame: _finishTutorial,
          //   ),
        ],
      ),
    );
  }
}
