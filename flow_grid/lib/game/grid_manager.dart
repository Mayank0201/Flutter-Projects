import '../models/grid_cell.dart';
import '../models/game_constants.dart';

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
  final Map<String, double> highDemandTimers = {}; // Tracks time spent at 6+ dots
  final Map<String, bool> spawnedBonusHouse = {}; // Tracks if this dest hub already gave a bonus house
  final Map<String, double> houseCarTimers = {};
  final Set<GridPosition> infrastructure = {};

  /// Combined list of all buildings (houses + destinations)
  List<GridPosition> get buildings => [...houses, ...destinations];

  /// Maps a building's position to its dedicated driveway (the first road connected to it)
  final Map<String, GridPosition> buildingDriveways = {};

  /// Each express lane is a pair [start, end]
  final List<List<GridPosition>> placedExpressLanes = [];

  // Road capacity tracking (runtime)
  final Map<String, int> roadLoad = {};

  // Traffic signal state
  final Map<String, int> signalPhases = {}; // 0=NS green, 1=EW green
  final Map<String, double> signalTimers = {};

  final List<MountainCluster> mountainClusters = [];
  
  // Region tracking for spawning
  final List<GridPosition> regionA = [];
  final List<GridPosition> regionB = [];

  // [NEW] Mountain Centering (Issue 2)
  int _mountainX = 0;
  int get mountainX => _mountainX;

  // [NEW] Expressway Placement State
  GridPosition? _pendingExpressLaneStart;
  bool get isPlacingExpressLane => _pendingExpressLaneStart != null;
  GridPosition? get pendingExpressLaneStart => _pendingExpressLaneStart;


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

  // Infrastructure Inventories
  int roads = 0;
  int tunnels = 0; // was: bridges
  int trafficLights = 0;
  int smartJunctions = 0; // was: roundabouts
  int expressLanes = 0; // was: motorways

  GridManager(this.cols, this.rows) {
    grid = List.generate(rows, (y) => List.generate(cols, (x) => GridCell()));
    _generateMountainRange();
  }

  void _generateMountainRange() {
    _mountainX = cols ~/ 2;
    rebuildMountain(_mountainX);
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
        cluster.cells.add(GridPosition(_mountainX, y));
        grid[y][_mountainX] = GridCell(type: CellType.mountain, region: null);
      }
    }
    
    mountainClusters.add(cluster);
    _detectRegions();
    _applyTerrainSpeeds();
  }

  void _detectRegions() {
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


  /// Pre-compute speed multipliers based on mountain proximity
  void _applyTerrainSpeeds() {
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

  /// Tick all traffic signals
  void updateTrafficSignals(double dt) {
    for (final pos in infrastructure) {
      final cell = grid[pos.y][pos.x];
      if (!cell.hasTrafficLight) continue;
      final key = _key(pos);
      signalTimers[key] = (signalTimers[key] ?? 0) + dt;
      if (signalTimers[key]! >= GameConstants.trafficSignalInterval) {
        signalTimers[key] = 0;
        final currentPhase = signalPhases[key] ?? 0;
        signalPhases[key] = currentPhase == 0 ? 1 : 0;
        // Update the cell's signal phase
        grid[pos.y][pos.x] = cell.copyWith(signalPhase: signalPhases[key]);
      }
    }
  }

  int getSignalPhase(int x, int y) =>
      signalPhases[_key(GridPosition(x, y))] ?? 0;

  bool isGreenForDirection(int x, int y, Direction movingDir) {
    final phase = getSignalPhase(x, y);
    // Phase 0 = N/S green, Phase 1 = E/W green
    if (phase == 0) {
      return movingDir == Direction.north || movingDir == Direction.south;
    }
    return movingDir == Direction.east || movingDir == Direction.west;
  }

  // Road load tracking
  int getRoadLoad(int x, int y) => roadLoad[_key(GridPosition(x, y))] ?? 0;
  void setRoadLoad(int x, int y, int val) =>
      roadLoad[_key(GridPosition(x, y))] = val;
  bool isRoadCongested(int x, int y) {
    final cell = grid[y][x];
    return getRoadLoad(x, y) >=
        (cell.capacity * GameConstants.roadCapacityCongestedThreshold).ceil();
  }

  void reset() {
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
    _generateMountainRange();
  }

  void loadFromSave(Map<String, dynamic> data) {
    reset(); // Clear first

    // Grid
    final gridData = data['grid'] as List<dynamic>;
    for (int y = 0; y < rows; y++) {
      final rowData = gridData[y] as List<dynamic>;
      for (int x = 0; x < cols; x++) {
        final cellData = rowData[x] as Map<String, dynamic>;
        final type = CellType.values[cellData['type'] as int];
        grid[y][x] = GridCell(
          type: type,
          colorIndex: cellData['colorIndex'] as int?,
          isPendingDeletion: cellData['isPendingDeletion'] as bool? ?? false,
          isTunnelExtension: cellData['isTunnelExtension'] as bool? ?? false,
          hasTrafficLight: cellData['hasTrafficLight'] as bool? ?? false,
        );

        final pos = GridPosition(x, y);
        if (type == CellType.house) houses.add(pos);
        if (type == CellType.destination) destinations.add(pos);

        // Rebuild infrastructure list
        if (type != CellType.empty &&
            type != CellType.mountain &&
            type != CellType.house &&
            type != CellType.destination) {
          infrastructure.add(pos);
        }
      }
    }

    // Express Lanes
    if (data['placedExpressLanes'] != null) {
      final mws = data['placedExpressLanes'] as List<dynamic>;
      for (final mw in mws) {
        final pair = mw as List<dynamic>;
        placedExpressLanes.add([
          GridPosition(pair[0]['x'], pair[0]['y']),
          GridPosition(pair[1]['x'], pair[1]['y']),
        ]);
      }
    }

    // Driveways
    if (data['driveways'] != null) {
      final dws = data['driveways'] as Map<String, dynamic>;
      dws.forEach((key, value) {
        buildingDriveways[key] = GridPosition(value['x'], value['y']);
      });
    }

    // Inventory
    final inv = data['inventory'] as Map<String, dynamic>;
    roads = inv['roads'] ?? 0;
    tunnels = inv['tunnels'] ?? 0;
    trafficLights = inv['trafficLights'] ?? 0;
    smartJunctions = inv['smartJunctions'] ?? 0;
    expressLanes = inv['expressLanes'] ?? 0;

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
    // Can only build on empty, or replace existing road/tunnel
    return cell.isEmpty || cell.isRoad || cell.type == CellType.mountain;
  }

  bool placeRoad(int x, int y, {GridPosition? from}) {
    if (!isValid(x, y)) return false;
    final cell = grid[y][x];
    
    // PART 3: Convert mountain to tunnel
    if (cell.type == CellType.mountain) {
      return placeTunnel(x, y, from: from);
    }
    
    if (cell.type != CellType.empty && cell.type != CellType.road) return false;

    // Create or update the road cell
    grid[y][x] = cell.copyWith(type: CellType.road);
    final pos = GridPosition(x, y);
    if (!infrastructure.contains(pos)) {
      infrastructure.add(pos);
    }

    if (from != null) {
      addEdge(from.x, from.y, x, y);
      updateNodeConnections(from.x, from.y);
    }

    updateNodeConnections(x, y);
    _assignAllDriveways(x, y);
    return true;
  }

  bool placeTunnel(
    int x,
    int y, {
    bool isExtension = false,
    GridPosition? from,
  }) {
    // 1. Basic Validation
    if (!isValid(x, y)) {
      print('[TUNNEL] FAILED: Invalid coordinates ($x, $y)');
      return false;
    }
    
    final cell = grid[y][x];
    if (cell.type != CellType.mountain && cell.type != CellType.tunnel) {
      print('[TUNNEL] FAILED: Tile ($x, $y) is not a mountain or tunnel (${cell.type.name})');
      return false;
    }

    // 2. Endpoint/Connectivity Validation (Horizontal Only)
    if (from != null) {
      if (from.y != y) {
        print('[TUNNEL] FAILED: Vertical tunnels are not allowed');
        return false;
      }
      final dist = (from.x - x).abs();
      if (dist != 1) {
        print('[TUNNEL] FAILED: Endpoint ${from.key} is not adjacent to ($x, $y)');
        return false;
      }
    }

    // 3. Transactional Commit
    grid[y][x] = cell.copyWith(
      type: CellType.tunnel,
      isTunnelExtension: isExtension,
      speedMultiplier:
          GameConstants.tunnelSpeedBonus, // tunnels remove mountain penalty
    );
    
    final pos = GridPosition(x, y);
    if (!infrastructure.contains(pos)) {
      infrastructure.add(pos);
    }

    if (from != null) {
      addEdge(from.x, from.y, x, y);
      updateNodeConnections(from.x, from.y);
    }

    updateNodeConnections(x, y);
    _cleanOrphanRoads();
    
    print('[TUNNEL] COMMITTED: Success at ($x, $y) ${isExtension ? "(Extension)" : ""} from ${from?.key ?? "start"}');
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
  }


  bool placeExpressLane(GridPosition start, GridPosition end) {
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

    // 2. Commit Overpass Property (Layered)
    grid[start.y][start.x] = startCell.copyWith(
      overpass: OverpassType.start,
      speedMultiplier: GameConstants.expressLaneSpeed,
      isExpressLane: true,
    );
    grid[end.y][end.x] = endCell.copyWith(
      overpass: OverpassType.end,
      speedMultiplier: GameConstants.expressLaneSpeed,
      isExpressLane: true,
    );

    infrastructure.add(start);
    infrastructure.add(end);

    // 3. Commit Graph Edge
    placedExpressLanes.add([start, end]);
    
    // 4. Automatic Connectivity (Rule 5)
    _connectExpressToRoad(start);
    _connectExpressToRoad(end);

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

  void _assignAllDriveways(int rx, int ry) {
    const offsets = [[0, -1], [1, 0], [0, 1], [-1, 0]];
    for (int i = 0; i < 4; i++) {
      final nx = rx + offsets[i][0];
      final ny = ry + offsets[i][1];
      if (isValid(nx, ny)) {
        final cell = grid[ny][nx];
        if (cell.isHouse || cell.isDestination) {
          connectBuilding(nx, ny, rx, ry);
        }
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
      final beforeCount = activeEdges.length;
      addEdge(bx, by, rx, ry);
      final afterCount = activeEdges.length;
      
      print('[GRAPH] Building inserted: ($bx,$by) connected to driveway ($rx,$ry). Edge count: $beforeCount -> $afterCount');
      
      buildingDriveways[_key(GridPosition(bx, by))] = GridPosition(rx, ry);
    }

    updateNodeConnections(rx, ry);
    updateNodeConnections(bx, by);
  }


  @Deprecated('Use connectBuilding instead')
  void forceConnectBuilding(int bx, int by, int rx, int ry) {
    connectBuilding(bx, by, rx, ry);
  }

  bool placeTrafficLight(int x, int y) {
    if (!isValid(x, y)) return false;
    final cell = grid[y][x];
    if (!cell.isRoad) return false;
    if (cell.hasTrafficLight) return false;

    grid[y][x] = GridCell(
      type: cell.type,
      hasTrafficLight: true,
      isPendingDeletion: cell.isPendingDeletion,
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
      print('[GRAPH] Player deleting driveway at ($x,$y)');
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
      grid[y][x] = GridCell(type: CellType.road, isPendingDeletion: true);
      rebuildRoadGraph();
      return 'road';
    } else if (cell.type == CellType.tunnel) {
      grid[y][x] = GridCell(
        type: CellType.tunnel,
        isPendingDeletion: true,
        isTunnelExtension: cell.isTunnelExtension,
      );
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
        // Immediate removal from graph (Part 1)
        placedExpressLanes.remove(mwToRemove);
        removeEdge(mwToRemove[0].x, mwToRemove[0].y, mwToRemove[1].x, mwToRemove[1].y);
        
        // Mark cells for cleanup (Layered: remove overpass, keep underlying structure)
        grid[mwToRemove[0].y][mwToRemove[0].x] = grid[mwToRemove[0].y][mwToRemove[0].x].copyWith(
          overpass: OverpassType.none,
          isExpressLane: false,
          speedMultiplier: 1.0,
        );
        grid[mwToRemove[1].y][mwToRemove[1].x] = grid[mwToRemove[1].y][mwToRemove[1].x].copyWith(
          overpass: OverpassType.none,
          isExpressLane: false,
          speedMultiplier: 1.0,
        );
        
        // Only remove from infrastructure if it's now truly empty
        if (grid[mwToRemove[0].y][mwToRemove[0].x].isEmpty) {
          infrastructure.remove(mwToRemove[0]);
        }
        if (grid[mwToRemove[1].y][mwToRemove[1].x].isEmpty) {
          infrastructure.remove(mwToRemove[1]);
        }
        
        return 'expressLane';
      }
    }
    return '';
  }

  void cancelPendingDeletion(int x, int y) {
    if (!isValid(x, y)) return;
    final cell = grid[y][x];
    if (cell.isPendingDeletion) {
      grid[y][x] = GridCell(
        type: cell.type,
        colorIndex: cell.colorIndex,
        isTunnelExtension: cell.isTunnelExtension,
        hasTrafficLight: cell.hasTrafficLight,
      );
    }
  }

  void forceRemoveInfrastructure(int x, int y) {
    if (!isValid(x, y)) return;
    final cell = grid[y][x];
    if (cell.type == CellType.tunnel) {
      grid[y][x] = GridCell(type: CellType.mountain);
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
        refunds['trafficLight'] = (refunds['trafficLight'] ?? 0) + 1;
      } else if (cell.type == CellType.tunnel) {
        grid[pos.y][pos.x] = GridCell(type: CellType.mountain);
        infrastructure.remove(pos);
        if (cell.isTunnelExtension) {
          refunds['road'] = (refunds['road'] ?? 0) + 1;
        } else {
          refunds['tunnel'] = (refunds['tunnel'] ?? 0) + 1;
        }
      } else {
        grid[pos.y][pos.x] = GridCell();
        infrastructure.remove(pos);
        if (cell.type == CellType.road) {
          refunds['road'] = (refunds['road'] ?? 0) + 1;
        }
      }
    }
    if (toRemove.isNotEmpty) {
      rebuildRoadGraph();
    }
    return refunds;
  }

  /// Place a 1x1 smart junction at (x, y).
  bool placeSmartJunction(int x, int y) {
    if (!isValid(x, y)) return false;
    final cell = grid[y][x];

    if (cell.type != CellType.empty && cell.type != CellType.road) return false;

    grid[y][x] = GridCell(type: CellType.smartJunction);
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
        if (neighbor.isPassable || neighbor.isHouse || neighbor.isDestination) {
          addEdge(x, y, nx, ny);
          updateNodeConnections(nx, ny);
        }
      }
    }

    updateNodeConnections(x, y);
    return true;
  }

  bool placeExpressLaneNode(int x, int y) {
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
      final success = placeExpressLane(_pendingExpressLaneStart!, pos);
      
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
    houseCarTimers[key] = 0;
  }

  void placeDestination(int x, int y, int colorIndex, Direction entrySide) {
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
    demand[key] = 0;
    demandTimers[key] = 0;
  }

  int getDemand(GridPosition pos) => demand[_key(pos)] ?? 0;
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

    // Express Lane shortcuts (NOT teleport — just connectivity)
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
}
