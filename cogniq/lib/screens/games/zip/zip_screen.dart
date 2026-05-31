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
  // Easy (grids up to 12 cells)
  ZipLevel(rows: 3, cols: 3, waypoints: [[1,0,0],[0,0,0],[0,0,2]]),
  ZipLevel(rows: 3, cols: 3, waypoints: [[1,0,0],[0,3,0],[0,0,2]]),
  ZipLevel(rows: 3, cols: 4, waypoints: [[1,0,0,0],[0,0,0,0],[2,0,0,3]]),
  ZipLevel(rows: 3, cols: 4, waypoints: [[1,0,0,0],[2,0,0,0],[0,0,0,3]]),
  // Medium (grids with 16 to 20 cells)
  ZipLevel(rows: 4, cols: 4, waypoints: [[1,0,0,0],[0,0,4,0],[0,0,0,0],[2,0,0,3]]),
  ZipLevel(rows: 4, cols: 4, waypoints: [[1,0,0,0],[0,0,2,0],[0,0,0,0],[3,0,0,0]]),
  ZipLevel(rows: 4, cols: 5, waypoints: [[1,0,0,0,0],[0,0,0,0,0],[0,0,0,0,0],[2,0,0,0,3]]),
  // Hard (grids with 20+ cells)
  ZipLevel(rows: 4, cols: 5, waypoints: [[1,0,0,0,0],[0,2,0,0,0],[0,0,3,0,0],[4,0,0,0,0]]),
  ZipLevel(rows: 5, cols: 5, waypoints: [[1,0,0,0,0],[0,0,0,0,0],[0,0,0,0,0],[0,0,0,0,0],[2,0,0,0,3]]),
  ZipLevel(rows: 5, cols: 5, waypoints: [[1,0,0,0,0],[0,2,0,0,0],[0,0,3,0,0],[0,0,0,4,0],[0,0,0,0,5]]),
  // Expansions
  ZipLevel(rows: 3, cols: 4, waypoints: [[1,0,0,0],[0,2,0,0],[0,0,0,3]]),
  ZipLevel(rows: 4, cols: 4, waypoints: [[1,0,0,0],[0,2,0,3],[0,0,0,0],[0,0,4,0]]),
  ZipLevel(rows: 4, cols: 5, waypoints: [[1,0,0,0,0],[0,3,0,0,0],[0,0,0,0,0],[2,0,0,0,4]]),
  ZipLevel(rows: 5, cols: 4, waypoints: [[1,0,0,0],[0,2,0,0],[0,0,3,0],[0,0,0,0],[0,0,0,4]]),
  ZipLevel(rows: 5, cols: 5, waypoints: [[1,0,0,0,0],[0,0,2,0,0],[0,0,0,3,0],[0,0,0,0,4],[0,0,0,0,5]]),
  ZipLevel(rows: 3, cols: 3, waypoints: [[1,0,0],[0,2,0],[3,0,0]]),
  ZipLevel(rows: 3, cols: 4, waypoints: [[1,0,0,0],[0,2,0,0],[0,0,3,4]]),
  ZipLevel(rows: 3, cols: 4, waypoints: [[1,2,0,0],[0,0,0,0],[4,0,0,3]]),
  ZipLevel(rows: 4, cols: 3, waypoints: [[1,0,0],[0,2,0],[0,0,3],[0,0,4]]),
  ZipLevel(rows: 4, cols: 4, waypoints: [[1,0,0,0],[0,2,3,0],[0,0,0,0],[0,0,0,4]]),
  ZipLevel(rows: 4, cols: 4, waypoints: [[1,0,0,0],[0,2,0,0],[0,0,3,0],[0,0,0,4]]),
  ZipLevel(rows: 4, cols: 4, waypoints: [[1,0,0,2],[0,0,0,0],[0,3,0,0],[4,0,0,0]]),
  ZipLevel(rows: 4, cols: 5, waypoints: [[1,0,0,0,0],[0,2,0,0,3],[0,0,0,0,0],[0,0,4,0,5]]),
  ZipLevel(rows: 5, cols: 4, waypoints: [[1,0,0,0],[0,2,0,0],[0,0,3,0],[0,4,0,0],[0,0,0,5]]),
  ZipLevel(rows: 5, cols: 4, waypoints: [[1,0,0,0],[0,0,0,0],[2,0,0,3],[0,0,0,0],[0,4,0,5]]),
  ZipLevel(rows: 5, cols: 5, waypoints: [[1,0,0,0,0],[0,2,0,0,0],[0,0,3,0,0],[0,0,0,4,0],[0,0,0,0,5]]),
  ZipLevel(rows: 5, cols: 5, waypoints: [[1,0,0,0,0],[0,0,0,2,0],[0,3,0,0,0],[0,0,0,4,0],[5,0,0,0,6]]),
  ZipLevel(rows: 5, cols: 5, waypoints: [[1,2,3,0,0],[0,0,0,0,0],[0,0,4,5,0],[0,0,0,0,0],[0,0,0,0,6]]),
  ZipLevel(rows: 6, cols: 5, waypoints: [[1,0,0,0,0],[0,2,0,0,0],[0,0,3,0,0],[0,0,0,4,0],[0,0,0,0,5],[0,0,0,0,6]]),
  ZipLevel(rows: 6, cols: 6, waypoints: [[1,0,0,0,0,0],[0,2,0,0,0,0],[0,0,3,0,0,0],[0,0,0,4,0,0],[0,0,0,0,5,0],[0,0,0,0,0,6]]),
  ZipLevel(rows: 6, cols: 6, waypoints: [[1,0,0,0,0,0],[0,0,2,0,0,0],[0,0,0,3,0,0],[0,0,0,0,4,0],[0,0,0,0,0,5],[0,0,0,0,0,6]]),
  ZipLevel(rows: 6, cols: 6, waypoints: [[1,0,0,0,0,2],[0,0,0,0,0,0],[0,0,3,4,0,0],[0,0,0,0,0,0],[0,0,0,0,0,0],[5,0,0,0,0,6]]),
  ZipLevel(rows: 5, cols: 5, waypoints: [[1,2,0,0,0],[0,3,4,0,0],[0,0,5,6,0],[0,0,0,0,0],[0,0,0,0,7]]),
  ZipLevel(rows: 5, cols: 5, waypoints: [[1,0,0,0,0],[0,2,0,0,0],[0,0,3,0,0],[0,0,0,4,0],[5,0,0,0,6]]),
  ZipLevel(rows: 6, cols: 6, waypoints: [[1,0,0,0,0,0],[0,2,3,0,0,0],[0,0,4,0,0,0],[0,0,0,5,0,0],[0,0,0,0,6,0],[0,0,0,0,0,7]]),
  ZipLevel(rows: 6, cols: 6, waypoints: [[1,0,0,0,0,0],[0,2,0,0,0,0],[0,0,3,4,0,0],[0,0,0,5,0,0],[0,0,0,0,6,0],[0,0,0,0,0,7]]),
  ZipLevel(rows: 5, cols: 5, waypoints: [[1,0,0,0,0],[0,2,3,0,0],[0,0,4,5,0],[0,0,0,6,7],[0,0,0,0,8]]),
  ZipLevel(rows: 6, cols: 6, waypoints: [[1,2,0,0,0,0],[0,3,4,0,0,0],[0,0,5,6,0,0],[0,0,0,7,8,0],[0,0,0,0,0,0],[0,0,0,0,0,9]]),
  ZipLevel(rows: 6, cols: 6, waypoints: [[1,0,0,0,0,0],[0,2,0,0,0,0],[0,0,3,0,0,0],[0,0,0,4,0,0],[0,0,0,0,5,0],[0,0,0,0,0,8]]),
  ZipLevel(rows: 6, cols: 6, waypoints: [[1,2,3,4,5,6],[0,0,0,0,0,7],[0,0,0,0,0,8],[0,0,0,0,0,9],[0,0,0,0,0,0],[0,0,0,0,0,10]]),
  // 10 new levels
  ZipLevel(rows: 3, cols: 3, waypoints: [[1,0,0],[0,2,0],[0,0,3]]),
  ZipLevel(rows: 3, cols: 3, waypoints: [[1,2,0],[0,0,0],[0,3,4]]),
  ZipLevel(rows: 3, cols: 4, waypoints: [[1,0,2,0],[0,0,0,0],[0,4,0,3]]),
  ZipLevel(rows: 4, cols: 4, waypoints: [[1,0,0,0],[0,2,0,0],[0,0,3,0],[0,0,0,4]]),
  ZipLevel(rows: 4, cols: 5, waypoints: [[1,0,0,0,2],[0,0,0,0,0],[0,0,0,0,0],[3,0,0,0,4]]),
  ZipLevel(rows: 4, cols: 5, waypoints: [[1,0,0,0,0],[0,2,0,3,0],[0,0,0,0,0],[4,0,0,0,5]]),
  ZipLevel(rows: 5, cols: 5, waypoints: [[1,0,0,0,0],[0,2,0,0,0],[0,0,3,0,0],[0,0,0,4,0],[5,0,0,0,6]]),
  ZipLevel(rows: 6, cols: 6, waypoints: [[1,0,0,0,0,0],[0,2,0,0,0,0],[0,0,3,0,0,0],[0,0,0,4,0,0],[0,0,0,0,5,6],[0,0,0,0,0,7]]),
  ZipLevel(rows: 6, cols: 6, waypoints: [[1,0,0,0,0,2],[0,3,0,0,4,0],[0,0,0,0,0,0],[0,0,5,0,0,0],[0,0,0,0,0,0],[6,0,0,0,0,7]]),
  ZipLevel(rows: 6, cols: 6, waypoints: [[1,0,0,0,0,0],[0,2,0,0,0,0],[0,0,3,0,0,0],[0,0,0,4,0,0],[0,0,0,0,5,0],[6,7,8,9,10,11]]),
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
  bool _failed = false;
  String _msg = 'Drag through every cell — hit numbers in order';
  final GlobalKey _gridKey = GlobalKey();

  int _hintCount = 0;

  late List<ZipLevel> _sortedLevels;

  @override
  void initState() {
    super.initState();
    _sortedLevels = List<ZipLevel>.from(_kLevels);
    _sortedLevels.sort((a, b) {
      final cmp = a.maxWaypoint.compareTo(b.maxWaypoint);
      if (cmp != 0) return cmp;
      return a.totalCells.compareTo(b.totalCells);
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
        _loadLevel();
      });
    }
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
    if (_won || _failed || _hintCount <= 0) return;
    final solution = _solveZip(_level);
    if (solution == null || solution.isEmpty) return;

    // Check if current path matches solution prefix
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
        // Reset to first two steps of solution
        _path.clear();
        _path.add(solution[0]);
        if (solution.length > 1) {
          _path.add(solution[1]);
        }
      } else {
        // Append next cell in solution
        _path.add(solution[_path.length]);
      }

      // Re-evaluate next waypoint
      _nextWaypoint = 1;
      for (var p in _path) {
        final wp = _level.waypoints[p.$1][p.$2];
        if (wp == _nextWaypoint) {
          _nextWaypoint++;
        }
      }

      // Check if won
      final lastCellWp = _level.waypoints[_path.last.$1][_path.last.$2];
      if (lastCellWp == _level.maxWaypoint && _path.length == _level.totalCells) {
        _won = true;
        _msg = 'Path complete!';
      } else {
        _msg = 'Hint added to path!';
      }
    });
  }

  void _loadLevel() {
    _level = _sortedLevels[_levelIndex % _sortedLevels.length];
    _path.clear();
    _nextWaypoint = 1;
    _won = false;
    _failed = false;
    _msg = 'Drag through every cell — hit numbers in order';
  }

  void _reset() => setState(() => _loadLevel());

  bool _inPath(int r, int c) => _path.any((p) => p.$1 == r && p.$2 == c);
  bool _isAdjacent((int,int) a, (int,int) b) => (a.$1-b.$1).abs() + (a.$2-b.$2).abs() == 1;

  void _addCell(int r, int c) {
    if (_won || _failed) return;
    if (r < 0 || r >= _level.rows || c < 0 || c >= _level.cols) return;

    if (_path.isEmpty) {
      final wp = _level.waypoints[r][c];
      if (wp != 1) {
        setState(() => _msg = 'Start at number 1!');
        return;
      }
    }

    // Backtrack: if dragging to the second-to-last cell, remove last
    if (_path.length >= 2 && _path[_path.length - 2].$1 == r && _path[_path.length - 2].$2 == c) {
      setState(() {
        final removed = _path.removeLast();
        final wp = _level.waypoints[removed.$1][removed.$2];
        if (wp > 0 && wp == _nextWaypoint - 1) { _nextWaypoint--; }
        _msg = 'Dragging...';
      });
      return;
    }

    if (_inPath(r, c)) return;
    if (_path.isNotEmpty && !_isAdjacent(_path.last, (r, c))) return;

    // If already reached the final waypoint in current path, don't allow extending further
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
    });
  }

  (int,int)? _cellAt(Offset global) {
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final local = box.globalToLocal(global);
    final cw = box.size.width / _level.cols;
    final ch = box.size.height / _level.rows;
    final col = (local.dx / cw).floor();
    final row = (local.dy / ch).floor();
    if (row < 0 || row >= _level.rows || col < 0 || col >= _level.cols) return null;
    return (row, col);
  }

  void _nextLevel() {
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
            onPressed: _hintCount > 0 && !_won && !_failed ? _useHint : null,
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
              if (_won || _failed) return;
              final c = _cellAt(d.globalPosition);
              if (c != null) {
                if (_path.isEmpty) {
                  final wp = _level.waypoints[c.$1][c.$2];
                  if (wp == 1) {
                    _addCell(c.$1, c.$2);
                  } else {
                    setState(() => _msg = 'Start at number 1!');
                  }
                } else if (c == _path.last) {
                  // drag continuation
                } else if (_isAdjacent(_path.last, c)) {
                  _addCell(c.$1, c.$2);
                }
              }
            },
            onPanUpdate: (d) {
              if (_won || _failed) return;
              final c = _cellAt(d.globalPosition);
              if (c != null) {
                _addCell(c.$1, c.$2);
              }
            },
            onPanEnd: (_) {
              if (_won || _failed) return;
              if (_path.isNotEmpty) {
                final lastCellWp = _level.waypoints[_path.last.$1][_path.last.$2];
                if (lastCellWp == _level.maxWaypoint) {
                  if (_path.length == _level.totalCells) {
                    setState(() {
                      _won = true;
                      _msg = 'Path complete!';
                      _savePersistedLevel(_levelIndex);
                    });
                  } else {
                    setState(() {
                      _failed = true;
                      _msg = 'Not all cells filled! Tap Reset to retry.';
                    });
                  }
                } else {
                  // Mid-path lift: reset path so user must restart from #1
                  setState(() {
                    _path.clear();
                    _nextWaypoint = 1;
                    _msg = 'Start from number 1!';
                  });
                }
              }
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
                  gridColor: context.isDarkMode ? const Color(0xFF2A2A3A) : const Color(0xFFD1D5DB),
                  fillColor: AppTheme.zipPink.withOpacity(0.2),
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
  final ZipLevel level; final List<(int,int)> path;
  final double cellW, cellH; final bool won;
  final Color gridColor; final Color fillColor;
  const _ZipPainter({required this.level, required this.path, required this.cellW, required this.cellH, required this.won, required this.gridColor, required this.fillColor});

  Offset _ctr(int r, int c) => Offset(c * cellW + cellW / 2, r * cellH + cellH / 2);

  @override
  void paint(Canvas canvas, Size size) {
    final border = Paint()..color = gridColor..style = PaintingStyle.stroke..strokeWidth = 1;
    final filled = Paint()..color = fillColor..style = PaintingStyle.fill;
    final linePaint = Paint()..color = AppTheme.zipPink..style = PaintingStyle.stroke..strokeWidth = cellW * 0.32..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final wpCircle = Paint()..color = AppTheme.zipPink..style = PaintingStyle.fill;
    final wpDone   = Paint()..color = const Color(0xFF2A5A2A)..style = PaintingStyle.fill;

    for (int r = 0; r < level.rows; r++) {
      for (int c = 0; c < level.cols; c++) {
        final rect = Rect.fromLTWH(c * cellW + 2, r * cellH + 2, cellW - 4, cellH - 4);
        final rr = RRect.fromRectAndRadius(rect, const Radius.circular(6));
        if (path.any((p) => p.$1 == r && p.$2 == c)) { canvas.drawRRect(rr, filled); }
        canvas.drawRRect(rr, border);
      }
    }
    if (path.length > 1) {
      final lp = Path()..moveTo(_ctr(path[0].$1, path[0].$2).dx, _ctr(path[0].$1, path[0].$2).dy);
      for (int i = 1; i < path.length; i++) { lp.lineTo(_ctr(path[i].$1, path[i].$2).dx, _ctr(path[i].$1, path[i].$2).dy); }
      canvas.drawPath(lp, linePaint);
    }
    for (int r = 0; r < level.rows; r++) {
      for (int c = 0; c < level.cols; c++) {
        final wp = level.waypoints[r][c];
        if (wp > 0) {
          final visited = path.any((p) => p.$1 == r && p.$2 == c);
          final center = _ctr(r, c);
          canvas.drawCircle(center, cellW * 0.28, visited ? wpDone : wpCircle);
          final tp = TextPainter(text: TextSpan(text: '$wp', style: TextStyle(color: Colors.white, fontSize: cellW * 0.28, fontWeight: FontWeight.w900)), textDirection: TextDirection.ltr)..layout();
          tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
        }
      }
    }
  }
  @override
  bool shouldRepaint(_ZipPainter old) => old.path.length != path.length || old.won != won || old.gridColor != gridColor || old.fillColor != fillColor;
}
