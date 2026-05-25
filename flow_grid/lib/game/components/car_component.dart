import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import '../../models/game_constants.dart';
import '../../models/grid_cell.dart';
import '../../game/flow_grid_game.dart';
import '../pathfinder.dart';
import '../map_generator.dart';

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
  final List<Vector2> _trailPositions = [];
  static const int _maxTrailPoints = 6;
  double _trailDecayTimer = 0.0;

  // Follow-the-leader
  double _collisionCheckTimer = 0;
  double _lastTargetMultiplier = 1.0;
  double _currentSpeedMultiplier = 1.0;
  
  // Simulation throttling
  double _simCheckTimer = 0;
  double _congestionMultiplier = 1.0;
  double _terrainSpeed = 1.0;

  // Lane offset multiplier on the perpendicular drive-on-the-right offset.
  // +1.0 = right side (default), -1.0 = left side. Smoothly interpolated
  // toward _targetLaneSign so the car visually arcs across the centerline
  // instead of teleporting when it needs to pull alongside a parked car.
  double _currentLaneSign = 1.0;
  double _targetLaneSign = 1.0;
  
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
    _trailPositions.clear();
    _trailDecayTimer = 0.0;
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
    _currentLaneSign = 1.0;
    _targetLaneSign = 1.0;

    _rebuildSmoothPath();

    if (initialProgress != null && _totalLength > 0) {
      _distanceTraveled = initialProgress * _totalLength;
      _updatePosition(0);
    } else if (path.isNotEmpty) {
      final startPos = path[0];
      double sx = offsetX + startPos.x * cellSize + cellSize / 2;
      double sy = offsetY + startPos.y * cellSize + cellSize / 2;
      if (startPos.side != null) {
        final r = cellSize * 0.4;
        switch (startPos.side!) {
          case Direction.north: sy -= r;
          case Direction.east:  sx += r;
          case Direction.south: sy += r;
          case Direction.west:  sx -= r;
        }
      }
      position = Vector2(sx, sy);
    }
    
    anchor = Anchor.center;
    priority = 10;
    _updateVehicleSize();
  }

  void _updateVehicleSize() {
    final baseSize = cellSize * 0.65;
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
    _currentLaneSign = 1.0;
    _targetLaneSign = 1.0;
    
    priority = 10;
    _rebuildSmoothPath();

    // Snap to the new path's starting cell so a reused-from-pool car doesn't
    // render at its previous trip's endpoint before the first update tick.
    if (path.isNotEmpty && _totalLength > 0) {
      final tangent = _metric?.getTangentForOffset(0);
      if (tangent != null) {
        final fwd = tangent.vector;
        final lane = cellSize * 0.13 * _currentLaneSign;
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

    // Smart-junction sub-nodes are the only path entries that share their
    // (x, y) with a path neighbor — buildings have a unique cell. Detect
    // structurally so we don't reach into the game (which throws on a
    // pooled car that hasn't reattached yet — that error then aborted the
    // path build and left the car invisible on the road).
    bool isJunctionNodeAt(int i) {
      if (path[i].side == null) return false;
      final p = path[i];
      final prevSame = i > 0 && path[i - 1].x == p.x && path[i - 1].y == p.y;
      final nextSame =
          i < path.length - 1 && path[i + 1].x == p.x && path[i + 1].y == p.y;
      return prevSame || nextSame;
    }

    Offset getPos(int i) {
      final p = path[i];
      final midX = offsetX + p.x * cellSize + cellSize / 2;
      final midY = offsetY + p.y * cellSize + cellSize / 2;
      if (p.side == null) return Offset(midX, midY);
      // Junction sub-nodes sit on the cell's outer edge so the smooth-path
      // bezier hugs the visible donut ring; building entries keep the
      // tighter 0.4 offset so the parking position lands at the door.
      final r = isJunctionNodeAt(i) ? cellSize * 0.5 : cellSize * 0.4;
      switch (p.side!) {
        case Direction.north: return Offset(midX, midY - r);
        case Direction.east:  return Offset(midX + r, midY);
        case Direction.south: return Offset(midX, midY + r);
        case Direction.west:  return Offset(midX - r, midY);
      }
    }

    // Side angle in canvas (y-down) coords: 0=east, pi/2=south, pi=west,
    // -pi/2=north. Used by the smart-junction arc.
    double sideAngle(Direction d) {
      switch (d) {
        case Direction.east: return 0;
        case Direction.south: return pi / 2;
        case Direction.west: return pi;
        case Direction.north: return -pi / 2;
      }
    }

    bool isJunctionTransitionAt(int i) {
      if (i < 0 || i >= path.length - 1) return false;
      final a = path[i];
      final b = path[i + 1];
      return a.x == b.x &&
          a.y == b.y &&
          isJunctionNodeAt(i) &&
          isJunctionNodeAt(i + 1);
    }

    bool isLongJumpAt(int i) {
      if (i < 0 || i >= path.length - 1) return false;
      final a = path[i];
      final b = path[i + 1];
      return (a.x - b.x).abs() > 1 || (a.y - b.y).abs() > 1;
    }

    final start = getPos(0);
    _smoothPath.moveTo(start.dx, start.dy);

    for (int i = 0; i < path.length - 1; i++) {
      final p1 = path[i];
      final p2 = path[i + 1];
      final c1 = getPos(i);
      final c2 = getPos(i + 1);

      // Long jump (express lane): bezier with a perpendicular arc.
      //
      // Sign of the perpendicular is chosen by a fixed rule (always the
      // half-plane with perp.dy < 0, ties broken by perp.dx < 0) instead of
      // "right of forward". That makes the bezier curve identical whether
      // the car is traveling A→B or B→A — without this, the return trip
      // arced to the opposite side of the painted lane and the car looked
      // like it was floating off in space. The painted lane in
      // _drawExpressLanesGlobal uses the same rule so the two match.
      //
      // Pen is guaranteed to be at c1 here because the previous iteration's
      // look-ahead skipped its corner-cut when this segment was about to
      // run — see the !nextSpecial branch below.
      if (isLongJumpAt(i)) {
        final delta = c2 - c1;
        final dist = delta.distance;
        final mid = (c1 + c2) / 2;
        final unitDir = delta / dist;
        final perp = Offset(-unitDir.dy, unitDir.dx);
        final perpSign = (perp.dy < 0 || (perp.dy == 0 && perp.dx < 0))
            ? 1.0
            : -1.0;
        final arcHeight = dist * 0.15 * perpSign;
        final cp = mid + perp * arcHeight;
        _smoothPath.quadraticBezierTo(cp.dx, cp.dy, c2.dx, c2.dy);
        continue;
      }

      // Sub-node → sub-node within the same smart junction: draw a true
      // circular arc along the outer ring of the donut so the car visibly
      // goes *through* the roundabout instead of cutting across the inner
      // half. Sweep is +pi/2 CW because the pathfinder always rotates in
      // the N→E→S→W→N order, which is clockwise in canvas y-down coords.
      if (isJunctionTransitionAt(i)) {
        final cx = offsetX + p1.x * cellSize + cellSize / 2;
        final cy = offsetY + p1.y * cellSize + cellSize / 2;
        final ringR = cellSize * 0.5;
        final rect = Rect.fromCircle(center: Offset(cx, cy), radius: ringR);
        final startAngle = sideAngle(p1.side!);
        const sweepAngle = pi / 2;
        _smoothPath.arcTo(rect, startAngle, sweepAngle, false);
        continue;
      }

      // Look ahead: if the next iteration's segment is a long jump or a
      // junction transition, do NOT corner-cut here. Corner-cutting drops
      // the pen at cornerEnd (between c2 and c3) which would sit halfway
      // along the express-lane bezier or off the donut ring. Instead end
      // cleanly at c2 so the next iteration's curve starts at its c1.
      final nextSpecial =
          isLongJumpAt(i + 1) || isJunctionTransitionAt(i + 1);

      if (!nextSpecial && i < path.length - 2) {
        final p3 = path[i + 2];
        final c3 = getPos(i + 2);
        bool isStraight = (p1.x == p2.x &&
                p2.x == p3.x &&
                p1.side == null &&
                p2.side == null &&
                p3.side == null) ||
            (p1.y == p2.y &&
                p2.y == p3.y &&
                p1.side == null &&
                p2.side == null &&
                p3.side == null);
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
      // _currentLaneSign flips the offset (+1 right, -1 left) so a car can
      // pull alongside a parked one in the other lane.
      final fwd = tangent.vector;
      final lane = cellSize * 0.13 * _currentLaneSign;
      position = Vector2(
        tangent.position.dx - fwd.dy * lane,
        tangent.position.dy + fwd.dx * lane,
      );
      angle = -tangent.angle;
    }
  }

  /// Sets [_targetLaneSign] to -1 when this car is about to arrive at a
  /// destination that already has a parked car, so it pulls into the other
  /// lane instead of stacking on top. Reverts to +1 (right side) otherwise.
  void _updateLaneTarget() {
    if (arrived || isReturning) {
      _targetLaneSign = 1.0;
      return;
    }
    // Only swap when approaching the final cell — within the last 3 path nodes
    // (building + driveway + last road tile). Earlier swaps look like aimless
    // weaving.
    if (path.length < 2 || _currentPathIndex < path.length - 3) {
      _targetLaneSign = 1.0;
      return;
    }
    final gWidth = game.gridWidth;
    if (gWidth <= 0) {
      _targetLaneSign = 1.0;
      return;
    }
    final destKeyX = targetDest.x;
    final destKeyY = targetDest.y;
    bool parkedAtDest = false;
    for (int dy = -1; dy <= 1 && !parkedAtDest; dy++) {
      for (int dx = -1; dx <= 1 && !parkedAtDest; dx++) {
        final bucketKey = (destKeyX + dx) + (destKeyY + dy) * gWidth;
        final bucket = game.carGrid[bucketKey];
        if (bucket == null) continue;
        for (final other in bucket) {
          if (identical(other, this) || other.arrived) continue;
          if (!other.isWaiting || other.isReturning) continue;
          if (other.targetDest.x == destKeyX && other.targetDest.y == destKeyY) {
            parkedAtDest = true;
            break;
          }
        }
      }
    }
    _targetLaneSign = parkedAtDest ? -1.0 : 1.0;
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

    // The outbound path was extended into the building cells, so path.last is
    // the destination tile itself (not passable). Pathfind from the dest
    // driveway back to the home driveway, then splice the buildings onto
    // both ends so the return trip mirrors the outbound — leave the dest
    // doorstep, drive home, park at the home doorstep, then disappear.
    final destDriveway = gm.buildingDriveways['${targetDest.x},${targetDest.y}'];
    final homeDriveway = gm.buildingDriveways['${spawnHousePos.x},${spawnHousePos.y}'];
    if (destDriveway == null || homeDriveway == null) {
      arrived = true;
      return;
    }

    final returnRoadPath = Pathfinder.findPath(gm, destDriveway, homeDriveway);
    if (returnRoadPath == null || returnRoadPath.isEmpty) {
      arrived = true;
      return;
    }

    final destEntry = gm.getCell(targetDest.x, targetDest.y).entrySide;
    final houseEntry = gm.getCell(spawnHousePos.x, spawnHousePos.y).entrySide;
    final returnPath = <GridPosition>[
      if (destEntry != null)
        GridPosition(targetDest.x, targetDest.y, destEntry)
      else
        GridPosition(targetDest.x, targetDest.y),
      ...returnRoadPath,
      if (houseEntry != null)
        GridPosition(spawnHousePos.x, spawnHousePos.y, houseEntry)
      else
        GridPosition(spawnHousePos.x, spawnHousePos.y),
    ];

    if (returnPath.length >= 2) {
      startReturnTrip(returnPath);
    } else {
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

    final isStopped = _currentSpeedMultiplier < 0.05 || _waitingAtSignal || isWaiting || arrived;
    
    // Dynamically limit max trail length as speed decreases
    final speedFactor = arrived ? 0.0 : (_currentSpeedMultiplier / 1.0).clamp(0.0, 1.0);
    final int activeMaxPoints = (isStopped || arrived) ? 0 : (_maxTrailPoints * speedFactor).round();

    if (!arrived && !isWaiting && !isStopped) {
      if (_trailPositions.isEmpty || _trailPositions.first.distanceToSquared(position) > 0.05) {
        _trailPositions.insert(0, position.clone());
      }
    }

    if (arrived || isWaiting) {
      _trailPositions.clear();
      _trailDecayTimer = 0.0;
    } else if (isStopped) {
      // Decay the trail rapidly when stopped (e.g. at traffic lights)
      _trailDecayTimer += dt;
      if (_trailDecayTimer >= 0.02) {
        _trailDecayTimer = 0.0;
        if (_trailPositions.isNotEmpty) {
          _trailPositions.removeLast();
        }
      }
    } else {
      _trailDecayTimer = 0.0;
      while (_trailPositions.length > activeMaxPoints) {
        _trailPositions.removeLast();
      }
    }

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
        double speedMult = curCell.speedMultiplier;

        if (curCell.isIceRoad) {
          speedMult *= 0.6;
        }

        if (game.selectedMapType == MapType.savanna && curCell.type == CellType.road && curCell.owner == InfrastructureOwner.player) {
          speedMult *= 0.8;
        }

        if (game.activeEvent == 'blizzard') {
          if (curCell.isIceRoad) {
            speedMult *= 0.66; // 0.6 * 0.66 ~= 0.4
          } else {
            speedMult *= 0.6;
          }
        } else if (game.activeEvent == 'dustStorm') {
          speedMult *= 0.7;
        }

        final isBlocked = game.floodedRoads.contains(curPos) || game.activeEventTiles.contains(curPos);
        if (isBlocked) {
          speedMult = 0.0;
        }

        _terrainSpeed = speedMult;
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

    // --- Lane swap when another car is parked at our destination ---
    _updateLaneTarget();
    final laneRate = dt * 2.5; // sign units per second; 0.8s for a full swap
    final laneDiff = _targetLaneSign - _currentLaneSign;
    if (laneDiff.abs() <= laneRate) {
      _currentLaneSign = _targetLaneSign;
    } else {
      _currentLaneSign += laneDiff > 0 ? laneRate : -laneRate;
    }

    // --- Acceleration/Deceleration ---
    final baseTarget = targetMultiplier * _vehicleSpeedMultiplier * _terrainSpeed * _congestionMultiplier;
    if (_currentSpeedMultiplier < baseTarget) {
      double rate = accelerationRate;
      if (_currentSpeedMultiplier < 0.1) rate *= startupAccelerationBonus;
      if (game.activeEvent == 'dustStorm') {
        rate *= 0.3; // Much slower acceleration in thick dust
      }
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

    // 1. Draw trailing paths in local space (before saving/translating/rotating canvas)
    final baseColor = GameConstants.getBuildingColor(colorIndex);
    if (_trailPositions.length >= 2) {
      final trailPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final cosA = cos(-angle);
      final sinA = sin(-angle);
      final halfSizeX = size.x / 2;
      final halfSizeY = size.y / 2;

      for (int i = 0; i < _trailPositions.length - 1; i++) {
        final p1 = _trailPositions[i];
        final p2 = _trailPositions[i + 1];

        final dx1 = p1.x - position.x;
        final dy1 = p1.y - position.y;
        final rx1 = dx1 * cosA - dy1 * sinA;
        final ry1 = dx1 * sinA + dy1 * cosA;
        final o1 = Offset(rx1 + halfSizeX, ry1 + halfSizeY);

        final dx2 = p2.x - position.x;
        final dy2 = p2.y - position.y;
        final rx2 = dx2 * cosA - dy2 * sinA;
        final ry2 = dx2 * sinA + dy2 * cosA;
        final o2 = Offset(rx2 + halfSizeX, ry2 + halfSizeY);

        final ratio = i / _trailPositions.length;
        final opacity = (1.0 - ratio) * 0.45;
        final width = size.x * 0.45 * (1.0 - ratio * 0.7);

        trailPaint.color = baseColor.withValues(alpha: opacity);
        trailPaint.strokeWidth = width;

        canvas.drawLine(o1, o2, trailPaint);
      }
    }

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

    // 2. [Removed shadow to avoid black highlight]

    // 3. Draw vehicle sprite
    sprite.render(
      canvas,
      position: Vector2(-width / 2, -length / 2),
      size: Vector2(width, length),
    );

    canvas.restore();
  }
}
