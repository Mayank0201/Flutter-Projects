import'dart:math';
import'package:flutter/material.dart';
import'package:google_fonts/google_fonts.dart';
import'package:shared_preferences/shared_preferences.dart';
import'../../../utils/rules_helper.dart';
import'../../../theme/app_theme.dart';
import'../../../utils/hint_manager.dart';

class WordBuilderLevel {
  final List<String> letters;
  final int targetCount;
  final Set<String> validWords;
  const WordBuilderLevel({required this.letters, required this.targetCount, required this.validWords});
}

const List<WordBuilderLevel> _kLevels = [
  // Easy
  WordBuilderLevel(
    letters: ['A','E','T'],
    targetCount: 2,
    validWords: {'ATE','EAT','TEA','ETA'},
  ),
  WordBuilderLevel(
    letters: ['O','P','T','S'],
    targetCount: 3,
    validWords: {'POT','TOP','STOP','SPOT','POST','POTS','TOPS','SOP','SOT','OPT','OPTS'},
  ),
  WordBuilderLevel(
    letters: ['A','R','T','S'],
    targetCount: 4,
    validWords: {'ART','RAT','TAR','STAR','TARS','RATS','ARTS','TSAR','SAT'},
  ),
  WordBuilderLevel(
    letters: ['O','D','G','S'],
    targetCount: 4,
    validWords: {'DOG','GOD','DOGS','GODS','SOD','DOS'},
  ),
  // Medium
  WordBuilderLevel(
    letters: ['E','I','N','S','T'],
    targetCount: 5,
    validWords: {'ITS','NET','TEN','SITE','NEST','SENT','TENS','TIN','SIN','NIT','SIT','TIE','TINS','NITS','TIES','SINE','TINE','TINES','NETS'},
  ),
  WordBuilderLevel(
    letters: ['A','C','E','R','S'],
    targetCount: 6,
    validWords: {'ARE','CAR','EAR','ERA','SEA','CARE','CASE','RACE','ACRE','SCARE','ACE','ACES','ARC','ARCS','CARS','EARS','ERAS','CARES','ACRES','RACES','SCAR','SCARS'},
  ),
  WordBuilderLevel(
    letters: ['E','D','N','S'],
    targetCount: 4,
    validWords: {'END','DEN','ENDS','DENS','SEND'},
  ),
  // Hard
  WordBuilderLevel(
    letters: ['E','A','P','R','S'],
    targetCount: 6,
    validWords: {'APE','EAR','PEA','REAP','PEAR','APES','PEAS','PEARS','REAPS','SPARE','ARE','ERA','RAP','SAP','SPA','PAR','REPS','SPEAR','PARSE','PARE','PARES','RAPE','RAPES'},
  ),
  WordBuilderLevel(
    letters: ['I','N','G','S','T'],
    targetCount: 6,
    validWords: {'ITS','TIN','GIN','SING','SIGN','TINS','GINS','STING','SIN','SIT','NIT','NITS','GITS'},
  ),
  WordBuilderLevel(
    letters: ['E','L','A','T','S'],
    targetCount: 7,
    validWords: {'ATE','EAT','TEA','LAT','LET','LATE','TALE','EAST','SEAT','LEAST','SLATE','TALES','STEAL','ALE','ALES','SEA','SAT','LETS','STALE','SEAL','SALE','SLAT','TEAL','TEALS'},
  ),
  // Expansions
  WordBuilderLevel(
    letters: ['P','I','N'],
    targetCount: 2,
    validWords: {'PIN','NIP','IN','PI'},
  ),
  WordBuilderLevel(
    letters: ['K','I','N','G'],
    targetCount: 3,
    validWords: {'INK','KIN','KING','GIN'},
  ),
  WordBuilderLevel(
    letters: ['M','A','T','E'],
    targetCount: 4,
    validWords: {'ATE','EAT','TEA','MAT','MET','MATE','TAME','TEAM','MEAT','TAM','MAE'},
  ),
  WordBuilderLevel(
    letters: ['C','L','A','Y','S'],
    targetCount: 5,
    validWords: {'LAY','SAY','CLAY','LAYS','CLAYS','LACY','SLAY','LAC'},
  ),
  WordBuilderLevel(
    letters: ['B','R','E','A','D'],
    targetCount: 6,
    validWords: {'RED','BED','BAD','BAR','EAR','ERA','READ','DEAR','BEAR','BARE','BREAD','BEAD','BARD','ARE','DARE','DRAB'},
  ),
  WordBuilderLevel(
    letters: ['C','A','T'],
    targetCount: 2,
    validWords: {'CAT','ACT'},
  ),
  WordBuilderLevel(
    letters: ['D','O','G'],
    targetCount: 2,
    validWords: {'DOG','GOD'},
  ),
  WordBuilderLevel(
    letters: ['A','R','T'],
    targetCount: 3,
    validWords: {'ART','RAT','TAR'},
  ),
  WordBuilderLevel(
    letters: ['E','A','R'],
    targetCount: 3,
    validWords: {'EAR','ERA','ARE'},
  ),
  WordBuilderLevel(
    letters: ['P','O','T','S'],
    targetCount: 4,
    validWords: {'POT','TOP','POTS','TOPS','SPOT','STOP','POST','OPT','SOP','SOT','OPTS'},
  ),
  WordBuilderLevel(
    letters: ['R','A','T','S'],
    targetCount: 4,
    validWords: {'RAT','TAR','ART','SAT','RATS','TARS','ARTS','STAR','TSAR'},
  ),
  WordBuilderLevel(
    letters: ['N','O','T','E'],
    targetCount: 4,
    validWords: {'NOT','NET','TEN','ONE','TON','TOE','NOTE','TONE'},
  ),
  WordBuilderLevel(
    letters: ['P','I','N','E'],
    targetCount: 4,
    validWords: {'PIN','NIP','PEN','PIE','PINE'},
  ),
  WordBuilderLevel(
    letters: ['R','O','S','E'],
    targetCount: 4,
    validWords: {'ORE','ROSE','SORE','EROS','ROE'},
  ),
  WordBuilderLevel(
    letters: ['S','P','I','N'],
    targetCount: 4,
    validWords: {'PIN','NIP','SIN','SIP','SPIN','SNIP','PINS','NIPS'},
  ),
  WordBuilderLevel(
    letters: ['L','I','O','N'],
    targetCount: 4,
    validWords: {'ION','NIL','LION','LOIN','OIL'},
  ),
  WordBuilderLevel(
    letters: ['P','E','A','R'],
    targetCount: 5,
    validWords: {'EAR','ERA','ARE','PEA','REAP','PEAR','PARE','APE','RAP','PAR'},
  ),
  WordBuilderLevel(
    letters: ['S','M','A','R','T'],
    targetCount: 6,
    validWords: {'ART','RAT','TAR','SAT','MAT','RAM','ARM','MAR','STAR','MART','TRAM','SMART','RAMS','ARMS','MARS','ARTS','RATS','TARS'},
  ),
  WordBuilderLevel(
    letters: ['F','L','O','W','S'],
    targetCount: 6,
    validWords: {'LOW','OWL','SOW','FLOW','WOLF','SLOW','FOWL','FLOWS','OWLS','LOWS'},
  ),
  WordBuilderLevel(
    letters: ['C','R','A','B','S'],
    targetCount: 6,
    validWords: {'CAB','CAR','BAR','ARC','CRAB','BARS','CABS','CARS','ARCS','CRABS','SCAB'},
  ),
  WordBuilderLevel(
    letters: ['P','E','A','C','H'],
    targetCount: 5,
    validWords: {'PEACH','CHEAP','CAPE','PACE','EACH','APE','CAP','PEA','ACE','CHAP'},
  ),
  WordBuilderLevel(
    letters: ['S','P','I','L','L'],
    targetCount: 4,
    validWords: {'SPILL','SLIP','PILL','LIPS','ILL','LIP','SIP','PILLS','SLIPS','LISP'},
  ),
  WordBuilderLevel(
    letters: ['T','R','A','I','N'],
    targetCount: 5,
    validWords: {'TRAIN','RAIN','RAN','TIN','ART','RAT','TAR','TAN','ANTI'},
  ),
  WordBuilderLevel(
    letters: ['S','M','A','R','T'],
    targetCount: 7,
    validWords: {'SMART','MART','TRAM','STAR','RATS','TARS','ARTS','RAMS','ARMS','MARS','ART','RAT','TAR','MAT','SAT'},
  ),
  WordBuilderLevel(
    letters: ['S','P','A','C','E'],
    targetCount: 5,
    validWords: {'SPACE','CAPES','PACES','CAPE','PACE','CASE','APES','PEAS','SEA','CAP','APE','ACE','ACES','SPA'},
  ),
  WordBuilderLevel(
    letters: ['L','E','M','O','N'],
    targetCount: 5,
    validWords: {'LEMON','MELON','LONE','MEN','ONE','ELM','OLE'},
  ),
  WordBuilderLevel(
    letters: ['S','T','O','R','M'],
    targetCount: 6,
    validWords: {'STORM','MOST','SORT','ROTS','TORS','ROT','TOM','SOT'},
  ),
  WordBuilderLevel(
    letters: ['T','I','G','E','R'],
    targetCount: 5,
    validWords: {'TIGER','TIRE','RITE','GIRT','TRIG','GET','TIE','RIG'},
  ),
  WordBuilderLevel(
    letters: ['B','R','E','A','D'],
    targetCount: 7,
    validWords: {'BREAD','BEAD','BARD','DEAR','READ','BEAR','BARE','BED','RED','BAD','BAR','EAR','ERA','ARE','DARE','DRAB'},
  ),
  WordBuilderLevel(
    letters: ['F','L','U','T','E'],
    targetCount: 5,
    validWords: {'FLUTE','LUTE','FLUE','FUEL','FELT','LEFT','LET','ELF','FLU'},
  ),
  // 10 new levels
  WordBuilderLevel(
    letters: ['P','A','N'],
    targetCount: 2,
    validWords: {'PAN','NAP','AN','PA'},
  ),
  WordBuilderLevel(
    letters: ['L','I','P','S'],
    targetCount: 3,
    validWords: {'LIP','SIP','LIPS','SLIP','LISP'},
  ),
  WordBuilderLevel(
    letters: ['N','E','S','T'],
    targetCount: 4,
    validWords: {'NET','TEN','NEST','SENT','TENS','NETS'},
  ),
  WordBuilderLevel(
    letters: ['F','A','S','T'],
    targetCount: 4,
    validWords: {'FAST','FAT','SAT','AS','AT','FATS'},
  ),
  WordBuilderLevel(
    letters: ['H','E','A','R','T'],
    targetCount: 5,
    validWords: {'HEAR','HATE','HEAT','EAR','ERA','ARE','HEART','EARTH','HATER','RATE','TEAR','TARE'},
  ),
  WordBuilderLevel(
    letters: ['G','R','A','P','E'],
    targetCount: 5,
    validWords: {'APE','GAP','RAG','EAR','ERA','ARE','GRAPE','PEAR','REAP','PAGE','RAGE','PARE'},
  ),
  WordBuilderLevel(
    letters: ['P','L','A','N','E','T'],
    targetCount: 6,
    validWords: {'PLAN','LANE','PALE','LATE','TALE','PLANET','PLATE','PLANT','PANEL','PLEAT','NEAT','PEAL','LEAN'},
  ),
  WordBuilderLevel(
    letters: ['S','I','L','V','E','R'],
    targetCount: 6,
    validWords: {'LIVE','VILE','RISE','SIRE','SILVER','SLIVER','LIVER','ELVES'},
  ),
  WordBuilderLevel(
    letters: ['F','I','N','G','E','R'],
    targetCount: 6,
    validWords: {'FINE','RING','REIN','FINGER','FRINGE','REIGN','FERN','GRIF'},
  ),
  WordBuilderLevel(
    letters: ['P','O','S','T','E','R'],
    targetCount: 6,
    validWords: {'POST','SPOT','STOP','PORT','POET','ROSE','SORE','POSTER','STORE','TROPES','PORE','PORES','ROPE','ROPES','SORT','ROTS','PORTS'},
  ),
];

class WordBuilderScreen extends StatefulWidget {
  const WordBuilderScreen({super.key});
  @override
  State<WordBuilderScreen> createState() => _WordBuilderScreenState();
}

class _WordBuilderScreenState extends State<WordBuilderScreen> {
  int _levelIndex = 0;
  late WordBuilderLevel _level;
  final List<String> _currentGuess = [];
  final List<int> _selectedIndices = [];
  final Set<String> _foundWords = {};
  String _message ='';
  bool _won = false;

  final GlobalKey _honeycombKey = GlobalKey();
  final List<Offset> _linePoints = [];
  Offset? _currentDragOffset;

  int _hintCount = 0;

  @override
  void initState() {
    super.initState();
    // Default synchronous initialization to avoid LateInitializationError
    _level = _kLevels[0];
    _initLevel();
  }

  Future<void> _initLevel() async {
    _hintCount = await HintManager.getHints('wordbuilder');
    final prefs = await SharedPreferences.getInstance();
    final savedLevel = prefs.getInt('level_wordbuilder') ?? 0;
    if (mounted) {
      setState(() {
        _levelIndex = savedLevel % _kLevels.length;
        _loadLevel();
      });
    }
  }

  Future<void> _savePersistedLevel(int lvl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('level_wordbuilder', lvl);
    final earned = await HintManager.onLevelCleared('wordbuilder');
    final newCount = await HintManager.getHints('wordbuilder');
    setState(() {
      _hintCount = newCount;
    });
    if (earned && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hint earned! (Total: $newCount)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: AppTheme.accentFor('wordbuilder'),
        ),
      );
    }
  }

  Future<void> _useHint() async {
    if (_won || _hintCount <= 0) return;
    String? targetWord;
    for (final word in _level.validWords) {
      if (!_foundWords.contains(word)) {
        targetWord = word;
        break;
      }
    }
    if (targetWord == null) return;

    await HintManager.useHint('wordbuilder');
    final newCount = await HintManager.getHints('wordbuilder');

    setState(() {
      _hintCount = newCount;
      _foundWords.add(targetWord!);
      _message ='Hint revealed word:"$targetWord"';
      if (_foundWords.length >= _level.targetCount) {
        _won = true;
        _savePersistedLevel(_levelIndex);
      }
    });
  }

  void _loadLevel() {
    _level = _kLevels[_levelIndex % _kLevels.length];
    _currentGuess.clear();
    _selectedIndices.clear();
    _foundWords.clear();
    _linePoints.clear();
    _currentDragOffset = null;
    _message ='';
    _won = false;
  }

  void _reset() => setState(() => _loadLevel());

  void _addLetterToGuess(int index, Offset center) {
    if (_won) return;
    if (_selectedIndices.length >= 2 && _selectedIndices[_selectedIndices.length - 2] == index) {
      setState(() {
        _currentGuess.removeLast();
        _selectedIndices.removeLast();
        _linePoints.removeLast();
        _currentDragOffset = center;
      });
      return;
    }
    if (!_selectedIndices.contains(index)) {
      setState(() {
        _currentGuess.add(_level.letters[index]);
        _selectedIndices.add(index);
        _linePoints.add(center);
        _currentDragOffset = center;
        _message ='';
      });
    }
  }

  void _handlePan(Offset globalPos) {
    final box = _honeycombKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalPos);
    final size = box.size.width;
    final ctr = Offset(size / 2, size / 2);
    final scaleVal = size / 220.0;
    final n = _level.letters.length;
    final radius = 70.0 * scaleVal;

    for (int i = 0; i < n; i++) {
      final angle = i * 2 * pi / n - pi / 2;
      final buttonCenter = ctr + Offset(radius * cos(angle), radius * sin(angle));
      final dist = (local - buttonCenter).distance;
      if (dist < 28.0 * scaleVal) {
        _addLetterToGuess(i, buttonCenter);
        return;
      }
    }

    setState(() {
      _currentDragOffset = local;
    });
  }

  void _handlePanEnd() {
    if (_currentGuess.isNotEmpty) {
      _submitWord();
    }
    setState(() {
      _selectedIndices.clear();
      _linePoints.clear();
      _currentDragOffset = null;
    });
  }

  void _backspace() {
    if (_won || _currentGuess.isEmpty) return;
    setState(() {
      _currentGuess.removeLast();
      if (_selectedIndices.isNotEmpty) {
        _selectedIndices.removeLast();
      }
      if (_linePoints.isNotEmpty) {
        _linePoints.removeLast();
      }
    });
  }

  void _clearGuess() {
    setState(() {
      _currentGuess.clear();
      _selectedIndices.clear();
      _linePoints.clear();
      _currentDragOffset = null;
    });
  }

  void _submitWord() {
    if (_won || _currentGuess.isEmpty) return;
    final word = _currentGuess.join();
    if (_foundWords.contains(word)) {
      setState(() {
        _message ='Already found"$word"!';
        _currentGuess.clear();
        _selectedIndices.clear();
        _linePoints.clear();
        _currentDragOffset = null;
      });
      return;
    }
    if (_level.validWords.contains(word)) {
      setState(() {
        _foundWords.add(word);
        _message ='Nice! +1 word';
        _currentGuess.clear();
        _selectedIndices.clear();
        _linePoints.clear();
        _currentDragOffset = null;
        if (_foundWords.length >= _level.targetCount) {
          _won = true;
          _message ='Level Complete!';
          _savePersistedLevel(_levelIndex);
        }
      });
    } else {
      setState(() {
        _message ='"$word"is not a valid word!';
        _currentGuess.clear();
        _selectedIndices.clear();
        _linePoints.clear();
        _currentDragOffset = null;
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
    final accentColor = AppTheme.accentFor('wordbuilder');
    final n = _level.letters.length;
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        backgroundColor: context.bgDark,
        foregroundColor: context.textPrimary,
        title: Text('Word Builder', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: context.textPrimary)),
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
            onPressed: () => RulesHelper.showRulesBottomSheet(context,'wordbuilder','Word Builder'),
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
'Drag over letters to connect and build words',
                style: GoogleFonts.outfit(color: context.textSecondary, fontSize: context.scale(13)),
              ),
              const SizedBox(height: 8),
              Text(
'Find ${_level.targetCount} words to pass',
                style: GoogleFonts.outfit(color: accentColor, fontSize: context.scale(13), fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              // Target spaces and found list
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: List.generate(_level.targetCount, (index) {
                        final list = _foundWords.toList();
                        final hasWord = index < list.length;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: hasWord ? accentColor.withOpacity(0.2) : context.bgCard,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: hasWord ? accentColor : context.textMuted.withAlpha(50),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            hasWord ? list[index] :'• • •',
                            style: GoogleFonts.outfit(
                              fontSize: context.scale(16),
                              fontWeight: FontWeight.w700,
                              color: hasWord ? context.textPrimary : context.textMuted,
                              letterSpacing: 2,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
              // Message / Display Current Guess
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_message.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Text(
                        _message,
                        style: GoogleFonts.outfit(
                          color: _won ? accentColor : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: context.scale(14),
                        ),
                      ),
                    ),
                  // Current selection display
                  Container(
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: context.textMuted.withAlpha(50), width: 1)),
                    ),
                    child: Text(
                      _currentGuess.join(),
                      style: GoogleFonts.outfit(
                        fontSize: context.scale(26),
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Circular Letter Selector
              Center(
                child: GestureDetector(
                  onPanStart: (d) => _handlePan(d.globalPosition),
                  onPanUpdate: (d) => _handlePan(d.globalPosition),
                  onPanEnd: (d) => _handlePanEnd(),
                  child: SizedBox(
                    key: _honeycombKey,
                    width: context.scale(220),
                    height: context.scale(220),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Line paint behind letters
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _LineConnectorPainter(
                              points: _linePoints,
                              currentDrag: _currentDragOffset,
                              color: accentColor,
                            ),
                          ),
                        ),
                        // Circular letter buttons
                        ...List.generate(n, (index) {
                          final angle = index * 2 * pi / n - pi / 2;
                          final radius = context.scale(70.0);
                          final x = radius * cos(angle);
                          final y = radius * sin(angle);
                          final letter = _level.letters[index];
                          final isSel = _selectedIndices.contains(index);

                          return Positioned(
                            left: context.scale(110) + x - context.scale(26),
                            top: context.scale(110) + y - context.scale(26),
                            child: Container(
                              width: context.scale(52),
                              height: context.scale(52),
                              decoration: BoxDecoration(
                                color: isSel ? accentColor : context.bgCard,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSel ? Colors.transparent : context.textMuted.withAlpha(100),
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  letter,
                                  style: GoogleFonts.outfit(
                                    fontSize: context.scale(22),
                                    fontWeight: FontWeight.w800,
                                    color: isSel ? Colors.white : context.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Action buttons (Clear, Backspace, Submit, Next)
              if (!_won)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: _clearGuess,
                      child: Text('CLEAR', style: GoogleFonts.outfit(color: context.textSecondary, fontWeight: FontWeight.bold, fontSize: context.scale(14))),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      onPressed: _submitWord,
                      child: Text('SUBMIT', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: context.scale(14))),
                    ),
                    IconButton(
                      icon: Icon(Icons.backspace_outlined, size: context.scale(22)),
                      onPressed: _backspace,
                      color: context.textSecondary,
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

class _LineConnectorPainter extends CustomPainter {
  final List<Offset> points;
  final Offset? currentDrag;
  final Color color;
  _LineConnectorPainter({required this.points, this.currentDrag, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = color.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    if (currentDrag != null) {
      path.lineTo(currentDrag!.dx, currentDrag!.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_LineConnectorPainter oldDelegate) => true;
}
