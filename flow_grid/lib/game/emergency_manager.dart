import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import '../models/grid_cell.dart';
import '../models/game_constants.dart';
import 'flow_grid_game.dart';
import 'pathfinder.dart';

class EmergencyEvent {
  final String id;
  final GridPosition location;
  final String description;
  double timeout; // Seconds to reach destination
  bool resolved = false;

  EmergencyEvent({
    required this.id,
    required this.location,
    required this.description,
    this.timeout = 60.0,
  });
}

class EmergencyManager extends Component with HasGameReference<FlowGridGame> {
  final List<EmergencyEvent> activeEvents = [];
  double _eventTimer = 0;
  static const double eventFrequency = 45.0; // One emergency every 45s

  @override
  void update(double dt) {
    if (game.paused || game.timeScale == 0.0) return;

    _eventTimer += dt * game.timeScale;
    if (_eventTimer >= eventFrequency) {
      _eventTimer = 0;
      _triggerRandomEmergency();
    }

    _checkTimeouts(dt);
  }

  void _triggerRandomEmergency() {
    if (game.gridManager!.destinations.isEmpty) return;

    final target = game.gridManager!.destinations[Random().nextInt(game.gridManager!.destinations.length)];
    final event = EmergencyEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      location: target,
      description: "Medical Emergency",
      timeout: 60.0,
    );

    // Only start the emergency (and its timeout penalty clock) once we've confirmed
    // a responder vehicle can actually be dispatched. Previously the event was added
    // unconditionally, but the vehicle's spawn point was hardcoded to (0,0), which is
    // almost never a real road tile — so the vehicle silently failed to spawn and the
    // event always timed out for a guaranteed -500 penalty with no way to prevent it.
    final spawned = _spawnEmergencyVehicle(event);
    if (!spawned) {
      if (GameConstants.debugInfrastructure) {
        debugPrint('[BREADCRUMB] Emergency event skipped (no reachable responder route) at: (${target.x}, ${target.y}).');
      }
      return;
    }

    activeEvents.add(event);

    if (GameConstants.debugInfrastructure) {
      debugPrint('[BREADCRUMB] Emergency event triggered at: (${target.x}, ${target.y}). Timeout: 60s.');
    }
    game.onStateChanged?.call();
  }

  /// Returns true if a responder vehicle was actually spawned and dispatched.
  bool _spawnEmergencyVehicle(EmergencyEvent event) {
    // Dispatch from the nearest existing road tile to the incident, rather than a
    // hardcoded grid corner that is almost never part of the player's road network.
    final start = _findNearestRoadPosition(event.location);
    if (start == null) return false;

    final path = Pathfinder.findPath(
      game.gridManager!,
      start,
      event.location,
      isEmergency: true,
    );

    if (path == null) return false;

    final ev = game.carPool.getCar(
      path: path,
      colorIndex: 0,
      spawnHousePos: start,
      targetDest: event.location,
      vehicleType: VehicleType.emergency,
      cellSize: game.cellSize,
      offsetX: game.boardOffsetX,
      offsetY: game.boardOffsetY,
      routeId: event.id,
    );
    game.cars.add(ev);
    game.world.add(ev);
    return true;
  }

  /// Scans the grid for the closest road-type tile to [target], excluding the
  /// target tile itself, to use as an emergency-vehicle dispatch point.
  GridPosition? _findNearestRoadPosition(GridPosition target) {
    final gridManager = game.gridManager!;
    GridPosition? best;
    int bestDistSq = 1 << 30;

    for (int y = 0; y < gridManager.rows; y++) {
      for (int x = 0; x < gridManager.cols; x++) {
        if (x == target.x && y == target.y) continue;
        final cell = gridManager.grid[y][x];
        if (!cell.isRoad) continue;

        final dx = x - target.x;
        final dy = y - target.y;
        final distSq = dx * dx + dy * dy;
        if (distSq < bestDistSq) {
          bestDistSq = distSq;
          best = GridPosition(x, y);
        }
      }
    }

    return best;
  }

  void _checkTimeouts(double dt) {
    for (int i = activeEvents.length - 1; i >= 0; i--) {
      final event = activeEvents[i];
      if (!event.resolved) {
        event.timeout -= dt * game.timeScale;
        if (event.timeout <= 0) {
          _handleFailure(event);
          activeEvents.removeAt(i);
          game.onStateChanged?.call();
        }
      }
    }
  }

  void _handleFailure(EmergencyEvent event) {
    game.score -= 500;
    if (GameConstants.debugInfrastructure) {
      debugPrint('[BREADCRUMB] Emergency event failed (timeout) at: (${event.location.x}, ${event.location.y}).');
    }
  }

  void resolveEvent(String eventId) {
    final eventIndex = activeEvents.indexWhere((e) => e.id == eventId);
    if (eventIndex != -1) {
      final event = activeEvents[eventIndex];
      activeEvents.removeAt(eventIndex);
      game.score += 200;
      if (GameConstants.debugInfrastructure) {
        debugPrint('[BREADCRUMB] Emergency event resolved at: (${event.location.x}, ${event.location.y}).');
      }
      game.onStateChanged?.call();
    }
  }
}

