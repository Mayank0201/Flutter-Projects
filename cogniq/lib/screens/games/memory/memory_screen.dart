import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../utils/rules_helper.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/hint_manager.dart';

class MahjongPosition {
  final int col;
  final int row;
  final int layer;
  const MahjongPosition(this.col, this.row, this.layer);
}

class MahjongLevel {
  final String name;
  final int maxCols;
  final int maxRows;
  final List<MahjongPosition> positions;
  
  const MahjongLevel({
    required this.name,
    required this.maxCols,
    required this.maxRows,
    required this.positions,
  });
}

// 4 distinct layouts that repeat across levels
const List<MahjongLevel> _kMahjongLevels = [
  MahjongLevel(
    name: 'The Cross',
    maxCols: 8,
    maxRows: 8,
    positions: [
      // Layer 0 (12 tiles)
      MahjongPosition(2, 2, 0), MahjongPosition(4, 2, 0), MahjongPosition(6, 2, 0),
      MahjongPosition(1, 4, 0), MahjongPosition(3, 4, 0), MahjongPosition(5, 4, 0), MahjongPosition(7, 4, 0),
      MahjongPosition(2, 6, 0), MahjongPosition(4, 6, 0), MahjongPosition(6, 6, 0),
      MahjongPosition(4, 0, 0), MahjongPosition(4, 8, 0),
      // Layer 1 (4 tiles)
      MahjongPosition(3, 3, 1), MahjongPosition(5, 3, 1),
      MahjongPosition(3, 5, 1), MahjongPosition(5, 5, 1),
    ],
  ),
  MahjongLevel(
    name: 'The Pyramid',
    maxCols: 10,
    maxRows: 10,
    positions: [
      // Layer 0 (16 tiles)
      MahjongPosition(2, 2, 0), MahjongPosition(4, 2, 0), MahjongPosition(6, 2, 0),
      MahjongPosition(0, 4, 0), MahjongPosition(2, 4, 0), MahjongPosition(4, 4, 0), MahjongPosition(6, 4, 0), MahjongPosition(8, 4, 0),
      MahjongPosition(2, 6, 0), MahjongPosition(4, 6, 0), MahjongPosition(6, 6, 0),
      MahjongPosition(4, 8, 0),
      MahjongPosition(1, 3, 0), MahjongPosition(7, 3, 0),
      MahjongPosition(1, 5, 0), MahjongPosition(7, 5, 0),
      // Layer 1 (6 tiles)
      MahjongPosition(2, 3, 1), MahjongPosition(4, 3, 1), MahjongPosition(6, 3, 1),
      MahjongPosition(2, 5, 1), MahjongPosition(4, 5, 1), MahjongPosition(6, 5, 1),
      // Layer 2 (2 tiles)
      MahjongPosition(3, 4, 2), MahjongPosition(5, 4, 2),
    ],
  ),
  MahjongLevel(
    name: 'The Fortress',
    maxCols: 10,
    maxRows: 10,
    positions: [
      // Layer 0 (20 tiles)
      MahjongPosition(2, 2, 0), MahjongPosition(4, 2, 0), MahjongPosition(6, 2, 0), MahjongPosition(8, 2, 0),
      MahjongPosition(0, 4, 0), MahjongPosition(2, 4, 0), MahjongPosition(4, 4, 0), MahjongPosition(6, 4, 0), MahjongPosition(8, 4, 0), MahjongPosition(10, 4, 0),
      MahjongPosition(0, 6, 0), MahjongPosition(2, 6, 0), MahjongPosition(4, 6, 0), MahjongPosition(6, 6, 0), MahjongPosition(8, 6, 0), MahjongPosition(10, 6, 0),
      MahjongPosition(2, 8, 0), MahjongPosition(4, 8, 0), MahjongPosition(6, 8, 0), MahjongPosition(8, 8, 0),
      // Layer 1 (8 tiles)
      MahjongPosition(3, 3, 1), MahjongPosition(5, 3, 1), MahjongPosition(7, 3, 1),
      MahjongPosition(3, 5, 1), MahjongPosition(5, 5, 1), MahjongPosition(7, 5, 1),
      MahjongPosition(3, 7, 1), MahjongPosition(7, 7, 1),
      // Layer 2 (4 tiles)
      MahjongPosition(4, 4, 2), MahjongPosition(6, 4, 2),
      MahjongPosition(4, 6, 2), MahjongPosition(6, 6, 2),
    ],
  ),
  MahjongLevel(
    name: 'The Dragon',
    maxCols: 10,
    maxRows: 10,
    positions: [
      // Layer 0 (24 tiles)
      MahjongPosition(2, 0, 0), MahjongPosition(4, 0, 0), MahjongPosition(6, 0, 0),
      MahjongPosition(1, 2, 0), MahjongPosition(3, 2, 0), MahjongPosition(5, 2, 0), MahjongPosition(7, 2, 0),
      MahjongPosition(0, 4, 0), MahjongPosition(2, 4, 0), MahjongPosition(4, 4, 0), MahjongPosition(6, 4, 0), MahjongPosition(8, 4, 0),
      MahjongPosition(0, 6, 0), MahjongPosition(2, 6, 0), MahjongPosition(4, 6, 0), MahjongPosition(6, 6, 0), MahjongPosition(8, 6, 0),
      MahjongPosition(1, 8, 0), MahjongPosition(3, 8, 0), MahjongPosition(5, 8, 0), MahjongPosition(7, 8, 0),
      MahjongPosition(2, 10, 0), MahjongPosition(4, 10, 0), MahjongPosition(6, 10, 0),
      // Layer 1 (12 tiles)
      MahjongPosition(2, 2, 1), MahjongPosition(4, 2, 1), MahjongPosition(6, 2, 1),
      MahjongPosition(2, 4, 1), MahjongPosition(4, 4, 1), MahjongPosition(6, 4, 1),
      MahjongPosition(2, 6, 1), MahjongPosition(4, 6, 1), MahjongPosition(6, 6, 1),
      MahjongPosition(2, 8, 1), MahjongPosition(4, 8, 1), MahjongPosition(6, 8, 1),
      // Layer 2 (4 tiles)
      MahjongPosition(4, 3, 2), MahjongPosition(4, 5, 2), MahjongPosition(4, 7, 2), MahjongPosition(4, 9, 2),
    ],
  ),
];

// Distinct, recognizable icons to use as tile symbols
const List<IconData> _kIcons = [
  Icons.celebration, Icons.favorite, Icons.star, Icons.lightbulb,
  Icons.pets, Icons.flight, Icons.directions_car, Icons.palette,
  Icons.music_note, Icons.sports_basketball, Icons.sunny, Icons.ac_unit,
  Icons.local_cafe, Icons.anchor, Icons.cookie, Icons.face,
  Icons.work, Icons.phone, Icons.camera, Icons.home,
  Icons.eco, Icons.science, Icons.key, Icons.brush
];

class MahjongTile {
  final int id;
  final IconData icon;
  final int col;
  final int row;
  final int layer;
  bool isMatched;
  bool inTray;

  MahjongTile({
    required this.id,
    required this.icon,
    required this.col,
    required this.row,
    required this.layer,
    this.isMatched = false,
    this.inTray = false,
  });
}

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});
  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class MahjongStateSnapshot {
  final List<bool> tileMatchedStates;
  final List<bool> tileInTrayStates;
  final List<int> trayTileIds;
  final int moves;
  const MahjongStateSnapshot({
    required this.tileMatchedStates,
    required this.tileInTrayStates,
    required this.trayTileIds,
    required this.moves,
  });
}

class _MemoryScreenState extends State<MemoryScreen> {
  int _levelIndex = 0;
  late MahjongLevel _level;
  late List<MahjongTile> _tiles;
  List<MahjongTile> _tray = [];
  final List<MahjongStateSnapshot> _history = [];
  int? _selectedTileId;
  int? _hintTileIdA;
  int? _hintTileIdB;
  bool _won = false;
  int _moves = 0;
  int _hintCount = 0;

  @override
  void initState() {
    super.initState();
    _level = _kMahjongLevels[0];
    _tiles = [];
    _initLevel();
  }

  Future<void> _initLevel() async {
    _hintCount = await HintManager.getHints('memory');
    final prefs = await SharedPreferences.getInstance();
    final savedLevel = prefs.getInt('level_memory') ?? 0;
    if (mounted) {
      setState(() {
        _levelIndex = savedLevel;
        _loadLevel();
      });
    }
  }

  Future<void> _savePersistedLevel(int lvl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('level_memory', lvl);
    final earned = await HintManager.onLevelCleared('memory');
    final newCount = await HintManager.getHints('memory');
    setState(() {
      _hintCount = newCount;
    });
    if (earned && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hint earned! (Total: $newCount)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: AppTheme.accentFor('memory'),
        ),
      );
    }
  }

  void _loadLevel() {
    _level = _kMahjongLevels[_levelIndex % _kMahjongLevels.length];
    final positions = _level.positions;
    final numTiles = positions.length;
    final numPairs = numTiles ~/ 2;

    // Pick pairs of icons
    final rng = Random();
    final shuffledIcons = _kIcons.toList()..shuffle(rng);
    final selectedIcons = <IconData>[];
    for (int i = 0; i < numPairs; i++) {
      final icon = shuffledIcons[i % shuffledIcons.length];
      selectedIcons.add(icon);
      selectedIcons.add(icon);
    }
    selectedIcons.shuffle(rng);

    _tiles = List.generate(numTiles, (idx) {
      final pos = positions[idx];
      return MahjongTile(
        id: idx,
        icon: selectedIcons[idx],
        col: pos.col,
        row: pos.row,
        layer: pos.layer,
      );
    });

    _selectedTileId = null;
    _hintTileIdA = null;
    _hintTileIdB = null;
    _won = false;
    _moves = 0;
    _tray = [];
    _history.clear();
  }

  // Returns true if tile is blocked on top, or blocked on both left and right
  bool _isTileFree(MahjongTile target) {
    if (target.isMatched || target.inTray) return false;

    // 1. Check if covered by any tile on a higher layer
    for (final tile in _tiles) {
      if (tile.isMatched || tile.inTray) continue;
      if (tile.layer > target.layer) {
        // Tile occupies 2x2 area, so check for overlaps
        final overlapX = (tile.col < target.col + 2) && (tile.col + 2 > target.col);
        final overlapY = (tile.row < target.row + 2) && (tile.row + 2 > target.row);
        if (overlapX && overlapY) {
          return false; // Covered
        }
      }
    }

    // 2. Check if blocked on left and right on same layer
    bool blockedLeft = false;
    bool blockedRight = false;

    for (final tile in _tiles) {
      if (tile.isMatched || tile.inTray || tile.layer != target.layer || tile.id == target.id) continue;

      final overlapY = (tile.row < target.row + 2) && (tile.row + 2 > target.row);
      if (overlapY) {
        // Check if directly left (col overlaps with target.col - 2)
        if (tile.col == target.col - 2) {
          blockedLeft = true;
        }
        // Check if directly right (col overlaps with target.col + 2)
        if (tile.col == target.col + 2) {
          blockedRight = true;
        }
      }
    }

    // Free if no tiles on top, AND (not blocked left OR not blocked right)
    return !blockedLeft || !blockedRight;
  }

  bool _hasPossibleMoves() {
    final freeTiles = _tiles.where(_isTileFree).toList();
    // 1. Check board free pairs
    for (int i = 0; i < freeTiles.length; i++) {
      for (int j = i + 1; j < freeTiles.length; j++) {
        if (freeTiles[i].icon == freeTiles[j].icon) {
          return true;
        }
      }
    }
    // 2. Check if any free tile on board matches a tile already in the tray
    final trayIcons = _tray.map((t) => t.icon).toSet();
    for (final ft in freeTiles) {
      if (trayIcons.contains(ft.icon)) {
        return true;
      }
    }
    return false;
  }

  void _shuffleRemaining() {
    final unmatchedTiles = _tiles.where((t) => !t.isMatched && !t.inTray).toList();
    if (unmatchedTiles.isEmpty) return;

    final icons = unmatchedTiles.map((t) => t.icon).toList()..shuffle();
    setState(() {
      for (int i = 0; i < unmatchedTiles.length; i++) {
        final idx = _tiles.indexWhere((t) => t.id == unmatchedTiles[i].id);
        if (idx != -1) {
          _tiles[idx] = MahjongTile(
            id: _tiles[idx].id,
            icon: icons[i],
            col: _tiles[idx].col,
            row: _tiles[idx].row,
            layer: _tiles[idx].layer,
            isMatched: false,
            inTray: false,
          );
        }
      }
      _selectedTileId = null;
      _hintTileIdA = null;
      _hintTileIdB = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Board Shuffled!', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _useHint() async {
    if (_won || _hintCount <= 0) return;

    final freeTiles = _tiles.where(_isTileFree).toList();
    MahjongTile? matchA;
    MahjongTile? matchB;

    // 1. Check if we can match with something in the tray
    for (final trayTile in _tray) {
      for (final ft in freeTiles) {
        if (ft.icon == trayTile.icon) {
          matchA = ft;
          break;
        }
      }
      if (matchA != null) break;
    }

    // 2. Otherwise match free tiles on the board
    if (matchA == null) {
      for (int i = 0; i < freeTiles.length; i++) {
        for (int j = i + 1; j < freeTiles.length; j++) {
          if (freeTiles[i].icon == freeTiles[j].icon) {
            matchA = freeTiles[i];
            matchB = freeTiles[j];
            break;
          }
        }
        if (matchA != null) break;
      }
    }

    if (matchA != null) {
      await HintManager.useHint('memory');
      final newCount = await HintManager.getHints('memory');
      setState(() {
        _hintCount = newCount;
        _hintTileIdA = matchA!.id;
        if (matchB != null) {
          _hintTileIdB = matchB.id;
        }
        _selectedTileId = null;
      });

      Timer(const Duration(milliseconds: 2000), () {
        if (mounted) {
          setState(() {
            _hintTileIdA = null;
            _hintTileIdB = null;
          });
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No moves currently possible! Shuffle the board.', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        ),
      );
    }
  }

  void _saveToHistory() {
    _history.add(MahjongStateSnapshot(
      tileMatchedStates: _tiles.map((t) => t.isMatched).toList(),
      tileInTrayStates: _tiles.map((t) => t.inTray).toList(),
      trayTileIds: _tray.map((t) => t.id).toList(),
      moves: _moves,
    ));
  }

  void _undo() {
    if (_history.isEmpty || _won) return;
    final last = _history.removeLast();
    setState(() {
      _moves = last.moves;
      for (int i = 0; i < _tiles.length; i++) {
        _tiles[i].isMatched = last.tileMatchedStates[i];
        _tiles[i].inTray = last.tileInTrayStates[i];
      }
      _tray = last.trayTileIds.map((id) => _tiles.firstWhere((t) => t.id == id)).toList();
      _selectedTileId = null;
      _hintTileIdA = null;
      _hintTileIdB = null;
    });
  }

  void _onTileTap(MahjongTile tile) {
    if (tile.isMatched || tile.inTray || !_isTileFree(tile) || _won) return;

    if (_tray.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tray is full! Use Undo or Shuffle.', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }

    setState(() {
      _saveToHistory();
      _hintTileIdA = null;
      _hintTileIdB = null;

      tile.inTray = true;
      _tray.add(tile);
      _moves++;

      // Check for matching pair in the tray
      MahjongTile? match1;
      MahjongTile? match2;
      for (int i = 0; i < _tray.length; i++) {
        for (int j = i + 1; j < _tray.length; j++) {
          if (_tray[i].icon == _tray[j].icon) {
            match1 = _tray[i];
            match2 = _tray[j];
            break;
          }
        }
        if (match1 != null) break;
      }

      if (match1 != null && match2 != null) {
        _tray.remove(match1);
        _tray.remove(match2);
        match1.isMatched = true;
        match1.inTray = false;
        match2.isMatched = true;
        match2.inTray = false;

        if (_tiles.every((t) => t.isMatched)) {
          _won = true;
          _savePersistedLevel(_levelIndex);
        }
      }
    });
  }

  void _reset() => setState(() => _loadLevel());

  void _nextLevel() {
    setState(() {
      _levelIndex++;
      _savePersistedLevel(_levelIndex);
      _loadLevel();
    });
  }

  Widget _buildTray() {
    final accentColor = AppTheme.accentFor('memory');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.textMuted.withAlpha(50)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tray Slots (${_tray.length}/6)',
                style: GoogleFonts.outfit(color: context.textSecondary, fontSize: context.scale(11), fontWeight: FontWeight.bold),
              ),
              if (_history.isNotEmpty)
                GestureDetector(
                  onTap: _undo,
                  child: Text(
                    'Undo last move',
                    style: GoogleFonts.outfit(color: accentColor, fontSize: context.scale(11), fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (index) {
              if (index < _tray.length) {
                final tile = _tray[index];
                return Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF2C2F38)
                        : const Color(0xFFF9F7F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accentColor, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        offset: const Offset(0, 2),
                        blurRadius: 2.0,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      tile.icon,
                      color: accentColor,
                      size: 20,
                    ),
                  ),
                );
              } else {
                return Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.bgDark.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.textMuted.withAlpha(40), width: 1),
                  ),
                );
              }
            }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = AppTheme.accentFor('memory');
    final noMovesRemaining = !_won && !_tiles.every((t) => t.isMatched) && !_hasPossibleMoves();

    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        backgroundColor: context.bgDark,
        foregroundColor: context.textPrimary,
        title: Text('Mahjong Solitaire', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: context.textPrimary)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.undo, size: 20),
            color: context.textMuted,
            onPressed: _history.isNotEmpty && !_won ? _undo : null,
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
            onPressed: () => RulesHelper.showRulesBottomSheet(context, 'memory', 'Mahjong Solitaire'),
          ),
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _reset, color: context.textMuted),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                'Level ${_levelIndex + 1}',
                style: GoogleFonts.outfit(color: accentColor, fontSize: context.scale(13)),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                children: [
                  Text(
                    'Match free pairs of tiles to clear the board',
                    style: GoogleFonts.outfit(color: context.textSecondary, fontSize: context.scale(13)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Layout: ${_level.name}  |  ',
                        style: GoogleFonts.outfit(color: context.textMuted, fontSize: context.scale(12)),
                      ),
                      Text(
                        'Moves: $_moves',
                        style: GoogleFonts.outfit(color: accentColor, fontSize: context.scale(12), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Grid mapping calculations
                    final gridCols = _level.maxCols + 2;
                    final gridRows = _level.maxRows + 2;
                    
                    final cellWidth = constraints.maxWidth / gridCols;
                    final cellHeight = constraints.maxHeight / gridRows;
                    
                    // Maintain standard Mahjong rectangular tiles aspect ratio (approx 3:4)
                    final tileWidth = cellWidth * 2.1;
                    final tileHeight = tileWidth * 1.3;

                    // Ensure tiles fit within container boundaries
                    final boardWidth = gridCols * cellWidth;
                    final boardHeight = gridRows * cellHeight;

                    // Sort tiles by layer so that higher layers are rendered on top
                    final sortedTiles = _tiles.toList()..sort((a, b) {
                      if (a.layer != b.layer) return a.layer.compareTo(b.layer);
                      // Tie breaker: top to bottom, left to right
                      if (a.row != b.row) return a.row.compareTo(b.row);
                      return a.col.compareTo(b.col);
                    });

                    return Center(
                      child: SizedBox(
                        width: boardWidth,
                        height: boardHeight,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: sortedTiles.map((tile) {
                            if (tile.isMatched || tile.inTray) return const SizedBox.shrink();

                            final isFree = _isTileFree(tile);
                            final isSelected = _selectedTileId == tile.id;
                            final isHinted = _hintTileIdA == tile.id || _hintTileIdB == tile.id;

                            // Calculate position on the screen
                            // Apply shift for layers to give 3D depth effect
                            final layerOffset = tile.layer * 4.0;
                            final leftPos = tile.col * cellWidth - layerOffset;
                            final topPos = tile.row * cellHeight - layerOffset;

                            return Positioned(
                              left: leftPos,
                              top: topPos,
                              width: tileWidth,
                              height: tileHeight,
                              child: GestureDetector(
                                onTap: () => _onTileTap(tile),
                                behavior: HitTestBehavior.opaque,
                                child: Container(
                                  margin: const EdgeInsets.all(2.0),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? accentColor.withOpacity(0.2)
                                        : (isHinted
                                            ? Colors.amber.withOpacity(0.3)
                                            : (Theme.of(context).brightness == Brightness.dark
                                                ? const Color(0xFF2C2F38)
                                                : const Color(0xFFF9F7F2))),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isSelected
                                          ? accentColor
                                          : (isHinted
                                              ? Colors.amber
                                              : (isFree
                                                  ? (Theme.of(context).brightness == Brightness.dark
                                                      ? Colors.white.withOpacity(0.25)
                                                      : Colors.black.withOpacity(0.15))
                                                  : Colors.transparent)),
                                      width: isSelected || isHinted ? 2.2 : 1.0,
                                    ),
                                    boxShadow: [
                                      // 3D bottom bevel/shadow offset based on layer
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.25),
                                        offset: Offset(1.5 + tile.layer, 2.0 + tile.layer),
                                        blurRadius: 2.0,
                                      ),
                                    ],
                                  ),
                                  child: Opacity(
                                    opacity: isFree ? 1.0 : 0.45,
                                    child: Center(
                                      child: Icon(
                                        tile.icon,
                                        color: isSelected
                                            ? accentColor
                                            : (isHinted
                                                ? Colors.amber.shade800
                                                : (Theme.of(context).brightness == Brightness.dark
                                                    ? Colors.white
                                                    : Colors.black87)),
                                        size: tileWidth * 0.48,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            _buildTray(),
            if (noMovesRemaining) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.amber),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No moves left! You can shuffle the remaining tiles to continue.',
                          style: GoogleFonts.outfit(color: context.textPrimary, fontSize: context.scale(12)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        onPressed: _shuffleRemaining,
                        child: Text('Shuffle', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_won) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  children: [
                    Text(
                      'All Tiles Cleared in $_moves moves!',
                      style: GoogleFonts.outfit(color: accentColor, fontSize: context.scale(16), fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: _nextLevel,
                      child: Text('Next Level →', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: context.scale(14))),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
