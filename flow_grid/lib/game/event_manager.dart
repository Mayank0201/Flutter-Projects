import 'dart:math';
import 'package:flame/components.dart';
import '../models/city_event.dart';
import '../models/grid_cell.dart';
import '../models/game_constants.dart';
import 'grid_manager.dart';
import 'district_planner.dart';
import 'flow_grid_game.dart';

class EventManager extends Component with HasGameReference<FlowGridGame> {
  final GridManager gridManager;
  final DistrictPlanner districtPlanner;
  final Random _random = Random();

  final List<CityEvent> activeEvents = [];
  
  double _eventTimer = 0;
  double _nextEventInterval = 60.0; // Initial interval
  bool _pathCacheNeedsInvalidation = false;
  
  bool get pathCacheNeedsInvalidation => _pathCacheNeedsInvalidation;

  EventManager({required this.gridManager, required this.districtPlanner}) {
    _scheduleNextEvent();
  }

  void _scheduleNextEvent() {
    _eventTimer = 0;
    _nextEventInterval = 40.0 + _random.nextDouble() * 40.0; // 40-80 seconds
  }

  @override
  void update(double dt) {
    if (game.paused) return;
    
    final safeDt = dt.clamp(0.0, 0.05) * game.timeScale;
    final currentWeek = game.week;

    // 1. Process active events (age them, clean up expired)
    bool eventsChanged = false;
    
    for (int i = activeEvents.length - 1; i >= 0; i--) {
      final event = activeEvents[i];
      event.elapsed += safeDt;
      
      if (event.isExpired) {
        _cleanupEvent(event);
        activeEvents.removeAt(i);
        eventsChanged = true;
      }
    }

    if (eventsChanged) {
      _pathCacheNeedsInvalidation = true;
    }

    // 2. Grace Rules for spawning new events
    if (currentWeek < 3) return; // No events before week 3
    if (activeEvents.length >= 2) return; // Max 2 concurrent events
    
    // Check global overflow (no events if city is struggling > 60%)
    bool isStruggling = false;
    for (final level in gridManager.overflowLevels.values) {
      if (level > 0.6) {
        isStruggling = true;
        break;
      }
    }
    if (isStruggling) return;

    // 3. Spawn new event
    _eventTimer += safeDt;
    if (_eventTimer >= _nextEventInterval) {
      _spawnRandomEvent();
      _scheduleNextEvent();
    }
  }

  void clearInvalidationFlag() {
    _pathCacheNeedsInvalidation = false;
  }

  void _spawnRandomEvent() {
    final possibleTypes = CityEventType.values.toList();
    possibleTypes.shuffle(_random);
    
    for (final type in possibleTypes) {
      if (_trySpawnEvent(type)) {
        _pathCacheNeedsInvalidation = true;
        return; // Successfully spawned one
      }
    }
  }

  bool _trySpawnEvent(CityEventType type) {
    switch (type) {
      case CityEventType.roadBlock:
        // Find a valid road tile (not an intersection, not an endpoint, not a bridge/tunnel)
        final validRoads = <GridPosition>[];
        for (int y = 0; y < gridManager.rows; y++) {
          for (int x = 0; x < gridManager.cols; x++) {
            final cell = gridManager.grid[y][x];
            if (cell.isRoad && !cell.isTunnel && !cell.isBridge && !cell.isInfrastructureInternal) {
              validRoads.add(GridPosition(x, y));
            }
          }
        }
        if (validRoads.isEmpty) return false;
        
        final pos = validRoads[_random.nextInt(validRoads.length)];
        
        // Apply effect
        gridManager.grid[pos.y][pos.x] = gridManager.grid[pos.y][pos.x].copyWith(speedMultiplier: 0.01); // Effectively impassable
        
        activeEvents.add(CityEvent(
          type: type,
          title: "Road Blockage",
          description: "An accident has blocked traffic.",
          affectedTile: pos,
          duration: 20.0 + _random.nextDouble() * 15.0, // 20-35s
        ));
        return true;

      case CityEventType.trafficSurge:
      case CityEventType.festival:
        // Pick a random active color
        final activeColors = gridManager.destinations.map((d) => gridManager.grid[d.y][d.x].colorIndex).where((c) => c != null).toSet().toList();
        if (activeColors.isEmpty) return false;
        final color = activeColors[_random.nextInt(activeColors.length)];
        
        if (type == CityEventType.trafficSurge) {
          activeEvents.add(CityEvent(
            type: type,
            title: "Traffic Surge",
            description: "High demand in district.",
            affectedColor: color,
            duration: 30.0 + _random.nextDouble() * 20.0,
          ));
        } else {
          activeEvents.add(CityEvent(
            type: type,
            title: "Local Festival",
            description: "Bonus score, high traffic.",
            affectedColor: color,
            duration: 40.0 + _random.nextDouble() * 20.0,
          ));
        }
        return true;

      case CityEventType.bridgeMaintenance:
        final validInfra = <GridPosition>[];
        for (int y = 0; y < gridManager.rows; y++) {
          for (int x = 0; x < gridManager.cols; x++) {
            final cell = gridManager.grid[y][x];
            if (cell.isTunnel || cell.isBridge) {
               validInfra.add(GridPosition(x, y));
            }
          }
        }
        if (validInfra.isEmpty) return false;
        
        final pos = validInfra[_random.nextInt(validInfra.length)];
        // Apply effect
        gridManager.grid[pos.y][pos.x] = gridManager.grid[pos.y][pos.x].copyWith(speedMultiplier: 0.3); // Very slow
        
        activeEvents.add(CityEvent(
          type: type,
          title: "Maintenance",
          description: "Infrastructure repairs.",
          affectedTile: pos,
          duration: 35.0 + _random.nextDouble() * 25.0,
        ));
        return true;
    }
  }

  void _cleanupEvent(CityEvent event) {
    if (event.affectedTile != null) {
      final pos = event.affectedTile!;
      final cell = gridManager.grid[pos.y][pos.x];
      // Restore normal speed
      if (cell.isExpressLane) {
          gridManager.grid[pos.y][pos.x] = cell.copyWith(speedMultiplier: GameConstants.expressLaneSpeed);
      } else {
          gridManager.grid[pos.y][pos.x] = cell.copyWith(speedMultiplier: 1.0);
      }
    }
  }

  // Helper methods to query event effects from the rest of the game
  
  double getDemandMultiplier(int colorIndex) {
    double mult = 1.0;
    for (final event in activeEvents) {
      if (event.affectedColor == colorIndex) {
        if (event.type == CityEventType.trafficSurge) mult *= 2.0;
        if (event.type == CityEventType.festival) mult *= 1.5;
      }
    }
    return mult;
  }

  double getCongestionMultiplier(int colorIndex) {
    double mult = 1.0;
    for (final event in activeEvents) {
      if (event.affectedColor == colorIndex && event.type == CityEventType.festival) {
        mult *= 1.5;
      }
    }
    return mult;
  }

  int getScoreBonus(int colorIndex) {
    int bonus = 0;
    for (final event in activeEvents) {
      if (event.affectedColor == colorIndex && event.type == CityEventType.festival) {
        bonus += 50; // Extra 50 points per delivery
      }
    }
    return bonus;
  }
}
