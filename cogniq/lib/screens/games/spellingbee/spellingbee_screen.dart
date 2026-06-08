import'dart:math';
import'package:flutter/material.dart';
import'package:google_fonts/google_fonts.dart';
import'package:shared_preferences/shared_preferences.dart';
import'../../../utils/rules_helper.dart';
import'../../../theme/app_theme.dart';
import'../../../utils/hint_manager.dart';

class SpellingBeeLevel {
  final String centerLetter;
  final List<String> outerLetters;
  final int targetCount;
  final Set<String> validWords;
  const SpellingBeeLevel({
    required this.centerLetter,
    required this.outerLetters,
    required this.targetCount,
    required this.validWords,
  });

  List<String> get allLetters => [centerLetter, ...outerLetters];
}

const List<SpellingBeeLevel> _kLevels = [
  // Easy
  SpellingBeeLevel(
    centerLetter:'T',
    outerLetters: ['A','C','E','O','P','R'],
    targetCount: 4,
    validWords: {
'ACT','CAT','EAT','TEA','TOP','POT','PAT','TAP','ATE','COAT','POET','TAPE','PACT',
'RAT','TAR','ROTE','TORE','PORT','TARP','PART','RAPT','PEAT','TEAR','TARE','RATE',
'CRATE','TRACE','CATER','REACT','TRACT','COPTER','COPT','PATTER','POTTER','TORT','TROT','PET','OAT','TOE'
    },
  ),
  SpellingBeeLevel(
    centerLetter:'I',
    outerLetters: ['L','N','E','S','T','A'],
    targetCount: 5,
    validWords: {
'ITS','LINE','LIEN','NILE','SAIL','NAIL','TAIL','SLIT','LINT','TIN','TINS','SATIN',
'LIT','NIL','SIN','SIT','TIE','LIE','AIL','ALIEN','INLET','SILENT','LIST','SAINT',
'STAIN','SLAIN','TILES','LINES','LIENS','NILES','SAILS','NAILS','TAILS','SLITS','LINTS','TINE','TINES'
    },
  ),
  SpellingBeeLevel(
    centerLetter:'E',
    outerLetters: ['O','P','R','S','T','U'],
    targetCount: 6,
    validWords: {
'PET','REPO','ROPE','ROSE','SURE','PEST','STEP','POET','TRUE','SUPER','REPOST',
'ROTE','TORE','POSE','USER','PURE','STEEP','PEER','SEER','SORE','STORE','ROSTER',
'UPSET','PESTER','PURSE','SPREE','TREE','TREES','PRESS','REPT','PETS','REPOS',
'ROPES','ROSES','PESTS','STEPS','POETS','SUPERS','USERS'
    },
  ),
  SpellingBeeLevel(
    centerLetter:'N',
    outerLetters: ['A','C','E','O','P','R'],
    targetCount: 5,
    validWords: {
'CON','ONE','PAN','PEN','PIN','CANE','CONE','OPEN','PANE','ACNE','ONCE','PRONE','CRONE'
    },
  ),
  // Medium
  SpellingBeeLevel(
    centerLetter:'A',
    outerLetters: ['B','C','D','E','L','R'],
    targetCount: 6,
    validWords: {
'CAB','BAD','LAD','BALD','LACE','ACRE','CARE','BREAD','CRADLE','CABLE','BAR','CAR',
'EAR','ERA','ALE','LARD','CARD','DEAL','LEAD','BEAR','BARE','DARE','READ','DEAR','RACE','CLEAR'
    },
  ),
  SpellingBeeLevel(
    centerLetter:'C',
    outerLetters: ['E','H','I','N','O','T'],
    targetCount: 7,
    validWords: {
'ICE','CHIN','COIN','NICE','CONE','TECH','ETHIC','TONIC','NOTICE','ECHIN',
'CHIC','ECHO','ONCE','ITCH','NICH','CON','COT','CONIC'
    },
  ),
  SpellingBeeLevel(
    centerLetter:'O',
    outerLetters: ['B','D','G','L','S','U'],
    targetCount: 6,
    validWords: {
'DOG','GOD','LOG','OLD','DOGS','GODS','LOGS','BOLD','GOLD','SOUL','BOLO','LOGO','LOGOS'
    },
  ),
  // Hard
  SpellingBeeLevel(
    centerLetter:'R',
    outerLetters: ['A','D','E','G','N','S'],
    targetCount: 7,
    validWords: {
'RED','ERA','EAR','ARE','DEAR','DARE','READ','RAGE','GEAR','NEAR','EARN','RANG','DANGER','GARDEN','GRAND','GRANDER','RAGES','GEARS','NEARS','EARNS','DANGERS','GARDENS','GRANDS'
    },
  ),
  SpellingBeeLevel(
    centerLetter:'G',
    outerLetters: ['I','N','S','T','A','E'],
    targetCount: 8,
    validWords: {
'GIN','TAG','AGE','SING','SIGN','GATE','GAIN','GENT','STAGE','GIANT','STING','SINGE','AGENT','ANGEL','TEASING','EASING','GINS','TAGS','AGES','SINGS','SIGNS','GATES','GAINS','GENTS','STAGES','GIANTS','STINGS','SINGES','AGENTS'
    },
  ),
  SpellingBeeLevel(
    centerLetter:'L',
    outerLetters: ['E','A','T','S','C','O'],
    targetCount: 10,
    validWords: {
'LET','LOT','ALE','LATE','TALE','SOLE','COAL','LACE','CLOT','LEAST','STEAL','SLATE','CASTLE','CLOSE','SOLACE','CLOSET','COALESCE','LETS','LOTS','ALES','TALES','SOLES','COALS','LACES','CLOTS','STEALS','SLATES','CASTLES','CLOSES'
    },
  ),
  // Expansions
  SpellingBeeLevel(
    centerLetter:'P',
    outerLetters: ['A','E','L','S','T','O'],
    targetCount: 4,
    validWords: {
'PEA','PAL','POT','PET','PAT','POET','PLOT','PAST','POST','PLATE','PEAL','PLEA','PALE','POLE','POTS','PETS','PALS','PLOTS','PLATES','PLEAS','PALES','POLES'
    },
  ),
  SpellingBeeLevel(
    centerLetter:'R',
    outerLetters: ['A','C','E','O','P','T'],
    targetCount: 5,
    validWords: {
'RAT','TAR','ARE','CAR','EAR','ERA','ROTE','TORE','PORT','TARP','PART','PEAR','CRATE','TRACE','CATER','REACT','RACE','ACTOR','COPTER'
    },
  ),
  SpellingBeeLevel(
    centerLetter:'S',
    outerLetters: ['A','E','L','M','N','T'],
    targetCount: 6,
    validWords: {
'SEA','SAME','SEAM','SENT','NEST','EAST','SEAT','LEAST','SLATE','STEAL','TALES','MALES','NAMES','SEAS','SAMES','SEAMS','SENTS','NESTS','STEALS','SLATES'
    },
  ),
  SpellingBeeLevel(
    centerLetter:'U',
    outerLetters: ['B','L','R','E','S','T'],
    targetCount: 4,
    validWords: {
'RUB','SUB','BLUE','SURE','TRUE','BUST','RUST','LUST','RUSE','RULE','LUBE','BLUES','BUSTS','RUSTS','LUSTS','RUSES','RULES','LUBES'
    },
  ),
  SpellingBeeLevel(
    centerLetter:'D',
    outerLetters: ['A','E','L','P','R','S'],
    targetCount: 4,
    validWords: {
'RED','BAD','LAD','PAD','DEAR','BREAD','BEAD','BARD','LEAD','DEAL','DEALER','PLEAD','PLEADS','ADDED','DARED','DRAPED'
    },
  ),
  SpellingBeeLevel(
    centerLetter:'C',
    outerLetters: ['R','A','B','S','T','E'],
    targetCount: 5,
    validWords: {
'CAB','CAR','ARC','CRAB','CABS','CARS','ARCS','CRABS','SCAB','CART','CARTS','TRACE','CRATE','REACT','CREST','CERT'
    },
  ),
  SpellingBeeLevel(
    centerLetter:'F',
    outerLetters: ['L','O','W','S','E','R'],
    targetCount: 4,
    validWords: {
'FLOW','FOWL','FLOWS','FOWLS','FLOWER','FLOWERS','FLOE','FLOES','FORE','FROE','FOES'
    },
  ),
  SpellingBeeLevel(
    centerLetter:'L',
    outerLetters: ['I','O','N','S','T','E'],
    targetCount: 4,
    validWords: {
'NIL','LION','LOIN','LIONS','LOINS','SILO','SLING','SLIT','LIST','LOST','LINE','LINES','TILE','TILES','LENT','LINTEL','INLET','ENLIST'
    },
  ),
  SpellingBeeLevel(
    centerLetter:'M',
    outerLetters: ['A','R','T','S','E','L'],
    targetCount: 4,
    validWords: {
'MAT','MET','MEAT','MATE','TAME','TEAM','SMART','MART','TRAM','RAMS','ARMS','MARS','MALE','MALES','MELT','MELTS'
    },
  ),
  SpellingBeeLevel(
    centerLetter:'D',
    outerLetters: ['E','A','R','C','H','T'],
    targetCount: 5,
    validWords: {
'DEAR','READ','DREAD','HEARD','TREAD','HEAD','DATE','DACE','EACH','DEAD','DARE','DRAT','HARD','CHARD','ADHERE'
    },
  ),
  SpellingBeeLevel(
    centerLetter:'P',
    outerLetters: ['L','A','Y','E','R','S'],
    targetCount: 5,
    validWords: {
'PLAY','PLAYER','PLAYERS','PEAR','PEARL','PEARS','PEARLS','REAP','REAPS','PAY','PAYS','PLEAS','YELP','YELPS','SPAY','PRAY','PRAYS','DRAPE','DRAPES','SPARE','SPEAR'
    },
  ),
  SpellingBeeLevel(
    centerLetter:'O',
    outerLetters: ['N','E','T','W','R','K'],
    targetCount: 5,
    validWords: {
'ONE','TWO','TON','NOTE','TONE','WORE','TORN','WORK','NETWORK','ROTE','KNOT','WOKE','TORE','ROOK','TOKEN','WOKEN'
    },
  ),
  SpellingBeeLevel(
    centerLetter:'C',
    outerLetters: ['A','R','D','O','B','N'],
    targetCount: 4,
    validWords: {
'CAR','CAD','CAB','CAN','COB','CON','CARD','CORD','CARBON','CRAB','CORN','ACORN','CROC','CODA','COBRA','BRACE'
    },
  ),
  SpellingBeeLevel(
    centerLetter:'G',
    outerLetters: ['R','O','W','T','H','I'],
    targetCount: 4,
    validWords: {
'GROW','GROWTH','GRIT','GOTH','TRIG','RING','GRIN','GIRT','GIRO','GRIOT','GOING'
    },
  ),
  SpellingBeeLevel(
    centerLetter:'B',
    outerLetters: ['L','A','C','K','S','E'],
    targetCount: 4,
    validWords: {
'BLACK','BLACKS','BACK','BACKS','BASK','BALE','BALES','BASE','BAKE','BAKES','BLEAK','BEAKS','CABLE','CABLES','BECK'
    },
  ),
  SpellingBeeLevel(
    centerLetter:'U',
    outerLetters: ['N','I','T','E','D','S'],
    targetCount: 5,
    validWords: {
'UNIT','UNITS','UNITED','DUET','DUETS','STUD','NUDE','NUDES','TUNE','TUNES','SUIT','SUITS','DUST','DUNES','DUNE'
    },
  ),
  SpellingBeeLevel(
    centerLetter:'F',
    outerLetters: ['L','O','W','E','R','S'],
    targetCount: 4,
    validWords: {
'FLOW','FLOWER','FLOWERS','FOWL','FEW','SELF','SERF','FORE','FROE','FOE','FLOE','FLOES','FOES','FROW','FOWLS','FLOWS'
    },
  ),
  SpellingBeeLevel(
    centerLetter:'V',
    outerLetters: ['I','C','T','O','R','Y'],
    targetCount: 3,
    validWords: {
'VICTOR','VICTORY','IVY','IVORY','OVARY','VICAR'
    },
  ),
  SpellingBeeLevel(
    centerLetter:'H',
    outerLetters: ['O','U','S','E','L','D'],
    targetCount: 5,
    validWords: {
'HOUSE','HOLD','HOLDS','SHED','SHOE','HOSE','HOLES','HELD','HUED','SHOULD','SHOAL','SHOD'
    },
  ),
  // 10 new levels
  SpellingBeeLevel(
    centerLetter:'A',
    outerLetters: ['B','C','K','S','T','U'],
    targetCount: 4,
    validWords: {
'CAB','CAT','BAT','BACK','SACK','TACK','CABS','CATS','BATS','BACKS','SACKS','TACKS'
    },
  ),
  SpellingBeeLevel(
    centerLetter:'E',
    outerLetters: ['L','M','N','O','S','T'],
    targetCount: 4,
    validWords: {
'MET','NET','TEN','MEN','ONE','LET','NEST','SENT','TENS','NETS','MELON','LEMON','LONE','SOLES','SOME'
    },
  ),
  SpellingBeeLevel(
    centerLetter:'I',
    outerLetters: ['G','N','P','S','T','U'],
    targetCount: 4,
    validWords: {
'PIN','NIP','PIG','SIN','SIP','TIN','STING','SING','SPIN','SNIP','PINS','NIPS','PIGS','SINS','SIPS','TINS','UNIT','UNITS','SUIT','SUITS'
    },
  ),
  SpellingBeeLevel(
    centerLetter:'O',
    outerLetters: ['C','D','G','L','R','S'],
    targetCount: 5,
    validWords: {
'DOG','GOD','LOG','OLD','COD','COLD','CORD','GOLD','SOLD','CLOD','DOGS','GODS','LOGS','CODS','COLDS','CORDS','GOLDS','CLODS','CLOG','CLOGS'
    },
  ),
  SpellingBeeLevel(
    centerLetter:'R',
    outerLetters: ['A','B','D','E','G','S'],
    targetCount: 5,
    validWords: {
'RED','EAR','ERA','ARE','BAR','DEAR','BEAR','BARE','DARE','READ','RAGE','GEAR','BREAD','BEARD','BARS','RAGES','GEARS','BREADS','BEARDS'
    },
  ),
  SpellingBeeLevel(
    centerLetter:'T',
    outerLetters: ['E','I','L','M','S','U'],
    targetCount: 5,
    validWords: {
'MET','LET','ITS','SIT','TIE','LIT','MUST','SUIT','LUTE','MELT','SLIT','MIST','MELTS','SLITS','MISTS','SUITS','LUTES','SITES'
    },
  ),
  SpellingBeeLevel(
    centerLetter:'C',
    outerLetters: ['A','E','L','P','S','T'],
    targetCount: 6,
    validWords: {
'CAT','ACT','LACE','CAPE','PACE','CLAP','CAST','CASE','PLACE','CASTLE','SCALP','SPACE','SCALE','CLEAT','CLASP','CAPES','LACED','CAPS'
    },
  ),
  SpellingBeeLevel(
    centerLetter:'D',
    outerLetters: ['A','E','H','L','R','S'],
    targetCount: 6,
    validWords: {
'RED','LAD','SAD','HAD','DEAR','DARE','READ','LEAD','DEAL','SHED','SHARD','SADDLE','ALDER','HEADER','LEADER'
    },
  ),
  SpellingBeeLevel(
    centerLetter:'G',
    outerLetters: ['E','I','L','N','R','S'],
    targetCount: 6,
    validWords: {
'GEL','LEG','GIN','SING','SIGN','RING','GRIN','GIRE','GIRN','RINGLE','SINGE','REIGN','SLING','GRINS','RINGS','SIGNS','SINGS','GINS','LEGS','GELS'
    },
  ),
  SpellingBeeLevel(
    centerLetter:'P',
    outerLetters: ['A','E','L','R','S','T'],
    targetCount: 6,
    validWords: {
'APE','PEA','PAL','RAP','TAP','PAT','PEAR','REAP','PARE','PALE','SPARE','PLATE','PLEAT','PEARL','PASTEL','STAPLE','PETAL','TARP'
    },
  ),
];

class SpellingBeeScreen extends StatefulWidget {
  const SpellingBeeScreen({super.key});
  @override
  State<SpellingBeeScreen> createState() => _SpellingBeeScreenState();
}

class _SpellingBeeScreenState extends State<SpellingBeeScreen> {
  int _levelIndex = 0;
  late SpellingBeeLevel _level;
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
    _hintCount = await HintManager.getHints('spellingbee');
    final prefs = await SharedPreferences.getInstance();
    final savedLevel = prefs.getInt('level_spellingbee') ?? 0;
    if (mounted) {
      setState(() {
        _levelIndex = savedLevel % _kLevels.length;
        _loadLevel();
      });
    }
  }

  Future<void> _savePersistedLevel(int lvl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('level_spellingbee', lvl);
    final earned = await HintManager.onLevelCleared('spellingbee');
    final newCount = await HintManager.getHints('spellingbee');
    setState(() {
      _hintCount = newCount;
    });
    if (earned && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hint earned! (Total: $newCount)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: AppTheme.accentFor('spellingbee'),
        ),
      );
    }
  }

  Future<void> _useHint() async {
    if (_won || _hintCount <= 0) return;
    String? targetWord;
    for (final word in _level.validWords) {
      if (word.contains(_level.centerLetter) && !_foundWords.contains(word)) {
        targetWord = word;
        break;
      }
    }
    if (targetWord == null) return;

    await HintManager.useHint('spellingbee');
    final newCount = await HintManager.getHints('spellingbee');

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

  void _addLetterToGuess(int index, String letter, Offset center) {
    if (_won) return;
    if (!_selectedIndices.contains(index)) {
      setState(() {
        _currentGuess.add(letter);
        _selectedIndices.add(index);
        _linePoints.add(center);
        _currentDragOffset = center;
        _message = '';
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

    // Check center letter (index 0)
    final distCenter = (local - ctr).distance;
    if (distCenter < 30.0 * scaleVal) {
      _addLetterToGuess(0, _level.centerLetter, ctr);
      return;
    }

    // Check outer letters (indices 1 to 6)
    for (int i = 0; i < 6; i++) {
      final angle = i * pi / 3 - pi / 6;
      final radius = 75.0 * scaleVal;
      final x = radius * cos(angle);
      final y = radius * sin(angle);
      final outerCenter = ctr + Offset(x, y);
      final distOuter = (local - outerCenter).distance;
      if (distOuter < 26.0 * scaleVal) {
        _addLetterToGuess(i + 1, _level.outerLetters[i], outerCenter);
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
    if (!word.contains(_level.centerLetter)) {
      setState(() {
        _message ='Must contain center letter"${_level.centerLetter}"';
        _currentGuess.clear();
        _selectedIndices.clear();
      });
      return;
    }
    if (_foundWords.contains(word)) {
      setState(() {
        _message ='Already found"$word"';
        _currentGuess.clear();
        _selectedIndices.clear();
      });
      return;
    }
    if (_level.validWords.contains(word)) {
      setState(() {
        _foundWords.add(word);
        _message ='Nice! +1 word';
        _currentGuess.clear();
        _selectedIndices.clear();
        if (_foundWords.length >= _level.targetCount) {
          _won = true;
          _message ='Word Hive cleared!';
          _savePersistedLevel(_levelIndex);
        }
      });
    } else {
      setState(() {
        _message ='"$word"is not in our word list!';
        _currentGuess.clear();
        _selectedIndices.clear();
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
    final accentColor = AppTheme.accentFor('spellingbee');
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        backgroundColor: context.bgDark,
        foregroundColor: context.textPrimary,
        title: Text('Word Hive', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: context.textPrimary)),
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
            onPressed: () => RulesHelper.showRulesBottomSheet(context,'spellingbee','Word Hive'),
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
'Drag over letters to connect and form words',
                style: GoogleFonts.outfit(color: context.textSecondary, fontSize: context.scale(13)),
              ),
              const SizedBox(height: 8),
              Text(
'Find ${_level.targetCount} words containing"${_level.centerLetter}"',
                style: GoogleFonts.outfit(color: accentColor, fontSize: context.scale(13), fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              // Solved word display
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
              // Circular Honeycomb Layout
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
                        // Center letter button
                        GestureDetector(
                          onTap: () {
                            if (_won) return;
                            setState(() {
                              _currentGuess.add(_level.centerLetter);
                              _message = '';
                            });
                          },
                          child: Container(
                            width: context.scale(60),
                            height: context.scale(60),
                            decoration: BoxDecoration(
                              color: accentColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withAlpha(120), width: 2),
                            ),
                            child: Center(
                              child: Text(
                                _level.centerLetter,
                                style: GoogleFonts.outfit(
                                  fontSize: context.scale(24),
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Outer letter buttons (6 of them)
                        ...List.generate(6, (index) {
                          final angle = index * pi / 3 - pi / 6;
                          final radius = context.scale(75.0);
                          final x = radius * cos(angle);
                          final y = radius * sin(angle);
                          final letter = _level.outerLetters[index];

                          return Positioned(
                            left: context.scale(110) + x - context.scale(26),
                            top: context.scale(110) + y - context.scale(26),
                            child: GestureDetector(
                              onTap: () {
                                if (_won) return;
                                setState(() {
                                  _currentGuess.add(letter);
                                  _message = '';
                                });
                              },
                              child: Container(
                                width: context.scale(52),
                                height: context.scale(52),
                                decoration: BoxDecoration(
                                  color: context.bgCard,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: context.textMuted.withAlpha(100), width: 2),
                                ),
                                child: Center(
                                  child: Text(
                                    letter,
                                    style: GoogleFonts.outfit(
                                      fontSize: context.scale(20),
                                      fontWeight: FontWeight.w800,
                                      color: context.textPrimary,
                                    ),
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
              // Action buttons
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
