import 'dart:math';
import 'package:flame/components.dart';
import '../models/bus_route.dart';
import '../models/grid_cell.dart';
import 'flow_grid_game.dart';
import 'pathfinder.dart';

class TransitManager extends Component with HasGameReference<FlowGridGame> {
  final Map<String, BusRoute> busRoutes = {};
  final List<BusStop> busStops = [];

  double _spawnTimer = 0;
  static const double spawnInterval = 30.0; // Spawn a bus every 30s per route

  // [FIX] Nothing in the codebase ever called addRoute(), so busRoutes was
  // always empty and _spawnBuses()/getCongestionRelief() were permanent
  // no-ops. Periodically scan the grid ourselves for a viable house<->
  // destination pair per district color and establish a route for it.
  double _routeScanTimer = 0;
  static const double routeScanInterval = 15.0;

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

    _routeScanTimer += dt * game.timeScale;
    if (_routeScanTimer >= routeScanInterval) {
      _routeScanTimer = 0;
      _scanForViableRoutes();
    }

    _spawnTimer += dt * game.timeScale;
    if (_spawnTimer >= spawnInterval) {
      _spawnTimer = 0;
      _spawnBuses();
    }

    _updatePassengerDemand(dt);
  }

  /// Looks for a district (color) that has both a house and a destination
  /// already connected to the road network, and — if it doesn't already
  /// have a route — wires up a simple two-stop bus route between them via
  /// [addRoute]. Re-run periodically so districts built later also get
  /// service; districts that already have a route are skipped cheaply.
  void _scanForViableRoutes() {
    final gm = game.gridManager;
    if (gm == null) return;

    for (int colorIndex = 0; colorIndex < game.activeColorCount; colorIndex++) {
      final routeId = 'auto_route_$colorIndex';
      if (busRoutes.containsKey(routeId)) continue;

      GridPosition? housePos;
      for (final h in gm.houses) {
        if (gm.getCell(h.x, h.y).colorIndex == colorIndex) {
          housePos = h;
          break;
        }
      }
      if (housePos == null) continue;

      GridPosition? destPos;
      for (final d in gm.destinations) {
        if (gm.getCell(d.x, d.y).colorIndex == colorIndex) {
          destPos = d;
          break;
        }
      }
      if (destPos == null) continue;

      final houseDriveway = gm.buildingDriveways['${housePos.x},${housePos.y}'];
      final destDriveway = gm.buildingDriveways['${destPos.x},${destPos.y}'];
      if (houseDriveway == null || destDriveway == null) continue;

      final path = Pathfinder.findPath(
        gm,
        houseDriveway,
        destDriveway,
        vehicleType: VehicleType.bus,
      );
      if (path == null || path.length < 2) continue;

      addRoute(BusRoute(
        id: routeId,
        name: 'District ${colorIndex + 1} Line',
        stops: [houseDriveway, destDriveway],
        path: path,
        colorIndices: [colorIndex],
      ));
    }
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
