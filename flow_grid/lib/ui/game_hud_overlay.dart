import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../game/flow_grid_game.dart';
import '../models/game_constants.dart';


class GameHudOverlay extends StatefulWidget {
  final FlowGridGame game;
  const GameHudOverlay({super.key, required this.game});

  @override
  State<GameHudOverlay> createState() => _GameHudOverlayState();
}

class _GameHudOverlayState extends State<GameHudOverlay> {
  @override
  void initState() {
    super.initState();
    widget.game.onStateChanged = () {
      if (mounted) setState(() {});
    };
  }

  FlowGridGame get g => widget.game;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: SafeArea(
        child: SizedBox(
          width: g.hudPanelWidth,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E24),
              borderRadius: BorderRadius.circular(16),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top: week + score
                  _topSection(),
                  // Middle: tool buttons
                  _toolSection(),
                  // Bottom: speed controls
                  _speedSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      child: Column(
        children: [
          _miniStat('WK ${g.week}', Colors.white),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: g.weekProgress,
              backgroundColor: Colors.white10,
              color: Colors.blueAccent,
              minHeight: 3,
            ),
          ),
          const SizedBox(height: 8),
          _miniStat('${g.score}', Colors.amber),
          _miniLabel('SCORE'),
          const SizedBox(height: 4),
          _miniStat('${g.totalDeliveries}', Colors.blueAccent),
          _miniLabel('DELIVERIES'),
        ],
      ),
    );
  }

  Widget _toolSection() {
    return Column(
      children: [
        _divider(),
        const SizedBox(height: 4),
        _toolBtn(BuildTool.road, Icons.add_road, '${g.gridManager!.roads}', Colors.grey),
        _toolBtn(BuildTool.tunnel, Icons.terrain, '${g.gridManager!.tunnels}', const Color(0xFF7FB3D3)),
        _toolBtn(BuildTool.trafficLight, Icons.traffic, '${g.gridManager!.trafficLights}', const Color(0xFFE74C3C)),
        _toolBtn(BuildTool.smartJunction, Icons.hub, '${g.gridManager!.smartJunctions}', Colors.orangeAccent),
        _toolBtn(BuildTool.expressLane, Icons.bolt, 
            g.gridManager!.isPlacingExpressLane ? 'Placing...' : '${g.gridManager!.expressLanes}', 
            GameConstants.expressLaneColor),
        _toolBtn(BuildTool.erase, Icons.remove_circle_outline, '', Colors.redAccent),
        const SizedBox(height: 4),
        _divider(),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () {
            g.saveGame();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Game Saved!'), duration: Duration(seconds: 1)),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.save, color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                Text('SAVE', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () {
            g.overlays.remove('hud');
            g.overlays.add('mainMenu');
            g.phase = GamePhase.menu;
            g.timeScale = 0; // Pause game when in menu
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.menu, color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                Text('MENU', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        _divider(),
      ],
    );
  }

  Widget _speedSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: Column(
        children: [
          _miniLabel('SPEED'),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _speedDot(0.0, Icons.pause, Colors.redAccent),
              _speedDot(1.0, Icons.play_arrow, Colors.white70),
              _speedDot(2.0, Icons.fast_forward, Colors.blueAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toolBtn(BuildTool tool, IconData icon, String count, Color accent) {
    final isSelected = g.activeTool == tool;
    return GestureDetector(
      onTap: () => setState(() => g.activeTool = tool),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? accent.withValues(alpha: 0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: accent, width: 1.5)
              : Border.all(color: Colors.transparent),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? accent : Colors.white38, size: 16),
            if (count.isNotEmpty) ...[
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  count,
                  style: GoogleFonts.outfit(
                    color: isSelected ? Colors.white : Colors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _speedDot(double val, IconData icon, Color col) {
    final active = g.timeScale == val;
    return GestureDetector(
      onTap: () => setState(() => g.timeScale = val),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? col.withValues(alpha: 0.2) : Colors.transparent,
          border: Border.all(color: active ? col : Colors.white12, width: 1.5),
        ),
        child: Icon(icon, color: active ? col : Colors.white24, size: 14),
      ),
    );
  }

  Widget _miniStat(String text, Color col) {
    return Text(
      text,
      style: GoogleFonts.outfit(color: col, fontSize: 16, fontWeight: FontWeight.bold),
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _miniLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(color: Colors.white24, fontSize: 9, letterSpacing: 1.5),
    );
  }

  Widget _divider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: Colors.white10,
    );
  }
}
