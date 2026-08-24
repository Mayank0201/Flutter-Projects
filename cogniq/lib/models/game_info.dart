class GameInfo {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final String routeName;
  final bool isStashed;

  const GameInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.routeName,
    this.isStashed = false,
  });
}

const List<GameInfo> kAllGames = [
  GameInfo(id:'zip',         name:'Grid Path',    description:'Drag to fill the entire path',          emoji:'⚡', routeName:'/zip'),
  GameInfo(id:'oddcolor',    name:'Odd Color Out',  description:'Find the tile with a slightly off-color shade', emoji:'🎨', routeName:'/oddcolor'),
  GameInfo(id:'chimp',       name:'Chimp Test',   description:'Tap numbers in order from memory',     emoji:'', routeName:'/chimp'),
  GameInfo(id:'queens',      name:'Star Battle',  description:'Place stars avoiding row, column, and color overlaps', emoji:'♛', routeName:'/queens'),
  GameInfo(id:'minesweeper', name:'Mine Finder', description:'Locate and flag all hidden mines on the grid', emoji:'💣', routeName:'/minesweeper'),
  GameInfo(id:'hue',         name:'Spectrum',      description:'Arrange tiles to form a perfect color gradient', emoji:'🌈', routeName:'/hue'),
  GameInfo(id:'sudoku',      name:'Sudoku',       description:'Solve the mini 4x4 number grid',        emoji:'', routeName:'/sudoku'),
  GameInfo(id:'spellingbee', name:'Word Hive',    description:'Form words with honeycomb letters',    emoji:'', routeName:'/spellingbee'),
  
  // Graduate Games
  GameInfo(id:'pattern_lock', name:'Pattern Lock', description:'Trace the pattern from memory', emoji:'🔒', routeName:'/pattern_lock'),
  GameInfo(id:'colour_link', name:'Colour Link', description:'Link matching colors without crossing', emoji:'🔗', routeName:'/colour_link'),
  GameInfo(id:'color_flood', name:'Color Flood', description:'Flood the grid with a single color', emoji:'💧', routeName:'/color_flood'),
  GameInfo(id:'circuit_guide', name:'Circuit Guide', description:'Rotate wires to power all Bulbs', emoji:'🔌', routeName:'/circuit_guide'),
  GameInfo(id:'kakuro', name:'Kakuro', description:'Crossword-style addition grid puzzle', emoji:'🧩', routeName:'/kakuro', isStashed: true),
  GameInfo(id:'sandsort', name:'Sand Sort', description:'Pour sand layers until every tube is one color', emoji:'⏳', routeName:'/sandsort', isStashed: true),
  GameInfo(id:'lightbeam', name:'Light Beam', description:'Bend the beam with mirrors to light every crystal', emoji:'🔦', routeName:'/lightbeam', isStashed: true),
  GameInfo(id:'cipherdecoder', name:'Cipher Decoder', description:'Decode the secret shifting phrase', emoji:'🔑', routeName:'/cipher_decoder', isStashed: true),
  GameInfo(id:'hitori', name:'Hitori', description:'Shade duplicates in rows and columns', emoji:'🔲', routeName:'/hitori', isStashed: true),
  GameInfo(id:'untangle', name:'Untangle', description:'Drag the dots until no lines cross', emoji:'🕸️', routeName:'/untangle', isStashed: true),
  GameInfo(id:'zenslide', name:'Zen Slide', description:'Swipe the sage stone across the ice onto the lotus', emoji:'🪨', routeName:'/zenslide', isStashed: true),
  GameInfo(id:'slitherlink', name:'Slitherlink', description:'Connect dots to form a single loop', emoji:'⭕', routeName:'/slitherlink', isStashed: true),
  GameInfo(id:'masyu', name:'Pearl Loop', description:'Draw a loop through black and white pearls', emoji:'⭕', routeName:'/masyu'),
  GameInfo(id:'bridges', name:'Bridges', description:'Connect islands with bridges', emoji:'🌉', routeName:'/bridges'),
  GameInfo(id:'sumstrike', name:'Sum Strike', description:'Strike out numbers to match row and column sums', emoji:'➕', routeName:'/sumstrike'),
  GameInfo(id:'killersudoku', name:'Killer Sudoku', description:'Fill grid with cage sums and Sudoku rules', emoji:'🔢', routeName:'/killersudoku'),
];
