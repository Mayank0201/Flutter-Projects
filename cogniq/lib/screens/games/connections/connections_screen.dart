import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../utils/rules_helper.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/hint_manager.dart';

class ConnectionsPuzzle {
  final String title;
  final List<ConnectionsGroup> groups;
  const ConnectionsPuzzle({required this.title, required this.groups});
}

class ConnectionsGroup {
  final String category;
  final List<String> words;
  final Color color;
  const ConnectionsGroup({required this.category, required this.words, required this.color});
}

const List<ConnectionsPuzzle> _kPuzzles = [
  ConnectionsPuzzle(title: 'Puzzle 1', groups: [
    ConnectionsGroup(category: '🐾 Felines', words: ['LION', 'TIGER', 'LEOPARD', 'CHEETAH'], color: Color(0xFF6AAA64)),
    ConnectionsGroup(category: '🎨 Primary colors', words: ['RED', 'BLUE', 'GREEN', 'YELLOW'], color: Color(0xFF4F9EE8)),
    ConnectionsGroup(category: '🧬 Anagrams of body parts', words: ['EARTH', 'BELOW', 'SINK', 'INCH'], color: Color(0xFFE67E22)),
    ConnectionsGroup(category: '🗣️ Homophones of numbers', words: ['WON', 'FORE', 'ATE', 'TOO'], color: Color(0xFFE84F9E)),
  ]),
  ConnectionsPuzzle(title: 'Puzzle 2', groups: [
    ConnectionsGroup(category: '🍎 Fruits', words: ['APPLE', 'MANGO', 'GRAPE', 'PEACH'], color: Color(0xFF6AAA64)),
    ConnectionsGroup(category: '⚽ Sports', words: ['SOCCER', 'TENNIS', 'RUGBY', 'POLO'], color: Color(0xFF4F9EE8)),
    ConnectionsGroup(category: '🗣️ Homophones of sky/weather words', words: ['REIGN', 'SON', 'BLEW', 'DUE'], color: Color(0xFFE67E22)),
    ConnectionsGroup(category: '🔗 Words before "JACK"', words: ['FLAP', 'MONTEREY', 'APPLE', 'UNION'], color: Color(0xFFE84F9E)),
  ]),
  ConnectionsPuzzle(title: 'Puzzle 3', groups: [
    ConnectionsGroup(category: '☁️ Weather', words: ['RAIN', 'SNOW', 'HAIL', 'SLEET'], color: Color(0xFF6AAA64)),
    ConnectionsGroup(category: '🪐 Planets', words: ['MARS', 'SATURN', 'VENUS', 'EARTH'], color: Color(0xFF4F9EE8)),
    ConnectionsGroup(category: '🧬 Anagrams of animals', words: ['REED', 'HEAR', 'LOIN', 'PEA'], color: Color(0xFFE67E22)),
    ConnectionsGroup(category: '🗣️ Homophones of letters', words: ['BEE', 'SEA', 'EYE', 'QUEUE'], color: Color(0xFFE84F9E)),
  ]),
  ConnectionsPuzzle(title: 'Puzzle 4', groups: [
    ConnectionsGroup(category: '🧪 Chemical elements', words: ['GOLD', 'IRON', 'NEON', 'ZINC'], color: Color(0xFF6AAA64)),
    ConnectionsGroup(category: '🎲 Board games', words: ['CHESS', 'LUDO', 'RISK', 'GO'], color: Color(0xFF4F9EE8)),
    ConnectionsGroup(category: '🧬 Anagrams of kitchen items', words: ['NAP', 'TOP', 'BLOW', 'PETAL'], color: Color(0xFFE67E22)),
    ConnectionsGroup(category: '🎬 Movies preceding "STORY"', words: ['TOY', 'WEST', 'PHILADELPHIA', 'DETECTIVE'], color: Color(0xFFE84F9E)),
  ]),
  ConnectionsPuzzle(title: 'Puzzle 5', groups: [
    ConnectionsGroup(category: '🌺 Flowers', words: ['TULIP', 'DAISY', 'LILAC', 'ORCHID'], color: Color(0xFF6AAA64)),
    ConnectionsGroup(category: '🎬 Film genres', words: ['COMEDY', 'HORROR', 'ACTION', 'DRAMA'], color: Color(0xFF4F9EE8)),
    ConnectionsGroup(category: '🗣️ Homophones of sight words', words: ['SEA', 'SITE', 'I', 'STAIR'], color: Color(0xFFE67E22)),
    ConnectionsGroup(category: '🔗 Words before "BOARD"', words: ['KEY', 'BLACK', 'CHESS', 'DART'], color: Color(0xFFE84F9E)),
  ]),
  ConnectionsPuzzle(title: 'Puzzle 6', groups: [
    ConnectionsGroup(category: '☕ Beverages', words: ['TEA', 'MILK', 'SODA', 'JUICE'], color: Color(0xFF6AAA64)),
    ConnectionsGroup(category: '🛌 Furniture', words: ['BED', 'SOFA', 'DESK', 'CHAIR'], color: Color(0xFF4F9EE8)),
    ConnectionsGroup(category: '🧬 Anagrams of food items', words: ['TEAM', 'REAP', 'WEST', 'LEMON'], color: Color(0xFFE67E22)),
    ConnectionsGroup(category: '🔗 Words following "PINE"', words: ['CONE', 'NEEDLE', 'TREE', 'APPLE'], color: Color(0xFFE84F9E)),
  ]),
  ConnectionsPuzzle(title: 'Puzzle 7', groups: [
    ConnectionsGroup(category: '👔 Clothing', words: ['SHIRT', 'PANTS', 'VEST', 'COAT'], color: Color(0xFF6AAA64)),
    ConnectionsGroup(category: '🎹 Instruments', words: ['FLUTE', 'ORGAN', 'DRUM', 'HARP'], color: Color(0xFF4F9EE8)),
    ConnectionsGroup(category: '🗣️ Homophones of simple words', words: ['PAIN', 'BEAR', 'FLOUR', 'HAIR'], color: Color(0xFFE67E22)),
    ConnectionsGroup(category: '🔗 Things with a cap', words: ['BOTTLE', 'MUSHROOM', 'KNEE', 'PEN'], color: Color(0xFFE84F9E)),
  ]),
  ConnectionsPuzzle(title: 'Puzzle 8', groups: [
    ConnectionsGroup(category: '🏰 Fairy tale figures', words: ['WITCH', 'GIANT', 'DWARF', 'FAIRY'], color: Color(0xFF6AAA64)),
    ConnectionsGroup(category: '📖 Literature genres', words: ['NOVEL', 'POEM', 'PLAY', 'MYTH'], color: Color(0xFF4F9EE8)),
    ConnectionsGroup(category: '🧬 Anagrams of sky/wild words', words: ['IRAN', 'WED', 'SOWN', 'FLOW'], color: Color(0xFFE67E22)),
    ConnectionsGroup(category: '🔗 Words preceding "PAPER"', words: ['WALL', 'SAND', 'NEWS', 'FLY'], color: Color(0xFFE84F9E)),
  ]),
  ConnectionsPuzzle(title: 'Puzzle 9', groups: [
    ConnectionsGroup(category: '🏛️ Architecture elements', words: ['DOME', 'ARCH', 'SPIRE', 'TOWER'], color: Color(0xFF6AAA64)),
    ConnectionsGroup(category: '🕸️ Insects', words: ['BEE', 'WASP', 'ANT', 'MOTH'], color: Color(0xFF4F9EE8)),
    ConnectionsGroup(category: '🗣️ Homophones of colors', words: ['READ', 'BLEW', 'WIGHT', 'BRED'], color: Color(0xFFE67E22)),
    ConnectionsGroup(category: '🔗 Words preceding "CAKE"', words: ['PAN', 'CUP', 'SPONGE', 'CHEESE'], color: Color(0xFFE84F9E)),
  ]),
  ConnectionsPuzzle(title: 'Puzzle 10', groups: [
    ConnectionsGroup(category: '☕ Coffee items', words: ['LATTE', 'MOCHA', 'BREW', 'ESPRESSO'], color: Color(0xFF6AAA64)),
    ConnectionsGroup(category: '🌿 Garden herbs', words: ['MINT', 'BASIL', 'THYME', 'SAGE'], color: Color(0xFF4F9EE8)),
    ConnectionsGroup(category: '🧬 Anagrams of geology/natural items', words: ['LAPS', 'LACY', 'STUD', 'PEAT'], color: Color(0xFFE67E22)),
    ConnectionsGroup(category: '🔗 Words preceding "DAY"', words: ['BIRTH', 'SUN', 'HOLI', 'YESTER'], color: Color(0xFFE84F9E)),
  ]),
  ConnectionsPuzzle(title: 'Puzzle 11', groups: [
    ConnectionsGroup(category: '🐶 Dog breeds', words: ['POODLE', 'BEAGLE', 'BULLDOG', 'RETRIEVER'], color: Color(0xFF6AAA64)),
    ConnectionsGroup(category: '🍰 Desserts', words: ['DONUT', 'CUPCAKE', 'COOKIE', 'BROWNIE'], color: Color(0xFF4F9EE8)),
    ConnectionsGroup(category: '🗣️ Homophones of actions', words: ['MEAT', 'RODE', 'THREW', 'WRUNG'], color: Color(0xFFE67E22)),
    ConnectionsGroup(category: '🔗 Words preceding "WATER"', words: ['TAP', 'RAIN', 'SALT', 'SODA'], color: Color(0xFFE84F9E)),
  ]),
  ConnectionsPuzzle(title: 'Puzzle 12', groups: [
    ConnectionsGroup(category: '🌿 Cooking spices', words: ['CINNAMON', 'NUTMEG', 'CLOVE', 'GINGER'], color: Color(0xFF6AAA64)),
    ConnectionsGroup(category: '💎 Precious gems', words: ['DIAMOND', 'EMERALD', 'SAPPHIRE', 'RUBY'], color: Color(0xFF4F9EE8)),
    ConnectionsGroup(category: '🧬 Anagrams of animal/plant words', words: ['LOIN', 'ACT', 'REED', 'FLOW'], color: Color(0xFFE67E22)),
    ConnectionsGroup(category: '🔗 Words preceding "LIGHT"', words: ['GREEN', 'TRAFFIC', 'FLASH', 'MOON'], color: Color(0xFFE84F9E)),
  ]),
  ConnectionsPuzzle(title: 'Puzzle 13', groups: [
    ConnectionsGroup(category: '🥤 Beverages', words: ['COFFEE', 'TEA', 'WATER', 'MILK'], color: Color(0xFF6AAA64)),
    ConnectionsGroup(category: '🍽️ Tableware', words: ['FORK', 'SPOON', 'KNIFE', 'PLATE'], color: Color(0xFF4F9EE8)),
    ConnectionsGroup(category: '🗣️ Homophones of places', words: ['ROAM', 'SOUL', 'CHILI', 'WHALES'], color: Color(0xFFE67E22)),
    ConnectionsGroup(category: '🔗 Words following "BLUE"', words: ['BERRY', 'BIRD', 'BELL', 'JEAN'], color: Color(0xFFE84F9E)),
  ]),
  ConnectionsPuzzle(title: 'Puzzle 14', groups: [
    ConnectionsGroup(category: '👞 Footwear', words: ['SNEAKER', 'BOOT', 'SANDAL', 'SLIPPER'], color: Color(0xFF6AAA64)),
    ConnectionsGroup(category: '📐 Shapes', words: ['CIRCLE', 'SQUARE', 'TRIANGLE', 'RECTANGLE'], color: Color(0xFF4F9EE8)),
    ConnectionsGroup(category: '🧬 Anagrams of fruits/plants', words: ['REAP', 'MILE', 'LEMON', 'LUMP'], color: Color(0xFFE67E22)),
    ConnectionsGroup(category: '🪃 Palindromic words', words: ['RADAR', 'KAYAK', 'ROTATOR', 'LEVEL'], color: Color(0xFFE84F9E)),
  ]),
  ConnectionsPuzzle(title: 'Puzzle 15', groups: [
    ConnectionsGroup(category: '🦁 Zoo animals', words: ['ZEBRA', 'GIRAFFE', 'ELEPHANT', 'HIPPO'], color: Color(0xFF6AAA64)),
    ConnectionsGroup(category: '📱 Tech gadgets', words: ['PHONE', 'TABLET', 'LAPTOP', 'WATCH'], color: Color(0xFF4F9EE8)),
    ConnectionsGroup(category: '🗣️ Homophones of pronouns/adjectives', words: ['I', 'YOU', 'WEE', 'THEIR'], color: Color(0xFFE67E22)),
    ConnectionsGroup(category: '🔗 Words preceding "STONE"', words: ['SAND', 'KEY', 'CORNER', 'MILE'], color: Color(0xFFE84F9E)),
  ]),
  ConnectionsPuzzle(title: 'Puzzle 16', groups: [
    ConnectionsGroup(category: '🌳 Trees', words: ['OAK', 'MAPLE', 'BIRCH', 'WILLOW'], color: Color(0xFF6AAA64)),
    ConnectionsGroup(category: '🧥 Outerwear', words: ['JACKET', 'COAT', 'SWEATER', 'PARKA'], color: Color(0xFF4F9EE8)),
    ConnectionsGroup(category: '🗣️ Homophones of simple verbs', words: ['BARE', 'KNEW', 'HEARD', 'SEEN'], color: Color(0xFFE67E22)),
    ConnectionsGroup(category: '🔗 Things associated with "GLASS"', words: ['CASTLE', 'WALL', 'SLIPPER', 'ONION'], color: Color(0xFFE84F9E)),
  ]),
  ConnectionsPuzzle(title: 'Puzzle 17', groups: [
    ConnectionsGroup(category: '🎻 String instruments', words: ['VIOLIN', 'CELLO', 'HARP', 'GUITAR'], color: Color(0xFF6AAA64)),
    ConnectionsGroup(category: '🥐 French bakery', words: ['CROISSANT', 'BAGUETTE', 'ECLAIR', 'BRIOCHE'], color: Color(0xFF4F9EE8)),
    ConnectionsGroup(category: '🗣️ Homophones of plants/weather words', words: ['PEAS', 'ROSE', 'WIND', 'ROAD'], color: Color(0xFFE67E22)),
    ConnectionsGroup(category: '🔗 Words preceding "BALL"', words: ['FOOT', 'SNOW', 'DISCO', 'BUTTER'], color: Color(0xFFE84F9E)),
  ]),
  ConnectionsPuzzle(title: 'Puzzle 18', groups: [
    ConnectionsGroup(category: '🐶 Dog breeds', words: ['POODLE', 'BEAGLE', 'BULLDOG', 'RETRIEVER'], color: Color(0xFF6AAA64)),
    ConnectionsGroup(category: '🍰 Desserts', words: ['DONUT', 'CUPCAKE', 'COOKIE', 'BROWNIE'], color: Color(0xFF4F9EE8)),
    ConnectionsGroup(category: '🧬 Anagrams of simple felines/natural forms', words: ['AMUP', 'LINO', 'LOIN', 'PEAK'], color: Color(0xFFE67E22)),
    ConnectionsGroup(category: '🌍 Words containing/sounding like countries', words: ['GERMANE', 'FRANC', 'CHINATOWN', 'TURKEY'], color: Color(0xFFE84F9E)),
  ]),
  ConnectionsPuzzle(title: 'Puzzle 19', groups: [
    ConnectionsGroup(category: '🌿 Spices', words: ['CINNAMON', 'NUTMEG', 'CLOVE', 'GINGER'], color: Color(0xFF6AAA64)),
    ConnectionsGroup(category: '💎 Precious gems', words: ['DIAMOND', 'EMERALD', 'SAPPHIRE', 'RUBY'], color: Color(0xFF4F9EE8)),
    ConnectionsGroup(category: '🗣️ Homophones of commerce/body words', words: ['SELLER', 'SIGHT', 'SCENT', 'SOLE'], color: Color(0xFFE67E22)),
    ConnectionsGroup(category: '🚪 Types of doors', words: ['SLIDING', 'REVOLVING', 'FOLDING', 'POCKET'], color: Color(0xFFE84F9E)),
  ]),
  ConnectionsPuzzle(title: 'Puzzle 20', groups: [
    ConnectionsGroup(category: '🥤 Drinks', words: ['COFFEE', 'TEA', 'WATER', 'MILK'], color: Color(0xFF6AAA64)),
    ConnectionsGroup(category: '🍽️ Tableware', words: ['FORK', 'SPOON', 'KNIFE', 'PLATE'], color: Color(0xFF4F9EE8)),
    ConnectionsGroup(category: '🪵 Wood types', words: ['MAHOGANY', 'TEAK', 'WALNUT', 'CHERRY'], color: Color(0xFFE67E22)),
    ConnectionsGroup(category: '📐 Statistical metrics', words: ['MEAN', 'MODE', 'MEDIAN', 'RANGE'], color: Color(0xFFE84F9E)),
  ]),
  ConnectionsPuzzle(title: 'Puzzle 21', groups: [
    ConnectionsGroup(category: '👞 Footwear', words: ['SNEAKER', 'BOOT', 'SANDAL', 'SLIPPER'], color: Color(0xFF6AAA64)),
    ConnectionsGroup(category: '📐 Shapes', words: ['CIRCLE', 'SQUARE', 'TRIANGLE', 'RECTANGLE'], color: Color(0xFF4F9EE8)),
    ConnectionsGroup(category: '🗣️ Alliterative adjectives/nouns', words: ['WILD', 'WAVE', 'WIND', 'WARM'], color: Color(0xFFE67E22)),
    ConnectionsGroup(category: '🏛️ Column architecture styles', words: ['DORIC', 'IONIC', 'CORINTHIAN', 'TUSCAN'], color: Color(0xFFE84F9E)),
  ]),
  ConnectionsPuzzle(title: 'Puzzle 22', groups: [
    ConnectionsGroup(category: '🦁 Zoo animals', words: ['ZEBRA', 'GIRAFFE', 'ELEPHANT', 'HIPPO'], color: Color(0xFF6AAA64)),
    ConnectionsGroup(category: '📱 Tech', words: ['PHONE', 'TABLET', 'LAPTOP', 'WATCH'], color: Color(0xFF4F9EE8)),
    ConnectionsGroup(category: '🗣️ Homophones of past verbs/time', words: ['FLEW', 'NIGHT', 'GROWN', 'KNEW'], color: Color(0xFFE67E22)),
    ConnectionsGroup(category: '🏛️ World-famous museums', words: ['LOUVRE', 'PRADO', 'HERMITAGE', 'UFFIZI'], color: Color(0xFFE84F9E)),
  ]),
  ConnectionsPuzzle(title: 'Puzzle 23', groups: [
    ConnectionsGroup(category: '🌳 Trees', words: ['OAK', 'MAPLE', 'BIRCH', 'WILLOW'], color: Color(0xFF6AAA64)),
    ConnectionsGroup(category: '🧥 Outerwear', words: ['JACKET', 'COAT', 'SWEATER', 'PARKA'], color: Color(0xFF4F9EE8)),
    ConnectionsGroup(category: '🗣️ Homophones starting with H', words: ['HOSE', 'HARE', 'HART', 'HEAR'], color: Color(0xFFE67E22)),
    ConnectionsGroup(category: '🌋 Volcanic structural features', words: ['CALDERA', 'CONE', 'DOME', 'FISSURE'], color: Color(0xFFE84F9E)),
  ]),
  ConnectionsPuzzle(title: 'Puzzle 24', groups: [
    ConnectionsGroup(category: '🥣 Breakfast items', words: ['CEREAL', 'OATMEAL', 'WAFFLE', 'PANCAKE'], color: Color(0xFF6AAA64)),
    ConnectionsGroup(category: '🐚 Seafood shells', words: ['CLAM', 'OYSTER', 'SCALLOP', 'MUSSEL'], color: Color(0xFF4F9EE8)),
    ConnectionsGroup(category: '🗣️ Homophones starting with S', words: ['STEAL', 'STARE', 'STILE', 'SUITE'], color: Color(0xFFE67E22)),
    ConnectionsGroup(category: '🧗 Climbing handhold grips', words: ['SLOP', 'CRIMP', 'JUG', 'PINCH'], color: Color(0xFFE84F9E)),
  ]),
  ConnectionsPuzzle(title: 'Puzzle 25', groups: [
    ConnectionsGroup(category: '🎨 Colors', words: ['ORANGE', 'PURPLE', 'PINK', 'BROWN'], color: Color(0xFF6AAA64)),
    ConnectionsGroup(category: '🎹 Keyboard keys', words: ['ENTER', 'SHIFT', 'SPACE', 'ESCAPE'], color: Color(0xFF4F9EE8)),
    ConnectionsGroup(category: '🗣️ Homophones of small words', words: ['SEW', 'SOAR', 'SOLE', 'SOME'], color: Color(0xFFE67E22)),
    ConnectionsGroup(category: '🪐 Deep space phenomena', words: ['NEBULA', 'PULSAR', 'QUASAR', 'SUPERNOVA'], color: Color(0xFFE84F9E)),
  ]),
  ConnectionsPuzzle(title: 'Puzzle 26', groups: [
    ConnectionsGroup(category: '🐟 Seafood', words: ['SHRIMP', 'CRAB', 'LOBSTER', 'PRAWN'], color: Color(0xFF6AAA64)),
    ConnectionsGroup(category: '🧪 Math operations', words: ['ADDITION', 'SUBTRACTION', 'MULTIPLICATION', 'DIVISION'], color: Color(0xFF4F9EE8)),
    ConnectionsGroup(category: '🧬 Anagrams of animal/fruit/clothing words', words: ['TAIL', 'TAPE', 'TART', 'TEAM'], color: Color(0xFFE67E22)),
    ConnectionsGroup(category: '🏰 Royal titles', words: ['KING', 'QUEEN', 'PRINCE', 'PRINCESS'], color: Color(0xFFE84F9E)),
  ]),
  ConnectionsPuzzle(title: 'Puzzle 27', groups: [
    ConnectionsGroup(category: '👕 Tops', words: ['TSHIRT', 'BLOUSE', 'POLO', 'SWEATER'], color: Color(0xFF6AAA64)),
    ConnectionsGroup(category: '🧴 Cosmetics', words: ['LIPSTICK', 'MASCARA', 'BLUSH', 'FOUNDATION'], color: Color(0xFF4F9EE8)),
    ConnectionsGroup(category: '🗣️ Silent-K homophones', words: ['KNOT', 'KNEAD', 'KNIGHT', 'KNEW'], color: Color(0xFFE67E22)),
    ConnectionsGroup(category: '🌾 Grains', words: ['WHEAT', 'RICE', 'BARLEY', 'OATS'], color: Color(0xFFE84F9E)),
  ]),
  ConnectionsPuzzle(title: 'Puzzle 28', groups: [
    ConnectionsGroup(category: '🍇 Fruits', words: ['GRAPE', 'BERRY', 'FIG', 'DATE'], color: Color(0xFF6AAA64)),
    ConnectionsGroup(category: '📦 Office supplies', words: ['PAPERCLIP', 'STAPLER', 'TAPE', 'FOLDER'], color: Color(0xFF4F9EE8)),
    ConnectionsGroup(category: '🗣️ Homophones starting with T', words: ['TIME', 'TIDE', 'TOAD', 'TALE'], color: Color(0xFFE67E22)),
    ConnectionsGroup(category: '🦴 Bones', words: ['SKULL', 'RIB', 'FEMUR', 'SPINE'], color: Color(0xFFE84F9E)),
  ]),
  ConnectionsPuzzle(title: 'Puzzle 29', groups: [
    ConnectionsGroup(category: '🌧️ Water forms', words: ['RAIN', 'DEW', 'FOG', 'MIST'], color: Color(0xFF6AAA64)),
    ConnectionsGroup(category: '🎭 Moods', words: ['HAPPY', 'SAD', 'ANGRY', 'EXCITED'], color: Color(0xFF4F9EE8)),
    ConnectionsGroup(category: '🗣️ Homophones starting with P', words: ['PEAL', 'PEAR', 'PIECE', 'PRIDE'], color: Color(0xFFE67E22)),
    ConnectionsGroup(category: '🧀 Cheeses', words: ['CHEDDAR', 'MOZZARELLA', 'PARMESAN', 'GOUDA'], color: Color(0xFFE84F9E)),
  ]),
  ConnectionsPuzzle(title: 'Puzzle 30', groups: [
    ConnectionsGroup(category: '🧵 Sewing items', words: ['NEEDLE', 'THREAD', 'FABRIC', 'THIMBLE'], color: Color(0xFF6AAA64)),
    ConnectionsGroup(category: '🏔️ Landforms', words: ['VALLEY', 'CANYON', 'PLATEAU', 'CLIFF'], color: Color(0xFF4F9EE8)),
    ConnectionsGroup(category: '🗣️ Homophones starting with R', words: ['ROSE', 'RING', 'RAIN', 'ROOT'], color: Color(0xFFE67E22)),
    ConnectionsGroup(category: '🧴 Bathroom items', words: ['SOAP', 'TOWEL', 'BRUSH', 'MIRROR'], color: Color(0xFFE84F9E)),
  ]),
];

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key});
  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  int _puzzleIndex = 0;
  late ConnectionsPuzzle _puzzle;
  late List<String> _words;
  final Set<String> _selected = {};
  final List<ConnectionsGroup> _solved = [];
  int _mistakesLeft = 4;
  String _message = '';
  bool _won = false;

  int _hintCount = 0;

  @override
  void initState() {
    super.initState();
    // Default synchronous initialization to avoid LateInitializationError
    _puzzle = _kPuzzles[0];
    _words = _puzzle.groups.expand((g) => g.words).toList()..shuffle();
    _initPuzzle();
  }

  Future<void> _initPuzzle() async {
    _hintCount = await HintManager.getHints('connections');
    final prefs = await SharedPreferences.getInstance();
    final savedLevel = prefs.getInt('level_connections') ?? 0;
    if (mounted) {
      setState(() {
        _puzzleIndex = savedLevel % _kPuzzles.length;
        _loadPuzzle();
      });
    }
  }

  Future<void> _savePersistedLevel(int lvl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('level_connections', lvl);
    final earned = await HintManager.onLevelCleared('connections');
    final newCount = await HintManager.getHints('connections');
    setState(() {
      _hintCount = newCount;
    });
    if (earned && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 Hint earned! (Total: $newCount)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: AppTheme.accentFor('connections'),
        ),
      );
    }
  }

  Future<void> _useHint() async {
    if (_won || _mistakesLeft <= 0 || _hintCount <= 0) return;
    ConnectionsGroup? targetGroup;
    for (final group in _puzzle.groups) {
      if (!_solved.contains(group)) {
        targetGroup = group;
        break;
      }
    }
    if (targetGroup == null) return;

    await HintManager.useHint('connections');
    final newCount = await HintManager.getHints('connections');

    setState(() {
      _hintCount = newCount;
      _solved.add(targetGroup!);
      _words.removeWhere(targetGroup.words.contains);
      _selected.removeWhere(targetGroup.words.contains);
      _message = '💡 Revealed category: "${targetGroup.category}"';
      if (_solved.length == _puzzle.groups.length) {
        _won = true;
        _savePersistedLevel(_puzzleIndex);
      }
    });
  }

  void _loadPuzzle() {
    _puzzle = _kPuzzles[_puzzleIndex % _kPuzzles.length];
    _words = _puzzle.groups.expand((g) => g.words).toList()..shuffle();
    _selected.clear(); _solved.clear();
    _mistakesLeft = 4; _message = ''; _won = false;
  }

  void _toggleWord(String w) {
    if (_won || _isSolved(w)) return;
    setState(() {
      if (_selected.contains(w)) { _selected.remove(w); }
      else if (_selected.length < 4) { _selected.add(w); }
    });
  }

  bool _isSolved(String w) => _solved.any((g) => g.words.contains(w));

  void _submit() {
    if (_selected.length != 4) return;
    for (final group in _puzzle.groups) {
      if (_solved.contains(group)) continue;
      if (group.words.toSet().containsAll(_selected)) {
        setState(() {
          _solved.add(group);
          _words.removeWhere(_selected.contains);
          _selected.clear();
          _message = '✅ Correct! "${group.category}"';
          if (_solved.length == _puzzle.groups.length) {
            _won = true;
            _savePersistedLevel(_puzzleIndex);
          }
        });
        return;
      }
    }
    
    // Check if one away
    bool oneAway = false;
    for (final group in _puzzle.groups) {
      if (_solved.contains(group)) continue;
      final intersectionCount = group.words.toSet().intersection(_selected).length;
      if (intersectionCount == 3) {
        oneAway = true;
        break;
      }
    }

    setState(() {
      _mistakesLeft--;
      if (_mistakesLeft <= 0) {
        _message = '💀 Out of guesses!';
        _won = false;
      } else {
        _message = oneAway
            ? '❌ One away! $_mistakesLeft mistakes left.'
            : '❌ Wrong! $_mistakesLeft mistakes left.';
      }
    });
  }

  void _reset() => setState(() => _loadPuzzle());
  void _nextPuzzle() {
    setState(() {
      _puzzleIndex = (_puzzleIndex + 1) % _kPuzzles.length;
      _savePersistedLevel(_puzzleIndex);
      _loadPuzzle();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mistakes = 4 - _mistakesLeft;
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        backgroundColor: context.bgDark, foregroundColor: context.textPrimary,
        title: Text('Categories', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: context.textPrimary)),
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
            onPressed: _hintCount > 0 && !_won && _mistakesLeft > 0 ? _useHint : null,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, size: 20),
            color: context.textMuted,
            onPressed: () => RulesHelper.showRulesBottomSheet(context, 'connections', 'Categories'),
          ),
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _reset, color: context.textMuted),
          Padding(padding: const EdgeInsets.only(right: 12), child: Center(child: Text('Level ${_puzzleIndex + 1}', style: GoogleFonts.outfit(color: AppTheme.connectionsRed, fontSize: context.scale(13))))),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Mistakes left text and dots
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('Mistakes: ', style: GoogleFonts.outfit(color: context.textSecondary, fontSize: context.scale(14))),
            ...List.generate(4, (i) => Padding(padding: const EdgeInsets.symmetric(horizontal: 3),
              child: CircleAvatar(radius: 7, backgroundColor: i < mistakes ? Colors.redAccent : context.bgSurface))),
          ]),
          const SizedBox(height: 16),
          // Solved groups
          ..._solved.map((g) => _SolvedGroup(group: g)),
          if (_solved.isNotEmpty) const SizedBox(height: 8),
          // Word grid
          GridView.count(crossAxisCount: 4, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 6, mainAxisSpacing: 6, childAspectRatio: 1.3,
            children: _words.map((w) {
              final sel = _selected.contains(w);
              return GestureDetector(
                onTap: () => _toggleWord(w),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: sel ? AppTheme.connectionsRed : context.bgSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: sel ? AppTheme.connectionsRed : context.textMuted.withOpacity(0.3), width: sel ? 2 : 1),
                  ),
                  child: Center(child: Text(w, style: GoogleFonts.outfit(fontSize: context.scale(11), fontWeight: FontWeight.w700, color: sel ? Colors.white : context.textPrimary), textAlign: TextAlign.center)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          if (_message.isNotEmpty) Text(_message, style: GoogleFonts.outfit(color: context.textSecondary, fontSize: context.scale(14)), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          if (!_won && _mistakesLeft > 0) ...[
            Text('Select 4 words', style: GoogleFonts.outfit(color: context.textMuted, fontSize: context.scale(12))),
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _selected.length == 4 ? AppTheme.connectionsRed : context.bgSurface, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: _selected.length == 4 ? _submit : null,
              child: Text('Submit', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700, fontSize: context.scale(14))),
            ),
          ],
          if (_won || _mistakesLeft <= 0) ...[
            const SizedBox(height: 8),
            Text(
              _won ? 'All groups found!' : 'Better luck next time!',
              style: GoogleFonts.outfit(fontSize: context.scale(18), color: _won ? AppTheme.connectionsRed : Colors.redAccent, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            if (_won)
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.connectionsRed, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _nextPuzzle,
                child: Text('Next Puzzle →', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700, fontSize: context.scale(14))),
              )
            else
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: context.bgSurface, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _reset,
                child: Text('Try Again', style: GoogleFonts.outfit(color: context.textPrimary, fontWeight: FontWeight.w700, fontSize: context.scale(14))),
              ),
          ],
        ]),
      ),
    );
  }
}

class _SolvedGroup extends StatelessWidget {
  final ConnectionsGroup group;
  const _SolvedGroup({required this.group});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    decoration: BoxDecoration(color: group.color.withOpacity(0.3), borderRadius: BorderRadius.circular(10), border: Border.all(color: group.color.withOpacity(0.6))),
    child: Column(children: [
      Text(group.category, style: GoogleFonts.outfit(fontSize: context.scale(13), fontWeight: FontWeight.w700, color: group.color)),
      const SizedBox(height: 4),
      Text(group.words.join(' • '), style: GoogleFonts.outfit(fontSize: context.scale(12), color: context.textSecondary)),
    ]),
  );
}
