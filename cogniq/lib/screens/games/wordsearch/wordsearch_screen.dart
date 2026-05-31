import'dart:math';
import'package:flutter/material.dart';
import'package:google_fonts/google_fonts.dart';
import'package:shared_preferences/shared_preferences.dart';
import'../../../utils/rules_helper.dart';
import'../../../theme/app_theme.dart';
import'../../../utils/hint_manager.dart';

class WordSearchLevel {
  final int gridSize;
  final Set<String> targetWords;
  const WordSearchLevel({required this.gridSize, required this.targetWords});
}

const List<WordSearchLevel> _kLevels = [
  // Easy (6x6)
  WordSearchLevel(gridSize: 6, targetWords: {'CAT','DOG','COW'}),
  WordSearchLevel(gridSize: 6, targetWords: {'PIG','HEN','BLUE','RED'}),
  WordSearchLevel(gridSize: 6, targetWords: {'FOX','BAT','RAT','SUN'}),
  WordSearchLevel(gridSize: 6, targetWords: {'TEA','MILK','COLD','HOT'}),
  // Medium (8x8)
  WordSearchLevel(gridSize: 8, targetWords: {'LION','BEAR','DEER','WOLF','FROG'}),
  WordSearchLevel(gridSize: 8, targetWords: {'APPLE','PEAR','GRAPE','LIME','KIWI'}),
  WordSearchLevel(gridSize: 8, targetWords: {'GREEN','BLACK','WHITE','BROWN','PINK'}),
  WordSearchLevel(gridSize: 8, targetWords: {'PIANO','FLUTE','DRUMS','ORGAN','HARP'}),
  // Hard (10x10)
  WordSearchLevel(gridSize: 10, targetWords: {'PYTHON','KOTLIN','FLUTTER','SWIFT','JAVA','RUST'}),
  WordSearchLevel(gridSize: 10, targetWords: {'SPIDER','MONKEY','RABBIT','TURTLE','DONKEY','COYOTE'}),
  WordSearchLevel(gridSize: 10, targetWords: {'JUPITER','SATURN','NEPTUNE','URANUS','MARS','EARTH'}),
  WordSearchLevel(gridSize: 10, targetWords: {'GUITAR','VIOLIN','TRUMPET','CLARINET','CELLO'}),
  // Very Hard (12x12)
  WordSearchLevel(gridSize: 12, targetWords: {'AMERICA','CANADA','MEXICO','BRAZIL','FRANCE','GERMANY'}),
  WordSearchLevel(gridSize: 12, targetWords: {'BASEBALL','SOCCER','TENNIS','HOCKEY','RUGBY','CRICKET'}),
  WordSearchLevel(gridSize: 12, targetWords: {'CHOCOLATE','VANILLA','CARAMEL','BERRY','MINT','HONEY'}),
  WordSearchLevel(gridSize: 6, targetWords: {'RED','BLUE','PINK','GRAY'}),
  WordSearchLevel(gridSize: 6, targetWords: {'DOG','CAT','PIG','COW'}),
  WordSearchLevel(gridSize: 6, targetWords: {'OAK','PINE','FIR','ELM'}),
  WordSearchLevel(gridSize: 6, targetWords: {'SUN','STAR','MOON','SKY'}),
  WordSearchLevel(gridSize: 6, targetWords: {'CAR','BUS','VAN','CAB'}),
  WordSearchLevel(gridSize: 6, targetWords: {'HAT','COAT','VEST','CAP'}),
  WordSearchLevel(gridSize: 8, targetWords: {'SHARK','WHALE','SEAL','FISH','CRAB'}),
  WordSearchLevel(gridSize: 8, targetWords: {'ROSE','TULIP','DAISY','LILY','FERN'}),
  WordSearchLevel(gridSize: 8, targetWords: {'BREAD','CAKE','PIE','TART','BUN'}),
  WordSearchLevel(gridSize: 8, targetWords: {'RAIN','SNOW','WIND','MIST','HAIL'}),
  WordSearchLevel(gridSize: 8, targetWords: {'MILK','SODA','JUICE','COLA','TEA'}),
  WordSearchLevel(gridSize: 8, targetWords: {'DESK','CHAIR','TABLE','LAMP','BED'}),
  WordSearchLevel(gridSize: 10, targetWords: {'BANANA','ORANGE','CHERRY','PEACH','MELON','MANGO'}),
  WordSearchLevel(gridSize: 10, targetWords: {'COFFEE','MATCHA','MOCHA','LATTE','COCOA','CHAI'}),
  WordSearchLevel(gridSize: 10, targetWords: {'DOCTOR','NURSE','PILOT','CHEF','ACTOR','WRITER'}),
  WordSearchLevel(gridSize: 10, targetWords: {'LONDON','PARIS','TOKYO','ROME','BERLIN','MADRID'}),
  WordSearchLevel(gridSize: 10, targetWords: {'COPPER','SILVER','BRONZE','GOLD','IRON','NICKEL'}),
  WordSearchLevel(gridSize: 10, targetWords: {'WINTER','SPRING','SUMMER','AUTUMN','SEASON','CLIME'}),
  WordSearchLevel(gridSize: 12, targetWords: {'ASTRONOMY','PHYSICS','CHEMISTRY','BIOLOGY','GEOLOGY'}),
  WordSearchLevel(gridSize: 12, targetWords: {'VIOLIN','TRUMPET','CLARINET','SAXOPHONE','TROMBONE'}),
  WordSearchLevel(gridSize: 12, targetWords: {'ELEPHANT','KANGAROO','CROCODILE','FLAMINGO','GIRAFFE'}),
  WordSearchLevel(gridSize: 12, targetWords: {'SPAGHETTI','MACARONI','LASAGNA','TORTELLINI','RAVIOLI'}),
  WordSearchLevel(gridSize: 12, targetWords: {'CARPENTER','ENGINEER','ARCHITECT','SCIENTIST','TEACHER'}),
  WordSearchLevel(gridSize: 12, targetWords: {'MARATHON','TRIATHLON','DECATHLON','GYMNASTICS','CYCLING'}),
  WordSearchLevel(gridSize: 12, targetWords: {'RAINFOREST','DESERT','TUNDRA','SAVANNA','GRASSLAND'}),
  WordSearchLevel(gridSize: 12, targetWords: {'SUBMARINE','HELICOPTER','SPACESHIP','LOCOMOTIVE','BICYCLE'}),
  WordSearchLevel(gridSize: 12, targetWords: {'AMETHYST','EMERALD','SAPPHIRE','TURQUOISE','DIAMOND'}),
  WordSearchLevel(gridSize: 12, targetWords: {'LAVENDER','ROSEMARY','CHAMOMILE','HIBISCUS','JASMINE'}),
  // 10 new levels
  WordSearchLevel(gridSize: 6, targetWords: {'PEN','CUP','KEY','BAG'}),
  WordSearchLevel(gridSize: 6, targetWords: {'RUN','HOP','JUMP','FLY'}),
  WordSearchLevel(gridSize: 6, targetWords: {'SUN','STAR','SKY','SEA'}),
  WordSearchLevel(gridSize: 8, targetWords: {'CLOVER','DAISY','LILY','ROSE','IVY'}),
  WordSearchLevel(gridSize: 8, targetWords: {'CHAIR','DESK','LAMP','BED','SOFA'}),
  WordSearchLevel(gridSize: 8, targetWords: {'SWEET','SOUR','SALTY','BITTER','SPICY'}),
  WordSearchLevel(gridSize: 10, targetWords: {'SPARROW','ROBIN','EAGLE','FALCON','HAWK','OWL'}),
  WordSearchLevel(gridSize: 10, targetWords: {'OCTOPUS','DOLPHIN','SHARK','WHALE','ORCA','SEAL'}),
  WordSearchLevel(gridSize: 10, targetWords: {'DIAMOND','RUBY','PEARL','JADE','OPAL','ONYX'}),
  WordSearchLevel(gridSize: 10, targetWords: {'ORANGE','YELLOW','PURPLE','INDIGO','VIOLET','BRONZE'}),
];

class WordSearchScreen extends StatefulWidget {
  const WordSearchScreen({super.key});
  @override
  State<WordSearchScreen> createState() => _WordSearchScreenState();
}

class _WordSearchScreenState extends State<WordSearchScreen> {
  int _levelIndex = 0;
  late WordSearchLevel _level;
  late List<List<String>> _grid;
  final List<(int, int)> _selection = [];
  final Set<String> _foundWords = {};
  final Set<(int, int)> _permanentHighlights = {};
  String _message ='';
  bool _won = false;
  final GlobalKey _gridKey = GlobalKey();

  int _hintCount = 0;

  @override
  void initState() {
    super.initState();
    // Default synchronous initialization to avoid LateInitializationError
    _level = _kLevels[0];
    _grid = List.generate(_level.gridSize, (_) => List.filled(_level.gridSize,''));
    _initLevel();
  }

  Future<void> _initLevel() async {
    _hintCount = await HintManager.getHints('wordsearch');
    final prefs = await SharedPreferences.getInstance();
    final savedLevel = prefs.getInt('level_wordsearch') ?? 0;
    if (mounted) {
      setState(() {
        _levelIndex = savedLevel % _kLevels.length;
        _loadLevel();
      });
    }
  }

  Future<void> _savePersistedLevel(int lvl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('level_wordsearch', lvl);
    final earned = await HintManager.onLevelCleared('wordsearch');
    final newCount = await HintManager.getHints('wordsearch');
    setState(() {
      _hintCount = newCount;
    });
    if (earned && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hint earned! (Total: $newCount)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: AppTheme.accentFor('wordsearch'),
        ),
      );
    }
  }

  List<(int, int)>? _findWordInGrid(String word) {
    final directions = const [
      (0, 1), (1, 0), (1, 1), (1, -1),
      (0, -1), (-1, 0), (-1, -1), (-1, 1)
    ];
    final size = _level.gridSize;
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        for (final dir in directions) {
          bool match = true;
          final tempCoords = <(int, int)>[];
          for (int i = 0; i < word.length; i++) {
            final currR = r + dir.$1 * i;
            final currC = c + dir.$2 * i;
            if (currR < 0 || currR >= size || currC < 0 || currC >= size) {
              match = false;
              break;
            }
            if (_grid[currR][currC] != word[i]) {
              match = false;
              break;
            }
            tempCoords.add((currR, currC));
          }
          if (match) {
            return tempCoords;
          }
        }
      }
    }
    return null;
  }

  Future<void> _useHint() async {
    if (_won || _hintCount <= 0) return;
    String? targetWord;
    for (final word in _level.targetWords) {
      if (!_foundWords.contains(word)) {
        targetWord = word;
        break;
      }
    }
    if (targetWord == null) return;

    final coords = _findWordInGrid(targetWord);
    if (coords == null) return;

    await HintManager.useHint('wordsearch');
    final newCount = await HintManager.getHints('wordsearch');

    setState(() {
      _hintCount = newCount;
      _foundWords.add(targetWord!);
      _permanentHighlights.addAll(coords);
      _message ='Found via hint:"$targetWord"';
      if (_foundWords.length == _level.targetWords.length) {
        _won = true;
        _savePersistedLevel(_levelIndex);
      }
    });
  }

  List<List<String>> _generateGrid(int size, Set<String> words) {
    final rand = Random();
    
    // Choose allowed directions based on difficulty (gridSize)
    List<(int, int)> directions;
    if (size <= 6) {
      // Easy: only horizontal forward, vertical forward
      directions = const [(0, 1), (1, 0)];
    } else if (size <= 8) {
      // Medium: horizontal, vertical, diagonal down-right, diagonal down-left
      directions = const [(0, 1), (1, 0), (1, 1), (1, -1)];
    } else {
      // Hard/Very Hard: all 8 directions
      directions = const [
        (0, 1), (1, 0), (1, 1), (1, -1),
        (0, -1), (-1, 0), (-1, -1), (-1, 1)
      ];
    }

    for (int attempt = 0; attempt < 50; attempt++) {
      final grid = List.generate(size, (_) => List.filled(size,''));
      bool success = true;

      for (final word in words) {
        bool wordPlaced = false;
        // Try random positions/directions
        for (int wAttempt = 0; wAttempt < 150; wAttempt++) {
          final dir = directions[rand.nextInt(directions.length)];
          final r = rand.nextInt(size);
          final c = rand.nextInt(size);

          // Check bounds
          final endR = r + dir.$1 * (word.length - 1);
          final endC = c + dir.$2 * (word.length - 1);
          if (endR < 0 || endR >= size || endC < 0 || endC >= size) continue;

          // Check overlap
          bool canPlace = true;
          for (int i = 0; i < word.length; i++) {
            final currR = r + dir.$1 * i;
            final currC = c + dir.$2 * i;
            final charAt = grid[currR][currC];
            if (charAt.isNotEmpty && charAt != word[i]) {
              canPlace = false;
              break;
            }
          }

          if (canPlace) {
            for (int i = 0; i < word.length; i++) {
              final currR = r + dir.$1 * i;
              final currC = c + dir.$2 * i;
              grid[currR][currC] = word[i];
            }
            wordPlaced = true;
            break;
          }
        }

        if (!wordPlaced) {
          success = false;
          break; // Try entire grid generation again
        }
      }

      if (success) {
        // Fill remaining spaces with random letters
        for (int r = 0; r < size; r++) {
          for (int c = 0; c < size; c++) {
            if (grid[r][c].isEmpty) {
              grid[r][c] = String.fromCharCode(65 + rand.nextInt(26)); //'A'-'Z'
            }
          }
        }
        return grid;
      }
    }

    // Fallback
    return List.generate(size, (_) => List.generate(size, (_) => String.fromCharCode(65 + rand.nextInt(26))));
  }

  void _loadLevel() {
    _level = _kLevels[_levelIndex % _kLevels.length];
    _grid = _generateGrid(_level.gridSize, _level.targetWords);
    _selection.clear();
    _foundWords.clear();
    _permanentHighlights.clear();
    _message ='';
    _won = false;
  }

  void _reset() => setState(() => _loadLevel());

  (int, int)? _cellAt(Offset global) {
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final local = box.globalToLocal(global);
    final size = box.size;
    final gridSize = _level.gridSize;
    final cw = size.width / gridSize;
    final ch = size.height / gridSize;
    final col = (local.dx / cw).floor();
    final row = (local.dy / ch).floor();
    if (row >= 0 && row < gridSize && col >= 0 && col < gridSize) {
      return (row, col);
    }
    return null;
  }

  void _addCellToSelection((int, int) pos) {
    if (_won) return;
    if (_selection.length >= 2 && _selection[_selection.length - 2] == pos) {
      setState(() {
        _selection.removeLast();
        _message ='';
      });
      return;
    }
    if (!_selection.contains(pos)) {
      setState(() {
        _selection.add(pos);
        _message ='';
      });
    }
  }

  void _clearSelection() {
    setState(() {
      _selection.clear();
    });
  }

  void _submitWord() {
    if (_won || _selection.isEmpty) return;
    
    // Construct word from selection
    final word = _selection.map((pos) => _grid[pos.$1][pos.$2]).join();
    final reverseWord = word.split('').reversed.join();
    
    if (_foundWords.contains(word) || _foundWords.contains(reverseWord)) {
      setState(() {
        _message ='Already found"$word"!';
        _selection.clear();
      });
      return;
    }

    if (_level.targetWords.contains(word)) {
      setState(() {
        _foundWords.add(word);
        _permanentHighlights.addAll(_selection);
        _selection.clear();
        _message ='Found"$word"!';
        
        if (_foundWords.length == _level.targetWords.length) {
          _won = true;
          _message ='All words found!';
          _savePersistedLevel(_levelIndex);
        }
      });
    } else if (_level.targetWords.contains(reverseWord)) {
      setState(() {
        _foundWords.add(reverseWord);
        _permanentHighlights.addAll(_selection);
        _selection.clear();
        _message ='Found"$reverseWord"!';
        
        if (_foundWords.length == _level.targetWords.length) {
          _won = true;
          _message ='All words found!';
          _savePersistedLevel(_levelIndex);
        }
      });
    } else {
      setState(() {
        _message ='"$word"is not a target word!';
        _selection.clear();
      });
    }
  }

  void _nextLevel() {
    setState(() {
      _levelIndex = (_levelIndex + 1) % _kLevels.length;
      _savePersistedLevel(_levelIndex);
      _loadLevel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = AppTheme.accentFor('wordsearch');
    final gridSize = _level.gridSize;
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        backgroundColor: context.bgDark,
        foregroundColor: context.textPrimary,
        title: Text('Word Search', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: context.textPrimary)),
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
            onPressed: () => RulesHelper.showRulesBottomSheet(context,'wordsearch','Word Search'),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
          child: Column(
            children: [
              Text(
'Drag over letters to select a word, then tap SUBMIT',
                style: GoogleFonts.outfit(color: context.textSecondary, fontSize: context.scale(13)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Target Words checklist
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _level.targetWords.map((word) {
                  final found = _foundWords.contains(word);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: found ? accentColor.withAlpha(40) : context.bgCard,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: found ? accentColor : context.textMuted.withAlpha(50),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      word,
                      style: GoogleFonts.outfit(
                        fontSize: context.scale(12),
                        fontWeight: FontWeight.bold,
                        color: found ? context.textPrimary : context.textMuted,
                        decoration: found ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              // Word Search Grid
              Center(
                child: GestureDetector(
                  onPanStart: (d) {
                    final pos = _cellAt(d.globalPosition);
                    if (pos != null) _addCellToSelection(pos);
                  },
                  onPanUpdate: (d) {
                    final pos = _cellAt(d.globalPosition);
                    if (pos != null) _addCellToSelection(pos);
                  },
                  child: Container(
                    key: _gridKey,
                    width: context.scale(280),
                    height: context.scale(280),
                    decoration: BoxDecoration(
                      color: context.bgCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.textMuted.withAlpha(100), width: 2),
                    ),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: gridSize * gridSize,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: gridSize,
                      ),
                      itemBuilder: (ctx, idx) {
                        final r = idx ~/ gridSize;
                        final c = idx % gridSize;
                        final letter = _grid[r][c];
                        final pos = (r, c);
                        final isSel = _selection.contains(pos);
                        final isPerm = _permanentHighlights.contains(pos);

                        return GestureDetector(
                          onTap: () => _addCellToSelection(pos),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSel
                                  ? accentColor.withAlpha(120)
                                  : isPerm
                                      ? accentColor.withAlpha(50)
                                      : Colors.transparent,
                              border: Border.all(
                                  color: context.textMuted.withAlpha(20),
                                  width: 0.5,
                                ),
                            ),
                            child: Center(
                              child: Text(
                                letter,
                                style: GoogleFonts.outfit(
                                  fontSize: context.scale(gridSize > 10 ? 12 : gridSize > 8 ? 14 : 16),
                                  fontWeight: FontWeight.bold,
                                  color: (isSel || isPerm) ? Colors.white : context.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_message.isNotEmpty)
                Text(
                  _message,
                  style: GoogleFonts.outfit(
                    color: _won ? accentColor : Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: context.scale(14),
                  ),
                ),
              const SizedBox(height: 16),
              // Action buttons
              if (!_won)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: _clearSelection,
                      child: Text('CLEAR', style: GoogleFonts.outfit(color: context.textSecondary, fontWeight: FontWeight.bold, fontSize: context.scale(14))),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      onPressed: _submitWord,
                      child: Text('SUBMIT', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: context.scale(14))),
                    ),
                  ],
                )
              else
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
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
