import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../game/flow_grid_game.dart';
import '../game/save_manager.dart';

class Ember {
  double x, y;
  double speed;
  double radius;
  double opacity;
  double angle;
  double angleSpeed;

  Ember({
    required this.x,
    required this.y,
    required this.speed,
    required this.radius,
    required this.opacity,
    required this.angle,
    required this.angleSpeed,
  });
}

class EmberPainter extends CustomPainter {
  final List<Ember> embers;
  EmberPainter(this.embers);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final e in embers) {
      paint.color = const Color(0xFFE74C3C).withValues(alpha: e.opacity);
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
      canvas.drawCircle(Offset(e.x, e.y), e.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class GameOverOverlay extends StatefulWidget {
  final FlowGridGame game;

  const GameOverOverlay({super.key, required this.game});

  @override
  State<GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<GameOverOverlay> with SingleTickerProviderStateMixin {
  int _highScore = 0;
  bool _loaded = false;
  late AnimationController _controller;
  final List<Ember> _embers = [];
  final math.Random _random = math.Random();
  double _pulseVal = 0.0;
  double _vignetteIntensity = 0.0;

  @override
  void initState() {
    super.initState();
    _loadHighScore();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addListener(_updateAnimation);
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateAnimation() {
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    setState(() {
      _pulseVal = _controller.value * 2 * math.pi;
      _vignetteIntensity = 0.5 + 0.15 * math.sin(_pulseVal * 2.0);

      // Spawn embers
      if (_embers.length < 40 && _random.nextDouble() < 0.15) {
        _embers.add(Ember(
          x: _random.nextDouble() * size.width,
          y: size.height + 10,
          speed: 30 + _random.nextDouble() * 50,
          radius: 1.0 + _random.nextDouble() * 3.0,
          opacity: 0.15 + _random.nextDouble() * 0.4,
          angle: _random.nextDouble() * 2 * math.pi,
          angleSpeed: -0.5 + _random.nextDouble() * 1.0,
        ));
      }

      // Update embers
      for (int i = _embers.length - 1; i >= 0; i--) {
        final e = _embers[i];
        e.y -= e.speed * 0.016;
        e.angle += e.angleSpeed * 0.016;
        e.x += math.sin(e.angle) * 8 * 0.016;
        
        final progress = (e.y / size.height).clamp(0.0, 1.0);
        e.opacity = (progress * 0.5).clamp(0.0, 1.0);

        if (e.y < -10 || e.opacity <= 0.0) {
          _embers.removeAt(i);
        }
      }
    });
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
    final mapName = widget.game.selectedMapType.name.toUpperCase();
    final size = MediaQuery.of(context).size;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: DefaultTextStyle(
        style: GoogleFonts.outfit(decoration: TextDecoration.none),
        child: Stack(
          children: [
            // Radial Crimson Vignette background
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    Colors.black.withValues(alpha: 0.75),
                    const Color(0xFFC0392B).withValues(alpha: 0.25 * _vignetteIntensity),
                  ],
                ),
              ),
            ),
            // Custom Painter for rising embers
            CustomPaint(
              size: size,
              painter: EmberPainter(_embers),
            ),
            Center(
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 500),
                tween: Tween<double>(begin: 0.0, end: 1.0),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.8 + (value * 0.2),
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
                      color: const Color(0xFF13151A).withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: const Color(0xFFE74C3C).withValues(alpha: 0.2 + 0.15 * math.sin(_pulseVal * 3.0)),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE74C3C).withValues(alpha: 0.1 + 0.08 * math.sin(_pulseVal * 3.0)),
                          blurRadius: 20 + 8 * math.sin(_pulseVal * 3.0),
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(31),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Top Accent bar
                          Container(
                            height: 6,
                            width: double.infinity,
                            color: const Color(0xFFE74C3C),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Title / Icon
                                const Icon(
                                  Icons.error_outline,
                                  color: Color(0xFFE74C3C),
                                  size: 48,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'CITY OVERFLOW',
                                  style: GoogleFonts.outfit(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w300,
                                    color: const Color(0xFFE74C3C),
                                    letterSpacing: 4,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Grid infrastructure limit exceeded.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.4),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$mapName REGION',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white.withValues(alpha: 0.6),
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32),

                                // New High Score Celebration Banner
                                if (widget.game.newHighScore) ...[
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
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
                                          color: Colors.amber.withValues(alpha: 0.4),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
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
                                      child: _buildStatCard('Score', '${widget.game.score}', isPrimary: true),
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
                                      child: _buildStatCard('Weeks Survived', '${widget.game.week}'),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildStatCard('Deliveries', '${widget.game.totalDeliveries}'),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 40),

                                // Action Buttons
                                GestureDetector(
                                  onTap: () {
                                    widget.game.overlays.remove('gameOver');
                                    widget.game.startGame(resume: false, mapType: widget.game.selectedMapType);
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.white.withValues(alpha: 0.1),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        'RETRY SIMULATION',
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                GestureDetector(
                                  onTap: () {
                                    widget.game.overlays.remove('gameOver');
                                    widget.game.overlays.add('mainMenu');
                                    widget.game.phase = GamePhase.menu;
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.12),
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'MAIN MENU',
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white.withValues(alpha: 0.6),
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
        ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, {bool isPrimary = false, bool isHighScore = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: isPrimary
            ? const Color(0xFFE74C3C).withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighScore
              ? Colors.amber.withValues(alpha: 0.3)
              : isPrimary
                  ? const Color(0xFFE74C3C).withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
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
                  ? Colors.amber.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.3),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w500,
              color: isHighScore
                  ? Colors.amber
                  : isPrimary
                      ? const Color(0xFFE74C3C)
                      : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
