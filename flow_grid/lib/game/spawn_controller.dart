import 'dart:math';
import 'package:flow_grid/game/district_name_generator.dart';
import 'package:flow_grid/game/district_planner.dart';
import 'package:flow_grid/game/grid_manager.dart';
import 'package:flow_grid/game/spawn_scoring_service.dart';
import 'package:flow_grid/models/grid_cell.dart';
import 'package:flutter/foundation.dart';

// ============================================================
// SPAWN CONFIGURATION â€” all tunable constants in one place
// ============================================================
// [NEW] Immutable Spawn Profiles (Issue: Residential/Commercial Contamination)
class BuildingProfile {
  final double influenceRadius;
  final double renderScale;
  final int sameColorSpacing;
  final int interColorSpacing;
  final int corridorLength;
  final int borderPadding;
  final int minOpenness;

  const BuildingProfile({
    required this.influenceRadius,
    required this.renderScale,
    required this.sameColorSpacing,
    required this.interColorSpacing,
    required this.corridorLength,
    required this.borderPadding,
    required this.minOpenness,
  });

  static const residential = BuildingProfile(
    influenceRadius: 6.0,
    renderScale: 0.45,
    sameColorSpacing: 4,
    interColorSpacing: 2,
    corridorLength: 2,
    borderPadding: 2,
    minOpenness: 3,
  );

  static const commercial = BuildingProfile(
    influenceRadius: 10.0, // Reduced from 15.0 for better early-game fit
    renderScale: 0.85,
    sameColorSpacing: 6,  // Reduced from 10
    interColorSpacing: 8, // Reduced from 14 (critical for 16-wide map)
    corridorLength: 2,    // Reduced from 3
    borderPadding: 2,    // Reduced from 4
    minOpenness: 4,      // Reduced from 5
  );
}

class SpawnConfig {
  /// Seconds between any two spawn actions
  static const double spawnCooldown = 15.0; // Reverted from test speed

  /// Delay before the very first spawn (lets player orient)
  static const double initialDelay = 0.5;

  /// Delay between 1st and 2nd house of a new color
  static const double secondHouseDelay = 2.0;

  /// Minimum seconds to wait after spawning a house before spawning another house of the SAME color
  static const double sameColorSpawnCooldown = 45.0; // Reverted from test speed

  /// Max houses per color before demand gating kicks in
  static const int earlyHouseCap = 2;

  /// Soft cap on how many houses a single destination can comfortably support
  static const int housesPerDestination = 3;

  /// How often to sample demand pressure (seconds)
  static const double pressureSampleInterval = 8.0;

  /// Maximum pressure value (prevents infinite runaway)
  static const int maxPressure = 12;

  /// Hard elapsed time minimums before a new color CAN unlock [Color0, Color1, Color2, ...]
  static const List<double> colorUnlockDelays = [0.0, 72.0, 240.0, 480.0, 720.0, 960.0, 1200.0];

  // ============================================================
  // [NEW] District Locality & Spacing Rules (Issue 1 & 2)
  // ============================================================
  // Sized for a Mini-Motorways style starting region (~20x14). Larger
  // separations would force the spawn planner to push buildings across the
  // whole grid, which is impossible to connect with the early road budget.
  static const int maxDistrictExpansionRadius = 14;
  static const int destinationToHouseMinDistance = 5;
  static const int destinationToDestinationMinDistance = 7;
  static const int sameColorHouseClusterRadius = 4;
}

enum SpawnNodeType { house, destination }

enum SpawnZone {
  leftTop,
  leftMid,
  leftBottom,
  rightTop,
  rightMid,
  rightBottom,
}

enum PlanningStage { 
  stage1Ideal, 
  stage2Relaxed, 
  stage3MoreRelaxed, 
  stage4StrongRelax, 
  stage5ExtremeRelax 
}

enum SpawnFailure {
  none,
  space,    // [NEW] Genuine lack of valid spawn space
  demand,   // Gated by demand pressure
  cooldown, // Gated by global or per-color cooldown
  other     // Transient errors, geometry conflicts
}

class HousePlan {
  final GridPosition pos;
  final Direction entry;
  HousePlan({required this.pos, required this.entry});
}

class DistrictPlan {
  final GridPosition destPos;
  final Direction destEntry;
  final List<HousePlan> houses;
  final GridPosition resCenter;

  DistrictPlan({
    required this.destPos,
    required this.destEntry,
    required this.houses,
    required this.resCenter,
  });

  List<GridPosition> get allSpots => [
    destPos,
    ...houses.map((h) => h.pos),
  ];
}


class SpawnRequest {
  final int colorIndex;
  final SpawnNodeType nodeType;
  final double requestTime;
  final String reason; 
  final int priority; // 10 = Unlock, 5 = House, 1 = Demand

  int retryCount = 0;
  double nextRetryTime = 0;

  SpawnRequest({
    required this.colorIndex,
    required this.nodeType,
    required this.requestTime,
    required this.reason,
    this.priority = 1,
  }) {
    nextRetryTime = requestTime;
  }

  @override
  String toString() => 'SpawnRequest($nodeType color=$colorIndex reason=$reason, retries=$retryCount)';
}

// [NEW] District DNA: Represents the "personality" of a neighborhood
class DistrictDNA {
  final double compactness;        // 0.2 (loose) to 1.0 (tight)
  final double? preferredAngle;     // null (uniform) or 0..2*pi
  final double asymmetryBias;       // 0.0 (even) to 1.0 (heavy bias)
  final double branchiness;         // preference for new angles vs following previous
  
  // Memory of previous spawn directions from center
  final List<double> spawnAngles = [];

  DistrictDNA({
    required this.compactness,
    this.preferredAngle,
    required this.asymmetryBias,
    required this.branchiness,
  });

  factory DistrictDNA.random(Random r) {
    return DistrictDNA(
      compactness: 0.4 + r.nextDouble() * 0.6,
      preferredAngle: r.nextBool() ? r.nextDouble() * 2 * pi : null,
      asymmetryBias: r.nextDouble() * 0.8,
      branchiness: r.nextDouble(),
    );
  }
}

// ============================================================
// SPAWN CONTROLLER â€” the single authority for all spawning
// ============================================================
class SpawnController {
  final Random _random;
  final GridManager gridManager;
  final DistrictPlanner districtPlanner;
  
  /// Callback when a spawn fails due to space and map should expand
  VoidCallback? onAdaptiveExpansionRequired;

  /// Tracks the reason for the last attempted (and failed) spawn
  SpawnFailure lastFailure = SpawnFailure.none;

  // Spawn bounds (set by FlowGridGame based on visible area)
  int minSpawnX = 0;
  int maxSpawnX = 16;
  int minSpawnY = 0;
  int maxSpawnY = 10;

  // State
  double _elapsedTime = 0;
  double _lastSpawnTime = -SpawnConfig.spawnCooldown; // Allow immediate first spawn
  double _pressureTimer = 0; // 1-second tick for demand sampling
  final List<SpawnRequest> _queue = [];
  final Map<int, GridPosition> clusterCenters = {};
  final Map<int, GridPosition> residentialCenters = {};
  final Map<int, DistrictDNA> dnaMap = {};
  int activeColorCount = 1;

  // Per-color tracking
  final Map<int, int> _demandPressure = {}; // sustained unmet demand counter (seconds)
  final Map<int, double> _lastSpawnTimeForColor = {}; // track pacing per color
  
  // Per-color variety tracking
  final Map<int, List<Direction>> _recentDirections = {};
  final Map<int, List<int>> _recentRows = {};
  final Map<int, List<int>> _recentCols = {};
  
  // District state
  final Map<int, SpawnZone> colorHomeZones = {};
  final Map<int, List<SpawnZone>> colorAllowedHouseZones = {};
  final Map<int, List<SpawnZone>> colorAllowedDestZones = {};

  // Callback: notify game when a spawn succeeds so it can markDirty etc.
  void Function(String message)? onLog;
  void Function()? onSpawnComplete;
  /// Fires once for each building (house or destination) the controller
  /// places, so the renderer can register a spawn-pulse animation at that
  /// cell. Distinct from [onSpawnComplete] which fires once per logical
  /// spawn event (and may batch multiple buildings).
  void Function(GridPosition pos)? onBuildingSpawned;

  SpawnController({
    required this.gridManager,
    required this.districtPlanner,
    Random? random,
  }) : _random = random ?? Random();

  late SpawnScoringService scoringService;

  void initializeScoring() {
    scoringService = SpawnScoringService(gridManager: gridManager, spawnController: this);
  }

  // ============================================================
  // PUBLIC API
  // ============================================================

  /// Called every frame from FlowGridGame.update()
  void update(double dt) {
    _elapsedTime += dt;
    _pressureTimer += dt;

    if (_pressureTimer >= SpawnConfig.pressureSampleInterval) {
      _pressureTimer -= SpawnConfig.pressureSampleInterval;
      _updateDemandPressure();
    }

    _processStagedInitialDistrict();
    _maybeEnqueueDemandDrivenHouse();
    _processQueue();
  }

  /// Reset all state for a new game
  void reset() {
    _elapsedTime = 0;
    _pressureTimer = 0;
    _lastSpawnTime = -SpawnConfig.spawnCooldown;
    _queue.clear();
    clusterCenters.clear();
    residentialCenters.clear();
    _demandPressure.clear();
    _lastSpawnTimeForColor.clear();
    activeColorCount = 1;
    _stagedInitialPlan = null;
    _stagedInitialColor = null;
    _stagedDestSpawnAt = null;
    _stagedHouse2SpawnAt = null;
  }

  // ============================================================
  // STAGED INITIAL DISTRICT
  // The first district is committed in three beats instead of all at once
  // (house → +2s destination → +5s second house) so the player gets a moment
  // to register what's appearing instead of three buildings popping in
  // simultaneously. Positions are still planned atomically up front so we
  // never strand a house without a matching destination.
  // ============================================================
  DistrictPlan? _stagedInitialPlan;
  int? _stagedInitialColor;
  double? _stagedDestSpawnAt;
  double? _stagedHouse2SpawnAt;

  static const double _stagedDestDelay = 2.0;
  static const double _stagedHouse2Delay = 5.0;

  void _processStagedInitialDistrict() {
    final plan = _stagedInitialPlan;
    final ci = _stagedInitialColor;
    if (plan == null || ci == null) return;

    if (_stagedDestSpawnAt != null && _elapsedTime >= _stagedDestSpawnAt!) {
      _stagedDestSpawnAt = null;
      gridManager.commitPlacement(() => _placeStagedDestination(ci, plan));
      onSpawnComplete?.call();
    }

    if (_stagedHouse2SpawnAt != null && _elapsedTime >= _stagedHouse2SpawnAt!) {
      _stagedHouse2SpawnAt = null;
      if (plan.houses.length >= 2) {
        gridManager.commitPlacement(() => _placeStagedSecondHouse(ci, plan));
        onSpawnComplete?.call();
      }
      // Clear the slot — staging is complete regardless of whether house 2
      // was in the plan, so the next initial-district request can start fresh.
      _stagedInitialPlan = null;
      _stagedInitialColor = null;
    }
  }

  void _placeStagedDestination(int colorIndex, DistrictPlan plan) {
    if (!gridManager.isValid(plan.destPos.x, plan.destPos.y)) return;
    if (!gridManager.grid[plan.destPos.y][plan.destPos.x].isEmpty) {
      _log('STAGED DEST: dest spot ${plan.destPos} no longer empty; skipping');
      return;
    }
    final profile = districtPlanner.getProfileFor(colorIndex);
    final name = DistrictNameGenerator.generate(profile.type);
    gridManager.placeDestination(plan.destPos.x, plan.destPos.y, colorIndex, plan.destEntry, name: name);
    onBuildingSpawned?.call(plan.destPos);
    scoringService.reserveEntranceCorridor(plan.destPos, plan.destEntry, isDestination: true);
    final dDP = plan.destPos.getNeighbor(plan.destEntry);
    gridManager.placeRoad(dDP.x, dDP.y, owner: InfrastructureOwner.systemGenerated);
    gridManager.connectBuilding(plan.destPos.x, plan.destPos.y, dDP.x, dDP.y);
    districtPlanner.claimSector(colorIndex, plan.destPos, isCommercial: true);
    _log('STAGED DEST PLACED: Color $colorIndex at ${plan.destPos}');
  }

  void _placeStagedSecondHouse(int colorIndex, DistrictPlan plan) {
    final hPlan = plan.houses[1];
    if (!gridManager.isValid(hPlan.pos.x, hPlan.pos.y)) return;
    if (!gridManager.grid[hPlan.pos.y][hPlan.pos.x].isEmpty) {
      _log('STAGED HOUSE 2: spot ${hPlan.pos} no longer empty; skipping');
      return;
    }
    gridManager.placeHouse(hPlan.pos.x, hPlan.pos.y, colorIndex, hPlan.entry);
    onBuildingSpawned?.call(hPlan.pos);
    scoringService.reserveEntranceCorridor(hPlan.pos, hPlan.entry, isDestination: false);
    final hDP = hPlan.pos.getNeighbor(hPlan.entry);
    gridManager.placeRoad(hDP.x, hDP.y, owner: InfrastructureOwner.systemGenerated);
    gridManager.connectBuilding(hPlan.pos.x, hPlan.pos.y, hDP.x, hDP.y);
    districtPlanner.claimSector(colorIndex, hPlan.pos, isCommercial: false);
    _log('STAGED HOUSE 2 PLACED: Color $colorIndex at ${hPlan.pos}');
  }

  /// ATOMIC TRANSACTION: Spawn a new district (1 Destination + 2 Houses)
  /// Returns true if the entire district was successfully placed.
  bool spawnInitialPair(int colorIndex) {
    _log('ATOMIC DISTRICT REQUEST: Color $colorIndex');

    for (final stage in PlanningStage.values) {
      _log('PLANNER: Attempting Stage ${stage.index + 1} (${stage.name}) for Color $colorIndex');
      
      // 1. Find Residential Center First (Favor Central Gaps)
      final resCenter = _findInitialHouseCenter(colorIndex, stage: stage);
      if (resCenter == null) continue;

      // 2. Find Destination (Separate search, wider radii, separation from resCenter)
      final destPos = _findDestinationSpot(colorIndex, stage: stage, anchor: resCenter);
      if (destPos == null) continue;
      
      final destEntry = findValidEntrySide(destPos, profile: BuildingProfile.commercial, stage: stage);
      if (destEntry == null) continue;
      
      // 3. FIND NEARBY HOUSES (Complete with entries)
      final housePlans = _findNearbyHouseSpots(colorIndex, resCenter, stage: stage, avoidDest: destPos);
      
      if (housePlans.isEmpty) continue;

      // 4. Create Plan & Commit
      final plan = DistrictPlan(
        destPos: destPos,
        destEntry: destEntry,
        houses: housePlans,
        resCenter: resCenter,
      );

      _commitInitialDistrict(colorIndex, plan);
      return true;
    }

    _log('ATOMIC DISTRICT FAILED: Color $colorIndex could not be placed even in Emergency mode.');
    lastFailure = SpawnFailure.space;
    onAdaptiveExpansionRequired?.call();
    return false;
  }

  List<HousePlan> _findNearbyHouseSpots(int colorIndex, GridPosition center, {required PlanningStage stage, GridPosition? avoidDest}) {
    final candidates = <GridPosition>[];
    double minDist = 1.0;
    double maxDist = 8.0;

    if (stage.index >= PlanningStage.stage5ExtremeRelax.index) maxDist = 12.0;

    for (int y = minSpawnY; y <= maxSpawnY; y++) {
      for (int x = minSpawnX; x <= maxSpawnX; x++) {
        final pos = GridPosition(x, y);
        final d = pos.manhattanDistance(center);
        if (d < minDist || d > maxDist) continue;
        
        // Avoid pending destination during district generation
        if (avoidDest != null && pos.manhattanDistance(avoidDest) < SpawnConfig.destinationToHouseMinDistance) {
          if (stage.index < PlanningStage.stage5ExtremeRelax.index) continue;
        }

        if (!_validateSpawnTile(pos, colorIndex, stage: stage, nodeType: SpawnNodeType.house)) continue;
        candidates.add(pos);
      }
    }

    if (candidates.isEmpty) return [];

    // Sort by score using SpawnScoringService
    candidates.sort((a, b) {
      final sA = scoringService.scoreHouse(a, colorIndex, center, stage);
      final sB = scoringService.scoreHouse(b, colorIndex, center, stage);
      return sB.compareTo(sA);
    });

    // Pick best spots that HAVE valid entry sides
    final result = <HousePlan>[];
    for (final pos in candidates) {
      final entry = findValidEntrySide(pos, profile: BuildingProfile.residential, stage: stage);
      if (entry == null) continue;

      bool tooClose = false;
      for (final r in result) {
        if (pos.manhattanDistance(r.pos) < 2) {
          tooClose = true;
          break;
        }
      }
      if (!tooClose) {
        result.add(HousePlan(pos: pos, entry: entry));
        if (result.length >= 2) break;
      }
    }

    return result;
  }

  void _commitInitialDistrict(int colorIndex, DistrictPlan plan) {
    gridManager.commitPlacement(() => _doCommitInitialDistrict(colorIndex, plan));
  }

  void _doCommitInitialDistrict(int colorIndex, DistrictPlan plan) {
    // 1. ATOMIC VALIDATION (Ghost Reservation check)
    // Validate ALL spots up front even though we'll commit them in stages —
    // we don't want to lay down house 1 only to discover the destination
    // spot got taken by something else in the meantime.
    for (final spot in plan.allSpots) {
      if (!gridManager.isValid(spot.x, spot.y) || !gridManager.grid[spot.y][spot.x].isEmpty) {
        _log('INITIAL DISTRICT ATOMIC FAIL: Spot $spot became occupied. Aborting all.');
        return;
      }
    }

    if (plan.houses.isEmpty) {
      _log('INITIAL DISTRICT FAIL: plan has no houses');
      return;
    }

    // 2. Commit ONLY the first house immediately. The destination and the
    //    second house are scheduled via _processStagedInitialDistrict so the
    //    player sees them appear one at a time:
    //      t=0  : house 1
    //      t=+2 : destination
    //      t=+5 : house 2
    final h1 = plan.houses.first;
    _log('[VALIDATE] type=HOUSE reservation=${BuildingProfile.residential.corridorLength} influence=${BuildingProfile.residential.influenceRadius}');
    gridManager.placeHouse(h1.pos.x, h1.pos.y, colorIndex, h1.entry);
    onBuildingSpawned?.call(h1.pos);
    assert(gridManager.grid[h1.pos.y][h1.pos.x].isHouse, 'CRITICAL: Position ${h1.pos} must be a HOUSE');
    scoringService.reserveEntranceCorridor(h1.pos, h1.entry, isDestination: false);
    final h1DP = h1.pos.getNeighbor(h1.entry);
    gridManager.placeRoad(h1DP.x, h1DP.y, owner: InfrastructureOwner.systemGenerated);
    gridManager.connectBuilding(h1.pos.x, h1.pos.y, h1DP.x, h1DP.y);
    districtPlanner.claimSector(colorIndex, h1.pos, isCommercial: false);

    // 3. State setup — done immediately so subsequent spawn logic knows about
    //    this color even before the destination and second house land.
    clusterCenters[colorIndex] = plan.destPos;
    residentialCenters[colorIndex] = plan.resCenter;

    final houseZone = _getZoneAt(plan.resCenter.x, plan.resCenter.y);
    colorHomeZones[colorIndex] = houseZone;
    colorAllowedHouseZones[colorIndex] = [houseZone];

    final destZone = _getZoneAt(plan.destPos.x, plan.destPos.y);
    colorAllowedDestZones[colorIndex] = [destZone];
    dnaMap[colorIndex] = DistrictDNA.random(_random);

    // 4. Schedule the remaining commits.
    _stagedInitialPlan = plan;
    _stagedInitialColor = colorIndex;
    _stagedDestSpawnAt = _elapsedTime + _stagedDestDelay;
    _stagedHouse2SpawnAt = plan.houses.length >= 2
        ? _elapsedTime + _stagedHouse2Delay
        : null;

    _log('INITIAL DISTRICT STAGE 1 COMMITTED: Color $colorIndex. House at ${h1.pos}; dest @+${_stagedDestDelay}s, house 2 @+${_stagedHouse2Delay}s.');
    onSpawnComplete?.call();
  }

  /// [NEW] Reactive Spawning (Part 2): Adds a single house to reinforce a color
  bool spawnExtraHouse(int colorIndex) {
    _log('EXTRA HOUSE REQUEST: Color $colorIndex');
    
    // Stage 1: Find an existing hub to reinforce
    final existingHub = residentialCenters[colorIndex];
    if (existingHub != null) {
      for (final stage in PlanningStage.values) {
        final housePlans = _findNearbyHouseSpots(colorIndex, existingHub, stage: stage);
        if (housePlans.isNotEmpty) {
          final hPlan = housePlans.first;
          _commitHouse(colorIndex, hPlan.pos, hPlan.entry);
          _log('EXTRA HOUSE COMMITTED: Reinforced existing cluster for Color $colorIndex at ${hPlan.pos}');
          onSpawnComplete?.call();
          return true;
        }
      }
    }
    
    // Stage 2: Fallback to a completely new central location
    final newCenter = _findInitialHouseCenter(colorIndex, stage: PlanningStage.stage3MoreRelaxed);
    if (newCenter != null) {
      final housePlans = _findNearbyHouseSpots(colorIndex, newCenter, stage: PlanningStage.stage3MoreRelaxed);
      if (housePlans.isNotEmpty) {
        final hPlan = housePlans.first;
        _commitHouse(colorIndex, hPlan.pos, hPlan.entry);
        _log('EXTRA HOUSE COMMITTED: New hub created for Color $colorIndex at ${hPlan.pos}');
        onSpawnComplete?.call();
        return true;
      }
    }
    
    return false;
  }

  void _commitHouse(int colorIndex, GridPosition pos, Direction entry) {
    gridManager.commitPlacement(() => _doCommitHouse(colorIndex, pos, entry));
  }

  void _doCommitHouse(int colorIndex, GridPosition pos, Direction entry) {
    _log('[SPAWN] Placing HOUSE for Color $colorIndex at ${pos.key}');
    gridManager.placeHouse(pos.x, pos.y, colorIndex, entry);
    onBuildingSpawned?.call(pos);

    assert(gridManager.grid[pos.y][pos.x].isHouse, 'CRITICAL: Position $pos must be a HOUSE');
    
    scoringService.reserveEntranceCorridor(pos, entry, isDestination: false);
    final hDP = pos.getNeighbor(entry);
    gridManager.placeRoad(hDP.x, hDP.y, owner: InfrastructureOwner.systemGenerated);
    gridManager.connectBuilding(pos.x, pos.y, hDP.x, hDP.y);
    districtPlanner.claimSector(colorIndex, pos, isCommercial: false);
  }





  /// Escalation: Trigger faster demand growth for older colors
  void escalateDistricts(int currentWeek) {
    _log('ESCALATION: Increasing pressure on districts older than 1 week');
    for (int c = 0; c < activeColorCount; c++) {
      _demandPressure[c] = (_demandPressure[c] ?? 0) + 2;
    }
  }

  /// ATOMIC EXPANSION PACKAGE: 1 new destination + 2 new houses
  /// in a DIFFERENT cluster/zone than the color's existing buildings.
  /// Returns true only if ALL 3 parts succeed. Rolls back on failure.
  bool spawnExpansionPackage(int colorIndex) {
    _log('EXPANSION PACKAGE REQUEST: Color $colorIndex');

    for (final stage in PlanningStage.values) {
      _log('EXPANSION PLANNER: Attempting Stage ${stage.index + 1} (${stage.name}) for Color $colorIndex');
      
      final existingCenter = clusterCenters[colorIndex];
      final homeZone = colorHomeZones[colorIndex];
      final candidateZones = SpawnZone.values.where((z) => z != homeZone).toList();
      candidateZones.shuffle(_random);

      for (final targetZone in candidateZones) {
        // [NEW] District Center Offsetting
        final offsetX = (_random.nextInt(11) - 5); // Increased range
        final offsetY = (_random.nextInt(11) - 5);
        
        final plan = _tryExpansionInZone(colorIndex, targetZone, existingCenter, stage: stage, offsetX: offsetX, offsetY: offsetY);
        if (plan != null) {
          // Dynamic Territory Growth
          districtPlanner.expandTerritory(colorIndex, amount: 6.0);
          
          _commitExpansion(colorIndex, plan, targetZone);
          _log('EXPANSION PACKAGE COMMITTED: Color $colorIndex expanded territory into $targetZone');
          return true;
        }
      }
    }

    _log('EXPANSION PACKAGE FAILED: No valid expansion found for Color $colorIndex even at Stage 5');
    lastFailure = SpawnFailure.space;
    onAdaptiveExpansionRequired?.call();
    return false;
  }

  /// Ensures minimum distance from the existing cluster center and applies optional offset.
  DistrictPlan? _tryExpansionInZone(int colorIndex, SpawnZone targetZone, GridPosition? existingCenter, {required PlanningStage stage, int offsetX = 0, int offsetY = 0}) {
    // [FIX] Destination Separation (Issue 1)
    // Minimum distance from existing color cluster center (source or destination)
    double minDistFromExisting = 14.0; 
    if (stage.index >= PlanningStage.stage3MoreRelaxed.index) minDistFromExisting = 10.0;
    if (stage.index >= PlanningStage.stage5ExtremeRelax.index) minDistFromExisting = 6.0;

    // Find destination candidates globally
    final destCandidates = <GridPosition>[];
    for (int y = minSpawnY; y <= maxSpawnY; y++) {
      for (int x = minSpawnX; x <= maxSpawnX; x++) {
        final pos = GridPosition(x, y);

        // Soft zone preference: prefer the target zone but don't hard-lock
        final zone = _getZoneAt(x, y);
        if (zone != targetZone && stage.index < PlanningStage.stage3MoreRelaxed.index) continue;      // [FIX] Anti-Linear Spawning (Issue 2)
      // Destination should NOT be on the same axis as the existing cluster
      if (stage.index < PlanningStage.stage4StrongRelax.index && existingCenter != null) {
        if (pos.x == existingCenter.x || pos.y == existingCenter.y) continue;
      }

        if (existingCenter != null && pos.manhattanDistance(existingCenter) < minDistFromExisting) continue;

        if (!_validateSpawnTile(pos, colorIndex, stage: stage, nodeType: SpawnNodeType.destination)) continue;
        destCandidates.add(pos);
      }
    }

    if (destCandidates.isEmpty) return null;
    
    // Score destination candidates globally (Rule 3)
    destCandidates.sort((a, b) {
      final sA = scoringService.scoreDestination(a, colorIndex, stage);
      final sB = scoringService.scoreDestination(b, colorIndex, stage);
      return sB.compareTo(sA);
    });

    for (final destPos in destCandidates.take(8)) {
      final destEntry = findValidEntrySide(destPos, profile: BuildingProfile.commercial, stage: stage);
      if (destEntry == null) continue;

      // [NEW] Find Residential Center for the expansion
      final resCenter = _findResidentialCenter(destPos, colorIndex, stage: stage);
      if (resCenter == null && stage.index < PlanningStage.stage4StrongRelax.index) continue;

      // Find house candidates near the NEW residential center
      final housePlans = _findNearbyHouseSpots(colorIndex, resCenter ?? destPos, stage: stage, avoidDest: destPos);
      
      // [FIX] Atomic Expansion (Issue 2): Always require 2 houses for a matured color expansion
      if (housePlans.length < 2) continue; 

      return DistrictPlan(
        destPos: destPos,
        destEntry: destEntry,
        houses: housePlans,
        resCenter: resCenter ?? housePlans.first.pos,
      );
    }

    return null;
  }

  /// Commits an expansion plan (all-or-nothing, already validated)
  void _commitExpansion(int colorIndex, DistrictPlan plan, SpawnZone zone) {
    gridManager.commitPlacement(() => _doCommitExpansion(colorIndex, plan, zone));
  }

  void _doCommitExpansion(int colorIndex, DistrictPlan plan, SpawnZone zone) {
    // 1. ATOMIC VALIDATION (Ghost Reservation check)
    // Ensure all target cells are still empty/valid before committing
    for (final spot in plan.allSpots) {
      if (!gridManager.isValid(spot.x, spot.y) || !gridManager.grid[spot.y][spot.x].isEmpty) {
        _log('EXPANSION ATOMIC FAIL: Spot $spot became occupied. Aborting all.');
        return;
      }
    }

    // 2. Destination
    _log('[VALIDATE] type=DESTINATION reservation=${BuildingProfile.commercial.corridorLength} influence=${BuildingProfile.commercial.influenceRadius}');
    final profile = districtPlanner.getProfileFor(colorIndex);
    final name = DistrictNameGenerator.generate(profile.type);
    gridManager.placeDestination(plan.destPos.x, plan.destPos.y, colorIndex, plan.destEntry, name: name);
    onBuildingSpawned?.call(plan.destPos);
    scoringService.reserveEntranceCorridor(plan.destPos, plan.destEntry, isDestination: true);
    final dDP = plan.destPos.getNeighbor(plan.destEntry);
    gridManager.placeRoad(dDP.x, dDP.y, owner: InfrastructureOwner.systemGenerated);
    gridManager.connectBuilding(plan.destPos.x, plan.destPos.y, dDP.x, dDP.y);
    districtPlanner.claimSector(colorIndex, plan.destPos, isCommercial: true);

    // 3. Houses
    for (final hPlan in plan.houses) {
      _log('[VALIDATE] type=HOUSE reservation=${BuildingProfile.residential.corridorLength} influence=${BuildingProfile.residential.influenceRadius}');
      gridManager.placeHouse(hPlan.pos.x, hPlan.pos.y, colorIndex, hPlan.entry);
      onBuildingSpawned?.call(hPlan.pos);

      // HARD ASSERTION
      assert(gridManager.grid[hPlan.pos.y][hPlan.pos.x].isHouse, 'CRITICAL: Position ${hPlan.pos} must be a HOUSE');
      
      scoringService.reserveEntranceCorridor(hPlan.pos, hPlan.entry, isDestination: false);
      final hDP = hPlan.pos.getNeighbor(hPlan.entry);
      gridManager.placeRoad(hDP.x, hDP.y, owner: InfrastructureOwner.systemGenerated);
      gridManager.connectBuilding(hPlan.pos.x, hPlan.pos.y, hDP.x, hDP.y);
      districtPlanner.claimSector(colorIndex, hPlan.pos, isCommercial: false);
    }

    // 4. State setup
    if (!colorAllowedHouseZones[colorIndex]!.contains(zone)) {
      colorAllowedHouseZones[colorIndex]!.add(zone);
    }
    if (!colorAllowedDestZones[colorIndex]!.contains(zone)) {
      colorAllowedDestZones[colorIndex]!.add(zone);
    }

    _log('EXPANSION PACKAGE COMMITTED: Color $colorIndex. New Dest at ${plan.destPos}.');
    onSpawnComplete?.call();
  }

  /// Request a spawn through the queue (the ONLY way gameplay code should spawn)
  void requestSpawn(int colorIndex, SpawnNodeType nodeType, String reason) {
    final req = SpawnRequest(
      colorIndex: colorIndex,
      nodeType: nodeType,
      requestTime: _elapsedTime,
      reason: reason,
    );
    _queue.add(req);
    _log('QUEUED: $req');
  }

  /// Get the number of houses for a color
  int getHouseCount(int colorIndex) {
    return gridManager.getHousesForColor(colorIndex).length;
  }

  /// Highest weekly-transition age among this color's destinations. age == 0
  /// for a destination that hasn't survived a weekly transition yet, == 1
  /// after one transition, etc. Used to gate demand-driven extra houses so a
  /// newly spawned destination can't push past the initial pair until it has
  /// actually aged.
  int _maxDestinationAgeForColor(int colorIndex) {
    int maxAge = 0;
    final dests = gridManager.getDestinationsForColor(colorIndex);
    for (final dest in dests) {
      final age = gridManager.destinationAges['${dest.x},${dest.y}'] ?? 0;
      if (age > maxAge) maxAge = age;
    }
    return maxAge;
  }

  /// Minimum age (in weekly transitions) a color's oldest destination must
  /// have before demand pressure can push the house count past
  /// [SpawnConfig.earlyHouseCap]. Two means the destination has survived two
  /// weekly transitions — i.e. it is "more than 1 week old" — matching the
  /// player-facing rule that 1-week-old destinations stay capped at 2 houses.
  static const int _minDestAgeForExtraHouse = 2;

  /// Get current queue depth (for debugging)
  int get queueDepth => _queue.length;

  // ============================================================
  // SCHEDULER â€” one spawn per cooldown, no exceptions
  // ============================================================

  void _processQueue() {
    lastFailure = SpawnFailure.none;
    if (_queue.isEmpty) return;

    // RULE 1: Global spawn cooldown
    if (_elapsedTime - _lastSpawnTime < SpawnConfig.spawnCooldown) return;

    // RULE 2: Sort by Priority (Unlocks first)
    _queue.sort((a, b) => b.priority.compareTo(a.priority));

    // RULE 3: SNAPSHOT ITERATION
    // We only process requests that were already in the queue and aren't on backoff
    final candidates = _queue.where((req) => _elapsedTime >= req.nextRetryTime).toList();
    if (candidates.isEmpty) return;

    final request = candidates.first;
    bool success = false;

    if (request.nodeType == SpawnNodeType.house) {
      success = _processHouseSpawn(request);
    } else {
      success = _processDestinationSpawn(request);
    }

    if (success) {
      _queue.remove(request);
      _lastSpawnTime = _elapsedTime;
      onSpawnComplete?.call();
    } else {
      // RULE 4: BACKOFF SYSTEM
      request.retryCount++;
      if (request.retryCount > 5) {
        _log('SPAWN DISCARDED: Too many failures for $request');
        _queue.remove(request);
      } else {
        // Exponential backoff: 5s, 10s, 20s, 40s...
        final delay = 5.0 * pow(2, request.retryCount - 1);
        request.nextRetryTime = _elapsedTime + delay;
        _log('SPAWN FAILED: Backing off $request for ${delay}s');
      }
    }
  }

  // ============================================================
  // HOUSE SPAWN PROCESSOR
  // ============================================================

  bool _processHouseSpawn(SpawnRequest request) {
    final colorIndex = request.colorIndex;
    final houseCount = getHouseCount(colorIndex);

    // DEMAND GATE: Don't exceed early cap unless demand justifies it
    if (houseCount >= SpawnConfig.earlyHouseCap) {
      // Per-destination age gate: backstop the same rule from
      // _maybeEnqueueDemandDrivenHouse so any request that slipped into the
      // queue still gets refused if the color's oldest destination hasn't
      // aged past the threshold.
      final destAge = _maxDestinationAgeForColor(colorIndex);
      if (destAge < _minDestAgeForExtraHouse) {
        _log('HOUSE REJECTED: Color $colorIndex has $houseCount houses; '
            'oldest destination age=$destAge < $_minDestAgeForExtraHouse, '
            'cap holds at ${SpawnConfig.earlyHouseCap}.');
        lastFailure = SpawnFailure.demand;
        return false;
      }
      final pressure = _demandPressure[colorIndex] ?? 0; // Non-linear threshold scaling for expansion (values in samples, e.g. 5 samples = 15s)
      int requiredPressure = 5; // default for 3rd house (15s)
      if (houseCount == 3) requiredPressure = 8; // 4th house (24s)
      if (houseCount >= 4) requiredPressure = 10; // 5th+ house (30s)

      if (pressure < requiredPressure) {
        _log('HOUSE REJECTED: Color $colorIndex has $houseCount houses, '
            'demand pressure=$pressure < threshold=$requiredPressure');
        lastFailure = SpawnFailure.demand;
        return false; // Don't re-queue — demand gate blocks until pressure rises
      }
      _log('HOUSE ALLOWED: Demand pressure=$pressure justifies house #${houseCount + 1} for Color $colorIndex');
    }

    // Find a valid tile (Try stages 1-5)
    GridPosition? pos;
    PlanningStage finalStage = PlanningStage.stage1Ideal;

    for (final stage in PlanningStage.values) {
      _log('PLANNER: Attempting Incremental House for Color $colorIndex at Stage ${stage.index + 1} (${stage.name})');
      
      final center = residentialCenters[colorIndex] ?? clusterCenters[colorIndex];
      pos = _findHouseSpot(colorIndex, isFirstHouse: false, stage: stage, center: center);
      
      if (pos != null) {
        finalStage = stage;
        _log('PLANNER: Success at Stage ${stage.index + 1} for Color $colorIndex at $pos');
        break;
      }
    }

    if (pos == null) {
      _log('HOUSE REJECTED: No valid tile for Color $colorIndex even at Stage 5');
      lastFailure = SpawnFailure.space;
      onAdaptiveExpansionRequired?.call();
      return false;
    }

    // [NEW] Local Density Cap (Skip if Stage 4+)
    if (finalStage.index < PlanningStage.stage4StrongRelax.index) {
      int nearbyHouses = 0;
      for (final house in gridManager.houses) {
        if (gridManager.grid[house.y][house.x].colorIndex == colorIndex) {
          if (pos.manhattanDistance(house) <= 3) {
            nearbyHouses++;
          }
        }
      }
      if (nearbyHouses >= 4) {
        _log('HOUSE REJECTED: Local density cap reached for Color $colorIndex at $pos');
        lastFailure = SpawnFailure.other; // Temporary conflict
        return false;
      }
    }

    // Validate
    final entry = findValidEntrySide(pos, profile: BuildingProfile.residential, stage: finalStage);
    if (entry == null) {
      _log('HOUSE REJECTED: No entry side at $pos');
      return false;
    }

    // Hard Type Validation (Issue: Scale Contamination)
    assert(request.nodeType == SpawnNodeType.house, 'House spawn requested but nodeType is ${request.nodeType}');
    final profile = BuildingProfile.residential;
    _log('[VALIDATE] type=HOUSE reservation=${profile.corridorLength} influence=${profile.influenceRadius}');

    // Place
    gridManager.placeHouse(pos.x, pos.y, colorIndex, entry);
    onBuildingSpawned?.call(pos);

    // HARD ASSERTION (Issue 3: Role Contamination)
    assert(gridManager.grid[pos.y][pos.x].isHouse, 'CRITICAL: Position $pos must be a HOUSE');

    scoringService.reserveEntranceCorridor(pos, entry, isDestination: false);
    final drivewayPos = pos.getNeighbor(entry);
    gridManager.placeRoad(drivewayPos.x, drivewayPos.y, owner: InfrastructureOwner.systemGenerated);
    gridManager.connectBuilding(pos.x, pos.y, drivewayPos.x, drivewayPos.y);
    districtPlanner.claimSector(colorIndex, pos, isCommercial: false);
    _lastSpawnTimeForColor[colorIndex] = _elapsedTime;

    // [NEW] Update DNA memory to influence future expansion
    final dna = dnaMap[colorIndex];
    final center = residentialCenters[colorIndex] ?? clusterCenters[colorIndex];
    if (dna != null && center != null) {
      final angle = atan2((pos.y - center.y).toDouble(), (pos.x - center.x).toDouble());
      dna.spawnAngles.add(angle);
      if (dna.spawnAngles.length > 5) dna.spawnAngles.removeAt(0);
    }

    _log('HOUSE PLACED: Color $colorIndex House #${houseCount + 1} at $pos with $entry driveway at $drivewayPos');

    // [NEW] Update Global Variety Memory
    _recentDirections.putIfAbsent(colorIndex, () => []).add(entry);
    if (_recentDirections[colorIndex]!.length > 4) _recentDirections[colorIndex]!.removeAt(0);
    
    _recentRows.putIfAbsent(colorIndex, () => []).add(pos.y);
    if (_recentRows[colorIndex]!.length > 4) _recentRows[colorIndex]!.removeAt(0);
    
    _recentCols.putIfAbsent(colorIndex, () => []).add(pos.x);
    if (_recentCols[colorIndex]!.length > 4) _recentCols[colorIndex]!.removeAt(0);

    // Reset demand pressure after satisfying it to provide total immediate relief
    if (houseCount >= SpawnConfig.earlyHouseCap) {
      _demandPressure[colorIndex] = 0;
    }

    return true;
  }

  // ============================================================
  // DESTINATION SPAWN PROCESSOR
  // ============================================================

  bool _processDestinationSpawn(SpawnRequest request) {
    final colorIndex = request.colorIndex;

    GridPosition? pos;
    PlanningStage finalStage = PlanningStage.stage1Ideal;
    for (final stage in PlanningStage.values) {
      _log('PLANNER: Attempting Incremental Dest for Color $colorIndex at Stage ${stage.index + 1} (${stage.name})');
      pos = _findDestinationSpot(colorIndex, stage: stage);
      if (pos != null) {
        _log('PLANNER: Success at Stage ${stage.index + 1} for Color $colorIndex at $pos');
        finalStage = stage;
        break;
      }
    }

    if (pos == null) {
      _log('DEST REJECTED: No valid tile for Color $colorIndex even at Stage 5');
      lastFailure = SpawnFailure.space;
      onAdaptiveExpansionRequired?.call();
      return false;
    }

    final entry = findValidEntrySide(pos, profile: BuildingProfile.commercial, stage: finalStage);
    if (entry == null) {
      _log('DEST REJECTED: No entry side at $pos');
      lastFailure = SpawnFailure.space; // Effectively space limit
      onAdaptiveExpansionRequired?.call();
      return false;
    }

    // Hard Type Validation (Issue: Scale Contamination)
    assert(request.nodeType == SpawnNodeType.destination, 'Destination spawn requested but nodeType is ${request.nodeType}');
    final profile = BuildingProfile.commercial;
    _log('[VALIDATE] type=DESTINATION reservation=${profile.corridorLength} influence=${profile.influenceRadius}');

    final districtProfile = districtPlanner.getProfileFor(colorIndex);
    final name = DistrictNameGenerator.generate(districtProfile.type);
    gridManager.placeDestination(pos.x, pos.y, colorIndex, entry, name: name);
    onBuildingSpawned?.call(pos);

    // HARD ASSERTION (Issue 3: Role Contamination)
    assert(gridManager.grid[pos.y][pos.x].isDestination, 'CRITICAL: Position $pos must be a DESTINATION');

    scoringService.reserveEntranceCorridor(pos, entry, isDestination: true);
    districtPlanner.claimSector(colorIndex, pos, isCommercial: true);
    
    // Destination driveway — systemGenerated so it doesn't consume the
    // player's road inventory.
    final drivewayPos = pos.getNeighbor(entry);
    gridManager.placeRoad(drivewayPos.x, drivewayPos.y, owner: InfrastructureOwner.systemGenerated);
    gridManager.connectBuilding(pos.x, pos.y, drivewayPos.x, drivewayPos.y);

    _log('DEST PLACED: Color $colorIndex at $pos with driveway at $drivewayPos');
    return true;
  }

  // ============================================================
  // POSITION SOLVER â€” cluster-aware, geography-aware
  // ============================================================

  GridPosition? _findHouseSpot(int colorIndex, {required bool isFirstHouse, required PlanningStage stage, GridPosition? center}) {
    if (isFirstHouse) {
      return _findSpotInZones(colorAllowedHouseZones[colorIndex]!, colorIndex, stage: stage, nodeType: SpawnNodeType.house);
    }

    center ??= residentialCenters[colorIndex] ?? clusterCenters[colorIndex];
    if (center == null) {
      return _findSpotInZones(colorAllowedHouseZones[colorIndex]!, colorIndex, stage: stage, nodeType: SpawnNodeType.house);
    }

    // [NEW] Search within a wider neighborhood radius to allow spread
    final candidates = <GridPosition>[];
    final zones = colorAllowedHouseZones[colorIndex]!;

    int radius = 15; // Max cluster search radius
    if (stage.index >= PlanningStage.stage3MoreRelaxed.index) radius += 5;

    for (int dy = -radius; dy <= radius; dy++) {
      for (int dx = -radius; dx <= radius; dx++) {
        final x = center.x + dx;
        final y = center.y + dy;
        if (!gridManager.isValid(x, y)) continue;
        if (!zones.contains(_getZoneAt(x, y))) continue;

        final pos = GridPosition(x, y);
        final dist = pos.manhattanDistance(center);
        
        if (stage.index < PlanningStage.stage3MoreRelaxed.index) {
           if (dist < 2.0 || dist > radius) continue; // Tighter cluster for houses
        }

        if (!_validateSpawnTile(pos, colorIndex, stage: stage, nodeType: SpawnNodeType.house)) continue;
        candidates.add(pos);
      }
    }

    if (candidates.isEmpty) {
      // Rule: No infinite fallback to random locations
      if (stage.index >= PlanningStage.stage3MoreRelaxed.index && stage.index < PlanningStage.stage5ExtremeRelax.index) {
         return _findSpotInZones(colorAllowedHouseZones[colorIndex]!, colorIndex, stage: stage, nodeType: SpawnNodeType.house);
      }
      return null;
    }

    // [NEW] Neighborhood Scoring: prefer outer rings and angular spread
    final centerPos = center;
    candidates.sort((a, b) {
      final scoreA = scoringService.scoreHouse(a, colorIndex, centerPos, stage);
      final scoreB = scoringService.scoreHouse(b, colorIndex, centerPos, stage);
      return scoreB.compareTo(scoreA); // Highest score first
    });

    final topN = max(1, min(candidates.length, 4)); // Pick from top 4 best spots
    return candidates[_random.nextInt(topN)];
  }

  // _scorePlacement moved to SpawnScoringService

  /// [NEW] Find the best spot for an initial house cluster, favoring central gaps.
  GridPosition? _findInitialHouseCenter(int colorIndex, {required PlanningStage stage}) {
    final candidates = <GridPosition>[];
    
    // Search the whole map within spawn bounds
    for (int y = minSpawnY; y <= maxSpawnY; y++) {
      for (int x = minSpawnX; x <= maxSpawnX; x++) {
        final pos = GridPosition(x, y);
        
        // 1. Must be empty
        if (!gridManager.grid[y][x].isEmpty) continue;
        
        // 2. Must not be reserved (unless in emergency)
        if (gridManager.grid[y][x].isReserved && stage.index < PlanningStage.stage4StrongRelax.index) continue;
        
        // 3. Must have enough breathing room for a cluster
        if (gridManager.countNearbyBuildings(x, y, 3) > 0) continue;

        candidates.add(pos);
      }
    }

    if (candidates.isEmpty) return null;

    // Use Scoring Service to pick the best "central/organic" spot
    candidates.sort((a, b) {
      final sA = scoringService.scoreInitialHouseCenter(a, colorIndex, stage);
      final sB = scoringService.scoreInitialHouseCenter(b, colorIndex, stage);
      return sB.compareTo(sA);
    });

    final topN = max(1, min(candidates.length, 5));
    return candidates[_random.nextInt(topN)];
  }

  /// [REWORKED] Finds a residential center near a specific anchor (used for expansions)
  GridPosition? _findResidentialCenter(GridPosition anchor, int colorIndex, {required PlanningStage stage}) {
    final candidates = <GridPosition>[];
    
    int minDist = 12;
    int maxDist = 18;
    if (stage.index >= PlanningStage.stage3MoreRelaxed.index) {
      minDist = 8;
      maxDist = 24;
    }

    for (int dy = -maxDist; dy <= maxDist; dy++) {
      for (int dx = -maxDist; dx <= maxDist; dx++) {
        final x = anchor.x + dx;
        final y = anchor.y + dy;
        final pos = GridPosition(x, y);
        final d = pos.manhattanDistance(anchor);
        
        if (d < minDist || d > maxDist) continue;
        if (!gridManager.isValid(x, y)) continue;
        if (!gridManager.grid[y][x].isEmpty) continue;
        
        candidates.add(pos);
      }
    }

    if (candidates.isEmpty) return null;
    candidates.shuffle(_random);
    return candidates.first;
  }

  GridPosition? _findDestinationSpot(int colorIndex, {required PlanningStage stage, GridPosition? anchor}) {
    final center = anchor ?? clusterCenters[colorIndex];
    final zones = colorAllowedDestZones[colorIndex] ?? SpawnZone.values;

    final candidates = <GridPosition>[];
    for (int y = minSpawnY; y <= maxSpawnY; y++) {
      for (int x = minSpawnX; x <= maxSpawnX; x++) {
        final pos = GridPosition(x, y);
        
        // Soft zone restriction: only apply if we aren't in emergency fallback
        if (stage.index < PlanningStage.stage3MoreRelaxed.index) {
          if (!zones.contains(_getZoneAt(pos.x, pos.y))) continue;
        }

        // Rule: Separation from residential center
        double minDist = SpawnConfig.destinationToHouseMinDistance.toDouble();
        if (stage.index >= PlanningStage.stage4StrongRelax.index) minDist *= 0.5;
        if (stage.index >= PlanningStage.stage5ExtremeRelax.index) minDist = 4.0;

        if (center != null && pos.manhattanDistance(center) < minDist) continue;

        if (_validateSpawnTile(pos, colorIndex, stage: stage, nodeType: SpawnNodeType.destination)) {
          // Local expansion radius limit (only for mid-game color expansion, NOT initial spawn)
          if (center != null && anchor == null) {
            final dist = pos.manhattanDistance(center);
            if (dist > SpawnConfig.maxDistrictExpansionRadius) continue;
          }
          candidates.add(pos);
        }
      }
    }

    if (candidates.isEmpty) return null;
    
    // [NEW] Use Scoring Service to pick the best strategic spot
    candidates.sort((a, b) {
      final sA = scoringService.scoreDestination(a, colorIndex, stage, anchor: anchor);
      final sB = scoringService.scoreDestination(b, colorIndex, stage, anchor: anchor);
      return sB.compareTo(sA);
    });

    final topN = max(1, min(candidates.length, 3));
    return candidates[_random.nextInt(topN)];
  }

  /// [REWORKED] Search within a region/zone without hard inclusion limits
  GridPosition? _findSpotInZones(List<SpawnZone> zones, int colorIndex, {required PlanningStage stage, required SpawnNodeType nodeType}) {
    final candidates = <GridPosition>[];
    
    // Anchor center for radius enforcement
    final anchor = clusterCenters[colorIndex];

    for (int y = minSpawnY; y <= maxSpawnY; y++) {
      for (int x = minSpawnX; x <= maxSpawnX; x++) {
        final pos = GridPosition(x, y);
        
        // Rule 1: Radius enforcement (Issue 1: Fallbacks are too far)
        if (anchor != null) {
          final d = pos.manhattanDistance(anchor);
          if (d > SpawnConfig.maxDistrictExpansionRadius) continue;
        }

        if (!_validateSpawnTile(pos, colorIndex, stage: stage, nodeType: nodeType)) continue;
        
        candidates.add(pos);
      }
    }

    if (candidates.isEmpty) return null;

    // Use DistrictPlanner to pick the best spot based on territory and neighbor avoidance
    candidates.sort((a, b) {
      final sA = districtPlanner.calculateRegionScore(a, colorIndex);
      final sB = districtPlanner.calculateRegionScore(b, colorIndex);
      return sB.compareTo(sA);
    });

    final topN = max(1, min(candidates.length, 5));
    return candidates[_random.nextInt(topN)];
  }

  SpawnZone _getZoneAt(int x, int y) {
    final centerX = (minSpawnX + maxSpawnX) / 2;
    final quarterY = (maxSpawnY - minSpawnY) / 3;

    final isLeft = x < centerX;
    
    if (y < minSpawnY + quarterY) {
      return isLeft ? SpawnZone.leftTop : SpawnZone.rightTop;
    } else if (y < minSpawnY + quarterY * 2) {
      return isLeft ? SpawnZone.leftMid : SpawnZone.rightMid;
    } else {
      return isLeft ? SpawnZone.leftBottom : SpawnZone.rightBottom;
    }
  }

  // ============================================================
  // VALIDATION â€” correctness before convenience
  // ============================================================

  /// Check that a tile is valid for spawning a building
  bool _validateSpawnTile(GridPosition pos, int colorIndex, {required PlanningStage stage, required SpawnNodeType nodeType}) {
    final profile = (nodeType == SpawnNodeType.house) ? BuildingProfile.residential : BuildingProfile.commercial;
    final cell = gridManager.grid[pos.y][pos.x];


    // [LOG] Building Profile Validation
    if (stage.index == 0) {
      _log('[BUILDING] type=${nodeType.name.toUpperCase()} footprintRadius=1.0 reservationRadius=${profile.corridorLength} corridorLength=${profile.corridorLength} influenceRadius=${profile.influenceRadius}');
    }

    // ============================================================
    // HARD RULES (Preserved at all stages)
    // ============================================================

    // 1. Must be empty (No overlapping buildings/roads)
    if (!cell.isEmpty) return false;
    
    // 1b. Must not be reserved (Issue 2: Corridor Reservation)
    if (cell.isReserved && stage.index < PlanningStage.stage4StrongRelax.index) return false;

    // 2. Map Bounds (Preserved)
    if (pos.x < minSpawnX || pos.x > maxSpawnX || pos.y < minSpawnY || pos.y > maxSpawnY) {
      return false;
    }

    // 3. Reachable Driveway
    final entrySide = findValidEntrySide(pos, profile: profile, stage: stage);
    if (entrySide == null) return false;

    // 4. Basic Neighboring Check (Preserved)
    int freeNeighbors = 0;
    for (final dir in Direction.values) {
      final n = pos.getNeighbor(dir);
      if (gridManager.isValid(n.x, n.y) && gridManager.grid[n.y][n.x].isEmpty) {
        freeNeighbors++;
      }
    }
    if (freeNeighbors < 1) return false; // Minimum 1 for connectivity

    // [STRICT] Adjacency Check (Issue: Buildings touching each other)
    // Rule: New buildings must have a 2-tile clearance from other buildings and infrastructure ports.
    const int buildingClearance = 2;
    for (int dy = -buildingClearance; dy <= buildingClearance; dy++) {
      for (int dx = -buildingClearance; dx <= buildingClearance; dx++) {
        if (dx == 0 && dy == 0) continue;
        final nx = pos.x + dx;
        final ny = pos.y + dy;
        if (!gridManager.isValid(nx, ny)) continue;
        final cell = gridManager.grid[ny][nx];
        
        // Cannot be near another building footprint
        if (cell.isHouse || cell.isDestination) return false;
        
        // Cannot be near a driveway/entrance of another building
        if (gridManager.isLockedEntrance(GridPosition(nx, ny))) return false;

        // [NEW] Spacing Rule: Cannot spawn adjacent to infrastructure endpoints (tunnel/bridge mouths)
        if (cell.isConnectableEndpoint) return false;
      }
    }

    // ============================================================
    // SOFT RULES (Relaxed based on Stage)
    // ============================================================
    
    // [NEW] District Locality (Issue 1: Panic spawns too far)
    final anchor = clusterCenters[colorIndex];
    if (anchor != null) {
      final distFromAnchor = pos.manhattanDistance(anchor);
      // Hard cap even in Emergency: districts cannot teleport across the map
      if (distFromAnchor > SpawnConfig.maxDistrictExpansionRadius) {
        _log('REJECTED: Radius overflow ($distFromAnchor > ${SpawnConfig.maxDistrictExpansionRadius}) for Color $colorIndex');
        return false;
      }
    }

    // [NEW] Inter-Type Spacing (Issue 2: Dest+House too close)
    for (final dest in gridManager.destinations) {
       final dist = pos.manhattanDistance(dest);
       if (nodeType == SpawnNodeType.house) {
         // Houses must stay away from ANY destination
         if (dist < SpawnConfig.destinationToHouseMinDistance) {
           // Allow slightly closer only in extreme emergency
           if (stage.index < PlanningStage.stage5ExtremeRelax.index) return false;
           if (dist < 3) return false; // Hard minimum
         }
       } else {
         // Destinations must stay away from ANY other destination
         if (dist < SpawnConfig.destinationToDestinationMinDistance) {
           if (stage.index < PlanningStage.stage4StrongRelax.index) return false;
           if (dist < 7) return false; // Hard minimum (Mini Motorways spread)
         }
       }
    }

    // [NEW] Destination Accessibility (Hard Requirement)
    if (nodeType == SpawnNodeType.destination) {
      if (!_isDestinationAccessible(pos, entrySide, stage: stage)) {
        _log('REJECTED: Destination inaccessible at $pos');
        return false;
      }
      
      // Strict Border Padding for Destinations (Rule 3)
      // Even in Emergency, destinations shouldn't be pinned against the map edge
      int minPadding = 2; 
      if (stage == PlanningStage.stage5ExtremeRelax) minPadding = 1;

      if (pos.x < minSpawnX + minPadding || pos.x > maxSpawnX - minPadding ||
          pos.y < minSpawnY + minPadding || pos.y > maxSpawnY - minPadding) {
        _log('REJECTED: Border padding at $pos (padding=$minPadding)');
        return false;
      }
    }

    if (stage == PlanningStage.stage5ExtremeRelax) return true;

    // 5. Border Padding (Relaxed in Stage 3+)
    int padding = profile.borderPadding;
    if (stage.index >= PlanningStage.stage3MoreRelaxed.index) padding = 1;
    if (pos.x < minSpawnX + padding || pos.x > maxSpawnX - padding ||
        pos.y < minSpawnY + padding || pos.y > maxSpawnY - padding) {
      return false;
    }

    // 6. Entrance Influence Zone (Relaxed in Stage 3+)
    if (stage.index < PlanningStage.stage3MoreRelaxed.index) {
      for (final house in gridManager.houses) {
        final otherEntry = gridManager.grid[house.y][house.x].entrySide;
        if (otherEntry != null) {
          final otherDriveway = house.getNeighbor(otherEntry);
          final otherForward = otherDriveway.getNeighbor(otherEntry);
          if (pos == otherDriveway || pos == otherForward) {
            _log('REJECTED: Entrance influence at $pos');
            return false;
          }
          
          final myDriveway = pos.getNeighbor(entrySide);
          if (myDriveway == otherDriveway || myDriveway == otherForward) {
             _log('REJECTED: Driveway overlap at $pos');
             return false;
          }

          // Reintegrated raycast check
          if (_violatesEntranceCorridor(pos, entrySide, house, otherEntry)) {
            _log('REJECTED: Corridor violation at $pos');
            return false;
          }
        }
      }
    }

    // New: Outward Clearance Check (Relaxed in Stage 3+)
    if (stage.index < PlanningStage.stage3MoreRelaxed.index) {
      for (int i = 1; i <= profile.corridorLength; i++) {
        final checkPos = pos.getNeighbor(entrySide, count: i);
        if (!gridManager.isValid(checkPos.x, checkPos.y)) return false;
        final checkCell = gridManager.grid[checkPos.y][checkPos.x];
        if (!checkCell.isEmpty && !checkCell.isRoad) return false;
        if (i > 1 && !_isClearOfBuildings(checkPos)) return false;
      }
    }

    // 7. Inter-Color Spacing (Strict: Buildings must never touch)
    int interSpacing = 2; // Always at least 2
    
    // Check against all existing buildings
    for (int y = 0; y < gridManager.rows; y++) {
      for (int x = 0; x < gridManager.cols; x++) {
        final otherCell = gridManager.grid[y][x];
        if (!otherCell.isHouse && !otherCell.isDestination) continue;
        
        final otherPos = GridPosition(x, y);
        final dist = pos.manhattanDistance(otherPos);
        
        // [STRICT] Buildings must never touch (dist=1 is forbidden)
        if (dist < interSpacing) return false;
      }
    }

    // 9. Driveway Spacing (Relaxed in Stage 2+)
    int dSp = 2; // Default driveway spacing
    if (stage.index >= PlanningStage.stage2Relaxed.index) dSp = 1;
    for (final house in gridManager.houses) {
      final otherEntry = gridManager.grid[house.y][house.x].entrySide;
      if (otherEntry != null) {
        final otherDriveway = house.getNeighbor(otherEntry);
        if (pos.manhattanDistance(otherDriveway) < dSp) return false;
      }
    }

    // 10. Macro Sector Reservations (Soft influenced)
    if (stage.index < PlanningStage.stage4StrongRelax.index) {
      if (!districtPlanner.isPositionAllowedFor(colorIndex, pos, activeColorCount)) {
        return false;
      }
    }

    // 11. Local Orientation Diversity (Ignored in Stage 3+)
    if (stage.index < PlanningStage.stage3MoreRelaxed.index) {
      if (_violatesLocalOrientationDiversity(pos, entrySide, colorIndex)) return false;
    }

    return true;
  }

  /// [NEW] Validates that a new entrance doesn't collide with existing corridors (Issue 1)
  bool _violatesEntranceCorridor(GridPosition pos, Direction entry, GridPosition otherHouse, Direction otherEntry) {
    final myRay = _getEntranceRay(pos, entry);
    final otherRay = _getEntranceRay(otherHouse, otherEntry);
    
    // 1. Ray intersection
    for (final p1 in myRay) {
      if (otherRay.any((p2) => p1.x == p2.x && p1.y == p2.y)) return true;
    }
    
    // 2. Parallel ray proximity (side-by-side driveways)
    for (final p1 in myRay) {
      for (final p2 in otherRay) {
        if (p1.manhattanDistance(p2) <= 1) return true;
      }
    }
    
    return false;
  }

  /// [NEW] Enforces variety in house facings within a local district (Issue 1)
  bool _violatesLocalOrientationDiversity(GridPosition pos, Direction entry, int colorIndex) {
    const localRadius = 8;
    for (final house in gridManager.houses) {
      if (pos.manhattanDistance(house) > localRadius) continue;
      
      final otherEntry = gridManager.grid[house.y][house.x].entrySide;
      if (otherEntry == null) continue;
      
      // Rule: Same facing direction + Same/Near Row or Col = INVALID
      if (otherEntry == entry) {
        if (entry == Direction.east || entry == Direction.west) {
          if ((pos.y - house.y).abs() <= 2) return true;
        } else {
          if ((pos.x - house.x).abs() <= 2) return true;
        }
      }
    }
    return false;
  }

  List<GridPosition> _getEntranceRay(GridPosition pos, Direction dir) {
    return List.generate(6, (i) => pos.getNeighbor(dir, count: i + 1));
  }

  /// Helper to check if a tile is clear of ANY building footprints
  bool _isClearOfBuildings(GridPosition pos) {
    for (final house in gridManager.houses) {
      if (pos.manhattanDistance(house) < 3) return false; // Increased from 2
    }
    for (final dest in gridManager.destinations) {
      if (pos.manhattanDistance(dest) < 3) return false; // Increased from 2
    }
    return true;
  }

  /// Find a valid entry side for a building at pos based on map position constraints
  Direction? findValidEntrySide(GridPosition pos, {BuildingProfile profile = BuildingProfile.residential, PlanningStage stage = PlanningStage.stage1Ideal}) {
    final List<Direction> allowed = [
      Direction.north,
      Direction.east,
      Direction.south,
      Direction.west,
    ];

    // FORBID directions that lead out of bounds or into tight edges
    final padding = BuildingProfile.residential.borderPadding + 1;
    if (pos.y < minSpawnY + padding) allowed.remove(Direction.north);
    if (pos.y > maxSpawnY - padding) allowed.remove(Direction.south);
    if (pos.x < minSpawnX + padding) allowed.remove(Direction.west);
    if (pos.x > maxSpawnX - padding) allowed.remove(Direction.east);

    // [NEW] SCORING: Evaluate each direction for openness and network potential
    Direction? best;
    int bestScore = -1;

    for (final dir in allowed) {
      final neighbor = pos.getNeighbor(dir);
      if (!gridManager.isValid(neighbor.x, neighbor.y)) continue;
      
      final cell = gridManager.grid[neighbor.y][neighbor.x];
      if (!cell.isEmpty && !cell.isRoad) continue;

      // Rule: Must be breathable (not a dead end or tight shaft)
      if (!_isDrivewayBreathable(neighbor, dir)) continue;

      int score = calculateOpennessScore(pos, dir);
      
      // Preference: Face map center (usually (min+max)/2)
      final centerY = (minSpawnY + maxSpawnY) / 2;
      final centerX = (minSpawnX + maxSpawnX) / 2;
      if (dir == Direction.north && pos.y > centerY) score += 5;
      if (dir == Direction.south && pos.y < centerY) score += 5;
      if (dir == Direction.west && pos.x > centerX) score += 5;
      if (dir == Direction.east && pos.x < centerX) score += 5;

      if (score > bestScore) {
        bestScore = score;
        best = dir;
      }
    }

    // REQUIRE minimum accessibility score (Rule: can player build a good network?)
    int floor = profile.minOpenness;
    if (stage.index >= PlanningStage.stage3MoreRelaxed.index) floor = 1;
    if (stage.index >= PlanningStage.stage5ExtremeRelax.index) floor = 0;

    if (best != null && bestScore >= floor) {
      return best;
    }

    return null;
  }

  /// [NEW] Calculates how "open" the terrain is in front of a potential driveway
  int calculateOpennessScore(GridPosition pos, Direction dir) {
    int score = 0;
    final driveway = pos.getNeighbor(dir);
    
    // Check 3-tile expansion cone
    for (int i = 1; i <= 3; i++) {
      final fwd = driveway.getNeighbor(dir, count: i);
      if (!gridManager.isValid(fwd.x, fwd.y)) break;
      
      final fwdCell = gridManager.grid[fwd.y][fwd.x];
      
      // [FIX] Anti-Overlap: Forward tiles must NOT be buildings or facing another entrance (Issue 2)
      if (fwdCell.isHouse || fwdCell.isDestination) {
        score -= 20; // Severe penalty for facing a building
        break;
      }
      
      if (gridManager.isLockedEntrance(fwd)) {
        score -= 15; // Penalty for facing an entrance
        break;
      }

      if (fwdCell.isEmpty || fwdCell.isRoad) {
        score += 3; // Forward growth is high value
      } else {
        break; // Blocked (mountain/water)
      }

      // Check immediate sideways tiles for junction potential
      final left = fwd.getNeighbor(dir.rotateCCW());
      if (gridManager.isValid(left.x, left.y) && gridManager.grid[left.y][left.x].isEmpty) {
        score += 1;
      }
      final right = fwd.getNeighbor(dir.rotateCW());
      if (gridManager.isValid(right.x, right.y) && gridManager.grid[right.y][right.x].isEmpty) {
        score += 1;
      }
    }
    return score;
  }

  /// [NEW] Hard accessibility check for destinations (Rule 1 & 4)
  bool _isDestinationAccessible(GridPosition pos, Direction entrySide, {required PlanningStage stage}) {
    final driveway = pos.getNeighbor(entrySide);
    
    // In extreme emergency, just ensure we have ONE tile out
    if (stage == PlanningStage.stage5ExtremeRelax) {
       return gridManager.isValid(driveway.x, driveway.y) && 
              (gridManager.grid[driveway.y][driveway.x].isEmpty || gridManager.grid[driveway.y][driveway.x].isRoad);
    }

    // 1. Forward Approach Space (Requirement: 2 tiles beyond driveway, relaxed to 1 in later stages)
    int depth = (stage.index >= PlanningStage.stage4StrongRelax.index) ? 1 : 2;
    for (int i = 1; i <= depth; i++) {
      final fwd = driveway.getNeighbor(entrySide, count: i);
      if (!gridManager.isValid(fwd.x, fwd.y)) return false;
      
      final cell = gridManager.grid[fwd.y][fwd.x];
      // Must be empty or road, NOT another building or mountain
      if (!cell.isEmpty && !cell.isRoad) return false;
      
      // Reject if reserved by another building (prevent corridor overlap)
      if (cell.isReserved) return false;
    }
    
    // 2. Side Clearance (Ensure not pinned in a 1-tile shaft)
    // Check tiles to the left and right of the driveway AND the first approach tile
    // Relaxed in Stage 4+
    if (stage.index < PlanningStage.stage4StrongRelax.index) {
      final sideDirs = [entrySide.rotateCCW(), entrySide.rotateCW()];
      for (final dir in sideDirs) {
        final side1 = driveway.getNeighbor(dir);
        final side2 = driveway.getNeighbor(entrySide).getNeighbor(dir);
        
        bool side1Clear = gridManager.isValid(side1.x, side1.y) && 
                          (gridManager.grid[side1.y][side1.x].isEmpty || gridManager.grid[side1.y][side1.x].isRoad);
        bool side2Clear = gridManager.isValid(side2.x, side2.y) && 
                          (gridManager.grid[side2.y][side2.x].isEmpty || gridManager.grid[side2.y][side2.x].isRoad);
                          
        // If BOTH sides of the entrance path are blocked by non-road obstacles, it's a choke/throat
        if (!side1Clear && !side2Clear) return false;
      }
    }
    
    // 3. Openness Check (Hard floor for destinations, relaxed in Stage 3+)
    int floor = BuildingProfile.commercial.minOpenness;
    if (stage.index >= PlanningStage.stage3MoreRelaxed.index) floor = 2;
    
    int openness = calculateOpennessScore(pos, entrySide);
    if (openness < floor) return false;
    
    return true;
  }

  /// Validates that a driveway has room to branch or continue.
  /// Prevents dead-end traps and edge pinning.
  bool _isDrivewayBreathable(GridPosition drivewayPos, Direction entrySide) {
    int openDirections = 0;
    for (final dir in Direction.values) {
      // Don't count the direction going BACK into the building
      if (dir == entrySide.opposite) continue;
      
      final neighbor = drivewayPos.getNeighbor(dir);
      if (gridManager.isValid(neighbor.x, neighbor.y)) {
        final cell = gridManager.grid[neighbor.y][neighbor.x];
        if (cell.type == CellType.empty || cell.type == CellType.road) {
          openDirections++;
        }
      }
    }

    // Must have at least 2 ways out (including the current direction)
    // or a long straight corridor if space is tight.
    if (openDirections >= 2) return true;

    // Straight corridor check: 3 tiles clear in the entry direction
    for (int i = 1; i <= 3; i++) {
      final corridor = drivewayPos.getNeighbor(entrySide, count: i);
      if (!gridManager.isValid(corridor.x, corridor.y)) return false;
      if (!gridManager.grid[corridor.y][corridor.x].isEmpty) return false;
    }

    return true;
  }

  // ============================================================
  // DEMAND TRACKING â€” drives additional house spawning
  // ============================================================

  void _updateDemandPressure() {
    for (int c = 0; c < activeColorCount; c++) {
      final dests = gridManager.getDestinationsForColor(c);
      final houses = gridManager.getHousesForColor(c);
      
      int totalUnmet = 0;
      
      if (houses.isNotEmpty && dests.isEmpty) {
        // [NEW] CRITICAL: Build pressure if color exists but has no sink!
        totalUnmet = 10; // Forced pressure
      } else {
        for (final dest in dests) {
          final demand = gridManager.getDemand(dest);
          final claimed = gridManager.getClaimedDemand(dest);
          totalUnmet += max(0, demand - claimed);
        }
      }

      if (totalUnmet > 0) {
        _demandPressure[c] = min(SpawnConfig.maxPressure, (_demandPressure[c] ?? 0) + 1);
      } else {
        // Decay more aggressively when demand is met
        _demandPressure[c] = max(0, (_demandPressure[c] ?? 0) - 2);
      }
    }
  }

  /// Check if any color needs an additional house due to sustained demand, or if a new color should unlock
  void _maybeEnqueueDemandDrivenHouse() {
    // Only check once per cooldown cycle to avoid spam
    if (_queue.isNotEmpty) return;

    // Track state of existing colors
    int bestColor = -1;
    int bestPressure = 0;
    SpawnNodeType nodeToSpawn = SpawnNodeType.house;

    for (int c = 0; c < activeColorCount; c++) {
      final pressure = _demandPressure[c] ?? 0;
      final houseCount = getHouseCount(c);
      final timeSinceLastSpawn = _elapsedTime - (_lastSpawnTimeForColor[c] ?? -SpawnConfig.sameColorSpawnCooldown);

      if (houseCount < SpawnConfig.earlyHouseCap || pressure > 5) {
        // Network is still growing or struggling
      }

      // Priority 1: Colors with only 1 house (incomplete cluster)
      if (houseCount == 1 && pressure > 0) {
        bestColor = c;
        bestPressure = pressure;
        nodeToSpawn = SpawnNodeType.house;
        break; // Highest priority â€” do this immediately
      }

      // Non-linear threshold scaling for expansion (values in samples, e.g. 5 samples = 15s)
      int requiredPressure = 5; // default for 3rd house (15s)
      if (houseCount == 3) requiredPressure = 8; // 4th house (24s)
      if (houseCount >= 4) requiredPressure = 10; // 5th+ house (30s)

      // Priority 2: Colors needing demand-driven expansion.
      // Per-destination age gate: the initial pair of houses stays as the
      // firm cap until at least one destination for this color has aged
      // [_minDestAgeForExtraHouse] weekly transitions. A brand-new
      // destination — even one spawned mid-game in week 5 — starts capped
      // at the initial pair regardless of demand pressure, because demand
      // pressure on a fresh destination usually reflects an unconnected
      // road network rather than genuine over-capacity.
      final destAge = _maxDestinationAgeForColor(c);
      if (houseCount >= SpawnConfig.earlyHouseCap &&
          pressure >= requiredPressure &&
          pressure > bestPressure &&
          destAge >= _minDestAgeForExtraHouse) {

        // Enforce same-color spawn cooldown to prevent panic-flooding
        if (timeSinceLastSpawn >= SpawnConfig.sameColorSpawnCooldown) {
          bestColor = c;
          bestPressure = pressure;

          // Destination Capacity Check
          final destCount = gridManager.getDestinationsForColor(c).length;
          final capacity = destCount * SpawnConfig.housesPerDestination;

          if (houseCount >= capacity) {
            nodeToSpawn = SpawnNodeType.destination; // District is saturated, add new destination
          } else {
            nodeToSpawn = SpawnNodeType.house;
          }
        }
      }
    }

    if (bestColor >= 0) {
      requestSpawn(bestColor, nodeToSpawn,
          'demand-driven (pressure=$bestPressure, houses=${getHouseCount(bestColor)})');
      return;
    }
  }

  // ============================================================
  // LOGGING
  // ============================================================

  void _log(String message) {
    final ts = _elapsedTime.toStringAsFixed(1);
    final fullMessage = '[$ts] SPAWN: $message';
    onLog?.call(fullMessage);
    // Also print for debug console
    // ignore: avoid_print
    // print(fullMessage);
  }
}

