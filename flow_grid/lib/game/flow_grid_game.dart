import 'dart:math' as math;
import 'dart:math' show Random, min, max, pow;
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../models/game_constants.dart';
import '../models/grid_cell.dart';
import '../models/traffic_phase.dart';
import '../models/road_occupancy.dart';
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
import 'utils/performance_logger.dart';
import 'car_pool.dart';



enum GamePhase { menu, playing, paused, gameOver, weeklyUpgrade }

enum BuildTool { road, bridge, tunnel, trafficLight, smartJunction, expressLane, erase, inspect, upgradeRoad, busStop, busLane, oneWay, metroTrack, elevatedRail, highway, metroStation, priorityIntersection }

class FlowGridGame extends FlameGame with ScaleDetector, MouseMovementDetector, ScrollDetector {
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
  final ValueNotifier<TrafficPhase> trafficPhaseNotifier = ValueNotifier<TrafficPhase>(TrafficPhase.calm);
  
  
  final ValueNotifier<int> roadInventoryNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> tunnelInventoryNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> bridgeInventoryNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> trafficLightInventoryNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> smartJunctionInventoryNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> expressLaneInventoryNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> canUndoNotifier = ValueNotifier<bool>(false);

  final List<Map<String, dynamic>> _undoStack = [];

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
  /// Scaled road count awarded this week — increases every 3 weeks.
  int weeklyBaseRoads = 20;

  final Map<int, List<CarComponent>> carGrid = {};
  final Map<String, RoadOccupancy> occupancyMap = {};

  RoadOccupancy getOrCreateOccupancy(GridPosition pos) {
    final key = pos.side != null ? "${pos.x},${pos.y},${pos.side!.name}" : "${pos.x},${pos.y}";
    return occupancyMap.putIfAbsent(key, () {
      final cell = gridManager?.getCell(pos.x, pos.y);
      final occupancy = RoadOccupancy();
      if (pos.side != null) {
        // Roundabout sub-nodes are strictly single-occupancy
        occupancy.maxCars = 1;
      } else if (cell != null) {
        if (cell.isHighway) {
          occupancy.maxCars = 4;
        } else if (cell.roadLevel >= 1) {
          occupancy.maxCars = 3;
        } else {
          occupancy.maxCars = 2;
        }
      }
      return occupancy;
    });
  }

  void clearOccupancyAt(int x, int y) {
    occupancyMap.remove("$x,$y");
    for (final side in Direction.values) {
      occupancyMap.remove("$x,$y,${side.name}");
    }
  }

  int gridWidth = 0;
  final Map<String, int> houseCarCounts = {};

  int activeColorCount = 1;
  double timeScale = 1.0;

  SpawnController? spawnController;
  late ProgressionDirector progressionDirector;
  late DistrictPlanner districtPlanner;
  late EventManager eventManager;
  
  // Weather & Event simulation variables
  String? activeEvent; // 'blizzard', 'dustStorm', 'animalCrossing', 'drawbridgeOpen', 'flashFlood'
  double eventTimer = 0.0;
  double nextEventCooldown = 25.0; // Trigger the first event after 25s
  double eventDuration = 0.0;
  GridPosition? activeEventPos;
  final List<GridPosition> floodedRoads = [];
  final List<GridPosition> activeEventTiles = [];

  late TransitManager transitManager;
  late EmergencyManager emergencyManager;

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
  //
  // On a landscape phone (~2.0 aspect) the height drives the size — the
  // aspect-fit in _syncSpawnBounds expands the half-width to hh*screenAspect.
  static const int _initialActiveHalfWidth = 7;    // Week 1: 14 cells wide (base, before aspect-fit)
  static const int _initialActiveHalfHeight = 5;   // Week 1: 10 cells tall
  static const int _weeklyActiveExpansionX = 2;    // +4 width per week
  static const int _weeklyActiveExpansionY = 1;    // +2 height per week

  bool previewMode = false;
  double smoothWeek = 1.0;
  double _initialZoom = 1.0;
  Vector2? _scaleStartPixel;
  Vector2? _initialCameraPos;

  int get _activeHalfWidth {
    final maxHalf = (gridCols - 4) ~/ 2;
    return min(maxHalf, _initialActiveHalfWidth + (week - 1) * _weeklyActiveExpansionX);
  }

  int get _activeHalfHeight {
    final maxHalf = (gridRows - 4) ~/ 2;
    return min(maxHalf, _initialActiveHalfHeight + (week - 1) * _weeklyActiveExpansionY);
  }

  double get smoothActiveHalfWidth {
    final maxHalf = (gridCols - 4) / 2.0;
    return min(maxHalf, _initialActiveHalfWidth.toDouble() + (smoothWeek - 1.0) * _weeklyActiveExpansionX);
  }

  double get smoothActiveHalfHeight {
    final maxHalf = (gridRows - 4) / 2.0;
    return min(maxHalf, _initialActiveHalfHeight.toDouble() + (smoothWeek - 1.0) * _weeklyActiveExpansionY);
  }

  math.Point<double> getSmoothActiveHalfDimensions() {
    double hw = smoothActiveHalfWidth;
    double hh = smoothActiveHalfHeight;
    
    if (size.x > 100 && size.y > 100) {
      const double padding = 16.0;
      final screenW = size.x - hudPanelWidth - (2 * padding);
      final screenH = size.y - (2 * padding);
      if (screenW > 0 && screenH > 0) {
        final screenAspect = screenW / screenH;
        final baseAspect = hw / hh;
        if (screenAspect > baseAspect) {
          hw = hh * screenAspect;
          final maxHw = (gridCols - 4) / 2.0;
          if (hw > maxHw) hw = maxHw;
        } else {
          hh = hw / screenAspect;
          final maxHh = (gridRows - 4) / 2.0;
          if (hh > maxHh) hh = maxHh;
        }
      }
    }
    return math.Point(hw, hh);
  }

  double get _baseZoom {
    if (size.x <= 100 || size.y <= 100) return 1.0;
    const double padding = 16.0;
    final screenW = size.x - hudPanelWidth - (2 * padding);
    final screenH = size.y - (2 * padding);
    if (screenW <= 0 || screenH <= 0) return 1.0;

    double w;
    double h;
    if (spawnController != null) {
      final dims = getSmoothActiveHalfDimensions();
      w = (dims.x * 2.0) * cellSize;
      h = (dims.y * 2.0) * cellSize;
    } else {
      w = (smoothActiveHalfWidth * 2) * cellSize;
      h = (smoothActiveHalfHeight * 2) * cellSize;
    }
    final zoomX = screenW / w;
    final zoomY = screenH / h;
    return min(zoomX, zoomY).clamp(0.1, 8.0);
  }

  double get _targetZoom {
    if (size.x <= 100 || size.y <= 100) return 0.5;

    // Small inset for breathing room — large enough that the active region's
    // vignette edge doesn't crowd the screen edge, but tight enough that on a
    // phone the active region still fills most of the viewport.
    const double padding = 16.0;
    final screenW = size.x - hudPanelWidth - (2 * padding);
    final screenH = size.y - (2 * padding);

    if (screenW <= 0 || screenH <= 0) return 0.5;

    double w;
    double h;
    if (spawnController != null) {
      final dims = getSmoothActiveHalfDimensions();
      w = (dims.x * 2.0) * cellSize;
      h = (dims.y * 2.0) * cellSize;
    } else {
      w = (smoothActiveHalfWidth * 2) * cellSize;
      h = (smoothActiveHalfHeight * 2) * cellSize;
    }

    final zoomX = screenW / w;
    final zoomY = screenH / h;
    // Fit the active region edge-to-edge into the inset screen rect — the 16px
    // padding above is the only breathing room. Any further multiplier here
    // (e.g. 0.85) leaves a visibly large empty band between the active region
    // and the HUD on a phone.
    final baseZoom = min(zoomX, zoomY).clamp(0.1, 8.0);
    return (baseZoom * userZoomMultiplier).clamp(0.2, 5.0);
  }

  double userZoomMultiplier = 1.0;

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

  // ── Camera Focus (event tap / game-over cinematic) ──────────────────────────
  /// World-space position the camera is smoothly targeting.  When non-null,
  /// _syncCameraCenter yields so the programmatic focus takes precedence.
  Vector2? _cameraFocusTarget;

  // ── Game-over cinematic transition ───────────────────────────────────────────
  bool _gameOverTransitioning = false;
  double _gameOverTransitionTimer = 0.0;
  static const double _gameOverZoomInDuration = 1.8; // seconds before overlay shows
  static const double _gameOverZoomMultiplier = 2.5;

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
  // Drag threshold in screen pixels. At a typical mobile zoom (~0.6) a single
  // cell is ~24 screen pixels, so the old 8px threshold let normal finger
  // jitter during a tap cross into an adjacent cell — both cells ended up in
  // dragPath and the player was charged for two roads on what felt like a
  // single tap. ~24px keeps a tap as a tap unless the user really intended
  // to drag.
  static const double dragThreshold = 24.0;

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
    _undoStack.clear();
    canUndoNotifier.value = false;
    score = 0;
    week = 1;
    smoothWeek = 1.0;
    previewMode = false;
    totalDeliveries = 0;
    weekTimer = 0;
    _elapsedTime = 0;
    activeColorCount = 1;
    _pathCache.clear();
    occupancyMap.clear();
    // Reset cinematic transition state
    _gameOverTransitioning = false;
    _gameOverTransitionTimer = 0.0;
    clearCameraFocus();
    userZoomMultiplier = 1.0;

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
        selectedMapType = MapType.values[save['mapType'] ?? 0];
        gridManager = GridManager(gridCols, gridRows, selectedMapType: selectedMapType, initTerrain: false);
        
        // Restore Grid, Inventories, Driveways, and Demand State Unifiedly
        gridManager!.loadFromSave(save);

        // Restore Metadata
        week = save['week'] ?? 1;
        smoothWeek = week.toDouble();
        previewMode = false;
        score = save['score'] ?? 0;
        totalDeliveries = save['totalDeliveries'] ?? 0;
        weekTimer = (save['weekTimer'] as num?)?.toDouble() ?? 0;
        _elapsedTime = (save['elapsedTime'] as num?)?.toDouble() ?? 0;
        activeColorCount = save['activeColorCount'] ?? 1;
        userZoomMultiplier = (save['userZoomMultiplier'] as num?)?.toDouble() ?? 1.0;

        // Camera
        camera.viewfinder.zoom = (save['cameraZoom'] as num?)?.toDouble() ?? 1.0;
        camera.viewfinder.position = Vector2(
          (save['cameraPosX'] as num?)?.toDouble() ?? 0.0,
          (save['cameraPosY'] as num?)?.toDouble() ?? 0.0,
        );
      }
    } else {
      // New Game
      // Mini-Motorways style — the active play region grows from ~20x14 to
      // around 32x22 by late game, so generating a 64x40 grid was 2-3x more
      // cells than the player can ever see. The extra cells were a major
      // mobile cost (chunk pictures, terrain scans, pathfinding) for no
      // gameplay benefit.
      gridCols = 48;
      gridRows = 36;
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
    spawnController!.onBuildingSpawned = (pos) {
      gridRenderer?.registerSpawnAnimation(pos);
      if (GameConstants.debugInfrastructure) {
        debugPrint('[BREADCRUMB] Building spawned at coordinate: (${pos.x}, ${pos.y})');
      }
    };
    spawnController!.onLog = (msg) => debugPrint('[SPAWN] $msg');
    debugPrint("[SPAWN_MANAGER_INIT] SpawnController created and scoring initialized");
    gridRenderer = GridRenderer(gridManager: gridManager!, cellSize: cellSize);
    world.add(gridRenderer!);
    
    // Initialize Managers with valid references
    eventManager = EventManager(gridManager: gridManager!, districtPlanner: districtPlanner);
    transitManager = TransitManager();
    emergencyManager = EmergencyManager();
    progressionDirector = ProgressionDirector(spawnController!);
    progressionDirector.reset();
    if (resume) {
      spawnController!.restoreStateFromGrid(activeColorCount, _elapsedTime);
      progressionDirector.restoreState(week, _elapsedTime);
      for (int i = 0; i < activeColorCount; i++) {
        progressionDirector.registerUnlockedColor(i, 1);
      }
      if (GameConstants.debugInfrastructure) {
        debugPrint('[BREADCRUMB] Game loaded from slot $slotIndex. Week: $week, Score: $score, Active Colors: $activeColorCount.');
      }
    } else {
      if (GameConstants.debugInfrastructure) {
        debugPrint('[BREADCRUMB] Starting new game on map: $selectedMapType');
      }
    }

    // Add components to the game tree
    add(eventManager);
    add(transitManager);
    add(emergencyManager);
    debugPrint("[WORLD_INIT] Components added to game tree");

    // Connect callbacks
    gridManager!.onTopologyChanged = () {
      _pathCache.clear();
      for (final car in List.of(_cars)) {
        car.recalculatePath();
      }
    };
    gridManager!.isStagedBuilding = (x, y) => spawnController?.isStagedBuildingPosition(x, y) ?? false;

    phase = GamePhase.playing;
    paused = false;
    _syncSpawnBounds();
    camera.viewfinder.zoom = _targetZoom;
    _syncCameraCenter(instant: true);

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
      userZoomMultiplier: userZoomMultiplier,
      slotIndex: currentSlotIndex,
    );
  }

  void applyUpgrade(String option) {
    if (gridManager == null) return;
    final base = weeklyBaseRoads;

    if (option == 'tunnels') {
      gridManager!.roads += base;
      gridManager!.tunnels += 1;
    } else if (option == 'bridges') {
      gridManager!.roads += base;
      gridManager!.bridges += 1;
    } else if (option == 'trafficLights') {
      gridManager!.roads += base;
      gridManager!.trafficLights += 1;
    } else if (option == 'smartJunction') {
      gridManager!.roads += base;
      gridManager!.smartJunctions += 1;
    } else if (option == 'expressLane') {
      gridManager!.roads += (base * 0.6).round();
      gridManager!.expressLanes += 1;
    } else if (option == 'doubleRoads') {
      gridManager!.roads += base + 10;
    // ── Gamble outcomes ──────────────────────────────────────────────────────
    } else if (option == 'gamble_jackpot') {
      gridManager!.roads += 50;
      gridManager!.tunnels += 1;
      gridManager!.expressLanes += 1;
    } else if (option == 'gamble_bigwin') {
      gridManager!.roads += base + 15;
      gridManager!.smartJunctions += 1;
    } else if (option == 'gamble_win') {
      gridManager!.roads += base;
      gridManager!.trafficLights += 1;
    } else if (option == 'gamble_bust') {
      gridManager!.roads += 5;
    } else if (option == 'gamble_disaster') {
      gridManager!.roads = max(0, gridManager!.roads - 10);
      gridManager!.expressLanes += 1; // consolation prize
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
    trafficPhaseNotifier.value = trafficClock.currentPhase;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (phase == GamePhase.playing) {
      _syncSpawnBounds();
      camera.viewfinder.zoom = _targetZoom;
      _syncCameraCenter(instant: true);
      gridRenderer?.markDirty();
    }
  }

  double _debugLogTimer = 0;

  @override
  void update(double dt) {
    super.update(dt);

    if (smoothWeek < week) {
      smoothWeek = min(week.toDouble(), smoothWeek + dt * 0.4);
      _syncSpawnBounds();
      _syncCameraCenter(dt: dt);
    } else if (smoothWeek > week) {
      smoothWeek = week.toDouble();
      _syncSpawnBounds();
    }

    // First valid frame: snap the camera (zoom + position) to its target so
    // the player doesn't watch a ~half-second zoom drift at start-up.
    if (phase == GamePhase.playing && !_initialSyncDone && size.x > 100) {
      _syncSpawnBounds();
      camera.viewfinder.zoom = _targetZoom;
      _syncCameraCenter(instant: true);
      _initialSyncDone = true;
      debugPrint("[SYNC] Initial camera and spawn bounds synchronized with size: $size");

      _tryInitialSpawn();
    }

    // Tier 1: Real-time (Camera, Animations) — runs after the snap above so
    // the first valid frame already lands at the target zoom.
    _updateCameraSmoothing(dt.clamp(0.0, 0.05));

    _debugLogTimer += dt;
    if (_debugLogTimer > 5.0) {
      debugPrint("[UPDATE_LOOP_ACTIVE] phase: $phase, paused: $paused, week: $week, zoom: ${camera.viewfinder.zoom.toStringAsFixed(3)}, targetZoom: ${_targetZoom.toStringAsFixed(3)}, activeArea: [${spawnController?.minSpawnX}..${spawnController?.maxSpawnX}, ${spawnController?.minSpawnY}..${spawnController?.maxSpawnY}]");
      _debugLogTimer = 0;
    }
    
    if (phase != GamePhase.playing || paused || _gameOverTransitioning || timeScale == 0.0) return;
    
    final safeDt = dt.clamp(0.0, 0.05);
    final scaledDt = safeDt * timeScale;
    _elapsedTime += scaledDt;
    weekTimer += scaledDt;
    _updateMapSpecificEvents(scaledDt);

    // Tier 2: 15Hz - Physics & Traffic AI
    // Pass the accumulated tick interval (scaled), not just the last frame's dt,
    // so per-house timers accrue at real-time speed.
    _logicTickTimer += safeDt;
    if (_logicTickTimer >= 1 / 15) {
      final logicDt = _logicTickTimer * timeScale;
      _logicTickTimer = 0;
      _rebuildSpatialGrid();
      trafficClock.update(weekProgress);
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
      gridManager?.updateDemand(simDt);
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
      _checkGameOver();
    }
  }

  void _checkGameOver() {
    if (_gameOverTransitioning) return; // already transitioning, don't re-trigger
    final gm = gridManager;
    if (gm == null) return;
    for (final dest in gm.destinations) {
      final key = '${dest.x},${dest.y}';
      final overflow = gm.overflowLevels[key] ?? 0.0;
      if (overflow >= 1.0) {
        _startGameOverTransition(dest);
        return;
      }
    }
  }

  void _startGameOverTransition(GridPosition overflowDest) {
    _gameOverTransitioning = true;
    _gameOverTransitionTimer = 0.0;
    // Zoom into the losing building for a cinematic beat.
    // NOTE: Do NOT set paused = true here — Flame's paused flag stops the
    // entire update() loop, which means _updateCameraSmoothing never ticks
    // and _finishGameOverTransition is never called. Instead we use the
    // _gameOverTransitioning flag to suppress game-logic tiers below.
    focusCameraOnGridPosition(overflowDest, zoomMultiplier: _gameOverZoomMultiplier);
  }

  void _finishGameOverTransition() {
    _gameOverTransitioning = false;
    clearCameraFocus();
    userZoomMultiplier = 1.0;
    phase = GamePhase.gameOver;
    overlays.remove('hud');
    overlays.add('gameOver');
    onStateChanged?.call();
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
        if (!car.isReturning && gridManager != null) {
          final destKey = "${car.targetDest.x},${car.targetDest.y}";
          final currentClaimed = gridManager!.claimedDemand[destKey] ?? 0;
          if (currentClaimed > 0) {
            gridManager!.claimedDemand[destKey] = currentClaimed - 1;
          }
        }
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
    // ── Game-over cinematic transition ─────────────────────────────────────────
    if (_gameOverTransitioning) {
      _gameOverTransitionTimer += dt;
      // Smoothly lerp the viewfinder toward the focus target
      if (_cameraFocusTarget != null) {
        final t = 1.0 - pow(0.005, dt).toDouble(); // smooth exponential lerp
        camera.viewfinder.position += (_cameraFocusTarget! - camera.viewfinder.position) * t;
      }
      // Lerp zoom in.
      // NOTE: _targetZoom already incorporates userZoomMultiplier which was set
      // to _gameOverZoomMultiplier by focusCameraOnGridPosition — do NOT
      // multiply by _gameOverZoomMultiplier again or zoom double-compounds.
      final targetZoom = _targetZoom.clamp(0.2, 8.0);
      final zoomT = 1.0 - pow(0.005, dt).toDouble();
      camera.viewfinder.zoom += (targetZoom - camera.viewfinder.zoom) * zoomT;
      if (_gameOverTransitionTimer >= _gameOverZoomInDuration) {
        _finishGameOverTransition();
      }
      return;
    }

    if ((camera.viewfinder.zoom - _targetZoom).abs() > 0.001) {
      final zoomLerp = 1.0 - pow(0.05, dt).toDouble();
      final delta = (_targetZoom - camera.viewfinder.zoom) * zoomLerp;
      // Clamp rate of zoom change to be smooth and frame-rate independent (max 0.3 units per second)
      final maxChange = 0.3 * dt;
      final oldZoom = camera.viewfinder.zoom;
      camera.viewfinder.zoom += delta.clamp(-maxChange, maxChange);
      if (GameConstants.debugInfrastructure && (camera.viewfinder.zoom - oldZoom).abs() > 0.01) {
        debugPrint('[BREADCRUMB] Zoom changed: ${camera.viewfinder.zoom.toStringAsFixed(2)}x');
      }
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

              // Buildings aren't pathfinder nodes (they're not passable), so
              // splice them onto the ends here. The `side` makes the car park
              // at the building's door (where the driveway stub meets the body)
              // instead of the cell center, which looks correct for both the
              // small house sprites and the larger destinations.
              final houseEntry = gridManager!.getCell(housePos.x, housePos.y).entrySide;
              final destEntry = gridManager!.getCell(dest.x, dest.y).entrySide;
              final fullPath = <GridPosition>[
                if (houseEntry != null)
                  GridPosition(housePos.x, housePos.y, houseEntry)
                else
                  GridPosition(housePos.x, housePos.y),
                ...path,
                if (destEntry != null)
                  GridPosition(dest.x, dest.y, destEntry)
                else
                  GridPosition(dest.x, dest.y),
              ];

              final car = carPool.getCar(
                path: fullPath,
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
              
              // Claim the demand!
              final destKey = "${dest.x},${dest.y}";
              gridManager!.claimedDemand[destKey] = (gridManager!.claimedDemand[destKey] ?? 0) + 1;
              
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
    final targets = gridManager!.destinations.where((d) {
      final cell = gridManager!.getCell(d.x, d.y);
      if (cell.colorIndex != houseCell.colorIndex) return false;
      
      final key = "${d.x},${d.y}";
      final demandVal = gridManager!.demand[key] ?? 0;
      final claimedVal = gridManager!.claimedDemand[key] ?? 0;
      return demandVal > claimedVal;
    }).toList();
    
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
      gridRenderer?.registerSpawnAnimation(destPos);
      final destDw = destPos.getNeighbor(Direction.west);
      gm.placeRoad(destDw.x, destDw.y, owner: InfrastructureOwner.systemGenerated);
      gm.connectBuilding(destPos.x, destPos.y, destDw.x, destDw.y);

      // House 1 + driveway
      gm.placeHouse(house1Pos.x, house1Pos.y, colorIndex, Direction.east);
      gridRenderer?.registerSpawnAnimation(house1Pos);
      final h1Dw = house1Pos.getNeighbor(Direction.east);
      gm.placeRoad(h1Dw.x, h1Dw.y, owner: InfrastructureOwner.systemGenerated);
      gm.connectBuilding(house1Pos.x, house1Pos.y, h1Dw.x, h1Dw.y);

      // House 2 + driveway
      gm.placeHouse(house2Pos.x, house2Pos.y, colorIndex, Direction.east);
      gridRenderer?.registerSpawnAnimation(house2Pos);
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

    // While a programmatic camera focus is active (e.g. event tap or game-over
    // cinematic) we interpolate toward the focus target instead of the normal
    // active-region center.
    if (_cameraFocusTarget != null) {
      final t = instant ? 1.0 : (1.0 - pow(0.001, dt).toDouble());
      camera.viewfinder.position += (_cameraFocusTarget! - camera.viewfinder.position) * t;
      return;
    }

    final screenW = size.x - hudPanelWidth;
    final screenH = size.y;
    double zoom = camera.viewfinder.zoom;
    if (zoom <= 0.0 || zoom.isNaN || zoom.isInfinite) {
      zoom = 1.0;
    }

    Vector2 target;
    if (spawnController != null) {
      final dims = getSmoothActiveHalfDimensions();
      final hw = dims.x;
      final hh = dims.y;
      final cx = gridCols / 2.0;
      final cy = gridRows / 2.0;
      final minX = math.max(2.0, cx - hw);
      final minY = math.max(2.0, cy - hh);
      final w = hw * 2.0 * cellSize;
      final h = hh * 2.0 * cellSize;
      
      final targetX = (boardOffsetX + minX * cellSize) - ((screenW / zoom) - w) / 2;
      final targetY = (boardOffsetY + minY * cellSize) - ((screenH / zoom) - h) / 2;
      target = Vector2(targetX, targetY);
    } else {
      final gridW = gridCols * cellSize;
      final gridH = gridRows * cellSize;
      target = Vector2(
        (gridW - screenW / zoom) / 2,
        (gridH - screenH / zoom) / 2,
      );
    }

    if (instant) {
      camera.viewfinder.position = target;
    } else {
      final t = 1.0 - pow(0.001, dt).toDouble();
      camera.viewfinder.position += (target - camera.viewfinder.position) * t;
    }
  }

  /// Smoothly pan and zoom the camera to centre on [pos] (grid coordinates).
  /// [zoomMultiplier] scales the current game zoom — 1.0 keeps the normal
  /// gameplay zoom, 2.5 zooms in for e.g. the game-over cinematic.
  void focusCameraOnGridPosition(GridPosition pos, {double zoomMultiplier = 1.0}) {
    final worldX = boardOffsetX + pos.x * cellSize + cellSize / 2;
    final worldY = boardOffsetY + pos.y * cellSize + cellSize / 2;
    final zoom = (zoomMultiplier > 0.0 ? zoomMultiplier : 1.0);
    final screenW = size.x - hudPanelWidth;
    final screenH = size.y;
    final effectiveZoom = (_targetZoom * zoom).clamp(0.2, 8.0);
    final targetX = worldX - (screenW / effectiveZoom) / 2;
    final targetY = worldY - (screenH / effectiveZoom) / 2;
    _cameraFocusTarget = Vector2(targetX, targetY);
    userZoomMultiplier = zoom;
  }

  /// Clear any active programmatic camera focus, returning control to the
  /// normal active-region tracking.  Called when the player pans/zooms.
  void clearCameraFocus() {
    _cameraFocusTarget = null;
  }

  void _checkWeekTransition() {
    if (weekTimer >= GameConstants.weekDuration) {
      weekTimer = 0;
      _triggerWeeklyUpgrade();
    }
  }

  void _triggerWeeklyUpgrade() {
    if (gridManager == null) return;

    week++;
    for (final dest in gridManager!.destinations) {
      final key = "${dest.x},${dest.y}";
      gridManager!.destinationAges[key] = (gridManager!.destinationAges[key] ?? 0) + 1;
      gridRenderer?.markDirty(dest.x, dest.y);
    }
    _syncSpawnBounds();
    MapGeneratorFactory.getGenerator(selectedMapType).generateExpansion(gridManager!, week);

    // Road count scales up every 3 weeks (20 → 25 → 30 → ...)
    weeklyBaseRoads = 20 + (week ~/ 3) * 5;

    final options = <String>['doubleRoads', 'trafficLights', 'smartJunction', 'expressLane'];
    if (selectedMapType == MapType.nile || selectedMapType == MapType.delta) {
      options.add('bridges');
    }
    if (selectedMapType == MapType.andes || selectedMapType == MapType.savanna || selectedMapType == MapType.arctic) {
      options.add('tunnels');
    }

    options.shuffle();
    // Always 3 choices: 2 normal + 1 gamble card
    weeklyOptions = [...options.take(2), 'gamble'];
    weeklyOptions.shuffle();

    phase = GamePhase.weeklyUpgrade;
    overlays.add('weeklyUpgrade');
    paused = true;
    onStateChanged?.call();
  }

  /// Roll the gamble outcome. Returns a key that is passed back to applyUpgrade.
  String rollGamble() {
    final r = Random().nextDouble();
    if (r < 0.08) return 'jackpot';   //  8% — massive haul
    if (r < 0.28) return 'bigwin';    // 20% — great deal
    if (r < 0.58) return 'win';       // 30% — solid win
    if (r < 0.83) return 'bust';      // 25% — scraps
    return 'disaster';                 // 17% — painful
  }

  void _syncSpawnBounds() {
    if (spawnController == null || gridManager == null) return;
    
    // Base active half-dimensions for the current week
    int hw = _activeHalfWidth;
    int hh = _activeHalfHeight;
    
    // Adjust to match the viewport aspect ratio to eliminate black bars.
    // Keep this padding in sync with _targetZoom so the active region's aspect
    // matches the screen rect the camera is fitting it into.
    if (size.x > 100 && size.y > 100) {
      const double padding = 16.0;
      final screenW = size.x - hudPanelWidth - (2 * padding);
      final screenH = size.y - (2 * padding);
      if (screenW > 0 && screenH > 0) {
        final screenAspect = screenW / screenH;
        final baseAspect = hw / hh;
        if (screenAspect > baseAspect) {
          // Screen is wider: expand hw to match height
          hw = (hh * screenAspect).round();
          // Clamp to grid limits
          final maxHw = (gridCols - 4) ~/ 2;
          if (hw > maxHw) hw = maxHw;
        } else {
          // Screen is taller: expand hh to match width
          hh = (hw / screenAspect).round();
          // Clamp to grid limits
          final maxHh = (gridRows - 4) ~/ 2;
          if (hh > maxHh) hh = maxHh;
        }
      }
    }

    final cx = gridCols ~/ 2;
    final cy = gridRows ~/ 2;
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
  List<GridPosition> _interpolateAdjacentCells(GridPosition start, GridPosition end) {
    final result = <GridPosition>[];
    int cx = start.x;
    int cy = start.y;
    final tx = end.x;
    final ty = end.y;

    while (cx != tx || cy != ty) {
      if (cx != tx) {
        cx += (tx - cx).sign;
      } else if (cy != ty) {
        cy += (ty - cy).sign;
      }
      result.add(GridPosition(cx, cy));
    }
    return result;
  }

  @override
  void onScroll(PointerScrollInfo info) {
    if (phase != GamePhase.playing) return;
    final screenFocal = info.eventPosition.global;
    final worldFocalBefore = camera.viewfinder.globalToLocal(screenFocal);

    final scrollDelta = info.scrollDelta.global.y;
    if (scrollDelta < 0) {
      userZoomMultiplier = (userZoomMultiplier * 1.08).clamp(0.2, 5.0);
    } else if (scrollDelta > 0) {
      userZoomMultiplier = (userZoomMultiplier / 1.08).clamp(0.2, 5.0);
    }

    final oldZoom = camera.viewfinder.zoom;
    camera.viewfinder.zoom = _targetZoom;
    if (GameConstants.debugInfrastructure && (camera.viewfinder.zoom - oldZoom).abs() > 0.01) {
      debugPrint('[BREADCRUMB] Zoom changed manually (scroll): ${camera.viewfinder.zoom.toStringAsFixed(2)}x');
    }

    final worldFocalAfter = camera.viewfinder.globalToLocal(screenFocal);
    camera.viewfinder.position += (worldFocalBefore - worldFocalAfter);

    onStateChanged?.call();
  }

  @override
  void onScaleStart(ScaleStartInfo info) {
    // Cancel any programmatic camera focus (event tap / game-over cinematic)
    // so the player's gesture takes control immediately.
    clearCameraFocus();

    // Always capture zoom start state in case user uses multi-touch
    _initialZoom = camera.viewfinder.zoom;
    _scaleStartPixel = info.eventPosition.global;
    _initialCameraPos = camera.viewfinder.position.clone();

    if (!previewMode) {
      _panStartPixel = info.eventPosition.global;
      _lastPlacedPos = null;
    }
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    final pointerCount = info.raw.pointerCount;

    if (previewMode || pointerCount > 1) {
      // Clear drag path if multi-touch starts so we don't draw weird trailing segments
      if (pointerCount > 1) {
        _panStartPixel = null;
        if (_isDragging) {
          _isDragging = false;
          _dragPath.clear();
          previewPath.clear();
          expressLanePendingStart = null;
          expressLaneDraggingEnd = null;
          gridManager!.interactionState = InteractionState.idle;
          gridRenderer?.markDirty();
        }
      }

      if (_scaleStartPixel == null || _initialCameraPos == null) return;
      
      final screenFocal = info.eventPosition.global;
      // 1. Convert screen focal point to world before zooming
      final worldFocalBefore = camera.viewfinder.globalToLocal(screenFocal);

      // 2. Handle Zoom
      final newZoom = (_initialZoom * info.raw.scale).clamp(0.2, 5.0);
      if (GameConstants.debugInfrastructure && (camera.viewfinder.zoom - newZoom).abs() > 0.01) {
        debugPrint('[BREADCRUMB] Zoom changed manually (pinch): ${newZoom.toStringAsFixed(2)}x');
      }
      camera.viewfinder.zoom = newZoom;
      userZoomMultiplier = (newZoom / _baseZoom).clamp(0.2, 5.0);
      
      // 3. Convert screen focal point to world after zooming
      final worldFocalAfter = camera.viewfinder.globalToLocal(screenFocal);

      // 4. Handle Pan & Focal-point correction to prevent jumps
      final deltaPixel = screenFocal - _scaleStartPixel!;
      camera.viewfinder.position = _initialCameraPos! - deltaPixel / camera.viewfinder.zoom;
      
      // Correct viewfinder position so the focal point doesn't slide
      camera.viewfinder.position += (worldFocalBefore - worldFocalAfter);
    } else {
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
        if (activeTool == BuildTool.expressLane) {
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
          expressLanePendingStart ??= pos;
          expressLaneDraggingEnd = pos;
          gridRenderer?.markDirty();
        } else {
          if (_dragPath.isEmpty) {
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
            _dragPath.add(pos);
            if (!_isDeferredTool) _handleBuild(pos);
            previewPath = List.from(_dragPath);
            gridRenderer?.markDirty(pos.x, pos.y);
          } else {
            final last = _dragPath.last;
            final idx = _dragPath.indexOf(pos);
            if (idx != -1 && idx < _dragPath.length - 1) {
              // Revert/Backtrack: Remove all cells in the path after this cell
              for (int i = _dragPath.length - 1; i > idx; i--) {
                final removedPos = _dragPath[i];
                gridRenderer?.markDirty(removedPos.x, removedPos.y);
              }
              _dragPath.removeRange(idx + 1, _dragPath.length);
              previewPath = List.from(_dragPath);
              gridRenderer?.markDirty(pos.x, pos.y);
            } else if (last != pos) {
              final steps = _interpolateAdjacentCells(last, pos);
              for (final step in steps) {
                if (gridManager!.isValid(step.x, step.y) && !_dragPath.contains(step)) {
                  final stepCell = gridManager!.getCell(step.x, step.y);
                  final isTerrainOrCorridor =
                      stepCell.type == CellType.mountain ||
                      stepCell.type == CellType.water ||
                      stepCell.isTunnel ||
                      stepCell.isBridge;
                  if (activeTool != BuildTool.erase &&
                      !isTerrainOrCorridor &&
                      !_isInActiveArea(step)) {
                    continue;
                  }
                  _dragPath.add(step);
                  if (!_isDeferredTool) _handleBuild(step);
                  gridRenderer?.markDirty(step.x, step.y);
                }
              }
              previewPath = List.from(_dragPath);
            }
          }
        }
      }
    }
  }

  @override
  void onScaleEnd(ScaleEndInfo info) {
    if (previewMode) {
      _scaleStartPixel = null;
      _initialCameraPos = null;
    } else {
      if (activeTool == BuildTool.expressLane) {
        if (expressLanePendingStart != null && expressLaneDraggingEnd != null) {
          executeUndoableAction(() {
            final placed = gridManager!.placeExpressLane(
                expressLanePendingStart!, expressLaneDraggingEnd!);
            if (placed) {
              _updateInventoryNotifiers();
              onStateChanged?.call();
            }
          });
        }
      } else if (_isDragging && _isDeferredTool) {
        if (_dragPath.length > 1) {
          executeUndoableAction(() {
            gridManager!.commitPlacement(() => _commitDragBuild());
            if (activeTool == BuildTool.erase) _applyEraseRefunds();
          });
        }
      } else if (!_isDragging && _panStartPixel != null) {
        // Single click action
        final worldPos = camera.viewfinder.globalToLocal(_panStartPixel!);
        final x = ((worldPos.x - boardOffsetX) / cellSize).floor();
        final y = ((worldPos.y - boardOffsetY) / cellSize).floor();
        executeUndoableAction(() {
          _handleSingleClick(GridPosition(x, y));
          if (activeTool == BuildTool.erase) _applyEraseRefunds();
        });
      }
      _cleanupInput();
    }
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
    _cleanupOrphanedTunnels();
  }

  /// After a drag commit, remove any tunnel/bridge tile that has fewer than 2
  /// edge connections (i.e. it has an entry but no exit — a dead-end corridor).
  /// This prevents single orphaned tunnel tiles from appearing when the drag
  /// briefly clips one mountain/water cell without crossing through it.
  void _cleanupOrphanedTunnels() {
    if (gridManager == null) return;
    final gm = gridManager!;

    for (final pos in List<GridPosition>.from(_dragPath)) {
      if (!gm.isValid(pos.x, pos.y)) continue;
      final cell = gm.getCell(pos.x, pos.y);
      if (!cell.isTunnel && !cell.isBridge) continue;

      // Count active edges touching this tile
      int edgeCount = 0;
      for (final d in const [[0, -1], [1, 0], [0, 1], [-1, 0]]) {
        final nx = pos.x + d[0];
        final ny = pos.y + d[1];
        if (gm.isValid(nx, ny) && gm.hasEdge(pos.x, pos.y, nx, ny)) {
          edgeCount++;
        }
      }

      // A corridor tile with fewer than 2 edges is orphaned — remove it.
      if (edgeCount < 2) {
        final isTunnel = cell.isTunnel;
        gm.grid[pos.y][pos.x] = GridCell(); // erase
        gm.activeEdges.removeWhere((e) {
          final parts = e.split('|');
          if (parts.length != 2) return false;
          return parts[0] == '${pos.x},${pos.y}' || parts[1] == '${pos.x},${pos.y}';
        });
        gm.infrastructure.remove(pos);
        // Refund the inventory cost for this tile
        if (isTunnel) {
          gm.tunnels += 1;
        } else {
          gm.bridges += 1;
        }
        gm.rebuildRoadGraph();
        gridRenderer?.markDirty(pos.x, pos.y);
      }
    }
    _updateInventoryNotifiers();
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
        } else if ((cell.type == CellType.water || cell.isBridge) && selectedMapType != MapType.arctic) {
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
        clearOccupancyAt(pos.x, pos.y);
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

  bool _areSnapshotsIdentical(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a['roads'] != b['roads'] ||
        a['tunnels'] != b['tunnels'] ||
        a['bridges'] != b['bridges'] ||
        a['trafficLights'] != b['trafficLights'] ||
        a['smartJunctions'] != b['smartJunctions'] ||
        a['expressLanes'] != b['expressLanes']) {
      return false;
    }

    final List<List<GridCell>> aGrid = a['grid'];
    final List<List<GridCell>> bGrid = b['grid'];
    for (int y = 0; y < gridManager!.rows; y++) {
      for (int x = 0; x < gridManager!.cols; x++) {
        final ca = aGrid[y][x];
        final cb = bGrid[y][x];
        if (ca.type != cb.type ||
            ca.hasTrafficLight != cb.hasTrafficLight ||
            ca.isTunnelExtension != cb.isTunnelExtension ||
            ca.connUp != cb.connUp ||
            ca.connRight != cb.connRight ||
            ca.connDown != cb.connDown ||
            ca.connLeft != cb.connLeft ||
            ca.isExpressLane != cb.isExpressLane) {
          return false;
        }
      }
    }

    final Set<String> aEdges = a['activeEdges'];
    final Set<String> bEdges = b['activeEdges'];
    if (aEdges.length != bEdges.length) return false;
    for (final e in aEdges) {
      if (!bEdges.contains(e)) return false;
    }

    return true;
  }

  void executeUndoableAction(VoidCallback action) {
    if (gridManager == null) return;
    final oldSnapshot = gridManager!.takeUndoSnapshot();
    action();
    final newSnapshot = gridManager!.takeUndoSnapshot();
    if (!_areSnapshotsIdentical(oldSnapshot, newSnapshot)) {
      _undoStack.add(oldSnapshot);
      if (_undoStack.length > 1) {
        _undoStack.removeAt(0);
      }
      canUndoNotifier.value = true;
    }
  }

  void undo() {
    if (_undoStack.isEmpty || gridManager == null) return;
    final snapshot = _undoStack.removeLast();
    gridManager!.restoreUndoSnapshot(snapshot);
    _updateInventoryNotifiers();
    gridRenderer?.markDirty();
    _pathCache.clear();
    onStateChanged?.call();
    canUndoNotifier.value = false; // Cap at 1 step undo, so gray out immediately
  }

  void _updateMapSpecificEvents(double dt) {
    if (gridManager == null) return;
    final random = math.Random();

    if (activeEvent != null) {
      eventTimer += dt;
      if (eventTimer >= eventDuration) {
        // Event ended!
        activeEvent = null;
        activeEventTiles.clear();
        gridManager!.blockedTiles.clear();
        if (floodedRoads.isNotEmpty) {
          floodedRoads.clear();
          gridManager!.rebuildRoadGraph();
          _pathCache.clear();
        }
        nextEventCooldown = 35.0 + random.nextDouble() * 35.0; // 35-70 seconds
        gridRenderer?.markAllDirty();
      }
    } else {
      nextEventCooldown -= dt;
      if (nextEventCooldown <= 0) {
        if (selectedMapType == MapType.arctic) {
          activeEvent = 'blizzard';
          eventDuration = 15.0 + random.nextDouble() * 5.0;
          eventTimer = 0.0;
          gridRenderer?.markAllDirty();
        } else if (selectedMapType == MapType.savanna) {
          if (random.nextBool()) {
            activeEvent = 'dustStorm';
            eventDuration = 12.0 + random.nextDouble() * 6.0;
            eventTimer = 0.0;
            gridRenderer?.markAllDirty();
          } else {
            // Animal stampede
            final validRoads = <GridPosition>[];
            for (int y = 0; y < gridManager!.rows; y++) {
              for (int x = 0; x < gridManager!.cols; x++) {
                final cell = gridManager!.grid[y][x];
                if (cell.isRoad && !cell.isTunnel && !cell.isBridge && cell.owner == InfrastructureOwner.player) {
                  validRoads.add(GridPosition(x, y));
                }
              }
            }
            if (validRoads.isNotEmpty) {
              final pos = validRoads[random.nextInt(validRoads.length)];
              activeEvent = 'animalCrossing';
              activeEventPos = pos;
              activeEventTiles.clear();
              activeEventTiles.add(pos);
              gridManager!.blockedTiles.clear();
              gridManager!.blockedTiles.add(pos);
              eventDuration = 8.0;
              eventTimer = 0.0;
              _pathCache.clear(); // Recalculate routes to bypass stampede
              gridRenderer?.markAllDirty();
            } else {
              nextEventCooldown = 15.0; // Try again soon
            }
          }
        } else if (selectedMapType == MapType.delta) {
          if (random.nextBool()) {
            // Drawbridge open
            final validBridges = <GridPosition>[];
            for (int y = 0; y < gridManager!.rows; y++) {
              for (int x = 0; x < gridManager!.cols; x++) {
                final cell = gridManager!.grid[y][x];
                if (cell.isBridge && cell.owner == InfrastructureOwner.player) {
                  validBridges.add(GridPosition(x, y));
                }
              }
            }
            if (validBridges.isNotEmpty) {
              final pos = validBridges[random.nextInt(validBridges.length)];
              activeEvent = 'drawbridgeOpen';
              activeEventPos = pos;
              activeEventTiles.clear();
              activeEventTiles.add(pos);
              gridManager!.blockedTiles.clear();
              gridManager!.blockedTiles.add(pos);
              eventDuration = 8.0;
              eventTimer = 0.0;
              _pathCache.clear(); // Recalculate routes to bypass drawbridge
              gridRenderer?.markAllDirty();
            } else {
              nextEventCooldown = 15.0; // Try again soon
            }
          } else {
            // Flash Flood: Find player roads adjacent to water
            final choiceFloods = <GridPosition>[];
            for (int y = 0; y < gridManager!.rows; y++) {
              for (int x = 0; x < gridManager!.cols; x++) {
                final cell = gridManager!.grid[y][x];
                if (cell.isRoad && !cell.isTunnel && !cell.isBridge && cell.owner == InfrastructureOwner.player) {
                  // Check neighbors for water
                  bool adjacentToWater = false;
                  for (final dir in [[0, -1], [1, 0], [0, 1], [-1, 0]]) {
                    final nx = x + dir[0];
                    final ny = y + dir[1];
                    if (gridManager!.isValid(nx, ny) && gridManager!.grid[ny][nx].type == CellType.water) {
                      adjacentToWater = true;
                      break;
                    }
                  }
                  if (adjacentToWater) {
                    choiceFloods.add(GridPosition(x, y));
                  }
                }
              }
            }
            if (choiceFloods.isNotEmpty) {
              choiceFloods.shuffle(random);
              activeEvent = 'flashFlood';
              final chosen = choiceFloods.take(4).toList();
              floodedRoads.clear();
              floodedRoads.addAll(chosen);
              gridManager!.blockedTiles.clear();
              gridManager!.blockedTiles.addAll(chosen);
              eventDuration = 15.0;
              eventTimer = 0.0;
              gridManager!.rebuildRoadGraph();
              _pathCache.clear();
              gridRenderer?.markAllDirty();
            } else {
              nextEventCooldown = 15.0;
            }
          }
        }
      }
    }
  }
}
