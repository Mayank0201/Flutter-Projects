import 'dart:math';
import 'dart:async';
import '../../../widgets/fog_overlay.dart';
import '../../../utils/rotation_engine.dart';
import '../../../utils/point_manager.dart';
import '../../../utils/prefs_keys.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../widgets/game_level_chip.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../widgets/auto_next_countdown.dart';
import '../../../widgets/challenge_cleared_overlay.dart';
import '../../../widgets/loss_overlay.dart';
import '../../../widgets/game_tutorial_dialog.dart';
import '../../../utils/audio_manager.dart';
import '../../../utils/hint_manager.dart';
import '../../../utils/shuffle_manager.dart';
import '../../../widgets/swipe_trail_overlay.dart';
import '../../../widgets/buy_hints_dialog.dart';
import '../../../utils/achievement_manager.dart';
import '../../../widgets/achievement_toast.dart';

/// The endgame modifier pool, where the generator itself reads the
/// modifiers. Mirrored by `pools['circuitguide']` in
/// test/difficulty_curve_test.dart — keep the two in step.
const List<String> kCircuitGuideEndgamePool = [
  'tortuosity',
  'junctionDensity',
  'decoyWires',
  'scrambleDepth',
  'timer',
  'retro',
  'fog',
  'quota',
];

/// Levels below the endgame build their board without consulting modifiers, so
/// only ones that act on play or presentation may appear here — announcing
/// 'tortuosity' would name a modifier that then did nothing. `quota` qualifies:
/// it reads the finished board rather than shaping it.
const List<String> kCircuitGuidePresentationPool = [
  'timer',
  'retro',
  'fog',
  'quota',
];

/// `quota`'s move budget for a board whose optimum is [optimalMoves].
///
/// The budget tightens as the campaign goes on — twice the optimum early,
/// settling towards 1.15x — but a budget a perfect player cannot meet is a
/// broken level rather than a hard one, so the optimum plus two is the floor
/// however far that curve has run.
int circuitGuideQuotaBudget({required int optimalMoves, required int level}) {
  final mult = RotationEngine.getDecayValue(
    level: level,
    start: 2.0,
    floor: 1.15,
    rate: 40,
  );
  return max(optimalMoves + 2, (optimalMoves * mult).ceil());
}

class CircuitGuideScreen extends StatefulWidget {
  const CircuitGuideScreen({super.key});
  @override
  State<CircuitGuideScreen> createState() => _CircuitGuideScreenState();
}

class _CircuitGuideScreenState extends State<CircuitGuideScreen> {
  String? _forcedModifier;
  int _currentLevel = 0;
  bool _isSuccess = false;
  int _gridSize = 3;
  List<int> _rotations = []; // 0 to 3
  List<String> _wireTypes = []; // "SRC", "TGT", "S", "E", "T"
  List<int> _solutionRotations = [];
  int _hintCount = 0;
  int _hintIndex = -1;
  bool _shuffleActive = false;
  bool _isTutorialMode = false;
  bool _tutorialCompleted = false;
  int _actualGameLevel = 0;
  bool _playDailyMode = false;
  String _dailyModifierType = '';
  String _dailyModifierName = '';
  String _dailyModifierDesc = '';
  Timer? _gameTimer;
  int _timeLeft = -1;
  // Timer value at the moment the hard timer started; 0 when no timer ran.
  // Only used for the Speed Demon achievement check on clear.
  int _initialTime = 0;
  bool _timeBonusEarned = false;
  final Set<int> _lockedWires = {};
  Set<String> _activeModifiers = {};
  int _lastTappedIndex = -1;

  // COGNIQ-FIX:mod-active-helper
  bool _isModActive(String name) {
    if (_forcedModifier == name) return true;
    if (_playDailyMode) return _dailyModifierType == name;
    return _currentLevel >= RotationEngine.modifierStartLevel('circuitguide') &&
        _activeModifiers.contains(name);
  }

  // COGNIQ-FIX:mod-getters
  bool get _isFogActive => _isModActive('fog');
  bool get _isEndgame => _isModActive('timer');
  bool get _quota => _isModActive('quota');
  bool get _isRetroActive => _isModActive('retro');
  int _movesLeft = 0;
  int _optimalMoves = 0;
  bool _gameOver = false;

  /// The fewest taps that would take the board as generated to the stored
  /// solution. Rotations are compared by what a piece *connects*, not by its
  /// raw number: an "S" wire at rotation 0 and at rotation 2 is the same
  /// piece, so counting raw steps would charge for taps nobody needs to make.
  ///
  /// Tiles that are decoys, or simply off the powered path, are counted too.
  /// That can only ever overstate what the player must do, so the budget it
  /// feeds is never tighter than the board really requires.
  int _optimalTapsToSolution() {
    int total = 0;
    for (int i = 0; i < _wireTypes.length && i < _solutionRotations.length; i++) {
      final type = _wireTypes[i];
      if (type == 'SRC' || type == 'TGT' || type == 'EMPTY') continue;
      final wanted = _connectionsFor(type, _solutionRotations[i]).toSet();
      for (int k = 0; k < 4; k++) {
        if (setEquals(_connectionsFor(type, _rotations[i] + k).toSet(), wanted)) {
          total += k;
          break;
        }
      }
    }
    return total;
  }

  void _applyQuotaBudget() {
    _optimalMoves = _optimalTapsToSolution();
    _movesLeft = circuitGuideQuotaBudget(
      optimalMoves: _optimalMoves,
      level: _currentLevel,
    );
  }

  void _onOutOfMoves() {
    _gameTimer?.cancel();
    AudioManager.playFail();
    settingsNotifier.hapticError();
    setState(() => _gameOver = true);
  }

  bool _adjacent(int a, int b, int W) {
    final ra = a ~/ W, ca = a % W, rb = b ~/ W, cb = b % W;
    return (ra == rb && (ca - cb).abs() == 1) || (ca == cb && (ra - rb).abs() == 1);
  }

  bool _tooClose(int idx, int srcIdx, int srcNeighbor, Set<int> chosen, int W) {
    if (idx == srcIdx || idx == srcNeighbor) return true;
    if (_adjacent(idx, srcIdx, W)) return true;
    for (final t in chosen) {
      if (idx == t || _adjacent(idx, t, W)) return true;
    }
    return false;
  }

  int _maxSeparatedTargets(int W) {
    final perimeter = (W <= 1) ? 1 : (4 * W - 4);
    return (perimeter ~/ 2).clamp(1, 12);
  }

  bool _boardIsValid(int srcIdx, List<int> tgts, int W) {
    for (final t in tgts) {
      if (_adjacent(t, srcIdx, W)) return false;
      for (final u in tgts) {
        if (t != u && _adjacent(t, u, W)) return false;
      }
    }
    return true;
  }

  /// Modifiers now begin at a per-game level chosen in RotationEngine
  /// rather than a flat level 30 for every game.
  bool get _modsOn => !_playDailyMode && RotationEngine.hasModifiers('circuitguide', _currentLevel);

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
    int savedLvl = prefs.getInt(PrefsKeys.gameLevel('circuit_guide')) ?? 0;
    final active = await ShuffleManager.isActive();
    final hintCount = await HintManager.getHints('circuit_guide');
    
    if (mounted) {
      setState(() {
        _shuffleActive = active;
        _hintCount = hintCount;
        _actualGameLevel = savedLvl;
        _isTutorialMode = false;
        _currentLevel = _playDailyMode ? (savedLvl % 10) : savedLvl;
        _loadLevel();
      });
    }
  }

  // COGNIQ-FIX:mod-desc-copy
  String _getModifierDescription(String mod) {
    switch (mod) {
      case 'tortuosity':
        return 'Wires wind through longer, more complex paths.';
      case 'junctionDensity':
        return 'More cross-track junctions connect the circuit.';
      case 'decoyWires':
        return 'Disconnected decoy wires cross the board.';
      case 'scrambleDepth':
        return 'Tiles are rotated more times from their solution.';
      case 'timer':
        return 'Complete the circuit before time runs out.';
      case 'retro':
        return 'Classic CRT circuit visual styling.';
      case 'fog':
        return 'A dense fog obscures portions of the circuit.';
      case 'quota':
        return 'Complete the circuit within a tight move budget.';
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
    HintManager.startLevel('circuit_guide');
    setState(() {
      _isSuccess = false;
      _lockedWires.clear();
      _activeModifiers.clear();
      _lastTappedIndex = -1;
      if (_playDailyMode && _dailyModifierType.isNotEmpty) {
        _activeModifiers.add(_dailyModifierType);
      }
      _gameTimer?.cancel();
      _timeLeft = -1;
      _timeBonusEarned = false;

      final rng = _playDailyMode
          ? Random(_currentLevel + 2026)
          : RotationEngine.getDeterminism('circuitguide', _currentLevel);

      int srcIdx = 0;
      final List<int> tgts = [];
      int srcNeighbor = 0;
      final int W;
      final bool generateProc = _isEndgame || (_currentLevel >= 5);

      if (_isEndgame) {
        int numTargets = 6;
        if (_currentLevel >= 90) {
          _gridSize = 8;
          numTargets = 6;
        } else {
          if (_currentLevel < 35) {
            _gridSize = 5;
            numTargets = 4;
          } else if (_currentLevel < 42) {
            _gridSize = 6;
            numTargets = 4;
          } else if (_currentLevel < 50) {
            _gridSize = 6;
            numTargets = 5;
          } else if (_currentLevel < 60) {
            _gridSize = 7;
            numTargets = 5;
          } else if (_currentLevel < 70) {
            _gridSize = 7;
            numTargets = 6;
          } else {
            _gridSize = 8;
            numTargets = 6;
          }
        }
        W = _gridSize;
        bool isSmallGrid = (_gridSize <= 5);
        _activeModifiers = RotationEngine.getActiveModifiers(
          gameId: 'circuitguide',
          levelIndex: _currentLevel,
          pool: kCircuitGuideEndgamePool,
          minActive: 2,
          maxActive: 3,
          smallGrid: isSmallGrid,
        );
        if (_forcedModifier != null) {
          _activeModifiers = {_forcedModifier!};
        }
        
        final side = rng.nextInt(4);
        if (side == 0) {
          srcIdx = rng.nextInt(W);
          srcNeighbor = srcIdx + W;
        } else if (side == 1) {
          srcIdx = rng.nextInt(W) * W + (W - 1);
          srcNeighbor = srcIdx - 1;
        } else if (side == 2) {
          srcIdx = W * (W - 1) + rng.nextInt(W);
          srcNeighbor = srcIdx - W;
        } else {
          srcIdx = rng.nextInt(W) * W;
          srcNeighbor = srcIdx + 1;
        }

        final otherSides = [0, 1, 2, 3]..remove(side);
        final Set<int> chosenIndices = {};
        final int targetCount = numTargets.clamp(1, _maxSeparatedTargets(W));
        int guard = 0;
        while (chosenIndices.length < targetCount && guard < 800) {
          guard++;
          final targetSide = otherSides[rng.nextInt(otherSides.length)];
          final offset = rng.nextInt(W);
          int targetIdx;
          if (targetSide == 0) {
            targetIdx = offset;
          } else if (targetSide == 1) {
            targetIdx = offset * W + (W - 1);
          } else if (targetSide == 2) {
            targetIdx = W * (W - 1) + offset;
          } else {
            targetIdx = offset * W;
          }
          if (!_tooClose(targetIdx, srcIdx, srcNeighbor, chosenIndices, W)) {
            chosenIndices.add(targetIdx);
          }
        }
        tgts.addAll(chosenIndices);
      } else {
        if (_currentLevel < 5) {
          _gridSize = 3;
          _rotations = List.filled(9, 0);
          if (_currentLevel == 0) {
            _wireTypes = ["SRC", "E", "S", "S", "S", "E", "S", "E", "TGT"];
            _rotations = [1, 1, 0, 0, 0, 1, 1, 3, 3];
          } else if (_currentLevel == 1) {
            _wireTypes = ["SRC", "E", "S", "S", "S", "S", "E", "E", "TGT"];
            _rotations = [1, 0, 0, 0, 0, 0, 0, 1, 3];
          } else if (_currentLevel == 2) {
            _wireTypes = ["SRC", "S", "E", "S", "E", "E", "S", "E", "TGT"];
            _rotations = [1, 1, 0, 2, 0, 1, 0, 3, 3];
          } else if (_currentLevel == 3) {
            _wireTypes = ["SRC", "E", "E", "E", "S", "S", "S", "E", "TGT"];
            _rotations = [1, 0, 0, 0, 0, 0, 0, 1, 3];
          } else if (_currentLevel == 4) {
            _wireTypes = ["SRC", "E", "S", "E", "E", "S", "E", "S", "TGT"];
            _rotations = [1, 0, 0, 0, 0, 0, 1, 0, 3];
          }
          W = _gridSize;
          srcIdx = 0;
          tgts.add(8);
          srcNeighbor = 1;
        } else {
          int numTargets = 1;
          if (_currentLevel < 8) {
            _gridSize = 3;
            numTargets = 1;
          } else if (_currentLevel < 12) {
            _gridSize = 3;
            numTargets = 2;
          } else if (_currentLevel < 17) {
            _gridSize = 4;
            numTargets = 2;
          } else if (_currentLevel < 22) {
            _gridSize = 4;
            numTargets = 3;
          } else if (_currentLevel < 28) {
            _gridSize = 5;
            numTargets = 3;
          } else if (_currentLevel < 35) {
            _gridSize = 5;
            numTargets = 4;
          } else if (_currentLevel < 42) {
            _gridSize = 6;
            numTargets = 4;
          } else if (_currentLevel < 50) {
            _gridSize = 6;
            numTargets = 5;
          } else if (_currentLevel < 60) {
            _gridSize = 7;
            numTargets = 5;
          } else if (_currentLevel < 70) {
            _gridSize = 7;
            numTargets = 6;
          } else {
            _gridSize = 8;
            numTargets = 6;
          }
          
          W = _gridSize;

          // Below the endgame the board is built without consulting modifiers,
          // so only offer ones that act purely on presentation. Announcing
          // 'tortuosity' or 'decoyWires' here would name a modifier that then
          // did nothing, which is exactly the trap Sum Strike had fallen into.
          if (_modsOn) {
            _activeModifiers = RotationEngine.getActiveModifiers(
              gameId: 'circuitguide',
              levelIndex: _currentLevel,
              pool: kCircuitGuidePresentationPool,
              minActive: 1,
              maxActive: 2,
            );
            if (_forcedModifier != null) {
              _activeModifiers = {_forcedModifier!};
            }
          } else {
            _activeModifiers = {};
          }

          final side = rng.nextInt(4);
          if (side == 0) {
            srcIdx = rng.nextInt(W);
            srcNeighbor = srcIdx + W;
          } else if (side == 1) {
            srcIdx = rng.nextInt(W) * W + (W - 1);
            srcNeighbor = srcIdx - 1;
          } else if (side == 2) {
            srcIdx = W * (W - 1) + rng.nextInt(W);
            srcNeighbor = srcIdx - W;
          } else {
            srcIdx = rng.nextInt(W) * W;
            srcNeighbor = srcIdx + 1;
          }

          final otherSides = [0, 1, 2, 3]..remove(side);
          final Set<int> chosenIndices = {};
          final int targetCount = numTargets.clamp(1, _maxSeparatedTargets(W));
          int guard = 0;
          while (chosenIndices.length < targetCount && guard < 800) {
            guard++;
            final targetSide = otherSides[rng.nextInt(otherSides.length)];
            final offset = rng.nextInt(W);
            int targetIdx;
            if (targetSide == 0) {
              targetIdx = offset;
            } else if (targetSide == 1) {
              targetIdx = offset * W + (W - 1);
            } else if (targetSide == 2) {
              targetIdx = W * (W - 1) + offset;
            } else {
              targetIdx = offset * W;
            }
            if (!_tooClose(targetIdx, srcIdx, srcNeighbor, chosenIndices, W)) {
              chosenIndices.add(targetIdx);
            }
          }
          tgts.addAll(chosenIndices);
        }
      }

      if (generateProc) {
        final Map<int, int> targetNeighbors = {};
        List<List<int>> connections = List.generate(W * W, (_) => <int>[]);
        
        int dfsSteps = 0;
        bool findPathDFS(int current, Set<int> treeNodes, List<int> path, Set<int> pathSet, List<List<int>> connections, Random r) {
          dfsSteps++;
          if (dfsSteps > 4000) {
            return false;
          }
          if (treeNodes.contains(current)) {
            if (connections[current].length < 3) {
              path.add(current);
              return true;
            }
            return false;
          }
          
          int row = current ~/ W;
          int col = current % W;
          List<int> neighbors = [];
          if (row > 0) neighbors.add(current - W);
          if (row < W - 1) neighbors.add(current + W);
          if (col > 0) neighbors.add(current - 1);
          if (col < W - 1) neighbors.add(current + 1);
          
          neighbors.removeWhere((n) => n == srcIdx || tgts.contains(n));
          neighbors.shuffle(r);
          
          for (int n in neighbors) {
            if (pathSet.contains(n)) continue;
            
            if (treeNodes.contains(n)) {
              if (connections[n].length < 3) {
                int reqSpaceForCurrent = (current == path[0]) ? 1 : 2;
                if (connections[current].length + reqSpaceForCurrent <= 3) {
                  path.add(n);
                  return true;
                }
              }
              continue;
            }
            
            if (connections[n].length + 2 <= 3) {
              int reqSpaceForCurrent = (current == path[0]) ? 1 : 2;
              if (connections[current].length + reqSpaceForCurrent <= 3) {
                pathSet.add(n);
                path.add(n);
                if (findPathDFS(n, treeNodes, path, pathSet, connections, r)) {
                  return true;
                }
                path.removeLast();
                pathSet.remove(n);
              }
            }
          }
          return false;
        }

        bool success = false;
        int generationRetries = 0;
        while (!success && generationRetries < 50) {
          generationRetries++;
          int attempts = 0;
          final retryRng = Random(rng.nextInt(1000000) + generationRetries);
          while (!success && attempts < 200) {
            attempts++;
            for (int i = 0; i < W * W; i++) {
              connections[i] = [];
            }
            
            connections[srcIdx].add(srcNeighbor);
            connections[srcNeighbor].add(srcIdx);
            
            targetNeighbors.clear();
            final List<int> tNeighbors = [];
            bool skipDFS = false;
            for (int t in tgts) {
              int tNeighbor = -1;
              List<int> candidates = [];
              int r = t ~/ W;
              int c = t % W;
              if (r == 0) candidates.add(t + W);
              if (r == W - 1) candidates.add(t - W);
              if (c == 0) candidates.add(t + 1);
              if (c == W - 1) candidates.add(t - 1);
              
              candidates.removeWhere((n) => tgts.contains(n) || n == srcIdx);
              
              if (candidates.isNotEmpty) {
                tNeighbor = candidates[0];
              } else {
                skipDFS = true;
                break;
              }
              
              targetNeighbors[t] = tNeighbor;
              tNeighbors.add(tNeighbor);
              connections[t].add(tNeighbor);
              connections[tNeighbor].add(t);
            }
            
            if (skipDFS) {
              success = false;
              continue;
            }
            
            Set<int> treeNodes = {srcIdx, srcNeighbor};
            success = true;
            
            for (int tNeighbor in tNeighbors) {
              if (treeNodes.contains(tNeighbor)) continue;
              
              List<int> path = [tNeighbor];
              Set<int> pathSet = {tNeighbor};
              
              dfsSteps = 0;
              bool pathFound = findPathDFS(tNeighbor, treeNodes, path, pathSet, connections, retryRng);
              
              if (pathFound) {
                for (int i = 0; i < path.length - 1; i++) {
                  int u = path[i];
                  int v = path[i + 1];
                  connections[u].add(v);
                  connections[v].add(u);
                  treeNodes.add(u);
                }
              } else {
                success = false;
                break;
              }
            }

            if (success) {
              int tCount = 0;
              int playableCount = 0;
              for (int i = 0; i < W * W; i++) {
                if (i != srcIdx && !tgts.contains(i) && connections[i].isNotEmpty) {
                  playableCount++;
                  if (connections[i].length == 3) {
                    tCount++;
                  }
                }
              }

              bool tortuosityOk = true;
              if (_isModActive('tortuosity') && generationRetries < 5) {
                if (treeNodes.length < W * 1.8) {
                  tortuosityOk = false;
                }
              }

              bool junctionsOk = true;
              if (_isModActive('junctionDensity') && generationRetries < 5) {
                if (playableCount > 0 && (tCount / playableCount) < 0.25) {
                  junctionsOk = false;
                }
              }

              if (!tortuosityOk || !junctionsOk || !_boardIsValid(srcIdx, tgts, W)) {
                success = false;
              }
            }
          }
        }
        
        // Every other generator logs when it falls back to a best-effort board;
        // this one silently emitted whatever half-built state it had, so an
        // unsolvable level would ship with no trace of why.
        if (!success) {
          RotationEngine.logFallback('circuit_guide', _currentLevel);
        }

        // An orthogonal neighbour that actually exists on the grid. The old
        // default of `i + 1` wrapped past the right-hand edge onto the next
        // row, producing a rotation pointing at a cell that is not adjacent.
        int safeNeighbor(int i) {
          if (i >= W) return i - W;
          if (i + W < W * W) return i + W;
          if (i % W > 0) return i - 1;
          return i + 1;
        }

        _wireTypes = List.filled(W * W, "");
        _rotations = List.filled(W * W, 0);

        for (int i = 0; i < W * W; i++) {
          if (i == srcIdx) {
            _wireTypes[i] = "SRC";
            int diff = srcNeighbor - srcIdx;
            if (diff == -W) _rotations[i] = 0;
            else if (diff == 1) _rotations[i] = 1;
            else if (diff == W) _rotations[i] = 2;
            else if (diff == -1) _rotations[i] = 3;
            continue;
          }
          if (tgts.contains(i)) {
            _wireTypes[i] = "TGT";
            int tNeighbor = targetNeighbors[i] ?? safeNeighbor(i);

            int diff = tNeighbor - i;
            if (diff == -W) _rotations[i] = 0;
            else if (diff == 1) _rotations[i] = 1;
            else if (diff == W) _rotations[i] = 2;
            else if (diff == -1) _rotations[i] = 3;
            continue;
          }
          
          List<int> neighbors = connections[i];
          if (neighbors.isEmpty) {
            _wireTypes[i] = "EMPTY";
            _rotations[i] = 0;
            continue;
          }
          
          List<int> dirs = [];
          for (int n in neighbors) {
            int diff = n - i;
            if (diff == -W) dirs.add(0);
            else if (diff == 1) dirs.add(1);
            else if (diff == W) dirs.add(2);
            else if (diff == -1) dirs.add(3);
          }
          
          dirs.sort();
          
          if (dirs.length < 2) {
            _wireTypes[i] = "EMPTY";
            _rotations[i] = 0;
            continue;
          }
          
          if (dirs.length == 2) {
            if ((dirs[0] == 0 && dirs[1] == 2) || (dirs[0] == 1 && dirs[1] == 3)) {
              _wireTypes[i] = "S";
              _rotations[i] = dirs[0] == 0 ? 1 : 0;
            } else {
              _wireTypes[i] = "E";
              if (dirs[0] == 0 && dirs[1] == 1) _rotations[i] = 0;
              else if (dirs[0] == 1 && dirs[1] == 2) _rotations[i] = 1;
              else if (dirs[0] == 2 && dirs[1] == 3) _rotations[i] = 2;
              else if (dirs[0] == 0 && dirs[1] == 3) _rotations[i] = 3;
            }
          } else if (dirs.length == 3) {
            _wireTypes[i] = "T";
            if (!dirs.contains(0)) _rotations[i] = 0;
            else if (!dirs.contains(1)) _rotations[i] = 1;
            else if (!dirs.contains(2)) _rotations[i] = 2;
            else if (!dirs.contains(3)) _rotations[i] = 3;
          } else {
            _wireTypes[i] = "EMPTY";
            _rotations[i] = 0;
          }
        }
      }
      
      _solutionRotations = List.from(_rotations);

      // Stage 5: Decoy Wires (L75+)
      if (_isModActive('decoyWires')) {
        int decoyCount = 1 + (_currentLevel >= 30 ? (_currentLevel - 30) ~/ 4 : 0); // not-a-modifier-gate
        if (decoyCount > W) decoyCount = W;

        List<int> emptyIndices = [];
        for (int i = 0; i < W * W; i++) {
          if (_wireTypes[i] == "EMPTY" && i != srcIdx && !tgts.contains(i)) {
            emptyIndices.add(i);
          }
        }
        emptyIndices.shuffle(rng);
        for (int i = 0; i < min(decoyCount, emptyIndices.length); i++) {
          int idx = emptyIndices[i];
          _wireTypes[idx] = rng.nextBool() ? "S" : "E";
          _solutionRotations[idx] = rng.nextInt(4);
          _rotations[idx] = rng.nextInt(4);
        }
      }

      final playRng = Random(_currentLevel * 43 + 999);
      for (int i = 0; i < _gridSize * _gridSize; i++) {
        if (_wireTypes[i] != "SRC" && _wireTypes[i] != "TGT" && _wireTypes[i] != "EMPTY") {
          _rotations[i] = playRng.nextInt(4);
          // Stage 4: Scramble depth (L60+ ensures no pre-solved tiles)
          bool checkScramble = _isModActive('scrambleDepth');
          if (checkScramble && _rotations[i] == _solutionRotations[i]) {
            _rotations[i] = (_solutionRotations[i] + 1 + playRng.nextInt(3)) % 4;
          }
        }
      }

      _lockedWires.clear();

      // Derived from the finished board, so it has to run after the scramble.
      _movesLeft = 0;
      _optimalMoves = 0;
      _gameOver = false;
      if (_quota) _applyQuotaBudget();

      if (_isEndgame) {
        _timeLeft = 25 + (_gridSize * 10);
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
              }
            });
          }
        });
      }
    });
  }

  void _resetBoard() {
    setState(() {
      _isSuccess = false;
      _gameOver = false;
      _lockedWires.clear();
      final playRng = Random();
      for (int i = 0; i < _gridSize * _gridSize; i++) {
        if (_wireTypes[i] != "SRC" && _wireTypes[i] != "TGT" && _wireTypes[i] != "EMPTY") {
          _rotations[i] = playRng.nextInt(4);
          bool checkScramble = _isModActive('scrambleDepth');
          if (checkScramble && _rotations[i] == _solutionRotations[i]) {
            _rotations[i] = (_solutionRotations[i] + 1 + playRng.nextInt(3)) % 4;
          }
        }
      }
      // Reset Board re-scrambles the whole level, so it is a restart rather
      // than an undo -- the budget is refilled to match the board it now
      // describes. Nothing is gained by using it: every rotation made so far
      // is thrown away with it.
      if (_quota) _applyQuotaBudget();
    });
  }

  List<int> _getConnections(int idx) =>
      _connectionsFor(_wireTypes[idx], _rotations[idx]);

  /// Which sides a piece opens onto, for a given type and rotation.
  ///
  /// Split out from [_getConnections] so a rotation can be judged without
  /// being the one currently on the board -- the hint needs to compare a
  /// tile against the solution's rotation. That matters because an "S" wire
  /// is symmetric: rotations 0 and 2 are the same piece, as are 1 and 3.
  List<int> _connectionsFor(String type, int rotation) {
    final rot = rotation % 4;

    if (type == "SRC" || type == "TGT") {
      return [rot];
    }
    if (type == "S") {
      if (rot == 0 || rot == 2) {
        return [1, 3];
      } else {
        return [0, 2];
      }
    }
    if (type == "E") {
      if (rot == 0) return [0, 1];
      if (rot == 1) return [1, 2];
      if (rot == 2) return [2, 3];
      if (rot == 3) return [0, 3];
    }
    if (type == "T") {
      if (rot == 0) return [1, 2, 3];
      if (rot == 1) return [0, 2, 3];
      if (rot == 2) return [0, 1, 3];
      if (rot == 3) return [0, 1, 2];
    }
    return [];
  }


  List<bool> _getConnectedStatus() {
    List<bool> connected = List.filled(_gridSize * _gridSize, false);
    final src = _wireTypes.indexOf("SRC");
    if (src == -1) return connected;
    List<int> queue = [src];
    connected[src] = true;

    while (queue.isNotEmpty) {
      int curr = queue.removeAt(0);
      List<int> currConn = _getConnections(curr);

      int r = curr ~/ _gridSize;
      int c = curr % _gridSize;

      var directions = [
        (-1, 0, 0, 2), // North: dr=-1, dc=0, dir=0, opposite=2
        (0, 1, 1, 3),  // East: dr=0, dc=1, dir=1, opposite=3
        (1, 0, 2, 0),  // South: dr=1, dc=0, dir=2, opposite=0
        (0, -1, 3, 1), // West: dr=0, dc=-1, dir=3, opposite=1
      ];

      for (var d in directions) {
        int nr = r + d.$1;
        int nc = c + d.$2;
        int dir = d.$3;
        int opp = d.$4;

        if (nr >= 0 && nr < _gridSize && nc >= 0 && nc < _gridSize) {
          int nextIdx = nr * _gridSize + nc;
          if (!connected[nextIdx]) {
            if (currConn.contains(dir)) {
              List<int> nextConn = _getConnections(nextIdx);
              if (nextConn.contains(opp)) {
                connected[nextIdx] = true;
                queue.add(nextIdx);
              }
            }
          }
        }
      }
    }
    return connected;
  }

  void _checkConnections() {
    final conn = _getConnectedStatus();
    bool won = true;
    for (int i = 0; i < _wireTypes.length; i++) {
      if (_wireTypes[i] == "TGT" && !conn[i]) {
        won = false;
      }
    }

    if (won) {
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
    }
  }



  void _showJumpToLevelDialog() {
    showDialog(
      context: context,
      builder: (context) {
        int target = _currentLevel + 1;
        String? selectedMod = _forcedModifier;
        const pool = kCircuitGuideEndgamePool;
        
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

  /// The countdown the player actually sees. Turns terracotta at three moves
  /// left so running dry is never a surprise.
  Widget _buildQuotaPill() {
    final bool low = _movesLeft <= 3;
    final Color tone = low ? AppTheme.terracotta : AppTheme.slateBlue;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tone.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.rotate_right, size: 16, color: tone),
          const SizedBox(width: 6),
          Text(
            'Moves: $_movesLeft',
            style: GoogleFonts.spaceGrotesk(
              color: tone,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _onRotate(int idx) {
    if (_isSuccess || _gameOver) return;
    if (_wireTypes[idx] == "SRC" || _wireTypes[idx] == "TGT" || _wireTypes[idx] == "EMPTY") return;
    if (_lockedWires.contains(idx)) return;
    if (_quota && _movesLeft <= 0) return;

    AudioManager.playClick();
    settingsNotifier.hapticTap();
    setState(() {
      _lastTappedIndex = idx;
      _rotations[idx]++;
      if (_quota) _movesLeft--;
    });

    _checkConnections();

    if (_quota && _movesLeft <= 0 && !_isSuccess) _onOutOfMoves();
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
    final key = PrefsKeys.gameLevel('circuit_guide');
    int highest = prefs.getInt(key) ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt(key, _currentLevel + 1);
    }

    final earned = await HintManager.onLevelCleared(
      'circuit_guide',
      // Speed Demon: cleared a hard-timer level with more than half the
      // clock still left. _initialTime is 0 unless the timer modifier ran.
      isSpeedDemon: _initialTime > 0 && _timeLeft * 2 > _initialTime,
    );
    final hCount = await HintManager.getHints('circuit_guide');

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
          backgroundColor: AppTheme.accentFor('circuit_guide'),
        ),
      );
    }

    final newUnlocks = await AchievementManager.checkAndUnlock('circuit_guide');
    for (final a in newUnlocks) {
      if (mounted) {
        AchievementToast.show(context, a);
      }
    }
  }

  void _nextLevel() async {
    if (await ShuffleManager.isActive()) {
      final next = await ShuffleManager.pickNextGame('circuit_guide');
      if (mounted) ShuffleManager.navigateToGame(context, next);
      return;
    }
    setState(() {
      _currentLevel++;
      _loadLevel();
    });
  }

  Future<void> _useHint() async {
    if (_isSuccess || _hintIndex != -1) return;

    if (_hintCount <= 0) {
      BuyHintsDialog.show(
        context,
        initialGameId: 'circuit_guide',
        isFromGameScreen: true,
        onPurchaseComplete: () {
          HintManager.getHints('circuit_guide').then((val) {
            if (mounted) setState(() => _hintCount = val);
          });
        },
      );
      return;
    }

    List<int> wrongIndices = [];
    for (int i = 0; i < _wireTypes.length; i++) {
      if (_wireTypes[i] != "SRC" && _wireTypes[i] != "TGT" && _wireTypes[i] != "EMPTY") {
        // Compare what the piece actually connects, not its raw rotation. An
        // "S" wire at rotation 0 and at rotation 2 is the same piece, so the
        // hint used to spend itself pointing at tiles already the right way up.
        final current = _connectionsFor(_wireTypes[i], _rotations[i]);
        final wanted = _connectionsFor(_wireTypes[i], _solutionRotations[i]);
        if (!setEquals(current.toSet(), wanted.toSet())) {
          wrongIndices.add(i);
        }
      }
    }

    if (wrongIndices.isEmpty) return;

    settingsNotifier.hapticTap();
    final rng = Random();
    int targetIdx = wrongIndices[rng.nextInt(wrongIndices.length)];

    setState(() {
      _hintIndex = targetIdx;
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _hintIndex = -1;
        });
      }
    });

    await HintManager.useHint('circuit_guide');
    final hCount = await HintManager.getHints('circuit_guide');
    if (!mounted) return;
    setState(() {
      _hintCount = hCount;
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Hint: Flashing one incorrect wire!'),
      backgroundColor: AppTheme.accentFor('circuit_guide'),
      duration: const Duration(milliseconds: 1500),
    ));
  }

  void _showRules() {
    settingsNotifier.hapticTap();
    GameTutorialDialog.show(context, 'circuit_guide', 'Circuit Guide');
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    AudioManager.resumeMusic();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_wireTypes.isEmpty) {
      return Scaffold(
        backgroundColor: context.bgDark,
        appBar: AppBar(
          title: const GameTitle('Circuit Guide'),
          leading: IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        ),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.dustyMauve),
          ),
        ),
      );
    }

    final connected = _getConnectedStatus();
    final double screenWidth = MediaQuery.of(context).size.width;
    final double boardSize = min(screenWidth * 0.88, 360.0);

    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text('Circuit Guide', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        actions: [
          if (_shuffleActive)
            IconButton(
              icon: const Icon(Icons.skip_next_rounded),
              tooltip: 'Skip Game',
              onPressed: () => ShuffleManager.tryShuffleNavigate(context, 'circuit_guide'),
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
            onPressed: !_isSuccess
                ? () async {
                    if (_hintCount > 0) {
                      _useHint();
                    } else {
                      await BuyHintsDialog.show(
                        context,
                        initialGameId: 'circuit_guide',
                        onPurchaseComplete: () async {
                          final newCount = await HintManager.getHints('circuit_guide');
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
            icon: const Icon(Icons.help_outline, color: AppTheme.dustyMauve),
            tooltip: 'Rules',
            onPressed: _showRules,
          ),
          GameLevelChip(
            level: _currentLevel + 1,
            modeLabel: _isTutorialMode ? 'Tutorial' : (_playDailyMode ? 'Daily' : null),
            accent: AppTheme.accentFor('circuit_guide'),
            onTap: kDebugMode ? _showJumpToLevelDialog : null,
          ),
        ],
      ),
      body: SwipeTrailOverlay(
        accentColor: AppTheme.dustyMauve,
        child: Stack(
          children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 36),
            child: Column(
              children: [
                Expanded(
                  // Scrolls rather than overflowing: on a short screen the
                  // instruction line, board and controls together are a couple
                  // of pixels taller than the space available.
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _wireTypes.contains("TGT") && _wireTypes.where((t) => t == "TGT").length > 1
                              ? 'Rotate nodes to power all Bulbs.'
                              : 'Rotate nodes to connect the Power Source to the Bulb.', 
                          style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary), 
                          textAlign: TextAlign.center
                        ),
                        const SizedBox(height: 36),
                        if (_quota) ...[
                          Center(child: _buildQuotaPill()),
                          const SizedBox(height: 16),
                        ],
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
                        Container(
                          width: boardSize, 
                          height: boardSize,
                          decoration: BoxDecoration(
                            color: context.bgCard,
                            border: Border.all(
                              color: context.textMuted.withOpacity(0.35),
                              width: 2.0,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: RepaintBoundary(
                              child: Builder(
                                builder: (context) {
                                  final int srcIdx = _wireTypes.indexOf('SRC');
                                  final int activeIdx = _lastTappedIndex != -1 ? _lastTappedIndex : (srcIdx != -1 ? srcIdx : 0);
                                  final double revealRadius = (boardSize / _gridSize) * 1.6;
                                  return FogOverlay(
                                    enabled: _isFogActive,
                                    radius: revealRadius,
                                    focalPoint: Offset(
                                      ((activeIdx % _gridSize) + 0.5) * (boardSize / _gridSize),
                                      ((activeIdx ~/ _gridSize) + 0.5) * (boardSize / _gridSize),
                                    ),
                                    child: GridView.builder(
                                      padding: EdgeInsets.zero,
                                      physics: const NeverScrollableScrollPhysics(),
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: _gridSize),
                                      itemCount: _gridSize * _gridSize,
                                      itemBuilder: (context, idx) {
                                        final isNodeConnected = connected[idx];
                                        final isRetro = _activeModifiers.contains('retro');
                                        return AnimatedCircuitNode(
                                          type: _wireTypes[idx],
                                          index: idx,
                                          rotation: _rotations[idx],
                                          isConnected: isNodeConnected,
                                          onTap: () => _onRotate(idx),
                                          activeColor: isRetro ? const Color(0xFF39FF14) : Colors.amber,
                                          mutedColor: isRetro ? const Color(0xFF0F380F) : context.textMuted.withOpacity(0.25),
                                          isLevel9: _currentLevel >= 9,
                                          isLocked: _lockedWires.contains(idx),
                                          isRetro: isRetro,
                                        );
                                      },
                                    ),
                                  );
                                }
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),
                      ],
                    ),
                  ),
                ),
                if (!_isSuccess)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.bgCard,
                          foregroundColor: context.textPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: context.textMuted.withAlpha(40)),
                          ),
                        ),
                        onPressed: _resetBoard,
                        icon: const Icon(Icons.refresh),
                        label: Text('Reset Board', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                if (_isSuccess && !_playDailyMode && !_isTutorialMode)
                  AutoNextCountdown(
                    onNext: _nextLevel,
                    accentColor: AppTheme.dustyMauve,
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
          if (_gameOver && !_isSuccess)
            Positioned.fill(
              child: LossOverlay(
                onTryAgain: () {
                  setState(() {
                    _gameOver = false;
                    _loadLevel();
                  });
                },
                subtitle: 'Out of moves — the circuit stayed dark.',
                accentColor: AppTheme.dustyMauve,
              ),
            ),
          // if (_isTutorialMode)
          //   InteractiveTutorialOverlay(
          //     instruction: _tutorialCompleted
          //         ? "Nice! You completed the tutorial. Power successfully connects from the source to the lightbulb."
          //         : "Tap the wire tiles to rotate and align them so that power flows from the source to the bulb.",
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

class AnimatedCircuitNode extends StatelessWidget {
  final String type;
  final int index;
  final int rotation;
  final bool isConnected;
  final VoidCallback onTap;
  final Color activeColor;
  final Color mutedColor;
  final bool isLevel9;
  final bool isLocked;
  final bool isRetro;

  const AnimatedCircuitNode({
    super.key,
    required this.type,
    required this.index,
    required this.rotation,
    required this.isConnected,
    required this.onTap,
    required this.activeColor,
    required this.mutedColor,
    required this.isLevel9,
    required this.isLocked,
    required this.isRetro,
  });

  @override
  Widget build(BuildContext context) {
    final double targetAngle = rotation * (pi / 2);
    Widget tileContent = type == "EMPTY"
        ? const SizedBox()
        : TweenAnimationBuilder<double>(
            tween: Tween<double>(end: targetAngle),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            builder: (context, angle, child) {
              return CustomPaint(
                painter: WirePainter(
                  type: type,
                  index: index,
                  rotationAngle: angle,
                  isConnected: isConnected,
                  activeColor: activeColor,
                  mutedColor: mutedColor,
                  isLevel9: isLevel9,
                  isRetro: isRetro,
                ),
              );
            },
          );

    if (isLocked) {
      tileContent = Stack(
        children: [
          tileContent,
          const Positioned(
            right: 2,
            top: 2,
            child: Icon(
              Icons.lock,
              size: 11,
              color: Colors.redAccent,
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isRetro ? Colors.black : context.bgCard,
          border: Border.all(
            color: isRetro ? const Color(0xFF0F380F) : context.textMuted.withOpacity(0.35),
            width: 1.0,
          ),
        ),
        child: tileContent,
      ),
    );
  }
}

class WirePainter extends CustomPainter {
  final String type;
  final int index;
  final double rotationAngle;
  final bool isConnected;
  final Color activeColor;
  final Color mutedColor;
  final bool isLevel9;
  final bool isRetro;

  static const double _halfPi = 1.5707963267948966;

  WirePainter({
    required this.type,
    required this.index,
    required this.rotationAngle,
    required this.isConnected,
    required this.activeColor,
    required this.mutedColor,
    required this.isLevel9,
    required this.isRetro,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Color wireColor = isConnected ? activeColor : mutedColor;
    final paint = Paint()
      ..color = wireColor
      ..strokeWidth = isRetro ? 10.0 : 8.0
      ..strokeCap = isRetro ? StrokeCap.square : StrokeCap.round
      ..style = PaintingStyle.stroke;

    final double w = size.width;
    final double h = size.height;
    final double cx = w / 2;
    final double cy = h / 2;
    final double nodeR = (w < h ? w : h) * 0.25;

    final Offset east = Offset(w, cy);
    final Offset west = Offset(0, cy);
    final Offset north = Offset(cx, 0);

    if (type == "SRC" || type == "TGT") {
      final fillPaint = Paint()
        ..color = isConnected ? activeColor.withOpacity(0.12) : Colors.transparent
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, cy), nodeR, fillPaint);

      final borderPaint = Paint()
        ..color = wireColor.withOpacity(0.5)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(Offset(cx, cy), nodeR, borderPaint);

      final int iconCode = type == "SRC" ? Icons.bolt.codePoint : Icons.lightbulb_outline.codePoint;
      final textPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(iconCode),
          style: TextStyle(
            fontSize: 22,
            fontFamily: 'MaterialIcons',
            color: isConnected ? activeColor : mutedColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(cx - textPainter.width / 2, cy - textPainter.height / 2));

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(rotationAngle);
      canvas.translate(-cx, -cy);
      canvas.drawLine(north, Offset(cx, cy - nodeR), paint);
      canvas.restore();
    } else {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(rotationAngle);
      canvas.translate(-cx, -cy);

      if (type == "S") {
        canvas.drawLine(west, east, paint);
      } else if (type == "E") {
        canvas.drawArc(
          Rect.fromCircle(center: Offset(w, 0), radius: cx),
          _halfPi,
          _halfPi,
          false,
          paint,
        );
      } else if (type == "T") {
        canvas.drawLine(west, east, paint);
        canvas.drawLine(Offset(cx, cy), Offset(cx, h), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant WirePainter oldDelegate) {
    return oldDelegate.type != type ||
        oldDelegate.index != index ||
        oldDelegate.rotationAngle != rotationAngle ||
        oldDelegate.isConnected != isConnected ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.mutedColor != mutedColor ||
        oldDelegate.isLevel9 != isLevel9;
  }
}
