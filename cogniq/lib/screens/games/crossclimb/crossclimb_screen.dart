import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../utils/rules_helper.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/hint_manager.dart';

// Each level: 5 clues. Each answer shares a letter swap with next
class CrossClimbLevel {
  final List<String> clues;
  final List<String> answers;
  const CrossClimbLevel({required this.clues, required this.answers});
}

const List<CrossClimbLevel> _kLevels = [
  // Easy (3 letters)
  CrossClimbLevel(
    clues: ['Opposite of cold', 'Wear it on your hat', 'Feline pet', 'A taxi vehicle', 'A metal can'],
    answers: ['HOT', 'HAT', 'CAT', 'CAB', 'CAN'],
  ),
  CrossClimbLevel(
    clues: ['Move fast on foot', 'The star we orbit', 'A male offspring', 'Heavy weight unit', 'Number of fingers'],
    answers: ['RUN', 'SUN', 'SON', 'TON', 'TEN'],
  ),
  CrossClimbLevel(
    clues: ['Paper guide of the world', 'Tool to clean the floor', 'Fizzy soda drink', 'Cooking vessel', 'A small round mark'],
    answers: ['MAP', 'MOP', 'POP', 'POT', 'DOT'],
  ),
  // Medium (4 letters)
  CrossClimbLevel(
    clues: ['Not on time', 'A calendar day', 'Fenced entryway', 'Offered a gift', 'Underground stone chamber'],
    answers: ['LATE', 'DATE', 'GATE', 'GAVE', 'CAVE'],
  ),
  CrossClimbLevel(
    clues: ['Opposite of hot', 'A thin rope', 'Greeting or playing card', 'Hospital ward', 'Moderately hot'],
    answers: ['COLD', 'CORD', 'CARD', 'WARD', 'WARM'],
  ),
  CrossClimbLevel(
    clues: ['High quality or fine', 'A long thin line', 'A narrow road lane', 'Not arriving on time', 'Calendar day'],
    answers: ['FINE', 'LINE', 'LANE', 'LATE', 'DATE'],
  ),
  CrossClimbLevel(
    clues: ['Large sea ship', 'Store to buy things', 'Fired bullet or gun shot', 'Narrow slot for coins', 'Not moving fast'],
    answers: ['SHIP', 'SHOP', 'SHOT', 'SLOT', 'SLOW'],
  ),
  // Hard (5 letters)
  CrossClimbLevel(
    clues: ['A county or region', 'Divide with others', 'Land along the shore', 'A routine household chore', 'Struggling to breathe'],
    answers: ['SHIRE', 'SHARE', 'SHORE', 'CHORE', 'CHOKE'],
  ),
  CrossClimbLevel(
    clues: ['Ocean predator shark', 'Distribute portion with others', 'Land along the shore', 'Shop to purchase items', 'Small rock stone'],
    answers: ['SHARK', 'SHARE', 'SHORE', 'STORE', 'STONE'],
  ),
  CrossClimbLevel(
    clues: ['Green leafed living plant', 'Aircraft flying in sky', 'Flat plate for food', 'Writing chalkboard slate', 'Narrow slats of wood'],
    answers: ['PLANT', 'PLANE', 'PLATE', 'SLATE', 'SLATS'],
  ),
  CrossClimbLevel(
    clues: ['A round baking tin', 'Used to write on paper', 'A small metal needle pin', 'Cooking vessel pot', 'Opposite of cold'],
    answers: ['PAN', 'PEN', 'PIN', 'PIT', 'POT'],
  ),
  CrossClimbLevel(
    clues: ['A flying nocturnal bat', 'Feline animal pet', 'A taxi vehicle', 'A metal canister', 'A warm weather wind fan'],
    answers: ['BAT', 'CAT', 'CAB', 'CAN', 'FAN'],
  ),
  CrossClimbLevel(
    clues: ['Moderately hot', 'Hospital room ward', 'A playing card', 'To look after or feel concern', 'Naked or empty'],
    answers: ['WARM', 'WARD', 'CARD', 'CARE', 'BARE'],
  ),
  CrossClimbLevel(
    clues: ['Opposite of soft', 'A fast wild rabbit', 'Pay for temporary work', 'A metal strand cable', 'Opposite of narrow'],
    answers: ['HARD', 'HARE', 'HIRE', 'WIRE', 'WIDE'],
  ),
  CrossClimbLevel(
    clues: ['Land along the ocean edge', 'Distribute portion with others', 'Extra or backup resource', 'A tall church steeple', 'A sharp metal nail'],
    answers: ['SHORE', 'SHARE', 'SPARE', 'SPIRE', 'SPIKE'],
  ),
  CrossClimbLevel(
    clues: ['Opposite of dry', 'Feline or canine house animal', 'A deep cooking pot', 'A large amount or batch', 'Opposite of cold'],
    answers: ['WET', 'PET', 'POT', 'LOT', 'HOT'],
  ),
  CrossClimbLevel(
    clues: ['A small insect creep', 'To hold someone tightly', 'A large coffee cup', 'Floor covering mat', 'Move fast on foot'],
    answers: ['BUG', 'HUG', 'MUG', 'RUG', 'RUN'],
  ),
  CrossClimbLevel(
    clues: ['Make a hole in ground', 'Pink farm animal hog', 'False hair headpiece', 'Achieve victory', 'Fish swimming limb'],
    answers: ['DIG', 'PIG', 'WIG', 'WIN', 'FIN'],
  ),
  CrossClimbLevel(
    clues: ['Fleshy border of mouth', 'Drink in small mouthfuls', 'Gratuity or endpoint', 'The highest peak point', 'Plaything for children'],
    answers: ['LIP', 'SIP', 'TIP', 'TOP', 'TOY'],
  ),
  CrossClimbLevel(
    clues: ['Color of a ripe tomato', 'Furniture piece to sleep on', 'Opposite of good', 'Opposite of happy', 'Opposite of stood'],
    answers: ['RED', 'BED', 'BAD', 'SAD', 'SAT'],
  ),
  CrossClimbLevel(
    clues: ['Opposite of hot', 'Daring or courageous', 'Strong connection or tie', 'Group of musicians', 'Desert ground grains'],
    answers: ['COLD', 'BOLD', 'BOND', 'BAND', 'SAND'],
  ),
  CrossClimbLevel(
    clues: ['Opposite of wild', 'Unable to walk easily', 'Not arriving on time', 'A narrow street path', 'A large body of water'],
    answers: ['TAME', 'LAME', 'LATE', 'LANE', 'LAKE'],
  ),
  CrossClimbLevel(
    clues: ['Large sea boat', 'Accidentally fall or slide', 'Glided along a surface', 'Slender or thin body', 'Shut a door violently'],
    answers: ['SHIP', 'SLIP', 'SLID', 'SLIM', 'SLAM'],
  ),
  CrossClimbLevel(
    clues: ['High temperature warmth', 'Part of body with brain', 'Small round decorative bead', 'Large furry forest mammal', 'Teeth wheel in machinery'],
    answers: ['HEAT', 'HEAD', 'BEAD', 'BEAR', 'GEAR'],
  ),
  CrossClimbLevel(
    clues: ['Cognitive thought brain', 'Moving stream of air', 'Alcoholic grape drink', 'Long thin pencil mark', 'Excellent quality or fee'],
    answers: ['MIND', 'WIND', 'WINE', 'LINE', 'FINE'],
  ),
  CrossClimbLevel(
    clues: ['Gaze fixedly at something', 'Extra or backup key', 'A small glowing particle', 'Severe or completely bare', 'Begin a race or journey'],
    answers: ['STARE', 'SPARE', 'SPARK', 'STARK', 'START'],
  ),
  CrossClimbLevel(
    clues: ['Sugary tasting candy', 'Fabric piece on a bed', 'Utter or thin transparent', 'Woolly farm animal', 'Rest state of slumber'],
    answers: ['SWEET', 'SHEET', 'SHEER', 'SHEEP', 'SLEEP'],
  ),
  CrossClimbLevel(
    clues: ['Opposite of dark', 'Engage in physical combat', 'Ability to see with eyes', 'Opposite of day', 'Great strength or power'],
    answers: ['LIGHT', 'FIGHT', 'SIGHT', 'NIGHT', 'MIGHT'],
  ),
  CrossClimbLevel(
    clues: ['Cost of an item', 'Self-respect or satisfaction', 'Peak or of first rate', 'Illegal act offense', 'Musical bell sound'],
    answers: ['PRICE', 'PRIDE', 'PRIME', 'CRIME', 'CHIME'],
  ),
  CrossClimbLevel(
    clues: ['Water vapor gas', 'Take without permission', 'Strong iron metal alloy', 'Guide a car wheel', 'Absolute or thin fabric'],
    answers: ['STEAM', 'STEAL', 'STEEL', 'STEER', 'SHEER'],
  ),
  CrossClimbLevel(
    clues: ['A false statement', 'Part of mouth edge', 'Place on your knees', 'Paper world guide', 'Floor cleaning tool'],
    answers: ['LIE', 'LIP', 'LAP', 'MAP', 'MOP'],
  ),
  CrossClimbLevel(
    clues: ['A young boy child', 'Opposite of happy', 'Extremely angry', 'Paper world guide', 'Floor welcome rug'],
    answers: ['LAD', 'SAD', 'MAD', 'MAP', 'MAT'],
  ),
  CrossClimbLevel(
    clues: ['To run away flee', 'Warm weather wind maker', 'Fish breathing organ', 'Sharp metal needle pin', 'Cooking deep hole pit'],
    answers: ['RUN', 'FUN', 'FIN', 'PIN', 'PIT'],
  ),
  CrossClimbLevel(
    clues: ['Accidentally fall or slide', 'Slender and thin body', 'Shut a door violently', 'Shelled seafood creature', 'Pottery modeling earth'],
    answers: ['SLIP', 'SLIM', 'SLAM', 'CLAM', 'CLAY'],
  ),
  CrossClimbLevel(
    clues: ['Fenced yard entrance', 'Gave a present gift', 'Underground stone chamber', 'A box or folder instance', 'Throw a line fishing'],
    answers: ['GATE', 'GAVE', 'CAVE', 'CASE', 'CAST'],
  ),
  CrossClimbLevel(
    clues: ['Daring or courageous', 'Connection or tie', 'Group of musicians', 'Place to deposit money', 'Sound a dog makes'],
    answers: ['BOLD', 'BOND', 'BAND', 'BANK', 'BARK'],
  ),
  CrossClimbLevel(
    clues: ['Opposite of wild', 'Not arriving on time', 'Narrow street road lane', 'Large body of water', 'Late autumn fall wind'],
    answers: ['TAME', 'LATE', 'LANE', 'LAKE', 'GALE'],
  ),
  CrossClimbLevel(
    clues: ['Timepiece instrument', 'Group of sheep or birds', 'Quick motion snap', 'Smooth and shiny surface', 'Single portion of cake'],
    answers: ['CLOCK', 'FLOCK', 'FLICK', 'SLICK', 'SLICE'],
  ),
  CrossClimbLevel(
    clues: ['Home building dwelling', 'Small rodent animal', 'Awaken from sleep', 'Path or roadway travel', 'Defeats in battle'],
    answers: ['HOUSE', 'MOUSE', 'ROUSE', 'ROUTE', 'ROUTS'],
  ),
  CrossClimbLevel(
    clues: ['Liquid we drink', 'Flicker or hesitate', 'One who rescues or stores', 'Cut off or divide', 'High body temperature'],
    answers: ['WATER', 'WAVER', 'SAVER', 'SEVER', 'FEVER'],
  ),
  // 10 new levels
  CrossClimbLevel(
    clues: ['Opposite of girl', 'Plaything for kids', 'Also or excessively', 'Number after one', 'Inquiring about a person'],
    answers: ['BOY', 'TOY', 'TOO', 'TWO', 'WHO'],
  ),
  CrossClimbLevel(
    clues: ['Sharp metal needle', 'Writing tool with ink', 'Number of fingers', 'Skin color from sun', 'Apparatus for cooling air'],
    answers: ['PIN', 'PEN', 'TEN', 'TAN', 'FAN'],
  ),
  CrossClimbLevel(
    clues: ['Covered with water', 'House-trained animal', 'Deep cooking vessel', 'Decompose or decay', 'Adverb of negation'],
    answers: ['WET', 'PET', 'POT', 'ROT', 'NOT'],
  ),
  CrossClimbLevel(
    clues: ['Activity played for fun', 'Arrived at a place', 'Underground stone chamber', 'A box or instance', 'Throw a fishing line'],
    answers: ['GAME', 'CAME', 'CAVE', 'CASE', 'CAST'],
  ),
  CrossClimbLevel(
    clues: ['Belonging to me', 'Brain power or attention', 'Moving stream of air', 'Alcoholic grape beverage', 'Long thin mark'],
    answers: ['MINE', 'MIND', 'WIND', 'WINE', 'LINE'],
  ),
  CrossClimbLevel(
    clues: ['Do physical or mental labor', 'Single unit of language', 'Hospital room division', 'Moderately hot temperature', 'Creepy crawler in soil'],
    answers: ['WORK', 'WORD', 'WARD', 'WARM', 'WORM'],
  ),
  CrossClimbLevel(
    clues: ['Intelligent or clever', 'Begin a race or journey', 'Gaze fixedly at something', 'Shop to purchase items', 'Small hard rock piece'],
    answers: ['SMART', 'START', 'STARE', 'STORE', 'STONE'],
  ),
  CrossClimbLevel(
    clues: ['Green lawn ground cover', 'Transparent window material', 'Group of students in school', 'Fight or conflict', 'Accident or collision'],
    answers: ['GRASS', 'GLASS', 'CLASS', 'CLASH', 'CRASH'],
  ),
  CrossClimbLevel(
    clues: ['Running path or trail', 'A magic stunt or prank', 'Make a small hole with pin', 'Cost of an item', 'Self-respect or satisfaction'],
    answers: ['TRACK', 'TRICK', 'PRICK', 'PRICE', 'PRIDE'],
  ),
  CrossClimbLevel(
    clues: ['Baking powder ingredient', 'Ground surface in a room', 'Overflow of water', 'Red fluid in veins', 'Group of young birds'],
    answers: ['FLOUR', 'FLOOR', 'FLOOD', 'BLOOD', 'BROOD'],
  ),
  // 10 new levels
  CrossClimbLevel(
    clues: ['Writing tool', 'Sharp metal needle', 'Fruit stone or seed hole', 'Cooking vessel', 'Small round mark'],
    answers: ['PEN', 'PIN', 'PIT', 'POT', 'DOT'],
  ),
  CrossClimbLevel(
    clues: ['Move fast on foot', 'Amusement or enjoyment', 'Fish breathing limb', 'Healthy and in good shape', 'Rest on a chair'],
    answers: ['RUN', 'FUN', 'FIN', 'FIT', 'SIT'],
  ),
  CrossClimbLevel(
    clues: ['Opposite of happy', 'Opposite of good', 'Furniture piece to sleep on', 'Color of a tomato', 'Thin straight metal or wood bar'],
    answers: ['SAD', 'BAD', 'BED', 'RED', 'ROD'],
  ),
  CrossClimbLevel(
    clues: ['Not on time', 'Narrow street or road', 'Large body of water', 'Have a preference for', 'Long thin pencil mark'],
    answers: ['LATE', 'LANE', 'LAKE', 'LIKE', 'LINE'],
  ),
  CrossClimbLevel(
    clues: ['Large ocean vessel', 'Place to buy things', 'Fired bullet or gun attempt', 'Narrow opening for coins', 'Black powder from chimney'],
    answers: ['SHIP', 'SHOP', 'SHOT', 'SLOT', 'SOOT'],
  ),
  CrossClimbLevel(
    clues: ['Activity played for fun', 'Not wild or domestic', 'Clock measurement', 'Rising and falling sea level', 'Travel on a horse or bicycle'],
    answers: ['GAME', 'TAME', 'TIME', 'TIDE', 'RIDE'],
  ),
  CrossClimbLevel(
    clues: ['Outline or copy a drawing', 'Running path or trail', 'A magic stunt or prank', 'Make a small puncture with pin', 'Cost of a purchased item'],
    answers: ['TRACE', 'TRACK', 'TRICK', 'PRICK', 'PRICE'],
  ),
  CrossClimbLevel(
    clues: ['Baking powder ingredient', 'Surface we walk on in a room', 'Overflow of water', 'Red fluid in veins', 'Fair-haired or pale yellow'],
    answers: ['FLOUR', 'FLOOR', 'FLOOD', 'BLOOD', 'BLOND'],
  ),
  CrossClimbLevel(
    clues: ['Railway steam engine vehicle', 'Wheat cereal seed crop', 'Pipe to carry off wastewater', 'Cognitive thought organ', 'Product name mark'],
    answers: ['TRAIN', 'GRAIN', 'DRAIN', 'BRAIN', 'BRAND'],
  ),
  CrossClimbLevel(
    clues: ['Writing board of gray stone', 'Flat dish for food', 'Location or setting', 'Freedom from war or quietness', 'Sweet orange fruit with fuzzy skin'],
    answers: ['SLATE', 'PLATE', 'PLACE', 'PEACE', 'PEACH'],
  ),
];

class CrossClimbScreen extends StatefulWidget {
  const CrossClimbScreen({super.key});
  @override
  State<CrossClimbScreen> createState() => _CrossClimbScreenState();
}

class _CrossClimbScreenState extends State<CrossClimbScreen> {
  int _levelIndex = 0;
  late CrossClimbLevel _level;
  late List<String?> _slots; // 5 slots, null = empty
  late List<String> _shuffledAnswers; // Shuffled answer tiles
  String? _selectedTile; // For tap-to-place flow
  late List<bool?> _results; // null = unchecked/neutral, true = correct, false = wrong
  bool _won = false;

  int _hintCount = 0;

  @override
  void initState() {
    super.initState();
    _level = _kLevels[0];
    _slots = List.filled(5, null);
    _shuffledAnswers = [];
    _results = List.filled(5, null);
    _initLevel();
  }

  Future<void> _initLevel() async {
    _hintCount = await HintManager.getHints('crossclimb');
    final prefs = await SharedPreferences.getInstance();
    final savedLevel = prefs.getInt('level_crossclimb') ?? 0;
    if (mounted) {
      setState(() {
        _levelIndex = savedLevel % _kLevels.length;
        _loadLevel();
      });
    }
  }

  Future<void> _savePersistedLevel(int lvl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('level_crossclimb', lvl);
    final earned = await HintManager.onLevelCleared('crossclimb');
    final newCount = await HintManager.getHints('crossclimb');
    setState(() {
      _hintCount = newCount;
    });
    if (earned && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hint earned! (Total: $newCount)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: AppTheme.accentFor('crossclimb'),
        ),
      );
    }
  }

  Future<void> _useHint() async {
    if (_won || _hintCount <= 0) return;
    int idx = -1;
    for (int i = 0; i < _level.answers.length; i++) {
      if (_slots[i] != _level.answers[i]) {
        idx = i;
        break;
      }
    }
    if (idx == -1) return;

    await HintManager.useHint('crossclimb');
    final newCount = await HintManager.getHints('crossclimb');
    setState(() {
      _hintCount = newCount;
      final correctWord = _level.answers[idx];
      // If correctWord was in another slot, clear it
      final existingIdx = _slots.indexOf(correctWord);
      if (existingIdx != -1) {
        _slots[existingIdx] = null;
      }
      // If a word was in this slot, return it to pool
      final replacedWord = _slots[idx];
      if (replacedWord != null && !_shuffledAnswers.contains(replacedWord)) {
        _shuffledAnswers.add(replacedWord);
      }
      // Remove correctWord from pool
      _shuffledAnswers.remove(correctWord);
      _slots[idx] = correctWord;
      _results[idx] = true;
      _won = _slots.every((w) => w != null) && List.generate(5, (i) => _slots[i] == _level.answers[i]).every((r) => r);
      if (_won) {
        _savePersistedLevel(_levelIndex);
      }
    });
  }

  void _loadLevel() {
    _level = _kLevels[_levelIndex % _kLevels.length];
    _slots = List.filled(_level.clues.length, null);
    _shuffledAnswers = List<String>.from(_level.answers)..shuffle();
    _selectedTile = null;
    _results = List.filled(_level.clues.length, null);
    _won = false;
  }

  void _check() {
    final newResults = List<bool?>.filled(_level.answers.length, null);
    for (int i = 0; i < _level.answers.length; i++) {
      newResults[i] = _slots[i] == _level.answers[i];
    }
    setState(() {
      _results = newResults;
      _won = newResults.every((r) => r == true);
      if (_won) {
        _savePersistedLevel(_levelIndex);
      }
    });
  }

  void _reset() {
    setState(() {
      _loadLevel();
    });
  }

  void _nextLevel() {
    setState(() {
      _levelIndex = (_levelIndex + 1) % _kLevels.length;
      _savePersistedLevel(_levelIndex);
      _loadLevel();
    });
  }

  void _selectTile(String tile) {
    if (_won) return;
    setState(() {
      if (_selectedTile == tile) {
        _selectedTile = null;
      } else {
        _selectedTile = tile;
      }
    });
  }

  void _placeTile(int slotIdx) {
    if (_won) return;
    setState(() {
      // If a tile is selected, place it here
      if (_selectedTile != null) {
        final placedTile = _selectedTile!;
        // If this slot already has a tile, return it to pool
        final prevTile = _slots[slotIdx];
        if (prevTile != null) {
          _shuffledAnswers.add(prevTile);
        }
        // Place new tile
        _slots[slotIdx] = placedTile;
        _shuffledAnswers.remove(placedTile);
        _selectedTile = null;
        _results[slotIdx] = null; // Reset result status
      } else {
        // No tile selected, tap to remove tile from slot back to pool
        final tile = _slots[slotIdx];
        if (tile != null) {
          _slots[slotIdx] = null;
          _shuffledAnswers.add(tile);
          _results[slotIdx] = null;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        backgroundColor: context.bgDark, foregroundColor: context.textPrimary,
        title: Text('Word Climb', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: context.textPrimary)),
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
            onPressed: () => RulesHelper.showRulesBottomSheet(context, 'crossclimb', 'Word Climb'),
          ),
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _reset, color: context.textMuted),
          Padding(padding: const EdgeInsets.only(right: 12), child: Center(child: Text('Level ${_levelIndex + 1}', style: GoogleFonts.outfit(color: AppTheme.crossclimbPurple, fontSize: context.scale(13))))),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text('Climb the word ladder! Drag or tap words to arrange them. Each word swaps exactly ONE letter.', style: GoogleFonts.outfit(color: context.textSecondary, fontSize: context.scale(13)), textAlign: TextAlign.center),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                ...List.generate(_level.clues.length, (i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Ladder connector
                      SizedBox(
                        width: context.scale(28),
                        child: Column(
                          children: [
                            Container(
                              width: context.scale(28),
                              height: context.scale(28),
                              decoration: BoxDecoration(
                                color: AppTheme.crossclimbPurple.withOpacity(0.2),
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.crossclimbPurple.withOpacity(0.7), width: 1.5),
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: GoogleFonts.outfit(
                                    color: AppTheme.crossclimbPurple,
                                    fontWeight: FontWeight.w700,
                                    fontSize: context.scale(12),
                                  ),
                                ),
                              ),
                            ),
                            if (i < _level.clues.length - 1)
                              Container(
                                width: 2,
                                height: context.scale(45),
                                color: AppTheme.crossclimbPurple.withOpacity(0.3),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_level.clues[i], style: GoogleFonts.outfit(color: context.textPrimary, fontSize: context.scale(13))),
                            const SizedBox(height: 4),
                            DragTarget<String>(
                              onAcceptWithDetails: (details) {
                                final data = details.data;
                                setState(() {
                                  // Clear other slot if it was there
                                  final oldIdx = _slots.indexOf(data);
                                  if (oldIdx != -1) {
                                    _slots[oldIdx] = null;
                                  }
                                  final prev = _slots[i];
                                  if (prev != null) {
                                    _shuffledAnswers.add(prev);
                                  }
                                  _slots[i] = data;
                                  _shuffledAnswers.remove(data);
                                  _results[i] = null;
                                });
                              },
                              builder: (context, candidateData, rejectedData) {
                                final currentWord = _slots[i];
                                return GestureDetector(
                                  onTap: () => _placeTile(i),
                                  child: Container(
                                    height: context.scale(42),
                                    decoration: BoxDecoration(
                                      color: currentWord != null ? AppTheme.crossclimbPurple.withOpacity(0.15) : context.bgSurface,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _results[i] != null
                                            ? (_results[i]! ? AppTheme.wordleGreen : Colors.redAccent)
                                            : (currentWord != null ? AppTheme.crossclimbPurple : AppTheme.crossclimbPurple.withOpacity(0.3)),
                                        width: currentWord != null ? 2 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(left: 12),
                                          child: Text(
                                            currentWord ?? ('• ' * _level.answers[i].length),
                                            style: GoogleFonts.outfit(
                                              color: currentWord != null ? context.textPrimary : context.textMuted.withOpacity(0.4),
                                              fontWeight: FontWeight.bold,
                                              fontSize: context.scale(15),
                                              letterSpacing: 2,
                                            ),
                                          ),
                                        ),
                                        if (_results[i] != null)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 12),
                                            child: Icon(
                                              _results[i]! ? Icons.check_circle : Icons.cancel,
                                              color: _results[i]! ? AppTheme.wordleGreen : Colors.redAccent,
                                              size: 20,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 24),
                if (!_won) ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crossclimbPurple, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: _check,
                  child: Text('Check Answers', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700, fontSize: context.scale(14))),
                ),
                if (_won) ...[
                  Text('You climbed to the top!', style: GoogleFonts.outfit(fontSize: context.scale(20), color: AppTheme.crossclimbPurple, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crossclimbPurple, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: _nextLevel,
                    child: Text('Next Level →', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700, fontSize: context.scale(14))),
                  ),
                ],
              ]),
            ),
          ),
          // Word tile pool at bottom
          if (!_won && _shuffledAnswers.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              color: context.bgSurface,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Word Pool:', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: context.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _shuffledAnswers.map((word) {
                      final isSelected = _selectedTile == word;
                      return Draggable<String>(
                        data: word,
                        feedback: Material(
                          color: Colors.transparent,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.crossclimbPurple,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              word,
                              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        childWhenDragging: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: context.bgDark.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: context.textMuted.withOpacity(0.2)),
                          ),
                          child: Text(
                            word,
                            style: GoogleFonts.outfit(color: context.textMuted, fontWeight: FontWeight.bold),
                          ),
                        ),
                        child: GestureDetector(
                          onTap: () => _selectTile(word),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.crossclimbPurple : AppTheme.crossclimbPurple.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? AppTheme.crossclimbPurple : AppTheme.crossclimbPurple.withOpacity(0.4),
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              word,
                              style: GoogleFonts.outfit(
                                color: isSelected ? Colors.white : context.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
