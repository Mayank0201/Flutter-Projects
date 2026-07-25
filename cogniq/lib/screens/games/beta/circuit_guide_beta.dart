import 'dart:math';
import 'dart:async';
import '../../../utils/rotation_engine.dart';
import '../../../utils/point_manager.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../widgets/auto_next_countdown.dart';
import '../../../widgets/challenge_cleared_overlay.dart';
import '../../../widgets/game_tutorial_dialog.dart';
import '../../../utils/audio_manager.dart';
import '../../../utils/hint_manager.dart';
import '../../../utils/shuffle_manager.dart';
import '../../../widgets/swipe_trail_overlay.dart';
import '../../../widgets/buy_hints_dialog.dart';
import '../../../utils/achievement_manager.dart';
import '../../../widgets/achievement_toast.dart';

class CircuitGuideBetaScreen extends StatefulWidget {
  const CircuitGuideBetaScreen({super.key});
  @override
  State<CircuitGuideBetaScreen> createState() => _CircuitGuideBetaScreenState();
}

class _CircuitGuideBetaScreenState extends State<CircuitGuideBetaScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  bool _playDailyMode = false;
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
  bool get _isEndgame => !_playDailyMode && _currentLevel >= 30;
  Timer? _gameTimer;
  int _timeLeft = -1;
  bool _timeBonusEarned = false;
  final Set<int> _lockedWires = {};
  Set<String> _activeModifiers = {};

  @override
  void initState() {
    super.initState();
    _initLevelState();
  }

  Future<void> _initLevelState() async {
    final prefs = await SharedPreferences.getInstance();
    _playDailyMode = prefs.getBool('play_daily_mode') ?? false;
    int savedLvl = prefs.getInt('level_circuit_guide') ?? 0;
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

  void _loadLevel() {
    setState(() {
      _isSuccess = false;
      _lockedWires.clear();
      _activeModifiers.clear();
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
          pool: ['tortuosity', 'junctionDensity', 'decoyWires', 'scrambleDepth', 'timer'],
          minActive: 2,
          maxActive: 3,
          smallGrid: isSmallGrid,
        );
        
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
        final int targetCount = numTargets.clamp(1, W * 2);
        while (chosenIndices.length < targetCount) {
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
          if (targetIdx != srcIdx) {
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
          final int targetCount = numTargets.clamp(1, W * 2);
          while (chosenIndices.length < targetCount) {
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
            if (targetIdx != srcIdx) {
              chosenIndices.add(targetIdx);
            }
          }
          tgts.addAll(chosenIndices);
        }
      }

      if (generateProc) {
        final Map<int, int> targetNeighbors = {};
        List<List<int>> connections = List.generate(W * W, (_) => <int>[]);
        
        bool findPathDFS(int current, Set<int> treeNodes, List<int> path, Set<int> pathSet, List<List<int>> connections, Random r) {
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
                path.add(n);
                return true;
              }
              continue;
            }
            
            pathSet.add(n);
            path.add(n);
            if (findPathDFS(n, treeNodes, path, pathSet, connections, r)) {
              return true;
            }
            path.removeLast();
            pathSet.remove(n);
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
                if (r == 0) tNeighbor = t + W;
                else if (r == W - 1) tNeighbor = t - W;
                else if (c == 0) tNeighbor = t + 1;
                else tNeighbor = t - 1;
              }
              
              targetNeighbors[t] = tNeighbor;
              tNeighbors.add(tNeighbor);
              connections[t].add(tNeighbor);
              connections[tNeighbor].add(t);
            }
            
            Set<int> treeNodes = {srcIdx, srcNeighbor};
            success = true;
            
            for (int tNeighbor in tNeighbors) {
              if (treeNodes.contains(tNeighbor)) continue;
              
              List<int> path = [tNeighbor];
              Set<int> pathSet = {tNeighbor};
              
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
              if (!_playDailyMode && _currentLevel >= 30 && generationRetries < 5) {
                bool checkTort = _activeModifiers.contains('tortuosity');
                if (checkTort && treeNodes.length < W * 1.8) {
                  tortuosityOk = false;
                }
              }

              bool junctionsOk = true;
              if (!_playDailyMode && _currentLevel >= 30 && generationRetries < 5) {
                bool checkJunc = _activeModifiers.contains('junctionDensity');
                if (checkJunc && playableCount > 0 && (tCount / playableCount) < 0.25) {
                  junctionsOk = false;
                }
              }

              if (!tortuosityOk || !junctionsOk) {
                success = false;
              }
            }
          }
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
            int tNeighbor = targetNeighbors[i] ?? (i + 1);

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
      if (!_playDailyMode && _currentLevel >= 30 && _activeModifiers.contains('decoyWires')) {
        int decoyCount = 1 + (_currentLevel - 30) ~/ 4;
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
          bool checkScramble = false;
          if (_currentLevel >= 30) {
            checkScramble = _activeModifiers.contains('scrambleDepth');
          }
          if (checkScramble && _rotations[i] == _solutionRotations[i]) {
            _rotations[i] = (_solutionRotations[i] + 1 + playRng.nextInt(3)) % 4;
          }
        }
      }

      _lockedWires.clear();

      if (!_playDailyMode && _currentLevel >= 30 && _activeModifiers.contains('timer')) {
        _timeLeft = 25 + (_gridSize * 10);
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
      _lockedWires.clear();
      final playRng = Random();
      for (int i = 0; i < _gridSize * _gridSize; i++) {
        if (_wireTypes[i] != "SRC" && _wireTypes[i] != "TGT" && _wireTypes[i] != "EMPTY") {
          _rotations[i] = playRng.nextInt(4);
          bool checkScramble = false;
          if (_currentLevel >= 30) {
            checkScramble = _activeModifiers.contains('scrambleDepth');
          }
          if (checkScramble && _rotations[i] == _solutionRotations[i]) {
            _rotations[i] = (_solutionRotations[i] + 1 + playRng.nextInt(3)) % 4;
          }
        }
      }
    });
  }

  List<int> _getConnections(int idx) {
    final type = _wireTypes[idx];
    final rot = _rotations[idx] % 4;

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
    final controller = TextEditingController(text: '${_currentLevel + 1}');
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
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dustyMauve),
            onPressed: () {
              final val = int.tryParse(controller.text.trim());
              if (val != null && val >= 1) {
                Navigator.pop(context);
                setState(() {
                  _currentLevel = val - 1;
                  _loadLevel();
                });
              }
            },
            child: Text('Go', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _onRotate(int idx) {
    if (_isSuccess) return;
    if (_wireTypes[idx] == "SRC" || _wireTypes[idx] == "TGT" || _wireTypes[idx] == "EMPTY") return;
    if (_lockedWires.contains(idx)) return;

    AudioManager.playClick();
    settingsNotifier.hapticTap();
    setState(() {
      _rotations[idx]++;
    });

    _checkConnections();
  }

  Future<void> _onLevelCleared() async {
    _gameTimer?.cancel();
    AudioManager.playSuccess();
    settingsNotifier.hapticSuccess();
    
    final prefs = await SharedPreferences.getInstance();
    final key = 'level_circuit_guide';
    int highest = prefs.getInt(key) ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt(key, _currentLevel + 1);
    }

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

    final earned = await HintManager.onLevelCleared('circuit_guide');
    final hCount = await HintManager.getHints('circuit_guide');

    setState(() {
      _hintCount = hCount;
      _isSuccess = true;
    });

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
        if ((_rotations[i] % 4) != (_solutionRotations[i] % 4)) {
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
          title: Text('Circuit Guide', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
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
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        actions: [
          if (_shuffleActive)
            IconButton(
              icon: const Icon(Icons.skip_next_rounded),
              tooltip: 'Skip Game',
              onPressed: () => ShuffleManager.tryShuffleNavigate(context, 'circuit_guide'),
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
          GestureDetector(
            onTap: null,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isTutorialMode ? 'Tutorial' : 'Level ${_currentLevel + 1}', 
                      style: AppTheme.numberStyle(
                        color: AppTheme.dustyMauve, 
                        fontSize: 14, 
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!_isTutorialMode) ...[
                      const SizedBox(width: 4),
                      const Icon(null, size: 12, color: AppTheme.dustyMauve),
                    ],
                  ],
                ),
              ),
            ),
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
                  child: Center(
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
                              child: GridView.builder(
                                padding: EdgeInsets.zero,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: _gridSize),
                                itemCount: _gridSize * _gridSize,
                                itemBuilder: (context, idx) {
                                  final isNodeConnected = connected[idx];
                                  return AnimatedCircuitNode(
                                    type: _wireTypes[idx],
                                    index: idx,
                                    rotation: _rotations[idx],
                                    isConnected: isNodeConnected,
                                    onTap: () => _onRotate(idx),
                                    activeColor: Colors.amber,
                                    mutedColor: context.textMuted.withOpacity(0.25),
                                    isLevel9: _currentLevel >= 9,
                                    isLocked: _lockedWires.contains(idx),
                                  );
                                },
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
          color: context.bgCard,
          border: Border.all(
            color: context.textMuted.withOpacity(0.35),
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

  static const double _halfPi = 1.5707963267948966;

  WirePainter({
    required this.type,
    required this.index,
    required this.rotationAngle,
    required this.isConnected,
    required this.activeColor,
    required this.mutedColor,
    required this.isLevel9,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Color wireColor = isConnected ? activeColor : mutedColor;
    final paint = Paint()
      ..color = wireColor
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
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
            color: isConnected ? Colors.amber : mutedColor,
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
