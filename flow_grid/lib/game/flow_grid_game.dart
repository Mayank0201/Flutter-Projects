import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../models/game_constants.dart';
import '../models/grid_cell.dart';
import '../models/traffic_phase.dart';
import 'grid_manager.dart';
import 'spawn_controller.dart';
import 'district_planner.dart';
import 'progression_director.dart';
import 'components/grid_renderer.dart';
import 'components/car_component.dart';
import 'save_manager.dart';
import 'map_generator.dart';
import 'event_manager.dart';
import 'pathfinder.dart';
import 'transit_manager.dart';
import 'emergency_manager.dart';
import 'economy_manager.dart';
import 'utils/performance_logger.dart';
import 'car_pool.dart';



enum GamePhase { menu, playing, paused, gameOver, weeklyUpgrade }

enum BuildTool { road, bridge, tunnel, trafficLight, smartJunction, expressLane, erase, inspect, upgradeRoad, busStop, busLane, oneWay, metroTrack, elevatedRail, highway, metroStation, priorityIntersection }

class FlowGridGame extends FlameGame with PanDetector, MouseMovementDetector {
  GridManager? gridManager;
  GridRenderer? gridRenderer;

  GamePhase phase = GamePhase.menu;
  BuildTool activeTool = BuildTool.road;
  GridPosition? selectedDistrict;
  GridPosition? selectedInfrastructure;
  bool showDebugOverlay = false;

  // Inventory & Stats Notifiers
  final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> weekNotifier = ValueNotifier<int>(1);
  final ValueNotifier<double> weekProgressNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<double> satisfactionNotifier = ValueNotifier<double>(1.0);
  
  final ValueNotifier<int> roadInventoryNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> tunnelInventoryNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> bridgeInventoryNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> trafficLightInventoryNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> smartJunctionInventoryNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> expressLaneInventoryNotifier = ValueNotifier<int>(0);

  int get score => scoreNotifier.value;
  set score(int v) => scoreNotifier.value = v;
  int get week => weekNotifier.value;
  set week(int v) => weekNotifier.value = v;

  int totalDeliveries = 0;
  double weekTimer = 0;
  final TrafficClock trafficClock = TrafficClock();
  double _elapsedTime = 0;
  double get elapsedTime => _elapsedTime;
  final Map<String, List<GridPosition>> _pathCache = {};

  List<String> weeklyOptions = [];
  final Map<int, List<CarComponent>> carGrid = {};
  int gridWidth = 0;
  final Map<String, int> houseCarCounts = {};

  int activeColorCount = 1;
  double timeScale = 1.0;

  late SpawnController? spawnController;
  late ProgressionDirector progressionDirector;
  late DistrictPlanner districtPlanner;
  late EventManager eventManager;
  late TransitManager transitManager;
  late EmergencyManager emergencyManager;
  late EconomyManager economyManager;

  double cellSize = 40;
  double boardOffsetX = 0;
  double boardOffsetY = 0;
  int gridCols = 16;
  int gridRows = 10;
  double hudPanelWidth = 140;

  // Active region (Mini-Motorways style): a smaller centered rectangle that
  // grows each week. Both spawning AND player builds are confined to this
  // region; the camera zoom is derived from its size so it always fills the
  // visible area with a bit of padding.
  static const int _initialActiveHalfWidth = 10;   // Week 1: 20 cells wide
  static const int _initialActiveHalfHeight = 7;   // Week 1: 14 cells tall
  static const int _weeklyActiveExpansionX = 3;    // +6 width per week
  static const int _weeklyActiveExpansionY = 2;    // +4 height per week
  static const double _activeAreaPadding = 1.05;   // ~2.5% margin around region

  int get _activeHalfWidth {
    final maxHalf = (gridCols - 4) ~/ 2;
    return min(maxHalf, _initialActiveHalfWidth + (week - 1) * _weeklyActiveExpansionX);
  }

  int get _activeHalfHeight {
    final maxHalf = (gridRows - 4) ~/ 2;
    return min(maxHalf, _initialActiveHalfHeight + (week - 1) * _weeklyActiveExpansionY);
  }

  double get _targetZoom {
    if (size.x <= 100 || size.y <= 100) return 0.5;
    final screenW = size.x - hudPanelWidth;
    final screenH = size.y;
    final areaW = (_activeHalfWidth * 2) * cellSize * _activeAreaPadding;
    final areaH = (_activeHalfHeight * 2) * cellSize * _activeAreaPadding;
    final zoomX = screenW / areaW;
    final zoomY = screenH / areaH;
    return min(zoomX, zoomY).clamp(0.3, 2.0);
  }

  MapType selectedMapType = MapType.zen;
  int currentSlotIndex = 0;

  double get difficulty => 1.0 + ((week - 1) * 0.12);
  double get weekProgress => weekTimer / GameConstants.weekDuration;

  final List<CarComponent> _cars = [];
  List<CarComponent> get cars => _cars;
  final List<GridPosition> _dragPath = [];
  List<GridPosition> previewPath = [];
  
  GridPosition? expressLanePendingStart;
  GridPosition? expressLaneDraggingEnd;

  bool get _isDeferredTool => 
      activeTool == BuildTool.road || 
      activeTool == BuildTool.bridge || 
      activeTool == BuildTool.tunnel ||
      activeTool == BuildTool.erase;

  GridPosition? _lastPlacedPos;
  GridPosition? lastHoverPos;
  bool _isDragging = false;
  bool _initialSyncDone = false;
  bool _pendingInitialSpawn = false;
  final PerformanceLogger perfLogger = PerformanceLogger();
  

  final CarPool carPool = CarPool();

  // Shared vehicle sprite atlas — one row, six columns. Sliced once at boot
  // and reused by every CarComponent so render becomes one drawImageRect.
  final List<Sprite> vehicleSprites = [];
  // Source aspect ratio (height / width) of a single sprite cell. Used to keep
  // the rendered car from looking squished when the component is square.
  double vehicleSpriteAspect = 1.0;

  
  // Tiered Tick Rates
  double _logicTickTimer = 0;
  double _simTickTimer = 0;
  double _metricsTickTimer = 0;
  double _spawnTickTimer = 0;
  
  // Input Polish
  Vector2? _panStartPixel;
  static const double dragThreshold = 8.0;

  VoidCallback? onStateChanged;
  Function(Map<String, dynamic>)? onStatsChanged;

  @override
  Future<void> onLoad() async {
    debugPrint("[BOOT] onLoad started");
    await super.onLoad();
    camera.viewfinder.anchor = Anchor.topLeft;

    await _loadVehicleSprites();

    overlays.add('mainMenu');
    paused = true;
    debugPrint("[BOOT] onLoad complete, added mainMenu");
  }

  Future<void> _loadVehicleSprites() async {
    final image = await images.load('normal_vehicles.png');
    const cols = 6;
    final cellW = image.width / cols;
    final cellH = image.height.toDouble();
    vehicleSpriteAspect = cellH / cellW;
    vehicleSprites.clear();
    for (int i = 0; i < cols; i++) {
      vehicleSprites.add(Sprite(
        image,
        srcPosition: Vector2(i * cellW, 0),
        srcSize: Vector2(cellW, cellH),
      ));
    }
    debugPrint('[BOOT] loaded ${vehicleSprites.length} vehicle sprites '
        '(cell ${cellW.toStringAsFixed(1)}x${cellH.toStringAsFixed(1)})');
  }


  void startGame({required bool resume, MapType mapType = MapType.zen, int slotIndex = 0}) async {
    _initialSyncDone = false;
    _spawnAttempts = 0;
    currentSlotIndex = slotIndex;
    selectedMapType = mapType;
    
    // Reset core state
    score = 0;
    week = 1;
    totalDeliveries = 0;
    weekTimer = 0;
    _elapsedTime = 0;
    activeColorCount = 1;
    _pathCache.clear();
    _cars.clear();
    children.whereType<CarComponent>().forEach((c) => c.removeFromParent());
    world.children.whereType<CarComponent>().forEach((c) => c.removeFromParent());
    children.whereType<GridRenderer>().forEach((r) => r.removeFromParent());
    world.children.whereType<GridRenderer>().forEach((r) => r.removeFromParent());
    
    if (resume) {
      final save = await SaveManager.loadGame(slotIndex: slotIndex);
      if (save != null) {
        gridCols = save['gridCols'] ?? 16;
        gridRows = save['gridRows'] ?? 10;
        gridManager = GridManager(gridCols, gridRows, selectedMapType: MapType.values[save['mapType'] ?? 0], initTerrain: false);
        
        // Restore Grid, Inventories, Driveways, and Demand State Unifiedly
        gridManager!.loadFromSave(save);

        // Restore Metadata
        week = save['week'] ?? 1;
        score = save['score'] ?? 0;
        totalDeliveries = save['totalDeliveries'] ?? 0;
        weekTimer = (save['weekTimer'] as num?)?.toDouble() ?? 0;
        _elapsedTime = (save['elapsedTime'] as num?)?.toDouble() ?? 0;
        activeColorCount = save['activeColorCount'] ?? 1;

        // Camera
        camera.viewfinder.zoom = (save['cameraZoom'] as num?)?.toDouble() ?? 1.0;
        camera.viewfinder.position = Vector2(
          (save['cameraPosX'] as num?)?.toDouble() ?? 0.0,
          (save['cameraPosY'] as num?)?.toDouble() ?? 0.0,
        );
      }
    } else {
      // New Game
      gridCols = 64; // Default large map
      gridRows = 40;
      gridManager = GridManager(gridCols, gridRows, selectedMapType: mapType);
      
      final generator = MapGeneratorFactory.getGenerator(mapType);
      gridManager!.roads = generator.config.startingRoads;
      gridManager!.tunnels = generator.config.startingTunnels;
      gridManager!.bridges = generator.config.startingBridges;
      gridManager!.trafficLights = generator.config.startingTrafficLights;
      gridManager!.smartJunctions = generator.config.startingSmartJunctions;
      gridManager!.expressLanes = generator.config.startingExpressLanes;

      // Initial Camera
      _syncCameraCenter(instant: true);
    }

    // Initialize/Reset Systems
    debugPrint("[WORLD_INIT] Initializing systems");
    districtPlanner = DistrictPlanner(gridManager: gridManager!);
    spawnController = SpawnController(
      gridManager: gridManager!,
      districtPlanner: districtPlanner,
    );
    spawnController!.initializeScoring();
    spawnController!.onSpawnComplete = () {
      gridRenderer?.markDirty();
      onStateChanged?.call();
    };
    spawnController!.onLog = (msg) => debugPrint('[SPAWN] $msg');
    debugPrint("[SPAWN_MANAGER_INIT] SpawnController created and scoring initialized");
    gridRenderer = GridRenderer(gridManager: gridManager!, cellSize: cellSize);
    world.add(gridRenderer!);
    
    // Initialize Managers with valid references
    eventManager = EventManager(gridManager: gridManager!, districtPlanner: districtPlanner);
    transitManager = TransitManager();
    emergencyManager = EmergencyManager();
    economyManager = EconomyManager();
    progressionDirector = ProgressionDirector(spawnController!);
    progressionDirector.reset();
    if (resume) {
      for (int i = 0; i < activeColorCount; i++) {
        progressionDirector.registerUnlockedColor(i, 1);
      }
    }

    // Add components to the game tree
    add(eventManager);
    add(transitManager);
    add(emergencyManager);
    add(economyManager);
    debugPrint("[WORLD_INIT] Components added to game tree");

    // Connect callbacks
    gridManager!.onTopologyChanged = () => _pathCache.clear();

    phase = GamePhase.playing;
    paused = false;
    _syncCameraCenter(instant: true);
    _syncSpawnBounds();

    // Defer initial district spawn to first update tick so that `size`
    // is guaranteed populated â€” _focusCameraOn() depends on it.
    // Always pending: the deferred handler bails out if buildings already exist,
    // and recovers if a resumed save has no buildings yet.
    _pendingInitialSpawn = true;

    _updateInventoryNotifiers();
    
    // Manage Overlays
    overlays.remove('mainMenu');
    overlays.remove('mapSelection');
    overlays.remove('saveSlot');
    overlays.remove('tutorial');
    overlays.remove('gameOver');
    overlays.add('hud');

    onStateChanged?.call();
  }

  void saveGame() {
    if (gridManager == null) return;
    SaveManager.saveGame(
      gridManager!,
      week,
      score,
      totalDeliveries,
      weekTimer: weekTimer,
      spawnTimer: _spawnTickTimer,
      activeColorCount: activeColorCount,
      zoomLevel: 1, // Simplified
      elapsedTime: _elapsedTime,
      houseCarCounts: houseCarCounts,
      cars: _cars,
      cameraZoom: camera.viewfinder.zoom,
      cameraPosX: camera.viewfinder.position.x,
      cameraPosY: camera.viewfinder.position.y,
      slotIndex: currentSlotIndex,
    );
  }

  void applyUpgrade(String option) {
    if (gridManager == null) return;
    
    if (option == 'tunnels') {
      gridManager!.roads += 20;
      gridManager!.tunnels += 1;
    } else if (option == 'bridges') {
      gridManager!.roads += 20;
      gridManager!.bridges += 1;
    } else if (option == 'trafficLights') {
      gridManager!.roads += 20;
      gridManager!.trafficLights += 2;
    } else if (option == 'smartJunction') {
      gridManager!.roads += 20;
      gridManager!.smartJunctions += 1;
    } else if (option == 'expressLane') {
      gridManager!.roads += 10;
      gridManager!.expressLanes += 1;
    } else if (option == 'doubleRoads') {
      gridManager!.roads += 30;
    }

    phase = GamePhase.playing;
    paused = false;
    overlays.remove('weeklyUpgrade');
    _updateInventoryNotifiers();
    onStateChanged?.call();
  }

  void _updateInventoryNotifiers() {
    if (gridManager == null) return;
    roadInventoryNotifier.value = gridManager!.roads;
    tunnelInventoryNotifier.value = gridManager!.tunnels;
    bridgeInventoryNotifier.value = gridManager!.bridges;
    trafficLightInventoryNotifier.value = gridManager!.trafficLights;
    smartJunctionInventoryNotifier.value = gridManager!.smartJunctions;
    expressLaneInventoryNotifier.value = gridManager!.expressLanes;
    
    weekNotifier.value = week;
    weekProgressNotifier.value = weekProgress;
    scoreNotifier.value = score;
    satisfactionNotifier.value = gridManager!.regionalSatisfaction;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (phase == GamePhase.playing) {
      _syncCameraCenter(instant: true);
      _syncSpawnBounds();
    }
  }

  double _debugLogTimer = 0;

  @override
  void update(double dt) {
    super.update(dt);

    // First valid frame: snap the camera (zoom + position) to its target so
    // the player doesn't watch a ~half-second zoom drift at start-up.
    if (phase == GamePhase.playing && !_initialSyncDone && size.x > 100) {
      camera.viewfinder.zoom = _targetZoom;
      _syncCameraCenter(instant: true);
      _syncSpawnBounds();
      _initialSyncDone = true;
      debugPrint("[SYNC] Initial camera and spawn bounds synchronized with size: $size");

      _tryInitialSpawn();
    }

    // Tier 1: Real-time (Camera, Animations) — runs after the snap above so
    // the first valid frame already lands at the target zoom.
    _updateCameraSmoothing(dt);

    _debugLogTimer += dt;
    if (_debugLogTimer > 5.0) {
      debugPrint("[UPDATE_LOOP_ACTIVE] phase: $phase, paused: $paused, week: $week");
      _debugLogTimer = 0;
    }
    
    if (phase != GamePhase.playing || paused) return;
    
    final safeDt = dt.clamp(0.0, 0.05);
    final scaledDt = safeDt * timeScale;
    _elapsedTime += scaledDt;
    weekTimer += scaledDt;

    // Tier 2: 15Hz - Physics & Traffic AI
    // Pass the accumulated tick interval (scaled), not just the last frame's dt,
    // so per-house timers accrue at real-time speed.
    _logicTickTimer += safeDt;
    if (_logicTickTimer >= 1 / 15) {
      final logicDt = _logicTickTimer * timeScale;
      _logicTickTimer = 0;
      _rebuildSpatialGrid();
      trafficClock.update(logicDt);
      _updateTrafficSimulation(logicDt);
      gridManager?.updateTrafficSignals(logicDt, carGrid, gridWidth);
    }

    // Tier 3: 5Hz - Simulation & Pathfinding
    _simTickTimer += safeDt;
    if (_simTickTimer >= 1 / 5) {
      final simDt = _simTickTimer * timeScale;
      _simTickTimer = 0;
      gridManager?.updateCongestion(cars);
      gridManager?.updateSatisfaction(simDt);
    }

    // Tier 4: 2Hz - HUD & Analytics
    _metricsTickTimer += safeDt;
    if (_metricsTickTimer >= 1 / 2) {
      _updateInventoryNotifiers();
      _metricsTickTimer = 0;
    }

    // Tier 5: 1Hz - Spawning & Progression
    _spawnTickTimer += safeDt;
    if (_spawnTickTimer >= 1 / 1) {
      final spawnDt = _spawnTickTimer * timeScale;
      _spawnTickTimer = 0;
      if (_pendingInitialSpawn) _tryInitialSpawn();
      spawnController?.update(spawnDt);
      progressionDirector.update(week, weekProgress, spawnDt);
      _checkWeekTransition();
    }
  }

  void _rebuildSpatialGrid() {
    carGrid.clear();
    gridWidth = gridManager?.cols ?? 100;
    
    // Viewport Culling: Only update and index cars that are visible
    final viewport = camera.visibleWorldRect;
    
    // Remove arrived cars and return them to the pool
    final toRemove = <CarComponent>[];
    for (final car in _cars) {
      if (car.arrived) {
        toRemove.add(car);
        car.removeFromParent();
        carPool.returnCar(car);
        continue;
      }
      
      // Basic culling: If car is far from viewport, skip detailed indexing
      // (Position check is very cheap)
      if (!viewport.inflate(cellSize * 4).contains(car.position.toOffset())) {
        continue;
      }

      final pos = car.path[car.currentPathIndex.clamp(0, car.path.length - 1)];
      final key = pos.x + pos.y * gridWidth;
      carGrid.putIfAbsent(key, () => []).add(car);
    }
    
    if (toRemove.isNotEmpty) {
      _cars.removeWhere((c) => toRemove.contains(c));
    }
  }


  void _updateCameraSmoothing(double dt) {
    if ((camera.viewfinder.zoom - _targetZoom).abs() > 0.001) {
      final zoomLerp = 1.0 - pow(0.05, dt).toDouble();
      final delta = (_targetZoom - camera.viewfinder.zoom) * zoomLerp;
      camera.viewfinder.zoom += delta.clamp(-0.06, 0.06);
      _syncCameraCenter(dt: dt);
      _syncSpawnBounds();
    }
  }
  void _updateTrafficSimulation(double dt) {
    if (gridManager == null) return;

    for (final housePos in gridManager!.houses) {
      final key = "${housePos.x},${housePos.y}";
      double timer = gridManager!.getHouseCarTimer(housePos) + dt;
      
      if (timer >= GameConstants.carSpawnInterval) {
        // Try to spawn
        final dest = _findDestination(housePos);
        if (dest != null) {
          final start = gridManager!.buildingDriveways[key];
          final end = gridManager!.buildingDriveways["${dest.x},${dest.y}"];
          
          if (start != null && end != null) {
            final path = Pathfinder.findPath(gridManager!, start, end);
            if (path != null) {
              final colorIndex = gridManager!.getCell(housePos.x, housePos.y).colorIndex ?? 0;
              final car = carPool.getCar(
                path: path,
                colorIndex: colorIndex,
                spawnHousePos: housePos,
                targetDest: dest,
                vehicleType: VehicleType.car,
                cellSize: cellSize,
                offsetX: boardOffsetX,
                offsetY: boardOffsetY,
              );
              _cars.add(car);
              world.add(car);
              timer = 0;
            }
          }
        }
      }
      gridManager!.setHouseCarTimer(housePos, timer);
    }
  }

  GridPosition? _findDestination(GridPosition housePos) {
    final houseCell = gridManager!.getCell(housePos.x, housePos.y);
    final targets = gridManager!.destinations.where((d) => 
      gridManager!.getCell(d.x, d.y).colorIndex == houseCell.colorIndex
    ).toList();
    
    if (targets.isEmpty) return null;
    return targets[Random().nextInt(targets.length)];
  }


  int _spawnAttempts = 0;

  void _tryInitialSpawn() {
    if (!_pendingInitialSpawn) return;
    if (gridManager == null || spawnController == null) return;

    // If the world already has a district (e.g. resumed save), we're done.
    if (gridManager!.houses.isNotEmpty || gridManager!.destinations.isNotEmpty) {
      _pendingInitialSpawn = false;
      _spawnAttempts = 0;
      return;
    }

    _spawnAttempts++;
    final spawned = spawnController!.spawnInitialPair(0);
    debugPrint('[SPAWN] attempt #$_spawnAttempts spawnInitialPair(0)=$spawned, '
        'houses=${gridManager!.houses.length}, '
        'destinations=${gridManager!.destinations.length}, '
        'bounds=(${spawnController!.minSpawnX}..${spawnController!.maxSpawnX}, '
        '${spawnController!.minSpawnY}..${spawnController!.maxSpawnY})');

    if (spawned) {
      // Keep the camera on grid center (= active-region center) so the playable
      // border is symmetric on screen. Focusing on the destination instead
      // shifted the visible active region off to one side.
      gridRenderer?.markDirty();
      _pendingInitialSpawn = false;
      _spawnAttempts = 0;
      return;
    }

    // SpawnController failed too many times — drop a guaranteed minimal district
    // manually so the player always has something to work with.
    if (_spawnAttempts >= 3) {
      debugPrint('[SPAWN] SpawnController failed $_spawnAttempts times. Forcing manual district.');
      if (_forceManualDistrict(0)) {
        _pendingInitialSpawn = false;
        _spawnAttempts = 0;
      }
    }
  }

  /// Deterministic backup district. Bypasses SpawnController validators and drops
  /// 1 destination + 2 houses at hardcoded positions near the grid center, each
  /// with its driveway road already laid.
  bool _forceManualDistrict(int colorIndex) {
    final gm = gridManager;
    if (gm == null) return false;

    final cx = gm.cols ~/ 2;
    final cy = gm.rows ~/ 2;

    // Tight cluster so the player can actually connect them with the starter
    // road budget. Spread expands naturally over subsequent weeks via the
    // SpawnController, not via this fallback.
    final destPos = GridPosition(cx + 4, cy);
    final house1Pos = GridPosition(cx - 4, cy - 1);
    final house2Pos = GridPosition(cx - 4, cy + 1);

    // Sanity check: all four target cells (building + its driveway) must be empty.
    final spots = <GridPosition>[
      destPos, destPos.getNeighbor(Direction.west),
      house1Pos, house1Pos.getNeighbor(Direction.east),
      house2Pos, house2Pos.getNeighbor(Direction.east),
    ];
    for (final s in spots) {
      if (!gm.isValid(s.x, s.y) || !gm.grid[s.y][s.x].isEmpty) {
        debugPrint('[SPAWN] Manual district aborted: cell ${s.key} is not empty');
        return false;
      }
    }

    gm.commitPlacement(() {
      // Destination + driveway
      gm.placeDestination(destPos.x, destPos.y, colorIndex, Direction.west);
      final destDw = destPos.getNeighbor(Direction.west);
      gm.placeRoad(destDw.x, destDw.y, owner: InfrastructureOwner.systemGenerated);
      gm.connectBuilding(destPos.x, destPos.y, destDw.x, destDw.y);

      // House 1 + driveway
      gm.placeHouse(house1Pos.x, house1Pos.y, colorIndex, Direction.east);
      final h1Dw = house1Pos.getNeighbor(Direction.east);
      gm.placeRoad(h1Dw.x, h1Dw.y, owner: InfrastructureOwner.systemGenerated);
      gm.connectBuilding(house1Pos.x, house1Pos.y, h1Dw.x, h1Dw.y);

      // House 2 + driveway
      gm.placeHouse(house2Pos.x, house2Pos.y, colorIndex, Direction.east);
      final h2Dw = house2Pos.getNeighbor(Direction.east);
      gm.placeRoad(h2Dw.x, h2Dw.y, owner: InfrastructureOwner.systemGenerated);
      gm.connectBuilding(house2Pos.x, house2Pos.y, h2Dw.x, h2Dw.y);
    });

    // Register cluster center so later progression logic doesn't try to re-spawn color 0.
    spawnController?.clusterCenters[colorIndex] = destPos;
    spawnController?.residentialCenters[colorIndex] =
        GridPosition((house1Pos.x + house2Pos.x) ~/ 2, (house1Pos.y + house2Pos.y) ~/ 2);

    gridRenderer?.markDirty();
    debugPrint('[SPAWN] Manual district committed at dest=${destPos.key}, '
        'houses=[${house1Pos.key}, ${house2Pos.key}]');
    return true;
  }

  void _syncCameraCenter({bool instant = false, double dt = 0.016}) {
    if (gridManager == null) return;
    final screenW = size.x - hudPanelWidth;
    final screenH = size.y;
    double zoom = camera.viewfinder.zoom;
    if (zoom <= 0.0 || zoom.isNaN || zoom.isInfinite) {
      zoom = 1.0;
    }

    final gridW = gridCols * cellSize;
    final gridH = gridRows * cellSize;
    final target = Vector2(
      (gridW - screenW / zoom) / 2,
      (gridH - screenH / zoom) / 2,
    );

    if (instant) {
      camera.viewfinder.position = target;
    } else {
      final t = 1.0 - pow(0.001, dt).toDouble();
      camera.viewfinder.position += (target - camera.viewfinder.position) * t;
    }
  }

  void _checkWeekTransition() {
    if (weekTimer >= GameConstants.weekDuration) {
      weekTimer = 0;
      week++;
      // Active region grows with the week — refresh spawn bounds so new
      // buildings can land in the newly opened ring of cells, and the camera
      // zoom (derived from the region size) widens to match.
      _syncSpawnBounds();
      MapGeneratorFactory.getGenerator(selectedMapType).generateExpansion(gridManager!, week);
      _triggerWeeklyUpgrade();
    }
  }

  void _triggerWeeklyUpgrade() {
    weeklyOptions = ['doubleRoads', 'tunnels', 'bridges', 'trafficLights', 'smartJunction', 'expressLane'];
    weeklyOptions.shuffle();
    weeklyOptions = weeklyOptions.take(2).toList();
    
    phase = GamePhase.weeklyUpgrade;
    overlays.add('weeklyUpgrade');
    paused = true;
    onStateChanged?.call();
  }

  void _syncSpawnBounds() {
    if (spawnController == null || gridManager == null) return;
    final cx = gridCols ~/ 2;
    final cy = gridRows ~/ 2;
    final hw = _activeHalfWidth;
    final hh = _activeHalfHeight;
    spawnController!.minSpawnX = max(2, cx - hw);
    spawnController!.maxSpawnX = min(gridManager!.cols - 3, cx + hw - 1);
    spawnController!.minSpawnY = max(2, cy - hh);
    spawnController!.maxSpawnY = min(gridManager!.rows - 3, cy + hh - 1);
  }

  /// Returns true if [pos] is inside the current active region — used to block
  /// player builds outside the playable area until weekly expansions open it up.
  bool _isInActiveArea(GridPosition pos) {
    if (spawnController == null) return true;
    return pos.x >= spawnController!.minSpawnX &&
           pos.x <= spawnController!.maxSpawnX &&
           pos.y >= spawnController!.minSpawnY &&
           pos.y <= spawnController!.maxSpawnY;
  }


  @override
  void onPanStart(DragStartInfo info) {
    _panStartPixel = info.eventPosition.global;
    _lastPlacedPos = null;
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    if (phase != GamePhase.playing || paused || _panStartPixel == null) return;
    
    final currentPos = info.eventPosition.global;
    if (!_isDragging) {
      if (_panStartPixel!.distanceTo(currentPos) < dragThreshold) return;
      _isDragging = true;
      gridManager!.interactionState = InteractionState.preview;
    }

    final worldPos = camera.viewfinder.globalToLocal(currentPos);
    final x = ((worldPos.x - boardOffsetX) / cellSize).floor();
    final y = ((worldPos.y - boardOffsetY) / cellSize).floor();
    final pos = GridPosition(x, y);

    if (gridManager!.isValid(pos.x, pos.y)) {
      // Don't preview/queue placements outside the active region — but always
      // allow terrain cells (mountain/water) and existing tunnels/bridges so a
      // road drag can route through them via auto-tunnel / auto-bridge.
      final dragCell = gridManager!.getCell(pos.x, pos.y);
      final isTerrainOrCorridor =
          dragCell.type == CellType.mountain ||
          dragCell.type == CellType.water ||
          dragCell.isTunnel ||
          dragCell.isBridge;
      if (activeTool != BuildTool.erase &&
          !isTerrainOrCorridor &&
          !_isInActiveArea(pos)) {
        return;
      }

      if (activeTool == BuildTool.expressLane) {
        expressLanePendingStart ??= pos;
        expressLaneDraggingEnd = pos;
        gridRenderer?.markDirty();
      } else if (!_dragPath.contains(pos)) {
        _dragPath.add(pos);
        if (!_isDeferredTool) _handleBuild(pos);
        previewPath = List.from(_dragPath);
        gridRenderer?.markDirty(pos.x, pos.y);
      }
    }
  }

  @override
  void onPanEnd(DragEndInfo info) {
    if (activeTool == BuildTool.expressLane) {
      if (expressLanePendingStart != null && expressLaneDraggingEnd != null) {
        gridManager!.placeExpressLane(expressLanePendingStart!, expressLaneDraggingEnd!);
      }
    } else if (_isDragging && _isDeferredTool) {
      gridManager!.commitPlacement(() => _commitDragBuild());
      if (activeTool == BuildTool.erase) _applyEraseRefunds();
    } else if (!_isDragging && _panStartPixel != null) {
      // Single click action
      final worldPos = camera.viewfinder.globalToLocal(_panStartPixel!);
      final x = ((worldPos.x - boardOffsetX) / cellSize).floor();
      final y = ((worldPos.y - boardOffsetY) / cellSize).floor();
      _handleSingleClick(GridPosition(x, y));
      if (activeTool == BuildTool.erase) _applyEraseRefunds();
    }
    _cleanupInput();
  }

  /// Finalize cells marked `isPendingDeletion` by the erase tool: actually
  /// remove them and credit the inventory with whatever the player paid.
  void _applyEraseRefunds() {
    if (gridManager == null) return;
    final activeCarTiles = <GridPosition>{};
    for (final car in _cars) {
      if (car.arrived || car.path.isEmpty) continue;
      final idx = car.currentPathIndex.clamp(0, car.path.length - 1);
      activeCarTiles.add(car.path[idx]);
    }
    final refunds = gridManager!.cleanupPendingDeletions(activeCarTiles);
    if (refunds.isEmpty) return;
    gridManager!.roads += refunds['road'] ?? 0;
    gridManager!.tunnels += refunds['tunnel'] ?? 0;
    gridManager!.bridges += refunds['bridge'] ?? 0;
    gridManager!.trafficLights += refunds['trafficLight'] ?? 0;
    _updateInventoryNotifiers();
    gridRenderer?.markDirty();
    onStateChanged?.call();
  }

  void _cleanupInput() {
    _isDragging = false;
    _panStartPixel = null;
    _dragPath.clear();
    previewPath.clear();
    expressLanePendingStart = null;
    expressLaneDraggingEnd = null;
    gridManager?.interactionState = InteractionState.idle;
    gridRenderer?.markDirty();
  }

  void _commitDragBuild() {
    for (final pos in _dragPath) {
      _handleBuild(pos);
    }
    _autoExtendTunnelExit();
  }

  /// If the drag ended inside terrain (mountain/water) without exiting onto land,
  /// continue the corridor in the drag direction: extend the tunnel/bridge through
  /// matching terrain and lay a road on the first land cell beyond. Players who
  /// drag onto a mountain expect to come out the other side — this closes that gap.
  void _autoExtendTunnelExit() {
    if (gridManager == null || _dragPath.length < 2) return;
    if (activeTool != BuildTool.road &&
        activeTool != BuildTool.tunnel &&
        activeTool != BuildTool.bridge) {
      return;
    }

    final last = _dragPath.last;
    if (!gridManager!.isValid(last.x, last.y)) return;
    final lastCell = gridManager!.getCell(last.x, last.y);
    if (!lastCell.isTunnel && !lastCell.isBridge) return;

    final prev = _dragPath[_dragPath.length - 2];
    final dx = last.x - prev.x;
    final dy = last.y - prev.y;
    if (dx.abs() + dy.abs() != 1) return;

    GridPosition from = last;
    final extendingTunnel = lastCell.isTunnel;
    for (int i = 0; i < 12; i++) {
      final next = GridPosition(from.x + dx, from.y + dy);
      if (!gridManager!.isValid(next.x, next.y)) break;
      final nextCell = gridManager!.getCell(next.x, next.y);

      bool ok;
      if (extendingTunnel && nextCell.type == CellType.mountain) {
        ok = gridManager!.placeTunnel(next.x, next.y, from: from, isExtension: true, consumeRoad: true);
      } else if (!extendingTunnel && nextCell.type == CellType.water) {
        ok = gridManager!.placeBridge(next.x, next.y, from: from, isExtension: true, consumeRoad: true);
      } else if (nextCell.isEmpty) {
        gridManager!.placeRoad(next.x, next.y, from: from);
        break;
      } else {
        break;
      }

      if (!ok) break;
      from = next;
    }
  }

  void _placeTunnelOrExit(GridPosition pos) {
    final cell = gridManager!.getCell(pos.x, pos.y);
    // Tunnel core: only legal on a mountain tile or an existing tunnel tile.
    if (cell.type == CellType.mountain || cell.isTunnel) {
      // If the previous drag cell is already a tunnel/bridge, treat this as an
      // extension so the proximity check in _placeTransitCorridor doesn't
      // reject the rest of a multi-cell mountain crossing. Extensions also
      // consume a road tile — otherwise one tunnel ticket would buy an
      // arbitrarily long chain of tunnels for free.
      bool isExtension = false;
      final lp = _lastPlacedPos;
      if (lp != null && gridManager!.isValid(lp.x, lp.y)) {
        final fromCell = gridManager!.getCell(lp.x, lp.y);
        if (fromCell.isTunnel || fromCell.isBridge) isExtension = true;
      }
      gridManager!.placeTunnel(
        pos.x,
        pos.y,
        from: _lastPlacedPos,
        isExtension: isExtension,
        consumeRoad: isExtension,
      );
      return;
    }
    // Otherwise, if we're continuing from a tunnel/bridge cell, this is the exit:
    // lay a normal road so the tunnel actually connects to the road network.
    if (_lastPlacedPos != null && gridManager!.isValid(_lastPlacedPos!.x, _lastPlacedPos!.y)) {
      final fromCell = gridManager!.getCell(_lastPlacedPos!.x, _lastPlacedPos!.y);
      if (fromCell.isTunnel || fromCell.isBridge) {
        gridManager!.placeRoad(pos.x, pos.y, from: _lastPlacedPos);
      }
    }
  }

  void _placeBridgeOrExit(GridPosition pos) {
    final cell = gridManager!.getCell(pos.x, pos.y);
    if (cell.type == CellType.water || cell.isBridge) {
      bool isExtension = false;
      final lp = _lastPlacedPos;
      if (lp != null && gridManager!.isValid(lp.x, lp.y)) {
        final fromCell = gridManager!.getCell(lp.x, lp.y);
        if (fromCell.isTunnel || fromCell.isBridge) isExtension = true;
      }
      gridManager!.placeBridge(
        pos.x,
        pos.y,
        from: _lastPlacedPos,
        isExtension: isExtension,
        consumeRoad: isExtension,
      );
      return;
    }
    if (_lastPlacedPos != null && gridManager!.isValid(_lastPlacedPos!.x, _lastPlacedPos!.y)) {
      final fromCell = gridManager!.getCell(_lastPlacedPos!.x, _lastPlacedPos!.y);
      if (fromCell.isTunnel || fromCell.isBridge) {
        gridManager!.placeRoad(pos.x, pos.y, from: _lastPlacedPos);
      }
    }
  }

  void _handleBuild(GridPosition pos) {
    if (gridManager == null) return;

    final cell = gridManager!.getCell(pos.x, pos.y);
    final isTerrainOrCorridor =
        cell.type == CellType.mountain ||
        cell.type == CellType.water ||
        cell.isTunnel ||
        cell.isBridge;

    // Confine player builds to the active region — but only for plain cells.
    // Terrain (mountain/water) and existing tunnels/bridges can be acted on
    // anywhere, so a road drag can dig its own tunnel through a nearby
    // mountain even if that mountain is outside the current playable border.
    if (activeTool != BuildTool.erase && !isTerrainOrCorridor && !_isInActiveArea(pos)) {
      return;
    }

    switch (activeTool) {
      case BuildTool.road:
        // Mini-Motorways behaviour: a road drag auto-digs tunnels through
        // mountains and auto-spans bridges over water without the player
        // having to switch tools mid-gesture.
        if (cell.type == CellType.mountain || cell.isTunnel) {
          _placeTunnelOrExit(pos);
        } else if (cell.type == CellType.water || cell.isBridge) {
          _placeBridgeOrExit(pos);
        } else {
          gridManager!.placeRoad(pos.x, pos.y, from: _lastPlacedPos);
        }
        _lastPlacedPos = pos;
        break;
      case BuildTool.tunnel:
        _placeTunnelOrExit(pos);
        _lastPlacedPos = pos;
        break;
      case BuildTool.bridge:
        _placeBridgeOrExit(pos);
        _lastPlacedPos = pos;
        break;
      case BuildTool.erase:
        gridManager!.eraseCell(pos.x, pos.y);
        break;
      default:
        break;
    }
    gridRenderer?.markDirty(pos.x, pos.y);
  }

  void _handleSingleClick(GridPosition pos) {
    if (gridManager == null || !gridManager!.isValid(pos.x, pos.y)) return;
    
    switch (activeTool) {
      case BuildTool.trafficLight:
        gridManager!.toggleTrafficLight(pos.x, pos.y);
        break;
      case BuildTool.smartJunction:
        gridManager!.toggleSmartJunction(pos.x, pos.y);
        break;
      case BuildTool.expressLane:
        // Handle express lane logic if applicable
        break;
      case BuildTool.inspect:
        selectedInfrastructure = pos;
        onStateChanged?.call();
        break;
      default:
        _handleBuild(pos);
        break;
    }
    gridRenderer?.markDirty(pos.x, pos.y);
  }
}
