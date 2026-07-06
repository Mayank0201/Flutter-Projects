import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../widgets/auto_next_countdown.dart';
import '../../../widgets/challenge_cleared_overlay.dart';
import '../../../utils/ad_manager.dart';
import '../../../utils/audio_manager.dart';

import '../../../utils/hint_manager.dart';

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

  @override
  void initState() {
    super.initState();
    _initLevelState();
  }

  Future<void> _initLevelState() async {
    final prefs = await SharedPreferences.getInstance();
    _playDailyMode = prefs.getBool('play_daily_mode') ?? false;
    final savedLvl = prefs.getInt('level_circuit_guide') ?? 0;
    final hCount = await HintManager.getHints('circuit_guide');
    if (mounted) {
      setState(() {
        _hintCount = hCount;
        _currentLevel = _playDailyMode ? (savedLvl % 10) : savedLvl;
        _loadLevel();
      });
    }
  }

  void _loadLevel() {
    setState(() {
      _isSuccess = false;
      
      final seed = _currentLevel + 2026;
      final rng = Random(seed);

      if (_currentLevel < 9) {
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
        } else if (_currentLevel == 5) {
          _wireTypes = ["SRC", "E", "S", "S", "S", "E", "S", "E", "TGT"];
          _rotations = [1, 1, 0, 0, 0, 1, 1, 3, 3];
        } else if (_currentLevel == 6) {
          _wireTypes = ["SRC", "E", "S", "S", "S", "S", "E", "E", "TGT"];
          _rotations = [1, 0, 0, 0, 0, 0, 0, 1, 3];
        } else if (_currentLevel == 7) {
          _wireTypes = ["SRC", "S", "E", "S", "E", "E", "S", "E", "TGT"];
          _rotations = [1, 1, 0, 2, 0, 1, 0, 3, 3];
        } else if (_currentLevel == 8) {
          _wireTypes = ["SRC", "E", "E", "E", "S", "S", "S", "E", "TGT"];
          _rotations = [1, 0, 0, 0, 0, 0, 0, 1, 3];
        }
      } else {
        if (_currentLevel < 15) {
          _gridSize = 3;
        } else if (_currentLevel < 25) {
          _gridSize = 4;
        } else {
          _gridSize = 5;
        }
        
        final int W = _gridSize;
        final int numTargets = _currentLevel >= 12 ? 2 : 1;
        
        // Choose source and target positions randomly on opposite borders
        int srcIdx;
        final List<int> tgts = [];
        int srcNeighbor;
        
        final side = rng.nextInt(4); // 0: Top, 1: Right, 2: Bottom, 3: Left
        if (side == 0) {
          srcIdx = rng.nextInt(W);
          srcNeighbor = srcIdx + W;
          if (numTargets == 1) {
            tgts.add(W * (W - 1) + rng.nextInt(W));
          } else {
            tgts.add(W * (W - 1) + rng.nextInt(W ~/ 2));
            tgts.add(W * (W - 1) + W ~/ 2 + rng.nextInt(W - W ~/ 2));
          }
        } else if (side == 1) {
          srcIdx = rng.nextInt(W) * W + (W - 1);
          srcNeighbor = srcIdx - 1;
          if (numTargets == 1) {
            tgts.add(rng.nextInt(W) * W);
          } else {
            tgts.add(rng.nextInt(W ~/ 2) * W);
            tgts.add((W ~/ 2 + rng.nextInt(W - W ~/ 2)) * W);
          }
        } else if (side == 2) {
          srcIdx = W * (W - 1) + rng.nextInt(W);
          srcNeighbor = srcIdx - W;
          if (numTargets == 1) {
            tgts.add(rng.nextInt(W));
          } else {
            tgts.add(rng.nextInt(W ~/ 2));
            tgts.add(W ~/ 2 + rng.nextInt(W - W ~/ 2));
          }
        } else {
          srcIdx = rng.nextInt(W) * W;
          srcNeighbor = srcIdx + 1;
          if (numTargets == 1) {
            tgts.add(rng.nextInt(W) * W + (W - 1));
          } else {
            tgts.add(rng.nextInt(W ~/ 2) * W + (W - 1));
            tgts.add((W ~/ 2 + rng.nextInt(W - W ~/ 2)) * W + (W - 1));
          }
        }
        
        List<List<int>> connections = List.generate(W * W, (_) => <int>[]);
        
        bool success = false;
        int attempts = 0;
        while (!success && attempts < 1000) {
          attempts++;
          for (int i = 0; i < W * W; i++) {
            connections[i] = [];
          }
          
          connections[srcIdx].add(srcNeighbor);
          connections[srcNeighbor].add(srcIdx);
          
          final List<int> tNeighbors = [];
          for (int t in tgts) {
            int tNeighbor;
            if (t ~/ W == 0) tNeighbor = t + W;
            else if (t ~/ W == W - 1) tNeighbor = t - W;
            else if (t % W == 0) tNeighbor = t + 1;
            else tNeighbor = t - 1;
            
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
            int current = tNeighbor;
            bool pathFound = false;
            int walkAttempts = 0;
            
            while (walkAttempts < 200) {
              walkAttempts++;
              int r = current ~/ W;
              int c = current % W;
              List<int> neighbors = [];
              if (r > 0) neighbors.add(current - W);
              if (r < W - 1) neighbors.add(current + W);
              if (c > 0) neighbors.add(current - 1);
              if (c < W - 1) neighbors.add(current + 1);
              
              neighbors.removeWhere((n) => n == srcIdx || tgts.contains(n));
              
              if (neighbors.isEmpty) break;
              
              int nextNode = neighbors[rng.nextInt(neighbors.length)];
              if (treeNodes.contains(nextNode)) {
                path.add(nextNode);
                pathFound = true;
                break;
              }
              if (!pathSet.contains(nextNode)) {
                path.add(nextNode);
                pathSet.add(nextNode);
                current = nextNode;
              }
            }
            
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
            int tNeighbor;
            if (i ~/ W == 0) tNeighbor = i + W;
            else if (i ~/ W == W - 1) tNeighbor = i - W;
            else if (i % W == 0) tNeighbor = i + 1;
            else tNeighbor = i - 1;

            int diff = tNeighbor - i;
            if (diff == -W) _rotations[i] = 0;
            else if (diff == 1) _rotations[i] = 1;
            else if (diff == W) _rotations[i] = 2;
            else if (diff == -1) _rotations[i] = 3;
            continue;
          }
          
          List<int> neighbors = connections[i];
          if (neighbors.isEmpty) {
            _wireTypes[i] = rng.nextBool() ? "S" : "E";
            _rotations[i] = rng.nextInt(4);
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
            _wireTypes[i] = "S";
            _rotations[i] = 0;
          }
        }
      }
      
      _solutionRotations = List.from(_rotations);

      final playRng = Random(_currentLevel * 43 + 999);
      for (int i = 0; i < _gridSize * _gridSize; i++) {
        if (_wireTypes[i] != "SRC" && _wireTypes[i] != "TGT") {
          _rotations[i] = playRng.nextInt(4);
        }
      }
    });
  }

  List<int> _getConnections(int idx) {
    final type = _wireTypes[idx];
    final rot = _rotations[idx];

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
      _onLevelCleared();
    }
  }

  void _onRotate(int idx) {
    if (_isSuccess) return;
    if (_wireTypes[idx] == "SRC" || _wireTypes[idx] == "TGT") return;

    AudioManager.playClick();
    settingsNotifier.hapticTap();
    setState(() {
      _rotations[idx] = (_rotations[idx] + 1) % 4;
    });

    _checkConnections();
  }

  Future<void> _onLevelCleared() async {
    AudioManager.playSuccess();
    settingsNotifier.hapticSuccess();
    
    final prefs = await SharedPreferences.getInstance();
    final key = 'level_circuit_guide';
    int highest = prefs.getInt(key) ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt(key, _currentLevel + 1);
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
  }

  void _nextLevel() {
    setState(() {
      _currentLevel++;
      _loadLevel();
    });
  }

  Future<void> _useHint() async {
    if (_hintCount <= 0 || _isSuccess) return;

    List<int> wrongIndices = [];
    for (int i = 0; i < _wireTypes.length; i++) {
      if (_wireTypes[i] != "SRC" && _wireTypes[i] != "TGT") {
        if (_rotations[i] != _solutionRotations[i]) {
          wrongIndices.add(i);
        }
      }
    }

    if (wrongIndices.isEmpty) return;

    settingsNotifier.hapticTap();
    final rng = Random();
    int targetIdx = wrongIndices[rng.nextInt(wrongIndices.length)];

    setState(() {
      _rotations[targetIdx] = _solutionRotations[targetIdx];
    });

    await HintManager.useHint('circuit_guide');
    final hCount = await HintManager.getHints('circuit_guide');
    setState(() {
      _hintCount = hCount;
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Hint: Corrected one wire on the board!'),
      backgroundColor: AppTheme.accentFor('circuit_guide'),
    ));

    _checkConnections();
  }

  void _showRules() {
    settingsNotifier.hapticTap();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: context.textMuted.withAlpha(40)),
        ),
        title: Text(
          'How to Play',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary),
        ),
        content: Text(
          '• Tap wires to rotate them 90°.\n• Connect the power source to all lightbulbs.\n• Wires light up only when connected back to the source.',
          style: GoogleFonts.outfit(color: context.textSecondary, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Got it',
              style: GoogleFonts.outfit(color: AppTheme.dustyMauve, fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connected = _getConnectedStatus();

    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text('Circuit Guide', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        actions: [
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
                      '$_hintCount',
                      style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
            onPressed: _hintCount > 0 && !_isSuccess ? _useHint : null,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, color: AppTheme.dustyMauve),
            tooltip: 'Rules',
            onPressed: _showRules,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Level ${_currentLevel + 1}', 
                style: AppTheme.numberStyle(
                  color: AppTheme.dustyMauve, 
                  fontSize: 14, 
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
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
                        SizedBox(
                          width: 240, 
                          height: 240,
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
                              );
                            },
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
                        onPressed: _loadLevel,
                        icon: const Icon(Icons.refresh),
                        label: Text('Reset Board', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                if (_isSuccess && !_playDailyMode)
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
        ],
      ),
    );
  }
}

class AnimatedCircuitNode extends StatefulWidget {
  final String type;
  final int index;
  final int rotation;
  final bool isConnected;
  final VoidCallback onTap;
  final Color activeColor;
  final Color mutedColor;
  final bool isLevel9;

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
  });

  @override
  State<AnimatedCircuitNode> createState() => _AnimatedCircuitNodeState();
}

class _AnimatedCircuitNodeState extends State<AnimatedCircuitNode> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _startAngle = 0.0;
  double _targetAngle = 0.0;
  double _cleanTargetAngle = 0.0;

  @override
  void initState() {
    super.initState();
    _cleanTargetAngle = widget.rotation * (pi / 2);
    _startAngle = _cleanTargetAngle;
    _targetAngle = _cleanTargetAngle;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animation = Tween<double>(begin: _startAngle, end: _targetAngle).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(AnimatedCircuitNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rotation != widget.rotation) {
      _startAngle = _animation.value;
      double diff = (widget.rotation - oldWidget.rotation) % 4;
      if (diff < 0) diff += 4;
      
      _cleanTargetAngle += diff * (pi / 2);
      _targetAngle = _cleanTargetAngle;
      
      _animation = Tween<double>(begin: _startAngle, end: _targetAngle).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      );
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return CustomPaint(
            painter: WirePainter(
              type: widget.type,
              index: widget.index,
              rotationAngle: _animation.value,
              isConnected: widget.isConnected,
              activeColor: widget.activeColor,
              mutedColor: widget.mutedColor,
              isLevel9: widget.isLevel9,
            ),
          );
        },
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
      ..strokeWidth = 5
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
