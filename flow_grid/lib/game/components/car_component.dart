import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import '../../models/game_constants.dart';
import '../../models/grid_cell.dart';
import '../../game/flow_grid_game.dart';
import '../pathfinder.dart';

class CarComponent extends PositionComponent with HasGameReference<FlowGridGame> {
  int colorIndex;
  List<GridPosition> path;
  double cellSize;
  double offsetX;
  double offsetY;
  double speed;
  GridPosition spawnHousePos;
  GridPosition targetDest;
  VehicleType vehicleType;

  int _currentPathIndex = 0;
  double _distanceTraveled = 0.0;
  ui.Path _smoothPath = ui.Path();
  ui.PathMetric? _metric;
  double _totalLength = 0.0;
  
  bool arrived = false;
  bool isReturning = false;
  bool isWaiting = false;
  double _waitTimer = 0.0;
  bool onExpressLane = false;
  double travelTime = 0.0;
  bool _waitingAtSignal = false;
  static const double maxWaitTime = 1.5;
  String? routeId;

  // Follow-the-leader
  double _collisionCheckTimer = 0;
  double _lastTargetMultiplier = 1.0;
  double _currentSpeedMultiplier = 1.0;
  
  // Simulation throttling
  double _simCheckTimer = 0;
  double _congestionMultiplier = 1.0;
  double _terrainSpeed = 1.0;
  
  // Acceleration
  static const double accelerationRate = 1.5;
  static const double decelerationRate = 2.8;
  static const double startupAccelerationBonus = 1.3;

  CarComponent({
    required this.colorIndex,
    required this.path,
    required this.cellSize,
    required this.spawnHousePos,
    required this.targetDest,
    this.offsetX = 0,
    this.offsetY = 0,
    this.speed = GameConstants.carSpeed,
    this.vehicleType = VehicleType.car,
    this.routeId,
    int? initialPathIndex,
    double? initialProgress,
    bool? initialReturning,
  }) {
    _init(
      initialPathIndex: initialPathIndex,
      initialProgress: initialProgress,
      initialReturning: initialReturning,
    );
  }

  void _init({int? initialPathIndex, double? initialProgress, bool? initialReturning}) {
    _currentPathIndex = initialPathIndex ?? 0;
    isReturning = initialReturning ?? false;
    arrived = false;
    isWaiting = false;
    _waitTimer = 0.0;
    onExpressLane = false;
    travelTime = 0.0;
    _waitingAtSignal = false;
    _distanceTraveled = 0.0;
    _currentSpeedMultiplier = 1.0;
    _lastTargetMultiplier = 1.0;

    _rebuildSmoothPath();

    if (initialProgress != null && _totalLength > 0) {
      _distanceTraveled = initialProgress * _totalLength;
      _updatePosition(0);
    } else if (path.isNotEmpty) {
      final startPos = path[0];
      position = Vector2(
        offsetX + startPos.x * cellSize + cellSize / 2,
        offsetY + startPos.y * cellSize + cellSize / 2,
      );
    }
    
    anchor = Anchor.center;
    priority = 10;
    _updateVehicleSize();
  }

  void _updateVehicleSize() {
    final baseSize = cellSize * 0.55;
    switch (vehicleType) {
      case VehicleType.car:
        size = Vector2(baseSize, baseSize);
      case VehicleType.truck:
        size = Vector2(baseSize * 1.3, baseSize * 1.1);
      case VehicleType.serviceVan:
        size = Vector2(baseSize * 1.1, baseSize * 0.95);
      case VehicleType.bus:
        size = Vector2(baseSize * 1.5, baseSize * 1.2);
      case VehicleType.emergency:
        size = Vector2(baseSize * 1.2, baseSize);
    }
  }

  void reuseState({
    required List<GridPosition> path,
    required int colorIndex,
    required GridPosition spawnHousePos,
    required GridPosition targetDest,
    required VehicleType vehicleType,
    String? routeId,
  }) {
    this.path = path;
    this.colorIndex = colorIndex;
    this.spawnHousePos = spawnHousePos;
    this.targetDest = targetDest;
    this.vehicleType = vehicleType;
    this.routeId = routeId;
    
    _currentPathIndex = 0;
    _distanceTraveled = 0;
    travelTime = 0;
    _waitTimer = 0;
    arrived = false;
    isWaiting = false;
    isReturning = false;
    onExpressLane = false;
    _waitingAtSignal = false;
    _currentSpeedMultiplier = 0.0;
    _lastTargetMultiplier = 1.0;
    
    priority = 10;
    _rebuildSmoothPath();

    // Snap to the new path's starting cell so a reused-from-pool car doesn't
    // render at its previous trip's endpoint before the first update tick.
    if (path.isNotEmpty && _totalLength > 0) {
      final tangent = _metric?.getTangentForOffset(0);
      if (tangent != null) {
        final fwd = tangent.vector;
        final lane = cellSize * 0.14;
        position = Vector2(
          tangent.position.dx - fwd.dy * lane,
          tangent.position.dy + fwd.dx * lane,
        );
        angle = -tangent.angle;
      }
    } else if (path.isNotEmpty) {
      final startPos = path[0];
      position = Vector2(
        offsetX + startPos.x * cellSize + cellSize / 2,
        offsetY + startPos.y * cellSize + cellSize / 2,
      );
    }

    _updateVehicleSize();
  }

  double get _vehicleSpeedMultiplier {
    switch (vehicleType) {
      case VehicleType.car: return 1.0;
      case VehicleType.truck: return GameConstants.truckSpeedMultiplier;
      case VehicleType.serviceVan: return GameConstants.serviceVanSpeedMultiplier;
      case VehicleType.bus: return 0.7;
      case VehicleType.emergency: return 1.8;
    }
  }

  void _rebuildSmoothPath() {
    _smoothPath = ui.Path();
    if (path.length < 2) {
      _totalLength = 0;
      return;
    }

    Offset getPos(GridPosition p) {
      final midX = offsetX + p.x * cellSize + cellSize / 2;
      final midY = offsetY + p.y * cellSize + cellSize / 2;
      if (p.side == null) return Offset(midX, midY);
      final r = cellSize * 0.4;
      switch (p.side!) {
        case Direction.north: return Offset(midX, midY - r);
        case Direction.east:  return Offset(midX + r, midY);
        case Direction.south: return Offset(midX, midY + r);
        case Direction.west:  return Offset(midX - r, midY);
      }
    }

    final start = getPos(path[0]);
    _smoothPath.moveTo(start.dx, start.dy);

    for (int i = 0; i < path.length - 1; i++) {
      final p1 = path[i];
      final p2 = path[i + 1];
      final c1 = getPos(p1);
      final c2 = getPos(p2);

      final dx = (p1.x - p2.x).abs();
      final dy = (p1.y - p2.y).abs();
      if (dx > 1 || dy > 1) {
        final delta = c2 - c1;
        final dist = delta.distance;
        final mid = (c1 + c2) / 2;
        final unitDir = delta / dist;
        final perp = Offset(-unitDir.dy, unitDir.dx);
        final arcHeight = dist * 0.15;
        final cp = mid + perp * arcHeight;
        _smoothPath.quadraticBezierTo(cp.dx, cp.dy, c2.dx, c2.dy);
        continue;
      }

      if (i < path.length - 2) {
        final p3 = path[i + 2];
        final c3 = getPos(p3);
        bool isStraight = (p1.x == p2.x && p2.x == p3.x && p1.side == null && p2.side == null && p3.side == null) ||
            (p1.y == p2.y && p2.y == p3.y && p1.side == null && p2.side == null && p3.side == null);
        if (!isStraight) {
          // Endpoints at 0.5 land on the cell edges, matching the road
          // renderer's quadratic-bezier endpoints exactly. Anything less and
          // the car visibly cuts inside the painted curve at every corner.
          final cornerStart = c2 + (c1 - c2) * 0.5;
          _smoothPath.lineTo(cornerStart.dx, cornerStart.dy);
          final cornerEnd = c2 + (c3 - c2) * 0.5;
          _smoothPath.quadraticBezierTo(c2.dx, c2.dy, cornerEnd.dx, cornerEnd.dy);
          continue;
        }
      }
      _smoothPath.lineTo(c2.dx, c2.dy);
    }

    final metrics = _smoothPath.computeMetrics().toList();
    if (metrics.isNotEmpty) {
      _metric = metrics.first;
      _totalLength = _metric!.length;
    } else {
      _totalLength = 0;
    }
  }

  void _updatePosition(double dt) {
    if (_totalLength <= 0) return;
    _distanceTraveled += dt * speed * game.timeScale;
    if (_distanceTraveled >= _totalLength) {
      _distanceTraveled = _totalLength;
    }
    final tangent = _metric!.getTangentForOffset(_distanceTraveled);
    if (tangent != null) {
      // Drive on the right side of the road centerline. Right-perpendicular
      // in screen coords (y-down) of forward (fx, fy) is (-fy, fx). Two cars
      // going opposite directions land on opposite sides — no more overlap.
      final fwd = tangent.vector;
      final lane = cellSize * 0.14;
      position = Vector2(
        tangent.position.dx - fwd.dy * lane,
        tangent.position.dy + fwd.dx * lane,
      );
      angle = -tangent.angle;
    }
  }

  GridPosition? get currentTarget {
    if (_currentPathIndex + 1 < path.length) return path[_currentPathIndex + 1];
    return null;
  }

  int get currentPathIndex => _currentPathIndex;

  Set<GridPosition> get occupiedTiles {
    if (arrived) return {};
    return path.skip(_currentPathIndex).toSet();
  }

  void startReturnTrip(List<GridPosition> newPath) {
    path = newPath;
    _currentPathIndex = 0;
    _distanceTraveled = 0.0;
    arrived = false;
    isReturning = true;
    _rebuildSmoothPath();
  }

  void _onArrivedAtDestination() {
    final gm = game.gridManager;
    if (gm == null) {
      arrived = true;
      return;
    }

    // Credit the delivery once per outbound trip.
    if (gm.isValid(targetDest.x, targetDest.y) &&
        gm.getCell(targetDest.x, targetDest.y).isDestination) {
      game.score += 100;
      game.totalDeliveries += 1;

      // Decrease demand and claimed demand
      final destKey = "${targetDest.x},${targetDest.y}";
      final currentDemand = gm.demand[destKey] ?? 0;
      if (currentDemand > 0) {
        gm.demand[destKey] = currentDemand - 1;
      }
      final currentClaimed = gm.claimedDemand[destKey] ?? 0;
      if (currentClaimed > 0) {
        gm.claimedDemand[destKey] = currentClaimed - 1;
      }
    }

    // Pathfind home from current path endpoint to the home driveway.
    final returnStart = path.last;
    final homeDriveway = gm.buildingDriveways['${spawnHousePos.x},${spawnHousePos.y}'];
    if (homeDriveway == null) {
      arrived = true;
      return;
    }

    final returnPath = Pathfinder.findPath(gm, returnStart, homeDriveway);
    if (returnPath != null && returnPath.length >= 2) {
      startReturnTrip(returnPath);
    } else {
      // No way home (network broken). Vanish gracefully.
      arrived = true;
    }
  }

  Map<String, dynamic> toJson() => {
    'colorIndex': colorIndex,
    'path': path.map((p) => {'x': p.x, 'y': p.y}).toList(),
    'currentPathIndex': _currentPathIndex,
    'progress': _totalLength > 0 ? _distanceTraveled / _totalLength : 0.0,
    'isReturning': isReturning,
    'spawnHousePos': {'x': spawnHousePos.x, 'y': spawnHousePos.y},
    'targetDest': {'x': targetDest.x, 'y': targetDest.y},
    'vehicleType': vehicleType.index,
  };

  @override
  void update(double dt) {
    super.update(dt);
    if (game.paused) return;

    if (arrived || path.length < 2) {
      arrived = true;
      return;
    }

    travelTime += dt * game.timeScale;

    // Bus stop logic
    if (vehicleType == VehicleType.bus && !isWaiting && !arrived) {
      final currentCellPos = _getCurrentGridPos();
      final cell = game.gridManager!.getCell(currentCellPos.x, currentCellPos.y);
      if (cell.isBusStop) {
        isWaiting = true;
        _waitTimer = 0;
      }
    }

    if (isWaiting) {
      _waitTimer += dt * game.timeScale;
      double waitLimit;
      if (vehicleType == VehicleType.bus) {
        waitLimit = 1.5;
      } else if (isReturning) {
        waitLimit = 0.5;
      } else {
        waitLimit = maxWaitTime;
      }
      if (_waitTimer >= waitLimit) {
        isWaiting = false;
        // Bus: keep cruising along its route. Returning: this was the home stop, done.
        // Outbound non-bus: deliver, then try to head back home before disappearing.
        if (vehicleType != VehicleType.bus) {
          if (isReturning) {
            arrived = true;
          } else {
            _onArrivedAtDestination();
          }
        }
      }
      return;
    }

    if (_distanceTraveled >= _totalLength) {
      if (!isWaiting) {
        isWaiting = true;
        _waitTimer = 0;
        return;
      }
      arrived = true;
      return;
    }

    // --- Throttled Signal & Congestion Checks (15Hz) ---
    _simCheckTimer += dt;
    if (_simCheckTimer >= 1 / 15) {
      _simCheckTimer = 0;
      
      _waitingAtSignal = false;
      if (_currentPathIndex + 1 < path.length && game.gridManager != null) {
        final nextPos = path[_currentPathIndex + 1];
        final nextCell = game.gridManager!.getCell(nextPos.x, nextPos.y);
        if (nextCell.hasTrafficLight && nextPos.side == null) {
          final curPos = path[_currentPathIndex];
          Direction? moveDir;
          if (nextPos.x > curPos.x) {
            moveDir = Direction.east;
          } else if (nextPos.x < curPos.x) {
            moveDir = Direction.west;
          } else if (nextPos.y > curPos.y) {
            moveDir = Direction.south;
          } else if (nextPos.y < curPos.y) {
            moveDir = Direction.north;
          }
          
          if (moveDir != null && !game.gridManager!.isGreenForDirection(nextPos.x, nextPos.y, moveDir)) {
            final signalWorldX = offsetX + nextPos.x * cellSize + cellSize / 2;
            final signalWorldY = offsetY + nextPos.y * cellSize + cellSize / 2;
            if (position.distanceToSquared(Vector2(signalWorldX, signalWorldY)) < cellSize * cellSize) {
              _waitingAtSignal = true;
            }
          }
        }
      }

      _congestionMultiplier = 1.0;
      if (game.gridManager != null && _currentPathIndex < path.length) {
        final curPos = path[_currentPathIndex];
        if (game.gridManager!.isRoadCongested(curPos.x, curPos.y)) {
          _congestionMultiplier = 0.5;
        }
      }
      
      onExpressLane = false;
      _terrainSpeed = 1.0;
      if (_currentPathIndex < path.length && game.gridManager != null) {
        final curPos = path[_currentPathIndex];
        final curCell = game.gridManager!.getCell(curPos.x, curPos.y);
        _terrainSpeed = curCell.speedMultiplier;
        onExpressLane = curCell.isExpressLaneNode || _terrainSpeed >= GameConstants.expressLaneSpeed;
      }
    }

    // --- Follow-the-leader ---
    double targetMultiplier = 1.0;
    _collisionCheckTimer += dt;
    if (_collisionCheckTimer >= 0.1) {
      _collisionCheckTimer = 0;
      if (!onExpressLane && !_waitingAtSignal) {
        final myPos = position;
        final forward = Vector2(cos(angle), sin(angle));
        final minGap = cellSize * 0.7;
        double closestAheadDist = double.infinity;
        final myGridPos = path[_currentPathIndex.clamp(0, path.length - 1)];
        final gWidth = game.gridWidth;

        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            final key = (myGridPos.x + dx) + (myGridPos.y + dy) * gWidth;
            final others = game.carGrid[key];
            if (others == null) continue;
            for (final other in others) {
              if (identical(other, this) || other.onExpressLane || other.arrived) continue;
              final distSq = myPos.distanceToSquared(other.position);
              if (distSq > (cellSize * 1.8) * (cellSize * 1.8)) continue;
              final toOther = other.position - myPos;
              final dotProduct = toOther.x * forward.x + toOther.y * forward.y;
              if (dotProduct <= 0) continue;
              final dist = sqrt(distSq);
              if (dist < closestAheadDist) closestAheadDist = dist;
            }
          }
        }

        if (closestAheadDist < minGap) {
          targetMultiplier = (closestAheadDist / minGap).clamp(0.0, 1.0);
        } else {
          targetMultiplier = 1.0;
        }
      }
      _lastTargetMultiplier = targetMultiplier;
    }

    if (_waitingAtSignal) {
      targetMultiplier = 0.0;
    } else {
      targetMultiplier = _lastTargetMultiplier;
      if (_currentPathIndex + 1 < path.length) {
        final nextPos = path[_currentPathIndex + 1];
        if (game.gridManager!.isValid(nextPos.x, nextPos.y) && 
            game.gridManager!.isRoadCongested(nextPos.x, nextPos.y)) {
           targetMultiplier = min(targetMultiplier, 0.15);
        }
      }
    }

    // --- Acceleration/Deceleration ---
    final baseTarget = targetMultiplier * _vehicleSpeedMultiplier * _terrainSpeed * _congestionMultiplier;
    if (_currentSpeedMultiplier < baseTarget) {
      double rate = accelerationRate;
      if (_currentSpeedMultiplier < 0.1) rate *= startupAccelerationBonus;
      _currentSpeedMultiplier = min(baseTarget, _currentSpeedMultiplier + rate * dt);
    } else if (_currentSpeedMultiplier > baseTarget) {
      _currentSpeedMultiplier = max(baseTarget, _currentSpeedMultiplier - decelerationRate * dt);
    }

    double finalMultiplier = _currentSpeedMultiplier;
    if (!_waitingAtSignal && !arrived && !isWaiting) {
      finalMultiplier = max(0.08, _currentSpeedMultiplier);
    }

    _updatePosition(dt * finalMultiplier);

    if (_totalLength > 0) {
      _currentPathIndex = ((_distanceTraveled / _totalLength) * (path.length - 1)).floor().clamp(0, path.length - 1);
    }
  }

  GridPosition _getCurrentGridPos() {
    final x = ((position.x - offsetX) / cellSize).floor();
    final y = ((position.y - offsetY) / cellSize).floor();
    return GridPosition(
      x.clamp(0, game.gridManager?.cols ?? 1 - 1), 
      y.clamp(0, game.gridManager?.rows ?? 1 - 1)
    );
  }

  // ============================================================
  // RENDERING — single sprite from the shared 1x6 vehicle atlas.
  // One drawImageRect call per car; all 6 colors share one GPU texture.
  // ============================================================

  @override
  void render(Canvas canvas) {
    final sprites = game.vehicleSprites;
    if (sprites.isEmpty) return;
    final sprite = sprites[colorIndex % sprites.length];

    // Flame's render() canvas has (0,0) at the component's top-left, not at
    // the anchor — so we have to translate to size/2 to land on the world
    // `position` (= the road centerline) before rotating + drawing.
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.rotate(pi / 2);

    // Source art faces "up" (north); after the pi/2 rotation that maps to +x
    // (east), which is the component's forward direction.
    final length = size.x;
    final width = length / game.vehicleSpriteAspect;
    sprite.render(
      canvas,
      position: Vector2(-width / 2, -length / 2),
      size: Vector2(width, length),
    );
    canvas.restore();
  }
}
