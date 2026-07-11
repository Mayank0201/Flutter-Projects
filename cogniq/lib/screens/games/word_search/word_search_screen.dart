import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cogniq/widgets/buy_hints_dialog.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import'../../../utils/rules_helper.dart';
import'../../../theme/app_theme.dart';
import'../../../utils/hint_manager.dart';
import'../../../utils/audio_manager.dart';
import '../../../widgets/auto_next_countdown.dart';
class WordSearchLevel {
  final int gridSize;
  final Set<String> targetWords;
  const WordSearchLevel({required this.gridSize, required this.targetWords});
}

const List<WordSearchLevel> _kLevels = [
  // Easy (6x6) -> 8x8
  WordSearchLevel(gridSize: 8, targetWords: {'AMERICA','CANADA','MEXICO','BRAZIL','FRANCE','GERMANY'}),
  WordSearchLevel(gridSize: 8, targetWords: {'BASEBALL','SOCCER','TENNIS','HOCKEY','RUGBY','CRICKET'}),
  WordSearchLevel(gridSize: 8, targetWords: {'SWEETS','VANILLA','CARAMEL','BERRY','MINT','HONEY'}),
  WordSearchLevel(gridSize: 8, targetWords: {'SCIENCE','PHYSICS','HISTORY','BIOLOGY','GEOLOGY'}),
  // Medium (8x8) -> 10x10
  WordSearchLevel(gridSize: 10, targetWords: {'PYTHON','KOTLIN','FLUTTER','SWIFT','JAVA','RUST'}),
  WordSearchLevel(gridSize: 10, targetWords: {'SPIDER','MONKEY','RABBIT','TURTLE','DONKEY','COYOTE'}),
  WordSearchLevel(gridSize: 10, targetWords: {'JUPITER','SATURN','NEPTUNE','URANUS','MARS','EARTH'}),
  WordSearchLevel(gridSize: 10, targetWords: {'GUITAR','VIOLIN','TRUMPET','CLARINET','CELLO'}),
  // Hard (10x10) -> 12x12
  WordSearchLevel(gridSize: 12, targetWords: {'LION','BEAR','DEER','WOLF','FROG'}),
  WordSearchLevel(gridSize: 12, targetWords: {'APPLE','PEAR','GRAPE','LIME','KIWI'}),
  WordSearchLevel(gridSize: 12, targetWords: {'GREEN','BLACK','WHITE','BROWN','PINK'}),
  WordSearchLevel(gridSize: 12, targetWords: {'PIANO','FLUTE','DRUMS','ORGAN','HARP'}),
  // Very Hard (12x12) -> 14x14
  WordSearchLevel(gridSize: 14, targetWords: {'CAT','DOG','COW'}),
  WordSearchLevel(gridSize: 14, targetWords: {'PIG','HEN','BLUE','RED'}),
  WordSearchLevel(gridSize: 14, targetWords: {'FOX','BAT','RAT','SUN'}),
  WordSearchLevel(gridSize: 8, targetWords: {'VIOLIN','TRUMPET','CLARINET','OBOE','TROMBONE'}),
  WordSearchLevel(gridSize: 8, targetWords: {'ELEPHANT','KANGAROO','LEOPARD','FLAMINGO','GIRAFFE'}),
  WordSearchLevel(gridSize: 8, targetWords: {'NOODLES','MACARONI','LASAGNA','GNOCCHI','RAVIOLI'}),
  WordSearchLevel(gridSize: 8, targetWords: {'BUILDER','ENGINEER','DESIGNER','CHEMIST','TEACHER'}),
  WordSearchLevel(gridSize: 8, targetWords: {'MARATHON','RUNNING','JUMPING','SPORTS','CYCLING'}),
  WordSearchLevel(gridSize: 8, targetWords: {'JUNGLE','DESERT','TUNDRA','SAVANNA','MEADOW'}),
  WordSearchLevel(gridSize: 10, targetWords: {'BANANA','ORANGE','CHERRY','PEACH','MELON','MANGO'}),
  WordSearchLevel(gridSize: 10, targetWords: {'COFFEE','MATCHA','MOCHA','LATTE','COCOA','CHAI'}),
  WordSearchLevel(gridSize: 10, targetWords: {'DOCTOR','NURSE','PILOT','CHEF','ACTOR','WRITER'}),
  WordSearchLevel(gridSize: 10, targetWords: {'LONDON','PARIS','TOKYO','ROME','BERLIN','MADRID'}),
  WordSearchLevel(gridSize: 10, targetWords: {'COPPER','SILVER','BRONZE','GOLD','IRON','NICKEL'}),
  WordSearchLevel(gridSize: 10, targetWords: {'WINTER','SPRING','SUMMER','AUTUMN','SEASON','CLIME'}),
  WordSearchLevel(gridSize: 12, targetWords: {'SHARK','WHALE','SEAL','FISH','CRAB'}),
  WordSearchLevel(gridSize: 12, targetWords: {'ROSE','TULIP','DAISY','LILY','FERN'}),
  WordSearchLevel(gridSize: 12, targetWords: {'BREAD','CAKE','PIE','TART','BUN'}),
  WordSearchLevel(gridSize: 12, targetWords: {'RAIN','SNOW','WIND','MIST','HAIL'}),
  WordSearchLevel(gridSize: 12, targetWords: {'MILK','SODA','JUICE','COLA','TEA'}),
  WordSearchLevel(gridSize: 12, targetWords: {'DESK','CHAIR','TABLE','LAMP','BED'}),
  WordSearchLevel(gridSize: 14, targetWords: {'TEA','MILK','COLD','HOT'}),
  WordSearchLevel(gridSize: 14, targetWords: {'RED','BLUE','PINK','GRAY'}),
  WordSearchLevel(gridSize: 14, targetWords: {'DOG','CAT','PIG','COW'}),
  WordSearchLevel(gridSize: 14, targetWords: {'OAK','PINE','FIR','ELM'}),
  WordSearchLevel(gridSize: 14, targetWords: {'SUN','STAR','MOON','SKY'}),
  WordSearchLevel(gridSize: 14, targetWords: {'CAR','BUS','VAN','CAB'}),
  WordSearchLevel(gridSize: 14, targetWords: {'HAT','COAT','VEST','CAP'}),
  WordSearchLevel(gridSize: 14, targetWords: {'PEN','CUP','KEY','BAG'}),
  WordSearchLevel(gridSize: 14, targetWords: {'RUN','HOP','JUMP','FLY'}),
  WordSearchLevel(gridSize: 14, targetWords: {'SUN','STAR','SKY','SEA'}),
  // 10 new levels
  WordSearchLevel(gridSize: 8, targetWords: {'BOAT','PLANE','ROCKET','TRAIN','BICYCLE'}),
  WordSearchLevel(gridSize: 8, targetWords: {'AMETHYST','EMERALD','SAPPHIRE','CRYSTAL','DIAMOND'}),
  WordSearchLevel(gridSize: 8, targetWords: {'LAVENDER','ROSEMARY','GINGER','HIBISCUS','JASMINE'}),
  WordSearchLevel(gridSize: 10, targetWords: {'SPARROW','ROBIN','EAGLE','FALCON','HAWK','OWL'}),
  WordSearchLevel(gridSize: 10, targetWords: {'OCTOPUS','DOLPHIN','SHARK','WHALE','ORCA','SEAL'}),
  WordSearchLevel(gridSize: 10, targetWords: {'DIAMOND','RUBY','PEARL','JADE','OPAL','ONYX'}),
  WordSearchLevel(gridSize: 12, targetWords: {'CLOVER','DAISY','LILY','ROSE','IVY'}),
  WordSearchLevel(gridSize: 12, targetWords: {'CHAIR','DESK','LAMP','BED','SOFA'}),
  WordSearchLevel(gridSize: 12, targetWords: {'SWEET','SOUR','SALTY','BITTER','SPICY'}),
];

const List<String> _kDynamicWordPool = [
  'CHIMPANZEE', 'PENGUIN', 'KANGAROO', 'FLAMINGO', 'CROCODILE', 'WOLVERINE', 'HURRICANE', 'TORNADO',
  'ALGORITHM', 'DATABASE', 'TELEPHONE', 'MICROSCOPE', 'TELESCOPE', 'ASTRONOMY', 'CHEMISTRY', 'BIOLOGY',
  'AUSTRALIA', 'ANTARCTICA', 'ARGENTINA', 'SINGAPORE', 'HONGKONG', 'MADAGASCAR', 'SWITZERLAND', 'HIROSHIMA',
  'CHOCOLATE', 'MARSHMALLOW', 'STRAWBERRY', 'BLUEBERRY', 'PINEAPPLE', 'SPAGHETTI', 'CROISSANT', 'CAPPUCCINO',
  'BEAUTIFUL', 'WONDERFUL', 'DANGEROUS', 'MYSTERIOUS', 'ADVENTURE', 'CHALLENGE', 'EDUCATION', 'KNOWLEDGE',
  'IMAGINATION', 'CREATIVITY', 'EXPLORATION', 'DISCOVERY', 'CELEBRATION', 'CHAMPIONSHIP', 'TOURNAMENT'
];

class WordSearchScreen extends StatefulWidget {
  final int? dailyLevelIndex;
  const WordSearchScreen({super.key, this.dailyLevelIndex});
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
  bool _ignoreNextTap = false;
  String _message ='';
  bool _won = false;
  final GlobalKey _gridKey = GlobalKey();
  (int, int)? _startCell;
  Offset? _panDownPosition;
  bool _playDailyMode = false;
  String _dailyModifierType = '';
  String _dailyModifierName = '';

  int _hintCount = 0;
  late final List<WordSearchLevel> _sortedLevels;

  @override
  void initState() {
    super.initState();
    _sortedLevels = (List<WordSearchLevel>.from(_kLevels)..sort((a, b) => a.gridSize.compareTo(b.gridSize))).take(50).toList();
    // Default synchronous initialization to avoid LateInitializationError
    _level = _sortedLevels[0];
    _grid = List.generate(_level.gridSize, (_) => List.filled(_level.gridSize,''));
    _initLevel();
  }

  WordSearchLevel _getWordSearchLevel(int index) {
    if (index < _sortedLevels.length) {
      return _sortedLevels[index];
    }
    // Dynamically generate beyond predefined levels
    final rand = Random(index);
    final gridSize = index < 85 ? 12 : 14;
    final targetWords = <String>{};
    final wordCount = gridSize == 12 ? 5 : 6;
    while (targetWords.length < wordCount) {
      final w = _kDynamicWordPool[rand.nextInt(_kDynamicWordPool.length)];
      if (w.length <= gridSize) {
        targetWords.add(w);
      }
    }
    return WordSearchLevel(gridSize: gridSize, targetWords: targetWords);
  }

  Future<void> _initLevel() async {
    _hintCount = await HintManager.getHints('wordsearch');
    final prefs = await SharedPreferences.getInstance();
    _playDailyMode = prefs.getBool('play_daily_mode') ?? false;
    if (_playDailyMode) {
      _dailyModifierType = prefs.getString('daily_modifier_type') ?? '';
      _dailyModifierName = prefs.getString('daily_modifier_name') ?? '';
    } else {
      _dailyModifierType = '';
      _dailyModifierName = '';
    }

    int targetLevel = 0;
    if (widget.dailyLevelIndex != null) {
      targetLevel = widget.dailyLevelIndex!;
    } else {
      targetLevel = prefs.getInt('level_wordsearch') ?? 0;
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
        final savedStateStr = prefs.getString('normal_wordsearch_state');
        if (savedStateStr != null) {
          try {
            final data = jsonDecode(savedStateStr);
            if (data['levelIndex'] == _levelIndex) {
              final continueGame = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => AlertDialog(
                  backgroundColor: context.bgCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: context.textMuted.withAlpha(40)),
                  ),
                  title: Text(
                    'Continue Game?',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary),
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
                        style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx, true); // Continue
                      },
                      child: Text(
                        'Continue',
                        style: GoogleFonts.outfit(color: AppTheme.dustyMauve, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ) ?? false;

              if (continueGame) {
                final List<dynamic> gridData = data['grid'];
                final List<List<String>> loadedGrid = gridData.map((row) => List<String>.from(row)).toList();

                final List<dynamic> wordsData = data['foundWords'];
                final Set<String> loadedFoundWords = Set<String>.from(wordsData.map((e) => e as String));

                final List<dynamic> highlightsData = data['permanentHighlights'];
                final Set<(int, int)> loadedHighlights = Set<(int, int)>.from(
                  highlightsData.map((item) => (item[0] as int, item[1] as int))
                );

                setState(() {
                  _grid = loadedGrid;
                  _foundWords.clear();
                  _foundWords.addAll(loadedFoundWords);
                  _permanentHighlights.clear();
                  _permanentHighlights.addAll(loadedHighlights);
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
      'grid': _grid,
      'foundWords': _foundWords.toList(),
      'permanentHighlights': _permanentHighlights.map((coord) => [coord.$1, coord.$2]).toList(),
    };
    await prefs.setString('normal_wordsearch_state', jsonEncode(state));
  }

  Future<void> _clearNormalState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('normal_wordsearch_state');
  }

  Future<void> _savePersistedLevel(int lvl) async {
    if (_playDailyMode) {
      return;
    }
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
    await _clearNormalState();
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
      _message = 'Hint: "$targetWord" starts at Row ${coords.first.$1 + 1}, Col ${coords.first.$2 + 1}';
      AudioManager.playClick();
    });
  }

  (List<List<String>>, bool) _generateGrid(int size, Set<String> words) {
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

    for (int attempt = 0; attempt < 100; attempt++) {
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
        return (grid, true);
      }
    }

    // Fallback
    final fallback = List.generate(size, (_) => List.generate(size, (_) => String.fromCharCode(65 + rand.nextInt(26))));
    return (fallback, false);
  }

  void _loadLevel() {
    _selection.clear();
    _foundWords.clear();
    _permanentHighlights.clear();
    _message ='';
    _won = false;

    for (int attempt = 0; attempt < 10; attempt++) {
      _level = _getWordSearchLevel(_levelIndex + attempt * 1234);
      final result = _generateGrid(_level.gridSize, _level.targetWords);
      _grid = result.$1;
      if (result.$2) {
        break; // Successfully placed all words
      }
    }
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
    
    // Clamp to grid boundaries to allow dragging outside the grid area smoothly
    final col = (local.dx / cw).floor().clamp(0, gridSize - 1);
    final row = (local.dy / ch).floor().clamp(0, gridSize - 1);
    return (row, col);
  }

  void _updateLineSelection((int, int) start, (int, int) current) {
    if (_won) return;
    final r1 = start.$1;
    final c1 = start.$2;
    var r2 = current.$1;
    var c2 = current.$2;
    
    var dr = r2 - r1;
    var dc = c2 - c1;
    
    if (dr != 0 || dc != 0) {
      final absDr = dr.abs();
      final absDc = dc.abs();
      
      // Use 22.5 to 67.5 degree angles for snapping:
      // tan(22.5) = 0.414, tan(67.5) = 2.414
      if (absDr > 2.414 * absDc) {
        // Primarily vertical
        c2 = c1;
        dc = 0;
      } else if (absDc > 2.414 * absDr) {
        // Primarily horizontal
        r2 = r1;
        dr = 0;
      } else {
        // Primarily diagonal
        final dist = ((absDr + absDc) / 2.0).round();
        r2 = r1 + dist * dr.sign;
        c2 = c1 + dist * dc.sign;
        dr = r2 - r1;
        dc = c2 - c1;
      }
    }
    
    final stepR = dr.sign;
    final stepC = dc.sign;
    
    final List<(int, int)> newLine = [];
    int r = r1;
    int c = c1;
    while (true) {
      newLine.add((r, c));
      if (r == r2 && c == c2) break;
      r += stepR;
      c += stepC;
    }

    // Check if the selection has actually changed to avoid redundant rebuilds
    bool isSame = newLine.length == _selection.length;
    if (isSame) {
      for (int i = 0; i < newLine.length; i++) {
        if (newLine[i] != _selection[i]) {
          isSame = false;
          break;
        }
      }
    }
    if (isSame) return;
    
    setState(() {
      _selection.clear();
      _selection.addAll(newLine);
      _message = '';
    });
  }

  void _addCellToSelection((int, int) pos) {
    if (_won) return;
    if (_selection.isNotEmpty) {
      final last = _selection.last;
      final isAdjacent = (last.$1 - pos.$1).abs() <= 1 && (last.$2 - pos.$2).abs() <= 1;
      if (!isAdjacent) {
        _selection.clear();
      }
    }
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
        if (_selection.length == 1) {
          AudioManager.playClick();
        }
      });
      // Auto-check if current selection forms a target word
      _checkAutoSubmit();
    }
  }

  void _checkAutoSubmit() {
    if (_selection.length < 3) return; // Minimum word length
    final word = _selection.map((pos) => _grid[pos.$1][pos.$2]).join();
    final reverseWord = word.split('').reversed.join();

    String? matchedWord;
    if (_level.targetWords.contains(word) && !_foundWords.contains(word)) {
      matchedWord = word;
    } else if (_level.targetWords.contains(reverseWord) && !_foundWords.contains(reverseWord)) {
      matchedWord = reverseWord;
    }

    if (matchedWord != null) {
      setState(() {
        _foundWords.add(matchedWord!);
        _permanentHighlights.addAll(_selection);
        _selection.clear();
        _message ='Found "$matchedWord"!';

        if (_foundWords.length == _level.targetWords.length) {
          _won = true;
          _message ='All words found!';
          AudioManager.playSuccess();
          _savePersistedLevel(_levelIndex + 1);
        } else {
          AudioManager.playClick();
        }
      });
      _saveNormalState();
    }
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
        AudioManager.playFail();
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
          AudioManager.playSuccess();
          _savePersistedLevel(_levelIndex + 1);
        } else {
          AudioManager.playClick();
        }
      });
      _saveNormalState();
    } else if (_level.targetWords.contains(reverseWord)) {
      setState(() {
        _foundWords.add(reverseWord);
        _permanentHighlights.addAll(_selection);
        _selection.clear();
        _message ='Found"$reverseWord"!';
        
        if (_foundWords.length == _level.targetWords.length) {
          _won = true;
          _message ='All words found!';
          AudioManager.playSuccess();
          _savePersistedLevel(_levelIndex + 1);
        } else {
          AudioManager.playClick();
        }
      });
      _saveNormalState();
    } else {
      setState(() {
        _message ='"$word"is not a target word!';
        _selection.clear();
        AudioManager.playFail();
      });
    }
  }

  void _nextLevel() {
    if (!_won) return;
    if (_playDailyMode) {
      Navigator.pop(context, true);
      return;
    }

    setState(() {
      _levelIndex = _levelIndex + 1;
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
_hintCount == 0 ? '+' : '$_hintCount',
                      style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black),
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
                        initialGameId: 'wordsearch',
                        onPurchaseComplete: () async {
                          final newCount = await HintManager.getHints('wordsearch');
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
            onPressed: () => RulesHelper.showRulesBottomSheet(context,'wordsearch','Word Search'),
          ),
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _reset, color: context.textMuted),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                _playDailyMode ? 'Daily' : 'Level ${_levelIndex + 1}',
                style: AppTheme.numberStyle(color: accentColor, fontSize: context.scale(13)),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
              child: Column(
                children: [
                  if (_playDailyMode)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
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
                    ),
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
                          (_playDailyMode && _dailyModifierType == 'spy')
                              ? word.split('').reversed.join('')
                              : word,
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
                      onPanDown: (d) {
                        _panDownPosition = d.globalPosition;
                      },
                      onPanStart: (d) {
                        final trueStart = _panDownPosition ?? d.globalPosition;
                        final pos = _cellAt(trueStart);
                        if (pos != null) {
                          setState(() {
                            _startCell = pos;
                            _selection.clear();
                            _selection.add(pos);
                          });
                        }
                      },
                      onPanUpdate: (d) {
                        final pos = _cellAt(d.globalPosition);
                        if (pos != null && _startCell != null) {
                          _updateLineSelection(_startCell!, pos);
                        }
                      },
                      onPanEnd: (_) {
                        _submitWord();
                        setState(() {
                          _startCell = null;
                          _panDownPosition = null;
                          _ignoreNextTap = true;
                        });
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (mounted) {
                            setState(() {
                              _ignoreNextTap = false;
                            });
                          }
                        });
                      },
                      onPanCancel: () {
                        _submitWord();
                        setState(() {
                          _startCell = null;
                          _panDownPosition = null;
                          _ignoreNextTap = true;
                        });
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (mounted) {
                            setState(() {
                              _ignoreNextTap = false;
                            });
                          }
                        });
                      },
                      child: RepaintBoundary(
                        child: Container(
                          key: _gridKey,
                          width: context.scale(280),
                          height: context.scale(280),
                          decoration: BoxDecoration(
                            color: context.bgCard,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: context.textMuted.withAlpha(65), width: 1.2),
                            boxShadow: AppTheme.cardShadow,
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
                              onTap: () {
                                if (_ignoreNextTap) return;
                                _addCellToSelection(pos);
                              },
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
                                      color: isSel ? Colors.white : context.textPrimary,
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

                  if (_won) ...[
                    const SizedBox(height: 16),
                    AutoNextCountdown(
                      onNext: _nextLevel,
                      accentColor: accentColor,
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
