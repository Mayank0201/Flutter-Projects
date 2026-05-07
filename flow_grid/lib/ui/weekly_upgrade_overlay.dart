import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../game/flow_grid_game.dart';
import '../models/game_constants.dart';

class WeeklyUpgradeOverlay extends StatelessWidget {
  final FlowGridGame game;
  const WeeklyUpgradeOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Container(
            padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: GameConstants.hudBackground,
            borderRadius: BorderRadius.circular(24),
          ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('WEEK ${game.week}', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 8),
                Text('CHOOSE REWARD', style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                ...game.weeklyOptions.map((opt) {
                  String label = '';
                  IconData icon = Icons.add_road;
                  if (opt == 'tunnels') { label = '20 ROADS + 1 TUNNEL'; icon = Icons.terrain; }
                  else if (opt == 'trafficLights') { label = '20 ROADS + 2 TRAFFIC LIGHTS'; icon = Icons.traffic; }
                  else if (opt == 'smartJunction') { label = '20 ROADS + 1 SMART JUNCTION'; icon = Icons.hub; }
                  else if (opt == 'expressLane') { label = '10 ROADS + 1 EXPRESS LANE'; icon = Icons.bolt; }
                  else if (opt == 'doubleRoads') { label = '30 ROADS'; icon = Icons.add_road; }
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _upgradeButton(context, label, icon, () => game.applyUpgrade(opt)),
                  );
                }),
              ],
            ),
        ),
        ),
      ),
    );
  }

  Widget _upgradeButton(BuildContext context, String label, IconData icon, VoidCallback onTap) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white10,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      onPressed: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(label, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
