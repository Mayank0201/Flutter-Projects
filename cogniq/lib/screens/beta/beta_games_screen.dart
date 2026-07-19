/*
import 'logic_grid_placeholder_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../games/beta/killer_sudoku_beta.dart';
import '../games/beta/binairo_beta.dart';
import '../games/beta/kakuro_beta.dart';
import '../games/beta/futoshiki_beta.dart';
import '../games/beta/skyscrapers_beta.dart';
import '../games/beta/kenken_beta.dart';
import '../games/beta/sumplete_beta.dart';
import '../games/beta/light_up_beta.dart';
import '../games/beta/nurikabe_beta.dart';
import '../games/beta/cipher_decoder_beta.dart';
import '../games/beta/hashi_beta.dart';
import '../games/beta/masyu_beta.dart';
import '../games/beta/slitherlink_beta.dart';
import '../games/beta/math_sprint_beta.dart';
import '../games/beta/mental_math_blocks_beta.dart';
import '../games/beta/map_memory_beta.dart';
import '../games/beta/buzzer_beta.dart';
import '../games/beta/tent_and_trees_beta.dart';
import '../games/beta/kakurasu_beta.dart';
import '../games/beta/hitori_beta.dart';
import '../games/beta/shakashaka_beta.dart';
import '../games/beta/thermometers_beta.dart';
import '../games/beta/tic_tac_toe_beta.dart';

import '../../utils/daily_challenge_manager.dart';

class BetaGameInfo {
  final String id;
  final String name;
  final String description;
  final String category;
  final IconData icon;
  final Widget builder;

  const BetaGameInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.icon,
    required this.builder,
  });
}

class BetaGamesScreen extends StatefulWidget {
  const BetaGamesScreen({super.key});

  @override
  State<BetaGamesScreen> createState() => _BetaGamesScreenState();
}

class _BetaGamesScreenState extends State<BetaGamesScreen> {
  String _searchQuery = '';
  Map<String, int> _progressMap = {};

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, int> progress = {};
    for (final game in _getBetaGamesList()) {
      progress[game.id] = prefs.getInt('beta_level_${game.id}') ?? 0;
    }
    if (mounted) {
      setState(() {
        _progressMap = progress;
      });
    }
  }

  List<BetaGameInfo> _getBetaGamesList() {
    return [
      // --- LOGIC GRIDS ---
      BetaGameInfo(
        id: 'killersudoku',
        name: 'Killer Sudoku',
        description: 'Sudoku + cages with sum constraints.',
        category: 'Logic Grids',
        icon: Icons.grid_on_outlined,
        builder: const KillerSudokuBetaScreen(),
      ),      BetaGameInfo(
        id: 'binairo',
        name: 'Takuzu',
        description: 'Fill grid with 0s and 1s satisfying adjacency constraints.',
        category: 'Logic Grids',
        icon: Icons.apps_outlined,
        builder: const BinairoBetaScreen(),
      ),
      BetaGameInfo(
        id: 'kakuro',
        name: 'Kakuro',
        description: 'Crossword-style addition grid puzzle.',
        category: 'Logic Grids',
        icon: Icons.border_all_outlined,
        builder: const KakuroBetaScreen(),
      ),
      BetaGameInfo(
        id: 'futoshiki',
        name: 'Futoshiki',
        description: 'Fill grid satisfying inequalities between cells.',
        category: 'Logic Grids',
        icon: Icons.compare_arrows_outlined,
        builder: const FutoshikiBetaScreen(),
      ),
      BetaGameInfo(
        id: 'skyscrapers',
        name: 'Skyscrapers',
        description: 'Latin square matching visible building height counts.',
        category: 'Logic Grids',
        icon: Icons.domain_outlined,
        builder: const SkyscrapersBetaScreen(),
      ),
      BetaGameInfo(
        id: 'kenken',
        name: 'Calcudoku',
        description: 'Math cages matching targets via arithmetic operations.',
        category: 'Logic Grids',
        icon: Icons.calculate_outlined,
        builder: const KenKenBetaScreen(),
      ),
      BetaGameInfo(
        id: 'sumplete',
        name: 'Sum Strike',
        description: 'Delete numbers to match row and column target sums.',
        category: 'Logic Grids',
        icon: Icons.playlist_remove_outlined,
        builder: const SumpleteBetaScreen(),
      ),
      BetaGameInfo(
        id: 'lightup',
        name: 'Light Up',
        description: 'Illuminate all cells without placing overlapping bulbs.',
        category: 'Logic Grids',
        icon: Icons.lightbulb_outline_rounded,
        builder: const LightUpBetaScreen(),
      ),
      BetaGameInfo(
        id: 'nurikabe',
        name: 'Nurikabe',
        description: 'Form a continuous sea around isolated numbered islands.',
        category: 'Logic Grids',
        icon: Icons.landscape_outlined,
        builder: const NurikabeBetaScreen(),
      ),
      BetaGameInfo(
        id: 'cipher',
        name: 'Cipher Decoder',
        description: 'Decode the hidden quote using a substitution cipher mapping.',
        category: 'Logic Grids',
        icon: Icons.lock_open_outlined,
        builder: const CipherDecoderBetaScreen(),
      ),


      // --- PATHS & LOOPS ---
      BetaGameInfo(
        id: 'hashi',
        name: 'Hashi (Bridges)',
        description: 'Build bridges between islands to match target counts.',
        category: 'Paths & Loops',
        icon: Icons.linear_scale_outlined,
        builder: const HashiBetaScreen(),
      ),
      BetaGameInfo(
        id: 'masyu',
        name: 'Masyu',
        description: 'Draw a single closed loop satisfying pearl turning rules.',
        category: 'Paths & Loops',
        icon: Icons.circle_outlined,
        builder: const MasyuBetaScreen(),
      ),
      BetaGameInfo(
        id: 'slitherlink',
        name: 'Slitherlink',
        description: 'Form a single loop on grid edges to match clue values.',
        category: 'Paths & Loops',
        icon: Icons.grid_3x3_outlined,
        builder: const SlitherlinkBetaScreen(),
      ),

      // --- MATH & CALCULATION ---
      BetaGameInfo(
        id: 'mathsprint',
        name: 'Math Sprint',
        description: 'Speed arithmetic. Tap correct answers under a quick timer.',
        category: 'Math & Calculation',
        icon: Icons.timer_outlined,
        builder: const MathSprintBetaScreen(),
      ),
      BetaGameInfo(
        id: 'mathblocks',
        name: 'Mental Math Blocks',
        description: 'Falling block numbers. Match target calculation values.',
        category: 'Math & Calculation',
        icon: Icons.view_headline_outlined,
        builder: const MentalMathBlocksBetaScreen(),
      ),

      // --- MEMORY & REFLEX ---
      BetaGameInfo(
        id: 'mapmemory',
        name: 'Map Memory',
        description: 'Look at a map briefly, then recall specific location labels.',
        category: 'Memory & Reflex',
        icon: Icons.map_outlined,
        builder: const MapMemoryBetaScreen(),
      ),
      BetaGameInfo(
        id: 'buzzer',
        name: 'Buzzer',
        description: 'Estimate the exact passage of target seconds.',
        category: 'Memory & Reflex',
        icon: Icons.notifications_active_outlined,
        builder: const BuzzerBetaScreen(),
      ),
      BetaGameInfo(
        id: 'tentandtrees',
        name: 'Tent & Trees',
        description: 'Attach one tent orthogonally to each tree. Tents cannot touch.',
        category: 'Object Placement',
        icon: Icons.forest_outlined,
        builder: const TentAndTreesBetaScreen(),
      ),
      BetaGameInfo(
        id: 'kakurasu',
        name: 'Kakurasu',
        description: 'Shade cells matching weighted row/column target sums.',
        category: 'Math & Calculation',
        icon: Icons.calculate_outlined,
        builder: const KakurasuBetaScreen(),
      ),
      BetaGameInfo(
        id: 'hitori',
        name: 'Hitori',
        description: 'Shade duplicate numbers. Shaded cells cannot be adjacent.',
        category: 'Logic Grids',
        icon: Icons.grid_on_outlined,
        builder: const HitoriBetaScreen(),
      ),
      BetaGameInfo(
        id: 'shakashaka',
        name: 'Shakashaka',
        description: 'Place half-cell triangles to form rectangular white areas.',
        category: 'Logic Grids',
        icon: Icons.border_all_outlined,
        builder: const ShakashakaBetaScreen(),
      ),
      BetaGameInfo(
        id: 'thermometers',
        name: 'Thermometers',
        description: 'Fill thermometers from the bulb up to match row/col target counts.',
        category: 'Object Placement',
        icon: Icons.thermostat_outlined,
        builder: const ThermometersBetaScreen(),
      ),
      BetaGameInfo(
        id: 'tictactoe',
        name: 'Tic Tac Toe',
        description: 'Complete the classic grid without repeating marks in any line.',
        category: 'Memory & Reflex',
        icon: Icons.close_rounded,
        builder: const TicTacToeBetaScreen(),
      ),
          BetaGameInfo(
        id: 'tapa',
        name: 'Tapa',
        description: 'Shade contiguous cells satisfying adjacent run-length clues.',
        category: 'Logic Grids',
        icon: Icons.grid_on,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Tapa',
          description: 'Shade contiguous cells satisfying adjacent run-length clues.',
          category: 'Logic Grids',
          uiType: 'shading',
        ),
      ),
      BetaGameInfo(
        id: 'lits',
        name: 'LITS',
        description: 'Shade one tetromino in each region; all shading connects.',
        category: 'Logic Grids',
        icon: Icons.grid_4x4,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'LITS',
          description: 'Shade one tetromino in each region; all shading connects.',
          category: 'Logic Grids',
          uiType: 'shading',
        ),
      ),
      BetaGameInfo(
        id: 'norinori',
        name: 'Norinori',
        description: 'Shade exactly two cells per region to form 2x1 dominoes.',
        category: 'Logic Grids',
        icon: Icons.space_dashboard_outlined,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Norinori',
          description: 'Shade exactly two cells per region to form 2x1 dominoes.',
          category: 'Logic Grids',
          uiType: 'shading',
        ),
      ),
      BetaGameInfo(
        id: 'yinyang',
        name: 'Yin-Yang',
        description: 'Fill every cell black or white forming connected groups.',
        category: 'Logic Grids',
        icon: Icons.contrast,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Yin-Yang',
          description: 'Fill every cell black or white forming connected groups.',
          category: 'Logic Grids',
          uiType: 'yinyang',
        ),
      ),
      BetaGameInfo(
        id: 'kuromasu',
        name: 'Kuromasu',
        description: 'Shade cells to block line-of-sight counts from numbered cells.',
        category: 'Logic Grids',
        icon: Icons.visibility_off,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Kuromasu',
          description: 'Shade cells to block line-of-sight counts from numbered cells.',
          category: 'Logic Grids',
          uiType: 'shading',
        ),
      ),
      BetaGameInfo(
        id: 'heyawake',
        name: 'Heyawake',
        description: 'Shade cells per room count with no adjacent shading.',
        category: 'Logic Grids',
        icon: Icons.door_sliding_outlined,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Heyawake',
          description: 'Shade cells per room count with no adjacent shading.',
          category: 'Logic Grids',
          uiType: 'shading',
        ),
      ),
      BetaGameInfo(
        id: 'nurimisaki',
        name: 'Nurimisaki',
        description: 'Shade grid so unshaded cells form a path with circle capes.',
        category: 'Logic Grids',
        icon: Icons.navigation_outlined,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Nurimisaki',
          description: 'Shade grid so unshaded cells form a path with circle capes.',
          category: 'Logic Grids',
          uiType: 'shading',
        ),
      ),
      BetaGameInfo(
        id: 'kurotto',
        name: 'Kurotto',
        description: 'Circles state the total size of shaded blobs touching them.',
        category: 'Logic Grids',
        icon: Icons.lens_blur,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Kurotto',
          description: 'Circles state the total size of shaded blobs touching them.',
          category: 'Logic Grids',
          uiType: 'shading',
        ),
      ),
      BetaGameInfo(
        id: 'mosaic',
        name: 'Mosaic',
        description: 'Minesweeper logic where clues count shaded cells in 3x3.',
        category: 'Logic Grids',
        icon: Icons.blur_on,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Mosaic',
          description: 'Minesweeper logic where clues count shaded cells in 3x3.',
          category: 'Logic Grids',
          uiType: 'shading',
        ),
      ),
      BetaGameInfo(
        id: 'cave',
        name: 'Cave (Corral)',
        description: 'Draw a single closed cave region containing all clues.',
        category: 'Logic Grids',
        icon: Icons.panorama_fish_eye,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Cave (Corral)',
          description: 'Draw a single closed cave region containing all clues.',
          category: 'Logic Grids',
          uiType: 'shading',
        ),
      ),
      BetaGameInfo(
        id: 'fillomino',
        name: 'Fillomino',
        description: 'Divide grid into polyominoes equal to their cell number.',
        category: 'Paths & Loops',
        icon: Icons.grid_view,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Fillomino',
          description: 'Divide grid into polyominoes equal to their cell number.',
          category: 'Paths & Loops',
          uiType: 'region',
        ),
      ),
      BetaGameInfo(
        id: 'galaxies',
        name: 'Galaxies',
        description: 'Divide grid into 180-degree rotationally symmetric regions.',
        category: 'Paths & Loops',
        icon: Icons.brightness_low,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Galaxies',
          description: 'Divide grid into 180-degree rotationally symmetric regions.',
          category: 'Paths & Loops',
          uiType: 'region',
        ),
      ),
      BetaGameInfo(
        id: 'ripple_effect',
        name: 'Ripple Effect',
        description: 'Fill region of size N with 1..N. Duplicates must be spaced N cells apart.',
        category: 'Math & Calculation',
        icon: Icons.waves,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Ripple Effect',
          description: 'Fill region of size N with 1..N. Duplicates must be spaced N cells apart.',
          category: 'Math & Calculation',
          uiType: 'latin_square',
        ),
      ),
      BetaGameInfo(
        id: 'araf',
        name: 'Araf',
        description: 'Divide into regions containing 2 clues of size strictly between them.',
        category: 'Paths & Loops',
        icon: Icons.pivot_table_chart,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Araf',
          description: 'Divide into regions containing 2 clues of size strictly between them.',
          category: 'Paths & Loops',
          uiType: 'region',
        ),
      ),
      BetaGameInfo(
        id: 'sashigane',
        name: 'Sashigane',
        description: 'Divide grid into L-shaped pieces matching arrow directions.',
        category: 'Paths & Loops',
        icon: Icons.south_east,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Sashigane',
          description: 'Divide grid into L-shaped pieces matching arrow directions.',
          category: 'Paths & Loops',
          uiType: 'region',
        ),
      ),
      BetaGameInfo(
        id: 'dominosa',
        name: 'Dominosa',
        description: 'Recover a unique domino set hidden in a grid of numbers.',
        category: 'Logic Grids',
        icon: Icons.casino_outlined,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Dominosa',
          description: 'Recover a unique domino set hidden in a grid of numbers.',
          category: 'Logic Grids',
          uiType: 'region',
        ),
      ),
      BetaGameInfo(
        id: 'battleships',
        name: 'Battleships',
        description: 'Place a hidden fleet matching row/column segment counts.',
        category: 'Object Placement',
        icon: Icons.directions_boat,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Battleships',
          description: 'Place a hidden fleet matching row/column segment counts.',
          category: 'Object Placement',
          uiType: 'object',
        ),
      ),
      BetaGameInfo(
        id: 'statue_park',
        name: 'Statue Park',
        description: 'Place polyominoes without touching orthogonally to cover black dots.',
        category: 'Object Placement',
        icon: Icons.category,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Statue Park',
          description: 'Place polyominoes without touching orthogonally to cover black dots.',
          category: 'Object Placement',
          uiType: 'object',
        ),
      ),
      BetaGameInfo(
        id: 'aquarium',
        name: 'Aquarium',
        description: 'Fill tank regions with water obeying gravity to match target counts.',
        category: 'Object Placement',
        icon: Icons.water,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Aquarium',
          description: 'Fill tank regions with water obeying gravity to match target counts.',
          category: 'Object Placement',
          uiType: 'object',
        ),
      ),
      BetaGameInfo(
        id: 'snake',
        name: 'Snake',
        description: 'Draw a non-self-touching snake between endpoints of target length.',
        category: 'Object Placement',
        icon: Icons.gesture,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Snake',
          description: 'Draw a non-self-touching snake between endpoints of target length.',
          category: 'Object Placement',
          uiType: 'object',
        ),
      ),
      BetaGameInfo(
        id: 'yajilin',
        name: 'Yajilin',
        description: 'Arrows count shaded cells. Draw loop through non-shaded cells.',
        category: 'Paths & Loops',
        icon: Icons.loop,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Yajilin',
          description: 'Arrows count shaded cells. Draw loop through non-shaded cells.',
          category: 'Paths & Loops',
          uiType: 'loop',
        ),
      ),
      BetaGameInfo(
        id: 'shingoki',
        name: 'Shingoki',
        description: 'Draw closed loop: white circles = go straight, black = turn.',
        category: 'Paths & Loops',
        icon: Icons.traffic,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Shingoki',
          description: 'Draw closed loop: white circles = go straight, black = turn.',
          category: 'Paths & Loops',
          uiType: 'loop',
        ),
      ),
      BetaGameInfo(
        id: 'castle_wall',
        name: 'Castle Wall',
        description: 'Draw loop. Black clues are inside, white clues outside.',
        category: 'Paths & Loops',
        icon: Icons.fort,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Castle Wall',
          description: 'Draw loop. Black clues are inside, white clues outside.',
          category: 'Paths & Loops',
          uiType: 'loop',
        ),
      ),
      BetaGameInfo(
        id: 'country_road',
        name: 'Country Road',
        description: 'Draw loop visiting each bordered region exactly once.',
        category: 'Paths & Loops',
        icon: Icons.explore,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Country Road',
          description: 'Draw loop visiting each bordered region exactly once.',
          category: 'Paths & Loops',
          uiType: 'loop',
        ),
      ),
      BetaGameInfo(
        id: 'hidato',
        name: 'Hidato',
        description: 'Place consecutive numbers 1..N adjacent orthogonally/diagonally.',
        category: 'Paths & Loops',
        icon: Icons.format_list_numbered,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Hidato',
          description: 'Place consecutive numbers 1..N adjacent orthogonally/diagonally.',
          category: 'Paths & Loops',
          uiType: 'loop',
        ),
      ),
      BetaGameInfo(
        id: 'suguru',
        name: 'Suguru',
        description: 'Fill region of size N with 1..N. Same numbers cannot touch.',
        category: 'Math & Calculation',
        icon: Icons.looks_5,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Suguru',
          description: 'Fill region of size N with 1..N. Same numbers cannot touch.',
          category: 'Math & Calculation',
          uiType: 'latin_square',
        ),
      ),
      BetaGameInfo(
        id: 'kropki',
        name: 'Kropki',
        description: 'Latin square. White dots indicate consecutive, black indicate doubles.',
        category: 'Math & Calculation',
        icon: Icons.radio_button_checked,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Kropki',
          description: 'Latin square. White dots indicate consecutive, black indicate doubles.',
          category: 'Math & Calculation',
          uiType: 'latin_square',
        ),
      ),
      BetaGameInfo(
        id: 'renzoku',
        name: 'Renzoku',
        description: 'Latin square where dots mark consecutive neighbors.',
        category: 'Math & Calculation',
        icon: Icons.grain,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Renzoku',
          description: 'Latin square where dots mark consecutive neighbors.',
          category: 'Math & Calculation',
          uiType: 'latin_square',
        ),
      ),
      BetaGameInfo(
        id: 'sandwich_sudoku',
        name: 'Sandwich Sudoku',
        description: 'Sudoku where outside clues sum digits between 1 and 9.',
        category: 'Math & Calculation',
        icon: Icons.lunch_dining,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Sandwich Sudoku',
          description: 'Sudoku where outside clues sum digits between 1 and 9.',
          category: 'Math & Calculation',
          uiType: 'latin_square',
        ),
      ),
      BetaGameInfo(
        id: 'thermo_sudoku',
        name: 'Thermo Sudoku',
        description: 'Sudoku where digits increase along thermometer shapes.',
        category: 'Math & Calculation',
        icon: Icons.thermostat,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Thermo Sudoku',
          description: 'Sudoku where digits increase along thermometer shapes.',
          category: 'Math & Calculation',
          uiType: 'latin_square',
        ),
      ),
      BetaGameInfo(
        id: 'arrow_sudoku',
        name: 'Arrow Sudoku',
        description: 'Sudoku where shaft digits sum to the digit in the circle.',
        category: 'Math & Calculation',
        icon: Icons.trending_flat,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Arrow Sudoku',
          description: 'Sudoku where shaft digits sum to the digit in the circle.',
          category: 'Math & Calculation',
          uiType: 'latin_square',
        ),
      ),
      BetaGameInfo(
        id: 'schrodinger_cell',
        name: 'Schrödinger-Cell',
        description: 'Sudoku where select cells can hold two values simultaneously.',
        category: 'Math & Calculation',
        icon: Icons.science,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Schrödinger-Cell',
          description: 'Sudoku where select cells can hold two values simultaneously.',
          category: 'Math & Calculation',
          uiType: 'latin_square',
        ),
      ),
      BetaGameInfo(
        id: 'cryptarithms',
        name: 'Cryptarithms',
        description: 'Verbal arithmetic where letters stand for unique digits.',
        category: 'Math & Calculation',
        icon: Icons.abc,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Cryptarithms',
          description: 'Verbal arithmetic where letters stand for unique digits.',
          category: 'Math & Calculation',
          uiType: 'word',
        ),
      ),
      BetaGameInfo(
        id: 'mathler',
        name: 'Mathler',
        description: 'Guess the 6-character equation that equals target number.',
        category: 'Math & Calculation',
        icon: Icons.equalizer,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Mathler',
          description: 'Guess the 6-character equation that equals target number.',
          category: 'Math & Calculation',
          uiType: 'word',
        ),
      ),
      BetaGameInfo(
        id: 'waffle',
        name: 'Waffle',
        description: 'Swap scrambled letters to solve crossing words.',
        category: 'Word & Vocabulary',
        icon: Icons.grid_goldenratio,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Waffle',
          description: 'Swap scrambled letters to solve crossing words.',
          category: 'Word & Vocabulary',
          uiType: 'word',
        ),
      ),
      BetaGameInfo(
        id: 'semantle',
        name: 'Semantle',
        description: 'Guess target word based on semantic similarity score.',
        category: 'Word & Vocabulary',
        icon: Icons.compare,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Semantle',
          description: 'Guess target word based on semantic similarity score.',
          category: 'Word & Vocabulary',
          uiType: 'word',
        ),
      ),
      BetaGameInfo(
        id: 'anagram_hive',
        name: 'Anagram Hive',
        description: 'Find all words using 7 honeycomb letters including center.',
        category: 'Word & Vocabulary',
        icon: Icons.hive,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Anagram Hive',
          description: 'Find all words using 7 honeycomb letters including center.',
          category: 'Word & Vocabulary',
          uiType: 'word',
        ),
      ),
      BetaGameInfo(
        id: 'cell_tower',
        name: 'Cell Tower',
        description: 'Divide letter grid into regions spelling valid words.',
        category: 'Word & Vocabulary',
        icon: Icons.domain,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Cell Tower',
          description: 'Divide letter grid into regions spelling valid words.',
          category: 'Word & Vocabulary',
          uiType: 'word',
        ),
      ),
      BetaGameInfo(
        id: 'slant',
        name: 'Slant',
        description: 'Fill every cell with diagonal slashes avoiding closed loops.',
        category: 'Logic Grids',
        icon: Icons.horizontal_rule_rounded,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Slant',
          description: 'Fill every cell with diagonal slashes avoiding closed loops.',
          category: 'Logic Grids',
          uiType: 'slant',
        ),
      ),
      BetaGameInfo(
        id: 'stitches',
        name: 'Stitches',
        description: 'Connect adjacent regions with exactly one stitch pair.',
        category: 'Logic Grids',
        icon: Icons.difference,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Stitches',
          description: 'Connect adjacent regions with exactly one stitch pair.',
          category: 'Logic Grids',
          uiType: 'stitches',
        ),
      ),
      BetaGameInfo(
        id: 'tatamibari',
        name: 'Tatamibari',
        description: 'Divide grid into rectangles matching orientation clues.',
        category: 'Paths & Loops',
        icon: Icons.table_bar,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Tatamibari',
          description: 'Divide grid into rectangles matching orientation clues.',
          category: 'Paths & Loops',
          uiType: 'region',
        ),
      ),
      BetaGameInfo(
        id: 'aqre',
        name: 'Aqre',
        description: 'Shade cells per region counts with no 4-in-a-row constraint.',
        category: 'Logic Grids',
        icon: Icons.compress,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Aqre',
          description: 'Shade cells per region counts with no 4-in-a-row constraint.',
          category: 'Logic Grids',
          uiType: 'shading',
        ),
      ),
      BetaGameInfo(
        id: 'static_minesweeper',
        name: 'Static Minesweeper',
        description: 'Fixed Minesweeper board solvable by pure logical deduction.',
        category: 'Logic Grids',
        icon: Icons.warning_amber,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Static Minesweeper',
          description: 'Fixed Minesweeper board solvable by pure logical deduction.',
          category: 'Logic Grids',
          uiType: 'shading',
        ),
      ),
      BetaGameInfo(
        id: 'nurimaze',
        name: 'Nurimaze',
        description: 'Shade rooms to form a maze with a path from S to G.',
        category: 'Logic Grids',
        icon: Icons.alt_route,
        builder: const LogicGridPlaceholderScreen(
          gameName: 'Nurimaze',
          description: 'Shade rooms to form a maze with a path from S to G.',
          category: 'Logic Grids',
          uiType: 'shading',
        ),
      ),
];
  }

  @override
  Widget build(BuildContext context) {
    final allGames = _getBetaGamesList();
    final filteredGames = allGames.where((g) {
      final matchesSearch = g.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          g.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          g.category.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesSearch;
    }).toList();

    // Group filtered games by category
    final Map<String, List<BetaGameInfo>> grouped = {};
    for (final game in filteredGames) {
      grouped.putIfAbsent(game.category, () => []).add(game);
    }

    final categories = ['Logic Grids', 'Paths & Loops', 'Movement & Sliding', 'Math & Calculation', 'Memory & Reflex', 'Word & Vocabulary'];

    return Scaffold(
      backgroundColor: context.bgDark,
      body: Column(
        children: [
          // Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: const BoxDecoration(
              gradient: AppTheme.zenGradient,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CogniQ Beta Labs',
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Test and play upcoming cognitive training games',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              style: GoogleFonts.outfit(color: context.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search beta games...',
                hintStyle: GoogleFonts.outfit(color: context.textMuted),
                prefixIcon: Icon(Icons.search, color: context.textMuted),
                filled: true,
                fillColor: context.bgCard,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.textMuted.withAlpha(40)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.dustyMauve, width: 1.5),
                ),
              ),
            ),
          ),

          // Game List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                for (final cat in categories)
                  if (grouped[cat] != null && grouped[cat]!.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                      child: Text(
                        cat.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.dustyMauve,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: grouped[cat]!.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, idx) {
                        final game = grouped[cat]![idx];
                        final completed = _progressMap[game.id] ?? 0;

                        return Container(
                          decoration: BoxDecoration(
                            color: context.bgCard,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () async {
                                await DailyChallengeManager.clearDailyModifier();
                                if (!context.mounted) return;
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => game.builder),
                                );
                                _loadProgress(); // Reload completion progress when coming back
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppTheme.dustyMauve.withAlpha(20),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        game.icon,
                                        color: AppTheme.dustyMauve,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            game.name,
                                            style: GoogleFonts.outfit(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: context.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            game.description,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.outfit(
                                              fontSize: 12,
                                              color: context.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: completed == 10
                                                      ? AppTheme.softSage.withAlpha(30)
                                                      : Colors.amber.withAlpha(30),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  completed == 10 ? 'COMPLETED' : 'PROGRESS: $completed/10',
                                                  style: GoogleFonts.outfit(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 10,
                                                    color: completed == 10 ? AppTheme.softSage : Colors.amber[800],
                                                  ),
                                                ),
                                              ),
                                              const Spacer(),
                                              Icon(
                                                Icons.play_arrow_rounded,
                                                color: context.textMuted,
                                                size: 20,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
*/
