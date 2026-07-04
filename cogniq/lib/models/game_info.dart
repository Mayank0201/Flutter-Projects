class GameInfo {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final String routeName;
  const GameInfo({required this.id, required this.name, required this.description, required this.emoji, required this.routeName});
}

const List<GameInfo> kAllGames = [
  GameInfo(id:'zip',         name:'Grid Path',    description:'Drag to fill the entire path',          emoji:'⚡', routeName:'/zip'),
  GameInfo(id:'wordle',      name:'Word Guess',   description:'Guess the 5-letter word in 6 tries',    emoji:'', routeName:'/wordle'),
  GameInfo(id:'oddcolor',    name:'Odd Color Out',  description:'Find the tile with a slightly off-color shade', emoji:'🎨', routeName:'/oddcolor'),
  GameInfo(id:'chimp',       name:'Chimp Test',   description:'Tap numbers in order from memory',     emoji:'', routeName:'/chimp'),
  // GameInfo(id:'weaver',      name:'Word Ladder',  description:'Change one letter at a time',           emoji:'️', routeName:'/weaver'),
  GameInfo(id:'queens',      name:'Star Battle',  description:'Place stars avoiding row, column, and color overlaps', emoji:'♛', routeName:'/queens'),
  GameInfo(id:'memory',      name:'Mahjong Solitaire', description:'Match free pairs of tiles to clear the board',             emoji:'', routeName:'/memory'),
  GameInfo(id:'minesweeper', name:'Mine Finder', description:'Locate and flag all hidden mines on the grid', emoji:'💣', routeName:'/minesweeper'),
  GameInfo(id:'hangman',     name:'Hangman',      description:'Save the stick figure letter by letter', emoji:'', routeName:'/hangman'),
  // GameInfo(id:'reaction',    name:'Reaction Time', description:'Test your reflexes in milliseconds',   emoji:'⚡', routeName:'/reaction'),
  GameInfo(id:'nonogram',    name:'Nonogram',     description:'Fill grid cells to match row/column clues', emoji:'🧩', routeName:'/nonogram'),
  GameInfo(id:'hue',         name:'Spectrum',      description:'Arrange tiles to form a perfect color gradient', emoji:'🌈', routeName:'/hue'),
  GameInfo(id:'numbermemory', name:'Number Memory', description:'Memorize and recall growing numbers', emoji:'', routeName:'/numbermemory'),
  GameInfo(id:'wordbuilder', name:'Word Builder', description:'Form words using only given letters',   emoji:'', routeName:'/wordbuilder'),
  GameInfo(id:'sudoku',      name:'Sudoku',       description:'Solve the mini 4x4 number grid',        emoji:'', routeName:'/sudoku'),
  GameInfo(id:'sequence',    name:'Sequence Memory', description:'Repeat the tile pattern from memory', emoji:'', routeName:'/sequence'),
  // GameInfo(id:'crossclimb',  name:'Word Climb',   description:'Climb the 5-step trivia ladder',       emoji:'', routeName:'/crossclimb'),
  GameInfo(id:'connections', name:'Categories',   description:'Group 16 words into 4 categories',     emoji:'', routeName:'/connections'),
  GameInfo(id:'flagle',      name:'Flag Finder',  description:'Guess the country by revealing flag segments', emoji:'', routeName:'/flagle'),
  GameInfo(id:'spellingbee', name:'Word Hive',    description:'Form words with honeycomb letters',    emoji:'', routeName:'/spellingbee'),
  GameInfo(id:'wordsearch',  name:'Word Search',  description:'Find target words hidden in grid',     emoji:'', routeName:'/wordsearch'),
];
