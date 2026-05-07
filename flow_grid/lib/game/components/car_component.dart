import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import '../../models/game_constants.dart';
import '../../models/grid_cell.dart';
import '../../game/flow_grid_game.dart';

class CarComponent extends SpriteComponent with HasGameReference<FlowGridGame> {
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
  double travelTime = 0.0; // Delivery efficiency tracking
  bool _waitingAtSignal = false;
  static const double maxWaitTime = 1.5;
  String? routeId; // For buses
  double _sirenTimer = 0; // For emergency vehicles

  // Follow-the-leader constants
  double _collisionCheckTimer = 0;
  double _lastTargetMultiplier = 1.0;
  double _currentSpeedMultiplier = 1.0;
  
  // Simulation throttling
  double _simCheckTimer = 0;
  double _congestionMultiplier = 1.0;
  double _terrainSpeed = 1.0;
  
  // Acceleration constants
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
    _sirenTimer = 0.0;

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
    _updateVehicleVisuals();
  }

  void _updateVehicleVisuals() {
    final baseSize = cellSize * 0.22;
    switch (vehicleType) {
      case VehicleType.car:
        size = Vector2(baseSize * 2.0, baseSize); // Match sprite aspect ratio
        break;
      case VehicleType.truck:
        size = Vector2(baseSize * 2.6, baseSize * 1.3);
        break;
      case VehicleType.serviceVan:
        size = Vector2(baseSize * 2.2, baseSize * 1.1);
        break;
      case VehicleType.bus:
        size = Vector2(baseSize * 3.4, baseSize * 1.5);
        break;
      case VehicleType.emergency:
        size = Vector2(baseSize * 2.2, baseSize * 1.2);
        break;
    }
    _updateSprite();
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
    _sirenTimer = 0;
    _currentSpeedMultiplier = 0.0;
    _lastTargetMultiplier = 1.0;
    
    priority = 10;
    _rebuildSmoothPath();
    _updateVehicleVisuals();
  }

  void _updateSprite() {
    if (!isMounted || game.carSpriteSheet == null) return;
    
    int spriteIndex = 0;
    switch (vehicleType) {
      case VehicleType.car:
        spriteIndex = colorIndex.clamp(0, 5);
        break;
      case VehicleType.truck:
        spriteIndex = 6;
        break;
      case VehicleType.serviceVan:
      case VehicleType.bus:
      case VehicleType.emergency:
        spriteIndex = 7;
        break;
    }
    
    sprite = game.carSpriteSheet!.getSpriteById(spriteIndex);
  }

  @override
  void onMount() {
    super.onMount();
    _updateSprite();
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

      // Check for Express Lane jump (non-adjacent tiles)
      final dx = (p1.x - p2.x).abs();
      final dy = (p1.y - p2.y).abs();
      if (dx > 1 || dy > 1) {
        // Curved express lane logic (matches ExpressLaneComponent)
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
          final cornerStart = c2 + (c1 - c2) * 0.4;
          _smoothPath.lineTo(cornerStart.dx, cornerStart.dy);

          final cornerEnd = c2 + (c3 - c2) * 0.4;
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
      position = Vector2(tangent.position.dx, tangent.position.dy);
      angle = -tangent.angle;
    }
  }

  GridPosition? get currentTarget {
    if (_currentPathIndex + 1 < path.length) {
      return path[_currentPathIndex + 1];
    }
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
    if (game.paused) { return; }

    if (arrived || path.length < 2) {
      arrived = true;
      return;
    }

    // Track delivery time
    travelTime += dt * game.timeScale;

    // Emergency siren logic
    if (vehicleType == VehicleType.emergency) {
      _sirenTimer += dt * 10;
    }

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
      // Buses wait longer at stops, others (waiting for return trip) wait maxWaitTime
      double waitLimit = (vehicleType == VehicleType.bus) ? 1.5 : maxWaitTime;
      if (_waitTimer >= waitLimit) {
        isWaiting = false;
        if (!isReturning && vehicleType != VehicleType.bus) arrived = true;
      }
      return;
    }

    if (_distanceTraveled >= _totalLength) {
      if (!isReturning && !isWaiting) {
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
      
      // 1. Traffic Signal Check
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

      // 2. Congestion Slowdown
      _congestionMultiplier = 1.0;
      if (game.gridManager != null && _currentPathIndex < path.length) {
        final curPos = path[_currentPathIndex];
        if (game.gridManager!.isRoadCongested(curPos.x, curPos.y)) {
          _congestionMultiplier = 0.5;
        }
      }
      
      // 3. Express Lane Check
      onExpressLane = false;
      _terrainSpeed = 1.0;
      if (_currentPathIndex < path.length && game.gridManager != null) {
        final curPos = path[_currentPathIndex];
        final curCell = game.gridManager!.getCell(curPos.x, curPos.y);
        _terrainSpeed = curCell.speedMultiplier;
        onExpressLane = curCell.isExpressLaneNode || _terrainSpeed >= GameConstants.expressLaneSpeed;
      }
    }

    // --- Follow-the-leader target calculation ---
    double targetMultiplier = 1.0;
    _collisionCheckTimer += dt;
    if (_collisionCheckTimer >= 0.1) {
      _collisionCheckTimer = 0;
      if (!onExpressLane && !_waitingAtSignal) {
        final myPos = position;
        final forward = Vector2(cos(angle), sin(angle));
        final minGap = cellSize * 0.7; // Increased gap slightly for smoother flow
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
      
      // [NEW] Anti-Gridlock: Don't enter intersection if exit is congested
      if (_currentPathIndex + 1 < path.length) {
        final nextPos = path[_currentPathIndex + 1];
        if (game.gridManager!.isValid(nextPos.x, nextPos.y) && 
            game.gridManager!.isRoadCongested(nextPos.x, nextPos.y)) {
           // Slow down significantly if heading into a jam
           targetMultiplier = min(targetMultiplier, 0.15);
        }
      }
    }

    // --- Apply Acceleration/Deceleration ---
    final baseTarget = targetMultiplier * _vehicleSpeedMultiplier * _terrainSpeed * _congestionMultiplier;
    
    if (_currentSpeedMultiplier < baseTarget) {
      // Accelerate
      double rate = accelerationRate;
      if (_currentSpeedMultiplier < 0.1) rate *= startupAccelerationBonus;
      _currentSpeedMultiplier = min(baseTarget, _currentSpeedMultiplier + rate * dt);
    } else if (_currentSpeedMultiplier > baseTarget) {
      // Decelerate
      _currentSpeedMultiplier = max(baseTarget, _currentSpeedMultiplier - decelerationRate * dt);
    }

    // RULE: Creep Speed
    double finalMultiplier = _currentSpeedMultiplier;
    if (!_waitingAtSignal && !arrived && !isWaiting) {
      finalMultiplier = max(0.08, _currentSpeedMultiplier); // Soft creep in traffic
    }

    _updatePosition(dt * finalMultiplier);
    
    // Update current path index
    if (_totalLength > 0) {
      _currentPathIndex = ((_distanceTraveled / _totalLength) * (path.length - 1)).floor().clamp(0, path.length - 1);
    }
    
    // Position update based on smooth path
    final tangentObj = _metric?.getTangentForOffset(_distanceTraveled);
    if (tangentObj != null) {
      position = Vector2(tangentObj.position.dx, tangentObj.position.dy);
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
}
