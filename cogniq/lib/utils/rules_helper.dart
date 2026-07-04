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
    
'memory':'• Tap on a free tile to move it to the tray.\n\n• A tile is free if it has no tile on top, and has at least one free side (left or right).\n\n• Matching pairs in the tray are automatically removed.\n\n• Clear the board to win. Do not let the tray fill up!',
    
'spellingbee':'• Construct words using letters from the honeycomb grid.\n\n• Every word must contain the center letter at least once.',
    
'sudoku':'• Fill the grid with numbers from 1 to the grid size (4x4, 6x6, or 9x9).\n\n• Every row, column, and subgrid must contain unique numbers without duplicates.',
    
'wordsearch':'• Find the target words hidden inside the grid.\n\n• Words can run horizontally, vertically, or diagonally.',
    
'minesweeper':'• Locate and flag all hidden mines on the grid without detonating them.\n\n• Tap a cell to reveal it. If it contains a mine, you explode and lose!\n\n• If a cell is safe, it reveals a number showing how many mines are adjacent to it.\n\n• Long-press or toggle Flag mode to place a flag on suspected mine cells.\n\n• Reveal all safe cells to clear the level. Grid size and mines increase at higher levels.',
    
'reaction':'• Tap the screen as fast as you can when the red background turns green.\n\n• Avoid tapping too early!',
    
'numbermemory':'• Memorize the sequence of digits shown on the screen.\n\n• Recall and submit the correct number.\n\n• The sequence gets 1 digit longer each round.',
    
'sequence':'• Watch the pattern of flashing tiles.\n\n• Tap the tiles in the exact same sequence.\n\n• Each round adds one more flash.',
    
'oddcolor':'• Find the single grid cell that has a slightly different color shade.\n\n• The game gets progressively harder with larger grids and subtle color differences.\n\n• Tap correctly to advance; if you tap the wrong cell, a new color grid with the same difficulty will form.',
    
'hue':'• Arrange the scrambled color tiles to form a continuous color gradient.\n\n• Corner tiles marked with a black dot are locked in place and cannot be moved.\n\n• Drag and swap tiles to complete the spectrum.',
    
'nonogram':'• Fill in grid cells to match the row and column number clues.\n\n• Each number in a clue represents a group of consecutive filled cells (e.g. "1 2" means a group of 1 cell, then at least one empty space, then a group of 2 cells).\n\n• Switch between Paint mode (to fill cells) and X mode (to mark cells that must be empty).\n\n• The game auto-checks when the correct cells are filled.',
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
