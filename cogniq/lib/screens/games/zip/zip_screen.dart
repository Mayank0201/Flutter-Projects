import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../utils/rules_helper.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/hint_manager.dart';

class ZipLevel {
  final int rows, cols;
  final List<List<int>> waypoints;
  const ZipLevel({required this.rows, required this.cols, required this.waypoints});
  int get maxWaypoint { int m = 0; for (var r in waypoints) { for (var v in r) { if (v > m) { m = v; } } } return m; }
  int get totalCells => rows * cols;
}

const List<ZipLevel> _kLevels = [
  ZipLevel(rows: 3, cols: 3, waypoints: [[0, 0, 0], [0, 1, 0], [0, 0, 2]]),
  ZipLevel(rows: 3, cols: 3, waypoints: [[0, 0, 3], [0, 2, 0], [1, 0, 0]]),
  ZipLevel(rows: 3, cols: 4, waypoints: [[4, 1, 0, 2], [0, 0, 0, 0], [0, 0, 3, 0]]),
  ZipLevel(rows: 3, cols: 4, waypoints: [[1, 0, 0, 2], [0, 0, 5, 0], [4, 0, 3, 0]]),
  ZipLevel(rows: 4, cols: 4, waypoints: [[0, 0, 3, 0], [2, 0, 0, 0], [0, 6, 1, 4], [0, 5, 0, 0]]),
  ZipLevel(rows: 4, cols: 4, waypoints: [[3, 0, 2, 0], [0, 0, 0, 0], [0, 5, 6, 1], [4, 0, 0, 7]]),
  ZipLevel(rows: 4, cols: 4, waypoints: [[0, 5, 0, 6], [0, 0, 7, 0], [4, 8, 2, 0], [0, 3, 0, 1]]),
  ZipLevel(rows: 4, cols: 5, waypoints: [[9, 0, 8, 0, 0], [1, 0, 6, 0, 7], [0, 2, 0, 5, 0], [0, 3, 0, 4, 0]]),
  ZipLevel(rows: 4, cols: 5, waypoints: [[0, 8, 2, 0, 3], [9, 0, 0, 1, 0], [0, 7, 0, 0, 4], [10, 0, 6, 5, 0]]),
  ZipLevel(rows: 4, cols: 5, waypoints: [[0, 4, 0, 1, 11], [5, 0, 3, 0, 0], [7, 6, 0, 2, 10], [0, 8, 0, 9, 0]]),
  ZipLevel(rows: 5, cols: 5, waypoints: [[0, 9, 0, 8, 0], [0, 10, 0, 0, 7], [11, 0, 3, 4, 0], [0, 2, 0, 0, 6], [12, 0, 1, 5, 0]]),
  ZipLevel(rows: 5, cols: 5, waypoints: [[8, 0, 9, 0, 10], [0, 5, 0, 11, 0], [7, 0, 4, 0, 12], [0, 6, 0, 3, 0], [1, 0, 2, 0, 13]]),
  ZipLevel(rows: 5, cols: 5, waypoints: [[0, 6, 1, 0, 14], [7, 0, 5, 2, 0], [0, 8, 4, 0, 13], [9, 0, 0, 3, 0], [0, 10, 11, 0, 12]]),
  ZipLevel(rows: 5, cols: 5, waypoints: [[15, 0, 14, 13, 0], [10, 0, 11, 0, 12], [9, 0, 0, 4, 0], [0, 8, 5, 2, 3], [7, 6, 0, 0, 1]]),
  ZipLevel(rows: 5, cols: 5, waypoints: [[11, 0, 12, 13, 1], [0, 10, 14, 0, 0], [0, 9, 15, 0, 2], [8, 6, 0, 16, 3], [7, 0, 5, 4, 0]]),
  ZipLevel(rows: 6, cols: 6, waypoints: [[0, 2, 0, 0, 4, 0], [1, 17, 3, 0, 0, 5], [16, 0, 0, 11, 6, 0], [0, 0, 12, 0, 10, 7], [15, 13, 0, 9, 0, 0], [0, 0, 14, 0, 0, 8]]),
  ZipLevel(rows: 6, cols: 6, waypoints: [[12, 0, 0, 9, 0, 8], [0, 11, 0, 0, 5, 0], [13, 0, 10, 4, 0, 7], [0, 16, 0, 0, 6, 0], [14, 0, 17, 3, 0, 1], [0, 15, 0, 18, 2, 0]]),
  ZipLevel(rows: 6, cols: 6, waypoints: [[14, 0, 0, 8, 0, 7], [0, 13, 9, 0, 6, 0], [15, 0, 0, 5, 0, 1], [0, 12, 10, 0, 4, 0], [16, 0, 11, 3, 0, 2], [0, 17, 0, 18, 0, 19]]),
  ZipLevel(rows: 6, cols: 6, waypoints: [[0, 6, 0, 20, 0, 19], [5, 4, 7, 0, 18, 0], [3, 0, 1, 8, 0, 17], [0, 2, 0, 0, 9, 16], [12, 0, 11, 10, 0, 0], [0, 13, 0, 14, 0, 15]]),
  ZipLevel(rows: 6, cols: 6, waypoints: [[0, 14, 0, 15, 18, 0], [13, 0, 12, 16, 0, 19], [10, 0, 11, 0, 17, 20], [0, 0, 5, 0, 4, 0], [9, 6, 0, 0, 3, 21], [0, 8, 7, 2, 0, 1]]),
  ZipLevel(rows: 6, cols: 6, waypoints: [[0, 19, 17, 0, 15, 14], [20, 0, 18, 16, 0, 0], [21, 0, 22, 7, 0, 13], [0, 5, 6, 0, 8, 0], [4, 2, 0, 0, 9, 12], [0, 3, 1, 10, 0, 11]]),
  ZipLevel(rows: 6, cols: 6, waypoints: [[1, 3, 0, 4, 6, 0], [0, 2, 23, 5, 0, 7], [20, 0, 0, 0, 10, 8], [19, 21, 22, 11, 9, 0], [0, 17, 16, 0, 12, 13], [18, 0, 0, 15, 14, 0]]),
  ZipLevel(rows: 6, cols: 6, waypoints: [[24, 0, 23, 21, 20, 0], [1, 0, 22, 0, 18, 19], [3, 2, 11, 0, 0, 17], [0, 0, 10, 12, 13, 16], [4, 9, 8, 0, 0, 0], [5, 0, 6, 7, 14, 15]]),
  ZipLevel(rows: 6, cols: 6, waypoints: [[9, 10, 0, 11, 15, 0], [0, 5, 0, 12, 14, 16], [8, 6, 4, 0, 13, 17], [7, 0, 3, 0, 21, 0], [1, 2, 0, 22, 20, 18], [25, 24, 0, 23, 0, 19]]),
  ZipLevel(rows: 6, cols: 6, waypoints: [[16, 15, 0, 14, 12, 11], [17, 0, 1, 13, 0, 10], [19, 18, 2, 0, 9, 0], [0, 23, 24, 3, 8, 0], [20, 0, 0, 4, 0, 7], [21, 22, 25, 26, 5, 6]]),
  ZipLevel(rows: 6, cols: 6, waypoints: [[27, 26, 0, 25, 24, 23], [1, 2, 0, 3, 22, 0], [12, 0, 11, 4, 21, 20], [13, 9, 10, 5, 0, 0], [0, 0, 8, 7, 6, 19], [14, 15, 16, 0, 17, 18]]),
  ZipLevel(rows: 6, cols: 6, waypoints: [[17, 18, 19, 0, 20, 21], [0, 14, 13, 0, 12, 22], [16, 15, 0, 7, 11, 0], [4, 5, 6, 8, 10, 23], [3, 0, 28, 9, 0, 24], [1, 2, 27, 0, 26, 25]]),
  ZipLevel(rows: 6, cols: 6, waypoints: [[7, 8, 12, 13, 14, 29], [0, 9, 11, 1, 0, 28], [6, 10, 0, 2, 15, 27], [5, 4, 3, 0, 16, 0], [20, 19, 0, 18, 17, 26], [21, 22, 0, 23, 24, 25]]),
  ZipLevel(rows: 6, cols: 6, waypoints: [[3, 0, 4, 5, 0, 27], [2, 1, 7, 6, 28, 26], [9, 0, 8, 30, 29, 25], [10, 0, 18, 19, 20, 24], [11, 17, 16, 15, 21, 23], [12, 13, 0, 14, 22, 0]]),
  ZipLevel(rows: 6, cols: 6, waypoints: [[18, 17, 16, 10, 0, 9], [19, 20, 0, 11, 12, 8], [0, 21, 15, 14, 13, 7], [22, 23, 2, 1, 5, 6], [25, 24, 3, 0, 4, 31], [26, 27, 0, 28, 29, 30]]),
];

class ZipScreen extends StatefulWidget {
  const ZipScreen({super.key});
  @override
  State<ZipScreen> createState() => _ZipScreenState();
}

class _ZipScreenState extends State<ZipScreen> {
  int _levelIndex = 0;
  late ZipLevel _level;
  final List<(int, int)> _path = [];
  int _nextWaypoint = 1;
  bool _won = false;
  String _msg = 'Drag through every cell — hit numbers in order';
  final GlobalKey _gridKey = GlobalKey();

  int _hintCount = 0;
  late List<ZipLevel> _sortedLevels;
  bool _dragActive = false;
  Offset? _currentDragOffset;

  @override
  void initState() {
    super.initState();
    _sortedLevels = List<ZipLevel>.from(_kLevels);
    _sortedLevels.sort((a, b) {
      final cmpSize = a.totalCells.compareTo(b.totalCells);
      if (cmpSize != 0) return cmpSize;
      return a.maxWaypoint.compareTo(b.maxWaypoint);
    });
    _level = _sortedLevels[0];
    _initLevel();
  }

  Future<void> _initLevel() async {
    _hintCount = await HintManager.getHints('zip');
    final prefs = await SharedPreferences.getInstance();
    final savedLevel = prefs.getInt('level_zip') ?? 0;
    if (mounted) {
      setState(() {
        _levelIndex = savedLevel % _sortedLevels.length;
        _loadLevel(prefs);
      });
    }
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    final pathStrings = _path.map((p) => '${p.$1},${p.$2}').toList();
    await prefs.setStringList('zip_path_${_levelIndex}', pathStrings);
  }

  Future<void> _clearState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('zip_path_${_levelIndex}');
  }

  Future<void> _savePersistedLevel(int lvl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('level_zip', lvl);
    final earned = await HintManager.onLevelCleared('zip');
    final newCount = await HintManager.getHints('zip');
    setState(() {
      _hintCount = newCount;
    });
    if (earned && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hint earned! (Total: $newCount)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: AppTheme.accentFor('zip'),
        ),
      );
    }
  }

  List<(int, int)>? _solveZip(ZipLevel level) {
    int startR = -1, startC = -1;
    for (int r = 0; r < level.rows; r++) {
      for (int c = 0; c < level.cols; c++) {
        if (level.waypoints[r][c] == 1) {
          startR = r; startC = c;
        }
      }
    }
    if (startR == -1) return null;

    List<(int, int)> path = [(startR, startC)];
    Set<String> visited = {'$startR,$startC'};

    bool dfs(int r, int c, int nextWp) {
      if (path.length == level.totalCells) {
        final lastWp = level.waypoints[path.last.$1][path.last.$2];
        return lastWp == level.maxWaypoint;
      }

      final dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)];
      for (final dir in dirs) {
        final nr = r + dir.$1;
        final nc = c + dir.$2;
        if (nr >= 0 && nr < level.rows && nc >= 0 && nc < level.cols) {
          final key = '$nr,$nc';
          if (!visited.contains(key)) {
            final wp = level.waypoints[nr][nc];
            if (wp > 0 && wp != nextWp) continue;
            
            visited.add(key);
            path.add((nr, nc));
            
            if (dfs(nr, nc, wp > 0 ? nextWp + 1 : nextWp)) {
              return true;
            }
            
            path.removeLast();
            visited.remove(key);
          }
        }
      }
      return false;
    }

    if (dfs(startR, startC, 2)) {
      return path;
    }
    return null;
  }

  Future<void> _useHint() async {
    if (_won || _hintCount <= 0) return;
    final solution = _solveZip(_level);
    if (solution == null || solution.isEmpty) return;

    bool matches = true;
    if (_path.length > solution.length) {
      matches = false;
    } else {
      for (int i = 0; i < _path.length; i++) {
        if (_path[i].$1 != solution[i].$1 || _path[i].$2 != solution[i].$2) {
          matches = false;
          break;
        }
      }
    }

    await HintManager.useHint('zip');
    final newCount = await HintManager.getHints('zip');

    setState(() {
      _hintCount = newCount;
      if (!matches || _path.isEmpty) {
        _path.clear();
        _path.add(solution[0]);
        if (solution.length > 1) {
          _path.add(solution[1]);
        }
      } else {
        _path.add(solution[_path.length]);
      }

      _nextWaypoint = 1;
      for (var p in _path) {
        final wp = _level.waypoints[p.$1][p.$2];
        if (wp == _nextWaypoint) {
          _nextWaypoint++;
        }
      }

      final lastCellWp = _level.waypoints[_path.last.$1][_path.last.$2];
      if (lastCellWp == _level.maxWaypoint && _path.length == _level.totalCells) {
        _won = true;
        _msg = 'Path complete!';
        _savePersistedLevel(_levelIndex);
        _clearState();
      } else {
        _msg = 'Hint added to path!';
        _saveState();
      }
    });
  }

  void _loadLevel([SharedPreferences? prefs]) {
    _level = _sortedLevels[_levelIndex % _sortedLevels.length];
    _path.clear();
    _nextWaypoint = 1;
    _won = false;
    _msg = 'Drag through every cell — hit numbers in order';
    
    if (prefs != null) {
      final pathStrings = prefs.getStringList('zip_path_${_levelIndex}');
      if (pathStrings != null && pathStrings.isNotEmpty) {
        for (final s in pathStrings) {
          final parts = s.split(',');
          if (parts.length == 2) {
            final r = int.tryParse(parts[0]);
            final c = int.tryParse(parts[1]);
            if (r != null && c != null) {
              _path.add((r, c));
              final wp = _level.waypoints[r][c];
              if (wp == _nextWaypoint) {
                _nextWaypoint++;
              }
            }
          }
        }
        if (_path.isNotEmpty) {
          final lastCellWp = _level.waypoints[_path.last.$1][_path.last.$2];
          if (lastCellWp == _level.maxWaypoint && _path.length == _level.totalCells) {
            _won = true;
            _msg = 'Path complete!';
          }
        }
      }
    }
  }

  void _reset() {
    _clearState();
    setState(() => _loadLevel());
  }

  bool _inPath(int r, int c) => _path.any((p) => p.$1 == r && p.$2 == c);
  bool _isAdjacent((int,int) a, (int,int) b) => (a.$1-b.$1).abs() + (a.$2-b.$2).abs() == 1;

  void _truncatePathTo((int, int) cell) {
    final idx = _path.indexOf(cell);
    if (idx == -1 || idx == _path.length - 1) return;
    setState(() {
      _path.removeRange(idx + 1, _path.length);
      _nextWaypoint = 1;
      for (var p in _path) {
        final wp = _level.waypoints[p.$1][p.$2];
        if (wp == _nextWaypoint) {
          _nextWaypoint++;
        }
      }
      _msg = 'Dragging...';
      _saveState();
    });
  }

  void _addCell(int r, int c) {
    if (_won) return;
    if (r < 0 || r >= _level.rows || c < 0 || c >= _level.cols) return;

    if (_path.isEmpty) {
      final wp = _level.waypoints[r][c];
      if (wp != 1) return;
    }

    if (_inPath(r, c)) return;
    if (_path.isNotEmpty && !_isAdjacent(_path.last, (r, c))) return;

    if (_path.isNotEmpty) {
      final lastCellWp = _level.waypoints[_path.last.$1][_path.last.$2];
      if (lastCellWp == _level.maxWaypoint) return;
    }

    final wp = _level.waypoints[r][c];
    if (wp > 0 && wp != _nextWaypoint) {
      setState(() => _msg = 'Hit #$_nextWaypoint first!');
      return;
    }

    setState(() {
      if (wp > 0) { _nextWaypoint++; }
      _path.add((r, c));
      _msg = 'Dragging...';
      _saveState();
    });
  }

  (int,int)? _cellAtLocal(Offset local) {
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final cw = box.size.width / _level.cols;
    final ch = box.size.height / _level.rows;
    final col = (local.dx / cw).floor();
    final row = (local.dy / ch).floor();
    if (row < 0 || row >= _level.rows || col < 0 || col >= _level.cols) return null;
    return (row, col);
  }

  void _nextLevel() {
    _clearState();
    setState(() {
      _levelIndex = (_levelIndex + 1) % _sortedLevels.length;
      _savePersistedLevel(_levelIndex);
      _loadLevel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sw = context.screenWidth - 40;
    final cellW = sw / _level.cols;
    final cellH = cellW;

    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        backgroundColor: context.bgDark, foregroundColor: context.textPrimary,
        title: Text('Zip', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: context.textPrimary)),
        centerTitle: true,
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
            onPressed: _hintCount > 0 && !_won ? _useHint : null,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, size: 20),
            color: context.textMuted,
            onPressed: () => RulesHelper.showRulesBottomSheet(context, 'zip', 'Zip'),
          ),
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _reset, color: context.textMuted),
          Padding(padding: const EdgeInsets.only(right: 12),
            child: Center(child: Text('Level ${_levelIndex+1}', style: GoogleFonts.outfit(color: AppTheme.zipPink, fontSize: context.scale(13))))),
        ],
      ),
      body: SafeArea(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('${_path.length} / ${_level.totalCells} cells',
            style: GoogleFonts.outfit(color: context.textMuted, fontSize: context.scale(12))),
          const SizedBox(height: 4),
          if (_msg.isNotEmpty) Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(_msg, style: GoogleFonts.outfit(color: _won ? AppTheme.zipPink : context.textSecondary, fontSize: context.scale(13)), textAlign: TextAlign.center),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onPanStart: (d) {
              if (_won) return;
              final c = _cellAtLocal(d.localPosition);
              if (c != null) {
                if (_path.isEmpty) {
                  final wp = _level.waypoints[c.$1][c.$2];
                  if (wp == 1) {
                    _dragActive = true;
                    _addCell(c.$1, c.$2);
                  } else {
                    _dragActive = false;
                    setState(() => _msg = 'Start at number 1!');
                  }
                } else {
                  if (_path.contains(c)) {
                    _dragActive = true;
                    _truncatePathTo(c);
                  } else if (_isAdjacent(_path.last, c)) {
                    _dragActive = true;
                    _addCell(c.$1, c.$2);
                  } else {
                    _dragActive = false;
                  }
                }
              } else {
                _dragActive = false;
              }
              setState(() {
                _currentDragOffset = d.localPosition;
              });
            },
            onPanUpdate: (d) {
              if (_won || !_dragActive) return;
              final c = _cellAtLocal(d.localPosition);
              if (c != null) {
                if (_path.contains(c)) {
                  _truncatePathTo(c);
                } else {
                  _addCell(c.$1, c.$2);
                }
              }
              setState(() {
                _currentDragOffset = d.localPosition;
              });
            },
            onPanEnd: (_) {
              setState(() {
                _dragActive = false;
                _currentDragOffset = null;
              });
              if (_won) return;
              if (_path.isNotEmpty) {
                final lastCellWp = _level.waypoints[_path.last.$1][_path.last.$2];
                if (lastCellWp == _level.maxWaypoint) {
                  if (_path.length == _level.totalCells) {
                    setState(() {
                      _won = true;
                      _msg = 'Path complete!';
                      _savePersistedLevel(_levelIndex);
                      _clearState();
                    });
                  } else {
                    setState(() {
                      _msg = 'Not all cells filled!';
                    });
                  }
                }
              }
            },
            onPanCancel: () {
              setState(() {
                _dragActive = false;
                _currentDragOffset = null;
              });
            },
            child: SizedBox(
              key: _gridKey, width: sw, height: cellH * _level.rows,
              child: CustomPaint(
                painter: _ZipPainter(
                  level: _level,
                  path: _path,
                  cellW: cellW,
                  cellH: cellH,
                  won: _won,
                  cellBgColor: context.bgCard,
                  gridColor: context.textMuted.withAlpha(70),
                  pathColor: AppTheme.zipPink,
                  fillColor: AppTheme.zipPink.withAlpha(35),
                  visitedWpColor: AppTheme.softSage,
                  currentDragOffset: _currentDragOffset,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_won) TextButton(onPressed: _nextLevel,
            child: Text('Next →', style: GoogleFonts.outfit(color: AppTheme.zipPink, fontWeight: FontWeight.w700, fontSize: context.scale(16))))
          else if (_path.isNotEmpty) TextButton(onPressed: _reset,
            child: Text('Reset', style: GoogleFonts.outfit(color: context.textSecondary, fontSize: context.scale(15)))),
        ]),
      ),
    );
  }
}

class _ZipPainter extends CustomPainter {
  final ZipLevel level;
  final List<(int, int)> path;
  final double cellW, cellH;
  final bool won;
  final Color cellBgColor;
  final Color gridColor;
  final Color pathColor;
  final Color fillColor;
  final Color visitedWpColor;
  final Offset? currentDragOffset;

  const _ZipPainter({
    required this.level,
    required this.path,
    required this.cellW,
    required this.cellH,
    required this.won,
    required this.cellBgColor,
    required this.gridColor,
    required this.pathColor,
    required this.fillColor,
    required this.visitedWpColor,
    this.currentDragOffset,
  });

  Offset _ctr(int r, int c) => Offset(c * cellW + cellW / 2, r * cellH + cellH / 2);

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = cellBgColor..style = PaintingStyle.fill;
    final border = Paint()..color = gridColor..style = PaintingStyle.stroke..strokeWidth = 1.2;
    final filled = Paint()..color = fillColor..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = pathColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = cellW * 0.26
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (int r = 0; r < level.rows; r++) {
      for (int c = 0; c < level.cols; c++) {
        final rect = Rect.fromLTWH(c * cellW + 3, r * cellH + 3, cellW - 6, cellH - 6);
        final rr = RRect.fromRectAndRadius(rect, const Radius.circular(8));
        canvas.drawRRect(rr, bgPaint);
        if (path.any((p) => p.$1 == r && p.$2 == c)) {
          canvas.drawRRect(rr, filled);
        }
        canvas.drawRRect(rr, border);
      }
    }
    if (path.length > 1) {
      final lp = Path()..moveTo(_ctr(path[0].$1, path[0].$2).dx, _ctr(path[0].$1, path[0].$2).dy);
      for (int i = 1; i < path.length; i++) {
        lp.lineTo(_ctr(path[i].$1, path[i].$2).dx, _ctr(path[i].$1, path[i].$2).dy);
      }
      canvas.drawPath(lp, linePaint);
    }

    for (int r = 0; r < level.rows; r++) {
      for (int c = 0; c < level.cols; c++) {
        final wp = level.waypoints[r][c];
        if (wp > 0) {
          final visited = path.any((p) => p.$1 == r && p.$2 == c);
          final center = _ctr(r, c);
          if (visited) {
            canvas.drawCircle(center, cellW * 0.28, Paint()..color = pathColor..style = PaintingStyle.fill);
            final tp = TextPainter(
              text: TextSpan(
                text: '$wp',
                style: TextStyle(color: Colors.white, fontSize: cellW * 0.26, fontWeight: FontWeight.w900),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
          } else {
            canvas.drawCircle(center, cellW * 0.28, Paint()..color = pathColor..style = PaintingStyle.stroke..strokeWidth = 2.5);
            final tp = TextPainter(
              text: TextSpan(
                text: '$wp',
                style: TextStyle(color: pathColor, fontSize: cellW * 0.26, fontWeight: FontWeight.w900),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(_ZipPainter old) =>
      old.path.length != path.length ||
      old.won != won ||
      old.gridColor != gridColor ||
      old.fillColor != fillColor ||
      old.cellBgColor != cellBgColor ||
      old.pathColor != pathColor ||
      old.visitedWpColor != visitedWpColor ||
      old.currentDragOffset != currentDragOffset;
}
