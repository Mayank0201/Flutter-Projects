import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/grid_cell.dart';
import '../models/game_constants.dart';
import 'map_generator.dart';
import 'components/car_component.dart';

class HouseCluster {
  final GridPosition center;
  final int colorIndex;
  final MapRegion region;
  final int radius;
  int maturity = 1;
  final List<GridPosition> houses = [];

  HouseCluster({
    required this.center,
    required this.colorIndex,
    required this.region,
    required this.radius,
  });
}

class MountainCluster {
  final Set<GridPosition> cells = {};
  GridPosition center;

  MountainCluster(this.center);
}

class GridManager {
  final int cols;
  final int rows;
  
  /// Callback when roads/tunnels/bridges are placed or removed, triggering path cache invalidation.
  VoidCallback? onTopologyChanged;

  /// Optional guard set by SpawnController — returns true if the tile at (x,y)
  /// is reserved for a staged building that has not yet committed.  When set,
  /// player road-building on these tiles is silently blocked.
  bool Function(int x, int y)? isStagedBuilding;

  String _key(GridPosition pos) => "${pos.x},${pos.y}";

  late List<List<GridCell>> grid;

  final List<GridPosition> houses = [];
  final List<GridPosition> destinations = [];
  final Map<String, int> demand = {};
  final Map<String, int> claimedDemand = {};
  final Map<String, double> demandTimers = {};
  final Map<String, double> overflowLevels =
      {}; // Tracks game over countdown for max demand destinations
  final Map<String, int> destinationAges = {};
  final Map<String, String> districtNames = {}; // [NEW] District Naming
  final Set<String> upgradedRoads = {}; // [NEW] Manually upgraded roads (Avenue/Highway)
  final Map<String, double> houseCarTimers = {};
  final Map<String, double> highDemandTimers = {};
  final Map<String, bool> spawnedBonusHouse = {};
  final Set<GridPosition> infrastructure = {};
  
  // Map-specific temporary blockages (Floods, Stampedes, Drawbridges)
  final Set<GridPosition> blockedTiles = {};
  
  // Satisfaction System
  final Map<String, double> sectorSatisfaction = {}; // sectorId -> avg satisfaction
  double regionalSatisfaction = 1.0;

  /// Combined list of all buildings (houses + destinations)
  List<GridPosition> get buildings => [...houses, ...destinations];

  /// Maps a building's position to its dedicated driveway (the first road connected to it)
  final Map<String, GridPosition> buildingDriveways = {};

  /// Each express lane is a pair [start, end]
  final List<List<GridPosition>> placedExpressLanes = [];

  // Road capacity tracking (runtime)
  final Map<String, int> roadLoad = {};
  int getRoadLoad(int x, int y) => roadLoad["$x,$y"] ?? 0;

  // Traffic signal state
  final Map<String, int> signalPhases = {}; // 0=NS green, 1=EW green
  final Map<String, double> signalTimers = {};
  final Map<String, int> signalNsCounts = {};
  final Map<String, int> signalEwCounts = {};

  final List<MountainCluster> mountainClusters = [];
  
  // Region tracking for spawning
  final List<GridPosition> regionA = [];
  final List<GridPosition> regionB = [];

  // [NEW] Map Type
  MapType selectedMapType = MapType.zen;

  // [NEW] Mountain Centering (Issue 2)
  int _mountainX = 0;
  int get mountainX => _mountainX;

  // [NEW] Expressway Placement State
  GridPosition? _pendingExpressLaneStart;
  bool get isPlacingExpressLane => _pendingExpressLaneStart != null;
  GridPosition? get pendingExpressLaneStart => _pendingExpressLaneStart;

  // [NEW] Interaction State Control (Issue 1)
  InteractionState interactionState = InteractionState.idle;
  bool _hasChargedMergeThisGesture = false;

  void commitPlacement(VoidCallback action) {
    final oldState = interactionState;
    interactionState = InteractionState.commit;
    _hasChargedMergeThisGesture = false; // Reset for new gesture
    try {
      action();
    } finally {
      interactionState = oldState;
      _hasChargedMergeThisGesture = false;
    }
  }

  void eraseCell(int x, int y) {
    removeInfrastructure(x, y);
  }

  /// Cell qualifies for traffic-light placement when it's a road with at
  /// least two active connections — i.e. anything that's actually part of
  /// the network (rejects dead-end stubs that wouldn't benefit from a
  /// signal). Intersections (3+ connections) are still the most useful
  /// spots but the looser rule lets the player drop signals on a straight
  /// segment or a curve too, which matches their expectation.
  bool _isTrafficLightCandidate(int x, int y) {
    if (!isValid(x, y)) return false;
    final cell = grid[y][x];
    if (!cell.isRoad) return false;
    int connCount = 0;
    if (cell.connUp) connCount++;
    if (cell.connRight) connCount++;
    if (cell.connDown) connCount++;
    if (cell.connLeft) connCount++;
    return connCount >= 2;
  }

  void toggleTrafficLight(int x, int y) {
    if (!isValid(x, y)) return;
    final cell = grid[y][x];
    if (cell.hasTrafficLight) {
      grid[y][x] = cell.copyWith(hasTrafficLight: false);
      trafficLights++; // Refund
    } else {
      if (trafficLights > 0 && _isTrafficLightCandidate(x, y)) {
        grid[y][x] = cell.copyWith(hasTrafficLight: true);
        trafficLights--;
      }
    }
  }

  void toggleSmartJunction(int x, int y, {void Function(String)? onError}) {
    if (!isValid(x, y)) return;
    final cell = grid[y][x];
    if (cell.type == CellType.smartJunction) {
      grid[y][x] = GridCell(); // Remove
      smartJunctions++; // Refund
      infrastructure.remove(GridPosition(x, y));
      removeEdgesFor(x, y);
      onTopologyChanged?.call();
    } else if (cell.isEmpty || cell.isRoad) {
      if (smartJunctions <= 0) {
        onError?.call("NO ROUNDABOUTS REMAINING");
        return;
      }

      // Check 8-way mountain neighbor validation
      for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          final nx = x + dx;
          final ny = y + dy;
          if (isValid(nx, ny)) {
            if (grid[ny][nx].type == CellType.mountain) {
              onError?.call("CANNOT PLACE ROUNDABOUT ADJACENT TO MOUNTAIN");
              return;
            }
          }
        }
      }

      if (cell.isRoad) {
        removeEdgesFor(x, y);
        if (cell.owner == InfrastructureOwner.player) {
          roads++; // refund the overridden road
        }
      }
      grid[y][x] = GridCell(type: CellType.smartJunction, owner: InfrastructureOwner.player);
      smartJunctions--;
      infrastructure.add(GridPosition(x, y));
      // Re-connect
      for (var d in [[0, -1], [1, 0], [0, 1], [-1, 0]]) {
        final nx = x + d[0];
        final ny = y + d[1];
        if (isValid(nx, ny)) {
          final neighbor = grid[ny][nx];
          if (neighbor.isPassable) {
            addEdge(x, y, nx, ny);
            updateNodeConnections(nx, ny);
          } else if (neighbor.isHouse || neighbor.isDestination) {
            connectBuilding(nx, ny, x, y);
          }
        }
      }
      updateNodeConnections(x, y);
      onTopologyChanged?.call();
    }
  }


  /// Set of explicit connections between adjacent tiles: "x1,y1|x2,y2"
  /// where the coordinates are sorted lexicographically to ensure (A,B) == (B,A)
  final Set<String> activeEdges = {};

  String _edgeKey(int x1, int y1, int x2, int y2) {
    if (y1 < y2 || (y1 == y2 && x1 < x2)) {
      return "$x1,$y1|$x2,$y2";
    }
    return "$x2,$y2|$x1,$y1";
  }

  void addEdge(int x1, int y1, int x2, int y2) {
    if (!isValid(x1, y1) || !isValid(x2, y2)) return;
    
    // [STRICT CORRIDOR PROTECTION]
    // 1. Internal corridor tiles (middle of curved tunnel/bridge) block NEW external road connections.
    // 2. Endpoints allow at most ONE external road connection (prevents T-junctions on corridors).
    final cell1 = grid[y1][x1];
    final cell2 = grid[y2][x2];

    // Reject if either side is internal infrastructure
    if (cell1.isInfrastructureInternal || cell2.isInfrastructureInternal) {
      // Allow if it's an existing infrastructure edge (both are infrastructure)
      bool isInfraEdge = (cell1.isTunnel || cell1.isBridge) && (cell2.isTunnel || cell2.isBridge);
      if (!isInfraEdge) return; // Block road-to-internal connection
    }

    // [FIX] Infrastructure Portal Creation: 
    // If we are connecting a road to a tunnel/bridge for the FIRST time,
    // we must ensure the tunnel tile correctly marks itself as an endpoint.
    if ((cell1.isTunnel || cell1.isBridge) && cell2.type == CellType.road) {
      if (!cell1.isConnectableEndpoint && !cell1.isInfrastructureInternal) {
         grid[y1][x1] = cell1.copyWith(isConnectableEndpoint: true);
      }
    }
    if ((cell2.isTunnel || cell2.isBridge) && cell1.type == CellType.road) {
      if (!cell2.isConnectableEndpoint && !cell2.isInfrastructureInternal) {
         grid[y2][x2] = cell2.copyWith(isConnectableEndpoint: true);
      }
    }

    // [ENDPOINT ORIENTATION VALIDATION]
    // Redesigned: Use directional slots instead of a global limit.
    // Each endpoint can have 1 internal connection (corridor) and 1 external connection (road/house).
    // The specific direction must be allowed by the infrastructure axis.
    
    void validateEndpointSlots(GridCell ep, int ex, int ey, GridCell other, int ox, int oy) {
      if (!ep.isConnectableEndpoint) return;
      
      final dx = ox - ex;
      final dy = oy - ey;
      Direction? dir;
      if (dx == 1 && dy == 0) {
        dir = Direction.east;
      } else if (dx == -1 && dy == 0) {
        dir = Direction.west;
      } else if (dx == 0 && dy == 1) {
        dir = Direction.south;
      } else if (dx == 0 && dy == -1) {
        dir = Direction.north;
      }
      
      if (dir == null) return; // Not adjacent

      // 1. Axis check: Must align with portal orientation
      if (ep.infrastructureAxis != null) {
        if (ep.infrastructureAxis == InfrastructureAxis.horizontal) {
          if (dir != Direction.west && dir != Direction.east) {
            throw 'REJECT';
          }
        } else if (ep.infrastructureAxis == InfrastructureAxis.vertical) {
          if (dir != Direction.north && dir != Direction.south) {
            throw 'REJECT';
          }
        }
      }

      // 2. Directional Slot Occupancy: Is this specific direction already taken?
      bool isTaken = false;
      if (dir == Direction.north) {
        isTaken = ep.connUp;
      } else if (dir == Direction.south) {
        isTaken = ep.connDown;
      } else if (dir == Direction.west) {
        isTaken = ep.connLeft;
      } else if (dir == Direction.east) {
        isTaken = ep.connRight;
      }

      // [REGRESSION FIX] Allow connecting if this is the ONLY external connection 
      // and it aligns with the axis. The global limit of 1 was blocking legitimate 
      // tunnel exits if the connection was being formed during drag.
      if (isTaken && !hasEdge(ex, ey, ox, oy)) {
        throw 'REJECT';
      }

      // 3. Categorical Limit: a tunnel/bridge endpoint can have exactly ONE
      //    external road mouth. The other side of the corridor is sealed —
      //    so a single-cell tunnel is a dead-end, and chains have a mouth
      //    only at each chain end (middle cells are corridor-internal).
      bool isTargetInfra = other.isTunnel || other.isBridge;
      if (!isTargetInfra && (other.isRoad || other.isSmartJunction || other.isHouse || other.isDestination)) {
        int externalConns = _countExternalConnections(ex, ey);
        if (externalConns >= 1 && !hasEdge(ex, ey, ox, oy)) {
          throw 'REJECT';
        }
      }
    }

    try {
      validateEndpointSlots(cell1, x1, y1, cell2, x2, y2);
      validateEndpointSlots(cell2, x2, y2, cell1, x1, y1);
    } catch (e) {
      if (e == 'REJECT') return;
      rethrow;
    }

    final key = _edgeKey(x1, y1, x2, y2);
    if (!activeEdges.contains(key)) {
      activeEdges.add(key);
      // print('[GRAPH] Edge added: ($x1,$y1) <-> ($x2,$y2)');
    }
  }

  void removeEdge(int x1, int y1, int x2, int y2) {
    final key = _edgeKey(x1, y1, x2, y2);
    if (activeEdges.contains(key)) {
      activeEdges.remove(key);
      // print('[GRAPH] Edge removed: ($x1,$y1) <-> ($x2,$y2)');
    }
  }


  bool hasEdge(int x1, int y1, int x2, int y2) {
    return activeEdges.contains(_edgeKey(x1, y1, x2, y2));
  }

  // [NEW] Centralized Infrastructure Transaction Accounting
  void _logInv(String type, int delta) {
    final prefix = delta > 0 ? "+" : "";
    if (GameConstants.debugInfrastructure) {
      debugPrint('[ROAD_INV] $type: $prefix$delta');
    }
  }

  void spendRoads(int count) {
    roads -= count;
    _logInv('road', -count);
  }

  void refundRoads(int count) {
    roads += count;
    _logInv('road', count);
  }

  void spendTunnel(int count) {
    tunnels -= count;
    _logInv('tunnel', -count);
  }

  void refundTunnel(int count) {
    tunnels += count;
    _logInv('tunnel', count);
  }

  void spendBridge(int count) {
    bridges -= count;
    _logInv('bridge', -count);
  }

  void refundBridge(int count) {
    bridges += count;
    _logInv('bridge', count);
  }

  // Infrastructure Inventories
  int roads = 0;
  int tunnels = 0; // was: bridges
  int bridges = 0;
  int trafficLights = 0;
  int smartJunctions = 0; // was: roundabouts
  int expressLanes = 0; // was: motorways

  GridManager(this.cols, this.rows, {this.selectedMapType = MapType.zen, bool initTerrain = true}) {
    grid = List.generate(rows, (y) => List.generate(cols, (x) => GridCell()));
    if (initTerrain) {
      // Terrain is handled by MapGenerator on first reset/init
      final generator = MapGeneratorFactory.getGenerator(selectedMapType);
      generator.generateInitialTerrain(this);
    }
  }



  /// Rebuilds the mountain divider at a specific X coordinate (Issue: Mountain Centering)
  void rebuildMountain(int newX) {
    _mountainX = newX;
    mountainClusters.clear();
    
    // Clear old mountain cells from grid
    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        if (grid[y][x].type == CellType.mountain) {
          grid[y][x] = GridCell(); // Reset to empty
        }
      }
    }

    final cluster = MountainCluster(GridPosition(_mountainX, rows ~/ 2));
    
    // Wall with two gaps (crossings)
    final gap1 = 2;
    final gap2 = rows - 3;

    for (int y = 0; y < rows; y++) {
      if (y == gap1 || y == gap2) continue; // The gaps
      
      if (isValid(_mountainX, y)) {
        // [SAFETY] Only place mountain if cell is empty. Don't overwrite roads/tunnels/buildings.
        if (grid[y][_mountainX].isEmpty) {
          cluster.cells.add(GridPosition(_mountainX, y));
          grid[y][_mountainX] = GridCell(type: CellType.mountain, region: null);
        }
      }
    }
    
    mountainClusters.add(cluster);
    detectRegions();
    applyTerrainSpeeds();
  }

  void detectRegions() {
    regionA.clear();
    regionB.clear();
    
    final midX = cols ~/ 2;
    
    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        final pos = GridPosition(x, y);
        if (grid[y][x].type == CellType.mountain) {
          grid[y][x] = grid[y][x].copyWith(region: null);
          continue;
        }
        
        if (x < midX) {
          regionA.add(pos);
          grid[y][x] = grid[y][x].copyWith(region: MapRegion.A);
        } else {
          regionB.add(pos);
          grid[y][x] = grid[y][x].copyWith(region: MapRegion.B);
        }
      }
    }
  }

  /// Generic region detection for endless expansion
  void detectRegionsEndless() {
    detectRegions(); // For now, keep simple mid-split
  }


  /// Pre-compute speed multipliers based on mountain proximity
  void applyTerrainSpeeds() {
    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        final cell = grid[y][x];
        if (cell.type == CellType.mountain) continue;
        if (cell.type == CellType.tunnel) continue; // tunnels override penalty

        bool nearMountain = false;
        for (final d in [
          [-1, 0],
          [1, 0],
          [0, -1],
          [0, 1],
        ]) {
          final nx = x + d[0], ny = y + d[1];
          if (isValid(nx, ny) && grid[ny][nx].type == CellType.mountain) {
            nearMountain = true;
            break;
          }
        }
        if (nearMountain && cell.speedMultiplier == 1.0) {
          grid[y][x] = cell.copyWith(
            speedMultiplier: GameConstants.mountainTerrainPenalty,
          );
        }
      }
    }
  }

  /// Tick all traffic signals with queue-aware timing logic
  void updateTrafficSignals(double dt, Map<int, List<CarComponent>> carGrid, int gridWidth) {
    for (final pos in infrastructure) {
      final cell = grid[pos.y][pos.x];
      if (!cell.hasTrafficLight) continue;
      final key = _key(pos);
      
      double timer = (signalTimers[key] ?? 0) + dt;
      int currentPhase = signalPhases[key] ?? 0;
      
      int nsCount = 0;
      int ewCount = 0;
      
      // Optimization: use spatial grid to check ONLY nearby cars
      for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
          final neighborKey = (pos.x + dx) + (pos.y + dy) * gridWidth;
          final nearbyCars = carGrid[neighborKey];
          if (nearbyCars == null) continue;
          
          for (final car in nearbyCars) {
            if (car.arrived || car.isWaiting) continue;
            // Determine if car is NS or EW relative to this light
            if (car.angle.abs() < 0.5 || (car.angle.abs() - pi).abs() < 0.5) {
              ewCount++;
            } else {
              nsCount++;
            }
          }
        }
      }

      // Apply dynamic interval
      double baseInterval = GameConstants.trafficSignalInterval;
      double dynamicInterval = baseInterval;
      
      // If current green has way more cars, stay green longer (up to 1.5x)
      // If other side is packed, switch sooner (down to 0.5x)
      if (currentPhase == 0) { // NS is green
        if (nsCount > ewCount + 2) dynamicInterval *= 1.5;
        if (ewCount > nsCount + 3) dynamicInterval *= 0.5;
      } else { // EW is green
        if (ewCount > nsCount + 2) dynamicInterval *= 1.5;
        if (nsCount > ewCount + 3) dynamicInterval *= 0.5;
      }

      // Store traffic counts for low-traffic override checks
      signalNsCounts[key] = nsCount;
      signalEwCounts[key] = ewCount;

      if (timer >= dynamicInterval) {
        timer = 0;
        currentPhase = currentPhase == 0 ? 1 : 0;
        signalPhases[key] = currentPhase;
        grid[pos.y][pos.x] = cell.copyWith(signalPhase: currentPhase);
      }
      
      signalTimers[key] = timer;
    }
  }

  int getSignalPhase(int x, int y) =>
      signalPhases[_key(GridPosition(x, y))] ?? 0;

  bool isGreenForDirection(int x, int y, Direction movingDir) {
    if (!isValid(x, y)) return true;
    final cell = grid[y][x];
    
    // Straight roads (only vertical connections or only horizontal connections) do not block traffic.
    final hasVertical = cell.connUp || cell.connDown;
    final hasHorizontal = cell.connLeft || cell.connRight;
    if (!hasVertical || !hasHorizontal) {
      return true;
    }

    final key = _key(GridPosition(x, y));
    final nsCount = signalNsCounts[key] ?? 0;
    final ewCount = signalEwCounts[key] ?? 0;

    // When traffic is low (total nearby cars <= 1), both directions get green access.
    if (nsCount + ewCount <= 1) {
      return true;
    }

    final phase = getSignalPhase(x, y);
    // Phase 0 = N/S green, Phase 1 = E/W green
    if (phase == 0) {
      return movingDir == Direction.north || movingDir == Direction.south;
    }
    return movingDir == Direction.east || movingDir == Direction.west;
  }

  // Road load tracking
  void setRoadLoad(int x, int y, int val) =>
      roadLoad[_key(GridPosition(x, y))] = val;

  void updateCongestion(List<CarComponent> cars) {
    roadLoad.clear();
    for (final car in cars) {
      if (car.arrived) continue;
      final pos = car.path[car.currentPathIndex.clamp(0, car.path.length - 1)];
      final key = _key(pos);
      roadLoad[key] = (roadLoad[key] ?? 0) + 1;
    }
  }

  bool isRoadCongested(int x, int y) {
    if (!isValid(x, y)) return false;
    final cell = grid[y][x];
    final count = getRoadLoad(x, y);
    return count >= (cell.capacity * GameConstants.roadCapacityCongestedThreshold).ceil();
  }

  void updateSatisfaction(double dt) {
    double totalSatisfaction = 0;
    int count = 0;
    
    final sectorSums = <String, double>{};
    final sectorCounts = <String, int>{};

    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        final cell = grid[y][x];
        if (cell.isHouse || cell.isDestination) {
          double current = cell.satisfaction;
          final key = _key(GridPosition(x, y));
          
          // If high demand or congestion nearby, decay satisfaction
          bool isStressed = (overflowLevels[key] ?? 0) > 0.5 || isRoadCongested(x, y);
          if (isStressed) {
            current = (current - GameConstants.satisfactionDecayRate * dt).clamp(0.0, 1.0);
          } else {
            current = (current + GameConstants.satisfactionRecoveryRate * dt).clamp(0.0, 1.0);
          }
          
          grid[y][x] = cell.copyWith(satisfaction: current);
          
          totalSatisfaction += current;
          count++;
          
          if (cell.sectorId != null) {
            sectorSums[cell.sectorId!] = (sectorSums[cell.sectorId!] ?? 0) + current;
            sectorCounts[cell.sectorId!] = (sectorCounts[cell.sectorId!] ?? 0) + 1;
          }
        }
      }
    }
    
    if (count > 0) {
      regionalSatisfaction = totalSatisfaction / count;
    }
    
    sectorSums.forEach((id, sum) {
      sectorSatisfaction[id] = sum / sectorCounts[id]!;
    });
  }

  void updateDemand(double dt) {
    for (final dest in destinations) {
      final key = _key(dest);
      final cell = grid[dest.y][dest.x];
      if (!cell.isDestination) continue;

      final age = destinationAges[key] ?? 0;
      final isMature = age >= GameConstants.maturityThresholdWeeks;

      double rateMultiplier = 1.0 + (age * GameConstants.demandAgeScalingRate);
      if (isMature) {
        rateMultiplier *= GameConstants.matureRequestSpeedMultiplier;
      }
      
      double interval = GameConstants.demandTickInterval / rateMultiplier;
      if (interval < GameConstants.minDemandInterval) {
        interval = GameConstants.minDemandInterval;
      }

      double timer = demandTimers[key] ?? 0.0;
      timer += dt;

      if (timer >= interval) {
        timer = 0.0;
        int currentDemand = demand[key] ?? 0;
        int maxD = isMature ? GameConstants.matureMaxDemand : GameConstants.maxDemand;
        if (currentDemand < maxD) {
          demand[key] = currentDemand + 1;
        }
      }
      demandTimers[key] = timer;

      int currentDemand = demand[key] ?? 0;
      int maxD = isMature ? GameConstants.matureMaxDemand : GameConstants.maxDemand;
      if (currentDemand >= maxD) {
        double overflow = overflowLevels[key] ?? 0.0;
        double speedMult = isMature ? GameConstants.matureOverflowBuildupMultiplier : 1.0;
        overflow += (dt / GameConstants.criticalDuration) * speedMult;
        overflowLevels[key] = overflow.clamp(0.0, 1.0);
      } else {
        double overflow = overflowLevels[key] ?? 0.0;
        if (overflow > 0.0) {
          overflow -= dt / GameConstants.overflowRecoveryDuration;
          overflowLevels[key] = overflow.clamp(0.0, 1.0);
        }
      }
    }
  }


  void reset({int? minX, int? maxX, int? minY, int? maxY}) {
    grid = List.generate(rows, (y) => List.generate(cols, (x) => GridCell()));
    houses.clear();
    destinations.clear();
    demand.clear();
    claimedDemand.clear();
    demandTimers.clear();
    overflowLevels.clear();
    destinationAges.clear();
    houseCarTimers.clear();
    infrastructure.clear();
    buildingDriveways.clear();
    placedExpressLanes.clear();
    activeEdges.clear();
    roadLoad.clear();
    signalPhases.clear();
    signalTimers.clear();
    signalNsCounts.clear();
    signalEwCounts.clear();
    
    // Reset inventory based on starting constants
    roads = GameConstants.startingRoadBudget;
    tunnels = GameConstants.startingTunnels;
    bridges = GameConstants.startingBridges;
    trafficLights = GameConstants.startingTrafficLights;
    smartJunctions = GameConstants.startingSmartJunctions;
    expressLanes = GameConstants.startingExpressLanes;
    
    // Terrain is now handled by the selected MapGenerator
    final generator = MapGeneratorFactory.getGenerator(selectedMapType);
    generator.generateInitialTerrain(this, minX: minX, maxX: maxX, minY: minY, maxY: maxY);
  }

  void loadFromSave(Map<String, dynamic> data) {
    reset(); // Clear first

    // Grid
    final gridData = data['grid'] as List<dynamic>?;
    if (gridData == null) return;

    final savedRows = gridData.length;
    for (int y = 0; y < rows; y++) {
      if (y >= savedRows) break;
      final rowData = gridData[y] as List<dynamic>?;
      if (rowData == null) continue;

      final savedCols = rowData.length;
      for (int x = 0; x < cols; x++) {
        if (x >= savedCols) break;
        final cellData = rowData[x] as Map<String, dynamic>?;
        if (cellData == null) continue;

        final typeIndex = cellData['type'] as int? ?? 0;
        final type = CellType.values[typeIndex.clamp(0, CellType.values.length - 1)];
        
        final ownerIndex = cellData['owner'] as int? ?? 0;
        final owner = InfrastructureOwner.values[ownerIndex.clamp(0, InfrastructureOwner.values.length - 1)];

        grid[y][x] = GridCell(
          type: type,
          colorIndex: cellData['colorIndex'] as int?,
          isPendingDeletion: cellData['isPendingDeletion'] as bool? ?? false,
          isTunnelExtension: cellData['isTunnelExtension'] as bool? ?? false,
          hasTrafficLight: cellData['hasTrafficLight'] as bool? ?? false,
          entrySide: cellData['entrySide'] != null ? Direction.values[cellData['entrySide'] as int] : null,
          isInfrastructureInternal: cellData['isInfrastructureInternal'] as bool? ?? false,
          isConnectableEndpoint: cellData['isConnectableEndpoint'] as bool? ?? false,
          infrastructureAxis: cellData['infrastructureAxis'] != null ? InfrastructureAxis.values[cellData['infrastructureAxis'] as int] : null,
          owner: owner,
        );

        final pos = GridPosition(x, y);
        if (type == CellType.house) houses.add(pos);
        if (type == CellType.destination) destinations.add(pos);

        // Rebuild infrastructure list (Including buildings for rendering)
        if (type != CellType.empty &&
            type != CellType.mountain &&
            type != CellType.water) {
          infrastructure.add(pos);
        }
      }
    }

    // [NEW] Best-effort axis restoration for legacy saves or missing axis
    for (final pos in infrastructure) {
      final cell = grid[pos.y][pos.x];
      if (cell.isConnectableEndpoint && cell.infrastructureAxis == null) {
        // Infer axis from neighbors
        final neighbors = [[0, 1], [0, -1], [1, 0], [-1, 0]];
        for (final d in neighbors) {
          final nx = pos.x + d[0];
          final ny = pos.y + d[1];
          if (isValid(nx, ny)) {
            final neighbor = grid[ny][nx];
            if (neighbor.isTunnel || neighbor.isBridge) {
              final axis = (d[0] == 0) ? InfrastructureAxis.vertical : InfrastructureAxis.horizontal;
              grid[pos.y][pos.x] = grid[pos.y][pos.x].copyWith(infrastructureAxis: axis);
              break;
            }
          }
        }
      }
    }

    // Express Lanes
    if (data['placedExpressLanes'] != null) {
      final mws = data['placedExpressLanes'] as List<dynamic>;
      for (final mw in mws) {
        try {
          final pair = mw as List<dynamic>;
          if (pair.length < 2) continue;
          placedExpressLanes.add([
            GridPosition(pair[0]['x'] as int, pair[0]['y'] as int),
            GridPosition(pair[1]['x'] as int, pair[1]['y'] as int),
          ]);
        } catch (_) {}
      }
    }

    // Driveways
    if (data['driveways'] != null) {
      final dws = data['driveways'] as Map<String, dynamic>;
      dws.forEach((key, value) {
        try {
          buildingDriveways[key] = GridPosition(value['x'] as int, value['y'] as int);
        } catch (_) {}
      });
    }

    // Inventory
    final inv = data['inventory'] as Map<String, dynamic>? ?? {};
    roads = inv['roads'] as int? ?? 0;
    tunnels = inv['tunnels'] as int? ?? 0;
    trafficLights = inv['trafficLights'] as int? ?? 0;
    smartJunctions = inv['smartJunctions'] as int? ?? 0;
    bridges = inv['bridges'] as int? ?? 0;
    expressLanes = inv['expressLanes'] as int? ?? 0;

    // Load demand/spawn timers
    if (data['demand'] != null) {
      final m = data['demand'] as Map<String, dynamic>;
      m.forEach((k, v) => demand[k] = v as int);
    }
    if (data['claimedDemand'] != null) {
      final m = data['claimedDemand'] as Map<String, dynamic>;
      m.forEach((k, v) => claimedDemand[k] = v as int);
    }
    if (data['demandTimers'] != null) {
      final m = data['demandTimers'] as Map<String, dynamic>;
      m.forEach((k, v) => demandTimers[k] = (v as num).toDouble());
    }
    if (data['overflowLevels'] != null) {
      final m = data['overflowLevels'] as Map<String, dynamic>;
      m.forEach((k, v) => overflowLevels[k] = (v as num).toDouble());
    }
    if (data['destinationAges'] != null) {
      final m = data['destinationAges'] as Map<String, dynamic>;
      m.forEach((k, v) => destinationAges[k] = v as int);
    }
    if (data['houseCarTimers'] != null) {
      final m = data['houseCarTimers'] as Map<String, dynamic>;
      m.forEach((k, v) => houseCarTimers[k] = (v as num).toDouble());
    } else {
      // Fallback
      for (final pos in houses) {
        houseCarTimers[_key(pos)] = 0;
      }
    }

    // [NEW] Restore Topology (Issue: Road Desync)
    activeEdges.clear();
    if (data['activeEdges'] != null) {
      final edges = data['activeEdges'] as List<dynamic>;
      for (final e in edges) {
        activeEdges.add(e as String);
      }
    }

    // [NEW] Reconstruct topology-dependent state
    rebuildRoadGraph();

    // [NEW] Reconstruct terrain clusters for rendering (Issue: Terrain Desync)
    reconstructTerrainState();
  }

  Map<String, dynamic> takeUndoSnapshot() {
    final gridCopy = List.generate(
      rows,
      (y) => List<GridCell>.from(grid[y]),
    );

    final expressLanesCopy = placedExpressLanes.map((pair) => List<GridPosition>.from(pair)).toList();

    return {
      'grid': gridCopy,
      'placedExpressLanes': expressLanesCopy,
      'roads': roads,
      'tunnels': tunnels,
      'bridges': bridges,
      'trafficLights': trafficLights,
      'smartJunctions': smartJunctions,
      'expressLanes': expressLanes,
      'activeEdges': Set<String>.from(activeEdges),
    };
  }

  void restoreUndoSnapshot(Map<String, dynamic> snapshot) {
    // Collect current connections/edges that belong to houses, destinations, or system-generated roads,
    // so they are not broken by the undo action.
    final systemEdges = <String>{};
    for (final edge in activeEdges) {
      final parts = edge.split('|');
      if (parts.length == 2) {
        final p1 = parts[0].split(',');
        final p2 = parts[1].split(',');
        if (p1.length == 2 && p2.length == 2) {
          final x1 = int.parse(p1[0]);
          final y1 = int.parse(p1[1]);
          final x2 = int.parse(p2[0]);
          final y2 = int.parse(p2[1]);
          if (isValid(x1, y1) && isValid(x2, y2)) {
            final c1 = grid[y1][x1];
            final c2 = grid[y2][x2];
            if (c1.isHouse || c1.isDestination || c1.owner == InfrastructureOwner.systemGenerated ||
                c2.isHouse || c2.isDestination || c2.owner == InfrastructureOwner.systemGenerated) {
              systemEdges.add(edge);
            }
          }
        }
      }
    }

    // Restore grid, avoiding overwriting houses, destinations, or system-generated roads
    final gridSource = snapshot['grid'] as List<List<GridCell>>;
    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        final currentCell = grid[y][x];
        if (currentCell.isHouse || 
            currentCell.isDestination || 
            currentCell.owner == InfrastructureOwner.systemGenerated) {
          continue;
        }
        grid[y][x] = gridSource[y][x];
      }
    }

    // Restore express lanes
    placedExpressLanes.clear();
    final expressLanesSource = snapshot['placedExpressLanes'] as List<List<GridPosition>>;
    for (final pair in expressLanesSource) {
      placedExpressLanes.add(List<GridPosition>.from(pair));
    }

    // Restore inventories
    roads = snapshot['roads'] as int;
    tunnels = snapshot['tunnels'] as int;
    bridges = snapshot['bridges'] as int;
    trafficLights = snapshot['trafficLights'] as int;
    smartJunctions = snapshot['smartJunctions'] as int;
    expressLanes = snapshot['expressLanes'] as int;

    // Restore edges
    activeEdges.clear();
    activeEdges.addAll(snapshot['activeEdges'] as Set<String>);
    // Merge back system/building edges
    activeEdges.addAll(systemEdges);

    // Reconstruct road graph and terrain state
    rebuildRoadGraph();
    reconstructTerrainState();
  }

  /// Rebuilds mountain clusters and terrain data from the current grid state
  void reconstructTerrainState() {
    mountainClusters.clear();
    final visited = <String>{};

    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        final pos = GridPosition(x, y);
        final key = _key(pos);
        if (grid[y][x].type == CellType.mountain && !visited.contains(key)) {
          // New cluster found
          final cluster = MountainCluster(pos);
          final queue = <GridPosition>[pos];
          visited.add(key);
          cluster.cells.add(pos);

          while (queue.isNotEmpty) {
            final current = queue.removeAt(0);
            for (final d in [[-1,0],[1,0],[0,-1],[0,1]]) {
              final nx = current.x + d[0];
              final ny = current.y + d[1];
              final nKey = "$nx,$ny";
              if (isValid(nx, ny) && 
                  grid[ny][nx].type == CellType.mountain && 
                  !visited.contains(nKey)) {
                visited.add(nKey);
                final nPos = GridPosition(nx, ny);
                cluster.cells.add(nPos);
                queue.add(nPos);
              }
            }
          }
          mountainClusters.add(cluster);
        }
      }
    }
    
    detectRegionsEndless();
    applyTerrainSpeeds();
  }

  bool isCellReserved(int x, int y) {
    if (!isValid(x, y)) return false;
    return grid[y][x].isReserved;
  }

  void reserveCell(int x, int y, bool reserved) {
    if (!isValid(x, y)) return;
    grid[y][x] = grid[y][x].copyWith(isReserved: reserved);
  }

  bool canBuildRoadAt(int x, int y) {
    if (!isValid(x, y)) return false;
    final cell = grid[y][x];
    // Can only build on empty, or replace existing road/tunnel/bridge
    return cell.isEmpty || cell.isRoad || cell.type == CellType.mountain || cell.type == CellType.water;
  }

  bool placeRoad(int x, int y, {GridPosition? from, InfrastructureOwner owner = InfrastructureOwner.player}) {
    if (!isValid(x, y)) return false;

    // [GUARD] Block player roads on tiles reserved for a staged (not-yet-committed) building.
    if (owner == InfrastructureOwner.player && (isStagedBuilding?.call(x, y) ?? false)) {
      return false;
    }
    
    // [HARD RULE] No grid modification during preview (Issue 4)
    assert(interactionState != InteractionState.preview, 'CRITICAL: GridManager.placeRoad called during PREVIEW phase at ($x,$y)');

    final cell = grid[y][x];
    final prevType = cell.type;
    
    // PART 3: Convert mountain to tunnel
    if (cell.type == CellType.mountain) {
      return placeTunnel(x, y, from: from, owner: owner);
    }

    // PART 4: Convert water to bridge
    if (cell.type == CellType.water) {
      if (selectedMapType == MapType.arctic) {
        // Let it fall through to place as an Ice Road
      } else {
        return placeBridge(x, y, from: from, owner: owner);
      }
    }
    
    bool isInfraEndpoint = (cell.isTunnel || cell.isBridge) && cell.isConnectableEndpoint;
    if (cell.type != CellType.empty && cell.type != CellType.road && cell.type != CellType.bridge && !isInfraEndpoint) {
      if (!(selectedMapType == MapType.arctic && cell.type == CellType.water)) {
        return false;
      }
    }

    // [STRICT] ROAD ACCOUNTING (Issue 1, 3 & 4)
    // Rule: Deduct 1 road if this action creates NEW connectivity, merges, or takes over system roads.
    // [FIX] Merge Double-Charge: Only charge for merges ONCE per gesture (Issue: Bug 1)
    int deducted = 0;
    bool isNewConnectivity = from != null && !hasEdge(from.x, from.y, x, y);
    // System-owned roads are exclusively building driveways. Treat them as a
    // free pass-through: the player did not pay for the driveway when the
    // building spawned, and they shouldn't be charged 1 road just to drag
    // their build cursor through it to reach the cell beyond.
    bool isSystemRoad = cell.type == CellType.road &&
        cell.owner == InfrastructureOwner.systemGenerated;

    if (owner == InfrastructureOwner.player) {
      // [STRICT RULE] Only deduct 1 road if the tile is currently empty.
      // Merges and infra-exits do NOT cost extra if they land on an existing road.
      if (cell.isEmpty || (selectedMapType == MapType.arctic && cell.type == CellType.water)) {
        if (roads <= 0) return false;
        deducted = 1;
        spendRoads(1);
      } else if (isNewConnectivity && !_hasChargedMergeThisGesture && !isSystemRoad) {
        // [FIX] Merge costing: Charge exactly 1 road for the FIRST merge connection in a gesture
        if (roads <= 0) return false;
        deducted = 1;
        spendRoads(1);
        _hasChargedMergeThisGesture = true;
      } else {
        // [FIX] Already charged for merge, a system driveway pass-through, or just adding another segment
        deducted = 0;
      }
    }

    if (GameConstants.debugInfrastructure) {
      debugPrint('[ROAD_COST] pos=($x,$y) prev=${prevType.name} new=ROAD owner=${owner.name} state=${interactionState.name} deducted=$deducted');
    }

    // [STRICT] OWNERSHIP PIPELINE
    // Driveways (system roads) stay system-owned even when a player drag
    // passes over them — the player paid nothing for them above, so erase
    // should not refund a player road either.
    InfrastructureOwner finalOwner = isSystemRoad ? cell.owner : owner;

    // [ASSERT] Catch system-generated leaks (Issue 4)
    // Rule: systemGenerated roads must NEVER be committed to the grid during PREVIEW.
    assert(
      !(finalOwner == InfrastructureOwner.systemGenerated && 
        interactionState == InteractionState.preview),
      'CRITICAL LEAK: systemGenerated owner committed to grid during preview phase!'
    );

    // Rule: player-initiated preview must NEVER modify the grid.
    assert(
      interactionState != InteractionState.preview,
      'CRITICAL LEAK: GridManager.placeRoad called during PREVIEW phase at ($x,$y)'
    );

    // Create or update the road cell (Non-destructive for existing infra)
    CellType finalType = cell.type;
    bool finalIsIceRoad = cell.isIceRoad;
    if (cell.isEmpty || cell.owner == InfrastructureOwner.systemGenerated || (selectedMapType == MapType.arctic && cell.type == CellType.water)) {
      finalType = CellType.road;
      if (selectedMapType == MapType.arctic && cell.type == CellType.water) {
        finalIsIceRoad = true;
      }
    } else if (cell.isTunnel || cell.isBridge) {
      // [STRICT] Never overwrite tunnel or bridge core with a road
      finalType = cell.type;
    }

    grid[y][x] = cell.copyWith(type: finalType, owner: finalOwner, isIceRoad: finalIsIceRoad);
    final pos = GridPosition(x, y);
    if (!infrastructure.contains(pos)) {
      infrastructure.add(pos);
    }

    if (from != null) {
      addEdge(from.x, from.y, x, y);
      updateNodeConnections(from.x, from.y);
    }

    updateNodeConnections(x, y);
    // _resolveConnectivity(x, y); // Removed to ensure no side-effect reverts
    onTopologyChanged?.call(); // [NEW] Notify path cache invalidation
    return true;
  }

  bool placeTunnel(int x, int y, {bool isExtension = false, bool consumeRoad = false, GridPosition? from, InfrastructureOwner owner = InfrastructureOwner.player}) {
    return _placeTransitCorridor(x, y, CellType.tunnel, isExtension: isExtension, consumeRoad: consumeRoad, from: from, owner: owner);
  }

  bool placeBridge(int x, int y, {bool isExtension = false, bool consumeRoad = false, GridPosition? from, InfrastructureOwner owner = InfrastructureOwner.player}) {
    return _placeTransitCorridor(x, y, CellType.bridge, isExtension: isExtension, consumeRoad: consumeRoad, from: from, owner: owner);
  }

  /// [NEW] Unified Transit Logic (Issue 4)
  /// Handles shared logic for Tunnels and Bridges: endpoints, orientation, validation.
  bool _placeTransitCorridor(int x, int y, CellType type, {bool isExtension = false, bool consumeRoad = false, GridPosition? from, InfrastructureOwner owner = InfrastructureOwner.player}) {
    if (!isValid(x, y)) return false;
    if (from == null) return false;
    
    // [HARD RULE] No grid modification during preview
    assert(interactionState != InteractionState.preview, 'CRITICAL: GridManager._placeTransitCorridor called during PREVIEW phase at ($x,$y)');

    if (type == CellType.bridge && selectedMapType == MapType.arctic) {
      return false;
    }

    final cell = grid[y][x];
    final validSurface = (type == CellType.tunnel) ? CellType.mountain : CellType.water;
    
    // [FIX] Tunnel Exit / Land Extension (Issue 3)
    // If we are extending a tunnel/bridge onto land, it becomes a ROAD.
    if (isExtension && cell.type != validSurface && cell.type != type) {
       return placeRoad(x, y, from: from, owner: owner);
    }

    if (cell.type != validSurface && cell.type != type) {
      return false;
    }

    // Overlap Protection (Relaxed for extensions to improve Zen consistency)
    if (!isExtension && cell.type == type) {
       return false;
    }

    // Proximity Protection — only reject if a same-type tile exists at a
    // neighbour that is NOT on the from→pos axis. Two tiles along the same
    // axis are just extending the corridor; a cross-axis tile is a conflict.
    if (!isExtension) {
      final axisH = (from.x != x); // horizontal movement = horizontal axis
      for (final d in const [[0, -1], [1, 0], [0, 1], [-1, 0]]) {
        final nx = x + d[0];
        final ny = y + d[1];
        if (nx == from.x && ny == from.y) continue; // skip the 'from' cell
        if (!isValid(nx, ny)) continue;
        if (grid[ny][nx].type != type) continue;
        // Same-axis neighbour = continuation of same corridor, allow it.
        final neighbourAxisH = (d[0] != 0);
        if (neighbourAxisH == axisH) continue;
        // Cross-axis tunnel/bridge tile found — reject.
        return false;
      }
    }

    // Inventory Guard (Player-owned, new tunnel/bridge only).
    // Without this, spendTunnel / spendBridge silently push the counter negative.
    if (owner == InfrastructureOwner.player && !isExtension) {
      if (type == CellType.tunnel && tunnels <= 0) return false;
      if (type == CellType.bridge && bridges <= 0) return false;
    }

    final dist = (from.x - x).abs() + (from.y - y).abs();
    if (dist != 1) return false;

    final axis = (from.x == x) ? InfrastructureAxis.vertical : InfrastructureAxis.horizontal;

    // Enforce straight-line rule: no bending tunnels/bridges
    final fromCell = getCell(from.x, from.y);
    if (fromCell.type == type) {
      if (fromCell.infrastructureAxis != null && fromCell.infrastructureAxis != axis) {
        return false;
      }
    }

    // Enforce maximum length of 4 tiles
    {
      int len = 1;
      final d1 = (axis == InfrastructureAxis.vertical) ? const [0, -1] : const [-1, 0];
      int cx = x + d1[0];
      int cy = y + d1[1];
      while (isValid(cx, cy) && grid[cy][cx].type == type) {
        len++;
        cx += d1[0];
        cy += d1[1];
      }
      final d2 = (axis == InfrastructureAxis.vertical) ? const [0, 1] : const [1, 0];
      cx = x + d2[0];
      cy = y + d2[1];
      while (isValid(cx, cy) && grid[cy][cx].type == type) {
        len++;
        cx += d2[0];
        cy += d2[1];
      }
      if (len > 4) {
        return false;
      }
    }

    // Portal Preservation
    if (fromCell.type == type) {
      bool isPortal = _countExternalConnections(from.x, from.y) > 0;
      grid[from.y][from.x] = fromCell.copyWith(
        isInfrastructureInternal: !isPortal,
        isConnectableEndpoint: isPortal,
        infrastructureAxis: fromCell.infrastructureAxis ?? axis,
      );
    }
    
    // Inventory Transaction
    int roadDeducted = 0;
    if (owner == InfrastructureOwner.player) {
      if (!isExtension) {
        if (type == CellType.tunnel) {
          spendTunnel(1);
        } else {
          spendBridge(1);
        }
      } else if (consumeRoad) {
        // [FIX] Tunnel Extension Costing (Bug 2)
        if (roads <= 0) return false;
        roadDeducted = 1;
        spendRoads(1);
      }
    }

    if (roadDeducted > 0 && GameConstants.debugInfrastructure) {
      debugPrint('[ROAD_COST] pos=($x,$y) prev=${type.name} new=${type.name} owner=${owner.name} state=${interactionState.name} deducted=$roadDeducted');
    }

    // [STRICT] Ownership Rule: Tunnels/Bridges are infrastructure (system-owned by default).
    // They are ONLY created through terrain (mountain/water).
    // Extensions over land are handled by placeRoad directly.
    InfrastructureOwner corridorOwner = owner;

    grid[y][x] = cell.copyWith(
      type: type,
      isTunnelExtension: isExtension,
      isInfrastructureInternal: false, 
      isConnectableEndpoint: true, // Initially an endpoint until more are added
      infrastructureAxis: axis,
      speedMultiplier: (type == CellType.tunnel) ? GameConstants.tunnelSpeedBonus : 1.0,
      owner: corridorOwner,
    );
    
    final pos = GridPosition(x, y);
    if (!infrastructure.contains(pos)) {
      infrastructure.add(pos);
    }

    addEdge(from.x, from.y, x, y);
    updateNodeConnections(from.x, from.y);

    // Auto-wire to any adjacent road.
    for (final d in const [[0, -1], [1, 0], [0, 1], [-1, 0]]) {
      final nx = x + d[0];
      final ny = y + d[1];
      if (!isValid(nx, ny)) continue;
      if (from.x == nx && from.y == ny) continue;
      if (grid[ny][nx].type == CellType.road && !hasEdge(x, y, nx, ny)) {
        addEdge(x, y, nx, ny);
        updateNodeConnections(nx, ny);
      }
    }

    updateNodeConnections(x, y);
    // _resolveConnectivity(x, y); // Removed to prevent side-effect reverts

    if (type == CellType.tunnel || type == CellType.bridge) _cleanOrphanRoads();
    
    onTopologyChanged?.call(); // [NEW] Notify path cache invalidation
    return true;
  }



  void updateNodeConnections(int x, int y) {
    if (!isValid(x, y)) return;
    final currentCell = grid[y][x];

    if (!currentCell.isPassable && !currentCell.isHouse && !currentCell.isDestination) {
      return;
    }

    bool up = false, right = false, down = false, left = false;

    const offsets = [
      [0, -1], // North
      [1, 0], // East
      [0, 1], // South
      [-1, 0], // West
    ];
    final dirs = [
      Direction.north,
      Direction.east,
      Direction.south,
      Direction.west,
    ];

    for (int i = 0; i < 4; i++) {
      final nx = x + offsets[i][0];
      final ny = y + offsets[i][1];
      if (!isValid(nx, ny)) continue;

      if (hasEdge(x, y, nx, ny)) {
        final neighborCell = grid[ny][nx];
        
        // Rule: No active connections if either side is pending deletion
        bool canConnect = !currentCell.isPendingDeletion && !neighborCell.isPendingDeletion;

        // [STRICT PORT LOGIC] Enforce building isolation (Bug #2 Fix)
        // Buildings are ENDPOINTS ONLY. They only connect on their defined entrySide.
        if (currentCell.isHouse || currentCell.isDestination) {
          if (dirs[i] != currentCell.entrySide) {
            canConnect = false;
          }
        }
        
        // Neighbor Port Logic: If neighbor is a building, only connect if we are at its port
        if (neighborCell.isHouse || neighborCell.isDestination) {
          final oppositeDir = dirs[(i + 2) % 4];
          if (oppositeDir != neighborCell.entrySide) {
            canConnect = false;
          }
        }

        // [NEW] Corridor Protection: 
        // Standard roads can ONLY connect to Tunnel/Bridge ENDPOINTS (isConnectableEndpoint).
        // Connections to internal corridor tiles are strictly blocked.
        if (currentCell.type == CellType.road && (neighborCell.isTunnel || neighborCell.isBridge)) {
          if (!neighborCell.isConnectableEndpoint) canConnect = false;
        }
        if (neighborCell.type == CellType.road && (currentCell.isTunnel || currentCell.isBridge)) {
          if (!currentCell.isConnectableEndpoint) canConnect = false;
        }

        if (canConnect) {
          if (i == 0) up = true;
          if (i == 1) right = true;
          if (i == 2) down = true;
          if (i == 3) left = true;
        }
      }
    }

    grid[y][x] = currentCell.copyWith(
      connUp: up,
      connDown: down,
      connLeft: left,
      connRight: right,
    );
  }

  void rebuildRoadGraph() {
    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        final cell = grid[y][x];
        if (cell.isPassable || cell.isHouse || cell.isDestination) {
          updateNodeConnections(x, y);
        }
      }
    }
    onTopologyChanged?.call(); // [NEW] Notify path cache invalidation
  }


  bool placeExpressLane(GridPosition start, GridPosition end, {InfrastructureOwner owner = InfrastructureOwner.player}) {
    // print('[EXPRESSWAY] Attempting placement: ${start.key} -> ${end.key}');
    
    // 1. Validation
    if (!isValid(start.x, start.y) || !isValid(end.x, end.y)) {
      // print('[EXPRESSWAY] FAILED: Invalid coordinates');
      return false;
    }
    
    final startCell = grid[start.y][start.x];
    final endCell = grid[end.y][end.x];
    
    if (!startCell.isRoad && !startCell.isEmpty && !startCell.isExpressLaneNode) {
       // print('[EXPRESSWAY] FAILED: Start point ${start.key} is occupied by ${startCell.type.name}');
       return false;
    }
    if (!endCell.isRoad && !endCell.isEmpty && !endCell.isExpressLaneNode) {
       // print('[EXPRESSWAY] FAILED: End point ${end.key} is occupied by ${endCell.type.name}');
       return false;
    }

    if (start.manhattanDistance(end) < 2) {
      // print('[EXPRESSWAY] FAILED: Points too close');
      return false;
    }

    // Inventory gate: an express lane is a paid item, one inventory point
    // per pair of endpoints. Without this check the player could drop any
    // number of expressways for free.
    if (owner == InfrastructureOwner.player && expressLanes <= 0) {
      return false;
    }

    // Capture whether each endpoint was on an existing road BEFORE the
    // overpass commit. We use this below to gate auto-connectivity: if the
    // endpoint is already a road its existing edges are the ones the
    // player intended, and we shouldn't silently splice in fresh edges to
    // every adjacent road tile (which used to merge two parallel road
    // networks together the moment a lane endpoint landed between them).
    final startWasEmpty = startCell.isEmpty;
    final endWasEmpty = endCell.isEmpty;

    // 2. Commit Overpass Property (Layered)
    grid[start.y][start.x] = startCell.copyWith(
      overpass: OverpassType.start,
      speedMultiplier: GameConstants.expressLaneSpeed,
      isExpressLane: true,
      upgradeOwner: owner,
    );
    grid[end.y][end.x] = endCell.copyWith(
      overpass: OverpassType.end,
      speedMultiplier: GameConstants.expressLaneSpeed,
      isExpressLane: true,
      upgradeOwner: owner,
    );

    infrastructure.add(start);
    infrastructure.add(end);

    // 3. Commit Graph Edge
    placedExpressLanes.add([start, end]);

    // 4. Automatic Connectivity (Rule 5) — only for endpoints that landed
    //    on previously empty cells.
    if (startWasEmpty) _connectExpressToRoad(start);
    if (endWasEmpty) _connectExpressToRoad(end);

    if (owner == InfrastructureOwner.player) {
      expressLanes -= 1;
    }

    // print('[EXPRESSWAY] COMMITTED: Success from ${start.key} to ${end.key}');
    return true;
  }

  void _connectExpressToRoad(GridPosition pos) {
    for (final d in [
      [0, -1],
      [1, 0],
      [0, 1],
      [-1, 0],
    ]) {
      final nx = pos.x + d[0];
      final ny = pos.y + d[1];
      if (isValid(nx, ny) && grid[ny][nx].isRoad) {
        addEdge(pos.x, pos.y, nx, ny);
        updateNodeConnections(nx, ny);
        updateNodeConnections(pos.x, pos.y);
      }
    }
  }



  /// Handles strict single-entry logic for buildings
  void connectBuilding(int bx, int by, int rx, int ry) {
    if (!isValid(bx, by) || !isValid(rx, ry)) return;
    final cell = grid[by][bx];
    if (!cell.isHouse && !cell.isDestination) return;

    final dx = rx - bx;
    final dy = ry - by;
    Direction? side;
    if (dx > 0) {
      side = Direction.east;
    } else if (dx < 0) {
      side = Direction.west;
    } else if (dy > 0) {
      side = Direction.south;
    } else if (dy < 0) {
      side = Direction.north;
    }

    if (side == null) return;

    if (cell.isDestination) {
      // RULE: DESTINATION houses have FIXED entry sides. REJECT connections from other sides.
      if (side != cell.entrySide) {
        return; 
      }
      
      // Destination entry side matches - allow connection
      addEdge(bx, by, rx, ry);
      buildingDriveways[_key(GridPosition(bx, by))] = GridPosition(rx, ry);
    } else if (cell.isHouse) {
      // RULE: DRIVEWAY IS A NORMAL ROAD TILE
      if (side != cell.entrySide) {
        return;
      }
      
      // [NON-DESTRUCTIVE] Do NOT call removeEdgesFor here. (Architecture 1 Fix)
      // We only want to ADD the building connection, not wipe the existing road network.
      addEdge(bx, by, rx, ry);
      
      
      buildingDriveways[_key(GridPosition(bx, by))] = GridPosition(rx, ry);
    }

    updateNodeConnections(rx, ry);
    updateNodeConnections(bx, by);
  }


  @Deprecated('Use connectBuilding instead')
  void forceConnectBuilding(int bx, int by, int rx, int ry) {
    connectBuilding(bx, by, rx, ry);
  }

  bool placeTrafficLight(int x, int y, {InfrastructureOwner owner = InfrastructureOwner.player}) {
    if (!isValid(x, y)) return false;
    final cell = grid[y][x];
    if (!cell.isRoad) return false;
    if (cell.hasTrafficLight) return false;

    grid[y][x] = cell.copyWith(
      hasTrafficLight: true,
      isPendingDeletion: cell.isPendingDeletion,
      owner: owner,
    );

    final pos = GridPosition(x, y);
    if (!infrastructure.contains(pos)) {
      infrastructure.add(pos);
    }
    return true;
  }

  String removeInfrastructure(int x, int y) {
    if (!isValid(x, y)) return '';
    final cell = grid[y][x];
    if (cell.isEmpty || cell.isPendingDeletion) return '';

    // [FIX] Road Deletion near Houses
    // We no longer protect "driveway" tiles. Players can delete any road segment.
    // However, we still log it for debugging.
    final pos = GridPosition(x, y);
    if (isLockedEntrance(pos)) {
    }

    if (cell.hasTrafficLight) {
      grid[y][x] = GridCell(
        type: cell.type,
        hasTrafficLight: true,
        isPendingDeletion: true,
      );
      return 'trafficLight';
    }

    if (cell.type == CellType.road) {
      grid[y][x] = cell.copyWith(isPendingDeletion: true);
      rebuildRoadGraph();
      return 'road';
    } else if (cell.type == CellType.tunnel) {
      grid[y][x] = cell.copyWith(isPendingDeletion: true);
      rebuildRoadGraph();
      return 'tunnel';
    } else if (cell.type == CellType.smartJunction) {
      grid[y][x] = GridCell(
        type: CellType.smartJunction,
        isPendingDeletion: true,
      );
      rebuildRoadGraph();
      return 'smartJunction';
    } else if (cell.isExpressLaneNode) {
      final pos = GridPosition(x, y);
      List<GridPosition>? mwToRemove;
      for (final mw in placedExpressLanes) {
        if (mw[0] == pos || mw[1] == pos) {
          mwToRemove = mw;
          break;
        }
      }
      if (mwToRemove != null) {
        // Immediate removal from graph
        placedExpressLanes.remove(mwToRemove);
        removeEdge(mwToRemove[0].x, mwToRemove[0].y, mwToRemove[1].x, mwToRemove[1].y);
        
        final startCell = grid[mwToRemove[0].y][mwToRemove[0].x];
        final endCell = grid[mwToRemove[1].y][mwToRemove[1].x];

        // Refund Rule: Only if player owned
        final needsRefund = startCell.upgradeOwner == InfrastructureOwner.player;

        grid[mwToRemove[0].y][mwToRemove[0].x] = startCell.copyWith(
          overpass: OverpassType.none,
          isExpressLane: false,
          speedMultiplier: 1.0,
          upgradeOwner: InfrastructureOwner.none,
        );
        grid[mwToRemove[1].y][mwToRemove[1].x] = endCell.copyWith(
          overpass: OverpassType.none,
          isExpressLane: false,
          speedMultiplier: 1.0,
          upgradeOwner: InfrastructureOwner.none,
        );
        
        // Clean up infrastructure list ONLY if now truly empty
        if (grid[mwToRemove[0].y][mwToRemove[0].x].isEmpty) {
          infrastructure.remove(mwToRemove[0]);
        }
        if (grid[mwToRemove[1].y][mwToRemove[1].x].isEmpty) {
          infrastructure.remove(mwToRemove[1]);
        }
        
        return needsRefund ? 'expressLane' : 'expressLaneNoRefund';
      }
    }
    return '';
  }

  void cancelPendingDeletion(int x, int y) {
    if (!isValid(x, y)) return;
    final cell = grid[y][x];
    if (cell.isPendingDeletion) {
      grid[y][x] = cell.copyWith(isPendingDeletion: false);
    }
  }

  void forceRemoveInfrastructure(int x, int y) {
    if (!isValid(x, y)) return;
    final cell = grid[y][x];
    if (cell.type == CellType.tunnel) {
      grid[y][x] = GridCell(type: CellType.mountain);
    } else if (cell.type == CellType.bridge || cell.isIceRoad) {
      grid[y][x] = GridCell(type: CellType.water);
    } else {
      grid[y][x] = GridCell();
    }
    infrastructure.remove(GridPosition(x, y));
    removeEdgesFor(x, y);
  }

  void removeEdgesFor(int x, int y) {
    final search = "$x,$y";
    
    // Identify if this tile is a driveway for any building to protect that specific edge
    GridPosition? ownerBuilding;
    for (final house in houses) {
      if (buildingDriveways[house.key] == GridPosition(x, y)) {
        ownerBuilding = house;
        break;
      }
    }
    for (final dest in destinations) {
      if (buildingDriveways[dest.key] == GridPosition(x, y)) {
        ownerBuilding = dest;
        break;
      }
    }

    activeEdges.removeWhere((key) {
      final parts = key.split('|');
      bool isMatch = parts[0] == search || parts[1] == search;
      if (!isMatch) return false;
      
      // [RULE 5] Protect the house-driveway edge
      if (ownerBuilding != null) {
        if (parts[0] == ownerBuilding.key || parts[1] == ownerBuilding.key) {
          return false; // Preserve the link to the building
        }
      }
      
      return true;
    });
  }

  /// Returns a map of type -> count of tiles actually removed
  Map<String, int> cleanupPendingDeletions(Set<GridPosition> activeCarTiles) {
    final refunds = <String, int>{};
    final toRemove = <GridPosition>[];
    for (final pos in infrastructure) {
      if (grid[pos.y][pos.x].isPendingDeletion) {
        if (!activeCarTiles.contains(pos)) {
          toRemove.add(pos);
        }
      }
    }

    if (toRemove.isEmpty) return refunds;

    for (final pos in toRemove) {
      final cell = grid[pos.y][pos.x];
      if (cell.isExpressLaneNode) {
        placedExpressLanes.removeWhere((mw) => mw[0] == pos || mw[1] == pos);
        // Clear overpass property
        grid[pos.y][pos.x] = cell.copyWith(
          overpass: OverpassType.none,
          isExpressLane: false,
        );
      }

      removeEdgesFor(pos.x, pos.y);
      if (cell.connUp && isValid(pos.x, pos.y - 1)) {
        grid[pos.y - 1][pos.x] = grid[pos.y - 1][pos.x].copyWith(
          connDown: false,
        );
      }
      if (cell.connDown && isValid(pos.x, pos.y + 1)) {
        grid[pos.y + 1][pos.x] = grid[pos.y + 1][pos.x].copyWith(connUp: false);
      }
      if (cell.connLeft && isValid(pos.x - 1, pos.y)) {
        grid[pos.y][pos.x - 1] = grid[pos.y][pos.x - 1].copyWith(
          connRight: false,
        );
      }
      if (cell.connRight && isValid(pos.x + 1, pos.y)) {
        grid[pos.y][pos.x + 1] = grid[pos.y][pos.x + 1].copyWith(
          connLeft: false,
        );
      }

      if (cell.type == CellType.road ||
          cell.type == CellType.tunnel ||
          cell.isPendingDeletion) {
        buildingDriveways.removeWhere((key, drivewayPos) => drivewayPos == pos);
      }

      if (cell.hasTrafficLight) {
        grid[pos.y][pos.x] = grid[pos.y][pos.x].copyWith(
          hasTrafficLight: false,
        );
        if (cell.owner == InfrastructureOwner.player) {
          refunds['trafficLight'] = (refunds['trafficLight'] ?? 0) + 1;
        }
      }

      if (cell.type == CellType.tunnel) {
        grid[pos.y][pos.x] = GridCell(type: CellType.mountain);
        infrastructure.remove(pos);
        
        // [FIX] Portal Refund Rule: Endpoints are free connectors (NONE). 
        // Only internal corridor segments refund tunnels.
        if (cell.connectionType == ConnectionNodeType.corridorInternal) {
          if (cell.owner == InfrastructureOwner.player && !cell.isTunnelExtension) {
            refunds['tunnel'] = (refunds['tunnel'] ?? 0) + 1;
          }
        }
      } else if (cell.type == CellType.bridge) {
        grid[pos.y][pos.x] = GridCell(type: CellType.water);
        infrastructure.remove(pos);
        if (cell.connectionType == ConnectionNodeType.corridorInternal) {
          if (cell.owner == InfrastructureOwner.player && !cell.isTunnelExtension) {
            refunds['bridge'] = (refunds['bridge'] ?? 0) + 1;
          }
        }
      } else if (cell.type == CellType.road) {
        grid[pos.y][pos.x] = GridCell();
        infrastructure.remove(pos);
        if (cell.owner == InfrastructureOwner.player) {
          refunds['road'] = (refunds['road'] ?? 0) + 1;
        }
      } else if (cell.type == CellType.smartJunction) {
        grid[pos.y][pos.x] = GridCell();
        infrastructure.remove(pos);
        if (cell.owner == InfrastructureOwner.player) {
          refunds['smartJunction'] = (refunds['smartJunction'] ?? 0) + 1;
        }
      } else {
        grid[pos.y][pos.x] = GridCell();
        infrastructure.remove(pos);
      }

      // [NEW] Promotion Logic: If we deleted a tile, its neighbors might now be endpoints
      final dirs = [[0,1],[0,-1],[1,0],[-1,0]];
      for (final d in dirs) {
        final nx = pos.x + d[0];
        final ny = pos.y + d[1];
        if (isValid(nx, ny)) {
          final neighbor = grid[ny][nx];
          if (neighbor.isInfrastructureInternal && (neighbor.isTunnel || neighbor.isBridge)) {
            // Re-evaluate if it should still be internal
            // Count neighbors of same type
            int sameTypeNeighbors = 0;
            for (final d2 in dirs) {
              final nnx = nx + d2[0];
              final nny = ny + d2[1];
              if (isValid(nnx, nny) && grid[nny][nnx].type == neighbor.type) {
                sameTypeNeighbors++;
              }
            }
            if (sameTypeNeighbors < 2) {
              // Find the direction of the only remaining neighbor to determine axis
              InfrastructureAxis? axis;
              for (final d2 in dirs) {
                final nnx = nx + d2[0];
                final nny = ny + d2[1];
                if (isValid(nnx, nny) && grid[nny][nnx].type == neighbor.type) {
                  axis = (d2[0] == 0) ? InfrastructureAxis.vertical : InfrastructureAxis.horizontal;
                  break;
                }
              }
              grid[ny][nx] = neighbor.copyWith(
                isInfrastructureInternal: false,
                isConnectableEndpoint: true,
                infrastructureAxis: axis,
              );
            }
          }
        }
      }
    }
    if (toRemove.isNotEmpty) {
      // [OPTIMIZED] Localized graph updates instead of full rebuild
      for (final pos in toRemove) {
        updateNodeConnections(pos.x, pos.y);
        for (final d in [[0,1],[0,-1],[1,0],[-1,0]]) {
          updateNodeConnections(pos.x + d[0], pos.y + d[1]);
        }
      }
      onTopologyChanged?.call(); // [NEW] Notify path cache invalidation
    }
    return refunds;
  }

  /// Place a 1x1 smart junction at (x, y).
  bool placeSmartJunction(int x, int y, {InfrastructureOwner owner = InfrastructureOwner.player}) {
    if (!isValid(x, y)) return false;
    final cell = grid[y][x];

    if (cell.type != CellType.empty && cell.type != CellType.road) return false;

    grid[y][x] = GridCell(type: CellType.smartJunction, owner: owner);
    final pos = GridPosition(x, y);
    infrastructure.add(pos);

    const offsets = [
      [0, -1],
      [1, 0],
      [0, 1],
      [-1, 0],
    ];
    for (var off in offsets) {
      final nx = x + off[0];
      final ny = y + off[1];
      if (isValid(nx, ny)) {
        final neighbor = grid[ny][nx];
        if (neighbor.isPassable) {
          addEdge(x, y, nx, ny);
          updateNodeConnections(nx, ny);
        } else if (neighbor.isHouse || neighbor.isDestination) {
          connectBuilding(nx, ny, x, y);
        }
      }
    }

    updateNodeConnections(x, y);
    onTopologyChanged?.call();
    return true;
  }

  bool placeExpressLaneNode(int x, int y, {InfrastructureOwner owner = InfrastructureOwner.player}) {
    final pos = GridPosition(x, y);
    // print('[EXPRESSWAY] INTERACTION at ${pos.key}');

    if (_pendingExpressLaneStart == null) {
      // PHASE 1: START SELECTION
      // print('[EXPRESSWAY] START SELECTION triggered at ${pos.key}');
      final cell = grid[y][x];
      
      // Endpoints must be roads or empty or existing stubs
      if (!cell.isRoad && !cell.isEmpty && !cell.isExpressLaneNode) {
        // print('[EXPRESSWAY] FAILED: Start point ${pos.key} is invalid (Type: ${cell.type.name})');
        return false;
      }
      
      _pendingExpressLaneStart = pos;
      // print('[EXPRESSWAY] START SELECTED: ${pos.key}. Mode: Waiting for end point.');
      return false; 
    } else {
      // PHASE 2: END SELECTION
      // print('[EXPRESSWAY] END SELECTION triggered at ${pos.key}');
      
      if (_pendingExpressLaneStart == pos) {
        // print('[EXPRESSWAY] ACTION: Cancelled (same node clicked)');
        cancelExpressLanePlacement();
        return false;
      }

      // print('[EXPRESSWAY] VALIDATING endpoints: ${_pendingExpressLaneStart!.key} -> ${pos.key}');
      final success = placeExpressLane(_pendingExpressLaneStart!, pos, owner: owner);
      
      if (success) {
        // print('[EXPRESSWAY] COMMITTED: Placement successful. Consuming resource.');
        _pendingExpressLaneStart = null; 
        return true;
      } else {
        // print('[EXPRESSWAY] FAILED: Internal validation rejected placement.');
        // We keep the start node selected so the user can try a different end node
        return false;
      }
    }
  }

  void cancelExpressLanePlacement() {
    // print('[EXPRESSWAY] State reset: Clearing pending start node.');
    _pendingExpressLaneStart = null;
  }

  void placeHouse(int x, int y, int colorIndex, Direction entrySide) {
    if (!isValid(x, y)) return;
    final pos = GridPosition(x, y);
    final key = _key(pos);

    // [CRITICAL] Prevent Role Contamination (Issue 3)
    // If we are placing a house, it MUST NOT be in the destinations list or have demand
    destinations.removeWhere((p) => p.x == x && p.y == y);
    demand.remove(key);
    demandTimers.remove(key);
    overflowLevels.remove(key);

    grid[y][x] = GridCell(
      type: CellType.house,
      colorIndex: colorIndex,
      entrySide: entrySide,
    );
    
    houses.add(pos);
    infrastructure.add(pos); // [FIX] Add to infrastructure for rendering
    houseCarTimers[key] = 0;
  }

  void placeDestination(int x, int y, int colorIndex, Direction entrySide, {String? name}) {
    if (!isValid(x, y)) return;
    final pos = GridPosition(x, y);
    final key = _key(pos);

    // [CRITICAL] Prevent Role Contamination (Issue 3)
    // If we are placing a destination, it MUST NOT be in the houses list
    houses.removeWhere((p) => p.x == x && p.y == y);
    houseCarTimers.remove(key);

    grid[y][x] = GridCell(
      type: CellType.destination,
      colorIndex: colorIndex,
      entrySide: entrySide,
    );
    
    destinations.add(pos);
    infrastructure.add(pos); // [FIX] Add to infrastructure for rendering

    // Start at 0 demand and pre-load the demand timer so the first +1 fires
    // ~4s later. Without this, a brand-new destination shows a demand pip the
    // instant it appears and the demand-pressure planner can queue an extra
    // house spawn before the player has had a chance to react (or before the
    // staged second house from the initial district has even landed).
    const double initialDemandGrace = 4.0;
    final preloadedTimer = GameConstants.demandTickInterval - initialDemandGrace;
    demand[key] = 0;
    demandTimers[key] = preloadedTimer.clamp(0.0, GameConstants.demandTickInterval);
    if (name != null) districtNames[key] = name;
  }

  void setDemand(GridPosition pos, int val) => demand[_key(pos)] = val;

  int getClaimedDemand(GridPosition pos) => claimedDemand[_key(pos)] ?? 0;
  void setClaimedDemand(GridPosition pos, int val) =>
      claimedDemand[_key(pos)] = val;

  double getDemandTimer(GridPosition pos) => demandTimers[_key(pos)] ?? 0;

  void setDemandTimer(GridPosition pos, double value) {
    demandTimers[_key(pos)] = value;
  }

  double getHouseCarTimer(GridPosition pos) => houseCarTimers[_key(pos)] ?? 0;

  void setHouseCarTimer(GridPosition pos, double value) {
    houseCarTimers[_key(pos)] = value;
  }

  List<GridPosition> getNeighbors(int x, int y, {GridPosition? target}) {
    final neighbors = <GridPosition>[];
    final currentCell = grid[y][x];

    // Orthogonal neighbors ONLY (N, E, S, W)
    if (currentCell.connUp && isValid(x, y - 1)) {
      neighbors.add(GridPosition(x, y - 1));
    }
    if (currentCell.connRight && isValid(x + 1, y)) {
      neighbors.add(GridPosition(x + 1, y));
    }
    if (currentCell.connDown && isValid(x, y + 1)) {
      neighbors.add(GridPosition(x, y + 1));
    }
    if (currentCell.connLeft && isValid(x - 1, y)) {
      neighbors.add(GridPosition(x - 1, y));
    }

    // Smart Junction (internal moves handled by pathfinder sub-nodes)
    if (currentCell.type == CellType.smartJunction) {
      // conn bits handle connectivity
    }

    // Express Lane shortcuts (NOT teleport â€” just connectivity)
    for (final mw in placedExpressLanes) {
      if (x == mw[0].x && y == mw[0].y) {
        neighbors.add(mw[1]);
      } else if (x == mw[1].x && y == mw[1].y) {
        neighbors.add(mw[0]);
      }
    }

    return neighbors;
  }

  List<bool> getAdjacentPassable(int x, int y) {
    final cell = grid[y][x];
    return [
      cell.connUp,
      cell.connRight,
      cell.connDown,
      cell.connLeft,
      false, false, false, false, // No diagonals
    ];
  }

  List<GridPosition> getEmptyCells({
    int? minX,
    int? maxX,
    int? minY,
    int? maxY,
  }) {
    final empty = <GridPosition>[];
    final startX = minX ?? 0;
    final endX = maxX ?? cols;
    final startY = minY ?? 0;
    final endY = maxY ?? rows;

    for (int y = startY; y < endY; y++) {
      for (int x = startX; x < endX; x++) {
        if (isValid(x, y) && grid[y][x].isEmpty) {
          empty.add(GridPosition(x, y));
        }
      }
    }
    return empty;
  }

  List<GridPosition> getDestinationsForColor(int colorIndex) {
    return destinations
        .where((d) => grid[d.y][d.x].colorIndex == colorIndex)
        .toList();
  }

  List<GridPosition> getHousesForColor(int colorIndex) {
    return houses
        .where((h) => grid[h.y][h.x].colorIndex == colorIndex)
        .toList();
  }

  int getDemand(GridPosition pos) {
    return demand[_key(pos)] ?? 0;
  }

  bool isValid(int x, int y) => x >= 0 && x < cols && y >= 0 && y < rows;
  GridCell getCell(int x, int y) => grid[y][x];
  void _cleanOrphanRoads() {
    bool changed = true;
    while (changed) {
      changed = false;
      final toRemove = <GridPosition>[];
      
      for (final pos in infrastructure) {
        final cell = getCell(pos.x, pos.y);
        if (!cell.isRoad) continue;
        
        int connections = 0;
        if (cell.connUp) connections++;
        if (cell.connRight) connections++;
        if (cell.connDown) connections++;
        if (cell.connLeft) connections++;
        
        // A road is an orphan if it has no connections to other roads or buildings
        if (connections == 0) {
          toRemove.add(pos);
          changed = true;
        }
      }
      for (final pos in toRemove) {
        forceRemoveInfrastructure(pos.x, pos.y);
      }
    }
  }

  GridPosition? getBuildingOwningDriveway(GridPosition drivewayPos) {
    for (final entry in buildingDriveways.entries) {
      if (entry.value == drivewayPos) {
        final coords = entry.key.split(',');
        return GridPosition(int.parse(coords[0]), int.parse(coords[1]));
      }
    }
    return null;
  }

  bool isLockedEntrance(GridPosition pos) {
    // CATEGORY BYPASS: Infrastructure connectors are NEVER locked entrances
    final cell = getCell(pos.x, pos.y);
    if (cell.connectionType == ConnectionNodeType.infrastructureConnector) return false;
    
    return buildingDriveways.values.contains(pos);
  }

  GridPosition pixelToGrid(double px, double py, double cellSize) {
    return GridPosition((px / cellSize).floor(), (py / cellSize).floor());
  }

  bool isEntrance(int x, int y) {
    if (!isValid(x, y)) return false;
    return isLockedEntrance(GridPosition(x, y));
  }

  int countNearbyRoads(int cx, int cy, int radius) {
    int count = 0;
    for (int x = cx - radius; x <= cx + radius; x++) {
      for (int y = cy - radius; y <= cy + radius; y++) {
        if (isValid(x, y) && getCell(x, y).isRoad) {
          count++;
        }
      }
    }
    return count;
  }

  int countNearbyBuildings(int cx, int cy, int radius) {
    int count = 0;
    for (int x = cx - radius; x <= cx + radius; x++) {
      for (int y = cy - radius; y <= cy + radius; y++) {
        if (isValid(x, y)) {
          final cell = getCell(x, y);
          if (cell.isHouse || cell.isDestination) {
            count++;
          }
        }
      }
    }
    return count;
  }

  int countNearbyInfrastructure(int cx, int cy, int radius, CellType type) {
    int count = 0;
    for (int x = cx - radius; x <= cx + radius; x++) {
      for (int y = cy - radius; y <= cy + radius; y++) {
        if (x == cx && y == cy) continue;
        if (isValid(x, y) && getCell(x, y).type == type) {
          count++;
        }
      }
    }
    return count;
  }

  int _countExternalConnections(int x, int y) {
    int count = 0;
    final neighbors = [
      [x, y - 1], [x + 1, y], [x, y + 1], [x - 1, y]
    ];
    for (final n in neighbors) {
      if (isValid(n[0], n[1])) {
        final neighborCell = grid[n[1]][n[0]];
        // An "external" connection is one to a road or building, NOT to another tunnel/bridge tile
        if (hasEdge(x, y, n[0], n[1])) {
          if ((neighborCell.isRoad || neighborCell.isSmartJunction) && !neighborCell.isTunnel && !neighborCell.isBridge) {
            count++;
          } else if (neighborCell.isHouse || neighborCell.isDestination) {
            count++;
          }
        }
      }
    }
    return count;
  }
  void upgradeRoad(int x, int y) {
    if (!isValid(x, y)) return;
    final cell = grid[y][x];
    if (cell.isRoad || cell.isTunnel || cell.isBridge) {
      int nextLevel = (cell.roadLevel + 1).clamp(0, 2);
      int nextCapacity = GameConstants.roadCapacityDefault;
      if (nextLevel == 1) nextCapacity = GameConstants.avenueCapacity;
      if (nextLevel == 2) nextCapacity = GameConstants.highwayCapacity;

      grid[y][x] = cell.copyWith(
        roadLevel: nextLevel,
        capacity: nextCapacity,
      );
      upgradedRoads.add(_key(GridPosition(x, y)));
    }
  }

  void setBusStop(int x, int y, {String? routeId}) {
    if (!isValid(x, y)) return;
    final cell = grid[y][x];
    // Bus stops can only be on roads or destination entrances
    if (cell.isRoad || cell.isDestination) {
      grid[y][x] = cell.copyWith(
        isBusStop: true,
        busRouteId: routeId,
      );
    }
  }

  void toggleBusLane(int x, int y) {
    if (!isValid(x, y)) return;
    final cell = grid[y][x];
    if (cell.isRoad) {
      grid[y][x] = cell.copyWith(isBusLane: !cell.isBusLane);
    }
  }

  void setOneWay(int x, int y, Direction? dir) {
    if (!isValid(x, y)) return;
    final cell = grid[y][x];
    if (cell.isRoad) {
      grid[y][x] = cell.copyWith(
        isOneWay: dir != null,
        oneWayDirection: dir,
      );
    }
  }

  void toggleMetroStation(int x, int y) {
    if (!isValid(x, y)) return;
    final cell = grid[y][x];
    // Metro stations can be anywhere but usually replace empty space or are near roads
    grid[y][x] = cell.copyWith(isMetroStation: !cell.isMetroStation);
  }
}
