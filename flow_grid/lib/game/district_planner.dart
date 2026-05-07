import 'package:flow_grid/game/grid_manager.dart';
import 'package:flow_grid/models/grid_cell.dart';

class DistrictTerritory {
  final int colorIndex;
  final bool isCommercial;
  GridPosition center;
  double radius;
  
  DistrictTerritory({
    required this.colorIndex,
    required this.center,
    required this.radius,
    this.isCommercial = false,
  });

  void expand(double amount) {
    radius += amount;
  }
}

class DistrictPlanner {
  final GridManager gridManager;

  // Track territory for each active color
  final Map<int, DistrictTerritory> territories = {};
  
  // Neutral territory buffer to keep some areas open for future expansion
  final List<GridPosition> reservedNeutralCenters = [];

  DistrictPlanner({required this.gridManager});

  /// [NEW] Registers a new district and its starting anchor.
  void registerDistrict(int colorIndex, GridPosition anchor, {required bool isCommercial}) {
    territories[colorIndex] = DistrictTerritory(
      colorIndex: colorIndex,
      center: anchor,
      isCommercial: isCommercial,
      radius: isCommercial ? 15.0 : 6.0, 
    );
  }

  /// [NEW] Expands the territory of a specific color.
  void expandTerritory(int colorIndex, {double amount = 4.0}) {
    territories[colorIndex]?.expand(amount);
  }

  /// Evaluates if an expansion is allowed based on soft influence.
  /// No longer hard-blocks unless it overlaps too heavily with a "virgin" area reserved for others.
  bool isPositionAllowedFor(int colorIndex, GridPosition pos, int activeColorCount) {
    // Stage 1: Check if we are too deep in someone else's PRIMARY territory
    for (final entry in territories.entries) {
      if (entry.key == colorIndex) continue;
      
      final other = entry.value;
      final dist = pos.manhattanDistance(other.center);
      
      // If we are within 60% of their radius, we are "trespassing"
      if (dist < other.radius * 0.6) {
        return false; 
      }
    }

    return true;
  }

  /// Scores a candidate position based on distance to district center and avoidance of others.
  /// Higher score = better candidate.
  double calculateRegionScore(GridPosition pos, int colorIndex) {
    final territory = territories[colorIndex];
    if (territory == null) return 50.0; // Default if not registered yet

    double score = 100.0;

    // 1. Proximity to our own center
    final dist = pos.manhattanDistance(territory.center);
    if (dist <= territory.radius) {
      score += (territory.radius - dist) * 5.0; // Preference for staying inside
    } else {
      score -= (dist - territory.radius) * 10.0; // Penalty for "spilling over"
    }

    // 2. Avoidance of other centers (Soft boundaries)
    for (final entry in territories.entries) {
      if (entry.key == colorIndex) continue;
      final otherDist = pos.manhattanDistance(entry.value.center);
      if (otherDist < entry.value.radius) {
        score -= (entry.value.radius - otherDist) * 8.0; // Penalty for trespassing
      }
    }

    return score;
  }

  /// Updates territory center as the district grows to "drift" towards new buildings.
  void claimSector(int colorIndex, GridPosition pos, {required bool isCommercial}) {
    final territory = territories[colorIndex];
    if (territory == null) {
      registerDistrict(colorIndex, pos, isCommercial: isCommercial);
      return;
    }

    // [CRITICAL] Spacing Separation (Issue 3)
    // Only expand to commercial-scale radius if we are actually placing a destination.
    if (isCommercial) {
      territory.radius = 15.0;
    }

    // Drift the center towards the new building
    // Commercial centers don't drift as much as residential clusters
    double driftFactor = isCommercial ? 0.05 : 0.2;

    territory.center = GridPosition(
      ((territory.center.x * (1.0 - driftFactor)) + (pos.x * driftFactor)).round(),
      ((territory.center.y * (1.0 - driftFactor)) + (pos.y * driftFactor)).round(),
    );
  }
}
