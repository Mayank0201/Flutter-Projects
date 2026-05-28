import 'dart:math';
import 'package:flame/components.dart';
import '../models/bus_route.dart';
import '../models/grid_cell.dart';
import 'flow_grid_game.dart';

class TransitManager extends Component with HasGameReference<FlowGridGame> {
  final Map<String, BusRoute> busRoutes = {};
  final List<BusStop> busStops = [];
  
  double _spawnTimer = 0;
  static const double spawnInterval = 30.0; // Spawn a bus every 30s per route

  void addRoute(BusRoute route) {
    busRoutes[route.id] = route;
    for (final stopPos in route.stops) {
      busStops.add(BusStop(position: stopPos, routeId: route.id));
      game.gridManager!.setBusStop(stopPos.x, stopPos.y, routeId: route.id);
    }
  }

  @override
  void update(double dt) {
    if (game.paused || game.timeScale == 0.0) return;
    
    _spawnTimer += dt * game.timeScale;
    if (_spawnTimer >= spawnInterval) {
      _spawnTimer = 0;
      _spawnBuses();
    }
    
    _updatePassengerDemand(dt);
  }

  void _spawnBuses() {
    for (final route in busRoutes.values) {
      if (route.stops.length < 2) continue;
      
      // Spawn a bus at the first stop
      final start = route.stops.first;
      
      final bus = game.carPool.getCar(
        path: route.path,
        colorIndex: 0, // Transit is color-neutral
        spawnHousePos: start,
        targetDest: route.stops.last,
        vehicleType: VehicleType.bus,
        routeId: route.id,
        cellSize: game.cellSize,
        offsetX: game.boardOffsetX,
        offsetY: game.boardOffsetY,
      );
      
      game.cars.add(bus);
      game.world.add(bus);
    }
  }

  void _updatePassengerDemand(double dt) {
    // Every few ticks, increase waiting passengers at stops based on nearby house density
    for (final stop in busStops) {
       // Logic to attract passengers...
       // For now, just a slow tick
       if (Random().nextDouble() < 0.05 * game.timeScale) {
         stop.waitingPassengers++;
       }
    }
  }
  
  /// Returns the reduction in car spawn probability for a district served by transit.
  double getCongestionRelief(GridPosition pos, int colorIndex) {
    // If a bus route serves this color and has a stop nearby, reduce car spawning
    for (final route in busRoutes.values) {
      if (route.servesColor(colorIndex)) {
        for (final stop in route.stops) {
          if (pos.manhattanDistance(stop) < 8) {
            return 0.35; // 35% reduction in car generation
          }
        }
      }
    }
    return 0.0;
  }
}
