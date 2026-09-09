import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../game/flow_grid_game.dart';
import '../game/save_manager.dart';

class GameOverOverlay extends StatefulWidget {
  final FlowGridGame game;

  const GameOverOverlay({super.key, required this.game});

  @override
  State<GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<GameOverOverlay> {
  int _highScore = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadHighScore();
  }

  Future<void> _loadHighScore() async {
    final hs = await SaveManager.getHighScore(widget.game.selectedMapType);
    if (mounted) {
      setState(() {
        _highScore = hs;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine map name to display
    final mapName = widget.game.selectedMapType.name.toUpperCase();

    return DefaultTextStyle(
      style: GoogleFonts.outfit(decoration: TextDecoration.none),
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 300),
        tween: Tween<double>(begin: 0.0, end: 1.0),
        curve: Curves.easeOut,
        builder: (context, scrimValue, child) => Container(
          color: Colors.black.withValues(
            alpha: 0.85 * scrimValue.clamp(0.0, 1.0),
          ),
          child: child,
        ),
        child: Center(
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 400),
            tween: Tween<double>(begin: 0.0, end: 1.0),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.9 + (value * 0.1),
                  child: child,
                ),
              );
            },
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10191C),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFFE0736A).withValues(alpha: 0.7),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 36,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Status header badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF381E22),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  color: const Color(0xFFE0736A),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'GAME OVER',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFE0736A),
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'GRIDLOCK!',
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'A destination overflowed — the grid couldn\'t keep up.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.5),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$mapName REGION',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white.withValues(
                                        alpha: 0.6,
                                      ),
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32),

                                // New High Score Celebration Banner
                                if (widget.game.newHighScore) ...[
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    margin: const EdgeInsets.only(bottom: 24),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.amber.withValues(alpha: 0.0),
                                          Colors.amber.withValues(alpha: 0.2),
                                          Colors.amber.withValues(alpha: 0.0),
                                        ],
                                      ),
                                      border: Border.symmetric(
                                        horizontal: BorderSide(
                                          color: Colors.amber.withValues(
                                            alpha: 0.4,
                                          ),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.emoji_events,
                                          color: Colors.amber,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'NEW PERSONAL BEST!',
                                          style: GoogleFonts.outfit(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.amber,
                                            letterSpacing: 2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // Stats Grid
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildStatCard(
                                        'Score',
                                        '${widget.game.score}',
                                        isPrimary: true,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildStatCard(
                                        'Best',
                                        _loaded ? '$_highScore' : '--',
                                        isHighScore: widget.game.newHighScore,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildStatCard(
                                        'Weeks Survived',
                                        '${widget.game.week}',
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildStatCard(
                                        'Deliveries',
                                        '${widget.game.totalDeliveries}',
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 40),
                                 // Action Buttons
                                GestureDetector(
                                  onTap: () {
                                    widget.game.overlays.remove('gameOver');
                                    widget.game.startGame(
                                      resume: false,
                                      mapType: widget.game.selectedMapType,
                                    );
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFBF945C),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'TRY AGAIN',
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF10191C),
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                GestureDetector(
                                  onTap: () {
                                    widget.game.overlays.remove('gameOver');
                                    widget.game.overlays.add('mainMenu');
                                    widget.game.phase = GamePhase.menu;
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF141D20),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: const Color(0xFF2E3F44),
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'MAIN MENU',
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white70,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
  }

  Widget _buildStatCard(
    String label,
    String value, {
    bool isPrimary = false,
    bool isHighScore = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141D20),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isHighScore
              ? const Color(0xFFBF945C)
              : const Color(0xFF1F2F33),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: isHighScore
                  ? const Color(0xFFE5A96A)
                  : Colors.white.withValues(alpha: 0.4),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isHighScore
                  ? const Color(0xFFBF945C)
                  : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
