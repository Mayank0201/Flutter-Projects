import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../utils/rules_helper.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/hint_manager.dart';

// Each level: [startWord, ...intermediates(optional), endWord]
// User must type intermediate words that differ by 1 letter
const List<List<String>> _kLevels = [
  // Easy (3 letters)
  ['CAT', 'COT', 'COG', 'DOG'],
  ['HOT', 'HOP', 'MOP', 'MAP'],
  ['BOY', 'TOY', 'TOO', 'TWO'],
  ['BAT', 'CAT', 'COT', 'DOG'],
  ['WET', 'PET', 'POT', 'ROT'],
  // Medium (4 letters)
  ['COLD', 'CORD', 'WORD', 'WARD', 'WARM'],
  ['GAME', 'CAME', 'CAVE', 'LAVE', 'LIVE'],
  ['HEAD', 'HEAT', 'HEAP', 'REAP', 'READ'],
  ['FIRE', 'FARE', 'FATE', 'GATE', 'GAVE'],
  ['WORK', 'WORD', 'WARD', 'WARM', 'WORM'],
  // Hard (5 letters)
  ['GREAT', 'GREET', 'GREEN', 'GREED', 'CREED'],
  ['SHARK', 'SHARE', 'SHORE', 'STORE', 'STONE'],
  ['CLOCK', 'FLOCK', 'FLICK', 'SLICK', 'SLICE'],
  ['WATER', 'WAVER', 'SAVER', 'SEVER', 'FEVER'],
  ['HOUSE', 'MOUSE', 'ROUSE', 'ROUTE', 'ROOTS'],
  // Expansions
  ['SUN', 'RUN', 'RAN', 'MAN'],
  ['LATE', 'LANE', 'LINE', 'FINE'],
  ['GATE', 'FATE', 'FACE', 'FACT'],
  ['PLANT', 'PLANE', 'PLATE', 'SLATE'],
  ['SHIRT', 'SHIFT', 'SWIFT'],
  ['BAT', 'CAT', 'HAT', 'HOT'],
  ['PIN', 'PEN', 'TEN', 'TAN'],
  ['BEAR', 'BEAD', 'HEAD', 'HEAT'],
  ['GATE', 'LATE', 'LANE', 'LINE'],
  ['MORE', 'SORE', 'SOLE', 'SALE'],
  ['WIND', 'WINE', 'LINE', 'FINE'],
  ['STARE', 'SPARE', 'SPARK', 'STARK'],
  ['SWEET', 'SHEET', 'SHEEP', 'SLEEP'],
  ['PRICE', 'PRIDE', 'PRIME', 'CRIME'],
  ['STEAM', 'STEAL', 'STEEL', 'STEER'],
  ['WOOD', 'FOOD', 'FOOT', 'SOOT', 'BOOT'],
  ['WIND', 'WINE', 'LINE', 'LINT', 'LOST'],
  ['BEER', 'BEAR', 'BEAD', 'HEAD', 'HERD'],
  ['RUST', 'MUST', 'MUTE', 'MATE', 'LATE'],
  ['SHIP', 'SLIP', 'SLIT', 'SLOT', 'SHOT'],
  ['COAL', 'COAT', 'BOAT', 'BEAT', 'BEAR'],
  ['GRIN', 'GRIP', 'DRIP', 'DROP', 'CROP'],
  ['WAVE', 'WANE', 'WINE', 'WIND'],
  ['LOCK', 'LOOK', 'BOOK', 'BOOT', 'BOAT'],
  ['GOLD', 'COLD', 'CORD', 'CARD', 'WARD'],
  // 10 new levels
  ['POT', 'PAT', 'RAT', 'RAM'],
  ['SAD', 'MAD', 'MAN', 'PAN'],
  ['NET', 'NOT', 'HOT', 'HAT'],
  ['SURE', 'PURE', 'PARE', 'PART'],
  ['LION', 'LOON', 'LOOK', 'BOOK'],
  ['MIND', 'MINT', 'MIST', 'MOST'],
  ['SMART', 'START', 'STARE', 'STORE', 'STONE'],
  ['GRASS', 'GLASS', 'CLASS', 'CLASH', 'CRASH'],
  ['TRACK', 'TRICK', 'PRICK', 'PRICE', 'PRIDE'],
  ['FLOUR', 'FLOOR', 'FLOOD', 'BLOOD', 'BROOD', 'BROAD'],
];

class WeaverScreen extends StatefulWidget {
  const WeaverScreen({super.key});
  @override
  State<WeaverScreen> createState() => _WeaverScreenState();
}

class _WeaverScreenState extends State<WeaverScreen> {
  int _levelIndex = 0;
  late List<String> _chain;
  late List<String> _scrambledIntermediates;
  bool _won = false;
  int _hintCount = 0;

  @override
  void initState() {
    super.initState();
    // Default synchronous initialization to avoid LateInitializationError
    _chain = [''];
    _scrambledIntermediates = [];
    _initLevel();
  }

  Future<void> _initLevel() async {
    _hintCount = await HintManager.getHints('weaver');
    final prefs = await SharedPreferences.getInstance();
    final savedLevel = prefs.getInt('level_weaver') ?? 0;
    if (mounted) {
      setState(() {
        _levelIndex = savedLevel % _kLevels.length;
        _loadLevel();
      });
    }
  }

  Future<void> _savePersistedLevel(int lvl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('level_weaver', lvl);
    final earned = await HintManager.onLevelCleared('weaver');
    final newCount = await HintManager.getHints('weaver');
    setState(() {
      _hintCount = newCount;
    });
    if (earned && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hint earned! (Total: $newCount)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: AppTheme.accentFor('weaver'),
        ),
      );
    }
  }

  Future<void> _useHint() async {
    if (_won || _hintCount <= 0) return;

    // Find the first correct intermediate word that is not in the correct place
    int targetIndex = -1;
    for (int i = 1; i < _chain.length - 1; i++) {
      final correctWord = _chain[i];
      final currentWordAtIdx = _scrambledIntermediates[i - 1];
      if (correctWord != currentWordAtIdx) {
        targetIndex = i - 1; // 0-indexed in _scrambledIntermediates
        break;
      }
    }

    if (targetIndex != -1) {
      final correctWord = _chain[targetIndex + 1];
      await HintManager.useHint('weaver');
      final newCount = await HintManager.getHints('weaver');

      setState(() {
        _hintCount = newCount;
        // Move correctWord from its current position in _scrambledIntermediates to targetIndex
        final currentPos = _scrambledIntermediates.indexOf(correctWord);
        if (currentPos != -1) {
          _scrambledIntermediates.removeAt(currentPos);
          _scrambledIntermediates.insert(targetIndex, correctWord);
        }
        _won = _checkWin();
        if (_won) {
          _savePersistedLevel(_levelIndex);
        }
      });
    }
  }

  void _loadLevel() {
    _chain = _kLevels[_levelIndex % _kLevels.length];
    
    // Intermediate words to scramble
    final intermediates = _chain.sublist(1, _chain.length - 1);
    final correctOrder = List<String>.from(intermediates);
    final scrambled = List<String>.from(intermediates);
    
    if (scrambled.length > 1) {
      int attempts = 0;
      while (attempts < 20 && _isCorrectOrder(scrambled, correctOrder)) {
        scrambled.shuffle();
        attempts++;
      }
    }
    
    _scrambledIntermediates = scrambled;
    _won = _checkWin();
  }

  bool _isCorrectOrder(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _diffByOne(String a, String b) {
    if (a.length != b.length) return false;
    int diffs = 0;
    for (int i = 0; i < a.length; i++) { if (a[i] != b[i]) diffs++; }
    return diffs == 1;
  }

  bool _checkWin() {
    final fullList = [_chain.first, ..._scrambledIntermediates, _chain.last];
    for (int i = 0; i < fullList.length - 1; i++) {
      if (!_diffByOne(fullList[i], fullList[i + 1])) {
        return false;
      }
    }
    return true;
  }

  void _reset() => setState(() => _loadLevel());
  
  void _nextLevel() {
    setState(() {
      _levelIndex = (_levelIndex + 1) % _kLevels.length;
      _savePersistedLevel(_levelIndex);
      _loadLevel();
    });
  }

  Widget _buildConnector(bool active) {
    return Container(
      height: 24,
      width: 2,
      color: active ? Colors.green : context.textMuted.withOpacity(0.2),
    );
  }

  Widget _buildStartCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.weaverBlue.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.weaverBlue, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _chain.first,
            style: GoogleFonts.outfit(
              fontSize: context.scale(20),
              fontWeight: FontWeight.w800,
              color: AppTheme.weaverBlue,
              letterSpacing: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEndCard() {
    final lastIntermediate = _scrambledIntermediates.isNotEmpty ? _scrambledIntermediates.last : _chain.first;
    final isConnected = _diffByOne(lastIntermediate, _chain.last);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildConnector(isConnected),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.zipPink.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.zipPink, width: 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _chain.last,
                style: GoogleFonts.outfit(
                  fontSize: context.scale(20),
                  fontWeight: FontWeight.w800,
                  color: AppTheme.zipPink,
                  letterSpacing: 4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScrambledItem(String word, int index) {
    final prevWord = index == 0 ? _chain.first : _scrambledIntermediates[index - 1];
    final isConnected = _diffByOne(prevWord, word);

    return Column(
      key: ValueKey(word),
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildConnector(isConnected),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          color: context.bgSurface,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isConnected ? Colors.green.withOpacity(0.5) : context.textMuted.withOpacity(0.2),
              width: isConnected ? 2 : 1,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Icon(
              Icons.drag_handle,
              color: context.textMuted,
            ),
            title: Text(
              word,
              style: GoogleFonts.outfit(
                fontSize: context.scale(18),
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
                letterSpacing: 4,
              ),
              textAlign: TextAlign.center,
            ),
            trailing: isConnected
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.error_outline, color: Colors.orange),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        backgroundColor: context.bgDark,
        foregroundColor: context.textPrimary,
        title: Text('Word Ladder', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: context.textPrimary)),
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
            onPressed: () => RulesHelper.showRulesBottomSheet(context, 'weaver', 'Word Ladder'),
          ),
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _reset, color: context.textMuted),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                'Level ${_levelIndex + 1}',
                style: GoogleFonts.outfit(color: AppTheme.weaverBlue, fontSize: context.scale(13)),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Drag the intermediate tiles to arrange them in order. Every connected card must differ by exactly one letter.',
                  style: GoogleFonts.outfit(
                    color: context.textSecondary,
                    fontSize: context.scale(14),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              
              _buildStartCard(),
              
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    final item = _scrambledIntermediates.removeAt(oldIndex);
                    _scrambledIntermediates.insert(newIndex, item);
                    _won = _checkWin();
                    if (_won) {
                      _savePersistedLevel(_levelIndex);
                    }
                  });
                },
                children: [
                  for (int i = 0; i < _scrambledIntermediates.length; i++)
                    _buildScrambledItem(_scrambledIntermediates[i], i),
                ],
              ),
              
              _buildEndCard(),
              
              if (_won) ...[
                const SizedBox(height: 24),
                Text(
                  'Connected successfully!',
                  style: GoogleFonts.outfit(
                    fontSize: context.scale(18),
                    color: AppTheme.weaverBlue,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.weaverBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _nextLevel,
                  child: Text(
                    'Next Level →',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: context.scale(14),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
