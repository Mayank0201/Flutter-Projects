import'package:flutter/material.dart';
import'package:google_fonts/google_fonts.dart';
import'../theme/app_theme.dart';

class RulesHelper {
  static const Map<String, String> _gameRules = {
'wordle':'• Guess the target 5-letter word in 6 attempts.\n\n• Each guess must be a valid word.\n\n• Green tiles indicate correct letters in correct spots.\n\n• Yellow tiles indicate correct letters in incorrect spots.\n\n• Gray tiles indicate letters not present in the word.',
    
'hangman':'• Guess the hidden word letter by letter.\n\n• Each incorrect guess adds a part to the drawing.\n\n• Solve the word before the drawing is complete!',
    
'weaver':'• Transition from the start word to the end word.\n\n• Change exactly one letter at a time.\n\n• Each intermediate step must be a valid dictionary word.',
    
'zip':'• Drag from the start node to the end node.\n\n• Fill the entire grid path.\n\n• Do not overlap or leave empty tiles.',
    
'crossclimb':'• Climb the 5-step trivia ladder.\n\n• Solve clues to reveal words.\n\n• Each word differs by only one letter from the word below it.',
    
'queens':'• Place exactly one Star in each row, column, and colored region.\n\n• Stars cannot touch each other, even diagonally.',
    
'chimp':'• Tap the numbered cards in ascending order (1, 2, 3...).\n\n• After you tap the first number, the remaining numbers are hidden.',
    
'connections':'• Find groups of 4 items that share a common link.\n\n• Select 4 words and submit to check if they form a correct group.',
    
'flagle':'• Guess the country name.\n\n• Tap \'Next Clue\'to reveal parts of the flag.\n\n• Wrong guesses will clear the input so you can try again.',
    
'wordbuilder':'• Form words using the provided letters.\n\n• Each word must use at least 3 letters.\n\n• Form as many words as you can to hit the target count.',
    
'memory':'• Flip cards to find matching pairs.\n\n• Memorize card positions to solve the grid in the fewest moves.',
    
'spellingbee':'• Construct words using letters from the honeycomb grid.\n\n• Every word must contain the center letter at least once.',
    
'sudoku':'• Fill the grid with numbers from 1 to the grid size (4x4, 6x6, or 9x9).\n\n• Every row, column, and subgrid must contain unique numbers without duplicates.',
    
'wordsearch':'• Find the target words hidden inside the grid.\n\n• Words can run horizontally, vertically, or diagonally.',
    
'twentyfortyeight':'• Swipe to slide tiles across the grid.\n\n• Same-valued tiles merge into one when they collide.\n\n• Merge tiles to hit the level target score within move limits.',
    
'reaction':'• Tap the screen as fast as you can when the red background turns green.\n\n• Avoid tapping too early!',
    
'numbermemory':'• Memorize the sequence of digits shown on the screen.\n\n• Recall and submit the correct number.\n\n• The sequence gets 1 digit longer each round.',
    
'sequence':'• Watch the pattern of flashing tiles.\n\n• Tap the tiles in the exact same sequence.\n\n• Each round adds one more flash.',
  };

  static void showRulesBottomSheet(BuildContext context, String gameId, String gameName) {
    final rules = _gameRules[gameId] ??'Solve the puzzle to clear the level.';
    final accent = AppTheme.accentFor(gameId);

    showModalBottomSheet(
      context: context,
      backgroundColor: context.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top notch / drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.textMuted.withAlpha(50),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text(
'How to Play',
                    style: GoogleFonts.outfit(
                      fontSize: context.scale(20),
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
'• $gameName',
                    style: GoogleFonts.outfit(
                      fontSize: context.scale(15),
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    rules,
                    style: GoogleFonts.outfit(
                      fontSize: context.scale(14),
                      color: context.textSecondary,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
