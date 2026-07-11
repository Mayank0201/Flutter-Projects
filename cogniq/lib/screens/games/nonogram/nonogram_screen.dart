import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cogniq/widgets/buy_hints_dialog.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/audio_manager.dart';
import '../../../utils/hint_manager.dart';
import '../../../utils/rules_helper.dart';
import '../../../widgets/auto_next_countdown.dart';
import '../../../widgets/challenge_cleared_overlay.dart';

class NonogramLevel {
  final String name;
  final List<List<int>> grid;
  const NonogramLevel({required this.name, required this.grid});
}

const List<NonogramLevel> _kLevels = [
  NonogramLevel(
    name: 'Heart',
    grid: [
      [0, 1, 0, 1, 0],
      [1, 1, 1, 1, 1],
      [1, 1, 1, 1, 1],
      [0, 1, 1, 1, 0],
      [0, 0, 1, 0, 0],
    ],
  ),
  NonogramLevel(
    name: 'Sword',
    grid: [
      [0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0],
      [0, 1, 1, 1, 0],
      [0, 0, 1, 0, 0],
      [0, 1, 1, 1, 0],
    ],
  ),
  NonogramLevel(
    name: 'House',
    grid: [
      [0, 0, 1, 0, 0],
      [0, 1, 1, 1, 0],
      [1, 1, 1, 1, 1],
      [1, 0, 1, 0, 1],
      [1, 1, 1, 1, 1],
    ],
  ),
  NonogramLevel(
    name: 'Diamond',
    grid: [
      [0, 0, 1, 0, 0],
      [0, 1, 1, 1, 0],
      [1, 1, 1, 1, 1],
      [0, 1, 1, 1, 0],
      [0, 0, 1, 0, 0],
    ],
  ),
  NonogramLevel(
    name: 'Smile',
    grid: [
      [0, 1, 0, 1, 0],
      [0, 1, 0, 1, 0],
      [0, 0, 0, 0, 0],
      [1, 0, 0, 0, 1],
      [0, 1, 1, 1, 0],
    ],
  ),
  NonogramLevel(
    name: 'Pyramid',
    grid: [
      [0, 0, 1, 0, 0],
      [0, 1, 1, 1, 0],
      [1, 1, 1, 1, 1],
      [1, 1, 1, 1, 1],
      [1, 1, 1, 1, 1],
    ],
  ),
  NonogramLevel(
    name: 'Tree',
    grid: [
      [0, 0, 1, 0, 0],
      [0, 1, 1, 1, 0],
      [1, 1, 1, 1, 1],
      [0, 0, 1, 0, 0],
      [0, 1, 1, 1, 0],
    ],
  ),
  NonogramLevel(
    name: 'Arrow',
    grid: [
      [0, 0, 1, 0, 0],
      [0, 1, 1, 1, 0],
      [1, 0, 1, 0, 1],
      [0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0],
    ],
  ),
  NonogramLevel(
    name: 'Face',
    grid: [
      [1, 1, 1, 1, 1],
      [1, 0, 1, 0, 1],
      [1, 1, 1, 1, 1],
      [0, 1, 1, 1, 0],
      [0, 0, 0, 0, 0],
    ],
  ),
  NonogramLevel(
    name: 'Key',
    grid: [
      [0, 1, 1, 1, 0],
      [0, 1, 0, 1, 0],
      [0, 1, 1, 1, 0],
      [0, 0, 1, 0, 0],
      [0, 1, 1, 0, 0],
    ],
  ),
  NonogramLevel(
    name: 'Moon',
    grid: [
      [0, 1, 1, 1, 0],
      [1, 1, 1, 0, 0],
      [1, 1, 0, 0, 0],
      [1, 1, 1, 0, 0],
      [0, 1, 1, 1, 0],
    ],
  ),
  NonogramLevel(
    name: 'Star',
    grid: [
      [0, 0, 1, 0, 0],
      [1, 1, 1, 1, 1],
      [0, 1, 1, 1, 0],
      [0, 1, 0, 1, 0],
      [1, 0, 0, 0, 1],
    ],
  ),
  NonogramLevel(
    name: 'Fish',
    grid: [
      [0, 1, 1, 0, 0],
      [1, 1, 1, 1, 0],
      [1, 1, 1, 0, 1],
      [1, 1, 1, 1, 0],
      [0, 1, 1, 0, 0],
    ],
  ),
  NonogramLevel(
    name: 'Crown',
    grid: [
      [1, 0, 1, 0, 1],
      [1, 1, 1, 1, 1],
      [1, 1, 1, 1, 1],
      [0, 1, 1, 1, 0],
      [1, 1, 1, 1, 1],
    ],
  ),
  NonogramLevel(
    name: 'Duck',
    grid: [
      [0, 1, 1, 0, 0],
      [0, 1, 1, 1, 0],
      [1, 1, 1, 1, 1],
      [0, 1, 1, 1, 1],
      [0, 0, 1, 1, 0],
    ],
  ),
  NonogramLevel(
    name: 'Cross',
    grid: [
      [0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0],
      [1, 1, 1, 1, 1],
      [0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0],
    ],
  ),
  NonogramLevel(
    name: 'Frame',
    grid: [
      [1, 1, 1, 1, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 1, 1, 1, 1],
    ],
  ),
  NonogramLevel(
    name: 'Stripe H',
    grid: [
      [1, 1, 1, 1, 1],
      [0, 0, 0, 0, 0],
      [1, 1, 1, 1, 1],
      [0, 0, 0, 0, 0],
      [1, 1, 1, 1, 1],
    ],
  ),
  NonogramLevel(
    name: 'Stripe V',
    grid: [
      [1, 0, 1, 0, 1],
      [1, 0, 1, 0, 1],
      [1, 0, 1, 0, 1],
      [1, 0, 1, 0, 1],
      [1, 0, 1, 0, 1],
    ],
  ),
  NonogramLevel(
    name: 'Checker',
    grid: [
      [1, 0, 1, 0, 1],
      [0, 1, 0, 1, 0],
      [1, 0, 1, 0, 1],
      [0, 1, 0, 1, 0],
      [1, 0, 1, 0, 1],
    ],
  ),
  NonogramLevel(
    name: 'Inv Checker',
    grid: [
      [0, 1, 0, 1, 0],
      [1, 0, 1, 0, 1],
      [0, 1, 0, 1, 0],
      [1, 0, 1, 0, 1],
      [0, 1, 0, 1, 0],
    ],
  ),
  NonogramLevel(
    name: 'Corner TL',
    grid: [
      [1, 1, 1, 1, 0],
      [1, 1, 1, 0, 0],
      [1, 1, 0, 0, 0],
      [1, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
    ],
  ),
  NonogramLevel(
    name: 'Corner TR',
    grid: [
      [0, 1, 1, 1, 1],
      [0, 0, 1, 1, 1],
      [0, 0, 0, 1, 1],
      [0, 0, 0, 0, 1],
      [0, 0, 0, 0, 0],
    ],
  ),
  NonogramLevel(
    name: 'Corner BL',
    grid: [
      [0, 0, 0, 0, 0],
      [1, 0, 0, 0, 0],
      [1, 1, 0, 0, 0],
      [1, 1, 1, 0, 0],
      [1, 1, 1, 1, 0],
    ],
  ),
  NonogramLevel(
    name: 'Corner BR',
    grid: [
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 1],
      [0, 0, 0, 1, 1],
      [0, 0, 1, 1, 1],
      [0, 1, 1, 1, 1],
    ],
  ),
  NonogramLevel(
    name: 'X Shape',
    grid: [
      [1, 0, 0, 0, 1],
      [0, 1, 0, 1, 0],
      [0, 0, 1, 0, 0],
      [0, 1, 0, 1, 0],
      [1, 0, 0, 0, 1],
    ],
  ),
  NonogramLevel(
    name: 'T Shape',
    grid: [
      [1, 1, 1, 1, 1],
      [0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0],
    ],
  ),
  NonogramLevel(
    name: 'H Shape',
    grid: [
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 1, 1, 1, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
    ],
  ),
  NonogramLevel(
    name: 'C Shape',
    grid: [
      [1, 1, 1, 1, 1],
      [1, 0, 0, 0, 0],
      [1, 0, 0, 0, 0],
      [1, 0, 0, 0, 0],
      [1, 1, 1, 1, 1],
    ],
  ),
  NonogramLevel(
    name: 'E Shape',
    grid: [
      [1, 1, 1, 1, 1],
      [1, 0, 0, 0, 0],
      [1, 1, 1, 1, 0],
      [1, 0, 0, 0, 0],
      [1, 1, 1, 1, 1],
    ],
  ),
  NonogramLevel(
    name: 'F Shape',
    grid: [
      [1, 1, 1, 1, 1],
      [1, 0, 0, 0, 0],
      [1, 1, 1, 1, 0],
      [1, 0, 0, 0, 0],
      [1, 0, 0, 0, 0],
    ],
  ),
  NonogramLevel(
    name: 'L Shape',
    grid: [
      [1, 0, 0, 0, 0],
      [1, 0, 0, 0, 0],
      [1, 0, 0, 0, 0],
      [1, 0, 0, 0, 0],
      [1, 1, 1, 1, 1],
    ],
  ),
  NonogramLevel(
    name: 'Arrow Up',
    grid: [
      [0, 0, 1, 0, 0],
      [0, 1, 1, 1, 0],
      [1, 0, 1, 0, 1],
      [0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0],
    ],
  ),
  NonogramLevel(
    name: 'Arrow Down',
    grid: [
      [0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0],
      [1, 0, 1, 0, 1],
      [0, 1, 1, 1, 0],
      [0, 0, 1, 0, 0],
    ],
  ),
  NonogramLevel(
    name: 'Arrow Left',
    grid: [
      [0, 0, 1, 0, 0],
      [0, 1, 0, 0, 0],
      [1, 1, 1, 1, 1],
      [0, 1, 0, 0, 0],
      [0, 0, 1, 0, 0],
    ],
  ),
  NonogramLevel(
    name: 'Arrow Right',
    grid: [
      [0, 0, 1, 0, 0],
      [0, 0, 0, 1, 0],
      [1, 1, 1, 1, 1],
      [0, 0, 0, 1, 0],
      [0, 0, 1, 0, 0],
    ],
  ),
  NonogramLevel(
    name: 'Box Center',
    grid: [
      [0, 0, 0, 0, 0],
      [0, 1, 1, 1, 0],
      [0, 1, 1, 1, 0],
      [0, 1, 1, 1, 0],
      [0, 0, 0, 0, 0],
    ],
  ),
  NonogramLevel(
    name: 'Ring',
    grid: [
      [0, 0, 0, 0, 0],
      [0, 1, 1, 1, 0],
      [0, 1, 0, 1, 0],
      [0, 1, 1, 1, 0],
      [0, 0, 0, 0, 0],
    ],
  ),
  NonogramLevel(
    name: 'Diamond S',
    grid: [
      [0, 0, 0, 0, 0],
      [0, 0, 1, 0, 0],
      [0, 1, 0, 1, 0],
      [0, 0, 1, 0, 0],
      [0, 0, 0, 0, 0],
    ],
  ),
  NonogramLevel(
    name: 'Triangle U',
    grid: [
      [0, 0, 1, 0, 0],
      [0, 1, 1, 1, 0],
      [1, 1, 1, 1, 1],
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
    ],
  ),
  NonogramLevel(
    name: 'Triangle D',
    grid: [
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [1, 1, 1, 1, 1],
      [0, 1, 1, 1, 0],
      [0, 0, 1, 0, 0],
    ],
  ),
  NonogramLevel(
    name: 'Z Shape',
    grid: [
      [1, 1, 1, 1, 1],
      [0, 0, 0, 1, 0],
      [0, 0, 1, 0, 0],
      [0, 1, 0, 0, 0],
      [1, 1, 1, 1, 1],
    ],
  ),
  NonogramLevel(
    name: 'N Shape',
    grid: [
      [1, 0, 0, 0, 1],
      [1, 1, 0, 0, 1],
      [1, 0, 1, 0, 1],
      [1, 0, 0, 1, 1],
      [1, 0, 0, 0, 1],
    ],
  ),
  NonogramLevel(
    name: 'M Shape',
    grid: [
      [1, 0, 0, 0, 1],
      [1, 1, 0, 1, 1],
      [1, 0, 1, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
    ],
  ),
  NonogramLevel(
    name: 'W Shape',
    grid: [
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 1, 0, 1],
      [1, 1, 0, 1, 1],
      [1, 0, 0, 0, 1],
    ],
  ),
  NonogramLevel(
    name: 'Y Shape',
    grid: [
      [1, 0, 0, 0, 1],
      [0, 1, 0, 1, 0],
      [0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0],
    ],
  ),
  NonogramLevel(
    name: 'Plus',
    grid: [
      [0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0],
      [1, 1, 1, 1, 1],
      [0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0],
    ],
  ),
  NonogramLevel(
    name: 'Anchor',
    grid: [
      [0, 0, 1, 0, 0],
      [0, 1, 1, 1, 0],
      [0, 0, 1, 0, 0],
      [1, 0, 1, 0, 1],
      [0, 1, 1, 1, 0],
    ],
  ),
  NonogramLevel(
    name: 'Zigzag',
    grid: [
      [1, 1, 0, 0, 0],
      [0, 1, 1, 0, 0],
      [0, 0, 1, 1, 0],
      [0, 0, 0, 1, 1],
      [0, 0, 0, 0, 1],
    ],
  ),
  NonogramLevel(
    name: 'Hourglass',
    grid: [
      [1, 1, 1, 1, 1],
      [0, 1, 1, 1, 0],
      [0, 0, 1, 0, 0],
      [0, 1, 1, 1, 0],
      [1, 1, 1, 1, 1],
    ],
  ),
];

class NonogramScreen extends StatefulWidget {
  const NonogramScreen({super.key});

  @override
  State<NonogramScreen> createState() => _NonogramScreenState();
}

class _NonogramScreenState extends State<NonogramScreen> {
  int _levelIndex = 0;
  late NonogramLevel _level;
  int _gridSize = 5;
  late List<List<int>> _playerGrid; // 0 = empty, 1 = painted
  bool _won = false;
  int _hintCount = 0;
  bool _playDailyMode = false;
  String _dailyModifierType = '';
  String _dailyModifierName = '';
  String _dailyModifierDescription = '';
  int? _hoveredRow;
  int? _hoveredCol;

  late List<List<int>> _rowClues;
  late List<List<int>> _colClues;

  final GlobalKey _gridKey = GlobalKey();
  final Set<String> _draggedCells = {};
  int _dragMode = 1;

  int _gridSizeForLevel(int level) {
    if (level <= 10) return 5;
    if (level <= 20) return 6;
    if (level <= 30) return 7;
    if (level <= 40) return 8;
    return 9;
  }

  NonogramLevel _getLevelForIndex(int index) {
    if (index < 10 && index < _kLevels.length) {
      return _kLevels[index]; // Use first 10 hand-designed levels
    }

    final size = _gridSizeForLevel(index + 1);
    final rng = Random(index * 9876543);
    final grid = List.generate(size, (_) => List<int>.filled(size, 0));

    final bool isMirrorMode = _playDailyMode && _dailyModifierType == 'mirror';

    if (isMirrorMode) {
      // Asymmetric design for mirror challenge
      for (int r = 0; r < size; r++) {
        for (int c = 0; c < size; c++) {
          grid[r][c] = rng.nextDouble() > 0.5 ? 1 : 0;
        }
      }
    } else {
      // Symmetrical design
      for (int r = 0; r < (size + 1) ~/ 2; r++) {
        for (int c = 0; c < (size + 1) ~/ 2; c++) {
          final val = rng.nextDouble() > 0.45 ? 1 : 0;
          grid[r][c] = val;
          grid[r][size - 1 - c] = val;
          grid[size - 1 - r][c] = val;
          grid[size - 1 - r][size - 1 - c] = val;
        }
      }
    }

    int ones = 0;
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (grid[r][c] == 1) ones++;
      }
    }

    if (ones < size || ones > (size * size * 0.75)) {
      if (isMirrorMode) {
        // Asymmetric fallback
        for (int r = 0; r < size; r++) {
          for (int c = 0; c < size; c++) {
            grid[r][c] = (r >= c) ? 1 : 0;
          }
        }
      } else {
        for (int r = 0; r < size; r++) {
          for (int c = 0; c < size; c++) {
            grid[r][c] =
                (r == c ||
                    r == size - 1 - c ||
                    r == size ~/ 2 ||
                    c == size ~/ 2)
                ? 1
                : 0;
          }
        }
      }
    }

    final names = [
      'Shield',
      'Emblem',
      'Artifact',
      'Tartan',
      'Mosaic',
      'Crest',
      'Sigil',
      'Rune',
      'Glyph',
      'Totem',
      'Amulet',
      'Lattice',
      'Tapestry',
      'Gate',
      'Tower',
      'Crown',
      'Chamber',
      'Anchor',
      'Relic',
      'Pillar',
    ];
    final name = names[index % names.length];
    return NonogramLevel(name: name, grid: grid);
  }

  @override
  void initState() {
    super.initState();
    _level = _getLevelForIndex(0);
    _gridSize = _level.grid.length;
    _playerGrid = List.generate(_gridSize, (_) => List.filled(_gridSize, 0));
    _rowClues = [];
    _colClues = [];
    _initLevel();
  }

  Future<void> _initLevel() async {
    _hintCount = 1;
    final prefs = await SharedPreferences.getInstance();
    _playDailyMode = prefs.getBool('play_daily_mode') ?? false;
    if (_playDailyMode) {
      _dailyModifierType = prefs.getString('daily_modifier_type') ?? '';
      _dailyModifierName = prefs.getString('daily_modifier_name') ?? '';
      _dailyModifierDescription = prefs.getString('daily_modifier_description') ?? '';
    } else {
      _dailyModifierType = '';
      _dailyModifierName = '';
      _dailyModifierDescription = '';
    }

    final savedLevel = prefs.getInt('level_nonogram') ?? 0;


    if (mounted) {
      setState(() {
        _levelIndex = _playDailyMode ? (savedLevel % 50) : savedLevel;
        _loadLevel();
      });
    }

    if (!_playDailyMode) {
      Future.delayed(Duration.zero, () async {
        if (!mounted) return;
        final savedStateStr = prefs.getString('normal_nonogram_state');
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
                final List<dynamic> gridData = data['playerGrid'];
                final List<List<int>> loadedGrid = gridData
                    .map((row) => List<int>.from(row))
                    .toList();
                setState(() {
                  _playerGrid = loadedGrid;
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
    final state = {'playerGrid': _playerGrid, 'levelIndex': _levelIndex};
    await prefs.setString('normal_nonogram_state', jsonEncode(state));
  }

  Future<void> _clearNormalState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('normal_nonogram_state');
  }

  void _loadLevel() {
    _level = _getLevelForIndex(_levelIndex);
    _gridSize = _level.grid.length;
    _playerGrid = List.generate(_gridSize, (_) => List.filled(_gridSize, 0));
    _won = false;

    // In daily inverted mode, clues intentionally describe the original (non-inverted)
    // pattern so the player must mentally invert while solving.
    _rowClues = List.generate(
      _gridSize,
      (r) => _calculateClues(_level.grid[r]),
    );
    _colClues = List.generate(_gridSize, (c) {
      final colData = List.generate(_gridSize, (r) => _level.grid[r][c]);
      return _calculateClues(colData);
    });
  }

  List<int> _calculateClues(List<int> line) {
    final List<int> clues = [];
    int currentRun = 0;
    for (final val in line) {
      if (val == 1) {
        currentRun++;
      } else {
        if (currentRun > 0) {
          clues.add(currentRun);
          currentRun = 0;
        }
      }
    }
    if (currentRun > 0) {
      clues.add(currentRun);
    }
    return clues.isEmpty ? [0] : clues;
  }

  Future<void> _savePersistedLevel(int lvl) async {
    if (_playDailyMode) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('level_nonogram', lvl);
    final earned = await HintManager.onLevelCleared('nonogram');
    final newCount = await HintManager.getHints('nonogram');
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
          backgroundColor: AppTheme.accentFor('nonogram'),
        ),
      );
    }
  }

  void _toggleCell(int r, int c) {
    if (_won) return;
    AudioManager.playClick();

    setState(() {
      _playerGrid[r][c] = (_playerGrid[r][c] == 1) ? 0 : 1;
      _checkWinCondition();
    });
    if (_won) {
      _clearNormalState();
    } else {
      _saveNormalState();
    }
  }

  void _handleTap(Offset localPosition) {
    if (_won) return;
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final int maxRowClues = _rowClues.isEmpty
        ? 1
        : _rowClues.map((c) => c.length).reduce(max);
    final int maxColClues = _colClues.isEmpty
        ? 1
        : _colClues.map((c) => c.length).reduce(max);
    final double clueWidth = max(
      context.scale(45.0),
      maxRowClues * context.scale(14.0) + 8.0,
    );
    final double clueHeight = max(
      context.scale(45.0),
      maxColClues * context.scale(18.0) + 8.0,
    );

    final double screenW = context.screenWidth;
    final double screenH = context.screenHeight;
    final double maxGridW = min(screenW - 16, screenH * 0.68);
    final double cellSize = ((maxGridW - 16 - clueWidth) / _gridSize - 4).clamp(
      16.0,
      60.0,
    );

    final double contentX = localPosition.dx - 8;
    final double contentY = localPosition.dy - 8;

    final double cellsX = contentX - clueWidth;
    final double cellsY = contentY - clueHeight;

    if (cellsX < 0 || cellsY < 0) return;

    final int c = cellsX ~/ (cellSize + 4);
    final int r = cellsY ~/ (cellSize + 4);

    setState(() {
      if (r >= 0 && r < _gridSize) _hoveredRow = r;
      if (c >= 0 && c < _gridSize) _hoveredCol = c;
    });

    if (r >= 0 && r < _gridSize && c >= 0 && c < _gridSize) {
      _toggleCell(r, c);
    }
  }

  void _handlePan(Offset localPosition) {
    if (_won) return;
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final int maxRowClues = _rowClues.isEmpty
        ? 1
        : _rowClues.map((c) => c.length).reduce(max);
    final int maxColClues = _colClues.isEmpty
        ? 1
        : _colClues.map((c) => c.length).reduce(max);
    final double clueWidth = max(
      context.scale(45.0),
      maxRowClues * context.scale(14.0) + 8.0,
    );
    final double clueHeight = max(
      context.scale(45.0),
      maxColClues * context.scale(18.0) + 8.0,
    );

    final double screenW = context.screenWidth;
    final double screenH = context.screenHeight;
    final double maxGridW = min(screenW - 16, screenH * 0.68);
    final double cellSize = ((maxGridW - 16 - clueWidth) / _gridSize - 4).clamp(
      16.0,
      60.0,
    );

    final double contentX = localPosition.dx - 8;
    final double contentY = localPosition.dy - 8;

    final double cellsX = contentX - clueWidth;
    final double cellsY = contentY - clueHeight;

    if (cellsX < 0 || cellsY < 0) return;

    final int c = cellsX ~/ (cellSize + 4);
    final int r = cellsY ~/ (cellSize + 4);

    bool changed = false;
    int? nextHoveredRow = _hoveredRow;
    int? nextHoveredCol = _hoveredCol;

    if (r >= 0 && r < _gridSize && r != _hoveredRow) {
      nextHoveredRow = r;
      changed = true;
    }
    if (c >= 0 && c < _gridSize && c != _hoveredCol) {
      nextHoveredCol = c;
      changed = true;
    }

    bool gridChanged = false;
    if (r >= 0 && r < _gridSize && c >= 0 && c < _gridSize) {
      final String cellKey = '$r,$c';
      if (!_draggedCells.contains(cellKey)) {
        if (_draggedCells.isEmpty) {
          _dragMode = _playerGrid[r][c] == 1 ? 0 : 1;
          AudioManager.playClick();
        }
        _draggedCells.add(cellKey);
        _playerGrid[r][c] = _dragMode;
        gridChanged = true;
        changed = true;
      }
    }

    if (changed) {
      setState(() {
        _hoveredRow = nextHoveredRow;
        _hoveredCol = nextHoveredCol;
        if (gridChanged) {
          _checkWinCondition();
        }
      });
    }
  }

  void _checkWinCondition() {
    bool meetsWin = true;
    final isMirror = false;
    final isInverted = _playDailyMode && _dailyModifierType == 'inverted';

    for (int r = 0; r < _gridSize; r++) {
      for (int c = 0; c < _gridSize; c++) {
        final actualC = isMirror ? (_gridSize - 1 - c) : c;
        final targetVal = _level.grid[r][actualC];
        final playerVal = _playerGrid[r][c];

        if (isInverted) {
          if (targetVal == 0 && playerVal != 1) meetsWin = false;
          if (targetVal == 1 && playerVal == 1) meetsWin = false;
        } else {
          // Normal or Mirror mode
          if (targetVal == 1 && playerVal != 1) meetsWin = false;
          if (targetVal == 0 && playerVal == 1) meetsWin = false;
        }
      }
    }

    if (meetsWin) {
      _won = true;
      AudioManager.playSuccess();
      _savePersistedLevel(_levelIndex + 1);
    }
  }

  Future<void> _useHint() async {
    if (_won) return;

    int targetR = -1;
    int targetC = -1;
    final isMirror = false;
    final isInverted = _playDailyMode && _dailyModifierType == 'inverted';

    for (int r = 0; r < _gridSize; r++) {
      for (int c = 0; c < _gridSize; c++) {
        final actualC = isMirror ? (_gridSize - 1 - c) : c;
        final targetVal = _level.grid[r][actualC];
        final playerVal = _playerGrid[r][c];

        if (isInverted) {
          if (targetVal == 0 && playerVal != 1) {
            targetR = r;
            targetC = c;
            break;
          }
        } else {
          if (targetVal == 1 && playerVal != 1) {
            targetR = r;
            targetC = c;
            break;
          }
        }
      }
      if (targetR != -1) break;
    }

    if (targetR != -1 && targetC != -1) {
      setState(() {
        _playerGrid[targetR][targetC] = 1;
        _checkWinCondition();
      });
      if (_won) {
        _clearNormalState();
      } else {
        _saveNormalState();
      }
    }
  }

  void _nextLevel() {
    if (!_won) return;


    setState(() {
      _levelIndex++;
      _loadLevel();
    });
  }

  void _reset() {
    setState(() {
      _playerGrid = List.generate(_gridSize, (_) => List.filled(_gridSize, 0));
      _won = false;
    });
    _saveNormalState();
  }

  Widget _buildClueCell(List<int> clues, {required bool isRow, int? index}) {
    if (_playDailyMode && _dailyModifierType == 'zoom') {
      final active = isRow ? (_hoveredRow == index) : (_hoveredCol == index);
      if (!active) {
        return const SizedBox.shrink();
      }
    }
    if (clues.length == 1 && clues[0] == 0) {
      return Container(
        alignment: isRow ? Alignment.centerRight : Alignment.bottomCenter,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          '0',
          style: GoogleFonts.spaceGrotesk(
            fontSize: context.scale(9.5),
            fontWeight: FontWeight.bold,
            color: context.textMuted.withOpacity(0.5),
          ),
        ),
      );
    }

    final widgets = clues.map((c) {
      return Container(
        margin: EdgeInsets.all(isRow ? 0.8 : 0.4),
        padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.8),
        decoration: BoxDecoration(
          color: context.bgSurface.withOpacity(0.8),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          '$c',
          style: GoogleFonts.spaceGrotesk(
            fontSize: context.scale(9.0),
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
      );
    }).toList();

    return Container(
      alignment: isRow ? Alignment.centerRight : Alignment.bottomCenter,
      padding: const EdgeInsets.all(1),
      child: isRow
          ? Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: widgets,
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: widgets,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentFor('nonogram');

    final List<List<int>> effectiveRowClues = _rowClues;
    final List<List<int>> effectiveColClues = _colClues;

    final int maxRowClues = effectiveRowClues.isEmpty
        ? 1
        : effectiveRowClues.map((c) => c.length).reduce(max);
    final int maxColClues = effectiveColClues.isEmpty
        ? 1
        : effectiveColClues.map((c) => c.length).reduce(max);

    final double clueWidth = max(
      context.scale(45.0),
      maxRowClues * context.scale(14.0) + 8.0,
    );
    final double clueHeight = max(
      context.scale(45.0),
      maxColClues * context.scale(18.0) + 8.0,
    );

    final double screenW = context.screenWidth;
    final double screenH = context.screenHeight;
    final double maxGridW = min(screenW - 16, screenH * 0.68);
    final double cellSize = ((maxGridW - 16 - clueWidth) / _gridSize - 4).clamp(
      16.0,
      60.0,
    );
    final double containerWidth = clueWidth + _gridSize * (cellSize + 4) + 16;

    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        backgroundColor: context.bgDark,
        foregroundColor: context.textPrimary,
        title: Text(
          'Nonogram',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
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
                        initialGameId: 'nonogram',
                        onPurchaseComplete: () async {
                          final newCount = await HintManager.getHints('nonogram');
                          if (mounted) setState(() => _hintCount = newCount);
                        },
                      );
                    }
                  }
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, size: 20),
            color: context.textMuted,
            onPressed: () => RulesHelper.showRulesBottomSheet(
              context,
              'nonogram',
              'Nonogram',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            color: context.textMuted,
            onPressed: _reset,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                _playDailyMode ? 'Daily' : 'Level ${_levelIndex + 1}',
                style: AppTheme.numberStyle(
                  color: accent,
                  fontSize: context.scale(13),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_playDailyMode) ...[
                            Container(
                              margin: const EdgeInsets.all(12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.amber.withOpacity(0.5),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Daily Challenge: $_dailyModifierName - $_dailyModifierDescription',
                                      style: GoogleFonts.outfit(
                                        color: Colors.amber[200],
                                        fontSize: context.scale(12),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          // Clue grid + Nonogram grid
                          Center(
                            child: RepaintBoundary(
                              child: GestureDetector(
                                onTapUp: (details) {
                                _handleTap(details.localPosition);
                              },
                              onPanStart: (details) {
                                _draggedCells.clear();
                                _handlePan(details.localPosition);
                              },
                              onPanUpdate: (details) {
                                _handlePan(details.localPosition);
                              },
                              onPanEnd: (_) {
                                _draggedCells.clear();
                                _saveNormalState();
                              },
                              onPanCancel: () {
                                _draggedCells.clear();
                              },
                              child: Container(
                                key: _gridKey,
                                width: containerWidth,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: context.bgCard,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: AppTheme.cardShadow,
                                ),
                                child: (() {
                                  final isGravity = _playDailyMode && _dailyModifierType == 'gravity';
                                  final colCluesRow = Row(
                                    children: [
                                      if (!isGravity)
                                        SizedBox(
                                          width: clueWidth,
                                          height: clueHeight,
                                        ),
                                      for (int c = 0; c < _gridSize; c++)
                                        SizedBox(
                                          width: cellSize + 4,
                                          height: clueHeight,
                                          child: _buildClueCell(
                                            effectiveColClues.isNotEmpty
                                                ? effectiveColClues[c]
                                                : [0],
                                            isRow: false,
                                            index: c,
                                          ),
                                        ),
                                      if (isGravity)
                                        SizedBox(
                                          width: clueWidth,
                                          height: clueHeight,
                                        ),
                                    ],
                                  );

                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!isGravity) colCluesRow,
                                      // Row Clues + Cells
                                      for (int r = 0; r < _gridSize; r++)
                                        Row(
                                          children: [
                                            // Row Clue on left if not gravity
                                            if (!isGravity)
                                              SizedBox(
                                                width: clueWidth,
                                                height: cellSize + 4,
                                                child: _buildClueCell(
                                                  effectiveRowClues.isNotEmpty
                                                      ? effectiveRowClues[r]
                                                      : [0],
                                                  isRow: true,
                                                  index: r,
                                                ),
                                              ),
                                            // Row Cells
                                            for (int c = 0; c < _gridSize; c++)
                                              Container(
                                                width: cellSize,
                                                height: cellSize,
                                                margin: const EdgeInsets.all(2),
                                                decoration: BoxDecoration(
                                                  color: _playerGrid[r][c] == 1
                                                      ? accent
                                                      : context.bgSurface
                                                            .withOpacity(0.5),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: _playerGrid[r][c] == 1
                                                        ? accent
                                                        : context.textMuted
                                                              .withOpacity(0.2),
                                                    width: 1.5,
                                                  ),
                                                ),
                                                child: null,
                                              ),
                                            // Row Clue on right if gravity
                                            if (isGravity)
                                              SizedBox(
                                                width: clueWidth,
                                                height: cellSize + 4,
                                                child: _buildClueCell(
                                                  effectiveRowClues.isNotEmpty
                                                      ? effectiveRowClues[r]
                                                      : [0],
                                                  isRow: true,
                                                  index: r,
                                                ),
                                              ),
                                          ],
                                        ),
                                      if (isGravity) colCluesRow,
                                    ],
                                  );
                                })(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                          if (_won && !_playDailyMode) ...[
                            Text(
                              'Puzzle solved!',
                              style: GoogleFonts.outfit(
                                fontSize: context.scale(20),
                                fontWeight: FontWeight.bold,
                                color: accent,
                              ),
                            ),
                            const SizedBox(height: 12),
                            AutoNextCountdown(
                              onNext: _nextLevel,
                              accentColor: accent,
                            ),
                          ],
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_won && _playDailyMode)
            Positioned.fill(
              child: ChallengeClearedOverlay(
                accentColor: accent,
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
