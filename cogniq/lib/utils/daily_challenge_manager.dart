import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';
import '../models/game_info.dart';
import 'notification_manager.dart';
import 'prefs_keys.dart';
import 'point_manager.dart';

class DailyChallenge {
  final String difficulty; // 'Easy', 'Medium', 'Hard'
  final GameInfo game;
  final int levelIndex;
  final String modifierName;
  final String modifierDescription;
  final String? modifierType;
  final Map<String, dynamic>? extraParams;

  const DailyChallenge({
    required this.difficulty,
    required this.game,
    required this.levelIndex,
    required this.modifierName,
    required this.modifierDescription,
    this.modifierType,
    this.extraParams,
  });

  DailyChallenge copyWith({
    String? difficulty,
    GameInfo? game,
    int? levelIndex,
    String? modifierName,
    String? modifierDescription,
    String? modifierType,
    Map<String, dynamic>? extraParams,
  }) {
    return DailyChallenge(
      difficulty: difficulty ?? this.difficulty,
      game: game ?? this.game,
      levelIndex: levelIndex ?? this.levelIndex,
      modifierName: modifierName ?? this.modifierName,
      modifierDescription: modifierDescription ?? this.modifierDescription,
      modifierType: modifierType ?? this.modifierType,
      extraParams: extraParams ?? this.extraParams,
    );
  }
}

class _ChallengeData {
  final String gameId;
  final String difficulty;          // Day-1 slot label (informational only)
  final int levelIndex;             // now the game's EASY base level
  final int step;                   // level added per difficulty rank (default 3)
  final int? pinDifficulty;         // null = rotates; 0 = pinned to Easy (Chimp)
  final String modifierName;
  final String modifierDescription;
  final String? modifierType;
  final Map<String, dynamic>? extraParams;

  const _ChallengeData({
    required this.gameId,
    required this.difficulty,
    required this.levelIndex,
    this.step = 3,
    this.pinDifficulty,
    required this.modifierName,
    required this.modifierDescription,
    this.modifierType,
    this.extraParams,
  });
}

class _DayData {
  final String theme;
  final _ChallengeData easy;
  final _ChallengeData medium;
  final _ChallengeData hard;

  const _DayData({
    required this.theme,
    required this.easy,
    required this.medium,
    required this.hard,
  });
}

class DailyChallengeManager {
  static const List<_DayData> _kDailyChallengesPlan = [
    // Day 1: Fog Day
    _DayData(
      theme: 'Fog Day',
      easy: _ChallengeData(
        gameId: 'oddcolor',
        difficulty: 'Easy',
        levelIndex: 1,
        step: 3,
        modifierName: 'Foggy Focus',
        modifierDescription: 'A heavy fog obscures the screen. Only the cells immediately surrounding the selected cell/pointer are visible.',
        modifierType: 'fog',
        extraParams: {'radius': 1},
      ),
      medium: _ChallengeData(
        gameId: 'sudoku',
        difficulty: 'Medium',
        levelIndex: 6,
        step: 3,
        modifierName: 'Sudoku in the Mist',
        modifierDescription: 'The Sudoku board is blacked out by fog. Selecting a cell illuminates a 3x3 region around it.',
        modifierType: 'fog',
        extraParams: {'radius': 2.2, 'gridSize': 6},
      ),
      hard: _ChallengeData(
        gameId: 'minesweeper',
        difficulty: 'Hard',
        levelIndex: 5,
        step: 5,
        modifierName: 'Dark Minefield',
        modifierDescription: 'Visibility is limited to a small spotlight around your cursor. Uncover safe cells without stepping on hidden mines.',
        modifierType: 'fog',
        extraParams: {'radius': 1.5},
      ),
    ),
    // Day 2: Mirror Day
    _DayData(
      theme: 'Mirror Day',
      easy: _ChallengeData(
        gameId: 'zip',
        difficulty: 'Easy',
        levelIndex: 1,
        step: 3,
        modifierName: 'Flipped Maze',
        modifierDescription: 'The board and directional drawing coordinates are horizontally mirrored. Trace the path in reverse-visual alignment.',
        modifierType: 'mirror',
      ),
      medium: _ChallengeData(
        gameId: 'pattern_lock',
        difficulty: 'Medium',
        levelIndex: 2,
        step: 2,
        modifierName: 'Flipped Trace',
        modifierDescription: 'The pattern lock grid and the visual preview lines are horizontally mirrored.',
        modifierType: 'mirror',
      ),
      hard: _ChallengeData(
        gameId: 'queens',
        difficulty: 'Hard',
        levelIndex: 4,
        step: 3,
        modifierName: 'Reflected Matrix',
        modifierDescription: 'The grid is visually flipped left-to-right. Place stars avoiding overlaps.',
        modifierType: 'mirror',
      ),
    ),
    // Day 3: Monochrome Day
    _DayData(
      theme: 'Monochrome Day',
      easy: _ChallengeData(
        gameId: 'oddcolor',
        difficulty: 'Easy',
        levelIndex: 1,
        step: 3,
        modifierName: 'Grayscale Contrast',
        modifierDescription: 'The grid is rendered entirely in shades of gray. Locate the tile with the slightly different brightness level.',
        modifierType: 'monochrome',
      ),
      medium: _ChallengeData(
        gameId: 'hue',
        difficulty: 'Medium',
        levelIndex: 6,
        step: 3,
        modifierName: 'Monochrome Bands',
        modifierDescription: 'Sort color tiles of very close gray/silver intensities from black to white.',
        modifierType: 'monochrome',
      ),
      hard: _ChallengeData(
        gameId: 'colour_link',
        difficulty: 'Hard',
        levelIndex: 1,
        step: 2,
        modifierName: 'Monochrome Links',
        modifierDescription: 'Colors are replaced with shades of gray/silver. Connect links by matching shades.',
        modifierType: 'monochrome',
      ),
    ),
    // Day 4: Retro Day
    _DayData(
      theme: 'Retro Day',
      easy: _ChallengeData(
        gameId: 'oddcolor',
        difficulty: 'Easy',
        levelIndex: 1,
        step: 3,
        modifierName: 'Pixelated Shade',
        modifierDescription: 'The color tiles are rendered as blocky, pixelated textures. Find the odd shade.',
        modifierType: 'retro',
      ),
      medium: _ChallengeData(
        gameId: 'circuit_guide',
        difficulty: 'Medium',
        levelIndex: 2,
        step: 2,
        modifierName: 'Pixel Grid',
        modifierDescription: 'The wires are rendered with high-contrast retro green pixel lines and blocky terminals.',
        modifierType: 'retro',
      ),
      hard: _ChallengeData(
        gameId: 'zip',
        difficulty: 'Hard',
        levelIndex: 10,
        step: 6,
        modifierName: 'Pixel Grid',
        modifierDescription: 'Grid cells are hidden; you only see a low-res heat-map indicating path proximity (brighter = closer to path).',
        modifierType: 'retro',
      ),
    ),
    // Day 5: Glitch Day
    _DayData(
      theme: 'Glitch Day',
      easy: _ChallengeData(
        gameId: 'chimp',
        difficulty: 'Easy',
        levelIndex: 1,
        step: 0,
        pinDifficulty: 0,
        modifierName: 'Corrupted Sequence',
        modifierDescription: 'The numbers briefly glitch or show random symbols, requiring fast memorization.',
        modifierType: 'glitch',
      ),
      medium: _ChallengeData(
        gameId: 'sudoku',
        difficulty: 'Medium',
        levelIndex: 6,
        step: 3,
        modifierName: 'Shifting Numbers',
        modifierDescription: 'Once mid-game (after 5 entries), two rows swap their contents, forcing you to adapt your reasoning.',
        modifierType: 'glitch',
      ),
      hard: _ChallengeData(
        gameId: 'queens',
        difficulty: 'Hard',
        levelIndex: 2,
        step: 3,
        modifierName: 'Glitch Matrix',
        modifierDescription: 'A visual interference/static effect briefly disrupts grid boundaries.',
        modifierType: 'glitch',
      ),
    ),
    // Day 6: Whisper Day
    _DayData(
      theme: 'Whisper Day',
      easy: _ChallengeData(
        gameId: 'oddcolor',
        difficulty: 'Easy',
        levelIndex: 3,
        step: 3,
        modifierName: 'Silent Contrast',
        modifierDescription: 'The brightness differences between cells are extremely quiet (low delta), forcing concentration.',
        modifierType: 'whisper',
      ),
      medium: _ChallengeData(
        gameId: 'spellingbee',
        difficulty: 'Medium',
        levelIndex: 6,
        step: 3,
        modifierName: 'Hidden Center',
        modifierDescription: 'The central letter of the hive is hidden/blank. Deduce it and find the target number of words.',
        modifierType: 'whisper',
      ),
      hard: _ChallengeData(
        gameId: 'sumstrike',
        difficulty: 'Hard',
        levelIndex: 1,
        step: 2,
        modifierName: 'Silent Columns',
        modifierDescription: 'The row/column target sums are hidden (blanked out), and you must deduce them from intersections.',
        modifierType: 'whisper',
      ),
    ),
    // Day 7: Hidden Rule Day
    _DayData(
      theme: 'Hidden Rule Day',
      easy: _ChallengeData(
        gameId: 'oddcolor',
        difficulty: 'Easy',
        levelIndex: 1,
        step: 3,
        modifierName: 'Secret Anchor',
        modifierDescription: 'The odd color cell isn\'t a different shade; it\'s the tile whose color matches the background layout.',
        modifierType: 'hidden_rule',
      ),
      medium: _ChallengeData(
        gameId: 'minesweeper',
        difficulty: 'Medium',
        levelIndex: 6,
        step: 3,
        modifierName: 'Safe Corners',
        modifierDescription: 'The corners of the grid are guaranteed to contain mines, but clicking them reveals adjacent numbers without exploding.',
        modifierType: 'hidden_rule',
      ),
      hard: _ChallengeData(
        gameId: 'queens',
        difficulty: 'Hard',
        levelIndex: 5,
        step: 5,
        modifierName: 'Diagonal Shield',
        modifierDescription: 'A secret rule applies: no two stars can be diagonally adjacent (normally allowed if not touching).',
        modifierType: 'hidden_rule',
      ),
    ),
    // Day 8: Zoom Day
    _DayData(
      theme: 'Zoom Day',
      easy: _ChallengeData(
        gameId: 'queens',
        difficulty: 'Easy',
        levelIndex: 2,
        step: 3,
        modifierName: 'Macro Grid',
        modifierDescription: 'The board is zoomed in, requiring the player to drag and pan to locate safe zones.',
        modifierType: 'zoom',
      ),
      medium: _ChallengeData(
        gameId: 'sudoku',
        difficulty: 'Medium',
        levelIndex: 4,
        step: 3,
        modifierName: 'Cropped Clues',
        modifierDescription: 'A small portion of the board is zoomed in. Solve the grid.',
        modifierType: 'zoom',
      ),
      hard: _ChallengeData(
        gameId: 'bridges',
        difficulty: 'Hard',
        levelIndex: 1,
        step: 2,
        modifierName: 'Macro Bridges',
        modifierDescription: 'The map is zoomed in, requiring panning around the screen to build island bridges.',
        modifierType: 'zoom',
      ),
    ),
    // Day 9: Eclipse Day
    _DayData(
      theme: 'Eclipse Day',
      easy: _ChallengeData(
        gameId: 'oddcolor',
        difficulty: 'Easy',
        levelIndex: 1,
        step: 3,
        modifierName: 'Shadow Grid',
        modifierDescription: 'The grid wanes in and out of shadows every 3 seconds. Tap the odd shade.',
        modifierType: 'eclipse',
      ),
      medium: _ChallengeData(
        gameId: 'pattern_lock',
        difficulty: 'Medium',
        levelIndex: 1,
        step: 2,
        modifierName: 'Vanishing Lock',
        modifierDescription: 'The pattern dots go dark/eclipse every 4 seconds. Draw during lit windows.',
        modifierType: 'eclipse',
      ),
      hard: _ChallengeData(
        gameId: 'sudoku',
        difficulty: 'Hard',
        levelIndex: 10,
        step: 6,
        modifierName: 'Blackout Board',
        modifierDescription: 'The board goes completely dark for 2 seconds every 40 seconds. Use the lit intervals to plan your moves.',
        modifierType: 'eclipse',
        extraParams: {'duration': 2, 'interval': 40},
      ),
    ),
    // Day 10: Spy Day
    _DayData(
      theme: 'Spy Day',
      easy: _ChallengeData(
        gameId: 'spellingbee',
        difficulty: 'Easy',
        levelIndex: 1,
        step: 3,
        modifierName: 'Encrypted Words',
        modifierDescription: 'Words in the list are scrambled. Scan and solve them inside the Hive.',
        modifierType: 'spy',
      ),
      medium: _ChallengeData(
        gameId: 'queens',
        difficulty: 'Medium',
        levelIndex: 6,
        step: 3,
        modifierName: 'Decoy Region',
        modifierDescription: 'One color region contains zero stars instead of one, and no two stars are in the same region. Deduce the anomaly.',
        modifierType: 'spy',
      ),
      hard: _ChallengeData(
        gameId: 'killersudoku',
        difficulty: 'Hard',
        levelIndex: 1,
        step: 2,
        modifierName: 'Double Agent Cage',
        modifierDescription: 'One cage sum is a decoy/lie (mathematically incorrect). You must locate and bypass it.',
        modifierType: 'spy',
      ),
    ),
    // Day 11: Chaos Day
    _DayData(
      theme: 'Chaos Day',
      easy: _ChallengeData(
        gameId: 'oddcolor',
        difficulty: 'Easy',
        levelIndex: 1,
        step: 3,
        modifierName: 'Pulse Shift',
        modifierDescription: 'Colors wane and morph into a new palette every 4 seconds. Tap the odd color before it changes.',
        modifierType: 'chaos',
      ),
      medium: _ChallengeData(
        gameId: 'chimp',
        difficulty: 'Medium',
        levelIndex: 2,
        step: 0,
        pinDifficulty: 0,
        modifierName: 'Shifting Patches',
        modifierDescription: 'The numbers shuffle and swap grid slots after you tap the first 3 digits.',
        modifierType: 'chaos',
      ),
      hard: _ChallengeData(
        gameId: 'color_flood',
        difficulty: 'Hard',
        levelIndex: 1,
        step: 2,
        modifierName: 'Collapsing Moves',
        modifierDescription: 'Colors randomly shuffle after every 4 moves, requiring rapid adaptation.',
        modifierType: 'chaos',
      ),
    ),
    // Day 12: Nightmare Trial
    _DayData(
      theme: 'Nightmare Trial',
      easy: _ChallengeData(
        gameId: 'spellingbee',
        difficulty: 'Easy',
        levelIndex: 2,
        step: 3,
        modifierName: 'Bare Hive',
        modifierDescription: 'No starting letter helper cues are provided in the input bar.',
        modifierType: 'minimal',
      ),
      medium: _ChallengeData(
        gameId: 'sudoku',
        difficulty: 'Medium',
        levelIndex: 6,
        step: 3,
        modifierName: 'Bare Board',
        modifierDescription: 'Solve a 9x9 grid starting with only 12 clues (ordinary grids have 20+).',
        modifierType: 'minimal',
      ),
      hard: _ChallengeData(
        gameId: 'zip',
        difficulty: 'Hard',
        levelIndex: 9,
        step: 7,
        modifierName: 'Blind Steps',
        modifierDescription: 'The waypoints vanish 1 second after the round starts. Connect them entirely from memory.',
        modifierType: 'minimal',
      ),
    ),
    // Day 13: Prism Day
    _DayData(
      theme: 'Prism Day',
      easy: _ChallengeData(
        gameId: 'oddcolor',
        difficulty: 'Easy',
        levelIndex: 6,
        step: 3,
        modifierName: 'Split Prism',
        modifierDescription: 'The grid is divided diagonally into two distinct color ranges. Find the odd shade.',
        modifierType: 'prism',
      ),
      medium: _ChallengeData(
        gameId: 'hue',
        difficulty: 'Medium',
        levelIndex: 1,
        step: 2,
        modifierName: 'Rainbow Twist',
        modifierDescription: 'The four corner target colors rotate clockwise by 90 degrees every time you make a correct swap.',
        modifierType: 'prism',
      ),
      hard: _ChallengeData(
        gameId: 'masyu',
        difficulty: 'Hard',
        levelIndex: 1,
        step: 2,
        modifierName: 'Inverted Pearls',
        modifierDescription: 'Black pearls act as white pearls and vice-versa, flipping loop rules.',
        modifierType: 'prism',
      ),
    ),
    // Day 14: Time Warp Day
    _DayData(
      theme: 'Time Warp Day',
      easy: _ChallengeData(
        gameId: 'oddcolor',
        difficulty: 'Easy',
        levelIndex: 3,
        step: 3,
        modifierName: 'Rapid Warp',
        modifierDescription: 'Color grids morph palettes every 2 seconds. Tap the odd shade quickly.',
        modifierType: 'time_warp',
      ),
      medium: _ChallengeData(
        gameId: 'chimp',
        difficulty: 'Medium',
        levelIndex: 2,
        step: 0,
        pinDifficulty: 0,
        modifierName: 'Vanish Board',
        modifierDescription: 'Numbers vanish after 1 second of visibility, forcing rapid recall.',
        modifierType: 'time_warp',
      ),
      hard: _ChallengeData(
        gameId: 'sudoku',
        difficulty: 'Hard',
        levelIndex: 10,
        step: 6,
        modifierName: 'Hourglass Board',
        modifierDescription: 'A ticking timer runs. Correct numbers add 5 seconds; incorrect guesses subtract 10.',
        modifierType: 'time_warp',
      ),
    ),
    // Day 15: Gravity Day
    _DayData(
      theme: 'Gravity Day',
      easy: _ChallengeData(
        gameId: 'chimp',
        difficulty: 'Easy',
        levelIndex: 1, // 5 numbers
        modifierName: 'Falling Numbers',
        modifierDescription: 'Tapping a number makes the remaining tiles sink downwards to fill the gap.',
        modifierType: 'gravity',
      ),
      medium: _ChallengeData(
        gameId: 'memory',
        difficulty: 'Medium',
        levelIndex: 12,
        modifierName: 'Sliding Tiles',
        modifierDescription: 'Matching a pair causes the remaining tiles above to slide downwards, opening new matches.',
        modifierType: 'gravity',
      ),
      hard: _ChallengeData(
        gameId: 'sudoku',
        difficulty: 'Hard',
        levelIndex: 12,
        modifierName: 'Sinking Clues',
        modifierDescription: 'Solve the grid while numbers sink downwards.',
        modifierType: 'gravity',
      ),
    ),
    // Day 16: Illusion Day
    _DayData(
      theme: 'Illusion Day',
      easy: _ChallengeData(
        gameId: 'flagle',
        difficulty: 'Easy',
        levelIndex: 1,
        modifierName: 'Textured Banners',
        modifierDescription: 'Colors of the flag are replaced by textures (lines, dots). Identify the country.',
        modifierType: 'illusion',
      ),
      medium: _ChallengeData(
        gameId: 'oddcolor',
        difficulty: 'Medium',
        levelIndex: 12,
        modifierName: 'Jitter Grid',
        modifierDescription: 'The grid wiggles slightly, making color boundaries appear blurry.',
        modifierType: 'illusion',
      ),
      hard: _ChallengeData(
        gameId: 'hue',
        difficulty: 'Hard',
        levelIndex: 22,
        modifierName: 'Optical Shimmer',
        modifierDescription: 'The background behind the tiles wiggles in a shifting pattern, distorting color perception.',
        modifierType: 'illusion',
      ),
    ),
    // Day 17: Restriction Day
    _DayData(
      theme: 'Restriction Day',
      easy: _ChallengeData(
        gameId: 'hangman',
        difficulty: 'Easy',
        levelIndex: 2,
        modifierName: 'Vowel Void',
        modifierDescription: 'Vowels are blocked on the keyboard; you must solve the word using only consonants.',
        modifierType: 'restriction',
      ),
      medium: _ChallengeData(
        gameId: 'spellingbee',
        difficulty: 'Medium',
        levelIndex: 12,
        modifierName: 'Outer Ring Only',
        modifierDescription: 'You can only connect words using letters in the outer ring of the hive.',
        modifierType: 'restriction',
      ),
      hard: _ChallengeData(
        gameId: 'wordbuilder',
        difficulty: 'Hard',
        levelIndex: 22,
        modifierName: 'Orthogonal Path',
        modifierDescription: 'You are restricted from making diagonal letter connections; only vertical and horizontal paths are valid.',
        modifierType: 'restriction',
      ),
    ),
    // Day 18: Spotlight Day
    _DayData(
      theme: 'Spotlight Day',
      easy: _ChallengeData(
        gameId: 'oddcolor',
        difficulty: 'Easy',
        levelIndex: 1,
        modifierName: 'Flashlight Hunt',
        modifierDescription: 'The board is pitch black except for a circular beam centered on your touch pointer. Find the odd color.',
        modifierType: 'spotlight',
        extraParams: {'radius': 80.0},
      ),
      medium: _ChallengeData(
        gameId: 'sequence',
        difficulty: 'Medium',
        levelIndex: 5,
        modifierName: 'Guided Beam',
        modifierDescription: 'The sequence flash is accompanied by a narrow spotlight following the pattern. Recall it in the dark.',
        modifierType: 'spotlight',
        extraParams: {'radius': 100.0},
      ),
      hard: _ChallengeData(
        gameId: 'queens',
        difficulty: 'Hard',
        levelIndex: 22,
        modifierName: 'Blind Star Hunt',
        modifierDescription: 'The board is hidden in shadows. Touching the screen illuminates a small 3x3 area. Place stars conforming to region constraints.',
        modifierType: 'spotlight',
        extraParams: {'radius': 120.0},
      ),
    ),
    // Day 19: Ice Day
    _DayData(
      theme: 'Ice Day',
      easy: _ChallengeData(
        gameId: 'memory',
        difficulty: 'Easy',
        levelIndex: 2,
        modifierName: 'Frozen Pairs',
        modifierDescription: 'Some tiles are frozen. Match the "fire" counterpart tile to melt the ice and unlock them.',
        modifierType: 'ice',
      ),
      medium: _ChallengeData(
        gameId: 'sudoku',
        difficulty: 'Medium',
        levelIndex: 12,
        modifierName: 'Frost Grid',
        modifierDescription: 'Entering a number freezes the adjacent cells for 2 turns, preventing input in those spots.',
        modifierType: 'ice',
      ),
      hard: _ChallengeData(
        gameId: 'minesweeper',
        difficulty: 'Hard',
        levelIndex: 15,
        modifierName: 'Slippery Minefield',
        modifierDescription: 'Tapping a safe cell reveals not that cell, but the cell 2 steps in the direction you swiped. Aim carefully.',
        modifierType: 'ice',
      ),
    ),
    // Day 20: Ghost Day
    _DayData(
      theme: 'Ghost Day',
      easy: _ChallengeData(
        gameId: 'sequence',
        difficulty: 'Easy',
        levelIndex: 2, // 3 flashes
        modifierName: 'Fading Ghost',
        modifierDescription: 'Numbers flash leaving a faint glowing trail that quickly wiggles and vanishes.',
        modifierType: 'ghost',
      ),
      medium: _ChallengeData(
        gameId: 'zip',
        difficulty: 'Medium',
        levelIndex: 12,
        modifierName: 'Ghost Path',
        modifierDescription: 'Draw the path, but the drawn line disappears instantly behind your pointer (ghost drawing).',
        modifierType: 'ghost',
      ),
      hard: _ChallengeData(
        gameId: 'queens',
        difficulty: 'Hard',
        levelIndex: 22,
        modifierName: 'Ghost Stars',
        modifierDescription: 'Stars show up as invisible/ghost markers. Rules are verified only when all stars are placed.',
        modifierType: 'ghost',
      ),
    ),
    // Day 21: Swap Day
    _DayData(
      theme: 'Swap Day',
      easy: _ChallengeData(
        gameId: 'oddcolor',
        difficulty: 'Easy',
        levelIndex: 1,
        modifierName: 'Swap Target',
        modifierDescription: 'The odd color cell wiggles and swaps position with an adjacent tile every 4 seconds.',
        modifierType: 'swap',
      ),
      medium: _ChallengeData(
        gameId: 'hue',
        difficulty: 'Medium',
        levelIndex: 12,
        modifierName: 'Locked Corner',
        modifierDescription: 'One corner color is incorrect. Swap tiles to move the correct color to the corner and unlock the board.',
        modifierType: 'swap',
      ),
      hard: _ChallengeData(
        gameId: 'chimp',
        difficulty: 'Hard',
        levelIndex: 5, // 9 numbers
        modifierName: 'Double Swap',
        modifierDescription: 'The numbers shuffle and swap positions every time you make a correct tap.',
        modifierType: 'swap',
      ),
    ),
    // Day 22: Magnet Day
    _DayData(
      theme: 'Magnet Day',
      easy: _ChallengeData(
        gameId: 'chimp',
        difficulty: 'Easy',
        levelIndex: 1, // 5 numbers
        modifierName: 'Magnetic Tiles',
        modifierDescription: 'Clicking a tile pulls surrounding numbers one slot closer to it.',
        modifierType: 'magnet',
      ),
      medium: _ChallengeData(
        gameId: 'memory',
        difficulty: 'Medium',
        levelIndex: 12,
        modifierName: 'Mahjong Clumping',
        modifierDescription: 'Free tiles clump towards the center of the board, changing layout.',
        modifierType: 'magnet',
      ),
      hard: _ChallengeData(
        gameId: 'sudoku',
        difficulty: 'Hard',
        levelIndex: 22,
        modifierName: 'Repulsion Rules',
        modifierDescription: 'Entering a wrong number causes all adjacent cells to shake and flash red briefly — no permanent changes, just a visual warning pulse.',
        modifierType: 'magnet',
      ),
    ),
    // Day 23: Encryption Day
    _DayData(
      theme: 'Encryption Day',
      easy: _ChallengeData(
        gameId: 'sudoku',
        difficulty: 'Easy',
        levelIndex: 1,
        modifierName: 'Rot13 Search',
        modifierDescription: 'Solve the Sudoku grid with encrypted clues.',
        modifierType: 'encryption',
      ),
      medium: _ChallengeData(
        gameId: 'hangman',
        difficulty: 'Medium',
        levelIndex: 12,
        modifierName: 'Code Word',
        modifierDescription: 'The clue is a number sequence representing letter positions in the alphabet.',
        modifierType: 'encryption',
      ),
      hard: _ChallengeData(
        gameId: 'numbermemory',
        difficulty: 'Hard',
        levelIndex: 7, // 10 digits
        modifierName: 'Cipher Sequence',
        modifierDescription: 'The digits are shown as roman numerals or dot codes. Recall the sequence.',
        modifierType: 'encryption',
      ),
    ),
    // Day 24: Spotlight Day II
    _DayData(
      theme: 'Spotlight Day II',
      easy: _ChallengeData(
        gameId: 'minesweeper',
        difficulty: 'Easy',
        levelIndex: 1,
        modifierName: 'Flashlight Mines',
        modifierDescription: 'The grid cells are pitch black; moving your cursor reveals safe cell values like a flashlight.',
        modifierType: 'spotlight2',
      ),
      medium: _ChallengeData(
        gameId: 'spellingbee',
        difficulty: 'Medium',
        levelIndex: 12,
        modifierName: 'Spotlight Scanner',
        modifierDescription: 'Scan the honeycomb letters using only a moving spotlight that sweeps horizontally.',
        modifierType: 'spotlight2',
      ),
      hard: _ChallengeData(
        gameId: 'hue',
        difficulty: 'Hard',
        levelIndex: 22,
        modifierName: 'Dark Spectrum',
        modifierDescription: 'Sort colors while only a small circle around the active/selected tile is lit.',
        modifierType: 'spotlight2',
      ),
    ),
    // Day 25: Mutation Day
    _DayData(
      theme: 'Mutation Day',
      easy: _ChallengeData(
        gameId: 'oddcolor',
        difficulty: 'Easy',
        levelIndex: 1,
        modifierName: 'Hue Shift',
        modifierDescription: 'The palette slowly shifts hues over time. Tap the odd shade before it wanes into a matching color.',
        modifierType: 'mutation',
      ),
      medium: _ChallengeData(
        gameId: 'wordle',
        difficulty: 'Medium',
        levelIndex: 12,
        modifierName: 'Mutating Word',
        modifierDescription: 'The target secret word morphs one letter after your 3rd guess (clue provided).',
        modifierType: 'mutation',
      ),
      hard: _ChallengeData(
        gameId: 'sudoku',
        difficulty: 'Hard',
        levelIndex: 5,
        modifierName: 'Mutating Clues',
        modifierDescription: 'Making a mistake dims the number hints. Avoid errors to keep hints visible.',
        modifierType: 'mutation',
      ),
    ),
    // Day 26: Echo Day
    _DayData(
      theme: 'Echo Day',
      easy: _ChallengeData(
        gameId: 'sequence',
        difficulty: 'Easy',
        levelIndex: 2, // 3 flashes
        modifierName: 'Echo Sequence',
        modifierDescription: 'The sequence is shown twice, but the second time is played in reverse. Input the first (forward) sequence.',
        modifierType: 'echo',
      ),
      medium: _ChallengeData(
        gameId: 'zip',
        difficulty: 'Medium',
        levelIndex: 12,
        modifierName: 'Echo Path',
        modifierDescription: 'Draw a path that mirrors the computer\'s path shown briefly at the start.',
        modifierType: 'echo',
      ),
      hard: _ChallengeData(
        gameId: 'sudoku',
        difficulty: 'Hard',
        levelIndex: 22,
        modifierName: 'Echo Grid',
        modifierDescription: 'Entering a number in a cell copies it to the diagonally opposite cell if valid.',
        modifierType: 'echo',
      ),
    ),
    // Day 27: Blind Day
    _DayData(
      theme: 'Blind Day',
      easy: _ChallengeData(
        gameId: 'oddcolor',
        difficulty: 'Easy',
        levelIndex: 1,
        modifierName: 'Blind Choice',
        modifierDescription: 'You are limited to exactly 1 tap attempt to find the odd color tile.',
        modifierType: 'blind',
      ),
      medium: _ChallengeData(
        gameId: 'flagle',
        difficulty: 'Medium',
        levelIndex: 12,
        modifierName: 'Blind Flag',
        modifierDescription: 'The flag is hidden. Guess it using clues about its continent, color counts, and population.',
        modifierType: 'blind',
      ),
      hard: _ChallengeData(
        gameId: 'minesweeper',
        difficulty: 'Hard',
        levelIndex: 1, // Small grid (levelIndex=1) so it is humanly possible
        modifierName: 'One Life Minefield',
        modifierDescription: 'Safe cell indicators are hidden. A single wrong tap (hitting a mine) OR placing a flag on a safe cell instantly ends the run. No second chances.',
        modifierType: 'blind',
      ),
    ),
    // Day 28: Aurora Day
    _DayData(
      theme: 'Aurora Day',
      easy: _ChallengeData(
        gameId: 'hue',
        difficulty: 'Easy',
        levelIndex: 1,
        modifierName: 'Shimmering Aurora',
        modifierDescription: 'Sort color tiles under a waving northern lights color overlay.',
        modifierType: 'aurora',
      ),
      medium: _ChallengeData(
        gameId: 'memory',
        difficulty: 'Medium',
        levelIndex: 12,
        modifierName: 'Glow Match',
        modifierDescription: 'Tiles glow in shifting colors. You can only match pairs that currently share the same color glow.',
        modifierType: 'aurora',
      ),
      hard: _ChallengeData(
        gameId: 'oddcolor',
        difficulty: 'Hard',
        levelIndex: 22,
        modifierName: 'Aurora Hue',
        modifierDescription: 'The odd color tile has a shifting gradient pattern rather than a flat color.',
        modifierType: 'aurora',
      ),
    ),
    // Day 29: Matrix Day
    _DayData(
      theme: 'Matrix Day',
      easy: _ChallengeData(
        gameId: 'chimp',
        difficulty: 'Easy',
        levelIndex: 1,
        modifierName: 'Binary Board',
        modifierDescription: 'The numbers are shown in binary notation (e.g. 11 instead of 3).',
        modifierType: 'matrix',
      ),
      medium: _ChallengeData(
        gameId: 'queens',
        difficulty: 'Medium',
        levelIndex: 12,
        modifierName: 'Coordinates Only',
        modifierDescription: 'Regions are represented as a list of coordinates rather than colored borders.',
        modifierType: 'matrix',
      ),
      hard: _ChallengeData(
        gameId: 'sudoku',
        difficulty: 'Hard',
        levelIndex: 22,
        modifierName: 'Algebraic Sudoku',
        modifierDescription: 'Some cells contain equations (e.g. x + 3 where x is the correct number).',
        modifierType: 'matrix',
      ),
    ),
    // Day 30: Grand Finale
    _DayData(
      theme: 'Grand Finale',
      easy: _ChallengeData(
        gameId: 'numbermemory',
        difficulty: 'Easy',
        levelIndex: 7, // 10 digits
        modifierName: 'Infinite Recall',
        modifierDescription: 'Remember a number that grows by 1 digit each round, up to 10 digits, in a single fast run.',
        modifierType: 'grand_finale',
      ),
      medium: _ChallengeData(
        gameId: 'sequence',
        difficulty: 'Medium',
        levelIndex: 8, // 9 flashes
        modifierName: 'Grand Loop',
        modifierDescription: 'A 12-step sequence shown once. Input it without any mistakes.',
        modifierType: 'grand_finale',
      ),
      hard: _ChallengeData(
        gameId: 'hue',
        difficulty: 'Hard',
        levelIndex: 22,
        modifierName: 'Ultimate Sort',
        modifierDescription: 'A 6×6 spectrum board with corners that shift palette every 30–40 seconds. Solve it in under 120 seconds.',
        modifierType: 'grand_finale',
        extraParams: {'gridSize': 6, 'timer': 120, 'shiftSeconds': 35},
      ),
    ),
  ];

  static const int kThemeCount = 14;
  static const int kDaysPerWeek = 7;
  static const int kTotalDays = kThemeCount * kDaysPerWeek; // 98

  static Future<int> getActiveDay() async {
    final prefs = await SharedPreferences.getInstance();

    // Check one-time V3 Reset Migration for weekly challenge baseline
    if (!prefs.containsKey(PrefsKeys.weeklyResetV3Done)) {
      await prefs.setInt(PrefsKeys.dailyBronzeStars, 0);
      await prefs.setInt(PrefsKeys.dailySilverStars, 0);
      await prefs.setInt(PrefsKeys.dailyGoldStars, 0);
      await prefs.setInt(PrefsKeys.dailyV2Streak, 0);
      await prefs.setInt(PrefsKeys.dailyV2PerfectDays, 0);
      await prefs.setInt(PrefsKeys.weeklyPerfectStreak, 0);
      await prefs.remove(PrefsKeys.weeklyLastPerfectDate);
      await prefs.setInt(PrefsKeys.diamondStars, 0);
      await prefs.remove(PrefsKeys.perfectWeekHistory);
      await prefs.setInt(PrefsKeys.dailyUserProgressDay, 1);
      await prefs.remove(PrefsKeys.dailyChallengeStartTime);
      await prefs.setBool(PrefsKeys.weeklyResetV3Done, true);
    }

    if (!prefs.containsKey(PrefsKeys.dailyV2Migrated)) {
      await prefs.setInt(PrefsKeys.dailyUserProgressDay, 1);
      await prefs.setBool(PrefsKeys.dailyV2Migrated, true);
      await prefs.remove('daily_last_open_date');
      await prefs.remove(PrefsKeys.dailyChallengeStartTime);
    }

    int currentDay = prefs.getInt(PrefsKeys.dailyUserProgressDay) ?? 1;
    final now = DateTime.now().toUtc();
    final startTimeStr = prefs.getString(PrefsKeys.dailyChallengeStartTime) ?? '';

    if (startTimeStr.isEmpty) {
      // Set start time for the first time
      await prefs.setString(PrefsKeys.dailyChallengeStartTime, now.toIso8601String());
    } else {
      final startTime = DateTime.parse(startTimeStr);
      final diff = now.difference(startTime);
      final diffHours = diff.inHours;
      if (diffHours >= 24) {
        final elapsedDays = diffHours ~/ 24;
        currentDay = ((currentDay - 1 + elapsedDays) % kTotalDays) + 1;
        await prefs.setInt(PrefsKeys.dailyUserProgressDay, currentDay);
        
        final newStartTime = startTime.add(Duration(hours: elapsedDays * 24));
        await prefs.setString(PrefsKeys.dailyChallengeStartTime, newStartTime.toIso8601String());
      }
    }

    return currentDay;
  }

  static int weekOf(int globalDay) {
    final d = ((globalDay - 1) % kTotalDays);
    return ((d ~/ kDaysPerWeek) % kThemeCount) + 1;
  }

  static int dayInWeekOf(int globalDay) {
    final d = ((globalDay - 1) % kTotalDays);
    return (d % kDaysPerWeek) + 1;
  }

  static String themeOf(int globalDay) => _kDailyChallengesPlan[weekOf(globalDay) - 1].theme;

  static const List<String> _kDiffLabels = ['Easy', 'Medium', 'Hard'];

  static List<DailyChallenge> getChallengesForDay(int globalDay) {
    final week = weekOf(globalDay);            // 1..14
    final dayInWeek = dayInWeekOf(globalDay);  // 1..7
    final wk = _kDailyChallengesPlan[week - 1];
    final trio = [wk.easy, wk.medium, wk.hard]; // Day-1 [slot0, slot1, slot2]

    final slotToGame = _slotAssignment(trio, dayInWeek); // slot -> index into trio

    final out = <DailyChallenge>[];
    for (int slot = 0; slot < 3; slot++) {
      final c = trio[slotToGame[slot]];
      final level = c.levelIndex + slot * c.step;   // level scales with the slot
      out.add(DailyChallenge(
        difficulty: _kDiffLabels[slot],
        game: kAllGames.firstWhere((g) => g.id == c.gameId),
        levelIndex: level,
        modifierName: c.modifierName,
        modifierDescription: c.modifierDescription,
        modifierType: c.modifierType,
        extraParams: c.extraParams,
      ));
    }
    return out; // [0]=Easy, [1]=Medium, [2]=Hard, matching daily_screen
  }

  static List<int> _slotAssignment(List<_ChallengeData> trio, int dayInWeek) {
    final slotToGame = List<int>.filled(3, -1);
    final usedSlots = <int>{};
    final freeGames = <int>[];
    for (int i = 0; i < 3; i++) {                 // 1) place pinned games
      final p = trio[i].pinDifficulty;
      if (p != null) {
        slotToGame[p] = i;
        usedSlots.add(p);
      } else {
        freeGames.add(i);
      }
    }
    final freeSlots = [for (int s = 0; s < 3; s++) if (!usedSlots.contains(s)) s];
    final m = freeSlots.length;                   // 3 (no pin) or 2 (Chimp week)
    final r = m == 0 ? 0 : (dayInWeek - 1) % m;   // 2) rotate free games through free slots
    for (int j = 0; j < m; j++) {
      slotToGame[freeSlots[j]] = freeGames[((j - r) % m + m) % m];
    }
    return slotToGame;
  }

  static List<DailyChallenge> getChallengesForDate(DateTime date) {
    // Retain compatibility for legacy calls: map calendar date to a 1-98 cycle
    final dateUtc = date.toUtc();
    final epoch = DateTime.utc(2026, 6, 1);
    int daysDifference = dateUtc.difference(epoch).inDays;
    if (daysDifference < 0) {
      daysDifference = kTotalDays + (daysDifference % kTotalDays);
    }
    final dayNumber = (daysDifference % kTotalDays) + 1;
    return getChallengesForDay(dayNumber);
  }

  // --- V2 State Management ---

  static Future<bool> isChallengeCompleted(String difficulty, String dateStr) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(PrefsKeys.dailyV2Completed(difficulty, dateStr)) ?? false;
  }

  static Future<int> getCompletedCountForDate(String dateStr) async {
    int count = 0;
    if (await isChallengeCompleted('Easy', dateStr)) count++;
    if (await isChallengeCompleted('Medium', dateStr)) count++;
    if (await isChallengeCompleted('Hard', dateStr)) count++;
    return count;
  }

  static Future<int> getOrUpdateStreak(String dateStr) async {
    final prefs = await SharedPreferences.getInstance();
    final lastDate = prefs.getString(PrefsKeys.dailyV2LastDate) ?? '';
    int streak = prefs.getInt(PrefsKeys.dailyV2Streak) ?? 0;

    // Migrate from v1 if present
    if (streak == 0 && prefs.containsKey(PrefsKeys.dailyStreak)) {
      streak = prefs.getInt(PrefsKeys.dailyStreak) ?? 0;
      await prefs.setInt(PrefsKeys.dailyV2Streak, streak);
      final lastCompletedV1 = prefs.getString(PrefsKeys.dailyLastCompletedDate) ?? '';
      if (lastCompletedV1.isNotEmpty) {
        await prefs.setString(PrefsKeys.dailyV2LastDate, lastCompletedV1);
      }
    }

    if (lastDate.isNotEmpty && lastDate != dateStr) {
      final lastDateTime = DateTime.parse(lastDate);
      final now = DateTime.now().toUtc();
      final todayUtc = DateTime.utc(now.year, now.month, now.day);
      final diff = todayUtc.difference(lastDateTime).inDays;
      if (diff > 1) {
        streak = 0;
        await prefs.setInt(PrefsKeys.dailyV2Streak, 0);
      }
    }
    return streak;
  }

  static Future<int> getPerfectDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(PrefsKeys.dailyV2PerfectDays) ?? 0;
  }

  static Future<void> completeChallenge(String difficulty, String dateStr, String gameId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'daily_v2_completed_${difficulty.toLowerCase()}_$dateStr';
    if (prefs.getBool(key) == true) return; // already completed

    await prefs.setBool(key, true);

    // Update Star Reward Tracking
    final starKey = PrefsKeys.dailyStarForDate(dateStr);
    int completedCount = await getCompletedCountForDate(dateStr);
    
    // Decrement previous star count if any
    final prevStar = prefs.getString(starKey);
    if (prevStar == 'bronze') {
      await prefs.setInt(PrefsKeys.dailyBronzeStars, (prefs.getInt(PrefsKeys.dailyBronzeStars) ?? 0) - 1);
    } else if (prevStar == 'silver') {
      await prefs.setInt(PrefsKeys.dailySilverStars, (prefs.getInt(PrefsKeys.dailySilverStars) ?? 0) - 1);
    }

    // Assign new star
    String newStar = completedCount == 1 ? 'bronze' : completedCount == 2 ? 'silver' : 'gold';
    await prefs.setString(starKey, newStar);

    final starCountKey = newStar == 'bronze' ? PrefsKeys.dailyBronzeStars : newStar == 'silver' ? PrefsKeys.dailySilverStars : PrefsKeys.dailyGoldStars;
    await prefs.setInt(starCountKey, (prefs.getInt(starCountKey) ?? 0) + 1);

    // Push stars to widget
    await syncStarsToWidget();

    // Award rewards based on completions (points instead of hints)
    int pointsToAward = (completedCount == 3) ? 50 : 25;
    await PointManager.addPoints(pointsToAward);

    // Update streak
    int streak = prefs.getInt(PrefsKeys.dailyV2Streak) ?? 0;
    final lastDate = prefs.getString(PrefsKeys.dailyV2LastDate) ?? '';

    if (lastDate != dateStr) {
      if (lastDate.isEmpty) {
        streak = 1;
      } else {
        final lastDateTime = DateTime.parse(lastDate);
        final now = DateTime.now().toUtc();
        final todayUtc = DateTime.utc(now.year, now.month, now.day);
        final diff = todayUtc.difference(lastDateTime).inDays;
        if (diff <= 1) {
          streak += 1;
        } else {
          streak = 1;
        }
      }
      await prefs.setInt(PrefsKeys.dailyV2Streak, streak);
      await prefs.setString(PrefsKeys.dailyV2LastDate, dateStr);
    }

    // Check if Perfect Day (all 3 completed)
    if (completedCount == 3) {
      final perfectKey = PrefsKeys.dailyV2Perfect(dateStr);
      if (prefs.getBool(perfectKey) != true) {
        await prefs.setBool(perfectKey, true);
        int perfectDays = prefs.getInt(PrefsKeys.dailyV2PerfectDays) ?? 0;
        await prefs.setInt(PrefsKeys.dailyV2PerfectDays, perfectDays + 1);

        // --- Perfect Week Streak Logic ---
        final today = DateTime.parse(dateStr); // dateStr is UTC yyyy-MM-dd
        final last = prefs.getString(PrefsKeys.weeklyLastPerfectDate) ?? '';
        int streak = prefs.getInt(PrefsKeys.weeklyPerfectStreak) ?? 0;
        
        List<String> history = prefs.getStringList(PrefsKeys.perfectWeekHistory) ?? [];
        if (!history.contains(dateStr)) {
          history.add(dateStr);
          await prefs.setStringList(PrefsKeys.perfectWeekHistory, history);
        }

        if (last != dateStr) {
          if (last.isEmpty) {
            streak = 1;
          } else {
            final lastDateObj = DateTime.parse(last);
            // Calculate actual date difference in days in UTC
            final lastDateUtc = DateTime.utc(lastDateObj.year, lastDateObj.month, lastDateObj.day);
            final todayUtc = DateTime.utc(today.year, today.month, today.day);
            final diff = todayUtc.difference(lastDateUtc).inDays;
            
            if (diff == 1) {
              streak += 1;
            } else if (diff > 1) {
              streak = 1;
              history = [dateStr];
              await prefs.setStringList(PrefsKeys.perfectWeekHistory, history);
            }
          }
          await prefs.setString(PrefsKeys.weeklyLastPerfectDate, dateStr);
          
          if (streak >= 7) {
            final diamonds = prefs.getInt(PrefsKeys.diamondStars) ?? 0;
            await prefs.setInt(PrefsKeys.diamondStars, diamonds + 1);
            streak = 0; // Reset streak after award
            await prefs.remove(PrefsKeys.perfectWeekHistory);
          }
          await prefs.setInt(PrefsKeys.weeklyPerfectStreak, streak);
        }
      }
    }

    // Update notifications state
    await NotificationManager.updateDailyChallengeReminder();
  }

  static Future<void> syncStarsToWidget() async {
    final prefs = await SharedPreferences.getInstance();
    final bronze = prefs.getInt(PrefsKeys.dailyBronzeStars) ?? 0;
    final silver = prefs.getInt(PrefsKeys.dailySilverStars) ?? 0;
    final gold = prefs.getInt(PrefsKeys.dailyGoldStars) ?? 0;

    try {
      await HomeWidget.saveWidgetData('daily_bronze_stars', bronze);
      await HomeWidget.saveWidgetData('daily_silver_stars', silver);
      await HomeWidget.saveWidgetData('daily_gold_stars', gold);
      await HomeWidget.updateWidget(
        name: 'StreakWidgetProvider',
        androidName: 'com.mayank.cogniq.StreakWidgetProvider',
        qualifiedAndroidName: 'com.mayank.cogniq.StreakWidgetProvider',
      );
    } catch (_) {}
  }

  static Future<void> setupDailyModifier(DailyChallenge challenge) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PrefsKeys.playDailyMode, true);
    await prefs.setString(PrefsKeys.dailyModifierType, challenge.modifierType ?? '');
    await prefs.setString(PrefsKeys.dailyModifierName, challenge.modifierName);
    await prefs.setString(PrefsKeys.dailyModifierDesc, challenge.modifierDescription);
    await prefs.setString(PrefsKeys.dailyModifierDifficulty, challenge.difficulty);
    if (challenge.extraParams != null) {
      await prefs.setString(PrefsKeys.dailyModifierExtraParams, jsonEncode(challenge.extraParams));
    } else {
      await prefs.remove(PrefsKeys.dailyModifierExtraParams);
    }
  }

  static Future<void> clearDailyModifier() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PrefsKeys.playDailyMode, false);
    await prefs.remove(PrefsKeys.dailyModifierType);
    await prefs.remove(PrefsKeys.dailyModifierName);
    await prefs.remove(PrefsKeys.dailyModifierDesc);
    await prefs.remove(PrefsKeys.dailyModifierDifficulty);
    await prefs.remove(PrefsKeys.dailyModifierExtraParams);
  }
}
