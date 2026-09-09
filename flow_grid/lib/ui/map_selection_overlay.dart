import 'package:flutter/material.dart';
import '../game/flow_grid_game.dart';
import '../game/map_generator.dart';
import '../game/save_manager.dart';

class MapSelectionOverlay extends StatefulWidget {
  final FlowGridGame game;

  const MapSelectionOverlay({super.key, required this.game});

  @override
  State<MapSelectionOverlay> createState() => _MapSelectionOverlayState();
}

class _MapSelectionOverlayState extends State<MapSelectionOverlay> {
  final Map<MapType, int> _highScores = {};

  @override
  void initState() {
    super.initState();
    _loadHighScores();
  }

  Future<void> _loadHighScores() async {
    for (final type in MapType.values) {
      final hs = await SaveManager.getHighScore(type);
      _highScores[type] = hs;
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.85),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF10191C),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFFBF945C).withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'CHOOSE A MAP',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pick a region and start building.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 28),
                    // LOWKEY MVP: only 3 maps now (Zen/Andes/Nile)
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _MapCard(
                          title: 'ZEN',
                          description:
                              'Flat open land. Good for learning the basics.',
                          icon: Icons.grain_rounded,
                          color: const Color(0xFF5AC878),
                          highScore: _highScores[MapType.zen] ?? 0,
                          onTap: () => _startGame(context, MapType.zen),
                        ),
                        _MapCard(
                          title: 'ANDES',
                          description:
                              'Narrow valleys and cliffsides. Space is tight — plan your routes carefully.',
                          icon: Icons.filter_hdr_rounded,
                          color: const Color(0xFFE8853C),
                          highScore: _highScores[MapType.andes] ?? 0,
                          onTap: () => _startGame(context, MapType.andes),
                        ),
                        _MapCard(
                          title: 'NILE',
                          description:
                              'A big river splits the map in half. You\'ll need plenty of bridges.',
                          icon: Icons.water_rounded,
                          color: const Color(0xFF6FB3BE),
                          highScore: _highScores[MapType.nile] ?? 0,
                          onTap: () => _startGame(context, MapType.nile),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    TextButton(
                      onPressed: () {
                        widget.game.overlays.remove('mapSelection');
                        widget.game.overlays.add('mainMenu');
                      },
                      child: Text(
                        'BACK',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startGame(BuildContext context, MapType type) async {
    final slot = await SaveManager.getNextAvailableSlot();
    widget.game.overlays.remove('mapSelection');
    widget.game.startGame(resume: false, mapType: type, slotIndex: slot);
  }
}

class _MapCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final int highScore;
  final VoidCallback onTap;

  const _MapCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.highScore,
    required this.onTap,
  });

  @override
  State<_MapCard> createState() => _MapCardState();
}

class _MapCardState extends State<_MapCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          width: 220,
          height: 360,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _isHovered
                ? const Color(0xFF182428)
                : const Color(0xFF141D20),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: _isHovered
                  ? widget.color
                  : const Color(0xFF1F2F33),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: widget.color.withValues(alpha: 0.35)),
                ),
                child: Icon(
                  widget.icon,
                  size: 24,
                  color: widget.color,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              // High Score Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: widget.highScore > 0
                        ? const Color(0xFFBF945C)
                        : const Color(0xFF223035),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.highScore > 0
                            ? const Color(0xFFBF945C)
                            : const Color(0xFF33454B),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.highScore > 0
                          ? 'RECORD: ${widget.highScore}'
                          : 'RECORD: --',
                      style: TextStyle(
                        color: widget.highScore > 0
                            ? const Color(0xFFE5A96A)
                            : Colors.white.withValues(alpha: 0.4),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
              const Spacer(),
              if (_isHovered)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: widget.color),
                  ),
                  child: Text(
                    'START',
                    style: TextStyle(
                      color: widget.color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
