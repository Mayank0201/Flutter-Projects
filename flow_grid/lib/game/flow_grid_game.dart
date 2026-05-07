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
import 'package:flame/sprite.dart';


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

  double _baseTargetZoom = 1.0;
  double _adaptiveZoomOffset = 0.0;
  double get _targetZoom => (_baseTargetZoom - _adaptiveZoomOffset).clamp(0.35, 1.0);

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
  final PerformanceLogger perfLogger = PerformanceLogger();
  
  SpriteSheet? carSpriteSheet;
  final CarPool carPool = CarPool();

  
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
    print("[BOOT] onLoad started");
    await super.onLoad();
    camera.viewfinder.anchor = Anchor.topLeft;
    
    // Load vehicle atlas
    try {
      final atlasImage = await images.load('vehicles.png');
      carSpriteSheet = SpriteSheet(
        image: atlasImage,
        srcSize: Vector2(32, 16),
      );
      print("[BOOT] assets loaded");
    } catch (e) {
      print("[BOOT] ERROR loading assets: $e");
    }
    
    overlays.add('mainMenu');
    paused = true;
    print("[BOOT] onLoad complete, added mainMenu");
  }


  void startGame({required bool resume, MapType mapType = MapType.zen, int slotIndex = 0}) async {
    currentSlotIndex = slotIndex;
    selectedMapType = mapType;
    
    // Reset core state
    score = 0;
    week = 1;
    totalDeliveries = 0;
    weekTimer = 0;
    _elapsedTime = 0;
    activeColorCount = 1;
    _adaptiveZoomOffset = 0.0;
    _baseTargetZoom = 1.0;
    _pathCache.clear();
    _cars.clear();
    children.whereType<CarComponent>().forEach((c) => c.removeFromParent());
    
    if (resume) {
      final save = await SaveManager.loadGame(slotIndex: slotIndex);
      if (save != null) {
        gridCols = save['gridCols'] ?? 16;
        gridRows = save['gridRows'] ?? 10;
        gridManager = GridManager(gridCols, gridRows, selectedMapType: MapType.values[save['mapType'] ?? 0], initTerrain: false);
        
        // Restore Grid
        final gridData = save['grid'] as List;
        for (int y = 0; y < gridRows; y++) {
          for (int x = 0; x < gridCols; x++) {
            final cellData = gridData[y][x] as Map<String, dynamic>;
            gridManager!.grid[y][x] = GridCell(
              type: CellType.values[cellData['type']],
              colorIndex: cellData['colorIndex'],
              isPendingDeletion: cellData['isPendingDeletion'] ?? false,
              isTunnelExtension: cellData['isTunnelExtension'] ?? false,
              hasTrafficLight: cellData['hasTrafficLight'] ?? false,
              speedMultiplier: (cellData['speedMultiplier'] as num).toDouble(),
              entrySide: cellData['entrySide'] != null ? Direction.values[cellData['entrySide']] : null,
              isInfrastructureInternal: cellData['isInfrastructureInternal'] ?? false,
              isConnectableEndpoint: cellData['isConnectableEndpoint'] ?? false,
              infrastructureAxis: cellData['infrastructureAxis'] != null ? InfrastructureAxis.values[cellData['infrastructureAxis']] : null,
              owner: cellData['owner'] != null ? InfrastructureOwner.values[cellData['owner']] : InfrastructureOwner.player,
            );
          }
        }

        // Restore Metadata
        week = save['week'] ?? 1;
        score = save['score'] ?? 0;
        totalDeliveries = save['totalDeliveries'] ?? 0;
        weekTimer = (save['weekTimer'] as num?)?.toDouble() ?? 0;
        _elapsedTime = (save['elapsedTime'] as num?)?.toDouble() ?? 0;
        activeColorCount = save['activeColorCount'] ?? 1;
        
        // Restore Inventories
        final inv = save['inventory'] as Map<String, dynamic>?;
        if (inv != null) {
          gridManager!.roads = inv['roads'] ?? 0;
          gridManager!.tunnels = inv['tunnels'] ?? 0;
          gridManager!.bridges = inv['bridges'] ?? 0;
          gridManager!.trafficLights = inv['trafficLights'] ?? 0;
          gridManager!.smartJunctions = inv['smartJunctions'] ?? 0;
          gridManager!.expressLanes = inv['expressLanes'] ?? 0;
        }

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
      gridManager!.roads = 25; // Starting roads
      
      // Initial Camera
      _syncCameraCenter(instant: true);
    }

    // Initialize/Reset Systems
    print("[WORLD_INIT] Initializing systems");
    districtPlanner = DistrictPlanner(gridManager: gridManager!);
    spawnController = SpawnController(
      gridManager: gridManager!,
      districtPlanner: districtPlanner,
    );
    print("[SPAWN_MANAGER_INIT] SpawnController created");
    gridRenderer = GridRenderer(gridManager: gridManager!, cellSize: cellSize);
    add(gridRenderer!);
    
    // Initialize Managers with valid references
    eventManager = EventManager(gridManager: gridManager!, districtPlanner: districtPlanner);
    transitManager = TransitManager();
    emergencyManager = EmergencyManager();
    economyManager = EconomyManager();
    progressionDirector = ProgressionDirector(spawnController!);

    // Add components to the game tree
    add(eventManager);
    add(transitManager);
    add(emergencyManager);
    add(economyManager);
    print("[WORLD_INIT] Components added to game tree");

    // Connect callbacks
    gridManager!.onTopologyChanged = () => _pathCache.clear();

    phase = GamePhase.playing;
    paused = false;
    _updateInventoryNotifiers();
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

  double _debugLogTimer = 0;

  @override
  void update(double dt) {
    super.update(dt);
    
    // Tier 1: Real-time (Camera, Animations)
    _updateCameraSmoothing(dt);
    
    _debugLogTimer += dt;
    if (_debugLogTimer > 5.0) {
      print("[UPDATE_LOOP_ACTIVE] phase: $phase, paused: $paused, week: $week");
      _debugLogTimer = 0;
    }
    
    if (phase != GamePhase.playing || paused) return;
    
    final safeDt = dt.clamp(0.0, 0.05);
    final scaledDt = safeDt * timeScale;
    _elapsedTime += scaledDt;
    weekTimer += scaledDt;

    // Tier 2: 15Hz - Physics & Traffic AI
    _logicTickTimer += safeDt;
    if (_logicTickTimer >= 1 / 15) {
      _rebuildSpatialGrid();
      trafficClock.update(scaledDt);
      _updateTrafficSimulation(scaledDt);
      gridManager?.updateTrafficSignals(scaledDt, carGrid, gridWidth);
      _logicTickTimer = 0;
    }

    // Tier 3: 5Hz - Simulation & Pathfinding
    _simTickTimer += safeDt;
    if (_simTickTimer >= 1 / 5) {
      gridManager?.updateCongestion(cars);
      gridManager?.updateSatisfaction(_simTickTimer);
      _simTickTimer = 0;
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
      spawnController?.update(1.0);
      _checkWeekTransition();
      _spawnTickTimer = 0;
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
      camera.viewfinder.zoom += delta.clamp(-0.02, 0.02);
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


  void _syncCameraCenter({bool instant = false, double dt = 0.016}) {
    final screenW = size.x - hudPanelWidth;
    final screenH = size.y;
    final zoom = camera.viewfinder.zoom;
    final target = Vector2(-(screenW / zoom - screenW) / 2, -(screenH / zoom - screenH) / 2);
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
      _updateTargetZoom();
      MapGeneratorFactory.getGenerator(selectedMapType).generateExpansion(gridManager!, week);
      _triggerWeeklyUpgrade();
    }
  }

  void _updateTargetZoom() {
    double expansion = week <= 3 ? 0.08 : (week <= 8 ? 0.05 : 0.02);
    _adaptiveZoomOffset += expansion;
    _baseTargetZoom = max(0.65, 1.0 - (week * 0.025));
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
    final zoom = camera.viewfinder.zoom;
    final pos = camera.viewfinder.position;
    spawnController!.minSpawnX = max(0, ((pos.x - boardOffsetX) / cellSize).ceil() + 2);
    spawnController!.maxSpawnX = min(gridManager!.cols - 1, ((pos.x + (size.x - hudPanelWidth) / zoom - boardOffsetX) / cellSize).floor() - 2);
    spawnController!.minSpawnY = max(0, ((pos.y - boardOffsetY) / cellSize).ceil() + 2);
    spawnController!.maxSpawnY = min(gridManager!.rows - 1, ((pos.y + size.y / zoom - boardOffsetY) / cellSize).floor() - 2);
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
    } else if (!_isDragging && _panStartPixel != null) {
      // Single click action
      final worldPos = camera.viewfinder.globalToLocal(_panStartPixel!);
      final x = ((worldPos.x - boardOffsetX) / cellSize).floor();
      final y = ((worldPos.y - boardOffsetY) / cellSize).floor();
      _handleSingleClick(GridPosition(x, y));
    }
    _cleanupInput();
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
  }

  void _handleBuild(GridPosition pos) {
    if (gridManager == null) return;
    
    switch (activeTool) {
      case BuildTool.road:
        gridManager!.placeRoad(pos.x, pos.y, from: _lastPlacedPos);
        _lastPlacedPos = pos;
        break;
      case BuildTool.tunnel:
        gridManager!.placeTunnel(pos.x, pos.y, from: _lastPlacedPos, consumeRoad: true);
        _lastPlacedPos = pos;
        break;
      case BuildTool.bridge:
        gridManager!.placeBridge(pos.x, pos.y, from: _lastPlacedPos, consumeRoad: true);
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
