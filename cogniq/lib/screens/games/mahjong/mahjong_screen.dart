import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cogniq/widgets/buy_hints_dialog.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../utils/rules_helper.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/hint_manager.dart';
import '../../../utils/audio_manager.dart';
import '../../../widgets/auto_next_countdown.dart';
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
      MahjongPosition(2, 2, 0),
      MahjongPosition(4, 2, 0),
      MahjongPosition(6, 2, 0),
      MahjongPosition(1, 4, 0),
      MahjongPosition(3, 4, 0),
      MahjongPosition(5, 4, 0),
      MahjongPosition(7, 4, 0),
      MahjongPosition(2, 6, 0),
      MahjongPosition(4, 6, 0),
      MahjongPosition(6, 6, 0),
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
      MahjongPosition(2, 2, 0),
      MahjongPosition(4, 2, 0),
      MahjongPosition(6, 2, 0),
      MahjongPosition(0, 4, 0),
      MahjongPosition(2, 4, 0),
      MahjongPosition(4, 4, 0),
      MahjongPosition(6, 4, 0),
      MahjongPosition(8, 4, 0),
      MahjongPosition(2, 6, 0),
      MahjongPosition(4, 6, 0),
      MahjongPosition(6, 6, 0),
      MahjongPosition(4, 8, 0),
      MahjongPosition(1, 3, 0), MahjongPosition(7, 3, 0),
      MahjongPosition(1, 5, 0), MahjongPosition(7, 5, 0),
      // Layer 1 (6 tiles)
      MahjongPosition(2, 3, 1),
      MahjongPosition(4, 3, 1),
      MahjongPosition(6, 3, 1),
      MahjongPosition(2, 5, 1),
      MahjongPosition(4, 5, 1),
      MahjongPosition(6, 5, 1),
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
      MahjongPosition(2, 2, 0),
      MahjongPosition(4, 2, 0),
      MahjongPosition(6, 2, 0),
      MahjongPosition(8, 2, 0),
      MahjongPosition(0, 4, 0),
      MahjongPosition(2, 4, 0),
      MahjongPosition(4, 4, 0),
      MahjongPosition(6, 4, 0),
      MahjongPosition(8, 4, 0),
      MahjongPosition(10, 4, 0),
      MahjongPosition(0, 6, 0),
      MahjongPosition(2, 6, 0),
      MahjongPosition(4, 6, 0),
      MahjongPosition(6, 6, 0),
      MahjongPosition(8, 6, 0),
      MahjongPosition(10, 6, 0),
      MahjongPosition(2, 8, 0),
      MahjongPosition(4, 8, 0),
      MahjongPosition(6, 8, 0),
      MahjongPosition(8, 8, 0),
      // Layer 1 (8 tiles)
      MahjongPosition(3, 3, 1),
      MahjongPosition(5, 3, 1),
      MahjongPosition(7, 3, 1),
      MahjongPosition(3, 5, 1),
      MahjongPosition(5, 5, 1),
      MahjongPosition(7, 5, 1),
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
      MahjongPosition(2, 0, 0),
      MahjongPosition(4, 0, 0),
      MahjongPosition(6, 0, 0),
      MahjongPosition(1, 2, 0),
      MahjongPosition(3, 2, 0),
      MahjongPosition(5, 2, 0),
      MahjongPosition(7, 2, 0),
      MahjongPosition(0, 4, 0),
      MahjongPosition(2, 4, 0),
      MahjongPosition(4, 4, 0),
      MahjongPosition(6, 4, 0),
      MahjongPosition(8, 4, 0),
      MahjongPosition(0, 6, 0),
      MahjongPosition(2, 6, 0),
      MahjongPosition(4, 6, 0),
      MahjongPosition(6, 6, 0),
      MahjongPosition(8, 6, 0),
      MahjongPosition(1, 8, 0),
      MahjongPosition(3, 8, 0),
      MahjongPosition(5, 8, 0),
      MahjongPosition(7, 8, 0),
      MahjongPosition(2, 10, 0),
      MahjongPosition(4, 10, 0),
      MahjongPosition(6, 10, 0),
      // Layer 1 (12 tiles)
      MahjongPosition(2, 2, 1),
      MahjongPosition(4, 2, 1),
      MahjongPosition(6, 2, 1),
      MahjongPosition(2, 4, 1),
      MahjongPosition(4, 4, 1),
      MahjongPosition(6, 4, 1),
      MahjongPosition(2, 6, 1),
      MahjongPosition(4, 6, 1),
      MahjongPosition(6, 6, 1),
      MahjongPosition(2, 8, 1),
      MahjongPosition(4, 8, 1),
      MahjongPosition(6, 8, 1),
      // Layer 2 (4 tiles)
      MahjongPosition(4, 3, 2),
      MahjongPosition(4, 5, 2),
      MahjongPosition(4, 7, 2),
      MahjongPosition(4, 9, 2),
    ],
  ),
  MahjongLevel(
    name: 'The Diamond',
    maxCols: 8,
    maxRows: 8,
    positions: [
      // Layer 0 (12 tiles)
      MahjongPosition(3, 1, 0), MahjongPosition(4, 1, 0),
      MahjongPosition(2, 2, 0), MahjongPosition(5, 2, 0),
      MahjongPosition(1, 3, 0), MahjongPosition(6, 3, 0),
      MahjongPosition(1, 4, 0), MahjongPosition(6, 4, 0),
      MahjongPosition(2, 5, 0), MahjongPosition(5, 5, 0),
      MahjongPosition(3, 6, 0), MahjongPosition(4, 6, 0),
      // Layer 1 (8 tiles)
      MahjongPosition(3, 2, 1), MahjongPosition(4, 2, 1),
      MahjongPosition(2, 3, 1), MahjongPosition(5, 3, 1),
      MahjongPosition(2, 4, 1), MahjongPosition(5, 4, 1),
      MahjongPosition(3, 5, 1), MahjongPosition(4, 5, 1),
      // Layer 2 (4 tiles)
      MahjongPosition(3, 3, 2), MahjongPosition(4, 3, 2),
      MahjongPosition(3, 4, 2), MahjongPosition(4, 4, 2),
    ],
  ),
  MahjongLevel(
    name: 'The Hourglass',
    maxCols: 8,
    maxRows: 8,
    positions: [
      // Layer 0 (20 tiles)
      MahjongPosition(1, 1, 0),
      MahjongPosition(2, 1, 0),
      MahjongPosition(5, 1, 0),
      MahjongPosition(6, 1, 0),
      MahjongPosition(2, 2, 0),
      MahjongPosition(3, 2, 0),
      MahjongPosition(4, 2, 0),
      MahjongPosition(5, 2, 0),
      MahjongPosition(3, 3, 0), MahjongPosition(4, 3, 0),
      MahjongPosition(3, 4, 0), MahjongPosition(4, 4, 0),
      MahjongPosition(2, 5, 0),
      MahjongPosition(3, 5, 0),
      MahjongPosition(4, 5, 0),
      MahjongPosition(5, 5, 0),
      MahjongPosition(1, 6, 0),
      MahjongPosition(2, 6, 0),
      MahjongPosition(5, 6, 0),
      MahjongPosition(6, 6, 0),
      // Layer 1 (8 tiles)
      MahjongPosition(2, 2, 1), MahjongPosition(5, 2, 1),
      MahjongPosition(3, 3, 1), MahjongPosition(4, 3, 1),
      MahjongPosition(3, 4, 1), MahjongPosition(4, 4, 1),
      MahjongPosition(2, 5, 1), MahjongPosition(5, 5, 1),
    ],
  ),
  MahjongLevel(
    name: 'The Castle',
    maxCols: 10,
    maxRows: 10,
    positions: [
      // Layer 0 (16 tiles)
      MahjongPosition(1, 1, 0), MahjongPosition(8, 1, 0),
      MahjongPosition(1, 3, 0), MahjongPosition(8, 3, 0),
      MahjongPosition(1, 5, 0), MahjongPosition(8, 5, 0),
      MahjongPosition(1, 7, 0),
      MahjongPosition(3, 7, 0),
      MahjongPosition(4, 7, 0),
      MahjongPosition(5, 7, 0),
      MahjongPosition(6, 7, 0),
      MahjongPosition(8, 7, 0),
      MahjongPosition(2, 8, 0),
      MahjongPosition(3, 8, 0),
      MahjongPosition(6, 8, 0),
      MahjongPosition(7, 8, 0),
      // Layer 1 (6 tiles)
      MahjongPosition(2, 3, 1), MahjongPosition(7, 3, 1),
      MahjongPosition(3, 5, 1),
      MahjongPosition(4, 5, 1),
      MahjongPosition(5, 5, 1),
      MahjongPosition(6, 5, 1),
      // Layer 2 (2 tiles)
      MahjongPosition(4, 4, 2), MahjongPosition(5, 4, 2),
    ],
  ),
  MahjongLevel(
    name: 'The Helix',
    maxCols: 8,
    maxRows: 8,
    positions: [
      // Layer 0 (14 tiles)
      MahjongPosition(2, 1, 0), MahjongPosition(5, 1, 0),
      MahjongPosition(1, 2, 0), MahjongPosition(6, 2, 0),
      MahjongPosition(2, 3, 0), MahjongPosition(5, 3, 0),
      MahjongPosition(3, 4, 0), MahjongPosition(4, 4, 0),
      MahjongPosition(2, 5, 0), MahjongPosition(5, 5, 0),
      MahjongPosition(1, 6, 0), MahjongPosition(6, 6, 0),
      MahjongPosition(2, 7, 0), MahjongPosition(5, 7, 0),
      // Layer 1 (8 tiles)
      MahjongPosition(2, 2, 1), MahjongPosition(5, 2, 1),
      MahjongPosition(3, 3, 1), MahjongPosition(4, 3, 1),
      MahjongPosition(3, 5, 1), MahjongPosition(4, 5, 1),
      MahjongPosition(2, 6, 1), MahjongPosition(5, 6, 1),
      // Layer 2 (2 tiles)
      MahjongPosition(3, 4, 2), MahjongPosition(4, 4, 2),
    ],
  ),
];

// Distinct, recognizable icons to use as tile symbols
const List<IconData> _kIcons = [
  Icons.celebration,
  Icons.favorite,
  Icons.star,
  Icons.lightbulb,
  Icons.pets,
  Icons.flight,
  Icons.directions_car,
  Icons.palette,
  Icons.music_note,
  Icons.sports_basketball,
  Icons.sunny,
  Icons.ac_unit,
  Icons.local_cafe,
  Icons.anchor,
  Icons.cookie,
  Icons.face,
  Icons.work,
  Icons.phone,
  Icons.camera,
  Icons.home,
  Icons.eco,
  Icons.science,
  Icons.key,
  Icons.brush,
];

class MahjongTile {
  final int id;
  final int iconIndex;
  int col;
  int row;
  final int layer;
  bool isMatched;
  bool inTray;
  IconData get icon => _kIcons[iconIndex];

  MahjongTile({
    required this.id,
    required this.iconIndex,
    required this.col,
    required this.row,
    required this.layer,
    this.isMatched = false,
    this.inTray = false,
  });
}

class MahjongScreen extends StatefulWidget {
  final int? dailyLevelIndex;
  const MahjongScreen({super.key, this.dailyLevelIndex});
  @override
  State<MahjongScreen> createState() => _MahjongScreenState();
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

class _MahjongScreenState extends State<MahjongScreen> {
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
  bool _playDailyMode = false;
  String _dailyModifierType = '';
  String _dailyModifierName = '';
  Timer? _chaosTimer;
  int _chaosTimeLeft = 15;
  double _cellWidth = 1.0;
  double _cellHeight = 1.0;
  double _tileWidth = 1.0;
  double _tileHeight = 1.0;

  int? _shakingTileId;
  double _shakeOffset = 0.0;
  Timer? _shakeTimer;
  final Set<int> _animatingMatches = {};
  TransformationController? _zoomController;

  @override
  void initState() {
    super.initState();
    _level = _getMahjongLevel(0);
    _tiles = [];
    _initLevel();
  }

  @override
  void dispose() {
    _chaosTimer?.cancel();
    _shakeTimer?.cancel();
    _zoomController?.dispose();
    super.dispose();
  }

  Future<void> _initLevel() async {
    _hintCount = await HintManager.getHints('memory');
    final prefs = await SharedPreferences.getInstance();
    _playDailyMode = prefs.getBool('play_daily_mode') ?? false;
    if (_playDailyMode) {
      _dailyModifierType = prefs.getString('daily_modifier_type') ?? '';
      _dailyModifierName = prefs.getString('daily_modifier_name') ?? '';
      if (_dailyModifierType == 'zoom') {
        _zoomController = TransformationController()..value = (Matrix4.identity()..scale(1.3));
      }
    } else {
      _dailyModifierType = '';
      _dailyModifierName = '';
    }

    int targetLevel = 0;
    if (widget.dailyLevelIndex != null) {
      targetLevel = widget.dailyLevelIndex!;
    } else {
      targetLevel = prefs.getInt('level_memory') ?? 0;
    }

    if (mounted) {
      setState(() {
        _levelIndex = targetLevel;
        _loadLevel();
      });
    }

    if (!_playDailyMode) {
      Future.delayed(Duration.zero, () async {
        if (!mounted) return;
        final savedStateStr = prefs.getString('normal_memory_state');
        if (savedStateStr != null) {
          try {
            final data = jsonDecode(savedStateStr);
            if (data['levelIndex'] == _levelIndex) {
              final continueGame =
                  await showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: context.bgCard,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: context.textMuted.withAlpha(40),
                        ),
                      ),
                      title: Text(
                        'Continue Game?',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary,
                        ),
                      ),
                      content: Text(
                        'We found a saved state for this level. Would you like to continue playing or start a new game?',
                        style: GoogleFonts.outfit(color: context.textSecondary),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx, false); // New Game
                          },
                          child: Text(
                            'New Game',
                            style: GoogleFonts.outfit(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx, true); // Continue
                          },
                          child: Text(
                            'Continue',
                            style: GoogleFonts.outfit(
                              color: AppTheme.dustyMauve,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ) ??
                  false;

              if (continueGame) {
                final List<dynamic> tilesData = data['tiles'];
                final List<MahjongTile> loadedTiles = tilesData.map((item) {
                  int iconIndex;

                  if (item.containsKey('iconIndex')) {
                    // New save format
                    iconIndex = item['iconIndex'];
                  } else {
                    // Old save format (for closed testing users)
                    final codePoint = item['iconCodePoint'];

                    iconIndex = _kIcons.indexWhere(
                      (icon) => icon.codePoint == codePoint,
                    );

                    if (iconIndex == -1) {
                      iconIndex = 0;
                    }
                  }

                  return MahjongTile(
                    id: item['id'],
                    iconIndex: iconIndex,
                    col: item['col'],
                    row: item['row'],
                    layer: item['layer'],
                    isMatched: item['isMatched'],
                    inTray: item['inTray'],
                  );
                }).toList();

                setState(() {
                  _tiles = loadedTiles;
                  _tray = _tiles.where((t) => t.inTray).toList();
                  _selectedTileId = data['selectedTileId'];
                  _moves = data['moves'];
                  _won = data['won'];
                });
              } else {
                await _clearNormalState();
              }
            } else {
              await _clearNormalState();
            }
          } catch (_) {
            await _clearNormalState();
          }
        }
      });
    }
  }

  Future<void> _saveNormalState() async {
    if (_playDailyMode || _won) return;
    final prefs = await SharedPreferences.getInstance();
    final state = {
      'levelIndex': _levelIndex,
      'selectedTileId': _selectedTileId,
      'moves': _moves,
      'won': _won,
      'tiles': _tiles
          .map(
            (t) => {
              'id': t.id,
              'iconIndex': t.iconIndex,
              'col': t.col,
              'row': t.row,
              'layer': t.layer,
              'isMatched': t.isMatched,
              'inTray': t.inTray,
            },
          )
          .toList(),
    };
    await prefs.setString('normal_memory_state', jsonEncode(state));
  }

  Future<void> _clearNormalState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('normal_memory_state');
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
          content: Text(
            'Hint earned! (Total: $newCount)',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppTheme.accentFor('memory'),
        ),
      );
    }
    await _clearNormalState();
  }

  MahjongLevel _getMahjongLevel(int index) {
    if (index < _kMahjongLevels.length) {
      return _kMahjongLevels[index];
    }
    final rng = Random(index * 1337);
    final positions = <MahjongPosition>[];
    int totalPairs = 8 + (index - _kMahjongLevels.length);
    if (totalPairs > 24) totalPairs = 24;
    final occupied = <String>{};
    void addPosition(int c, int r, int l) {
      final key = '$c,$r,$l';
      if (!occupied.contains(key)) {
        occupied.add(key);
        positions.add(MahjongPosition(c, r, l));
      }
    }

    int pairsPlaced = 0;
    int attempts = 0;
    while (pairsPlaced < totalPairs && attempts < 1000) {
      attempts++;
      final layer = rng.nextInt(3);
      final col = rng.nextInt(5) * 2;
      final row = rng.nextInt(5) * 2;
      if (layer > 0) {
        final keyUnder = '$col,$row,${layer - 1}';
        if (!occupied.contains(keyUnder)) continue;
      }
      final c1 = col;
      final c2 = 10 - col;
      final key1 = '$c1,$row,$layer';
      final key2 = '$c2,$row,$layer';
      if (occupied.contains(key1) || occupied.contains(key2)) continue;
      addPosition(c1, row, layer);
      if (c1 != c2) {
        addPosition(c2, row, layer);
        pairsPlaced++;
      } else {
        pairsPlaced++;
      }
    }
    int fallbackCol = 0;
    int fallbackRow = 0;
    while (pairsPlaced < totalPairs) {
      final key1 = '$fallbackCol,$fallbackRow,0';
      final key2 = '${10 - fallbackCol},$fallbackRow,0';
      if (!occupied.contains(key1) && !occupied.contains(key2)) {
        addPosition(fallbackCol, fallbackRow, 0);
        addPosition(10 - fallbackCol, fallbackRow, 0);
        pairsPlaced++;
      }
      fallbackCol += 2;
      if (fallbackCol > 4) {
        fallbackCol = 0;
        fallbackRow += 2;
        if (fallbackRow > 8) break;
      }
    }
    return MahjongLevel(
      name: 'Pattern X-${index + 1}',
      maxCols: 10,
      maxRows: 10,
      positions: positions,
    );
  }

  void _loadLevel() {
    _level = _getMahjongLevel(_levelIndex);
    final positions = _level.positions;
    final numTiles = positions.length;
    final numPairs = numTiles ~/ 2;

    // Pick pairs of icons
    final rng = Random();
    final selectedIconIndices = <int>[];

    final shuffledIndices = List.generate(_kIcons.length, (i) => i)
      ..shuffle(rng);

    for (int i = 0; i < numPairs; i++) {
      final index = shuffledIndices[i % shuffledIndices.length];
      selectedIconIndices.add(index);
      selectedIconIndices.add(index);
    }

    selectedIconIndices.shuffle(rng);

    _tiles = List.generate(numTiles, (idx) {
      final pos = positions[idx];
      return MahjongTile(
        id: idx,
        iconIndex: selectedIconIndices[idx],
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

    _chaosTimer?.cancel();
    if (_playDailyMode && _dailyModifierType == 'chaos') {
      _chaosTimeLeft = 15;
      _chaosTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || _won) {
          timer.cancel();
          return;
        }
        setState(() {
          if (_chaosTimeLeft > 1) {
            _chaosTimeLeft--;
          } else {
            _chaosTimeLeft = 15;
            final free = _tiles.where((t) => !t.isMatched && !t.inTray && _isTileFree(t)).toList();
            if (free.isNotEmpty) {
              final rng = Random();
              final target = free[rng.nextInt(free.length)];
              // Find its matching counterpart anywhere on the board
              final counterpart = _tiles.firstWhere(
                (t) => !t.isMatched && !t.inTray && t.id != target.id && t.iconIndex == target.iconIndex,
                orElse: () => target,
              );
              target.isMatched = true;
              if (counterpart != target) {
                counterpart.isMatched = true;
              }
              if (_tiles.every((t) => t.isMatched)) {
                _won = true;
                AudioManager.playSuccess();
                _savePersistedLevel(_levelIndex + 1);
              }
              AudioManager.playClick();
            }
          }
        });
      });
    }
  }

  // Returns true if tile is blocked on top, or blocked on both left and right
  bool _isTileFree(MahjongTile target) {
    if (target.isMatched || target.inTray) return false;

    // Calculate visual rect for target
    final targetLayerOffset = target.layer * 4.0;
    final targetLeft = target.col * _cellWidth - targetLayerOffset;
    final targetTop = target.row * _cellHeight - targetLayerOffset;
    final targetRight = targetLeft + _tileWidth;
    final targetBottom = targetTop + _tileHeight;

    // 1. Check if covered by any tile on a higher layer
    for (final tile in _tiles) {
      if (tile.isMatched || tile.inTray) continue;
      if (tile.layer > target.layer) {
        final tileLayerOffset = tile.layer * 4.0;
        final tileLeft = tile.col * _cellWidth - tileLayerOffset;
        final tileTop = tile.row * _cellHeight - tileLayerOffset;
        final tileRight = tileLeft + _tileWidth;
        final tileBottom = tileTop + _tileHeight;

        // Check AABB overlap (using a small epsilon of 0.5 pixels to avoid rounding/touching issues)
        final overlapX =
            (tileLeft < targetRight - 0.5) && (tileRight > targetLeft + 0.5);
        final overlapY =
            (tileTop < targetBottom - 0.5) && (tileBottom > targetTop + 0.5);
        if (overlapX && overlapY) {
          return false; // Covered
        }
      }
    }

    // 2. Check if blocked on left and right on same layer
    bool blockedLeft = false;
    bool blockedRight = false;

    for (final tile in _tiles) {
      if (tile.isMatched ||
          tile.inTray ||
          tile.layer != target.layer ||
          tile.id == target.id)
        continue;

      final tileLayerOffset = tile.layer * 4.0;
      final tileLeft = tile.col * _cellWidth - tileLayerOffset;
      final tileTop = tile.row * _cellHeight - tileLayerOffset;
      final tileRight = tileLeft + _tileWidth;
      final tileBottom = tileTop + _tileHeight;

      // Check Y-overlap (using 0.5 pixel epsilon)
      final overlapY =
          (tileTop < targetBottom - 0.5) && (tileBottom > targetTop + 0.5);
      if (overlapY) {
        // Tile is to the left if tileLeft is less than targetLeft
        if (tileLeft < targetLeft - 0.5 && tileRight >= targetLeft + 0.5) {
          blockedLeft = true;
        }
        // Tile is to the right if tileLeft is greater than targetLeft
        if (tileLeft > targetLeft + 0.5 && tileLeft <= targetRight - 0.5) {
          blockedRight = true;
        }
      }
    }

    // Free if no tiles on top, AND (not blocked left OR not blocked right)
    return !blockedLeft || !blockedRight;
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
          content: Text(
            'No moves currently possible! Try using Undo or Restart the level.',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  void _saveToHistory() {
    _history.add(
      MahjongStateSnapshot(
        tileMatchedStates: _tiles.map((t) => t.isMatched).toList(),
        tileInTrayStates: _tiles.map((t) => t.inTray).toList(),
        trayTileIds: _tray.map((t) => t.id).toList(),
        moves: _moves,
      ),
    );
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
      _tray = last.trayTileIds
          .map((id) => _tiles.firstWhere((t) => t.id == id))
          .toList();
      _selectedTileId = null;
      _hintTileIdA = null;
      _hintTileIdB = null;
    });
    _saveNormalState();
  }

  void _applyMahjongGravity(MahjongTile target) {
    final layer = target.layer;
    final col = target.col;
    final startRow = target.row;
    
    final above = _tiles.where((t) => !t.isMatched && !t.inTray && t.layer == layer && t.col == col && t.row < startRow).toList()
      ..sort((a, b) => b.row.compareTo(a.row));
    
    for (final t in above) {
      int nextRow = t.row + 2;
      bool isOccupied = _tiles.any((other) => !other.isMatched && !other.inTray && other.id != t.id && other.layer == layer && other.col == col && other.row == nextRow);
      if (!isOccupied && nextRow <= _level.maxRows) {
        t.row = nextRow;
      }
    }
  }

  void _onTileTap(MahjongTile tile) {
    if (tile.isMatched || tile.inTray || _won || _selectedTileId != null)
      return;

    if (!_isTileFree(tile)) {
      AudioManager.playFail();
      setState(() {
        _shakingTileId = tile.id;
      });
      _shakeTimer?.cancel();
      int step = 0;
      _shakeTimer = Timer.periodic(const Duration(milliseconds: 45), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          step++;
          if (step == 1)
            _shakeOffset = -6.0;
          else if (step == 2)
            _shakeOffset = 6.0;
          else if (step == 3)
            _shakeOffset = -4.0;
          else if (step == 4)
            _shakeOffset = 4.0;
          else {
            _shakeOffset = 0.0;
            _shakingTileId = null;
            timer.cancel();
          }
        });
      });
      return;
    }

    if (_tray.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tray is full! Use Undo.',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }

    AudioManager.playClick();
    setState(() {
      _selectedTileId = tile.id;
    });

    Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      setState(() {
        _selectedTileId = null;
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

          if (_playDailyMode && _dailyModifierType == 'gravity') {
            _applyMahjongGravity(match1);
            _applyMahjongGravity(match2);
          }

          final m1Id = match1.id;
          final m2Id = match2.id;
          _animatingMatches.add(m1Id);
          _animatingMatches.add(m2Id);

          Timer(const Duration(milliseconds: 300), () {
            if (mounted) {
              setState(() {
                _animatingMatches.remove(m1Id);
                _animatingMatches.remove(m2Id);
              });
            }
          });

          if (_tiles.every((t) => t.isMatched)) {
            _won = true;
            AudioManager.playSuccess();
            _savePersistedLevel(_levelIndex + 1);
          }
        }
        _saveNormalState();
      });
    });
  }

  void _reset() => setState(() => _loadLevel());

  void _nextLevel() {
    if (!_won) return;

    setState(() {
      _levelIndex++;
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
                'Tray Slots (${_tray.length}/4)',
                style: GoogleFonts.outfit(
                  color: context.textSecondary,
                  fontSize: context.scale(11),
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_history.isNotEmpty)
                GestureDetector(
                  onTap: _undo,
                  child: Text(
                    'Undo last move',
                    style: GoogleFonts.outfit(
                      color: accentColor,
                      fontSize: context.scale(11),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(4, (index) {
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
                    child: Icon(tile.icon, color: accentColor, size: 20),
                  ),
                );
              } else {
                return Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.bgDark.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: context.textMuted.withAlpha(40),
                      width: 1,
                    ),
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

    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        backgroundColor: context.bgDark,
        foregroundColor: context.textPrimary,
        title: Text(
          'Mahjong Solitaire',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
          ),
        ),
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
                Icon(
                  Icons.lightbulb_outline,
                  size: 20,
                  color: context.textMuted,
                ),
                Positioned(
                  right: -4,
                  top: -4,
                  child: CircleAvatar(
                    radius: 6,
                    backgroundColor: Colors.amber,
                    child: Text(
                      _hintCount == 0 ? '+' : '$_hintCount',
                      style: GoogleFonts.outfit(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            onPressed: !_won
                ? () async {
                    if (_hintCount > 0) {
                      _useHint();
                    } else {
                      await BuyHintsDialog.show(
                        context,
                        initialGameId: 'memory',
                        onPurchaseComplete: () async {
                          final newCount = await HintManager.getHints('memory');
                          if (mounted) setState(() => _hintCount = newCount);
                        },
                      );
                    }
                  }
                : null,
          ),
          if (MediaQuery.of(context).size.width < 360)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: context.textMuted),
              onSelected: (val) {
                if (val == 'help') {
                  RulesHelper.showRulesBottomSheet(context, 'memory', 'Mahjong Solitaire');
                } else if (val == 'reset') {
                  _reset();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'help',
                  child: Row(
                    children: [
                      Icon(Icons.help_outline, size: 20),
                      SizedBox(width: 8),
                      Text('Rules'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'reset',
                  child: Row(
                    children: [
                      Icon(Icons.refresh, size: 20),
                      SizedBox(width: 8),
                      Text('Reset'),
                    ],
                  ),
                ),
              ],
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.help_outline, size: 20),
              color: context.textMuted,
              onPressed: () => RulesHelper.showRulesBottomSheet(
                context,
                'memory',
                'Mahjong Solitaire',
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: _reset,
              color: context.textMuted,
            ),
          ],
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                _playDailyMode 
                    ? 'Daily' 
                    : (MediaQuery.of(context).size.width < 360 ? 'L. ${_levelIndex + 1}' : 'Level ${_levelIndex + 1}'),
                style: AppTheme.numberStyle(
                  color: accentColor,
                  fontSize: context.scale(13),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_playDailyMode) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'DAILY CHALLENGE: ${_dailyModifierName.toUpperCase()}',
                          style: GoogleFonts.outfit(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    if (_dailyModifierType == 'chaos') ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.timer, color: Colors.amber, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Next Collapse in: $_chaosTimeLeft s',
                            style: GoogleFonts.spaceGrotesk(
                              color: Colors.amber[200],
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                children: [
                  Text(
                    'Match free pairs of tiles to clear the board',
                    style: GoogleFonts.outfit(
                      color: context.textSecondary,
                      fontSize: context.scale(13),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Layout: ${_level.name}',
                        style: GoogleFonts.outfit(
                          color: context.textMuted,
                          fontSize: context.scale(12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.08),
                    width: 1.5,
                  ),
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.1,
                    colors: Theme.of(context).brightness == Brightness.dark
                        ? [
                            const Color(0xFF0F3E2B), // Forest Green center
                            const Color(0xFF082016), // Dark outer edge
                          ]
                        : [
                            const Color(0xFF1E6F4B), // Rich lighter green
                            const Color(0xFF10432C), // Deeper forest green
                          ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
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

                    // Update member variables for AABB logic in _isTileFree
                    _cellWidth = cellWidth;
                    _cellHeight = cellHeight;
                    _tileWidth = tileWidth;
                    _tileHeight = tileHeight;

                    // Ensure tiles fit within container boundaries
                    final boardWidth = gridCols * cellWidth;
                    final boardHeight = gridRows * cellHeight;

                    // Sort tiles by layer so that higher layers are rendered on top
                    final sortedTiles = _tiles.toList()
                      ..sort((a, b) {
                        if (a.layer != b.layer)
                          return a.layer.compareTo(b.layer);
                        // Tie breaker: top to bottom, left to right
                        if (a.row != b.row) return a.row.compareTo(b.row);
                        return a.col.compareTo(b.col);
                      });

                    final stackContent = Stack(
                      clipBehavior: Clip.none,
                      children: sortedTiles.map((tile) {
                        final isAnimatingMatch = _animatingMatches.contains(
                          tile.id,
                        );
                        if ((tile.isMatched || tile.inTray) &&
                            !isAnimatingMatch) {
                          return const SizedBox.shrink();
                        }

                        final isFree = _isTileFree(tile);
                        final isSelected = _selectedTileId == tile.id;
                        final isHinted =
                            _hintTileIdA == tile.id ||
                            _hintTileIdB == tile.id;

                        // Calculate position on the screen
                        // Apply shift for layers to give 3D depth effect
                        final layerOffset = tile.layer * 4.0;
                        final isShaking = _shakingTileId == tile.id;
                        final leftPos =
                            tile.col * cellWidth -
                            layerOffset +
                            (isShaking ? _shakeOffset : 0.0);
                        final topPos = tile.row * cellHeight - layerOffset;

                        if (isAnimatingMatch) {
                          return TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 1.0, end: 0.0),
                            duration: const Duration(milliseconds: 300),
                            builder: (context, value, child) {
                              return Positioned(
                                left: leftPos,
                                top: topPos,
                                width: tileWidth,
                                height: tileHeight,
                                child: Transform.scale(
                                  scale: 1.0 + (1.0 - value) * 0.25,
                                  child: Opacity(
                                    opacity: value,
                                    child: Container(
                                      margin: const EdgeInsets.all(2.0),
                                      decoration: BoxDecoration(
                                        color: Colors.amber,
                                        borderRadius: BorderRadius.circular(
                                          6,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.amber.withOpacity(
                                              0.6 * value,
                                            ),
                                            blurRadius: 12,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Icon(
                                          tile.icon,
                                          color: Colors.white,
                                          size: tileWidth * 0.52,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        }

                        // 3D Mahjong tile layered container:
                        // Outer container represents the backing layer
                        final backingColor =
                            Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF1B4D3E)
                            : const Color(0xFF14533C);

                        final Color faceColor;
                        if (isSelected) {
                          faceColor = accentColor.withOpacity(0.15);
                        } else if (isHinted) {
                          faceColor = Colors.amber.withOpacity(0.2);
                        } else if (!isFree) {
                          faceColor =
                              Theme.of(context).brightness ==
                                  Brightness.dark
                              ? const Color(0xFF22242B)
                              : const Color(0xFFE5E2DA);
                        } else {
                          faceColor =
                              Theme.of(context).brightness ==
                                  Brightness.dark
                              ? const Color(0xFF2E323A)
                              : const Color(0xFFFAF6EE);
                        }

                        return Positioned(
                          left: leftPos,
                          top: topPos,
                          width: tileWidth,
                          height: tileHeight,
                          child: GestureDetector(
                            onTap: () => _onTileTap(tile),
                            behavior: HitTestBehavior.opaque,
                            child: AnimatedScale(
                              scale: isSelected ? 1.08 : 1.0,
                              duration: const Duration(milliseconds: 150),
                              curve: Curves.easeOutCubic,
                              child: Container(
                                margin: const EdgeInsets.all(2.0),
                                decoration: BoxDecoration(
                                  color: backingColor,
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.35),
                                      offset: Offset(
                                        2.0 +
                                            tile.layer * 1.5 +
                                            (isSelected ? 2.0 : 0.0),
                                        2.5 +
                                            tile.layer * 1.5 +
                                            (isSelected ? 2.0 : 0.0),
                                      ),
                                      blurRadius: isSelected ? 5.0 : 3.0,
                                    ),
                                  ],
                                ),
                                child: AnimatedContainer(
                                  duration: const Duration(
                                    milliseconds: 180,
                                  ),
                                  // Shift face up/left slightly to show the 3D green backing at the bottom-right
                                  margin: const EdgeInsets.only(
                                    bottom: 3.5,
                                    right: 3.0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: faceColor,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isSelected
                                          ? accentColor
                                          : (isHinted
                                                ? Colors.amber
                                                : (isFree
                                                      ? (Theme.of(
                                                                  context,
                                                                ).brightness ==
                                                                Brightness
                                                                    .dark
                                                            ? Colors.white
                                                                  .withOpacity(
                                                                    0.2,
                                                                  )
                                                            : Colors.black
                                                                  .withOpacity(
                                                                    0.12,
                                                                  ))
                                                      : Colors
                                                            .transparent)),
                                      width: isSelected || isHinted
                                          ? 2.0
                                          : 1.0,
                                    ),
                                  ),
                                  child: Opacity(
                                    opacity: isFree ? 1.0 : 0.4,
                                    child: Center(
                                      child: Icon(
                                        tile.icon,
                                        color: isSelected
                                            ? accentColor
                                            : (isHinted
                                                  ? Colors.amber.shade800
                                                  : (Theme.of(
                                                              context,
                                                            ).brightness ==
                                                            Brightness.dark
                                                        ? Colors.white
                                                              .withOpacity(
                                                                0.95,
                                                              )
                                                        : Colors.black87)),
                                        size: tileWidth * 0.48,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );

                    if (_playDailyMode && _dailyModifierType == 'zoom' && _dailyModifierType != 'chaos') {
                      return Center(
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.amber, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: InteractiveViewer(
                              transformationController: _zoomController,
                              boundaryMargin: const EdgeInsets.all(200),
                              minScale: 1.0,
                              maxScale: 3.5,
                              constrained: false,
                              child: SizedBox(
                                width: boardWidth,
                                height: boardHeight,
                                child: stackContent,
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    return Center(
                      child: SizedBox(
                        width: boardWidth,
                        height: boardHeight,
                        child: stackContent,
                      ),
                    );
                  },
                ),
              ),
            ),
            _buildTray(),
            if (_won)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'All Tiles Cleared!',
                      style: GoogleFonts.outfit(
                        color: accentColor,
                        fontSize: context.scale(16),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AutoNextCountdown(
                      onNext: _nextLevel,
                      accentColor: accentColor,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
