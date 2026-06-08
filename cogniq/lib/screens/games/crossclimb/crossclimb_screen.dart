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
  late List<bool?> _results; // null = unchecked/neutral, true = correct, false = wrong
  bool _won = false;
  int _hintCount = 0;

  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _level = _kLevels[0];
    _controllers = List.generate(3, (_) => TextEditingController());
    _focusNodes = List.generate(3, (_) => FocusNode());
    for (final node in _focusNodes) {
      node.addListener(() {
        if (mounted) setState(() {});
      });
    }
    _results = List.filled(5, null);
    _initLevel();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _initLevel() async {
    _hintCount = await HintManager.getHints('crossclimb');
    final prefs = await SharedPreferences.getInstance();
    final savedLevel = prefs.getInt('level_crossclimb') ?? 0;
    if (mounted) {
      setState(() {
        _levelIndex = savedLevel % _kLevels.length;
        _loadLevel(prefs);
      });
    }
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('crossclimb_slots', _controllers.map((c) => c.text).toList());
    await prefs.setBool('crossclimb_won', _won);
  }

  Future<void> _clearState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('crossclimb_slots');
    await prefs.remove('crossclimb_won');
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

  bool _differsByOne(String? a, String? b) {
    if (a == null || b == null) return false;
    final cleanA = a.trim().toUpperCase();
    final cleanB = b.trim().toUpperCase();
    if (cleanA.isEmpty || cleanB.isEmpty) return false;
    if (cleanA.length != cleanB.length) return false;
    int diff = 0;
    for (int i = 0; i < cleanA.length; i++) {
      if (cleanA[i] != cleanB[i]) {
        diff++;
        if (diff > 1) return false;
      }
    }
    return diff == 1;
  }

  Future<void> _useHint() async {
    if (_won || _hintCount <= 0) return;

    await HintManager.useHint('crossclimb');
    final newCount = await HintManager.getHints('crossclimb');

    setState(() {
      _hintCount = newCount;
      int idx = -1;
      for (int i = 1; i <= 3; i++) {
        if (_controllers[i - 1].text.toUpperCase().trim() != _level.answers[i]) {
          idx = i;
          break;
        }
      }
      if (idx != -1) {
        _controllers[idx - 1].text = _level.answers[idx];
        _results[idx] = true;

        bool allCorrect = true;
        for (int i = 1; i <= 3; i++) {
          if (_controllers[i - 1].text.toUpperCase().trim() != _level.answers[i]) {
            allCorrect = false;
          }
        }
        if (allCorrect) {
          _won = true;
          _savePersistedLevel(_levelIndex);
          _clearState();
        } else {
          _saveState();
        }
      }
    });
  }

  void _loadLevel([SharedPreferences? prefs]) {
    _level = _kLevels[_levelIndex % _kLevels.length];

    if (prefs != null && prefs.containsKey('crossclimb_slots')) {
      final savedSlots = prefs.getStringList('crossclimb_slots');
      if (savedSlots != null && savedSlots.length == 3) {
        for (int i = 0; i < 3; i++) {
          _controllers[i].text = savedSlots[i];
        }
      } else {
        for (int i = 0; i < 3; i++) {
          _controllers[i].clear();
        }
      }
      _won = prefs.getBool('crossclimb_won') ?? false;
      _results = List.filled(5, null);
      return;
    }

    for (int i = 0; i < 3; i++) {
      _controllers[i].clear();
    }
    _results = List.filled(5, null);
    _won = false;
    _clearState();
  }

  void _check() {
    final newResults = List<bool?>.filled(5, null);
    bool allCorrect = true;
    for (int i = 1; i <= 3; i++) {
      final input = _controllers[i - 1].text.toUpperCase().trim();
      final correct = input == _level.answers[i];
      newResults[i] = correct;
      if (!correct) allCorrect = false;
    }
    setState(() {
      _results = newResults;
      if (allCorrect) {
        _won = true;
        _savePersistedLevel(_levelIndex);
        _clearState();
      } else {
        _saveState();
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

  Widget _buildNumberCircle(int num) {
    return Container(
      width: context.scale(28),
      height: context.scale(28),
      decoration: BoxDecoration(
        color: AppTheme.crossclimbPurple.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.crossclimbPurple.withOpacity(0.7), width: 1.5),
      ),
      child: Center(
        child: Text(
          '$num',
          style: GoogleFonts.outfit(
            color: AppTheme.crossclimbPurple,
            fontWeight: FontWeight.w700,
            fontSize: context.scale(12),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectorLine(String? wordA, String? wordB) {
    final connected = _differsByOne(wordA, wordB);
    return Center(
      child: Container(
        width: 4,
        height: 24,
        decoration: BoxDecoration(
          color: connected ? AppTheme.wordleGreen : Colors.redAccent.withOpacity(0.4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildBookendRow(int idx, String label) {
    final word = _level.answers[idx];
    return Row(
      children: [
        _buildNumberCircle(idx + 1),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: context.scale(42),
            decoration: BoxDecoration(
              color: context.bgSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.textMuted.withAlpha(60), width: 1.2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    word,
                    style: GoogleFonts.outfit(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: context.scale(15),
                      letterSpacing: 2,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.crossclimbPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      label,
                      style: GoogleFonts.outfit(
                        color: AppTheme.crossclimbPurple,
                        fontSize: context.scale(10),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSolvingRow(int slotIdx) {
    final controller = _controllers[slotIdx - 1];
    final focusNode = _focusNodes[slotIdx - 1];
    final answerWord = _level.answers[slotIdx];
    final wordLen = answerWord.length;
    final text = controller.text;
    final result = _results[slotIdx];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(
          color: result != null
              ? (result ? AppTheme.wordleGreen.withOpacity(0.5) : Colors.redAccent.withOpacity(0.5))
              : (focusNode.hasFocus ? AppTheme.crossclimbPurple.withOpacity(0.5) : Colors.transparent),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildNumberCircle(slotIdx + 1),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _level.clues[slotIdx],
                  style: GoogleFonts.outfit(
                    color: context.textPrimary,
                    fontSize: context.scale(13),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (result != null)
                Icon(
                  result ? Icons.check_circle : Icons.cancel,
                  color: result ? AppTheme.wordleGreen : Colors.redAccent,
                  size: 20,
                ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              focusNode.requestFocus();
            },
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(wordLen, (charIdx) {
                final char = charIdx < text.length ? text[charIdx].toUpperCase() : '';
                final isCurrentChar = charIdx == text.length && focusNode.hasFocus;
                return Container(
                  width: context.scale(38),
                  height: context.scale(38),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: focusNode.hasFocus ? AppTheme.crossclimbPurple.withOpacity(0.05) : context.bgSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: result != null
                          ? (result ? AppTheme.wordleGreen : Colors.redAccent)
                          : (isCurrentChar
                              ? AppTheme.crossclimbPurple
                              : (char.isNotEmpty ? context.textPrimary.withOpacity(0.6) : context.textMuted.withAlpha(60))),
                      width: isCurrentChar || result != null ? 2 : 1.2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      char,
                      style: GoogleFonts.outfit(
                        fontSize: context.scale(16),
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          SizedBox(
            width: 0,
            height: 0,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              maxLength: wordLen,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
              ),
              onChanged: (val) {
                setState(() {
                  _results[slotIdx] = null;
                  _saveState();
                });
              },
            ),
          ),
        ],
      ),
    );
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
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                'Solve the clues by typing words to build a valid word ladder!',
                style: GoogleFonts.outfit(color: context.textSecondary, fontSize: context.scale(13)),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildBookendRow(0, 'Start Word'),
                    _buildConnectorLine(_level.answers[0], _controllers[0].text),
                    _buildSolvingRow(1),
                    _buildConnectorLine(_controllers[0].text, _controllers[1].text),
                    _buildSolvingRow(2),
                    _buildConnectorLine(_controllers[1].text, _controllers[2].text),
                    _buildSolvingRow(3),
                    _buildConnectorLine(_controllers[2].text, _level.answers[4]),
                    _buildBookendRow(4, 'End Word'),
                    const SizedBox(height: 24),
                    if (!_won)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.crossclimbPurple,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _check,
                        child: Text('Check Answers', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700, fontSize: context.scale(14))),
                      ),
                    if (_won) ...[
                      Text('You climbed to the top!', style: GoogleFonts.outfit(fontSize: context.scale(18), color: AppTheme.crossclimbPurple, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.crossclimbPurple,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _nextLevel,
                        child: Text('Next Level →', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700, fontSize: context.scale(14))),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
