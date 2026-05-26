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
    if (game.paused) return;

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

    activeEvents.add(event);
    _spawnEmergencyVehicle(event);
    
    if (GameConstants.debugInfrastructure) {
      debugPrint('[BREADCRUMB] Emergency event triggered at: (${target.x}, ${target.y}). Timeout: 60s.');
    }
    game.onStateChanged?.call();
  }

  void _spawnEmergencyVehicle(EmergencyEvent event) {
    // Find a "Service Depot" or just a random edge of the map for now
    final start = const GridPosition(0, 0); // Placeholder
    
    final path = Pathfinder.findPath(
      game.gridManager!,
      start,
      event.location,
      isEmergency: true,
    );

    if (path != null) {
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
    }
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

