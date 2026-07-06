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
import '../games/beta/chess_puzzles_beta.dart';
import '../games/beta/hashi_beta.dart';
import '../games/beta/masyu_beta.dart';
import '../games/beta/slitherlink_beta.dart';
import '../games/beta/sliding_tile_beta.dart';
import '../games/beta/math_sprint_beta.dart';
import '../games/beta/mental_math_blocks_beta.dart';
import '../games/beta/map_memory_beta.dart';
import '../games/beta/buzzer_beta.dart';
import '../games/categories/categories_screen.dart';
import '../games/beta/rush_hour_beta.dart';
import '../games/beta/word_salad_beta.dart';
import '../games/nonogram/nonogram_screen.dart';
import '../games/word_search/word_search_screen.dart';

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
      BetaGameInfo(
        id: 'chesspuzzles',
        name: 'Chess Puzzles',
        description: 'Find the tactical moves to achieve checkmate in 1 or 2.',
        category: 'Logic Grids',
        icon: Icons.extension_outlined,
        builder: const ChessPuzzlesBetaScreen(),
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
      BetaGameInfo(
        id: 'slidingtile',
        name: 'Sliding Tile',
        description: 'Reorder numbered tiles sequentially by sliding into the gap.',
        category: 'Movement & Sliding',
        icon: Icons.grid_view_outlined,
        builder: const SlidingTileBetaScreen(),
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
        id: 'connections',
        name: 'Categories',
        description: 'Group 16 words into 4 categories.',
        category: 'Word & Vocabulary',
        icon: Icons.hub_outlined,
        builder: const CategoriesScreen(),
      ),
      BetaGameInfo(
        id: 'block_escape',
        name: 'Block Escape',
        description: 'Slide blocks to escape the red block.',
        category: 'Movement & Sliding',
        icon: Icons.door_sliding_outlined,
        builder: const RushHourBetaScreen(),
      ),
      BetaGameInfo(
        id: 'word_salad',
        name: 'Word Salad',
        description: 'Unscramble letters to find words in target categories.',
        category: 'Word & Vocabulary',
        icon: Icons.restaurant_menu_outlined,
        builder: const WordSaladBetaScreen(),
      ),
      BetaGameInfo(
        id: 'nonogram',
        name: 'Nonogram',
        description: 'Fill grid cells to match row/column clues.',
        category: 'Logic Grids',
        icon: Icons.apps_rounded,
        builder: const NonogramScreen(),
      ),
      BetaGameInfo(
        id: 'wordsearch',
        name: 'Word Search',
        description: 'Find target words hidden in grid.',
        category: 'Word & Vocabulary',
        icon: Icons.search_outlined,
        builder: const WordSearchScreen(),
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
