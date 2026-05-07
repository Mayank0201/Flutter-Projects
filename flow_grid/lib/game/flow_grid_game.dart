import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../models/game_constants.dart';
import '../models/grid_cell.dart';
import 'grid_manager.dart';
import 'pathfinder.dart';
import 'spawn_controller.dart';
import 'district_planner.dart';
import 'progression_director.dart';
import 'components/grid_renderer.dart';
import 'components/car_component.dart';
import 'components/express_lane_component.dart';
import 'save_manager.dart';

enum GamePhase { menu, playing, paused, gameOver, weeklyUpgrade }

enum BuildTool { road, tunnel, trafficLight, smartJunction, expressLane, erase }

class FlowGridGame extends FlameGame with PanDetector, MouseMovementDetector {
  GridManager? gridManager;
  GridRenderer? gridRenderer;

  GamePhase phase = GamePhase.menu;
  BuildTool activeTool = BuildTool.road;
  bool showDebugOverlay = false; // Enabled for diagnostics

  int score = 0;
  int week = 1;
  int totalDeliveries = 0;
  double weekTimer = 0;
  double spawnTimer = 0;
  final Map<String, List<GridPosition>> _pathCache = {};

  // Spatial partitioning for car collisions (FPS Optimization)
  final Map<int, List<CarComponent>> carGrid = {};
  int gridWidth = 0;

  // Track active cars per house (Strategic Limit: 2 cars per house)
  // Uses string keys ("x,y") for JSON serialization compatibility
  final Map<String, int> houseCarCounts = {};

  int activeColorCount = 1;
  double timeScale = 1.0;

  // Spawn Controller — single authority for all building spawns
  late SpawnController? spawnController;
  late ProgressionDirector progressionDirector;
  late DistrictPlanner districtPlanner;

  // Layout — landscape: grid left, HUD panel right
  double cellSize = 40;
  double boardOffsetX = 0;
  double boardOffsetY = 0;
  int gridCols = 16;
  int gridRows = 10;
  double hudPanelWidth = 120; // right-side panel
  int _zoomLevel = 0;

  double _baseTargetZoom = 1.0;
  double _adaptiveZoomOffset = 0.0;
  double get _targetZoom => (_baseTargetZoom - _adaptiveZoomOffset).clamp(0.35, 1.0);

  double get difficulty => 1.0 + ((week - 1) * 0.12);
  double get weekProgress => weekTimer / GameConstants.weekDuration;

  final List<CarComponent> _cars = [];
  final List<ExpressLaneComponent> _expressLaneComponents = [];
  final List<GridPosition> _placedThisDrag = [];
  final List<GridPosition> _dragPath = [];
  List<GridPosition> previewPath = [];
  GridPosition? expressLanePendingStart;
  GridPosition? expressLaneDraggingEnd;

  GridPosition? _lastPlacedPos;
  GridPosition? lastHoverPos;
  Vector2 _lastMousePos = Vector2.zero(); // [NEW] Track world-space cursor
  Vector2 get lastMousePosWorld => _lastMousePos;
  bool _isDragging = false;
  Vector2? _panStartPixel;
  
  double _elapsedTime = 0;
  double get elapsedTime => _elapsedTime;
  final Random _random = Random();

  List<String> weeklyOptions = [];
  List<CarComponent> get cars => _cars;

  VoidCallback? onStateChanged;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder.anchor = Anchor.topLeft;
    camera.viewfinder.position = Vector2.zero();
    overlays.add('mainMenu');
    paused = true;
  }

  @override
  Color backgroundColor() => GameConstants.backgroundColor;

  Future<void> startGame({bool resume = false}) async {
    overlays.remove('mainMenu');
    overlays.remove('gameOver');
    overlays.remove('weeklyUpgrade');
    overlays.remove('hud');
    paused = false;

    // Clear old visual components
    for (final car in _cars) {
      car.removeFromParent();
    }
    _cars.clear();
    for (final mw in _expressLaneComponents) {
      mw.removeFromParent();
    }
    _expressLaneComponents.clear();
    // gridManager!.expressLanes = 1; // MOVED DOWN TO AFTER INITIALIZATION

    if (gridRenderer != null && gridRenderer!.parent != null) {
      gridRenderer!.removeFromParent();
    }

    // 1. Basic State Reset
    weekTimer = 0;
    spawnTimer = 0;
    activeColorCount = 1; // Start with 1 color, 2nd introduced mid-week
    timeScale = 1.0;
    activeTool = BuildTool.road;
    _lastPlacedPos = null;
    _zoomLevel = 0;
    _baseTargetZoom = 1.0;
    _adaptiveZoomOffset = 0.0;
    camera.viewfinder.zoom = 1.0;

    // 2. Load Dimensions (if resuming)
    Map<String, dynamic>? saveData;
    if (resume) {
      saveData = await SaveManager.loadGame();
      if (saveData != null) {
        gridCols = saveData['gridCols'] as int? ?? 16;
        gridRows = saveData['gridRows'] as int? ?? 10;
      }
    } else {
      await SaveManager.clearSave();
      // Base visible size
      gridCols = 36; // Use expanded size
      gridRows = 20; // Use expanded size
      
    }

    // 3. Layout & Component Initialization
    _updateTargetZoom(); // Ensure target zoom is synchronized with current week (Issue 1)
    if (!resume) {
      camera.viewfinder.zoom = _targetZoom;
    }
    _calculateGridSize();
    gridManager = GridManager(gridCols, gridRows);
    gridManager!.roads = GameConstants.startingRoadBudget;
    gridManager!.tunnels = GameConstants.startingTunnels;
    gridManager!.trafficLights = GameConstants.startingTrafficLights;
    gridManager!.smartJunctions = GameConstants.startingSmartJunctions;
    gridManager!.expressLanes = GameConstants.startingExpressLanes;

    gridRenderer = GridRenderer(
      gridManager: gridManager!,
      cellSize: cellSize,
      offsetX: boardOffsetX,
      offsetY: boardOffsetY,
    );
    world.add(gridRenderer!);

    // 4. Fill State
    if (resume && saveData != null) {
      gridManager!.loadFromSave(saveData);
      score = saveData['score'] ?? 0;
      week = saveData['week'] ?? 1;
      totalDeliveries = saveData['totalDeliveries'] ?? 0;
      weekTimer = (saveData['weekTimer'] as num?)?.toDouble() ?? 0;
      spawnTimer = (saveData['spawnTimer'] as num?)?.toDouble() ?? 0;
      activeColorCount = saveData['activeColorCount'] as int? ?? 1;
      _zoomLevel = saveData['zoomLevel'] as int? ?? 0;
      _elapsedTime = (saveData['elapsedTime'] as num?)?.toDouble() ?? 0;

      // Restore zoom
      if (_zoomLevel > 0) {
        final newZoom = (1.0 - _zoomLevel * 0.07).clamp(0.35, 1.0);
        camera.viewfinder.zoom = newZoom;
        final screenW = size.x - hudPanelWidth;
        final screenH = size.y;
        final panX = -(screenW / newZoom - screenW) / 2;
        final panY = -(screenH / newZoom - screenH) / 2;
        camera.viewfinder.position = Vector2(panX, panY);

        _syncSpawnBounds();
      }

      // Restore house car counts
      houseCarCounts.clear();
      if (saveData['houseCarCounts'] != null) {
        final hcc = saveData['houseCarCounts'] as Map<String, dynamic>;
        hcc.forEach((k, v) => houseCarCounts[k] = v as int);
      }

      // Re-add express lanes
      for (final mw in gridManager!.placedExpressLanes) {
        final mwComp = ExpressLaneComponent(
          start: mw[0],
          end: mw[1],
          cellSize: cellSize,
          offsetX: boardOffsetX,
          offsetY: boardOffsetY,
        );
        _expressLaneComponents.add(mwComp);
        world.add(mwComp);
      }

      // Restore active cars
      if (saveData['cars'] != null) {
        final carsData = saveData['cars'] as List<dynamic>;
        for (final carData in carsData) {
          final cd = carData as Map<String, dynamic>;
          final pathData = cd['path'] as List<dynamic>;
          final carPath = pathData.map((p) {
            final pm = p as Map<String, dynamic>;
            return GridPosition(pm['x'] as int, pm['y'] as int);
          }).toList();

          if (carPath.length < 2) continue;

          final spawnPos = cd['spawnHousePos'] as Map<String, dynamic>;
          final destPos = cd['targetDest'] as Map<String, dynamic>;

          final car = CarComponent(
            colorIndex: cd['colorIndex'] as int,
            path: carPath,
            cellSize: cellSize,
            spawnHousePos: GridPosition(
              spawnPos['x'] as int,
              spawnPos['y'] as int,
            ),
            targetDest: GridPosition(destPos['x'] as int, destPos['y'] as int),
            offsetX: boardOffsetX,
            offsetY: boardOffsetY,
            initialPathIndex: cd['currentPathIndex'] as int? ?? 0,
            initialProgress: (cd['progress'] as num?)?.toDouble() ?? 0.0,
            initialReturning: cd['isReturning'] as bool? ?? false,
          );
          _cars.add(car);
          world.add(car);
        }
      }
    } else {
      gridManager!.reset();
      score = 0;
      week = 1;
      totalDeliveries = 0;
      _elapsedTime = 0;
      _adaptiveZoomOffset = 0.0;
      
      gridManager!.roads = GameConstants.startingRoadBudget;
      gridManager!.tunnels = GameConstants.startingTunnels;
      gridManager!.trafficLights = GameConstants.startingTrafficLights;
      gridManager!.expressLanes = GameConstants.startingExpressLanes;
    }

    // 5. Initialize District Planner & Spawn Controller
    districtPlanner = DistrictPlanner(gridManager: gridManager!);
    spawnController = SpawnController(gridManager: gridManager!, districtPlanner: districtPlanner);
    spawnController!.onSpawnComplete = () {
      gridRenderer!.markDirty();
      onStateChanged?.call();
    };
    spawnController!.onAdaptiveExpansionRequired = () {
      _adaptiveZoomOffset += 0.015; // Incremental expansion (~1.5 tiles total width)
      // print('[ADAPTIVE] Expansion triggered. New offset: $_adaptiveZoomOffset');
    };
    _syncSpawnBounds();
    spawnController!.activeColorCount = activeColorCount;
    spawnController!.initializeScoring(); // Initialize the new scoring service
    progressionDirector = ProgressionDirector(spawnController!);

    // 6. Initial spawn for new game
    if (!resume || saveData == null) {
      progressionDirector.reset(); // Fresh state for new game
      _updateTargetZoom(); // Set initial zoom for Week 1
      spawnController!.spawnInitialPair(0);
    }

    phase = GamePhase.playing;
    overlays.add('hud');
    onStateChanged?.call();
  }

  void saveGame() {
    if (gridManager != null) {
      SaveManager.saveGame(
        gridManager!,
        week,
        score,
        totalDeliveries,
        weekTimer: weekTimer,
        spawnTimer: 0,
        activeColorCount: activeColorCount,
        zoomLevel: _zoomLevel,
        elapsedTime: _elapsedTime,
        houseCarCounts: houseCarCounts,
        cars: _cars,
      );
    }
  }

  void _calculateGridSize() {
    // In landscape: grid fills width minus the right HUD panel
    final sw = size.x;
    final sh = size.y;
    hudPanelWidth = (sw * 0.18).clamp(90.0, 150.0);
    final availW = sw - hudPanelWidth;
    final availH = sh;

    final visibleCols = 20; // [FIX] Restored larger gameplay scale (Issue 1)
    cellSize = availW / visibleCols;
    final visibleRows = (availH / cellSize).floor();

    // Pad the grid significantly to allow zoom-out expansion
    final padCols = 40; // [EXPANDED] was 25
    final padRows = 20; // [EXPANDED] was 15

    gridCols = visibleCols + padCols * 2;
    gridRows = visibleRows + padRows * 2;

    boardOffsetX = -padCols * cellSize;
    boardOffsetY = -padRows * cellSize + (availH - visibleRows * cellSize) / 2;

    // Sync to renderer if it exists (Issue: Quantization Sync)
    if (gridRenderer != null) {
      gridRenderer!.cellSize = cellSize;
      gridRenderer!.offsetX = boardOffsetX;
      gridRenderer!.offsetY = boardOffsetY;
      gridRenderer!.markDirty();
    }

    camera.viewfinder.anchor = Anchor.topLeft;
    _syncCameraCenter(); // [FIX] Centralized centering logic (Issue 1)
  }

  /// Ensures camera is correctly centered based on current zoom (Issue 1)
  void _syncCameraCenter() {
    final screenW = size.x - hudPanelWidth;
    final screenH = size.y;
    final zoom = camera.viewfinder.zoom;
    
    final panX = -(screenW / zoom - screenW) / 2;
    final panY = -(screenH / zoom - screenH) / 2;
    camera.viewfinder.position = Vector2(panX, panY);
    
    if (showDebugOverlay) {
      // print('[CAMERA] Fit Executed: zoom=$zoom pos=${camera.viewfinder.position}');
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _calculateGridSize(); // Re-center and re-quantize on window change
  }

  void _updateTargetZoom() {
    // [NEW] Endless Expansion System (Part 3)
    // Early: fast expansion, Mid: moderate, Late: slower but infinite (+2 cols)
    double expansion;
    if (week <= 3) {
      expansion = 0.08; // Roughly 6 tiles total width expansion
    } else if (week <= 8) {
      expansion = 0.05; // 4 tiles
    } else if (week <= 15) {
      expansion = 0.03; // 2-3 tiles
    } else {
      expansion = 0.02; // Slower infinite expansion
    }
    
    _adaptiveZoomOffset += expansion;
    
    // Stabilize zoom level near 0.65 for readability, but keep expanding bounds
    _baseTargetZoom = max(0.65, 1.0 - (week * 0.025)); 
  }

  /// Sync spawn bounds from current camera state to SpawnController
  void _syncSpawnBounds() {
    if (spawnController == null || gridManager == null) return;

    final screenW = size.x - hudPanelWidth;
    final screenH = size.y;
    final zoom = camera.viewfinder.zoom;
    final panX = camera.viewfinder.position.x;
    final panY = camera.viewfinder.position.y;

    // RULE 2: Safe Border Margins (Non-spawnable outer margin)
    // [EXPANDED] Reduced margins from 5/4 to 2/2 to utilize more screen space
    const marginX = 2;
    const marginY = 2;

    spawnController!.minSpawnX = max(0, ((panX - boardOffsetX) / cellSize).ceil() + marginX);
    spawnController!.maxSpawnX = min(
      gridManager!.cols - 1,
      ((panX + screenW / zoom - boardOffsetX) / cellSize).floor() - marginX,
    );
    spawnController!.minSpawnY = max(0, ((panY - boardOffsetY) / cellSize).ceil() + marginY);
    spawnController!.maxSpawnY = min(
      gridManager!.rows - 1,
      ((panY + screenH / zoom - boardOffsetY) / cellSize).floor() - marginY,
    );

    // [NEW] Dynamic Mountain Centering (Issue 2)
    final centerX = (spawnController!.minSpawnX + spawnController!.maxSpawnX) / 2.0;
    final newMountainX = centerX.round();
    if (gridManager!.mountainX != newMountainX) {
      gridManager!.rebuildMountain(newMountainX);
      gridRenderer?.markDirty();
    }
  }

  void _rebuildSpatialGrid() {
    carGrid.clear();
    gridWidth = gridManager?.cols ?? 100;
    for (final car in _cars) {
      if (car.arrived) continue;
      final pos = car.path[car.currentPathIndex.clamp(0, car.path.length - 1)];
      final key = pos.x + pos.y * gridWidth;
      carGrid.putIfAbsent(key, () => []).add(car);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (phase != GamePhase.playing || paused) return;

    final safeDt = dt.clamp(0.0, 0.05) * timeScale;

    _rebuildSpatialGrid();
    gridManager!.updateTrafficSignals(safeDt);

    _elapsedTime += safeDt;
    
    weekTimer += safeDt;
    
    // Update macro progression (Color Unlocks & Escalation)
    progressionDirector.update(week, weekTimer / GameConstants.weekDuration, safeDt);

    if (weekTimer >= GameConstants.weekDuration) {
      weekTimer = 0;
      week++;
      _updateTargetZoom(); // [NEW] Expand camera on new week
      
      // [NEW] Age all existing destinations
      for (final dest in gridManager!.destinations) {
        final key = '${dest.x},${dest.y}';
        gridManager!.destinationAges[key] = (gridManager!.destinationAges[key] ?? 0) + 1;
      }

      _triggerWeeklyUpgrade();
      return;
    }

    // ============================================================
    // RULE 1: Global Game Clock
    // ============================================================
    // (difficulty already computed as getter: 1 + elapsedTime / 90)



    // Smooth Camera Zoom and dynamic bounds expansion
    if ((camera.viewfinder.zoom - _targetZoom).abs() > 0.001) {
      // Faster interpolation for reveal feeling
      camera.viewfinder.zoom +=
          (_targetZoom - camera.viewfinder.zoom) * safeDt * 2.0;

      _syncCameraCenter(); // Use centralized logic
      _syncSpawnBounds();
    }

    // ============================================================
    // SPAWN CONTROLLER (single authority for all building spawns)
    // ============================================================
    spawnController!.update(safeDt);

    // ============================================================
    // DEMAND GENERATION & OVERFLOW RECOVERY
    // ============================================================
    final baseInterval = GameConstants.carSpawnInterval / difficulty;

    for (final dest in List.of(gridManager!.destinations)) {
      final key = '${dest.x},${dest.y}';
      final age = gridManager!.destinationAges[key] ?? 0;
      final isMature = age >= GameConstants.maturityThresholdWeeks;
      
      final currentDemand = gridManager!.getDemand(dest);
      final maxDemand = isMature ? GameConstants.matureMaxDemand : GameConstants.maxDemand;

      // 1. Manage Overflow Level (Continuous Meter)
      final currentLevel = gridManager!.overflowLevels[key] ?? 0.0;
      final buildupRate = isMature ? GameConstants.matureOverflowBuildupMultiplier : 1.0;

      if (currentDemand >= maxDemand) {
        // Accumulate tension (Faster for mature hubs)
        gridManager!.overflowLevels[key] = (currentLevel + (safeDt * buildupRate) / GameConstants.criticalDuration).clamp(0.0, 1.0);
        
        // [NEW] Bonus House Trigger (Part 2)
        // If demand is at max (6+) for a sustained period, trigger a bonus source house
        final highDemandTime = (gridManager!.highDemandTimers[key] ?? 0.0) + safeDt;
        gridManager!.highDemandTimers[key] = highDemandTime;
        
        if (highDemandTime >= GameConstants.highDemandHouseTriggerDuration && !(gridManager!.spawnedBonusHouse[key] ?? false)) {
          final colorIdx = gridManager!.getCell(dest.x, dest.y).colorIndex;
          if (colorIdx != null) {
            final success = spawnController!.spawnExtraHouse(colorIdx);
            if (success) {
               gridManager!.spawnedBonusHouse[key] = true;
               print('[SCALING] High demand sustained at ${dest.key}. Spawned bonus house for color $colorIdx.');
            }
          }
        }

        if (gridManager!.overflowLevels[key]! >= 1.0) {
          _gameOver();
          return;
        }
      } else {
        // Slow natural decay when under capacity
        gridManager!.overflowLevels[key] = (currentLevel - safeDt / GameConstants.overflowRecoveryDuration).clamp(0.0, 1.0);
        // Also decay high demand timer so it needs to be sustained again
        gridManager!.highDemandTimers[key] = max(0.0, (gridManager!.highDemandTimers[key] ?? 0.0) - safeDt);
      }

      // 2. Generate Demand (Staggered Interval)
      // Stacking penalty: the more pips, the slower the next one appears
      final maturitySpeedBonus = isMature ? GameConstants.matureRequestSpeedMultiplier : 1.0;
      
      // [NEW] Endless Scaling: Increase speed based on age (Part 1)
      double ageSpeedBonus = 1.0;
      if (age > GameConstants.maturityThresholdWeeks) {
        ageSpeedBonus += (age - GameConstants.maturityThresholdWeeks) * GameConstants.demandAgeScalingRate;
      }
      
      final rawInterval = (baseInterval / (maturitySpeedBonus * ageSpeedBonus)) * (1.0 + 0.4 * currentDemand);
      final staggeredInterval = max(GameConstants.minDemandInterval, rawInterval);
      
      if (currentDemand < maxDemand) {
        final timer = gridManager!.getDemandTimer(dest) + safeDt;
        gridManager!.setDemandTimer(dest, timer);
        if (timer >= staggeredInterval) {
          gridManager!.setDemandTimer(dest, 0);
          gridManager!.setDemand(dest, currentDemand + 1);
          gridRenderer!.markDirty();
        }
      }
    }

    // Delayed infrastructure deletion
    final activeCarTiles = <GridPosition>{};
    for (final car in _cars) {
      activeCarTiles.addAll(car.occupiedTiles);
    }

    final refunds = gridManager!.cleanupPendingDeletions(activeCarTiles);
    if (refunds.isNotEmpty) {
      gridManager!.roads += refunds['road'] ?? 0;
      gridManager!.tunnels += refunds['tunnel'] ?? 0;
      gridManager!.trafficLights += refunds['trafficLight'] ?? 0;
      gridRenderer!.markDirty();
    }

    _expressLaneComponents.removeWhere((mw) {
      if (mw.isPendingDeletion) {
        if (!activeCarTiles.contains(mw.start) &&
            !activeCarTiles.contains(mw.end)) {
          mw.removeFromParent();
          return true;
        }
      }
      return false;
    });

    for (final house in List.of(gridManager!.houses)) {
      final timer = gridManager!.getHouseCarTimer(house) + safeDt;
      // Cap at carSpawnInterval so it stays ready
      gridManager!.setHouseCarTimer(
        house,
        min(timer, GameConstants.carSpawnInterval),
      );
    }


    // Smart Spawning: dispatch cars for unmet demand
    for (final dest in List.of(gridManager!.destinations)) {
      final demand = gridManager!.getDemand(dest);
      final claimedDemand = gridManager!.getClaimedDemand(dest);
      int unmetDemand = demand - claimedDemand;

      if (unmetDemand > 0) {
        final destCell = gridManager!.getCell(dest.x, dest.y);
        final colorIdx = destCell.colorIndex;
        if (colorIdx == null) continue;

        // Find all houses of same color that are ready AND have < 2 active cars
        final readyHouses = gridManager!.houses.where((h) {
          if (gridManager!.getCell(h.x, h.y).colorIndex != colorIdx) {
            return false;
          }
          final houseKey = '${h.x},${h.y}';
          final activeCount = houseCarCounts[houseKey] ?? 0;
          if (activeCount >= 2) {
            return false;
          }
          return gridManager!.getHouseCarTimer(h) >=
              GameConstants.carSpawnInterval;
        }).toList();

        // Sort by manhattan distance to destination (cheapest first, avoid expensive pathfinding)
        readyHouses.sort(
          (a, b) =>
              a.manhattanDistance(dest).compareTo(b.manhattanDistance(dest)),
        );

        GridPosition? bestHouse;
        List<GridPosition>? bestPath;

        for (final house in readyHouses) {
          final cacheKey = '${house.x},${house.y}->${dest.x},${dest.y}';
          List<GridPosition>? path = _pathCache[cacheKey];

          if (path == null) {
            path = Pathfinder.findPath(gridManager!, house, dest);
            if (path != null) _pathCache[cacheKey] = path;
          }

          if (path != null && path.length >= 2) {
            bestHouse = house;
            bestPath = path;
            break;
          }
        }

        if (bestHouse != null && bestPath != null) {
          // SPAWN SAFETY: Check if driveway is physically blocked by another car
          final driveway =
              gridManager!.buildingDriveways['${bestHouse.x},${bestHouse.y}'];
          if (driveway != null) {
            final dvX = boardOffsetX + driveway.x * cellSize + cellSize / 2;
            final dvY = boardOffsetY + driveway.y * cellSize + cellSize / 2;
            final dvPos = Vector2(dvX, dvY);
            bool blocked = false;
            for (final car in _cars) {
              if (car.position.distanceTo(dvPos) < cellSize * 0.4) {
                blocked = true;
                break;
              }
            }
            if (blocked) continue; // Try another house or wait for next frame
          }

          gridManager!.setClaimedDemand(dest, claimedDemand + 1);
          gridManager!.setHouseCarTimer(bestHouse, 0);

          final car = CarComponent(
            colorIndex: colorIdx,
            path: bestPath,
            cellSize: cellSize,
            spawnHousePos: bestHouse,
            targetDest: dest,
            offsetX: boardOffsetX,
            offsetY: boardOffsetY,
          );
          _cars.add(car);
          world.add(car);
          final houseKey = '${bestHouse.x},${bestHouse.y}';
          houseCarCounts[houseKey] = (houseCarCounts[houseKey] ?? 0) + 1;
        }
      }
    }

    final arrived = _cars.where((c) => c.arrived).toList();
    for (final car in arrived) {
      _onCarArrived(car);
    }

    score += (safeDt * 5).floor();
    onStateChanged?.call();
  }


  void _onCarArrived(CarComponent car) {
    if (car.isReturning) {
      // Decrement active car count for the house
      final homePos = car.spawnHousePos;
      final homeKey = '${homePos.x},${homePos.y}';
      if (houseCarCounts.containsKey(homeKey)) {
        houseCarCounts[homeKey] = (houseCarCounts[homeKey]! - 1).clamp(0, 2);
      }

      _cars.remove(car);
      car.removeFromParent();
      onStateChanged?.call();
      return;
    }

    final destPos = car.targetDest;
    if (gridManager!.isValid(destPos.x, destPos.y)) {
      final destCell = gridManager!.getCell(destPos.x, destPos.y);
      if (destCell.isDestination) {
        gridManager!.setDemand(
          destPos,
          max(0, gridManager!.getDemand(destPos) - 1),
        );
        gridManager!.setClaimedDemand(
          destPos,
          max(0, gridManager!.getClaimedDemand(destPos) - 1),
        );

        // Gradual Overflow Recovery
        final key = '${destPos.x},${destPos.y}';
        final level = gridManager!.overflowLevels[key] ?? 0.0;
        gridManager!.overflowLevels[key] = (level - GameConstants.overflowDeliveryRecovery).clamp(0.0, 1.0);

        gridRenderer!.markDirty();
        score += 100;
        totalDeliveries++;
      }
    }

    // Try to return home
    final returnPath = Pathfinder.findPath(
      gridManager!,
      car.path.last,
      car.spawnHousePos,
    );
    if (returnPath != null && returnPath.length >= 2) {
      car.startReturnTrip(returnPath);
    } else {
      // Path is broken, disappear
      _cars.remove(car);
      car.removeFromParent();
    }

    onStateChanged?.call();
  }

  void _triggerWeeklyUpgrade() {
    // [FIX] Double increment: week++ is already called in update()
    // week++; 

    // Zoom out organically per week is now handled in _updateTargetZoom
    // and combined with adaptive expansion in the _targetZoom getter.
    // _targetZoom = (1.0 - ((week - 1) * 0.05)).clamp(0.25, 1.0);

    // Bounds are expanded continuously inside update() based on the targetZoom interpolation

    final pool = [
      'tunnels',
      'trafficLights',
      'smartJunction',
      'expressLane',
      'doubleRoads',
    ];
    pool.shuffle(_random);
    weeklyOptions = pool.take(2).toList();

    phase = GamePhase.weeklyUpgrade;
    overlays.add('weeklyUpgrade');
    paused = true;
    onStateChanged?.call();
  }

  // NOTE: _executeWeeklySpawn and _executeWeeklyUpgrade are NO LONGER USED.
  // All house spawning → RULE 2 (time-based) in update()
  // All destination spawning → RULE 3 (age-based) in update()
  // All color unlocking → RULE 3 (time schedule) in update()

  void applyUpgrade(String upgrade) {
    if (upgrade == 'tunnels') {
      gridManager!.roads += 20;
      gridManager!.tunnels += 1;
    } else if (upgrade == 'trafficLights') {
      gridManager!.roads += 20;
      gridManager!.trafficLights += 2;
    } else if (upgrade == 'smartJunction') {
      gridManager!.roads += 20;
      gridManager!.smartJunctions += 1;
    } else if (upgrade == 'expressLane') {
      gridManager!.roads += 10;
      gridManager!.expressLanes += 1;
    } else if (upgrade == 'doubleRoads') {
      gridManager!.roads += 30;
    } else {
      gridManager!.roads += 20;
    } // fallback

    phase = GamePhase.playing;
    overlays.remove('weeklyUpgrade');
    paused = false;
    onStateChanged?.call();
  }

  void _gameOver() {
    phase = GamePhase.gameOver;
    overlays.remove('hud');
    overlays.add('gameOver');
    paused = true;
    onStateChanged?.call();
  }

  GridPosition? _toGrid(Vector2 screenPos) {
    if (gridManager == null) return null;

    // [FIX] Correctly convert screen to world coordinates (Issue: Drag Audit)
    final worldPos = camera.viewfinder.globalToLocal(screenPos);

    // [FIX] Quantization Sync (Issue: Sticky Grid Coordinates)
    // Reduce snapping sensitivity during an active drag to prevent the cursor
    // from getting "stuck" on building entries or road endpoints.
    final snapRadius = _isDragging ? cellSize * 0.4 : cellSize * 1.1;

    if (activeTool == BuildTool.road || activeTool == BuildTool.tunnel) {
      // Priority 1: Driveway entry points (Rule 3A)
      for (final buildingPos in gridManager!.buildings) {
        final entrySide = gridManager!.getCell(buildingPos.x, buildingPos.y).entrySide;
        if (entrySide != null) {
          final entryPos = buildingPos.getNeighbor(entrySide);
          final entryWorldX = boardOffsetX + entryPos.x * cellSize + cellSize / 2;
          final entryWorldY = boardOffsetY + entryPos.y * cellSize + cellSize / 2;
          
          if (worldPos.distanceTo(Vector2(entryWorldX, entryWorldY)) < snapRadius) {
            return entryPos;
          }
        }
      }

      // Priority 2: Existing road endpoints (Rule 3A)
      for (final pos in gridManager!.infrastructure) {
        final cell = gridManager!.getCell(pos.x, pos.y);
        if (!cell.isRoad) continue;

        int connCount = 0;
        if (cell.connUp) connCount++;
        if (cell.connDown) connCount++;
        if (cell.connLeft) connCount++;
        if (cell.connRight) connCount++;

        if (connCount <= 1) {
          final worldX = boardOffsetX + pos.x * cellSize + cellSize / 2;
          final worldY = boardOffsetY + pos.y * cellSize + cellSize / 2;
          if (worldPos.distanceTo(Vector2(worldX, worldY)) < snapRadius) {
            return pos;
          }
        }
      }
    }

    final gx = ((worldPos.x - boardOffsetX) / cellSize).floor();
    final gy = ((worldPos.y - boardOffsetY) / cellSize).floor();

    // Clamp to valid range (Rule 3D: Out-of-bounds tolerance)
    final cx = gx.clamp(0, gridManager!.cols - 1);
    final cy = gy.clamp(0, gridManager!.rows - 1);

    // Allow a 2-tile margin outside the board for easier interaction near edges
    if ((gx - cx).abs() > 2 || (gy - cy).abs() > 2) return null;

    return GridPosition(cx, cy);
  }

  /// Interpolates grid positions between two points to ensure continuous dragging (Issue: Road Dragging)
  List<GridPosition> _getGridLine(GridPosition start, GridPosition end) {
    List<GridPosition> line = [];
    int x0 = start.x;
    int y0 = start.y;
    int x1 = end.x;
    int y1 = end.y;

    int dx = (x1 - x0).abs();
    int dy = (y1 - y0).abs();
    int sx = x0 < x1 ? 1 : -1;
    int sy = y0 < y1 ? 1 : -1;
    int err = dx - dy;

    while (true) {
      line.add(GridPosition(x0, y0));
      if (x0 == x1 && y0 == y1) break;
      int e2 = 2 * err;
      if (e2 > -dy) {
        err -= dy;
        x0 += sx;
      }
      if (e2 < dx) {
        err += dx;
        y0 += sy;
      }
    }
    return line;
  }


  @override
  void onPanStart(DragStartInfo info) {
    if (phase != GamePhase.playing) return;
    _placedThisDrag.clear();
    _lastPlacedPos = null;
    _dragPath.clear();
    _panStartPixel = info.eventPosition.global;
    _isDragging = false;

    final pos = _toGrid(_panStartPixel!);
    if (pos != null) {
      _dragPath.add(pos);
      lastHoverPos = pos;

      // If expressLane, don't place node 1 until we know if it's a tap or drag
      if (activeTool != BuildTool.expressLane) {
        _handleBuild(pos);
      }
    }
  }

  @override
  void onMouseMove(PointerHoverInfo info) {
    _lastMousePos = camera.viewfinder.globalToLocal(info.eventPosition.global);
    lastHoverPos = _toGrid(info.eventPosition.global);
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    if (phase != GamePhase.playing || paused) return;

    final screenPos = info.eventPosition.global;
    final worldPos = camera.viewfinder.globalToLocal(screenPos);
    _lastMousePos = worldPos; // Ensure debug highlight follows drag correctly
    
    final pos = _toGrid(screenPos);
    if (pos == null) return;
    
    // Determine if this is a real drag vs a stationary tap
    if (!_isDragging && _panStartPixel != null) {
      if (screenPos.distanceTo(_panStartPixel!) > 10) {
        _isDragging = true;
      }
    }

    // [DEBUG LOGS] (Issue: Drag Audit)
    if (showDebugOverlay) {
      final camPos = camera.viewfinder.position;
      final zoom = camera.viewfinder.zoom;
      // print('DRAG: Screen=$screenPos World=$worldPos Grid=$pos Cam=$camPos Zoom=$zoom CellSize=$cellSize Offset=($boardOffsetX,$boardOffsetY)');
    }

    if (gridManager!.isValid(pos.x, pos.y)) {
      if (!_dragPath.contains(pos)) {
        // [FIX] Initial Tile Acquisition (Issue 2)
        // For the first few tiles of a drag, snap directly without threshold checks
        // to make building feel instant and responsive.
        if (_lastPlacedPos == null || _dragPath.length < 3) {
          _dragPath.add(pos);
          lastHoverPos = pos;
          _handleBuild(pos);
        } else {
          // Continuous drag: interpolate path from last placed to current
          final line = _getGridLine(_lastPlacedPos!, pos);
          for (final p in line) {
            if (!_dragPath.contains(p)) {
              // Only place if we are close enough to the cell center (prevents diagonal flickering)
              if (p == pos) {
                final cellCenterX = boardOffsetX + p.x * cellSize + cellSize / 2;
                final cellCenterY = boardOffsetY + p.y * cellSize + cellSize / 2;
                final distSq = (worldPos.x - cellCenterX) * (worldPos.x - cellCenterX) + 
                               (worldPos.y - cellCenterY) * (worldPos.y - cellCenterY);
                
                // Use a generous 60% threshold for stable road building
                final threshold = cellSize * 0.6; 
                if (distSq > threshold * threshold) continue;
              }

              _dragPath.add(p);
              lastHoverPos = p;
              _handleBuild(p);
            }
          }
        }
      }
    }
    gridRenderer!.markDirty();
  }

  @override
  void onPanEnd(DragEndInfo info) {
    if (!_isDragging && _dragPath.isNotEmpty) {
      // It's a tap
      final pos = _dragPath.first;
      if (activeTool == BuildTool.trafficLight ||
          activeTool == BuildTool.smartJunction ||
          activeTool == BuildTool.erase ||
          activeTool == BuildTool.expressLane) {
        _handleBuild(pos);
      }
    } else if (_isDragging && activeTool == BuildTool.expressLane) {
      if (_dragPath.length >= 2) {
        final start = _dragPath.first;
        final end = _dragPath.last;
        print('[EXPRESSWAY] DRAG detected: ${start.key} -> ${end.key}');

        if (gridManager!.expressLanes > 0) {
          gridManager!.cancelExpressLanePlacement();
          final success = gridManager!.placeExpressLane(start, end);

          if (success) {
            print('[EXPRESSWAY] UI: Creating renderer for drag placement');
            final mwComp = ExpressLaneComponent(
              start: start,
              end: end,
              cellSize: cellSize,
              offsetX: boardOffsetX,
              offsetY: boardOffsetY,
            );
            _expressLaneComponents.add(mwComp);
            world.add(mwComp);
            gridManager!.expressLanes--;
            print('[EXPRESSWAY] UI: Drag placement successful. Remaining: ${gridManager!.expressLanes}');
          } else {
            print('[EXPRESSWAY] UI: Drag placement failed internal validation');
          }
        } else {
          print('[EXPRESSWAY] UI: No resources for drag placement');
        }
      }
    }

    _lastPlacedPos = null;
    lastHoverPos = null;
    _placedThisDrag.clear();
    _dragPath.clear();
    _panStartPixel = null;
    _isDragging = false;
    gridRenderer!.markDirty();
  }

  void _handleBuild(GridPosition pos) {
    if (gridManager == null) return;

    // [FIX] Boundary Enforcement (Priority 2)
    // Infrastructure must stay within the active world boundary.
    if (spawnController != null) {
      const buffer = 1; // 1-tile buffer
      if (pos.x < spawnController!.minSpawnX - buffer || 
          pos.x > spawnController!.maxSpawnX + buffer ||
          pos.y < spawnController!.minSpawnY - buffer ||
          pos.y > spawnController!.maxSpawnY + buffer) {
        return;
      }
    }

    // RULE: Hitbox/Snap logic - ensure we are snapping to the center of the target cell
    // and expanding the "clickable" area for road nodes/houses
    if (activeTool != BuildTool.expressLane) {
      if (_placedThisDrag.contains(pos)) return;
      if (_lastPlacedPos != null && pos == _lastPlacedPos) {
        return;
      }
    }

    bool success = false;
    switch (activeTool) {
      case BuildTool.road:
      case BuildTool.tunnel:
        if (gridManager!.isValid(pos.x, pos.y)) {
          final cell = gridManager!.getCell(pos.x, pos.y);

          // 1. If it's an existing matching structure, an overpass node, or a building entrance (Priority 1)
          if ((cell.type == CellType.road || cell.type == CellType.tunnel || cell.isExpressLaneNode || gridManager!.isEntrance(pos.x, pos.y)) &&
              !cell.isPendingDeletion) {
            // RULE 2: Allow joining existing roads when dragging over them
            // [FIX] Setting success=true here allows this tile to act as a drag origin.
            success = true;
            if (_lastPlacedPos != null && _lastPlacedPos != pos) {
              // ENTRANCE PROTECTION: We no longer block manual connections.
              // Logic is now unified in GridManager.
              bool allowed = true;

              if (allowed) {
                gridManager!.addEdge(
                  _lastPlacedPos!.x,
                  _lastPlacedPos!.y,
                  pos.x,
                  pos.y,
                );
                gridManager!.updateNodeConnections(_lastPlacedPos!.x, _lastPlacedPos!.y);
              }
            }
            gridManager!.updateNodeConnections(pos.x, pos.y);
            success = true;
            break;
          }
          if ((cell.type == CellType.road || cell.type == CellType.tunnel) &&
              cell.isPendingDeletion) {
            gridManager!.cancelPendingDeletion(pos.x, pos.y);
            gridManager!.updateNodeConnections(pos.x, pos.y);
            success = true;
            break;
          }

          // 2. Try to build (Tunnel through mountain, Road on land)
          if (cell.type == CellType.mountain) {
            // "Tunnel Extension" Logic: If adjacent to an existing tunnel, use a ROAD tile instead
            bool isExtension = false;
            for (final d in [
              [1, 0], // East
              [-1, 0], // West
            ]) {
              final nx = pos.x + d[0];
              final ny = pos.y + d[1];
              if (gridManager!.isValid(nx, ny) &&
                  gridManager!.getCell(nx, ny).type == CellType.tunnel) {
                isExtension = true;
                break;
              }
            }

            if (isExtension) {
              if (gridManager!.roads > 0 &&
                  gridManager!.placeTunnel(pos.x, pos.y, isExtension: true, from: _lastPlacedPos)) {
                gridManager!.roads--;
                success = true;
              }
            } else {
              if (gridManager!.tunnels > 0 &&
                  gridManager!.placeTunnel(pos.x, pos.y, from: _lastPlacedPos)) {
                gridManager!.tunnels--;
                success = true;
              }
            }
          } else if (cell.type == CellType.empty) {
            if (gridManager!.roads > 0) {
              // [FIX] Entrance Road Creation (Priority 1)
              // Resolve the building owner if the drag started at an entrance driveway.
              final firstTile = _dragPath.isNotEmpty ? _dragPath.first : null;
              final dragSource = (firstTile != null) 
                  ? (gridManager!.getBuildingOwningDriveway(firstTile) ?? firstTile)
                  : null;
              
              bool allowed = true;
              if (_lastPlacedPos != null && gridManager!.isLockedEntrance(_lastPlacedPos!)) {
                final owner = gridManager!.getBuildingOwningDriveway(_lastPlacedPos!);
                if (dragSource != owner) {
                  allowed = false;
                  print('[BUILD] Connection rejected: ${_lastPlacedPos!.key} is a locked entrance for building at ${owner?.key ?? "unknown"}');
                }
              }

              if (allowed && gridManager!.placeRoad(pos.x, pos.y, from: _lastPlacedPos)) {
                gridManager!.roads--;
                
                // Explicit House Connection: If we dragged FROM a house to this NEW road, mark it as the driveway
                if (_lastPlacedPos != null) {
                  final lastCell = gridManager!.getCell(_lastPlacedPos!.x, _lastPlacedPos!.y);
                  if (lastCell.isHouse || lastCell.isDestination) {
                    gridManager!.connectBuilding(_lastPlacedPos!.x, _lastPlacedPos!.y, pos.x, pos.y);
                  }
                }

                // FIX 3: GRAPH UPDATE (Rule 3)
                gridManager!.updateNodeConnections(pos.x, pos.y);
                for (final d in [[0,1],[1,0],[0,-1],[-1,0]]) {
                  gridManager!.updateNodeConnections(pos.x + d[0], pos.y + d[1]);
                }
                
                success = true;
              }
            }
          } else if (cell.isHouse || cell.isDestination) {
            // Decision 1: Disallow dynamic driveway rotation
            // The player connects TO the entrance connector, not the house footprint.
            print('[BUILD] Drag to building footprint ignored: Connect to the entrance road instead.');
          }
        }
        break;
      case BuildTool.trafficLight:
        if (gridManager!.trafficLights > 0 &&
            gridManager!.placeTrafficLight(pos.x, pos.y)) {
          gridManager!.trafficLights--;
          success = true;
        }
        break;
      case BuildTool.smartJunction:
        if (gridManager!.smartJunctions > 0 &&
            gridManager!.placeSmartJunction(pos.x, pos.y)) {
          gridManager!.smartJunctions--;
          success = true;
        }
        break;
      case BuildTool.expressLane:
        print('[EXPRESSWAY] TAP detected at ${pos.key}');
        if (gridManager!.expressLanes > 0 || gridManager!.isPlacingExpressLane) {
          final completed = gridManager!.placeExpressLaneNode(pos.x, pos.y);
          if (completed && gridManager!.placedExpressLanes.isNotEmpty) {
            print('[EXPRESSWAY] UI: Creating renderer for last placed edge');
            final mw = gridManager!.placedExpressLanes.last;
            final mwComp = ExpressLaneComponent(
              start: mw[0],
              end: mw[1],
              cellSize: cellSize,
              offsetX: boardOffsetX,
              offsetY: boardOffsetY,
            );
            _expressLaneComponents.add(mwComp);
            world.add(mwComp);
            gridManager!.expressLanes--;
            print('[EXPRESSWAY] UI: Component added to world. Remaining: ${gridManager!.expressLanes}');
          }
          success = true;
        } else {
          print('[EXPRESSWAY] UI: No resources available');
        }
        break;
      case BuildTool.erase:
        final removedType = gridManager!.removeInfrastructure(pos.x, pos.y);
        // Don't refund road tiles immediately — wait until car clears
        if (removedType == 'road') {
          // Road refund happens in cleanupPendingDeletions
        } else if (removedType == 'tunnel') {
          // Tunnel refund also deferred
        } else if (removedType == 'trafficLight') {
          // Traffic light refund also deferred
        } else if (removedType == 'smartJunction') {
          gridManager!.smartJunctions++;
        } else if (removedType == 'expressLane') {
          gridManager!.expressLanes++;
          // Remove from visual components list
          ExpressLaneComponent? compToRemove;
          for (final c in _expressLaneComponents) {
            if ((c.start.x == pos.x && c.start.y == pos.y) ||
                (c.end.x == pos.x && c.end.y == pos.y)) {
              compToRemove = c;
              break;
            }
          }
          if (compToRemove != null) {
            compToRemove.isPendingDeletion = true;
          }
        }

        if (removedType.isNotEmpty) {
          success = true;
          gridRenderer!.markDirty();
        }
        break;
    }

    if (success) {
      _pathCache.clear(); // Clear pathfinding cache on infrastructure changes
      _lastPlacedPos = pos;
      _placedThisDrag.add(pos);
      gridRenderer!.markDirty();
      onStateChanged?.call();
    }
  }


}

