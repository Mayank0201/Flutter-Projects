class GameInfo {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final String routeName;
  const GameInfo({required this.id, required this.name, required this.description, required this.emoji, required this.routeName});
}

const List<GameInfo> kAllGames = [
  GameInfo(id:'wordle',      name:'Word Guess',   description:'Guess the 5-letter word in 6 tries',    emoji:'', routeName:'/wordle'),
  GameInfo(id:'hangman',     name:'Hangman',      description:'Save the stick figure letter by letter', emoji:'', routeName:'/hangman'),
  GameInfo(id:'weaver',      name:'Word Ladder',  description:'Change one letter at a time',           emoji:'️', routeName:'/weaver'),
  GameInfo(id:'zip',         name:'Zip',          description:'Drag to fill the entire path',          emoji:'⚡', routeName:'/zip'),
  GameInfo(id:'crossclimb',  name:'Word Climb',   description:'Climb the 5-step trivia ladder',       emoji:'', routeName:'/crossclimb'),
  GameInfo(id:'queens',      name:'Star Battle',  description:'Place stars avoiding row, column, and color overlaps', emoji:'♛', routeName:'/queens'),
  GameInfo(id:'chimp',       name:'Chimp Test',   description:'Tap numbers in order from memory',     emoji:'', routeName:'/chimp'),
  GameInfo(id:'connections', name:'Categories',   description:'Group 16 words into 4 categories',     emoji:'', routeName:'/connections'),
  GameInfo(id:'flagle',      name:'Flag Finder',  description:'Guess the country by revealing flag segments', emoji:'', routeName:'/flagle'),
  GameInfo(id:'wordbuilder', name:'Word Builder', description:'Form words using only given letters',   emoji:'', routeName:'/wordbuilder'),
  GameInfo(id:'memory',      name:'Memory Match', description:'Find matching card pairs',             emoji:'', routeName:'/memory'),
  GameInfo(id:'spellingbee', name:'Word Hive',    description:'Form words with honeycomb letters',    emoji:'', routeName:'/spellingbee'),
  GameInfo(id:'sudoku',      name:'Sudoku',       description:'Solve the mini 4x4 number grid',        emoji:'', routeName:'/sudoku'),
  GameInfo(id:'wordsearch',  name:'Word Search',  description:'Find target words hidden in grid',     emoji:'', routeName:'/wordsearch'),
  GameInfo(id:'twentyfortyeight', name:'2048',    description:'Swipe and merge tiles to hit the target', emoji:'', routeName:'/2048'),
  GameInfo(id:'reaction',    name:'Reaction Time', description:'Test your reflexes in milliseconds',   emoji:'⚡', routeName:'/reaction'),
  GameInfo(id:'numbermemory', name:'Number Memory', description:'Memorize and recall growing numbers', emoji:'', routeName:'/numbermemory'),
  GameInfo(id:'sequence',    name:'Sequence Memory', description:'Repeat the tile pattern from memory', emoji:'', routeName:'/sequence'),
];
