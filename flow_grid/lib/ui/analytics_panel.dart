import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../game/flow_grid_game.dart';

class AnalyticsPanel extends StatelessWidget {
  final FlowGridGame game;
  final VoidCallback onClose;

  const AnalyticsPanel({super.key, required this.game, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final gm = game.gridManager!;
    
    // Calculate some live stats
    int totalInfra = gm.infrastructure.length;
    int totalCars = game.cars.length;
    
    // Find busiest district
    String busiestDistrict = "None";
    int maxDemand = -1;
    for (final pos in gm.destinations) {
      final d = gm.getDemand(pos);
      if (d > maxDemand) {
        maxDemand = d;
        busiestDistrict = gm.districtNames[pos.key] ?? "District ${pos.key}";
      }
    }

    return Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C22).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 5),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CITY ANALYTICS',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _statRow('Busiest District', busiestDistrict, Colors.orangeAccent),
          _statRow('Active Vehicles', '$totalCars', Colors.blueAccent),
          _statRow('Infrastructure Units', '$totalInfra', Colors.greenAccent),
          _statRow('Total Deliveries', '${game.totalDeliveries}', Colors.amberAccent),
          _statRow('City Efficiency', '${(game.difficulty * 100).toInt()}%', Colors.purpleAccent),
          const SizedBox(height: 20),
          _performanceBar('Traffic Load', _calculateGlobalLoad(game)),
          const SizedBox(height: 12),
          Text(
            'Strategy Tip: Upgrading highly congested roads to Avenues increases capacity by 3x.',
            style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  double _calculateGlobalLoad(FlowGridGame g) {
    if (g.gridManager!.infrastructure.isEmpty) return 0;
    double total = 0;
    for (final pos in g.gridManager!.infrastructure) {
      total += g.gridManager!.getRoadLoad(pos.x, pos.y);
    }
    return (total / (g.gridManager!.infrastructure.length * 5)).clamp(0.0, 1.0);
  }

  Widget _statRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12)),
          Text(value, style: GoogleFonts.outfit(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _performanceBar(String label, double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white10,
            color: progress > 0.8 ? Colors.redAccent : (progress > 0.5 ? Colors.orangeAccent : Colors.greenAccent),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
