import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import 'logic_grid_levels_data.dart';

class LogicGridPlaceholderScreen extends StatefulWidget {
  final String gameName;
  final String description;
  final String category;
  final String uiType; // shading, latin_square, loop, object, region, word

  const LogicGridPlaceholderScreen({
    super.key,
    required this.gameName,
    required this.description,
    required this.category,
    required this.uiType,
  });

  @override
  State<LogicGridPlaceholderScreen> createState() => _LogicGridPlaceholderScreenState();
}

class _LogicGridPlaceholderScreenState extends State<LogicGridPlaceholderScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;

  // Demo Board States
  late List<int> _gridInt;
  late List<bool> _gridBool;
  late List<int> _shadingState; // 0: empty, 1: shaded, 2: X
  late List<int> _objectState; // 0: empty, 1: tree, 2: tent, 3: water

  // Stitches state
  List<List<int>> _stitches = [];
  int? _selectedStitchCell;

  // Word input demo state
  String _currentWord = "";
  final List<String> _submittedWords = [];

  String _getGameId() {
    switch (widget.gameName) {
      case 'Cave (Corral)': return 'cave';
      case 'Yin-Yang': return 'yinyang';
      case 'Schrödinger-Cell': return 'schrodinger_cell';
      case 'Ripple Effect': return 'ripple_effect';
      case 'Sandwich Sudoku': return 'sandwich_sudoku';
      case 'Thermo Sudoku': return 'thermo_sudoku';
      case 'Arrow Sudoku': return 'arrow_sudoku';
      case 'Statue Park': return 'statue_park';
      case 'Cell Tower': return 'cell_tower';
      case 'Anagram Hive': return 'anagram_hive';
      case 'Static Minesweeper': return 'static_minesweeper';
      default: return widget.gameName.toLowerCase().replaceAll(' ', '_');
    }
  }

  LogicGridLevel _getCurrentLevelData() {
    final gameId = _getGameId();
    final levels = kLogicGridLevels[gameId];
    if (levels == null || _currentLevel >= levels.length) {
      // Fallback
      return const LogicGridLevel(
        initialGrid: [],
        rowCounts: [0, 0, 0, 0],
        colCounts: [0, 0, 0, 0],
        solution: null,
        instruction: "Deduce the grid layout to solve.",
      );
    }
    return levels[_currentLevel];
  }

  @override
  void initState() {
    super.initState();
    _loadLevel();
  }

  void _loadLevel() {
    final lvl = _getCurrentLevelData();
    setState(() {
      _isSuccess = false;
      _currentWord = "";
      _submittedWords.clear();
      _stitches = [];
      _selectedStitchCell = null;

      // Initialize grids from initialGrid or defaults
      _gridInt = List.filled(16, 0);
      _gridBool = List.filled(16, false);
      _shadingState = List.filled(16, 0);
      _objectState = List.filled(16, 0);

      if (widget.uiType == 'latin_square' && lvl.initialGrid.isNotEmpty) {
        for (int i = 0; i < 16 && i < lvl.initialGrid.length; i++) {
          if (lvl.initialGrid[i] is int) {
            _gridInt[i] = lvl.initialGrid[i] as int;
          }
        }
      }

      if (widget.uiType == 'object' && lvl.initialGrid.isNotEmpty) {
        for (int i = 0; i < 16 && i < lvl.initialGrid.length; i++) {
          if (lvl.initialGrid[i] is int) {
            _objectState[i] = lvl.initialGrid[i] as int;
          }
        }
      }

      if (widget.uiType == 'yinyang' && lvl.initialGrid.isNotEmpty) {
        for (int i = 0; i < 16 && i < lvl.initialGrid.length; i++) {
          if (lvl.initialGrid[i] is int) {
            _gridInt[i] = lvl.initialGrid[i] as int;
          }
        }
      }
    });
  }

  void _nextLevel() {
    if (_currentLevel < 4) {
      setState(() {
        _currentLevel++;
        _loadLevel();
      });
    } else {
      Navigator.pop(context);
    }
  }

  void _checkSolution() {
    final lvl = _getCurrentLevelData();
    bool correct = false;

    if (widget.uiType == 'shading') {
      if (lvl.solution is List) {
        final solList = lvl.solution as List;
        correct = true;
        for (int i = 0; i < 16; i++) {
          // Player's shading state 1 is shaded, others are not
          final playerShaded = _shadingState[i] == 1 ? 1 : 0;
          final solVal = solList[i] == 1 ? 1 : 0;
          if (playerShaded != solVal) {
            correct = false;
            break;
          }
        }
      }
    } else if (widget.uiType == 'yinyang') {
      if (lvl.solution is List) {
        final solList = lvl.solution as List;
        correct = true;
        for (int i = 0; i < 16; i++) {
          if (_gridInt[i] != solList[i]) {
            correct = false;
            break;
          }
        }
      }
    } else if (widget.uiType == 'slant') {
      if (lvl.solution is List) {
        final solList = lvl.solution as List;
        correct = true;
        for (int i = 0; i < 16; i++) {
          if (_gridInt[i] != solList[i]) {
            correct = false;
            break;
          }
        }
      }
    } else if (widget.uiType == 'stitches') {
      if (lvl.solution is List) {
        final solList = lvl.solution as List;
        Set<String> solSet = {};
        for (var pair in solList) {
          if (pair is List && pair.length == 2) {
            int a = pair[0] as int;
            int b = pair[1] as int;
            solSet.add(a < b ? "$a-$b" : "$b-$a");
          }
        }
        Set<String> playerSet = {};
        for (var pair in _stitches) {
          int a = pair[0];
          int b = pair[1];
          playerSet.add(a < b ? "$a-$b" : "$b-$a");
        }
        correct = solSet.length == playerSet.length && solSet.containsAll(playerSet);
      }
    } else if (widget.uiType == 'latin_square') {
      if (lvl.solution is List) {
        final solList = lvl.solution as List;
        correct = true;
        for (int i = 0; i < 16; i++) {
          if (_gridInt[i] != solList[i]) {
            correct = false;
            break;
          }
        }
      }
    } else if (widget.uiType == 'object') {
      if (lvl.solution is List) {
        final solList = lvl.solution as List;
        correct = true;
        for (int i = 0; i < 16; i++) {
          if (_objectState[i] != solList[i]) {
            correct = false;
            break;
          }
        }
      }
    } else if (widget.uiType == 'region') {
      if (lvl.solution is List) {
        final solList = lvl.solution as List;
        correct = true;
        for (int i = 0; i < 16; i++) {
          if (_gridInt[i] != solList[i]) {
            correct = false;
            break;
          }
        }
      }
    } else if (widget.uiType == 'loop') {
      if (lvl.solution is List) {
        final solList = lvl.solution as List;
        correct = true;
        for (int i = 0; i < 16; i++) {
          final playerVal = _gridBool[i] ? 1 : 0;
          if (playerVal != solList[i]) {
            correct = false;
            break;
          }
        }
      }
    } else if (widget.uiType == 'word') {
      if (lvl.solution is String) {
        final solStr = lvl.solution as String;
        correct = _currentWord.toUpperCase() == solStr.toUpperCase() ||
            _submittedWords.any((w) => w.toUpperCase() == solStr.toUpperCase());
      }
    }

    if (correct) {
      setState(() {
        _isSuccess = true;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.uiType == 'word'
                ? 'Incorrect word or formula! Try again.'
                : 'Solution is not correct yet! Check clues and patterns.',
          ),
          backgroundColor: AppTheme.roseGold,
        ),
      );
    }
  }

  void _showHint() {
    final lvl = _getCurrentLevelData();
    bool placed = false;

    if (widget.uiType == 'shading' && lvl.solution is List) {
      final solList = lvl.solution as List;
      for (int i = 0; i < 16; i++) {
        final playerShaded = _shadingState[i] == 1 ? 1 : 0;
        final solVal = solList[i] == 1 ? 1 : 0;
        if (playerShaded != solVal) {
          setState(() {
            _shadingState[i] = solVal == 1 ? 1 : 0;
          });
          placed = true;
          break;
        }
      }
    } else if (widget.uiType == 'yinyang' && lvl.solution is List) {
      final solList = lvl.solution as List;
      for (int i = 0; i < 16; i++) {
        if (_gridInt[i] != solList[i]) {
          setState(() {
            _gridInt[i] = solList[i] as int;
          });
          placed = true;
          break;
        }
      }
    } else if (widget.uiType == 'slant' && lvl.solution is List) {
      final solList = lvl.solution as List;
      for (int i = 0; i < 16; i++) {
        if (_gridInt[i] != solList[i]) {
          setState(() {
            _gridInt[i] = solList[i] as int;
          });
          placed = true;
          break;
        }
      }
    } else if (widget.uiType == 'stitches' && lvl.solution is List) {
      final solList = lvl.solution as List;
      Set<String> playerSet = {};
      for (var pair in _stitches) {
        int a = pair[0];
        int b = pair[1];
        playerSet.add(a < b ? "$a-$b" : "$b-$a");
      }
      for (var pair in solList) {
        if (pair is List && pair.length == 2) {
          int a = pair[0] as int;
          int b = pair[1] as int;
          String key = a < b ? "$a-$b" : "$b-$a";
          if (!playerSet.contains(key)) {
            setState(() {
              _stitches.add([a, b]);
            });
            placed = true;
            break;
          }
        }
      }
    } else if (widget.uiType == 'latin_square' && lvl.solution is List) {
      final solList = lvl.solution as List;
      for (int i = 0; i < 16; i++) {
        if (_gridInt[i] != solList[i]) {
          setState(() {
            _gridInt[i] = solList[i];
          });
          placed = true;
          break;
        }
      }
    } else if (widget.uiType == 'object' && lvl.solution is List) {
      final solList = lvl.solution as List;
      for (int i = 0; i < 16; i++) {
        if (_objectState[i] != solList[i]) {
          setState(() {
            _objectState[i] = solList[i];
          });
          placed = true;
          break;
        }
      }
    } else if (widget.uiType == 'region' && lvl.solution is List) {
      final solList = lvl.solution as List;
      for (int i = 0; i < 16; i++) {
        if (_gridInt[i] != solList[i]) {
          setState(() {
            _gridInt[i] = solList[i];
          });
          placed = true;
          break;
        }
      }
    } else if (widget.uiType == 'loop' && lvl.solution is List) {
      final solList = lvl.solution as List;
      for (int i = 0; i < 16; i++) {
        final playerVal = _gridBool[i] ? 1 : 0;
        if (playerVal != solList[i]) {
          setState(() {
            _gridBool[i] = solList[i] == 1;
          });
          placed = true;
          break;
        }
      }
    } else if (widget.uiType == 'word' && lvl.solution is String) {
      final solStr = lvl.solution as String;
      if (_currentWord.toUpperCase() != solStr.toUpperCase()) {
        setState(() {
          _currentWord = solStr;
        });
        placed = true;
      }
    }

    if (placed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hint placed!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Board matches correct solution!')),
      );
    }
  }

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.bgCard,
        title: Text(
          '${widget.gameName} Rules',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary),
        ),
        content: Text(
          widget.description,
          style: GoogleFonts.outfit(color: context.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Got it',
              style: GoogleFonts.outfit(color: AppTheme.dustyMauve, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoBoard(BuildContext context, LogicGridLevel lvl) {
    switch (widget.uiType) {
      case 'shading':
        return Column(
          children: [
            if (widget.gameName != 'Tapa' && widget.gameName != 'LITS' && widget.gameName != 'Norinori' &&
                widget.gameName != 'Yin-Yang' && widget.gameName != 'Kuromasu' && widget.gameName != 'Heyawake' &&
                widget.gameName != 'Nurimisaki' && widget.gameName != 'Kurotto' && widget.gameName != 'Mosaic' &&
                widget.gameName != 'Cave (Corral)' && widget.gameName != 'Slant' && widget.gameName != 'Stitches' &&
                widget.gameName != 'Aqre' && widget.gameName != 'Static Minesweeper' && widget.gameName != 'Nurimaze') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Row Counts: ',
                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: context.textSecondary),
                  ),
                  Text(
                    lvl.rowCounts.join(', '),
                    style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.dustyMauve),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Col Counts: ',
                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: context.textSecondary),
                  ),
                  Text(
                    lvl.colCounts.join(', '),
                    style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.dustyMauve),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: 220,
              height: 220,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 0,
                  crossAxisSpacing: 0,
                ),
                itemCount: 16,
                itemBuilder: (context, idx) {
                  final state = _shadingState[idx];
                  
                  // Region borders
                  Border? cellBorder;
                  if (lvl.regions != null && lvl.regions!.length == 16) {
                    final currentRegion = lvl.regions![idx];
                    final double thickWidth = 2.5;
                    final double thinWidth = 0.5;
                    final Color borderColor = context.textPrimary;
                    final Color thinColor = context.textMuted.withAlpha(40);

                    final hasTop = idx < 4 || lvl.regions![idx - 4] != currentRegion;
                    final hasBottom = idx >= 12 || lvl.regions![idx + 4] != currentRegion;
                    final hasLeft = idx % 4 == 0 || lvl.regions![idx - 1] != currentRegion;
                    final hasRight = idx % 4 == 3 || lvl.regions![idx + 1] != currentRegion;

                    cellBorder = Border(
                      top: BorderSide(color: hasTop ? borderColor : thinColor, width: hasTop ? thickWidth : thinWidth),
                      bottom: BorderSide(color: hasBottom ? borderColor : thinColor, width: hasBottom ? thickWidth : thinWidth),
                      left: BorderSide(color: hasLeft ? borderColor : thinColor, width: hasLeft ? thickWidth : thinWidth),
                      right: BorderSide(color: hasRight ? borderColor : thinColor, width: hasRight ? thickWidth : thinWidth),
                    );
                  } else {
                    cellBorder = Border.all(color: context.textMuted.withAlpha(40));
                  }

                  // Room Clue
                  bool isRoomClueCell = false;
                  String roomClueText = "";
                  if (lvl.regions != null && lvl.regionClues != null) {
                    final regionId = lvl.regions![idx];
                    final regionIndices = [
                      for (int i = 0; i < 16; i++)
                        if (lvl.regions![i] == regionId) i
                    ];
                    if (regionIndices.isNotEmpty && regionIndices.first == idx) {
                      if (lvl.regionClues!.containsKey(regionId)) {
                        isRoomClueCell = true;
                        roomClueText = lvl.regionClues![regionId]!;
                      }
                    }
                  }

                  // Check if cell is a locked clue
                  final hasClue = lvl.initialGrid.isNotEmpty && idx < lvl.initialGrid.length &&
                      lvl.initialGrid[idx] != 0 && lvl.initialGrid[idx] != "";
                  final isLocked = hasClue && widget.gameName != 'Mosaic';

                  Color cellBg = isLocked ? context.bgCard : context.bgSurface;
                  Widget? child;

                  if (state == 1) {
                    cellBg = AppTheme.dustyMauve;
                  } else if (state == 2) {
                    child = Icon(Icons.close_rounded, size: 16, color: context.textMuted);
                  }

                  // Specific game cell contents
                  if (hasClue) {
                    final clueVal = lvl.initialGrid[idx];
                    if (widget.gameName == 'Tapa') {
                      child = Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: context.bgSurface,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.dustyMauve.withAlpha(80)),
                        ),
                        child: Center(
                          child: Text(
                            clueVal.toString(),
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: context.textPrimary,
                            ),
                          ),
                        ),
                      );
                    } else if (widget.gameName == 'Kuromasu') {
                      child = Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: context.textPrimary, width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            clueVal.toString(),
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: context.textPrimary,
                            ),
                          ),
                        ),
                      );
                    } else if (widget.gameName == 'Nurimisaki' || widget.gameName == 'Kurotto') {
                      child = Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.dustyMauve, width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            clueVal.toString(),
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.dustyMauve,
                            ),
                          ),
                        ),
                      );
                    } else if (widget.gameName == 'Mosaic') {
                      child = Center(
                        child: Text(
                          clueVal.toString(),
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: state == 1 ? Colors.white : context.textPrimary,
                          ),
                        ),
                      );
                    } else if (widget.gameName == 'Cave (Corral)') {
                      child = Center(
                        child: Text(
                          clueVal.toString(),
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                        ),
                      );
                    } else if (widget.gameName == 'Static Minesweeper') {
                      child = Center(
                        child: Text(
                          clueVal.toString(),
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: clueVal == 1 ? Colors.blue : (clueVal == 2 ? Colors.green : Colors.red),
                          ),
                        ),
                      );
                    } else if (widget.gameName == 'Nurimaze') {
                      if (clueVal == 'S') {
                        child = Text('S', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16));
                      } else if (clueVal == 'G') {
                        child = Text('G', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16));
                      } else if (clueVal == 'C') {
                        child = Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: context.textMuted)),
                        );
                      } else if (clueVal == 'T') {
                        cellBg = AppTheme.dustyMauve;
                        child = const Icon(Icons.change_history, size: 12, color: Colors.white);
                      }
                    }
                  }

                  return GestureDetector(
                    onTap: isLocked ? null : () {
                      setState(() {
                        _shadingState[idx] = (_shadingState[idx] + 1) % 3;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: cellBg,
                        border: cellBorder,
                      ),
                      child: Stack(
                        children: [
                          if (isRoomClueCell)
                            Positioned(
                              top: 2,
                              left: 2,
                              child: Text(
                                roomClueText,
                                style: GoogleFonts.outfit(fontSize: 8, color: context.textSecondary, fontWeight: FontWeight.bold),
                              ),
                            ),
                          Center(child: child),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      case 'yinyang':
        return SizedBox(
          width: 220,
          height: 220,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: 16,
            itemBuilder: (context, idx) {
              final val = _gridInt[idx];
              final isGiven = lvl.initialGrid.isNotEmpty && idx < lvl.initialGrid.length && lvl.initialGrid[idx] != 0;

              Widget? circle;
              if (val == 1) {
                circle = Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.textPrimary,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withAlpha(80), blurRadius: 2, offset: const Offset(1, 1))
                    ],
                  ),
                );
              } else if (val == 2) {
                circle = Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: context.textPrimary, width: 2),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withAlpha(50), blurRadius: 2, offset: const Offset(1, 1))
                    ],
                  ),
                );
              }

              return GestureDetector(
                onTap: isGiven ? null : () {
                  setState(() {
                    _gridInt[idx] = (_gridInt[idx] + 1) % 3;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: context.bgSurface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: context.textMuted.withAlpha(40)),
                  ),
                  child: Center(child: circle),
                ),
              );
            },
          ),
        );
      case 'slant':
        return LayoutBuilder(
          builder: (context, constraints) {
            final double boardSize = 220.0;
            final double cellWidth = boardSize / 4;
            
            return SizedBox(
              width: boardSize,
              height: boardSize,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 0,
                      crossAxisSpacing: 0,
                    ),
                    itemCount: 16,
                    itemBuilder: (context, idx) {
                      final val = _gridInt[idx];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _gridInt[idx] = (_gridInt[idx] + 1) % 3;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: context.bgSurface,
                            border: Border.all(color: context.textMuted.withAlpha(40), width: 0.5),
                          ),
                          child: CustomPaint(
                            painter: SlantPainter(val, AppTheme.dustyMauve),
                          ),
                        ),
                      );
                    },
                  ),
                  if (lvl.vertexClues != null)
                    ...lvl.vertexClues!.entries.map((entry) {
                      final vIdx = entry.key;
                      final clue = entry.value;
                      final vRow = vIdx ~/ 5;
                      final vCol = vIdx % 5;
                      
                      final x = vCol * cellWidth;
                      final y = vRow * cellWidth;
                      
                      return Positioned(
                        left: x - 9,
                        top: y - 9,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: context.bgCard,
                            shape: BoxShape.circle,
                            border: Border.all(color: context.textPrimary, width: 1.5),
                          ),
                          child: Center(
                            child: Text(
                              clue.toString(),
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: context.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            );
          }
        );
      case 'stitches':
        return LayoutBuilder(
          builder: (context, constraints) {
            final double boardSize = 220.0;
            final double cellWidth = boardSize / 4;
            
            return SizedBox(
              width: boardSize,
              height: boardSize,
              child: Stack(
                children: [
                  GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 0,
                      crossAxisSpacing: 0,
                    ),
                    itemCount: 16,
                    itemBuilder: (context, idx) {
                      Border? cellBorder;
                      if (lvl.regions != null && lvl.regions!.length == 16) {
                        final currentRegion = lvl.regions![idx];
                        final double thickWidth = 2.5;
                        final double thinWidth = 0.5;
                        final Color borderColor = context.textPrimary;
                        final Color thinColor = context.textMuted.withAlpha(40);

                        final hasTop = idx < 4 || lvl.regions![idx - 4] != currentRegion;
                        final hasBottom = idx >= 12 || lvl.regions![idx + 4] != currentRegion;
                        final hasLeft = idx % 4 == 0 || lvl.regions![idx - 1] != currentRegion;
                        final hasRight = idx % 4 == 3 || lvl.regions![idx + 1] != currentRegion;

                        cellBorder = Border(
                          top: BorderSide(color: hasTop ? borderColor : thinColor, width: hasTop ? thickWidth : thinWidth),
                          bottom: BorderSide(color: hasBottom ? borderColor : thinColor, width: hasBottom ? thickWidth : thinWidth),
                          left: BorderSide(color: hasLeft ? borderColor : thinColor, width: hasLeft ? thickWidth : thinWidth),
                          right: BorderSide(color: hasRight ? borderColor : thinColor, width: hasRight ? thickWidth : thinWidth),
                        );
                      } else {
                        cellBorder = Border.all(color: context.textMuted.withAlpha(40));
                      }
                      
                      final isSelected = _selectedStitchCell == idx;
                      
                      return GestureDetector(
                        onTap: () {
                          if (_selectedStitchCell == null) {
                            setState(() {
                              _selectedStitchCell = idx;
                            });
                          } else if (_selectedStitchCell == idx) {
                            setState(() {
                              _selectedStitchCell = null;
                            });
                          } else {
                            final a = _selectedStitchCell!;
                            final b = idx;
                            final rowA = a ~/ 4;
                            final colA = a % 4;
                            final rowB = b ~/ 4;
                            final colB = b % 4;
                            final isAdjacent = (rowA - rowB).abs() + (colA - colB).abs() == 1;
                            final diffRegion = lvl.regions != null && lvl.regions![a] != lvl.regions![b];
                            
                            if (isAdjacent && diffRegion) {
                              setState(() {
                                final existingIdx = _stitches.indexWhere((pair) => 
                                  (pair[0] == a && pair[1] == b) || (pair[0] == b && pair[1] == a));
                                if (existingIdx != -1) {
                                  _stitches.removeAt(existingIdx);
                                } else {
                                  _stitches.add([a, b]);
                                }
                                _selectedStitchCell = null;
                              });
                            } else {
                              setState(() {
                                _selectedStitchCell = idx;
                              });
                            }
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.green.withAlpha(40) : context.bgSurface,
                            border: cellBorder,
                          ),
                          child: isSelected 
                            ? const Center(child: Icon(Icons.circle, size: 8, color: Colors.green))
                            : null,
                        ),
                      );
                    },
                  ),
                  IgnorePointer(
                    child: CustomPaint(
                      size: Size(boardSize, boardSize),
                      painter: StitchPainter(_stitches, cellWidth, AppTheme.dustyMauve),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      case 'latin_square':
        return Column(
          children: [
            SizedBox(
              width: 220,
              height: 220,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: 16,
                itemBuilder: (context, idx) {
                  final val = _gridInt[idx];
                  final isGiven = lvl.initialGrid.isNotEmpty && lvl.initialGrid[idx] != 0;
                  return GestureDetector(
                    onTap: isGiven ? null : () {
                      setState(() {
                        _gridInt[idx] = (_gridInt[idx] + 1) % 5;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isGiven ? context.bgCard : context.bgSurface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: context.textMuted.withAlpha(40)),
                      ),
                      child: Center(
                        child: Text(
                          val == 0 ? '' : '$val',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isGiven ? context.textSecondary : AppTheme.dustyMauve,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      case 'object':
        return Column(
          children: [
            SizedBox(
              width: 220,
              height: 220,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: 16,
                itemBuilder: (context, idx) {
                  final state = _objectState[idx];
                  final isGiven = lvl.initialGrid.isNotEmpty && lvl.initialGrid[idx] == 1; // Tree anchor
                  Widget? child;
                  if (state == 1) {
                    child = const Icon(Icons.park, color: Colors.green, size: 24);
                  } else if (state == 2) {
                    child = const Icon(Icons.home, color: Colors.amber, size: 24);
                  } else if (state == 3) {
                    child = const Icon(Icons.water_drop, color: Colors.blue, size: 24);
                  }
                  return GestureDetector(
                    onTap: isGiven ? null : () {
                      setState(() {
                        _objectState[idx] = (_objectState[idx] + 1) % 4;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isGiven ? context.bgCard : context.bgSurface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: context.textMuted.withAlpha(40)),
                      ),
                      child: Center(child: child),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      case 'region':
        return Column(
          children: [
            SizedBox(
              width: 220,
              height: 220,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: 16,
                itemBuilder: (context, idx) {
                  final state = _gridInt[idx];
                  final colors = [
                    context.bgSurface,
                    AppTheme.dustyMauve.withAlpha(50),
                    AppTheme.roseGold.withAlpha(50),
                    AppTheme.slateBlue.withAlpha(50),
                  ];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _gridInt[idx] = (_gridInt[idx] + 1) % 4;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: colors[state],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: context.textMuted.withAlpha(80)),
                      ),
                      child: Center(
                        child: Text(
                          'R${state + 1}',
                          style: GoogleFonts.outfit(fontSize: 10, color: context.textSecondary),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      case 'loop':
        return Column(
          children: [
            SizedBox(
              width: 220,
              height: 220,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: 16,
                itemBuilder: (context, idx) {
                  final hasLine = _gridBool[idx];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _gridBool[idx] = !_gridBool[idx];
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.bgSurface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: context.textMuted.withAlpha(40)),
                      ),
                      child: Center(
                        child: Container(
                          width: hasLine ? 16 : 8,
                          height: hasLine ? 16 : 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hasLine ? AppTheme.dustyMauve : context.textMuted.withAlpha(80),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      case 'word':
      default:
        final List<dynamic> initialLetters = lvl.initialGrid;
        return Column(
          children: [
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.bgSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _currentWord.isEmpty ? 'Tap letters below...' : _currentWord,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.dustyMauve,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: initialLetters.map((l) {
                final strVal = l.toString();
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentWord += strVal;
                    });
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: context.bgCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.textMuted.withAlpha(40)),
                    ),
                    child: Center(
                      child: Text(
                        strVal,
                        style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _currentWord = "";
                    });
                  },
                  child: const Text('Clear'),
                ),
                TextButton(
                  onPressed: () {
                    if (_currentWord.isNotEmpty) {
                      setState(() {
                        _submittedWords.add(_currentWord);
                        _currentWord = "";
                      });
                    }
                  },
                  child: const Text('Add Word'),
                ),
              ],
            ),
            if (_submittedWords.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Submitted: ${_submittedWords.join(", ")}',
                style: GoogleFonts.outfit(fontSize: 12, color: context.textMuted),
              ),
            ],
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lvl = _getCurrentLevelData();
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text(widget.gameName, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: AppTheme.dustyMauve),
            tooltip: 'Instructions',
            onPressed: _showInstructions,
          ),
          IconButton(
            icon: const Icon(Icons.lightbulb_outline, color: AppTheme.dustyMauve),
            tooltip: 'Hint',
            onPressed: _showHint,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Level ${_currentLevel + 1}/5',
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
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.dustyMauve.withAlpha(20), context.bgCard],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.dustyMauve.withAlpha(30)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.dustyMauve.withAlpha(40),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.category.toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.dustyMauve,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.gameName,
                        style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.description,
                        style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Instruction Bar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.textMuted.withAlpha(30)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.tips_and_updates, size: 20, color: AppTheme.warmAmber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          lvl.instruction,
                          style: GoogleFonts.outfit(fontSize: 13, color: context.textPrimary, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Demo Board Header
                Text(
                  'Interactive Sandbox',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.bgCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.textMuted.withAlpha(30)),
                  ),
                  child: _buildDemoBoard(context, lvl),
                ),
                const SizedBox(height: 24),

                // Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.bgCard,
                        foregroundColor: context.textPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: _loadLevel,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset'),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.dustyMauve,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: _checkSolution,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Check'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Specification & Rules Card
                Text(
                  'Rules & Specification',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: context.bgCard,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline, size: 20, color: AppTheme.dustyMauve),
                          const SizedBox(width: 8),
                          Text(
                            'General Game Rules',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '1. Follow logic constraints provided on grid edges or clue cells.\n'
                        '2. Avoid contradictions: every rule is critical and leads to a single unique solution.\n'
                        '3. Deduced moves only: pure logic is sufficient, guessing is not required.',
                        style: GoogleFonts.outfit(fontSize: 13, height: 1.5, color: context.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isSuccess)
            Container(
              color: Colors.black.withAlpha(150),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: context.bgCard,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.emoji_events, color: Colors.amber, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        'Level ${_currentLevel + 1} Cleared!',
                        style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.dustyMauve,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _nextLevel,
                        child: Text(_currentLevel < 4 ? 'Next Level' : 'Finish'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SlantPainter extends CustomPainter {
  final int type; // 0: empty, 1: /, 2: \
  final Color color;
  SlantPainter(this.type, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (type == 0) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    if (type == 1) {
      canvas.drawLine(Offset(0, size.height), Offset(size.width, 0), paint);
    } else if (type == 2) {
      canvas.drawLine(Offset(0, 0), Offset(size.width, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class StitchPainter extends CustomPainter {
  final List<List<int>> stitches;
  final double cellWidth;
  final Color color;
  StitchPainter(this.stitches, this.cellWidth, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    final knotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (final stitch in stitches) {
      final a = stitch[0];
      final b = stitch[1];
      final rowA = a ~/ 4;
      final colA = a % 4;
      final rowB = b ~/ 4;
      final colB = b % 4;

      final xA = (colA + 0.5) * cellWidth;
      final yA = (rowA + 0.5) * cellWidth;
      final xB = (colB + 0.5) * cellWidth;
      final yB = (rowB + 0.5) * cellWidth;

      canvas.drawLine(Offset(xA, yA), Offset(xB, yB), paint);
      canvas.drawCircle(Offset(xA, yA), 4.5, knotPaint);
      canvas.drawCircle(Offset(xB, yB), 4.5, knotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
