import 'dart:math';
import 'package:flow_grid/game/grid_manager.dart';
import 'package:flow_grid/game/spawn_controller.dart';
import 'package:flow_grid/models/grid_cell.dart';

/// SpawnScoringService â€” Responsible for:
/// - Destination global distribution
/// - Quadrant balancing
/// - Edge avoidance scoring
/// - Row/column penalty logic
/// - District spread scoring
class SpawnScoringService {
  final GridManager gridManager;
  final SpawnController spawnController;
  final Random _random = Random();

  SpawnScoringService({
    required this.gridManager,
    required this.spawnController,
  });

  /// Scores a candidate tile for a new DESTINATION.
  /// Higher is better.
  double scoreDestination(GridPosition pos, int colorIndex, PlanningStage stage, {GridPosition? anchor}) {
    double score = 500.0;

    // 1. GLOBAL DESTINATION SEPARATION (Rule 3)
    final sep = BuildingProfile.commercial.interColorSpacing;
    for (final otherDest in gridManager.destinations) {
      final dist = pos.manhattanDistance(otherDest);
      if (dist < sep) {
        score -= (sep - dist) * 80; // Heavy penalty for proximity
      }
    }

    // 2. EDGE AVOIDANCE (Dynamic: more relaxed in emergency stages)
    final marginX = 4;
    final marginY = 3;
    final distToTop = pos.y - spawnController.minSpawnY;
    final distToBottom = spawnController.maxSpawnY - pos.y;
    final distToLeft = pos.x - spawnController.minSpawnX;
    final distToRight = spawnController.maxSpawnX - pos.x;

    // Reduce edge penalty in emergency stages to allow fallback
    double edgePenaltyMult = 1.0;
    if (stage.index >= PlanningStage.stage4StrongRelax.index) edgePenaltyMult = 0.2;

    if (distToTop < marginY) score -= (marginY - distToTop) * 30 * edgePenaltyMult;
    if (distToBottom < marginY) score -= (marginY - distToBottom) * 30 * edgePenaltyMult;
    if (distToLeft < marginX) score -= (marginX - distToLeft) * 20 * edgePenaltyMult;
    if (distToRight < marginX) score -= (marginX - distToRight) * 20 * edgePenaltyMult;

    // [FIX] Same-Color Residential Separation (Anchor-aware)
    final resCenter = anchor ?? spawnController.residentialCenters[colorIndex];
    if (resCenter != null) {
      final distToRes = pos.manhattanDistance(resCenter);
      final minDist = SpawnConfig.destinationToHouseMinDistance;
      
      if (distToRes < minDist) {
        score -= (minDist - distToRes) * 200; // VERY heavy penalty for violating minimum
      } else {
        // Distance "Sweet Spot" (Rule 1: meaningful routing)
        // [REBALANCED] Favor 16-28 range for initial spawns
        if (distToRes >= 16 && distToRes <= 28) {
          score += 250; // High bonus for strategic separation
        } else if (distToRes > 28) {
          score += 150; // Still good for long-haul routing
        }
      }

      // [FIX] Anti-Linear Spawning
      // Penalize sharing the same axis as the residential center
      if (pos.x == resCenter.x) score -= 300; 
      if (pos.y == resCenter.y) score -= 300;
    }

    // 3. TERRITORY INFLUENCE (Reworked Rule 5)
    // Higher score for being in our own territory, lower for trespassing
    score += spawnController.districtPlanner.calculateRegionScore(pos, colorIndex) * 0.5;

    // 4. ROADABILITY (Issue 2)
    final entry = spawnController.findValidEntrySide(pos);
    if (entry != null) {
      score += calculateRoadabilityScore(pos, entry);
    } else {
      score -= 200; // Hard penalty for no entry
    }

    // 5. COMMERCIAL BUFFER (Issue 4)
    // Destinations need breathing room for future complex routing
    const buffer = 5; 
    for (final otherDest in gridManager.destinations) {
      final d = pos.manhattanDistance(otherDest);
      if (d < buffer) score -= (buffer - d) * 50; // Heavy buffer penalty
      
      if (pos.x == otherDest.x) score -= 30;
      if (pos.y == otherDest.y) score -= 30;
    }

    return score;
  }

  /// Scores a candidate tile for a HOUSE.
  /// Higher is better.
  double scoreHouse(GridPosition pos, int colorIndex, GridPosition center, PlanningStage stage) {
    final dna = spawnController.dnaMap[colorIndex] ?? DistrictDNA.random(_random);
    final existingHouses = gridManager.houses
        .where((h) => gridManager.grid[h.y][h.x].colorIndex == colorIndex)
        .toList();
    
    double score = 100.0;

    // 1. DISTRICT COHESION (Issue 1)
    // Houses should cluster tightly around the residential center
    final dist = pos.manhattanDistance(center);
    if (dist < 2) {
      score -= 300; // Too close (clumping)
    } else if (dist >= 2 && dist <= 6) {
      score += 250; // Ideal neighborhood cluster
    } else if (dist > 6 && dist <= 10) {
      score += 100;  // Acceptable spread
    } else {
      score -= (dist - 10) * 30; // gentler penalty for overflow
    }
    
    // Compactness Weight
    score += (15 - dist) * dna.compactness * 15;

    // 2. TERRITORY INFLUENCE (New)
    score += spawnController.districtPlanner.calculateRegionScore(pos, colorIndex) * 0.8;

    // 3. MAP CENTER PREFERENCE (Initial Hubs)
    // If we are in very early game or placing the first house center, favor map center.
    final centerX = (spawnController.minSpawnX + spawnController.maxSpawnX) / 2;
    final centerY = (spawnController.minSpawnY + spawnController.maxSpawnY) / 2;
    final distToMapCenter = (pos.x - centerX).abs() + (pos.y - centerY).abs();
    score += (20 - distToMapCenter).clamp(0, 20) * 8.0; 

    // [FIX] Anti-Linear Spawning (Issue 2)
    final angleToPos = atan2((pos.y - center.y).toDouble(), (pos.x - center.x).toDouble());
    
    // Penalize sharing the same axis as other houses OR the destination
    final dest = spawnController.clusterCenters[colorIndex];
    if (dest != null) {
      if (pos.x == dest.x) score -= 100;
      if (pos.y == dest.y) score -= 100;
    }

    for (final house in existingHouses) {
      if (pos.x == house.x) score -= 60; // Increased to 60 for stronger staggering
      if (pos.y == house.y) score -= 60;
    }

    if (dna.preferredAngle != null) {
      double diff = (angleToPos - dna.preferredAngle!).abs();
      if (diff > pi) diff = 2 * pi - diff;
      score += (1.0 - (diff / pi)) * 80 * dna.asymmetryBias;
    }

    // [FIX] Road Density Scoring (Priority 3)
    final nearbyRoads = gridManager.countNearbyRoads(pos.x, pos.y, 3);
    score -= nearbyRoads * 10.0;

    // 4. ACCESSIBILITY & ROADABILITY (Issue 2)
    final entry = spawnController.findValidEntrySide(pos);
    if (entry != null) {
      score += calculateRoadabilityScore(pos, entry);
      score += spawnController.calculateOpennessScore(pos, entry) * 10; // Increased weight

      // Parallel alignment penalty
      for (final house in existingHouses) {
        final otherEntry = gridManager.grid[house.y][house.x].entrySide;
        if (otherEntry == entry && pos.manhattanDistance(house) < 4) {
          score -= 40; 
        }
      }
    } else {
      score -= 300;
    }

    return score;
  }

  /// [NEW] Scores a candidate for a new initial house center.
  double scoreInitialHouseCenter(GridPosition pos, int colorIndex, PlanningStage stage) {
    double score = 1000.0;

    // 1. Map Center Preference (Fill Central Gaps)
    final centerX = (spawnController.minSpawnX + spawnController.maxSpawnX) / 2;
    final centerY = (spawnController.minSpawnY + spawnController.maxSpawnY) / 2;
    final distToMapCenter = (pos.x - centerX).abs() + (pos.y - centerY).abs();
    score += (25 - distToMapCenter).clamp(0, 25) * 20.0; // Strong pull to center

    // 2. Avoid existing buildings (inter-color spacing)
    for (final building in gridManager.buildings) {
      final dist = pos.manhattanDistance(building);
      if (dist < 10) score -= (10 - dist) * 50;
    }

    // 3. Urban Center Alignment
    final urbanCenter = _calculateUrbanCenter();
    if (urbanCenter != null) {
      final distToUrban = pos.manhattanDistance(urbanCenter);
      score += (15 - distToUrban).clamp(0, 15) * 10.0;
    }

    return score;
  }

  /// Calculates a "roadability" score for an entrance (Issue 2).
  /// Penalizes dead ends, edge trapping, and corridor collisions.
  double calculateRoadabilityScore(GridPosition pos, Direction entry) {
    double score = 0;
    final driveway = pos.getNeighbor(entry);

    // 1. Entrance Corridor Check (Rule: 3 tiles forward)
    bool corridorClear = true;
    for (int i = 1; i <= 3; i++) {
      final fwd = driveway.getNeighbor(entry, count: i);
      if (!gridManager.isValid(fwd.x, fwd.y)) {
        corridorClear = false;
        break;
      }
      final cell = gridManager.grid[fwd.y][fwd.x];
      if (!cell.isEmpty && !cell.isRoad) {
        corridorClear = false;
        break;
      }
      
      if (cell.isReserved) {
        score -= 60; // Penalty for corridor collision (overlapping corridors)
      }
      
      score += 15; // Bonus for clear expansion space
    }
    
    if (!corridorClear) {
      score -= 150; // Hard penalty for blocked corridor
    }

    // 2. Turning Potential (Side branching)
    // Check if player can branch left/right from the driveway or the tile ahead
    for (int i = 0; i <= 1; i++) {
      final base = driveway.getNeighbor(entry, count: i);
      final left = base.getNeighbor(entry.rotateCCW());
      final right = base.getNeighbor(entry.rotateCW());
      
      if (gridManager.isValid(left.x, left.y) && gridManager.grid[left.y][left.x].isEmpty) score += 25;
      if (gridManager.isValid(right.x, right.y) && gridManager.grid[right.y][right.x].isEmpty) score += 25;
    }

    // 3. Proximity to map boundaries (Rule: Edge trapping)
    final padding = 4;
    if (pos.x < spawnController.minSpawnX + padding || pos.x > spawnController.maxSpawnX - padding) score -= 40;
    if (pos.y < spawnController.minSpawnY + padding || pos.y > spawnController.maxSpawnY - padding) score -= 40;

    return score;
  }

  /// Reserves a short invisible corridor ahead of a driveway (Issue 2).
  void reserveEntranceCorridor(GridPosition pos, Direction entry, {bool isDestination = false}) {
    final driveway = pos.getNeighbor(entry);
    // Destinations need longer corridors (4 tiles) for complex routing and side buffers
    final depth = isDestination ? 4 : 2;
    
    for (int i = 0; i <= depth; i++) {
      final fwd = driveway.getNeighbor(entry, count: i);
      if (gridManager.isValid(fwd.x, fwd.y)) {
        gridManager.reserveCell(fwd.x, fwd.y, true);
        
        // [NEW] Side Buffers for Destinations (Rule 2: Clearance Zone)
        if (isDestination && i > 0 && i <= 2) {
          for (final side in [entry.rotateCCW(), entry.rotateCW()]) {
            final sidePos = fwd.getNeighbor(side);
            if (gridManager.isValid(sidePos.x, sidePos.y)) {
              gridManager.reserveCell(sidePos.x, sidePos.y, true);
            }
          }
        }
      }
    }
  }



  GridPosition? _calculateUrbanCenter() {
    if (gridManager.buildings.isEmpty) return null;
    double sumX = 0;
    double sumY = 0;
    for (final b in gridManager.buildings) {
      sumX += b.x;
      sumY += b.y;
    }
    return GridPosition(
        (sumX / gridManager.buildings.length).round(), 
        (sumY / gridManager.buildings.length).round()
    );
  }
}

