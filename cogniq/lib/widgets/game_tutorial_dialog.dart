import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class TutorialStep {
  final String title;
  final String description;
  final String illustrationEmoji;
  final Widget? customIllustration;

  const TutorialStep({
    required this.title,
    required this.description,
    required this.illustrationEmoji,
    this.customIllustration,
  });
}

class GameTutorialDialog extends StatefulWidget {
  final String gameId;
  final String gameName;

  const GameTutorialDialog({
    super.key,
    required this.gameId,
    required this.gameName,
  });

  static void show(BuildContext context, String gameId, String gameName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => GameTutorialDialog(gameId: gameId, gameName: gameName),
    );
  }

  @override
  State<GameTutorialDialog> createState() => _GameTutorialDialogState();
}

class _GameTutorialDialogState extends State<GameTutorialDialog> {

  List<TutorialStep> _getSteps() {
    switch (widget.gameId) {
      case 'zip':
        return [
          const TutorialStep(
            title: '⚡ Tracing the Path',
            description: 'Touch the yellow starting tile and drag your finger to trace a continuous path across the grid.',
            illustrationEmoji: '⚡',
          ),
          const TutorialStep(
            title: '🔢 Numbered Waypoints',
            description: 'You must visit the numbered tiles in strict ascending order (e.g., visit 1 first, then 2, then 3).',
            illustrationEmoji: '🔢',
          ),
          const TutorialStep(
            title: '🧱 Avoid Walls',
            description: 'Dark grey cells are solid walls. Your path cannot cross or pass through them.',
            illustrationEmoji: '🧱',
          ),
          const TutorialStep(
            title: '↩️ Backtracking',
            description: 'Made a mistake? Simply drag your finger back, or touch any previously visited cell on your path to resume from that point!',
            illustrationEmoji: '↩️',
          ),
        ];
      case 'oddcolor':
        return [
          const TutorialStep(
            title: '🎨 Find the Impostor',
            description: 'A grid of colored tiles will appear. One single tile has a slightly different shade or color compared to the rest.',
            illustrationEmoji: '🔍',
          ),
          const TutorialStep(
            title: '⚡ Be Quick!',
            description: 'Tap the odd tile as fast as you can. Finding it quickly increases your score, while wrong taps deduct precious time.',
            illustrationEmoji: '⏱️',
          ),
          const TutorialStep(
            title: '📈 Scaling Focus',
            description: 'As your score climbs, the grid size increases and the color difference gets extremely subtle. Lock in your focus!',
            illustrationEmoji: '🧠',
          ),
        ];
      case 'queens':
        return [
          const TutorialStep(
            title: '♛ Star Placement',
            description: 'Your goal is to place exactly 1 star (★) in every row, every column, and every colored region of the board.',
            illustrationEmoji: '★',
          ),
          const TutorialStep(
            title: '❌ No Touching',
            description: 'Stars cannot touch each other at all—not even diagonally! Keep them separated.',
            illustrationEmoji: '🚫',
          ),
          const TutorialStep(
            title: '💡 Use Markers',
            description: 'Tap a tile once to place an "X" if you know it cannot contain a star. Tap again to place a star (★). Tap a third time to clear it.',
            illustrationEmoji: '❌',
          ),
        ];
      case 'minesweeper':
        return [
          const TutorialStep(
            title: '💣 The Minefield',
            description: 'A grid of hidden tiles contains a set of dangerous mines. You must locate all of them safely.',
            illustrationEmoji: '💣',
          ),
          const TutorialStep(
            title: '🔢 Number Clues',
            description: 'Tap a tile to reveal it. The number shown indicates how many mines are hidden in the surrounding 8 tiles.',
            illustrationEmoji: '🔢',
          ),
          const TutorialStep(
            title: '🚩 Flagging Mines',
            description: 'Long press a tile to place a flag (🚩) if you believe a mine is hidden underneath. Flagged tiles cannot be clicked accidentally.',
            illustrationEmoji: '🚩',
          ),
          const TutorialStep(
            title: '🏆 Clear to Win',
            description: 'Successfully reveal all safe tiles and place flags on all active mines to win the game!',
            illustrationEmoji: '🏆',
          ),
        ];
      case 'hue':
        return [
          const TutorialStep(
            title: '🌈 Perfect Gradient',
            description: 'Arrange the colored tiles in the correct order to form a smooth, continuous spectrum of color hues.',
            illustrationEmoji: '🌈',
          ),
          const TutorialStep(
            title: '📌 Anchor Tiles',
            description: 'Tiles with a black dot in the center are locked in place. Use them as reference points to complete the rest of the board.',
            illustrationEmoji: '📌',
          ),
          const TutorialStep(
            title: '🔄 Swipe/Tap to Swap',
            description: 'Tap any unlocked tile to select it, then tap another unlocked tile to swap their positions. Match the hues smoothly!',
            illustrationEmoji: '🔄',
          ),
        ];
      case 'sudoku':
        return [
          const TutorialStep(
            title: '🔢 4x4 Sudoku Grid',
            description: 'Fill the 4x4 grid using the numbers 1, 2, 3, and 4.',
            illustrationEmoji: '🧩',
          ),
          const TutorialStep(
            title: '❌ Row, Col & Box Rules',
            description: 'A number must appear exactly once in every row, every column, and every 2x2 sub-grid.',
            illustrationEmoji: '🚫',
          ),
          const TutorialStep(
            title: '✏️ How to Input',
            description: 'Tap an empty cell, then select a number button at the bottom to fill it. Tap the eraser icon to clear a cell.',
            illustrationEmoji: '✏️',
          ),
        ];
      case 'spellingbee':
        return [
          const TutorialStep(
            title: '🐝 Honeycomb Letters',
            description: 'Spell as many words as possible using the 7 letters in the honeycomb cells.',
            illustrationEmoji: '🐝',
          ),
          const TutorialStep(
            title: '⭐️ Center Requirement',
            description: 'Every word you submit MUST contain the center letter of the honeycomb. Words must be at least 4 letters long.',
            illustrationEmoji: '⭐️',
          ),
          const TutorialStep(
            title: '🔄 Reuse Letters',
            description: 'You can tap and use the same letter multiple times in a single word. Tap "Submit" to score, or "Delete" to clear letters.',
            illustrationEmoji: '🔄',
          ),
        ];
      case 'pattern_lock':
        return [
          const TutorialStep(
            title: '🔒 Memorize the Path',
            description: 'Watch the screen closely at the start of the level. A pattern connecting the dots will be drawn and then hidden.',
            illustrationEmoji: '👀',
          ),
          const TutorialStep(
            title: '✍️ Recreate the Trace',
            description: 'Drag your finger across the dots to draw the exact same pattern sequence you just memorized.',
            illustrationEmoji: '✍️',
          ),
          const TutorialStep(
            title: '↩️ Backtracking Undo',
            description: 'Drew a wrong line? Simply drag your finger back to the previous dot to undo steps and draw a new path.',
            illustrationEmoji: '↩️',
          ),
        ];
      case 'colour_link':
        return [
          const TutorialStep(
            title: '🔗 Connect Matching Dots',
            description: 'Link matching colored dots on the grid together with continuous colored lines.',
            illustrationEmoji: '🔗',
          ),
          const TutorialStep(
            title: '⚠️ Paths Cannot Cross',
            description: 'Lines cannot intersect, share cells, or cross each other. Plan your routes carefully!',
            illustrationEmoji: '🚫',
          ),
          const TutorialStep(
            title: '🟦 Fill Every Cell',
            description: 'Every single blank space on the grid must be filled by a path. You cannot leave any cell empty to complete the level!',
            illustrationEmoji: '🟦',
          ),
        ];
      case 'color_flood':
        return [
          const TutorialStep(
            title: '💧 Flood the Grid',
            description: 'Your goal is to fill the entire grid with a single solid color, starting from the top-left home tile.',
            illustrationEmoji: '💧',
          ),
          const TutorialStep(
            title: '🎮 Flood Controls',
            description: 'Tap a color button at the bottom. The top-left region changes to that color and absorbs all adjacent cells of the same color.',
            illustrationEmoji: '🎮',
          ),
          const TutorialStep(
            title: '📉 Moves Budget',
            description: 'Absorb the whole grid within the maximum move count displayed at the top. Use your moves efficiently!',
            illustrationEmoji: '📉',
          ),
        ];
      case 'circuit_guide':
        return [
          const TutorialStep(
            title: '🔌 Complete the Circuit',
            description: 'Direct power from the bolt source (⚡) to light up all the target lightbulb nodes.',
            illustrationEmoji: '🔌',
          ),
          const TutorialStep(
            title: '🔄 Rotate Wires',
            description: 'Tap any wire tile to rotate it 90 degrees. Align the endpoints to form a continuous connection line.',
            illustrationEmoji: '🔄',
          ),
          const TutorialStep(
            title: '🧱 Decoy Tiles',
            description: 'Decoy tiles that do not connect to the main circuit may be present. You do not need to use every tile to solve the puzzle!',
            illustrationEmoji: '🧱',
          ),
        ];
      case 'chimp':
        return [
          const TutorialStep(
            title: '🐵 The Chimp Test',
            description: 'A set of numbered tiles will be placed randomly on the grid. Memorize their locations!',
            illustrationEmoji: '🧠',
          ),
          const TutorialStep(
            title: '🙈 Hidden Tiles',
            description: 'The moment you tap the number 1, all other numbers are hidden behind blank white tiles.',
            illustrationEmoji: '🙈',
          ),
          const TutorialStep(
            title: '🏆 Tap in Order',
            description: 'Tap the hidden tiles in ascending order (2, then 3, then 4...) using only your working memory.',
            illustrationEmoji: '🏆',
          ),
        ];
      case 'wordle':
        return [
          const TutorialStep(
            title: '📝 Guess the Word',
            description: 'Your goal is to guess a hidden 5-letter word within exactly 6 attempts.',
            illustrationEmoji: '📝',
          ),
          const TutorialStep(
            title: '🟩 Green Letters',
            description: 'If a letter turns green, it is in the word and in the correct spot.',
            illustrationEmoji: '🟩',
          ),
          const TutorialStep(
            title: '🟨 Yellow Letters',
            description: 'If a letter turns yellow, it is in the word but in a different spot.',
            illustrationEmoji: '🟨',
          ),
          const TutorialStep(
            title: '⬛ Grey Letters',
            description: 'If a letter turns grey, it is not in the word at all.',
            illustrationEmoji: '⬛',
          ),
        ];
      case 'weaver':
        return [
          const TutorialStep(
            title: '🪜 Word Ladder',
            description: 'Your goal is to transition from a starting word to a target word step-by-step.',
            illustrationEmoji: '🪜',
          ),
          const TutorialStep(
            title: '🔠 Change One Letter',
            description: 'Change exactly one letter of your current word at a time to form a new word.',
            illustrationEmoji: '🔠',
          ),
          const TutorialStep(
            title: '📖 Valid Dictionary Words',
            description: 'Each word you enter must be a valid dictionary word. Climb the ladder to reach the target!',
            illustrationEmoji: '📖',
          ),
        ];
      case 'memory':
        return [
          const TutorialStep(
            title: '🀄 Mahjong Solitaire',
            description: 'Match pairs of matching tiles to clear the board.',
            illustrationEmoji: '🀄',
          ),
          const TutorialStep(
            title: '📌 Free Tiles Only',
            description: 'You can only tap and select free tiles. A tile is free if it has no tiles on top, and has at least one open side (left or right).',
            illustrationEmoji: '📌',
          ),
          const TutorialStep(
            title: '📥 Match in Tray',
            description: 'Tapping a free tile moves it to the tray. Identical pairs are automatically cleared. Avoid filling the tray!',
            illustrationEmoji: '📥',
          ),
        ];
      case 'hangman':
        return [
          const TutorialStep(
            title: '😵 Save the Figure',
            description: 'Solve the hidden word letter-by-letter before the drawing is completed!',
            illustrationEmoji: '😵',
          ),
          const TutorialStep(
            title: '🅰️ Guess Letters',
            description: 'Tap letters on the keyboard to guess them. Correct letters fill in their respective blank spots.',
            illustrationEmoji: '🅰️',
          ),
          const TutorialStep(
            title: '⚠️ Mistake Limit',
            description: 'Each incorrect guess adds a part to the drawing. Think carefully before you tap!',
            illustrationEmoji: '⚠️',
          ),
        ];
      case 'reaction':
        return [
          const TutorialStep(
            title: '⚡ Test Your Reflexes',
            description: 'Wait for the red background screen to turn bright green.',
            illustrationEmoji: '⚡',
          ),
          const TutorialStep(
            title: '🟢 Tap on Green!',
            description: 'Tap the screen as fast as you can the instant the color turns green. Tap too early, and it is a foul!',
            illustrationEmoji: '🟢',
          ),
          const TutorialStep(
            title: '⏱️ Average Speed',
            description: 'The test repeats 5 times to calculate your final average reaction speed in milliseconds.',
            illustrationEmoji: '⏱️',
          ),
        ];

      case 'numbermemory':
        return [
          const TutorialStep(
            title: '🔢 Memorize Digits',
            description: 'A sequence of digits will flash on the screen. Watch and memorize them quickly!',
            illustrationEmoji: '👀',
          ),
          const TutorialStep(
            title: '⌨️ Recall & Type',
            description: 'Type the exact sequence of digits using the on-screen keypad and click submit.',
            illustrationEmoji: '⌨️',
          ),
          const TutorialStep(
            title: '📈 Endless Scaling',
            description: 'The number sequence gets one digit longer with every correct round. Challenge your short-term memory limit!',
            illustrationEmoji: '📈',
          ),
        ];
      case 'wordbuilder':
        return [
          const TutorialStep(
            title: '🏗️ Form Words',
            description: 'Use the letters provided at the bottom of the screen to form as many words as you can.',
            illustrationEmoji: '🏗️',
          ),
          const TutorialStep(
            title: '📏 Word Length',
            description: 'Each word you build must contain at least 3 letters.',
            illustrationEmoji: '📏',
          ),
          const TutorialStep(
            title: '🎯 Reach the Target',
            description: 'Find enough valid words to hit the level clearance target and progress!',
            illustrationEmoji: '🎯',
          ),
        ];
      case 'sequence':
        return [
          const TutorialStep(
            title: '💡 Watch the Pattern',
            description: 'Watch the grid tiles flash in a specific, growing sequence.',
            illustrationEmoji: '👀',
          ),
          const TutorialStep(
            title: '🧠 Repeat Sequence',
            description: 'Tap the grid tiles in the exact same order they flashed. Tap carefully!',
            illustrationEmoji: '🧠',
          ),
          const TutorialStep(
            title: '📈 Growing Length',
            description: 'Each correct round adds one more flash to the sequence. Keep your focus locked in!',
            illustrationEmoji: '📈',
          ),
        ];
      case 'crossclimb':
        return [
          const TutorialStep(
            title: '🧗 Word Climb Ladder',
            description: 'Solve the word puzzle steps to climb to the top of the trivia ladder.',
            illustrationEmoji: '🧗',
          ),
          const TutorialStep(
            title: '🔠 One Letter Change',
            description: 'Each word on the ladder differs by only one letter from the word directly below or above it.',
            illustrationEmoji: '🔠',
          ),
          const TutorialStep(
            title: '🧠 Trivia Answers',
            description: 'Solve trivia clues to fill in the missing letters and complete the ladder!',
            illustrationEmoji: '🧠',
          ),
        ];
      case 'flagle':
        return [
          const TutorialStep(
            title: '🗺️ Guess the Country',
            description: 'Identify the country based on its national flag.',
            illustrationEmoji: '🗺️',
          ),
          const TutorialStep(
            title: '🎨 Reveal Segments',
            description: 'Tap "Next Clue" to reveal another segment of the flag and check proximity distance clues.',
            illustrationEmoji: '🎨',
          ),
          const TutorialStep(
            title: '🏆 Proximity Clues',
            description: 'Proximity indicators show how close your guess was to the target country. Find it in as few guesses as possible!',
            illustrationEmoji: '🏆',
          ),
        ];
      default:
        return [
          TutorialStep(
            title: '🎮 How to Play ${widget.gameName}',
            description: 'Follow the rules and clear matching puzzle cells to score points.',
            illustrationEmoji: '💡',
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = _getSteps();
    final buffer = StringBuffer();
    for (final s in steps) {
      buffer.writeln('• ${s.title}: ${s.description}\n');
    }
    final text = buffer.toString().trim();

    return AlertDialog(
      backgroundColor: context.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: context.textMuted.withAlpha(40)),
      ),
      title: Text(
        '${widget.gameName} Rules',
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          color: context.textPrimary,
        ),
      ),
      content: SingleChildScrollView(
        child: Text(
          text,
          style: GoogleFonts.outfit(
            color: context.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Got it',
            style: GoogleFonts.outfit(
              color: AppTheme.dustyMauve,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
