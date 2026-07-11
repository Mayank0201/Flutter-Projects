import 'package:flutter/material.dart';
import 'package:cogniq/widgets/buy_hints_dialog.dart';
import 'dart:convert';
import '../../../theme/settings_manager.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../utils/rules_helper.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/hint_manager.dart';
import '../../../utils/audio_manager.dart';
import'../../../widgets/auto_next_countdown.dart';

class ConnectionsPuzzle {
  final String title;
  final List<ConnectionsGroup> groups;
  const ConnectionsPuzzle({required this.title, required this.groups});
}

class ConnectionsGroup {
  final String category;
  final List<String> words;
  final Color color;
  const ConnectionsGroup({
    required this.category,
    required this.words,
    required this.color,
  });
}

const List<ConnectionsPuzzle> _kPuzzles = [
  ConnectionsPuzzle(
    title: 'Puzzle 1',
    groups: [
      ConnectionsGroup(
        category: '🐾 Felines',
        words: ['LION', 'TIGER', 'LEOPARD', 'CHEETAH'],
        color: Color(0xFF6AAA64),
      ),
      ConnectionsGroup(
        category: '🎨 Primary colors',
        words: ['RED', 'BLUE', 'GREEN', 'YELLOW'],
        color: Color(0xFF4F9EE8),
      ),
      ConnectionsGroup(
        category: '🧬 Anagrams of body parts',
        words: ['EARTH', 'BELOW', 'SINK', 'INCH'],
        color: Color(0xFFE67E22),
      ),
      ConnectionsGroup(
        category: '🗣️ Homophones of numbers',
        words: ['WON', 'FORE', 'ATE', 'TOO'],
        color: Color(0xFFE84F9E),
      ),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 2',
    groups: [
      ConnectionsGroup(
        category: '🍎 Fruits',
        words: ['APPLE', 'MANGO', 'GRAPE', 'PEACH'],
        color: Color(0xFF6AAA64),
      ),
      ConnectionsGroup(
        category: '⚽ Sports',
        words: ['SOCCER', 'TENNIS', 'RUGBY', 'POLO'],
        color: Color(0xFF4F9EE8),
      ),
      ConnectionsGroup(
        category: '🗣️ Homophones of sky/weather words',
        words: ['REIGN', 'SON', 'BLEW', 'DUE'],
        color: Color(0xFFE67E22),
      ),
      ConnectionsGroup(
        category: '🔗 Words before "JACK"',
        words: ['FLAP', 'MONTEREY', 'BLACK', 'UNION'],
        color: Color(0xFFE84F9E),
      ),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 3',
    groups: [
      ConnectionsGroup(
        category: '☁️ Weather',
        words: ['RAIN', 'SNOW', 'HAIL', 'SLEET'],
        color: Color(0xFF6AAA64),
      ),
      ConnectionsGroup(
        category: '🪐 Planets',
        words: ['MARS', 'SATURN', 'VENUS', 'EARTH'],
        color: Color(0xFF4F9EE8),
      ),
      ConnectionsGroup(
        category: '🧬 Anagrams of animals',
        words: ['REED', 'HEAR', 'LOIN', 'PEA'],
        color: Color(0xFFE67E22),
      ),
      ConnectionsGroup(
        category: '🗣️ Homophones of letters',
        words: ['BEE', 'SEA', 'EYE', 'QUEUE'],
        color: Color(0xFFE84F9E),
      ),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 4',
    groups: [
      ConnectionsGroup(
        category: '🧪 Chemical elements',
        words: ['GOLD', 'IRON', 'NEON', 'ZINC'],
        color: Color(0xFF6AAA64),
      ),
      ConnectionsGroup(
        category: '🎲 Board games',
        words: ['CHESS', 'LUDO', 'RISK', 'GO'],
        color: Color(0xFF4F9EE8),
      ),
      ConnectionsGroup(
        category: '🧬 Anagrams of kitchen items',
        words: ['NAP', 'TOP', 'BLOW', 'PETAL'],
        color: Color(0xFFE67E22),
      ),
      ConnectionsGroup(
        category: '🎬 Movies preceding "STORY"',
        words: ['TOY', 'WEST', 'PHILADELPHIA', 'DETECTIVE'],
        color: Color(0xFFE84F9E),
      ),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 5',
    groups: [
      ConnectionsGroup(
        category: '🌺 Flowers',
        words: ['TULIP', 'DAISY', 'LILAC', 'ORCHID'],
        color: Color(0xFF6AAA64),
      ),
      ConnectionsGroup(
        category: '🎬 Film genres',
        words: ['COMEDY', 'HORROR', 'ACTION', 'DRAMA'],
        color: Color(0xFF4F9EE8),
      ),
      ConnectionsGroup(
        category: '🗣️ Homophones of sight words',
        words: ['SEA', 'SITE', 'I', 'STAIR'],
        color: Color(0xFFE67E22),
      ),
      ConnectionsGroup(
        category: '🔗 Words before "BOARD"',
        words: ['KEY', 'BLACK', 'CHESS', 'DART'],
        color: Color(0xFFE84F9E),
      ),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 6',
    groups: [
      ConnectionsGroup(
        category: '☕ Beverages',
        words: ['TEA', 'MILK', 'SODA', 'JUICE'],
        color: Color(0xFF6AAA64),
      ),
      ConnectionsGroup(
        category: '🛌 Furniture',
        words: ['BED', 'SOFA', 'DESK', 'CHAIR'],
        color: Color(0xFF4F9EE8),
      ),
      ConnectionsGroup(
        category: '🧬 Anagrams of food items',
        words: ['TEAM', 'REAP', 'WEST', 'LEMON'],
        color: Color(0xFFE67E22),
      ),
      ConnectionsGroup(
        category: '🔗 Words following "PINE"',
        words: ['CONE', 'NEEDLE', 'TREE', 'APPLE'],
        color: Color(0xFFE84F9E),
      ),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 7',
    groups: [
      ConnectionsGroup(
        category: '👔 Clothing',
        words: ['SHIRT', 'PANTS', 'VEST', 'COAT'],
        color: Color(0xFF6AAA64),
      ),
      ConnectionsGroup(
        category: '🎹 Instruments',
        words: ['FLUTE', 'ORGAN', 'DRUM', 'HARP'],
        color: Color(0xFF4F9EE8),
      ),
      ConnectionsGroup(
        category: '🗣️ Homophones of simple words',
        words: ['PAIN', 'BEAR', 'FLOUR', 'HAIR'],
        color: Color(0xFFE67E22),
      ),
      ConnectionsGroup(
        category: '🔗 Things with a cap',
        words: ['BOTTLE', 'MUSHROOM', 'KNEE', 'PEN'],
        color: Color(0xFFE84F9E),
      ),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 8',
    groups: [
      ConnectionsGroup(
        category: '🏰 Fairy tale figures',
        words: ['WITCH', 'GIANT', 'DWARF', 'FAIRY'],
        color: Color(0xFF6AAA64),
      ),
      ConnectionsGroup(
        category: '📖 Literature genres',
        words: ['NOVEL', 'POEM', 'PLAY', 'MYTH'],
        color: Color(0xFF4F9EE8),
      ),
      ConnectionsGroup(
        category: '🧬 Anagrams of sky/wild words',
        words: ['IRAN', 'WED', 'SOWN', 'FLOW'],
        color: Color(0xFFE67E22),
      ),
      ConnectionsGroup(
        category: '🔗 Words preceding "PAPER"',
        words: ['WALL', 'SAND', 'NEWS', 'FLY'],
        color: Color(0xFFE84F9E),
      ),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 9',
    groups: [
      ConnectionsGroup(
        category: '🏛️ Architecture elements',
        words: ['DOME', 'ARCH', 'SPIRE', 'TOWER'],
        color: Color(0xFF6AAA64),
      ),
      ConnectionsGroup(
        category: '🕸️ Insects',
        words: ['BEE', 'WASP', 'ANT', 'MOTH'],
        color: Color(0xFF4F9EE8),
      ),
      ConnectionsGroup(
        category: '🗣️ Homophones of colors',
        words: ['READ', 'BLEW', 'WIGHT', 'BRED'],
        color: Color(0xFFE67E22),
      ),
      ConnectionsGroup(
        category: '🔗 Words preceding "CAKE"',
        words: ['PAN', 'CUP', 'SPONGE', 'CHEESE'],
        color: Color(0xFFE84F9E),
      ),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 10',
    groups: [
      ConnectionsGroup(
        category: '☕ Coffee items',
        words: ['LATTE', 'MOCHA', 'BREW', 'ESPRESSO'],
        color: Color(0xFF6AAA64),
      ),
      ConnectionsGroup(
        category: '🌿 Garden herbs',
        words: ['MINT', 'BASIL', 'THYME', 'SAGE'],
        color: Color(0xFF4F9EE8),
      ),
      ConnectionsGroup(
        category: '🧬 Anagrams of geology/natural items',
        words: ['LAPS', 'LACY', 'STUD', 'PEAT'],
        color: Color(0xFFE67E22),
      ),
      ConnectionsGroup(
        category: '🔗 Words preceding "DAY"',
        words: ['BIRTH', 'SUN', 'HOLI', 'YESTER'],
        color: Color(0xFFE84F9E),
      ),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 11',
    groups: [
      ConnectionsGroup(
        category: '🐶 Dog breeds',
        words: ['POODLE', 'BEAGLE', 'BULLDOG', 'RETRIEVER'],
        color: Color(0xFF6AAA64),
      ),
      ConnectionsGroup(
        category: '🍰 Desserts',
        words: ['DONUT', 'CUPCAKE', 'COOKIE', 'BROWNIE'],
        color: Color(0xFF4F9EE8),
      ),
      ConnectionsGroup(
        category: '🗣️ Homophones of actions',
        words: ['MEAT', 'RODE', 'THREW', 'WRUNG'],
        color: Color(0xFFE67E22),
      ),
      ConnectionsGroup(
        category: '🔗 Words preceding "WATER"',
        words: ['TAP', 'RAIN', 'SALT', 'SODA'],
        color: Color(0xFFE84F9E),
      ),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 12',
    groups: [
      ConnectionsGroup(
        category: '🌿 Cooking spices',
        words: ['CINNAMON', 'NUTMEG', 'CLOVE', 'GINGER'],
        color: Color(0xFF6AAA64),
      ),
      ConnectionsGroup(
        category: '💎 Precious gems',
        words: ['DIAMOND', 'EMERALD', 'SAPPHIRE', 'RUBY'],
        color: Color(0xFF4F9EE8),
      ),
      ConnectionsGroup(
        category: '🧬 Anagrams of animal/plant words',
        words: ['LOIN', 'ACT', 'REED', 'FLOW'],
        color: Color(0xFFE67E22),
      ),
      ConnectionsGroup(
        category: '🔗 Words preceding "LIGHT"',
        words: ['GREEN', 'TRAFFIC', 'FLASH', 'MOON'],
        color: Color(0xFFE84F9E),
      ),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 13',
    groups: [
      ConnectionsGroup(
        category: '🥤 Beverages',
        words: ['COFFEE', 'TEA', 'WATER', 'MILK'],
        color: Color(0xFF6AAA64),
      ),
      ConnectionsGroup(
        category: '🍽️ Tableware',
        words: ['FORK', 'SPOON', 'KNIFE', 'PLATE'],
        color: Color(0xFF4F9EE8),
      ),
      ConnectionsGroup(
        category: '🗣️ Homophones of places',
        words: ['ROAM', 'SOUL', 'CHILI', 'WHALES'],
        color: Color(0xFFE67E22),
      ),
      ConnectionsGroup(
        category: '🔗 Words following "BLUE"',
        words: ['BERRY', 'BIRD', 'BELL', 'JEAN'],
        color: Color(0xFFE84F9E),
      ),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 14',
    groups: [
      ConnectionsGroup(
        category: '👞 Footwear',
        words: ['SNEAKER', 'BOOT', 'SANDAL', 'SLIPPER'],
        color: Color(0xFF6AAA64),
      ),
      ConnectionsGroup(
        category: '📐 Shapes',
        words: ['CIRCLE', 'SQUARE', 'TRIANGLE', 'RECTANGLE'],
        color: Color(0xFF4F9EE8),
      ),
      ConnectionsGroup(
        category: '🧬 Anagrams of fruits/plants',
        words: ['REAP', 'MILE', 'LEMON', 'LUMP'],
        color: Color(0xFFE67E22),
      ),
      ConnectionsGroup(
        category: '🪃 Palindromic words',
        words: ['RADAR', 'KAYAK', 'ROTATOR', 'LEVEL'],
        color: Color(0xFFE84F9E),
      ),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 15',
    groups: [
      ConnectionsGroup(
        category: '🦁 Zoo animals',
        words: ['ZEBRA', 'GIRAFFE', 'ELEPHANT', 'HIPPO'],
        color: Color(0xFF6AAA64),
      ),
      ConnectionsGroup(
        category: '📱 Tech gadgets',
        words: ['PHONE', 'TABLET', 'LAPTOP', 'WATCH'],
        color: Color(0xFF4F9EE8),
      ),
      ConnectionsGroup(
        category: '🗣️ Homophones of pronouns/adjectives',
        words: ['I', 'YOU', 'WEE', 'THEIR'],
        color: Color(0xFFE67E22),
      ),
      ConnectionsGroup(
        category: '🔗 Words preceding "STONE"',
        words: ['SAND', 'KEY', 'CORNER', 'MILE'],
        color: Color(0xFFE84F9E),
      ),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 16',
    groups: [
      ConnectionsGroup(
        category: '🌳 Trees',
        words: ['OAK', 'MAPLE', 'BIRCH', 'ASH'],
        color: Color(0xFF6AAA64),
      ),
      ConnectionsGroup(
        category: '🧥 Outerwear',
        words: ['JACKET', 'COAT', 'SWEATER', 'VEST'],
        color: Color(0xFF4F9EE8),
      ),
      ConnectionsGroup(
        category: '🗣️ Homophones of simple verbs',
        words: ['BARE', 'KNEW', 'HEARD', 'SEEN'],
        color: Color(0xFFE67E22),
      ),
      ConnectionsGroup(
        category: '🔗 Words preceding "HORN"',
        words: ['BULL', 'FOG', 'GREEN', 'CAPE'],
        color: Color(0xFFE84F9E),
      ),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 17',
    groups: [
      ConnectionsGroup(
        category: '🎻 String instruments',
        words: ['VIOLIN', 'CELLO', 'HARP', 'LYRE'],
        color: Color(0xFF6AAA64),
      ),
      ConnectionsGroup(
        category: '🗣️ Untruthful people',
        words: ['LIAR', 'CHEAT', 'FRAUD', 'PHONY'],
        color: Color(0xFF4F9EE8),
      ),
      ConnectionsGroup(
        category: '🥐 French bakery',
        words: ['CROISSANT', 'BAGUETTE', 'ECLAIR', 'ROLL'],
        color: Color(0xFFE67E22),
      ),
      ConnectionsGroup(
        category: '🔗 Words preceding "BALL"',
        words: ['FOOT', 'SNOW', 'DISCO', 'BUTTER'],
        color: Color(0xFFE84F9E),
      ),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 18',
    groups: [
      ConnectionsGroup(
        category: '🚗 Car brands',
        words: ['TOYOTA', 'FORD', 'HONDA', 'DODGE'],
        color: Color(0xFF6AAA64),
      ),
      ConnectionsGroup(
        category: '🏃 Verbs meaning to avoid',
        words: ['EVADE', 'DUCK', 'ELUDE', 'SHUN'],
        color: Color(0xFF4F9EE8),
      ),
      ConnectionsGroup(
        category: '🍕 Pizza toppings',
        words: ['PEPPERONI', 'MUSHROOM', 'OLIVE', 'HAM'],
        color: Color(0xFFE67E22),
      ),
      ConnectionsGroup(
        category: '🗣️ Homophones of meat/food',
        words: ['MEET', 'STEAK', 'BREAD', 'ROSE'],
        color: Color(0xFFE84F9E),
      ),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 19',
    groups: [
      ConnectionsGroup(
        category: '🧗 Mountain gear',
        words: ['ROPE', 'HARNESS', 'HELMET', 'PITON'],
        color: Color(0xFF6AAA64),
      ),
      ConnectionsGroup(
        category: '🛡️ Medieval combatants',
        words: ['KNIGHT', 'SQUIRE', 'ARCHER', 'HERALD'],
        color: Color(0xFF4F9EE8),
      ),
      ConnectionsGroup(
        category: '⏱️ Time periods',
        words: ['SECOND', 'MINUTE', 'HOUR', 'DAY'],
        color: Color(0xFFE67E22),
      ),
      ConnectionsGroup(
        category: '🔗 Words following "GOLD"',
        words: ['FISH', 'RUSH', 'MINE', 'LEAF'],
        color: Color(0xFFE84F9E),
      ),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 20',
    groups: [
      ConnectionsGroup(
        category: '🥬 Green vegetables',
        words: ['SPINACH', 'BROCCOLI', 'KALE', 'LETTUCE'],
        color: Color(0xFF6AAA64),
      ),
      ConnectionsGroup(
        category: '📐 Drafting tools',
        words: ['RULER', 'COMPASS', 'PROTRACTOR', 'PENCIL'],
        color: Color(0xFF4F9EE8),
      ),
      ConnectionsGroup(
        category: '🧬 Anagrams of clothing items',
        words: ['TACO', 'HOSE', 'PACE', 'LIPS'],
        color: Color(0xFFE67E22),
      ),
      ConnectionsGroup(
        category: '🔗 Words preceding "ROOM"',
        words: ['BED', 'BATH', 'CLASS', 'COURT'],
        color: Color(0xFFE84F9E),
      ),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 21',
    groups: [
      ConnectionsGroup(
        category: '🦁 Cats',
        words: ['PANTHER', 'JAGUAR', 'COUGAR', 'PUMA'],
        color: Color(0xFF6AAA64),
      ),
      ConnectionsGroup(
        category: '🎸 Rock bands',
        words: ['QUEEN', 'ACDC', 'METALLICA', 'NIRVANA'],
        color: Color(0xFF4F9EE8),
      ),
      ConnectionsGroup(
        category: '🗣️ Homophones of visual items',
        words: ['SEE', 'SCENT', 'SITE', 'SEEN'],
        color: Color(0xFFE67E22),
      ),
      ConnectionsGroup(
        category: '🔗 Words preceding "GLASS"',
        words: ['HOUR', 'WIND', 'MAGNIFYING', 'LOOKING'],
        color: Color(0xFFE84F9E),
      ),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 22',
    groups: [
      ConnectionsGroup(
        category: '🌌 Astronomy',
        words: ['STAR', 'GALAXY', 'COMET', 'ASTEROID'],
        color: Color(0xFF6AAA64),
      ),
      ConnectionsGroup(
        category: '🍔 Fast food',
        words: ['BURGER', 'FRIES', 'NUGGETS', 'SHAKE'],
        color: Color(0xFF4F9EE8),
      ),
      ConnectionsGroup(
        category: '🗣️ Homophones of numbers',
        words: ['WON', 'TOO', 'FORE', 'ATE'],
        color: Color(0xFFE67E22),
      ),
      ConnectionsGroup(
        category: '🔗 Words following "HOT"',
        words: ['DOG', 'SAUCE', 'TUB', 'POTATO'],
        color: Color(0xFFE84F9E),
      ),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 23',
    groups: [
      ConnectionsGroup(
        category: '🐦 Birds',
        words: ['EAGLE', 'HAWK', 'FALCON', 'SPARROW'],
        color: Color(0xFF6AAA64),
      ),
      ConnectionsGroup(
        category: '🧪 Laboratory equipment',
        words: ['BEAKER', 'FLASK', 'TUBE', 'PIPETTE'],
        color: Color(0xFF4F9EE8),
      ),
      ConnectionsGroup(
        category: '🧬 Anagrams of insects',
        words: ['TNA', 'EEB', 'THOM', 'ASPW'],
        color: Color(0xFFE67E22),
      ),
      ConnectionsGroup(
        category: '🔗 Words preceding "CARD"',
        words: ['CREDIT', 'POST', 'GIFT', 'SCORE'],
        color: Color(0xFFE84F9E),
      ),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 24',
    groups: [
      ConnectionsGroup(
        category: '🥣 Breakfast items',
        words: ['CEREAL', 'OATMEAL', 'WAFFLE', 'PANCAKE'],
        color: Color(0xFF6AAA64),
      ),
      ConnectionsGroup(
        category: '🐚 Seafood shells',
        words: ['CLAM', 'OYSTER', 'SCALLOP', 'MUSSEL'],
        color: Color(0xFF4F9EE8),
      ),
      ConnectionsGroup(
        category: '🗣️ Homophones starting with S',
        words: ['STEAL', 'STARE', 'STILE', 'SUITE'],
        color: Color(0xFFE67E22),
      ),
      ConnectionsGroup(
        category: '🧗 Climbing handhold grips',
        words: ['SLOP', 'CRIMP', 'JUG', 'PINCH'],
        color: Color(0xFFE84F9E),
      ),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 25',
    groups: [
      ConnectionsGroup(
        category: '🎨 Colors',
        words: ['ORANGE', 'PURPLE', 'PINK', 'BROWN'],
        color: Color(0xFF6AAA64),
      ),
      ConnectionsGroup(
        category: '🎹 Keyboard keys',
        words: ['ENTER', 'SHIFT', 'SPACE', 'ESCAPE'],
        color: Color(0xFF4F9EE8),
      ),
      ConnectionsGroup(
        category: '🗣️ Homophones of small words',
        words: ['SEW', 'SOAR', 'SOLE', 'SOME'],
        color: Color(0xFFE67E22),
      ),
      ConnectionsGroup(
        category: '🪐 Deep space phenomena',
        words: ['NEBULA', 'PULSAR', 'QUASAR', 'SUPERNOVA'],
        color: Color(0xFFE84F9E),
      ),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 26',
    groups: [
      ConnectionsGroup(
        category: '🐟 Seafood',
        words: ['SHRIMP', 'CRAB', 'LOBSTER', 'PRAWN'],
        color: Color(0xFF6AAA64),
      ),
      ConnectionsGroup(
        category: '🧪 Math operations',
        words: ['ADDITION', 'SUBTRACTION', 'MULTIPLICATION', 'DIVISION'],
        color: Color(0xFF4F9EE8),
      ),
      ConnectionsGroup(
        category: '🧬 Anagrams of animal/fruit/clothing words',
        words: ['TAIL', 'TAPE', 'TART', 'TEAM'],
        color: Color(0xFFE67E22),
      ),
      ConnectionsGroup(
        category: '🏰 Royal titles',
        words: ['KING', 'QUEEN', 'PRINCE', 'PRINCESS'],
        color: Color(0xFFE84F9E),
      ),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 27',
    groups: [
      ConnectionsGroup(
        category: '👕 Tops',
        words: ['TSHIRT', 'BLOUSE', 'POLO', 'SWEATER'],
        color: Color(0xFF6AAA64),
      ),
      ConnectionsGroup(
        category: '🧴 Cosmetics',
        words: ['LIPSTICK', 'MASCARA', 'BLUSH', 'FOUNDATION'],
        color: Color(0xFF4F9EE8),
      ),
      ConnectionsGroup(
        category: '🗣️ Silent-K homophones',
        words: ['KNOT', 'KNEAD', 'KNIGHT', 'KNEW'],
        color: Color(0xFFE67E22),
      ),
      ConnectionsGroup(
        category: '🌾 Grains',
        words: ['WHEAT', 'RICE', 'BARLEY', 'OATS'],
        color: Color(0xFFE84F9E),
      ),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 28',
    groups: [
      ConnectionsGroup(
        category: '🍇 Fruits',
        words: ['GRAPE', 'BERRY', 'FIG', 'DATE'],
        color: Color(0xFF6AAA64),
      ),
      ConnectionsGroup(
        category: '📦 Office supplies',
        words: ['PAPERCLIP', 'STAPLER', 'TAPE', 'FOLDER'],
        color: Color(0xFF4F9EE8),
      ),
      ConnectionsGroup(
        category: '🗣️ Homophones starting with T',
        words: ['TIME', 'TIDE', 'TOAD', 'TALE'],
        color: Color(0xFFE67E22),
      ),
      ConnectionsGroup(
        category: '🦴 Bones',
        words: ['SKULL', 'RIB', 'FEMUR', 'SPINE'],
        color: Color(0xFFE84F9E),
      ),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 29',
    groups: [
      ConnectionsGroup(
        category: '🌧️ Water forms',
        words: ['RAIN', 'DEW', 'FOG', 'MIST'],
        color: Color(0xFF6AAA64),
      ),
      ConnectionsGroup(
        category: '🎭 Moods',
        words: ['HAPPY', 'SAD', 'ANGRY', 'EXCITED'],
        color: Color(0xFF4F9EE8),
      ),
      ConnectionsGroup(
        category: '🗣️ Homophones starting with P',
        words: ['PEAL', 'PEAR', 'PIECE', 'PRIDE'],
        color: Color(0xFFE67E22),
      ),
      ConnectionsGroup(
        category: '🧀 Cheeses',
        words: ['CHEDDAR', 'MOZZARELLA', 'PARMESAN', 'GOUDA'],
        color: Color(0xFFE84F9E),
      ),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 30',
    groups: [
      ConnectionsGroup(
        category: '🧵 Sewing items',
        words: ['NEEDLE', 'THREAD', 'FABRIC', 'THIMBLE'],
        color: Color(0xFF6AAA64),
      ),
      ConnectionsGroup(
        category: '🏔️ Landforms',
        words: ['VALLEY', 'CANYON', 'PLATEAU', 'CLIFF'],
        color: Color(0xFF4F9EE8),
      ),
      ConnectionsGroup(
        category: '🗣️ Homophones starting with R',
        words: ['ROSE', 'RING', 'RAIN', 'ROOT'],
        color: Color(0xFFE67E22),
      ),
      ConnectionsGroup(
        category: '🧴 Bathroom items',
        words: ['SOAP', 'TOWEL', 'BRUSH', 'MIRROR'],
        color: Color(0xFFE84F9E),
      ),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 31',
    groups: [
      ConnectionsGroup(category: '🐕 Dog breeds', words: ['PUG', 'BEAGLE', 'POODLE', 'BOXER'], color: Color(0xFF6AAA64)),
      ConnectionsGroup(category: '🚗 Car brands', words: ['FORD', 'TOYOTA', 'HONDA', 'TESLA'], color: Color(0xFF4F9EE8)),
      ConnectionsGroup(category: '🗣️ Homophones starting with B', words: ['BEE', 'BLUE', 'BARE', 'BRED'], color: Color(0xFFE67E22)),
      ConnectionsGroup(category: '🌲 Trees', words: ['OAK', 'PINE', 'MAPLE', 'BIRCH'], color: Color(0xFFE84F9E)),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 32',
    groups: [
      ConnectionsGroup(category: '🍳 Cooking methods', words: ['FRY', 'BOIL', 'BAKE', 'STEAM'], color: Color(0xFF6AAA64)),
      ConnectionsGroup(category: '🦷 Dental items', words: ['FLOSS', 'BRUSH', 'PASTE', 'RINSE'], color: Color(0xFF4F9EE8)),
      ConnectionsGroup(category: '🗣️ Homophones starting with S', words: ['SEA', 'SON', 'SORE', 'SEEN'], color: Color(0xFFE67E22)),
      ConnectionsGroup(category: '⚽ Soccer positions', words: ['KEEPER', 'FORWARD', 'MIDFIELDER', 'DEFENDER'], color: Color(0xFFE84F9E)),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 33',
    groups: [
      ConnectionsGroup(category: '🎸 Instruments', words: ['GUITAR', 'DRUMS', 'PIANO', 'FLUTE'], color: Color(0xFF6AAA64)),
      ConnectionsGroup(category: '🌌 Celestial objects', words: ['STAR', 'PLANET', 'COMET', 'NEBULA'], color: Color(0xFF4F9EE8)),
      ConnectionsGroup(category: '🗣️ Homophones starting with W', words: ['WON', 'WOOD', 'WAR', 'WROTE'], color: Color(0xFFE67E22)),
      ConnectionsGroup(category: '🧪 Lab equipment', words: ['BEAKER', 'FLASK', 'TUBE', 'SCALE'], color: Color(0xFFE84F9E)),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 34',
    groups: [
      ConnectionsGroup(category: '🍰 Desserts', words: ['CAKE', 'PIE', 'TART', 'COOKIE'], color: Color(0xFF6AAA64)),
      ConnectionsGroup(category: '🦁 African animals', words: ['ZEBRA', 'GIRAFFE', 'RHINO', 'LION'], color: Color(0xFF4F9EE8)),
      ConnectionsGroup(category: '🗣️ Homophones starting with F', words: ['FORE', 'FLEW', 'FAIR', 'FOR'], color: Color(0xFFE67E22)),
      ConnectionsGroup(category: '🧥 Winter clothing', words: ['COAT', 'SCARF', 'GLOVES', 'HAT'], color: Color(0xFFE84F9E)),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 35',
    groups: [
      ConnectionsGroup(category: '🚤 Watercraft', words: ['BOAT', 'SHIP', 'YACHT', 'CANOE'], color: Color(0xFF6AAA64)),
      ConnectionsGroup(category: '📐 Math shapes', words: ['CIRCLE', 'SQUARE', 'OVAL', 'TRIANGLE'], color: Color(0xFF4F9EE8)),
      ConnectionsGroup(category: '🗣️ Homophones starting with M', words: ['MEET', 'MALE', 'MAID', 'MORN'], color: Color(0xFFE67E22)),
      ConnectionsGroup(category: '☕ Coffee types', words: ['LATTE', 'MOCHA', 'ESPRESSO', 'FRAPPE'], color: Color(0xFFE84F9E)),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 36',
    groups: [
      ConnectionsGroup(category: '🥦 Vegetables', words: ['BROCCOLI', 'CARROT', 'SPINACH', 'ONION'], color: Color(0xFF6AAA64)),
      ConnectionsGroup(category: '✈️ Aircraft types', words: ['JET', 'GLIDER', 'HELICOPTER', 'BIPLANE'], color: Color(0xFF4F9EE8)),
      ConnectionsGroup(category: '🗣️ Homophones starting with K', words: ['KNEW', 'KNOT', 'KNIGHT', 'KEY'], color: Color(0xFFE67E22)),
      ConnectionsGroup(category: '⛺ Camping gear', words: ['TENT', 'TARP', 'LANTERN', 'STOVE'], color: Color(0xFFE84F9E)),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 37',
    groups: [
      ConnectionsGroup(category: '🐍 Reptiles', words: ['SNAKE', 'LIZARD', 'TURTLE', 'IGUANA'], color: Color(0xFF6AAA64)),
      ConnectionsGroup(category: '🏦 Bank terms', words: ['LOAN', 'LOOT', 'DEPOSIT', 'VAULT'], color: Color(0xFF4F9EE8)),
      ConnectionsGroup(category: '🗣️ Homophones starting with L', words: ['LAIN', 'LEEK', 'LOAD', 'LUTE'], color: Color(0xFFE67E22)),
      ConnectionsGroup(category: '👔 Office wear', words: ['SUIT', 'TIE', 'SHIRT', 'PANTS'], color: Color(0xFFE84F9E)),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 38',
    groups: [
      ConnectionsGroup(category: '🍹 Drinks', words: ['JUICE', 'SODA', 'WATER', 'MILK'], color: Color(0xFF6AAA64)),
      ConnectionsGroup(category: '🏰 Castle parts', words: ['TOWER', 'MOAT', 'WALL', 'GATE'], color: Color(0xFF4F9EE8)),
      ConnectionsGroup(category: '🗣️ Homophones starting with H', words: ['HARE', 'HEAR', 'HOLE', 'HIM'], color: Color(0xFFE67E22)),
      ConnectionsGroup(category: '🪓 Tools', words: ['AXE', 'SAW', 'HAMMER', 'DRILL'], color: Color(0xFFE84F9E)),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 39',
    groups: [
      ConnectionsGroup(category: '🕷️ Insects', words: ['ANT', 'BEE', 'FLY', 'WASP'], color: Color(0xFF6AAA64)),
      ConnectionsGroup(category: '🛤️ Train terms', words: ['TRACK', 'ENGINE', 'CABOOSE', 'RAIL'], color: Color(0xFF4F9EE8)),
      ConnectionsGroup(category: '🗣️ Homophones starting with C', words: ['COIN', 'COLE', 'CHORD', 'CENT'], color: Color(0xFFE67E22)),
      ConnectionsGroup(category: '🛏️ Bedroom furniture', words: ['BED', 'DRESSER', 'DESK', 'WARDROBE'], color: Color(0xFFE84F9E)),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 40',
    groups: [
      ConnectionsGroup(category: '🐠 Fish', words: ['SALMON', 'TUNA', 'SHARK', 'TROUT'], color: Color(0xFF6AAA64)),
      ConnectionsGroup(category: '📖 Book parts', words: ['PAGE', 'COVER', 'SPINE', 'INDEX'], color: Color(0xFF4F9EE8)),
      ConnectionsGroup(category: '🗣️ Homophones starting with G', words: ['GRATE', 'GILT', 'GUEST', 'GROAN'], color: Color(0xFFE67E22)),
      ConnectionsGroup(category: '🧼 Cleaning supplies', words: ['SOAP', 'SPONGE', 'BLEACH', 'MOP'], color: Color(0xFFE84F9E)),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 41',
    groups: [
      ConnectionsGroup(category: '🐦 Birds', words: ['EAGLE', 'HAWK', 'OWL', 'CROW'], color: Color(0xFF6AAA64)),
      ConnectionsGroup(category: '🎬 Movie genres', words: ['ACTION', 'COMEDY', 'HORROR', 'DRAMA'], color: Color(0xFF4F9EE8)),
      ConnectionsGroup(category: '🗣️ Homophones starting with D', words: ['DEW', 'DEER', 'DAZE', 'DRAFT'], color: Color(0xFFE67E22)),
      ConnectionsGroup(category: '👟 Footwear', words: ['BOOT', 'SHOE', 'SANDAL', 'SNEAKER'], color: Color(0xFFE84F9E)),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 42',
    groups: [
      ConnectionsGroup(category: '🐝 Pollinators', words: ['BEE', 'BUTTERFLY', 'MOTH', 'WASP'], color: Color(0xFF6AAA64)),
      ConnectionsGroup(category: '🏛️ Building styles', words: ['GOTHIC', 'MODERN', 'BAROQUE', 'CLASSICAL'], color: Color(0xFF4F9EE8)),
      ConnectionsGroup(category: '🗣️ Homophones starting with N', words: ['NUN', 'NIGHT', 'NAY', 'NONE'], color: Color(0xFFE67E22)),
      ConnectionsGroup(category: '🧴 Skincare', words: ['LOTION', 'CREAM', 'SERUM', 'TONER'], color: Color(0xFFE84F9E)),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 43',
    groups: [
      ConnectionsGroup(category: '🏔️ Mountains', words: ['EVEREST', 'ANDES', 'ALPS', 'ROCKIES'], color: Color(0xFF6AAA64)),
      ConnectionsGroup(category: '🚢 Ship parts', words: ['DECK', 'MAST', 'STERN', 'BOW'], color: Color(0xFF4F9EE8)),
      ConnectionsGroup(category: '🗣️ Homophones starting with V', words: ['VAIN', 'VIAL', 'VANE', 'VICE'], color: Color(0xFFE67E22)),
      ConnectionsGroup(category: '🕰️ Time units', words: ['SECOND', 'MINUTE', 'HOUR', 'DAY'], color: Color(0xFFE84F9E)),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 44',
    groups: [
      ConnectionsGroup(category: '🌶️ Spices', words: ['PEPPER', 'CUMIN', 'GINGER', 'CLOVE'], color: Color(0xFF6AAA64)),
      ConnectionsGroup(category: '🎭 Theatre roles', words: ['ACTOR', 'DIRECTOR', 'WRITER', 'PRODUCER'], color: Color(0xFF4F9EE8)),
      ConnectionsGroup(category: '🗣️ Homophones starting with A', words: ['AIR', 'ATE', 'AISLE', 'ALOUD'], color: Color(0xFFE67E22)),
      ConnectionsGroup(category: '📎 Fasteners', words: ['CLIP', 'SCREW', 'NAIL', 'BOLT'], color: Color(0xFFE84F9E)),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 45',
    groups: [
      ConnectionsGroup(category: '🌽 Grains', words: ['WHEAT', 'RICE', 'OAT', 'CORN'], color: Color(0xFF6AAA64)),
      ConnectionsGroup(category: '🚀 Space terms', words: ['ORBIT', 'LAUNCH', 'ROCKET', 'GRAVITY'], color: Color(0xFF4F9EE8)),
      ConnectionsGroup(category: '🗣️ Homophones starting with O', words: ['ONE', 'ORE', 'OUR', 'OH'], color: Color(0xFFE67E22)),
      ConnectionsGroup(category: '🔑 Key types', words: ['HOME', 'CAR', 'SKELETON', 'DIGITAL'], color: Color(0xFFE84F9E)),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 46',
    groups: [
      ConnectionsGroup(category: '🐻 Bears', words: ['GRIZZLY', 'POLAR', 'PANDA', 'BROWN'], color: Color(0xFF6AAA64)),
      ConnectionsGroup(category: '🎨 Art tools', words: ['BRUSH', 'CANVAS', 'EASEL', 'PAINT'], color: Color(0xFF4F9EE8)),
      ConnectionsGroup(category: '🗣️ Homophones starting with E', words: ['EIGHT', 'EYE', 'EWE', 'EARN'], color: Color(0xFFE67E22)),
      ConnectionsGroup(category: '🛋️ Living room', words: ['SOFA', 'CHAIR', 'TV', 'TABLE'], color: Color(0xFFE84F9E)),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 47',
    groups: [
      ConnectionsGroup(category: '🐒 Primates', words: ['CHIMP', 'GORILLA', 'MONKEY', 'BABOON'], color: Color(0xFF6AAA64)),
      ConnectionsGroup(category: '🧪 Elements', words: ['GOLD', 'IRON', 'OXYGEN', 'CARBON'], color: Color(0xFF4F9EE8)),
      ConnectionsGroup(category: '🗣️ Homophones starting with P', words: ['PAIR', 'PEAR', 'PEACE', 'PIECE'], color: Color(0xFFE67E22)),
      ConnectionsGroup(category: '👜 Bag styles', words: ['PURSE', 'CLUTCH', 'TOTE', 'BACKPACK'], color: Color(0xFFE84F9E)),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 48',
    groups: [
      ConnectionsGroup(category: '🐾 Footprints', words: ['TRACK', 'PAW', 'CLAW', 'HOOF'], color: Color(0xFF6AAA64)),
      ConnectionsGroup(category: '🎼 Music notes', words: ['DO', 'RE', 'MI', 'FA'], color: Color(0xFF4F9EE8)),
      ConnectionsGroup(category: '🗣️ Homophones starting with W', words: ['WON', 'WOOD', 'WAR', 'WROTE'], color: Color(0xFFE67E22)),
      ConnectionsGroup(category: '🪞 Mirrors', words: ['GLASS', 'FRAME', 'REFLECT', 'SILVER'], color: Color(0xFFE84F9E)),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 49',
    groups: [
      ConnectionsGroup(category: '🌵 Desert plants', words: ['CACTUS', 'ALOE', 'PALM', 'YUCCA'], color: Color(0xFF6AAA64)),
      ConnectionsGroup(category: '🪙 Coins', words: ['PENNY', 'NICKEL', 'DIME', 'QUARTER'], color: Color(0xFF4F9EE8)),
      ConnectionsGroup(category: '🗣️ Homophones starting with Y', words: ['YOU', 'YOUR', 'YOKE', 'YEW'], color: Color(0xFFE67E22)),
      ConnectionsGroup(category: '🕯️ Lighting', words: ['LAMP', 'BULB', 'CANDLE', 'TORCH'], color: Color(0xFFE84F9E)),
    ],
  ),
  ConnectionsPuzzle(
    title: 'Puzzle 50',
    groups: [
      ConnectionsGroup(category: '🦖 Dinosaurs', words: ['REX', 'RAPTOR', 'TRICERATOPS', 'STEGOSAURUS'], color: Color(0xFF6AAA64)),
      ConnectionsGroup(category: '📬 Mail terms', words: ['STAMP', 'ENVELOPE', 'LETTER', 'POST'], color: Color(0xFF4F9EE8)),
      ConnectionsGroup(category: '🗣️ Homophones starting with S', words: ['SON', 'SEA', 'SORE', 'SEEN'], color: Color(0xFFE67E22)),
      ConnectionsGroup(category: '🧹 Cleaning tools', words: ['BROOM', 'MOP', 'DUSTER', 'VACUUM'], color: Color(0xFFE84F9E)),
    ],
  ),
];

class CategoriesScreen extends StatefulWidget {
  final int? dailyLevelIndex;
  const CategoriesScreen({super.key, this.dailyLevelIndex});
  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  int _puzzleIndex = 0;
  late ConnectionsPuzzle _puzzle;
  late List<String> _words;
  final Set<String> _selected = {};
  final List<ConnectionsGroup> _solved = [];
  int _mistakesLeft = 4;
  String _message = '';
  bool _won = false;

  int _hintCount = 0;
  bool _playDailyMode = false;

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
    _playDailyMode = prefs.getBool('play_daily_mode') ?? false;

    int targetLevel = 0;
    if (widget.dailyLevelIndex != null) {
      targetLevel = widget.dailyLevelIndex!;
    } else {
      targetLevel = prefs.getInt('level_connections') ?? 0;
    }

    if (mounted) {
      setState(() {
        _puzzleIndex = targetLevel % _kPuzzles.length;
        _loadPuzzle();
      });
    }

    if (!_playDailyMode) {
      Future.delayed(Duration.zero, () async {
        if (!mounted) return;
        final savedStateStr = prefs.getString('normal_connections_state');
        if (savedStateStr != null) {
          try {
            final data = jsonDecode(savedStateStr);
            if (data['puzzleIndex'] == _puzzleIndex) {
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
                final List<dynamic> wordsData = data['words'];
                final List<String> loadedWords = List<String>.from(wordsData);
                final List<dynamic> solvedInds = data['solvedIndices'];
                
                setState(() {
                  _words = loadedWords;
                  _solved.clear();
                  for (final idx in solvedInds) {
                    if (idx >= 0 && idx < _puzzle.groups.length) {
                      _solved.add(_puzzle.groups[idx]);
                    }
                  }
                  _mistakesLeft = data['mistakesLeft'];
                  _won = data['won'];
                  _message = data['message'] ?? '';
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
      'puzzleIndex': _puzzleIndex,
      'words': _words,
      'solvedIndices': _solved.map((g) => _puzzle.groups.indexOf(g)).toList(),
      'mistakesLeft': _mistakesLeft,
      'won': _won,
      'message': _message,
    };
    await prefs.setString('normal_connections_state', jsonEncode(state));
  }

  Future<void> _clearNormalState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('normal_connections_state');
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
          content: Text(
            'Hint earned! (Total: $newCount)',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppTheme.accentFor('connections'),
        ),
      );
    }
    await _clearNormalState();
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
      _message = 'Hint: One of the categories is "${targetGroup!.category}"';
      AudioManager.playClick();
    });
  }

  void _loadPuzzle() {
    _puzzle = _kPuzzles[_puzzleIndex % _kPuzzles.length];
    _words = _puzzle.groups.expand((g) => g.words).toList()..shuffle();
    _selected.clear();
    _solved.clear();
    _mistakesLeft = 4;
    _message = '';
    _won = false;
  }

  void _toggleWord(String w) {
    if (_won || _isSolved(w)) return;
    setState(() {
      if (_selected.contains(w)) {
        _selected.remove(w);
        AudioManager.playClick();
      } else if (_selected.length < 4) {
        _selected.add(w);
        AudioManager.playClick();
      }
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
          _message = 'Correct! "${group.category}"';
          AudioManager.playSuccess();
          if (_solved.length == _puzzle.groups.length) {
            _won = true;
            _savePersistedLevel(_puzzleIndex + 1);
          }
        });
        _saveNormalState();
        return;
      }
    }

    // Check if one away
    bool oneAway = false;
    for (final group in _puzzle.groups) {
      if (_solved.contains(group)) continue;
      final intersectionCount = group.words
          .toSet()
          .intersection(_selected)
          .length;
      if (intersectionCount == 3) {
        oneAway = true;
        break;
      }
    }

    setState(() {
      _mistakesLeft--;
      AudioManager.playFail();
      if (_mistakesLeft <= 0) {
        _message = 'Out of guesses!';
        _won = false;
      } else {
        _message = oneAway
            ? 'One away! $_mistakesLeft mistakes left.'
            : 'Wrong! $_mistakesLeft mistakes left.';
      }
    });
    _saveNormalState();
  }

  void _reset() => setState(() => _loadPuzzle());
  void _nextPuzzle() {
    if (!_won) return;
    setState(() {
      _puzzleIndex = (_puzzleIndex + 1) % _kPuzzles.length;
      _loadPuzzle();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mistakes = 4 - _mistakesLeft;
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        backgroundColor: context.bgDark,
        foregroundColor: context.textPrimary,
        title: Text(
          'Categories',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
          ),
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
            onPressed: !_won && _mistakesLeft > 0
                ? () async {
                    if (_hintCount > 0) {
                      _useHint();
                    } else {
                      await BuyHintsDialog.show(
                        context,
                        initialGameId: 'connections',
                        onPurchaseComplete: () async {
                          final newCount = await HintManager.getHints('connections');
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
              'connections',
              'Categories',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _reset,
            color: context.textMuted,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                _playDailyMode ? 'Daily' : 'Level ${_puzzleIndex + 1}',
                style: AppTheme.numberStyle(
                  color: AppTheme.connectionsRed,
                  fontSize: context.scale(13),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Mistakes left text and dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Mistakes: ',
                    style: GoogleFonts.outfit(
                      color: context.textSecondary,
                      fontSize: context.scale(14),
                    ),
                  ),
                  ...List.generate(
                    4,
                    (i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: CircleAvatar(
                        radius: 7,
                        backgroundColor: i < mistakes
                            ? Colors.redAccent
                            : context.bgSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Solved groups
              ..._solved.map((g) => _SolvedGroup(group: g)),
              if (_solved.isNotEmpty) const SizedBox(height: 8),
              // Word grid
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
                childAspectRatio: 1.3,
                children: _words.map((w) {
                  final sel = _selected.contains(w);
                  return GestureDetector(
                    onTap: () => _toggleWord(w),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: sel ? AppTheme.connectionsRed : context.bgCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: sel
                              ? AppTheme.connectionsRed
                              : context.textMuted.withAlpha(60),
                          width: 1.2,
                        ),
                        boxShadow: sel ? null : AppTheme.cardShadow,
                      ),
                      child: Center(
                        child: Text(
                          w,
                          style: GoogleFonts.outfit(
                            fontSize: context.scale(11),
                            fontWeight: FontWeight.bold,
                            color: sel ? Colors.white : context.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              if (_message.isNotEmpty)
                Text(
                  _message,
                  style: GoogleFonts.outfit(
                    color: context.textSecondary,
                    fontSize: context.scale(14),
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 12),
              if (!_won && _mistakesLeft > 0) ...[
                Text(
                  'Select 4 words',
                  style: GoogleFonts.outfit(
                    color: context.textMuted,
                    fontSize: context.scale(12),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selected.length == 4
                        ? AppTheme.connectionsRed
                        : context.bgSurface,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _selected.length == 4 ? _submit : null,
                  child: Text(
                    'Submit',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: context.scale(14),
                    ),
                  ),
                ),
              ],
              if (_won || _mistakesLeft <= 0) ...[
                const SizedBox(height: 8),
                Text(
                  _won ? 'All groups found!' : 'Better luck next time!',
                  style: GoogleFonts.outfit(
                    fontSize: context.scale(18),
                    color: _won ? AppTheme.connectionsRed : Colors.redAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                if (_won)
                  AutoNextCountdown(
                    onNext: _nextPuzzle,
                    accentColor: AppTheme.connectionsRed,
                  )
                else
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.bgSurface,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _reset,
                    child: Text(
                      'Try Again',
                      style: GoogleFonts.outfit(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: context.scale(14),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SolvedGroup extends StatelessWidget {
  final ConnectionsGroup group;
  const _SolvedGroup({required this.group});

  Color _getZenColor(Color original) {
    if (original.value == 0xFF6AAA64) return const Color(0xFF7FA875); // Sage
    if (original.value == 0xFF4F9EE8)
      return const Color(0xFF6C96BC); // Slate Blue
    if (original.value == 0xFFE67E22)
      return const Color(0xFFC58652); // Warm Amber
    if (original.value == 0xFFE84F9E)
      return const Color(0xFFBD7FA3); // Soft Rose
    return original;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getZenColor(group.color);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withAlpha(context.isDarkMode ? 35 : 45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(90), width: 1.2),
      ),
      child: Column(
        children: [
          Text(
            group.category,
            style: GoogleFonts.outfit(
              fontSize: context.scale(13),
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            group.words.join(' • '),
            style: GoogleFonts.outfit(
              fontSize: context.scale(12),
              color: context.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
