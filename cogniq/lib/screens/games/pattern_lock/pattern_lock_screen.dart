import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../widgets/game_level_chip.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../widgets/auto_next_countdown.dart';
import '../../../widgets/challenge_cleared_overlay.dart';
import '../../../utils/audio_manager.dart';
import '../../../utils/hint_manager.dart';
import '../../../widgets/game_tutorial_dialog.dart';
import '../../../widgets/swipe_trail_overlay.dart';
import '../../../widgets/buy_hints_dialog.dart';
import '../../../utils/shuffle_manager.dart';
import '../../../utils/achievement_manager.dart';
import '../../../widgets/achievement_toast.dart';
import '../../../utils/rotation_engine.dart';
import '../../../utils/point_manager.dart';
import '../../../utils/prefs_keys.dart';

class PatternLockScreen extends StatefulWidget {
  const PatternLockScreen({super.key});
  @override
  State<PatternLockScreen> createState() => _PatternLockScreenState();
}

class _PatternLockScreenState extends State<PatternLockScreen> {
  String? _forcedModifier;
  int _currentLevel = 0;
  bool _isSuccess = false;
  bool _eclipseVisible = true;
  Timer? _eclipseTimer;
  List<int> _targetPattern = [];
  List<int> _userPattern = [];
  bool _isMemorizing = true;
  Timer? _memorizeTimer;
  int _hintCount = 0;
  int _hintDot = -1;
  bool _shuffleActive = false;
  bool _isTutorialMode = false;
  bool _tutorialCompleted = false;
  int _actualGameLevel = 0;
  bool _playDailyMode = false;
  String _dailyModifierType = '';
  String _dailyModifierName = '';
  String _dailyModifierDesc = '';
  Set<String> _activeModifiers = {};
  List<int> _distractorDots = [];
  int _transformType = 0;
  Timer? _gameTimer;
  int _timeLeft = -1;
  // Timer value at the moment the hard timer started; 0 when no timer ran.
  // Only used for the Speed Demon achievement check on clear.
  int _initialTime = 0;
  bool _timeBonusEarned = false;

  final ValueNotifier<Offset?> _dragPositionNotifier = ValueNotifier<Offset?>(null);
  double get _boardSize => min(MediaQuery.of(context).size.width - 48, 400.0);

  // COGNIQ-FIX:mod-active-helper
  bool _isModActive(String name) {
    if (_forcedModifier == name) return true;
    if (_playDailyMode) return _dailyModifierType == name;
    return _currentLevel >= RotationEngine.modifierStartLevel('patternlock') &&
        _activeModifiers.contains(name);
  }

  // COGNIQ-FIX:mod-getters
  bool get _isGridSizeActive => _isModActive('gridSize');
  bool get _isBoardTransformActive => _isModActive('boardTransform');
  bool get _isMirrorActive => _isModActive('mirror');
  bool get _isEclipseActive => _isModActive('eclipse');
  bool get _isPathComplexityActive => _isModActive('pathComplexity');
  bool get _isDistractorDotsActive => _isModActive('distractorDots');
  bool get _isMemorizeTimerActive => _isModActive('memorizeTimer');
  bool get _isEndgame => _isModActive('timer');

  // COGNIQ-FIX:mod-deadeffect
  /// The board transform is live whenever a transform was actually rolled for
  /// this level. It used to be gated on [_isEndgame] ('timer'), which is not in
  /// this game's modifier pool, so in free play the transform was computed and
  /// then never applied. _transformType is only non-zero when boardTransform
  /// (or the daily mirror) is genuinely active, so this is the honest gate.
  bool get _transformApplies => _transformType != 0;

  int get _gridN {
    if (!_playDailyMode && _currentLevel >= 30) { // not-a-modifier-gate
      int base = _currentLevel >= 80 ? 6 + ((_currentLevel - 80) % 2) : 7;
      if (_isGridSizeActive) base += 1;
      return base.clamp(3, 8);
    }
    if (_currentLevel < 5) return 3;
    if (_currentLevel < 10) return 4;
    if (_currentLevel < 20) return 5;
    return 6;
  }
  double get _spacing => _boardSize / _gridN;

  Offset _dotCenter(int idx) => Offset(
        _spacing * (idx % _gridN) + _spacing / 2,
        _spacing * (idx ~/ _gridN) + _spacing / 2,
      );

  /// Modifiers now begin at a per-game level chosen in RotationEngine
  /// rather than a flat level 30 for every game.
  bool get _modsOn => !_playDailyMode && RotationEngine.hasModifiers('patternlock', _currentLevel);

  @override
  void initState() {
    super.initState();
    _initLevelState();
  }

  Future<void> _initLevelState() async {
    final prefs = await SharedPreferences.getInstance();
    _playDailyMode = prefs.getBool('play_daily_mode') ?? false;
    _dailyModifierType = _playDailyMode ? (prefs.getString(PrefsKeys.dailyModifierType) ?? '') : '';
    _dailyModifierName = _playDailyMode ? (prefs.getString(PrefsKeys.dailyModifierName) ?? '') : '';
    _dailyModifierDesc = _playDailyMode ? (prefs.getString(PrefsKeys.dailyModifierDesc) ?? '') : '';
    final savedLvl = prefs.getInt(PrefsKeys.gameLevel('pattern_lock')) ?? 0;
    final active = await ShuffleManager.isActive();
    final hintCount = await HintManager.getHints('pattern_lock');
    
    if (mounted) {
      setState(() {
        _shuffleActive = active;
        _hintCount = hintCount;
        _actualGameLevel = savedLvl;
        _isTutorialMode = false;
        final diff = prefs.getString(PrefsKeys.dailyModifierDifficulty) ?? 'Easy';
        if (_playDailyMode) {
          if (diff == 'Easy') {
            _currentLevel = savedLvl % 5;
          } else if (diff == 'Medium') {
            _currentLevel = 5 + (savedLvl % 5);
          } else {
            _currentLevel = 10 + (savedLvl % 10);
          }
        } else {
          _currentLevel = savedLvl;
        }
        _loadLevel();
      });
    }
  }

  @override
  void dispose() {
    _memorizeTimer?.cancel();
    _gameTimer?.cancel();
    _eclipseTimer?.cancel();
    _dragPositionNotifier.dispose();
    super.dispose();
  }

  int _transformIndex(int idx, int n, int transformType) {
    int r = idx ~/ n;
    int c = idx % n;
    switch (transformType) {
      case 1: // Rotate 90 CW
        return c * n + (n - 1 - r);
      case 2: // Rotate 180
        return (n - 1 - r) * n + (n - 1 - c);
      case 3: // Mirror H
        return r * n + (n - 1 - c);
      default:
        return idx;
    }
  }

  void _startSolveTimer() {
    _gameTimer?.cancel();
    _timeLeft = 25 + (_gridN * 5);
    _initialTime = _timeLeft;
    _timeBonusEarned = true;
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_timeLeft > 0) {
            _timeLeft--;
          } else {
            _gameTimer?.cancel();
            AudioManager.playFail();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Time is up! Restarting level...'), duration: Duration(seconds: 1)),
            );
            _loadLevel();
          }
        });
      }
    });
  }

  void _onReadyTapped() {
    _memorizeTimer?.cancel();
    setState(() {
      _isMemorizing = false;
      if (_isEndgame) {
        _startSolveTimer();
      }
    });
  }

  // COGNIQ-FIX:mod-desc-copy
  String _getModifierDescription(String mod) {
    switch (mod) {
      case 'pathComplexity':
        return 'Pattern contains sharper turns and longer leaps.';
      case 'distractorDots':
        return 'Unconnected distractor dots appear on the board.';
      case 'gridSize':
        return 'The dot grid is expanded in dimensions.';
      case 'boardTransform':
        return 'The pattern is rotated from its preview.';
      case 'mirror':
        return 'The pattern is mirrored across axes.';
      case 'memorizeTimer':
        return 'Memorize the path before the preview timer expires.';
      case 'eclipse':
        return 'The path fades out shortly after preview.';
      case 'timer':
        return 'Draw the sequence before time expires.';
      default:
        return '';
    }
  }

  String get _modifierBannerText {
    if (_isTutorialMode) return '';
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

  void _loadLevel() {
    HintManager.startLevel('pattern_lock');
    _memorizeTimer?.cancel();
    _gameTimer?.cancel();
    _eclipseTimer?.cancel();
    _dragPositionNotifier.value = null;
    setState(() {
      _isSuccess = false;
      _userPattern = [];
      _isMemorizing = true;
      _timeLeft = -1;
      _timeBonusEarned = false;
      
      _activeModifiers.clear();
      if (_playDailyMode && _dailyModifierType.isNotEmpty) {
        _activeModifiers.add(_dailyModifierType);
      } else if (!_playDailyMode && _currentLevel >= RotationEngine.modifierStartLevel('patternlock')) {
        final baseN = _currentLevel >= 80 ? 6 + ((_currentLevel - 80) % 2) : 7;
        _activeModifiers = RotationEngine.getActiveModifiers(
          gameId: 'patternlock',
          levelIndex: _currentLevel,
          pool: ['pathComplexity', 'distractorDots', 'gridSize', 'boardTransform', 'memorizeTimer', 'eclipse'],
          minActive: 2,
          maxActive: 3,
          smallGrid: (baseN <= 5),
        );
        if (_forcedModifier != null) {
          _activeModifiers = {_forcedModifier!};
        }
      }
      
      final n = _gridN; // now correctly reflects 'gridSize' if it was rolled above
      final rng = _playDailyMode
          ? Random(_currentLevel * 137 + 42)
          : RotationEngine.getDeterminism('patternlock', _currentLevel);
      
      int targetLength = 3 + (_currentLevel ~/ 2);
      _transformType = 0;
      _distractorDots = [];

      if (!_playDailyMode && _currentLevel >= 30) { // not-a-modifier-gate
        // COGNIQ-FIX:curve-regression
        // The pre-30 ramp (3 + level ~/ 2) ends at 17 dots on level 29, so the
        // level-30 formula has to start at 17 and keep climbing. It now adds a
        // dot every 5 levels and caps at 24, which stays well inside the 7x7
        // (49 dot) board used for levels 30-79. Monotonic in _currentLevel.
        targetLength = (17 + ((_currentLevel - 30) ~/ 5)).clamp(17, 24);
        targetLength = targetLength.clamp(3, n * n);
        if (_isBoardTransformActive) {
          _transformType = 1 + rng.nextInt(3); // CW, 180, or Mirror
        }
      } else {
        targetLength = targetLength.clamp(3, n * n);
        if (_isMirrorActive) {
          _transformType = 3; // Force Mirror H for daily challenge
        }
      }

      if (_isEclipseActive) {
        _eclipseVisible = true;
        _eclipseTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
          if (mounted) {
            setState(() {
              _eclipseVisible = !_eclipseVisible;
            });
          }
        });
      }

      bool checkComplexity = _isPathComplexityActive;

      int attempts = 0;
      bool pathOk = false;
      while (!pathOk && attempts < 500) {
        attempts++;
        List<int> pattern = [];
        int curr = rng.nextInt(n * n);
        pattern.add(curr);

        int walkAttempts = 0;
        while (pattern.length < targetLength && walkAttempts < 1000) {
          walkAttempts++;
          int r = curr ~/ n;
          int c = curr % n;

          List<int> neighbors = [];
          if (r > 0) neighbors.add((r - 1) * n + c);
          if (r < n - 1) neighbors.add((r + 1) * n + c);
          if (c > 0) neighbors.add(r * n + c - 1);
          if (c < n - 1) neighbors.add(r * n + c + 1);

          if (!_playDailyMode && _currentLevel >= 30) { // not-a-modifier-gate
            if (r > 0 && c > 0) neighbors.add((r - 1) * n + c - 1);
            if (r > 0 && c < n - 1) neighbors.add((r - 1) * n + c + 1);
            if (r < n - 1 && c > 0) neighbors.add((r + 1) * n + c - 1);
            if (r < n - 1 && c < n - 1) neighbors.add((r + 1) * n + c + 1);
          }

          neighbors.removeWhere((idx) => pattern.contains(idx));

          if (neighbors.isEmpty) {
            break;
          }

          int next = neighbors[rng.nextInt(neighbors.length)];
          pattern.add(next);
          curr = next;
        }

        if (pattern.length == targetLength) {
          if (checkComplexity) {
            int turns = 0;
            for (int i = 1; i < pattern.length - 1; i++) {
              int prev = pattern[i - 1];
              int curVal = pattern[i];
              int next = pattern[i + 1];
              int dr1 = (curVal ~/ n) - (prev ~/ n);
              int dc1 = (curVal % n) - (prev % n);
              int dr2 = (next ~/ n) - (curVal ~/ n);
              int dc2 = (next % n) - (curVal % n);
              if (dr1 != dr2 || dc1 != dc2) {
                turns++;
              }
            }
            if (turns >= (targetLength * 0.4).round()) {
              _targetPattern = pattern;
              pathOk = true;
            }
          } else {
            _targetPattern = pattern;
            pathOk = true;
          }
        }
      }
      
      if (!pathOk) {
        RotationEngine.logFallback('patternlock', _currentLevel);
        _targetPattern = _generateValidWalkPath(_gridN, targetLength, rng);
      }

      bool hasDistractors = _isDistractorDotsActive;
      if (hasDistractors) {
        int count = 2 + (_currentLevel >= 30 ? (_currentLevel - 30) ~/ 10 : 0); // not-a-modifier-gate
        if (count > 5) count = 5;
        final List<int> candidates = [];
        final patternSet = _targetPattern.toSet();
        for (int i = 0; i < n * n; i++) {
          if (patternSet.contains(i)) continue;
          final rowA = i ~/ n;
          final colA = i % n;
          bool isNear = false;
          for (final p in patternSet) {
            final rowB = p ~/ n;
            final colB = p % n;
            if ((rowA - rowB).abs() + (colA - colB).abs() <= 2) {
              isNear = true;
              break;
            }
          }
          if (isNear) {
            candidates.add(i);
          }
        }
        if (candidates.isEmpty) {
          for (int i = 0; i < n * n; i++) {
            if (!patternSet.contains(i)) {
              candidates.add(i);
            }
          }
        }
        candidates.shuffle(rng);
        _distractorDots = candidates.take(count).toList();
      }

      bool hasMemorizeTimer = _isMemorizeTimerActive;

      if (hasMemorizeTimer) {
        double durationSeconds = max(1.5, targetLength * 0.6);
        _memorizeTimer = Timer(Duration(milliseconds: (durationSeconds * 1000).toInt()), () {
          if (mounted) {
            setState(() {
              _isMemorizing = false;
              if (_isEndgame) {
                _startSolveTimer();
              }
            });
          }
        });
      }
    });
  }

  int _getHitDot(Offset localPos) {
    final total = _gridN * _gridN;
    // COGNIQ-FIX:patternlock-autofill
    final hitRadius = _spacing * 0.42;
    for (int idx = 0; idx < total; idx++) {
      double dist = (localPos - _dotCenter(idx)).distance;
      if (dist < hitRadius) {
        return idx;
      }
    }
    return -1;
  }

  // COGNIQ-FIX:patternlock-autofill
  /// Greatest common divisor on non-negative ints. gcd(0, x) == x.
  int _gcdInt(int a, int b) {
    while (b != 0) {
      final t = a % b;
      a = b;
      b = t;
    }
    return a;
  }

  // COGNIQ-FIX:patternlock-autofill
  /// Every dot that lies exactly ON the straight line between [from] and [to],
  /// in travel order, excluding both endpoints. Pure integer lattice maths: for
  /// a step (dr, dc) with g = gcd(|dr|, |dc|), the interior lattice points are
  /// (r1 + k*dr/g, c1 + k*dc/g) for k = 1..g-1. Returns empty when g <= 1.
  List<int> _dotsBetween(int from, int to) {
    final n = _gridN;
    final r1 = from ~/ n;
    final c1 = from % n;
    final dr = (to ~/ n) - r1;
    final dc = (to % n) - c1;
    final g = _gcdInt(dr.abs(), dc.abs());
    if (g <= 1) return const <int>[];
    final stepR = dr ~/ g;
    final stepC = dc ~/ g;
    final result = <int>[];
    for (int k = 1; k < g; k++) {
      result.add((r1 + k * stepR) * n + (c1 + k * stepC));
    }
    return result;
  }

  void _onPanStart(DragStartDetails d) {
    if (_isMemorizing || _isSuccess) return;
    final idx = _getHitDot(d.localPosition);
    if (idx != -1) {
      settingsNotifier.hapticTap();
      setState(() {
        _userPattern = [idx];
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_isMemorizing || _isSuccess) return;
    _dragPositionNotifier.value = d.localPosition;

    final idx = _getHitDot(d.localPosition);
    if (idx != -1) {
      if (!_userPattern.contains(idx)) {
        // COGNIQ-FIX:patternlock-autofill
        // A fast drag only samples a handful of points, so dots the player
        // visually swiped through used to be skipped. Fill in every dot on the
        // straight line from the last selected dot to this one, in order,
        // before appending the newly hit dot. One haptic for the whole batch.
        final List<int> filler = _userPattern.isEmpty
            ? const <int>[]
            : _dotsBetween(_userPattern.last, idx)
                .where((mid) => !_userPattern.contains(mid))
                .toList();
        settingsNotifier.hapticTap();
        setState(() {
          _userPattern.addAll(filler);
          _userPattern.add(idx);
        });
      } else if (_userPattern.length >= 2 && idx == _userPattern[_userPattern.length - 2]) {
        settingsNotifier.hapticTap();
        setState(() {
          _userPattern.removeLast();
        });
      }
    }
  }

  void _onPanEnd(DragEndDetails d) {
    if (_isMemorizing || _isSuccess) return;
    _dragPositionNotifier.value = null;

    if (_userPattern.isEmpty) return;

    // COGNIQ-FIX:mod-deadeffect
    final targetPattern = _transformApplies
        ? _targetPattern.map((idx) => _transformIndex(idx, _gridN, _transformType)).toList()
        : _targetPattern;

    bool win = listEquals(_userPattern, targetPattern) || 
               listEquals(_userPattern, targetPattern.reversed.toList());

    if (win) {
      _gameTimer?.cancel();
      if (_isTutorialMode) {
        if (!_tutorialCompleted) {
          AudioManager.playSuccess();
          settingsNotifier.hapticSuccess();
          setState(() {
            _tutorialCompleted = true;
          });
        }
      } else {
        _onLevelCleared();
      }
    } else {
      AudioManager.playFail();
      settingsNotifier.hapticError();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Incorrect pattern sequence! Try again.'),
        backgroundColor: Colors.redAccent,
      ));
      setState(() {
        _userPattern = [];
      });
    }
  }

  List<int> _generateValidWalkPath(int n, int len, Random rng) {
    int curr = rng.nextInt(n * n);
    List<int> path = [curr];
    Set<int> visited = {curr};
    
    for (int step = 1; step < len; step++) {
      int r = curr ~/ n;
      int c = curr % n;
      List<int> neighbors = [];
      for (int dr = -1; dr <= 1; dr++) {
        for (int dc = -1; dc <= 1; dc++) {
          if (dr == 0 && dc == 0) continue;
          int nr = r + dr;
          int nc = c + dc;
          if (nr >= 0 && nr < n && nc >= 0 && nc < n) {
            int nIdx = nr * n + nc;
            if (!visited.contains(nIdx)) neighbors.add(nIdx);
          }
        }
      }
      if (neighbors.isEmpty) break;
      curr = neighbors[rng.nextInt(neighbors.length)];
      path.add(curr);
      visited.add(curr);
    }
    return path;
  }

  Future<void> _onLevelCleared() async {
    _gameTimer?.cancel();
    AudioManager.playSuccess();
    settingsNotifier.hapticSuccess();

    // A daily challenge borrows the game's level slot, so saving here would leak
    // the challenge's level into real progress. Registering the clear would also
    // double-pay: the daily grants its own reward, and HintManager.onLevelCleared
    // adds points, the global clear count, achievements and trail milestones on
    // top. Same guard as star_battle_screen.dart.
    // The success flag still has to be set — the daily's own cleared overlay is
    // driven by _isSuccess.
    if (_timeLeft > 0 && _timeBonusEarned) {
      await PointManager.addPoints(5);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Speed Bonus! Earned +5 Points!', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black)),
            backgroundColor: Colors.amber,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }

    if (_playDailyMode) {
      if (mounted) setState(() => _isSuccess = true);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final key = PrefsKeys.gameLevel('pattern_lock');
    int highest = prefs.getInt(key) ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt(key, _currentLevel + 1);
    }

    final earned = await HintManager.onLevelCleared(
      'pattern_lock',
      // Speed Demon: cleared a hard-timer level with more than half the
      // clock still left. _initialTime is 0 unless the solve timer ran.
      isSpeedDemon: _initialTime > 0 && _timeLeft * 2 > _initialTime,
    );
    final hCount = await HintManager.getHints('pattern_lock');

    if (mounted) {
      setState(() {
        _hintCount = hCount;
        _isSuccess = true;
      });
    }

    if (earned && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hint earned! (Total: $hCount)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: AppTheme.accentFor('pattern_lock'),
        ),
      );
    }

    final newUnlocks = await AchievementManager.checkAndUnlock('pattern_lock');
    for (final a in newUnlocks) {
      if (mounted) {
        AchievementToast.show(context, a);
      }
    }
  }

  void _nextLevel() async {
    if (await ShuffleManager.isActive()) {
      final next = await ShuffleManager.pickNextGame('pattern_lock');
      if (mounted) ShuffleManager.navigateToGame(context, next);
      return;
    }
    setState(() {
      _currentLevel++;
      _loadLevel();
    });
  }

  void _showJumpToLevelDialog() {
    showDialog(
      context: context,
      builder: (context) {
        int target = _currentLevel + 1;
        String? selectedMod = _forcedModifier;
        final pool = ['pathComplexity', 'distractorDots', 'gridSize', 'boardTransform', 'memorizeTimer', 'eclipse'];
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: context.bgCard,
              title: Text('Jump to Level', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.outfit(color: context.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Level Number (1+)',
                        labelStyle: GoogleFonts.outfit(color: context.textSecondary),
                      ),
                      onChanged: (val) {
                        target = int.tryParse(val) ?? target;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedMod,
                      dropdownColor: context.bgCard,
                      style: GoogleFonts.outfit(color: context.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Force Modifier',
                        labelStyle: GoogleFonts.outfit(color: context.textSecondary),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('None (Default)')),
                        ...pool.map((m) => DropdownMenuItem(value: m, child: Text(m))),
                      ],
                      onChanged: (val) {
                        setDialogState(() {
                          selectedMod = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: GoogleFonts.outfit(color: context.textSecondary)),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (target > 0) {
                      setState(() {
                        _currentLevel = target - 1;
                        _forcedModifier = selectedMod;
                        _loadLevel();
                      });
                    }
                  },
                  child: Text('Jump', style: GoogleFonts.outfit(color: AppTheme.dustyMauve)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _useHint() async {
    if (_isSuccess || _isMemorizing || _hintDot != -1) return;

    if (_hintCount <= 0) {
      BuyHintsDialog.show(
        context,
        initialGameId: 'pattern_lock',
        isFromGameScreen: true,
        onPurchaseComplete: () {
          HintManager.getHints('pattern_lock').then((val) {
            if (mounted) setState(() => _hintCount = val);
          });
        },
      );
      return;
    }

    settingsNotifier.hapticTap();

    bool isPrefix = true;
    // COGNIQ-FIX:mod-deadeffect
    final target = _transformApplies
        ? _targetPattern.map((idx) => _transformIndex(idx, _gridN, _transformType)).toList()
        : _targetPattern;

    if (_userPattern.length > target.length) {
      isPrefix = false;
    } else {
      for (int i = 0; i < _userPattern.length; i++) {
        if (_userPattern[i] != target[i]) {
          isPrefix = false;
          break;
        }
      }
    }

    int nextDot = target[0];
    if (isPrefix && _userPattern.length < target.length) {
      nextDot = target[_userPattern.length];
    }

    setState(() {
      _hintDot = nextDot;
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _hintDot = -1;
        });
      }
    });

    await HintManager.useHint('pattern_lock');
    final hCount = await HintManager.getHints('pattern_lock');
    setState(() {
      _hintCount = hCount;
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Hint: Flashing the next dot!'),
      backgroundColor: AppTheme.accentFor('pattern_lock'),
      duration: const Duration(milliseconds: 1500),
    ));
  }

  // COGNIQ-FIX:patternlock-peek
  /// "Show again": costs one hint and re-shows the full target pattern for
  /// 1.5s. Implemented by flipping _isMemorizing back on and restarting
  /// _memorizeTimer, so the existing painter/dot branches and the existing
  /// input guards do all the work. The in-progress trace is deliberately kept.
  Future<void> _usePeek() async {
    if (_isSuccess || _isMemorizing) return;
    if (_hintCount <= 0) return;

    settingsNotifier.hapticTap();

    // Cancel first, otherwise the memorize-phase timer and this one fight over
    // _isMemorizing.
    _memorizeTimer?.cancel();
    if (mounted) {
      setState(() {
        _isMemorizing = true;
      });
    }
    _memorizeTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _isMemorizing = false;
        });
      }
    });

    await HintManager.useHint('pattern_lock');
    final hCount = await HintManager.getHints('pattern_lock');
    if (mounted) {
      setState(() {
        _hintCount = hCount;
      });
    }
  }

  void _showRules() {
    settingsNotifier.hapticTap();
    GameTutorialDialog.show(context, 'pattern_lock', 'Pattern Lock');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: const GameTitle('Pattern Lock'),
        leading: IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        actions: [
          if (_shuffleActive)
            IconButton(
              icon: const Icon(Icons.skip_next_rounded),
              tooltip: 'Skip Game',
              onPressed: () => ShuffleManager.tryShuffleNavigate(context, 'pattern_lock'),
            ),
          IconButton(
            tooltip: 'Hint',
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
            onPressed: !_isSuccess && !_isMemorizing
                ? () async {
                    if (_hintCount > 0) {
                      _useHint();
                    } else {
                      await BuyHintsDialog.show(
                        context,
                        initialGameId: 'pattern_lock',
                        onPurchaseComplete: () async {
                          final newCount = await HintManager.getHints('pattern_lock');
                          if (mounted) setState(() => _hintCount = newCount);
                        },
                      );
                    }
                  }
                : null,
          ),
          // COGNIQ-FIX:patternlock-peek
          IconButton(
            tooltip: 'Show again (1 hint)',
            icon: Icon(
              Icons.visibility_outlined,
              size: 20,
              color: (!_isSuccess && !_isMemorizing && _hintCount > 0)
                  ? context.textMuted
                  : context.textMuted.withOpacity(0.35),
            ),
            onPressed: (!_isSuccess && !_isMemorizing && _hintCount > 0) ? _usePeek : null,
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
            icon: const Icon(Icons.help_outline, color: AppTheme.dustyMauve),
            tooltip: 'Rules',
            onPressed: _showRules,
          ),
          GameLevelChip(
            level: _currentLevel + 1,
            modeLabel: _isTutorialMode ? 'Tutorial' : (_playDailyMode ? 'Daily' : null),
            accent: AppTheme.accentFor('pattern_lock'),
            onTap: kDebugMode ? _showJumpToLevelDialog : null,
          ),
        ],
      ),
      body: SwipeTrailOverlay(
        accentColor: AppTheme.dustyMauve,
        child: Stack(
          children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 12),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isMemorizing ? 'Memorize the highlighted pattern...' : 'Trace the pattern from memory!',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _isMemorizing ? Colors.amber : context.textPrimary,
                          ),
                        ),
                        // COGNIQ-FIX:mod-deadeffect
                        if (_transformApplies) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.redAccent.withOpacity(0.4), width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  _transformType == 1
                                      ? 'MENTAL SHIFT: BOARD ROTATED 90° CW'
                                      : (_transformType == 2
                                          ? 'MENTAL SHIFT: BOARD ROTATED 180°'
                                          : 'MENTAL SHIFT: BOARD MIRRORED HORIZONTALLY'),
                                  style: GoogleFonts.spaceGrotesk(
                                    color: Colors.redAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),
                        if (_modifierBannerText.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Text(
                              _modifierBannerText,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.dustyMauve.withOpacity(0.9),
                              ),
                            ),
                          ),
                        ],
                        RepaintBoundary(
                          child: GestureDetector(
                            onPanStart: _onPanStart,
                            onPanUpdate: _onPanUpdate,
                            onPanEnd: _onPanEnd,
                            child: Container(
                              width: _boardSize, height: _boardSize,
                              decoration: BoxDecoration(
                                color: context.bgCard, 
                                borderRadius: BorderRadius.circular(16), 
                                border: Border.all(color: context.textMuted.withAlpha(40)),
                              ),
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 400),
                                opacity: _isEclipseActive && !_isSuccess
                                    ? (_eclipseVisible ? 1.0 : 0.05)
                                    : 1.0,
                                child: Stack(
                                  children: [
                                    CustomPaint(
                                      size: Size(_boardSize, _boardSize),
                                      painter: PatternPainter(
                                        pattern: _isMemorizing ? _targetPattern : _userPattern,
                                        lineColor: _isMemorizing ? Colors.amber.withOpacity(0.6) : AppTheme.dustyMauve,
                                        dragPositionNotifier: _dragPositionNotifier,
                                        gridN: _gridN,
                                        spacing: _spacing,
                                      ),
                                    ),
                                  for (int idx = 0; idx < _gridN * _gridN; idx++)
                                    Positioned(
                                      left: _dotCenter(idx).dx - 20.0,
                                      top: _dotCenter(idx).dy - 20.0,
                                      child: IgnorePointer(
                                        child: Container(
                                          width: 40, height: 40,
                                          color: Colors.transparent,
                                          child: Center(
                                            child: Builder(
                                              builder: (context) {
                                                bool isDistractor = _distractorDots.contains(idx);
                                                bool isHighlighted = _isMemorizing
                                                    ? (_targetPattern.contains(idx) || isDistractor)
                                                    : (_userPattern.contains(idx) || _hintDot == idx);
                                                Color dotColor = isHighlighted
                                                    ? (_isMemorizing
                                                        ? Colors.amber
                                                        : (_hintDot == idx ? Colors.amber : AppTheme.dustyMauve))
                                                    : context.textMuted.withOpacity(0.3);
                                                double dotSize = isHighlighted ? 20.0 : 12.0;
                                                return Container(
                                                  width: dotSize,
                                                  height: dotSize,
                                                  decoration: BoxDecoration(
                                                    color: dotColor,
                                                    shape: BoxShape.circle,
                                                  ),
                                                );
                                              }
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_isMemorizing) ...[
                          const SizedBox(height: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.dustyMauve,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            onPressed: _onReadyTapped,
                            child: Text('READY', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ],
                        const SizedBox(height: 12),
                        if (_isSuccess && !_playDailyMode && !_isTutorialMode)
                          AutoNextCountdown(
                            onNext: _nextLevel,
                            accentColor: AppTheme.dustyMauve,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isSuccess && _playDailyMode)
            Positioned.fill(
              child: ChallengeClearedOverlay(
                accentColor: AppTheme.dustyMauve,
                onComplete: () {
                  Navigator.pop(context, true);
                },
              ),
            ),
          // if (_isTutorialMode)
          //   InteractiveTutorialOverlay(
          //     instruction: _tutorialCompleted
          //         ? "Nice! You successfully traced the pattern and unlocked the level."
          //         : "Watch the highlighted pattern blink, then drag your finger to trace the exact same line sequence!",
          //     isCompleted: _tutorialCompleted,
          //     onSkip: _finishTutorial,
          //     onStartGame: _finishTutorial,
          //   ),
        ],
      ),
    ),
  );
}
}

class PatternPainter extends CustomPainter {
  final List<int> pattern;
  final Color lineColor;
  final ValueNotifier<Offset?> dragPositionNotifier;
  final int gridN;
  final double spacing;

  PatternPainter({
    required this.pattern,
    required this.lineColor,
    required this.dragPositionNotifier,
    required this.gridN,
    required this.spacing,
  }) : super(repaint: dragPositionNotifier);

  Offset _center(int idx) => Offset(
        spacing * (idx % gridN) + spacing / 2,
        spacing * (idx ~/ gridN) + spacing / 2,
      );

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (pattern.length >= 2) {
      for (int i = 0; i < pattern.length - 1; i++) {
        canvas.drawLine(_center(pattern[i]), _center(pattern[i + 1]), paint);
      }
    }

    final dragOffset = dragPositionNotifier.value;
    if (dragOffset != null && pattern.isNotEmpty) {
      canvas.drawLine(_center(pattern.last), dragOffset, paint);
    }
  }

  @override
  bool shouldRepaint(covariant PatternPainter oldDelegate) {
    return !listEquals(oldDelegate.pattern, pattern) ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridN != gridN ||
        oldDelegate.spacing != spacing ||
        oldDelegate.dragPositionNotifier != dragPositionNotifier;
  }
}
