import 'package:flutter/material.dart';
import '../game/flow_grid_game.dart';
import '../game/map_generator.dart';
import '../game/save_manager.dart';

class MapSelectionOverlay extends StatelessWidget {
  final FlowGridGame game;

  const MapSelectionOverlay({super.key, required this.game});

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
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'SELECT MISSION',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose your terrain and start the flow.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _MapCard(
                          title: 'ZEN',
                          description: 'Balanced baseline terrain. Ideal for training. Standard mechanics and layouts.',
                          icon: Icons.unfold_more,
                          color: Colors.blueAccent,
                          onTap: () => _startGame(context, MapType.zen),
                        ),
                        _MapCard(
                          title: 'ANDES',
                          description: 'Terracotta canyons and mountain pockets. Restricts expansions, requiring strategic valley connections.',
                          icon: Icons.landscape,
                          color: Colors.orangeAccent,
                          onTap: () => _startGame(context, MapType.andes),
                        ),
                        _MapCard(
                          title: 'NILE',
                          description: 'Wide central river dividing fertile banks. Heavy reliance on water crossings and bridge management.',
                          icon: Icons.waves,
                          color: Colors.cyanAccent,
                          onTap: () => _startGame(context, MapType.nile),
                        ),
                        _MapCard(
                          title: 'ARCTIC',
                          description: 'Frozen Tundra. Features: Ice Roads over lakes (40% slower, 0 bridge cost), and periodic Blizzards that drop vehicle speed to 60%.',
                          icon: Icons.ac_unit,
                          color: Colors.lightBlueAccent,
                          onTap: () => _startGame(context, MapType.arctic),
                        ),
                        _MapCard(
                          title: 'SAVANNA',
                          description: 'Dusty grasslands. Features: Unpaved Dirt Roads (20% slower), wild Gazelle Crossings blocking lanes, and blinding Dust Storms.',
                          icon: Icons.terrain,
                          color: Colors.amberAccent,
                          onTap: () => _startGame(context, MapType.savanna),
                        ),
                        _MapCard(
                          title: 'DELTA',
                          description: 'River wetlands. Features: Periodic Drawbridges blocking lanes, and Flash Floods that temporarily submerge and close roads.',
                          icon: Icons.water,
                          color: Colors.tealAccent,
                          onTap: () => _startGame(context, MapType.delta),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    TextButton(
                      onPressed: () {
                        game.overlays.remove('mapSelection');
                        game.overlays.add('mainMenu');
                      },
                      child: Text(
                        'BACK TO HEADQUARTERS',
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
    game.overlays.remove('mapSelection');
    game.startGame(resume: false, mapType: type, slotIndex: slot);
  }
}

class _MapCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MapCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
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
          duration: const Duration(milliseconds: 200),
          width: 220,
          height: 360,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _isHovered ? widget.color.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isHovered ? widget.color : Colors.white.withValues(alpha: 0.1),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                size: 60,
                color: _isHovered ? widget.color : Colors.white.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 24),
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const Spacer(),
              if (_isHovered)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'SELECT MAP',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
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
