import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import '../../models/game_constants.dart';
import '../../models/grid_cell.dart';
import '../../models/road_occupancy.dart';
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
  List<double> segmentStartOffsets = [];
  
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
  static const int _maxTrailPoints = 2;
  double _trailDecayTimer = 0.0;

  // Follow-the-leader
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
  double _intersectionWaitingTimer = 0.0;
  late final double _deadlockBreakTimeout = 3.0 + Random().nextDouble() * 1.5;
  
  // Roundabout dynamic lane tracking
  bool? _roundaboutInnerLane;
  bool get isRoundaboutInner => _roundaboutInnerLane ?? (hashCode % 2 == 0);
  
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

  @override
  String toString() {
    final hexId = hashCode.toRadixString(16).padLeft(4, '0');
    final shortId = hexId.length > 4 ? hexId.substring(hexId.length - 4) : hexId;
    return 'Car#$shortId[col:$colorIndex]';
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

  @override
  void onMount() {
    super.onMount();
    _registerOccupancy();
  }

  @override
  void onRemove() {
    _unregisterOccupancy();
    super.onRemove();
  }

  void _registerOccupancy() {
    if (path.isEmpty || _currentPathIndex >= path.length) return;
    final pos = path[_currentPathIndex];
    final cell = game.gridManager?.getCell(pos.x, pos.y);
    if (cell != null && cell.isPassable) {
      final RoadOccupancy occupancy = game.getOrCreateOccupancy(pos);
      if (!occupancy.cars.contains(this)) {
        occupancy.cars.add(this);
        debugPrint("[ROAD_OCCUPY] Car $this entered (${pos.x}, ${pos.y})");
      }
      occupancy.clearReservation(this);
      occupancy.waitingCars.remove(this);
      
      final cellType = cell.type;
      final connType = cell.connectionType;
      final isJunction = cellType == CellType.smartJunction || 
                         cellType == CellType.trafficLight;
      final isIntersection = connType == ConnectionNodeType.intersection || isJunction;
      
      if (isIntersection) {
        if (!isReturning) {
          occupancy.consecutiveOutbound++;
          occupancy.consecutiveReturning = 0;
          occupancy.lastPassedWasOutbound = true;
        } else {
          occupancy.consecutiveReturning++;
          occupancy.consecutiveOutbound = 0;
          occupancy.lastPassedWasOutbound = false;
        }

        if (!occupancy.activeIntersectionCars.contains(this)) {
          occupancy.activeIntersectionCars.add(this);
          
          if (_currentPathIndex + 1 < path.length) {
            final nextPos = path[_currentPathIndex + 1];
            Direction? moveDir;
            if (nextPos.x > pos.x) {
              moveDir = Direction.east;
            } else if (nextPos.x < pos.x) {
              moveDir = Direction.west;
            } else if (nextPos.y > pos.y) {
              moveDir = Direction.south;
            } else if (nextPos.y < pos.y) {
              moveDir = Direction.north;
            }
            
            if (moveDir != null) {
              final axis = (moveDir == Direction.east || moveDir == Direction.west)
                  ? InfrastructureAxis.horizontal
                  : InfrastructureAxis.vertical;
              occupancy.reservedAxis = axis;
            }
          }
        }
      }
    }
  }

  void _unregisterOccupancy() {
    if (path.isNotEmpty && _currentPathIndex < path.length) {
      final pos = path[_currentPathIndex];
      final RoadOccupancy occupancy = game.getOrCreateOccupancy(pos);
      occupancy.cars.remove(this);
      occupancy.waitingCars.remove(this);
      debugPrint("[ROAD_RELEASE] Car $this left (${pos.x}, ${pos.y})");
      
      occupancy.activeIntersectionCars.remove(this);
      if (occupancy.activeIntersectionCars.isEmpty) {
        occupancy.reservedAxis = null;
        debugPrint("[INTERSECTION_RELEASE] Intersection (${pos.x}, ${pos.y}) released");
      }
      
      occupancy.clearReservation(this);
    }
    
    if (path.isNotEmpty && _currentPathIndex + 1 < path.length) {
      final nextPos = path[_currentPathIndex + 1];
      final RoadOccupancy nextOccupancy = game.getOrCreateOccupancy(nextPos);
      nextOccupancy.waitingCars.remove(this);
      nextOccupancy.clearReservation(this);
    }
  }

  InfrastructureAxis _getMoveAxis(GridPosition cur, GridPosition next) {
    if (next.x != cur.x) {
      return InfrastructureAxis.horizontal;
    } else {
      return InfrastructureAxis.vertical;
    }
  }

  void _updateVehicleSize() {
    final baseSize = cellSize * 0.58;
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
    _roundaboutInnerLane = null;
    _intersectionWaitingTimer = 0.0;
    
    priority = 10;
    _rebuildSmoothPath();

    // Snap to the new path's starting cell so a reused-from-pool car doesn't
    // render at its previous trip's endpoint before the first update tick.
    if (path.isNotEmpty && _totalLength > 0) {
      final tangent = _metric?.getTangentForOffset(0);
      if (tangent != null) {
        final fwd = tangent.vector;
        final lane = cellSize * 0.22 * _currentLaneSign;
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

    // Strip consecutive duplicate non-roundabout nodes (same x,y, same side)
    // These arise when recalculatePath splices a new subpath at a shared
    // boundary cell, and cause a car to reserve its own current cell.
    {
      final deduped = <GridPosition>[];
      for (final node in path) {
        if (deduped.isNotEmpty) {
          final prev = deduped.last;
          // Skip if same grid cell AND neither is a roundabout sub-node
          if (prev.x == node.x && prev.y == node.y && prev.side == node.side) {
            continue;
          }
        }
        deduped.add(node);
      }
      if (deduped.length != path.length) {
        path = deduped;
      }
    }

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
      // Junction sub-nodes sit on the enlarged hub ring so the smooth-path
      // bezier matches the wider visible donut; building entries keep the
      // tighter 0.4 offset so the parking position lands at the door.
      final r = isJunctionNodeAt(i) ? cellSize * 0.75 : cellSize * 0.4;
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
        case Direction.east: return 0.0;
        case Direction.south: return pi / 2;
        case Direction.west: return pi;
        case Direction.north: return 1.5 * pi;
      }
    }

    double normalizeAngle(double angle) {
      double a = angle % (2 * pi);
      if (a < 0) a += 2 * pi;
      return a;
    }

    Offset getJunctionControlPoint(double cx, double cy, Direction d, double cpDist) {
      switch (d) {
        case Direction.east:  return Offset(cx + cpDist, cy);
        case Direction.south: return Offset(cx, cy + cpDist);
        case Direction.west:  return Offset(cx - cpDist, cy);
        case Direction.north: return Offset(cx, cy - cpDist);
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

    segmentStartOffsets = List.filled(path.length, 0.0);
    Offset currentPenPos = start;
    double accum = 0.0;

    for (int i = 0; i < path.length - 1; i++) {
      final p1 = path[i];
      final p2 = path[i + 1];
      final c1 = getPos(i);
      final c2 = getPos(i + 1);

      final segPath = ui.Path();
      segPath.moveTo(currentPenPos.dx, currentPenPos.dy);

      // Long jump (express lane): bezier with a perpendicular arc.
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
        segPath.quadraticBezierTo(cp.dx, cp.dy, c2.dx, c2.dy);
        currentPenPos = c2;
      }
      // Sub-node → sub-node within the same smart junction: draw a true
      // circular arc along the outer ring of the donut.
      else if (isJunctionTransitionAt(i)) {
        final cx = offsetX + p1.x * cellSize + cellSize / 2;
        final cy = offsetY + p1.y * cellSize + cellSize / 2;
        final ringR = cellSize * 0.75;
        final rect = Rect.fromCircle(center: Offset(cx, cy), radius: ringR);
        
        final bool prevIsEntry = i > 0 && (path[i - 1].side == null && path[i].side != null);
        final bool nextIsExit = i + 1 < path.length - 1 && (path[i + 1].side != null && path[i + 2].side == null);
        
        const alpha = pi / 6;
        final startAngle = sideAngle(p1.side!) + (prevIsEntry ? alpha : 0.0);
        final endAngle = sideAngle(p2.side!) - (nextIsExit ? alpha : 0.0);
        
        final sweepAngle = normalizeAngle(endAngle - startAngle);
        _smoothPath.arcTo(rect, startAngle, sweepAngle, false);
        segPath.arcTo(rect, startAngle, sweepAngle, false);
        currentPenPos = Offset(cx + ringR * cos(endAngle), cy + ringR * sin(endAngle));
      }
      // Entry transition for smart junctions
      else if (p1.side == null && p2.side != null) {
        final cx = offsetX + p2.x * cellSize + cellSize / 2;
        final cy = offsetY + p2.y * cellSize + cellSize / 2;
        final r = cellSize * 0.75;
        const alpha = pi / 6;
        
        final startPoint = c2 + (c1 - c2) * 0.5;
        final targetAngle = sideAngle(p2.side!) + alpha;
        final endPoint = Offset(cx + r * cos(targetAngle), cy + r * sin(targetAngle));
        
        final cpDist = r / cos(alpha);
        final cp = getJunctionControlPoint(cx, cy, p2.side!, cpDist);
        
        _smoothPath.lineTo(startPoint.dx, startPoint.dy);
        _smoothPath.quadraticBezierTo(cp.dx, cp.dy, endPoint.dx, endPoint.dy);
        
        segPath.lineTo(startPoint.dx, startPoint.dy);
        segPath.quadraticBezierTo(cp.dx, cp.dy, endPoint.dx, endPoint.dy);
        currentPenPos = endPoint;
      }
      // Exit transition for smart junctions
      else if (p1.side != null && p2.side == null) {
        final cx = offsetX + p1.x * cellSize + cellSize / 2;
        final cy = offsetY + p1.y * cellSize + cellSize / 2;
        final r = cellSize * 0.75;
        const alpha = pi / 6;
        
        final endPoint = c1 + (c2 - c1) * 0.5;
        
        final cpDist = r / cos(alpha);
        final cp = getJunctionControlPoint(cx, cy, p1.side!, cpDist);
        
        _smoothPath.quadraticBezierTo(cp.dx, cp.dy, endPoint.dx, endPoint.dy);
        
        segPath.quadraticBezierTo(cp.dx, cp.dy, endPoint.dx, endPoint.dy);
        currentPenPos = endPoint;
      }
      // Normal roads and intersections
      else {
        final nextSpecial = isLongJumpAt(i + 1) || isJunctionTransitionAt(i + 1);
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
            final cornerStart = c2 + (c1 - c2) * 0.5;
            _smoothPath.lineTo(cornerStart.dx, cornerStart.dy);
            segPath.lineTo(cornerStart.dx, cornerStart.dy);
            final cornerEnd = c2 + (c3 - c2) * 0.5;
            _smoothPath.quadraticBezierTo(c2.dx, c2.dy, cornerEnd.dx, cornerEnd.dy);
            segPath.quadraticBezierTo(c2.dx, c2.dy, cornerEnd.dx, cornerEnd.dy);
            currentPenPos = cornerEnd;
          } else {
            _smoothPath.lineTo(c2.dx, c2.dy);
            segPath.lineTo(c2.dx, c2.dy);
            currentPenPos = c2;
          }
        } else {
          _smoothPath.lineTo(c2.dx, c2.dy);
          segPath.lineTo(c2.dx, c2.dy);
          currentPenPos = c2;
        }
      }

      final segMetrics = segPath.computeMetrics().toList();
      final segLength = segMetrics.isNotEmpty ? segMetrics.first.length : 0.0;
      accum += segLength;
      segmentStartOffsets[i + 1] = accum;
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
    
    // Stage 6: Curve / Turn Speeds
    final tangent = _metric!.getTangentForOffset(_distanceTraveled);
    double curveSpeedMultiplier = 1.0;
    if (tangent != null) {
      final nextOffset = min(_totalLength, _distanceTraveled + cellSize * 0.5);
      final nextTangent = _metric!.getTangentForOffset(nextOffset);
      if (nextTangent != null) {
        double turnAngleDiff = (nextTangent.angle - tangent.angle).abs();
        if (turnAngleDiff > pi) {
          turnAngleDiff = 2 * pi - turnAngleDiff;
        }
        curveSpeedMultiplier = 1.0 - (turnAngleDiff / (pi / 2) * 0.35).clamp(0.0, 0.35);
      }
    }

    // Rule 7: Curve Speed Reduction inside roundabout (~80% speed)
    double roundaboutSpeedMultiplier = 1.0;
    if (_currentPathIndex < path.length && path[_currentPathIndex].side != null) {
      roundaboutSpeedMultiplier = 0.80;
    }

    _distanceTraveled += dt * speed * game.timeScale * curveSpeedMultiplier * roundaboutSpeedMultiplier;
    if (_distanceTraveled >= _totalLength) {
      _distanceTraveled = _totalLength;
    }
    
    final finalTangent = _metric!.getTangentForOffset(_distanceTraveled);
    if (finalTangent != null) {
      // Drive on the right side of the road centerline. Right-perpendicular
      // in screen coords (y-down) of forward (fx, fy) is (-fy, fx). Two cars
      // going opposite directions land on opposite sides — no more overlap.
      // _currentLaneSign flips the offset (+1 right, -1 left) so a car can
      // pull alongside a parked one in the other lane.
      final fwd = finalTangent.vector;
      final lane = cellSize * 0.22 * _currentLaneSign;

      position = Vector2(
        finalTangent.position.dx - fwd.dy * lane,
        finalTangent.position.dy + fwd.dx * lane,
      );
      angle = -finalTangent.angle;
    }
  }

  /// Sets [_targetLaneSign] to -1 when this car is about to arrive at a
  /// destination that already has a parked car, so it pulls into the other
  /// lane instead of stacking on top. Reverts to +1 (right side) otherwise.
  void _updateLaneTarget() {
    // --- Roundabout/Smart Junction Lane Alignment ---
    bool nearJunction = false;
    if (_currentPathIndex < path.length) {
      if (path[_currentPathIndex].side != null) {
        nearJunction = true;
      } else if (_currentPathIndex + 1 < path.length && path[_currentPathIndex + 1].side != null) {
        nearJunction = true;
      }
    }
    
    if (nearJunction) {
      // Rule 8: Dual-lane illusion — each car is dynamically or deterministically assigned to the
      // inner or outer orbital lane. On a clockwise circle the right-perpendicular points inward,
      // so +0.85 → inner lane, −0.85 → outer.
      _targetLaneSign = isRoundaboutInner ? 0.85 : -0.85;
      return;
    }

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

  int _calculatePathIndex(double distance) {
    if (segmentStartOffsets.isEmpty) return 0;
    int newIndex = 0;
    for (int i = 0; i < segmentStartOffsets.length - 1; i++) {
      if (distance <= segmentStartOffsets[i + 1]) {
        newIndex = i;
        break;
      }
      newIndex = i + 1;
    }
    return newIndex.clamp(0, path.length - 1);
  }

  Set<GridPosition> get occupiedTiles {
    if (arrived) return {};
    return path.skip(_currentPathIndex).toSet();
  }

  void startReturnTrip(List<GridPosition> newPath) {
    _unregisterOccupancy();
    path = newPath;
    _currentPathIndex = 0;
    _distanceTraveled = 0.0;
    arrived = false;
    isReturning = true;
    _rebuildSmoothPath();
    _registerOccupancy();
  }

  void recalculatePath() {
    if (arrived || path.length < 2 || _currentPathIndex + 1 >= path.length) return;

    // Rule 9: Commit to chosen exit once inside roundabout, do not reroute.
    if (path[_currentPathIndex].side != null) {
      return;
    }

    final gm = game.gridManager;
    if (gm == null) return;

    final nextNode = path[_currentPathIndex + 1];
    final endNode = path[path.length - 2];

    // Find new road path from nextNode to endNode
    List<GridPosition>? newSubPath = Pathfinder.findPath(gm, nextNode, endNode);
    bool shouldReturnHome = false;

    if (newSubPath == null || newSubPath.isEmpty) {
      if (!isReturning) {
        // Try to pathfind back to home driveway
        final homeDriveway = gm.buildingDriveways['${spawnHousePos.x},${spawnHousePos.y}'];
        if (homeDriveway != null) {
          newSubPath = Pathfinder.findPath(gm, nextNode, homeDriveway);
          if (newSubPath != null && newSubPath.isNotEmpty) {
            shouldReturnHome = true;
          }
        }
      }
    }

    if (newSubPath == null || newSubPath.isEmpty) {
      // Completely stranded
      _unregisterOccupancy();
      arrived = true;
      return;
    }

    // Unregister old occupancy
    _unregisterOccupancy();

    // Construct new path
    final prefix = path.sublist(0, _currentPathIndex + 1);
    
    if (shouldReturnHome) {
      isReturning = true;
      final houseEntry = gm.getCell(spawnHousePos.x, spawnHousePos.y).entrySide;
      path = [
        ...prefix,
        ...newSubPath,
        if (houseEntry != null)
          GridPosition(spawnHousePos.x, spawnHousePos.y, houseEntry)
        else
          GridPosition(spawnHousePos.x, spawnHousePos.y),
      ];
    } else {
      path = [
        ...prefix,
        ...newSubPath,
        path.last,
      ];
    }

    // Rebuild smooth path
    _rebuildSmoothPath();

    // Find the distance along the new path that is closest to the current position
    double bestDistance = _distanceTraveled;
    double minDistanceSq = double.infinity;
    
    if (_totalLength > 0 && _metric != null) {
      final startScan = max(0.0, _distanceTraveled - cellSize * 2.0);
      final endScan = min(_totalLength, _distanceTraveled + cellSize * 2.0);
      final step = cellSize * 0.05;
      for (double d = startScan; d <= endScan; d += step) {
        final tangent = _metric!.getTangentForOffset(d);
        if (tangent != null) {
          final fwd = tangent.vector;
          final lane = cellSize * 0.22 * _currentLaneSign;
          final px = tangent.position.dx - fwd.dy * lane;
          final py = tangent.position.dy + fwd.dx * lane;
          
          final dx = px - position.x;
          final dy = py - position.y;
          final distSq = dx * dx + dy * dy;
          if (distSq < minDistanceSq) {
            minDistanceSq = distSq;
            bestDistance = d;
          }
        }
      }
    }
    _distanceTraveled = bestDistance;

    // Update path index and register occupancy
    _currentPathIndex = _calculatePathIndex(_distanceTraveled);
    _registerOccupancy();
  }

  void _onArrivedAtDestination() {
    if (vehicleType == VehicleType.emergency) {
      if (routeId != null) {
        game.emergencyManager.resolveEvent(routeId!);
      }
      arrived = true;
      return;
    }

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
    if (game.paused || game.timeScale == 0.0) return;

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

    // --- Follow-the-leader, Road Occupancy, and Reservations ---
    double targetMultiplier = 1.0;
    bool hasReservation = true;
    bool exitBlocked = false;

    if (!onExpressLane && !_waitingAtSignal) {
      final myIdx = _currentPathIndex.clamp(0, path.length - 1);
      final myNode = path[myIdx];
      
      // 1. Check occupancy & reservations for the next cell
      if (myIdx + 1 < path.length) {
        final nextNode = path[myIdx + 1];
        
        // Guard: skip if nextNode is the same grid cell as myNode (degenerate path).
        // This prevents self-reservation deadlocks. The path dedup in _rebuildSmoothPath
        // should handle this, but belt-and-suspenders here for safety.
        if (nextNode.x == myNode.x && nextNode.y == myNode.y && nextNode.side == myNode.side) {
          // Skip to outer block — no reservation needed, the car will advance naturally.
        } else {
        final cell = game.gridManager?.getCell(nextNode.x, nextNode.y);
        
        if (cell != null && cell.isPassable) {
          final occupancy = game.getOrCreateOccupancy(nextNode);
          
          final isRoundaboutNode = myNode.side != null || nextNode.side != null;

          if (isRoundaboutNode) {
            // ==========================================================
            // DEDICATED ROUNDABOUT CONTROLLER SYSTEM (Rules 1, 2, 3, 4, 5, 6, 10)
            // ==========================================================
            final progressToNext = (myIdx + 1 < segmentStartOffsets.length)
                ? segmentStartOffsets[myIdx + 1] - _distanceTraveled
                : _totalLength - _distanceTraveled;
            final stopTriggerDist = cellSize * 0.85;

            // Role A: Entering Roundabout
            if (myNode.side == null && nextNode.side != null) {
              if (_roundaboutInnerLane == null) {
                // Dynamic Lane Selection: Choose the lane with fewer cars/reservations in the entry node
                final innerReserved = occupancy.reservedByInner != null;
                final outerReserved = occupancy.reservedByOuter != null;
                
                int innerCars = occupancy.cars.where((c) => c.isRoundaboutInner).length;
                int outerCars = occupancy.cars.where((c) => !c.isRoundaboutInner).length;
                
                if (innerReserved && !outerReserved) {
                  _roundaboutInnerLane = false;
                } else if (!innerReserved && outerReserved) {
                  _roundaboutInnerLane = true;
                } else {
                  if (innerCars < outerCars) {
                    _roundaboutInnerLane = true;
                  } else if (outerCars < innerCars) {
                    _roundaboutInnerLane = false;
                  } else {
                    _roundaboutInnerLane = (hashCode % 2 == 0);
                  }
                }
                debugPrint("[ROUNDABOUT_LANE_CHOOSE] Car $this selected lane: ${_roundaboutInnerLane! ? 'INNER' : 'OUTER'}");
              }

              final alreadyReserved = occupancy.isReservedBy(this, true);
              if (alreadyReserved) {
                hasReservation = true;
              } else {
                bool roundaboutEntryAllowed = true;
                
                // 1. Check Entry Occupancy
                bool entryOccupied = occupancy.isReservedBySameLane(this, true);
                if (!entryOccupied) {
                  for (final c in occupancy.cars) {
                    if (c.isRoundaboutInner == isRoundaboutInner) {
                      entryOccupied = true;
                      break;
                    }
                  }
                }
                if (entryOccupied) {
                  roundaboutEntryAllowed = false;
                  debugPrint("[ROUNDABOUT_BLOCKED] Car $this blocked at entry (${nextNode.x}, ${nextNode.y}) because same-lane entry segment is occupied/reserved.");
                }

                 // 2. Check 1st Upstream Segment (Yield) — yield to continuing same-lane cars inside roundabout
                if (roundaboutEntryAllowed) {
                  final yieldDir = _getRoundaboutYieldDirection(nextNode.side!);
                  final sidePos = GridPosition(nextNode.x, nextNode.y, yieldDir);
                  final sideOcc = game.getOrCreateOccupancy(sidePos);
                  bool hasSameLaneCar = false;
                  for (final c in sideOcc.cars) {
                    final cNextNode = c._currentPathIndex + 1 < c.path.length ? c.path[c._currentPathIndex + 1] : null;
                    final cIsContinuing = cNextNode != null && cNextNode.side != null;
                    if (cIsContinuing && c.isRoundaboutInner == isRoundaboutInner) {
                      hasSameLaneCar = true;
                      break;
                    }
                  }
                  if (hasSameLaneCar) {
                    roundaboutEntryAllowed = false;
                    debugPrint("[ROUNDABOUT_YIELD] Car $this yielding to same-lane car inside roundabout at segment (${sidePos.x}, ${sidePos.y}, ${sidePos.side!.name})");
                  }
                }

                // 3. Entry Spacing Cooldown (Rule 6)
                if (roundaboutEntryAllowed) {
                  final gameTime = game.elapsedTime;
                  final isInner = isRoundaboutInner;
                  final lastEntry = isInner ? occupancy.lastEntryTimeInner : occupancy.lastEntryTimeOuter;
                  if (gameTime - lastEntry < 0.3) {
                    roundaboutEntryAllowed = false;
                    debugPrint("[ROUNDABOUT_BLOCKED] Car $this entry spacing cooldown active on (${nextNode.x}, ${nextNode.y})");
                  }
                }

                if (roundaboutEntryAllowed) {
                  occupancy.setReservation(this, true);
                  hasReservation = true;
                  final isInner = isRoundaboutInner;
                  if (isInner) {
                    occupancy.lastEntryTimeInner = game.elapsedTime;
                  } else {
                    occupancy.lastEntryTimeOuter = game.elapsedTime;
                  }
                } else {
                  hasReservation = false;
                  occupancy.clearReservation(this); // Cleanly release reservation if blocked
                  _roundaboutInnerLane = null;       // Reset lane choice so we can try the other lane next frame
                  if (progressToNext < stopTriggerDist) {
                    final mult = (progressToNext / stopTriggerDist).clamp(0.0, 1.0);
                    if (mult < targetMultiplier) {
                      targetMultiplier = mult;
                    }
                  }
                }
              }
            }
            // Role C: Exiting Roundabout
            else if (myNode.side != null && nextNode.side == null) {
              // Rule 5: Exit Reservation - ensure exit road has space.
              bool exitAllowed = true;
              final sameDirectionCars = occupancy.cars.where((c) => !_isOncomingCar(c)).length;
              if (sameDirectionCars >= occupancy.maxCars && !occupancy.isReservedBy(this, false)) {
                exitAllowed = false;
              }

              if (!exitAllowed) {
                // If exit is blocked, we slow down inside the roundabout using standard safe distance,
                // rather than inserting clockwise nodes which bloats paths and causes mutual locks.
                hasReservation = false;
                if (progressToNext < stopTriggerDist) {
                  final mult = (progressToNext / stopTriggerDist).clamp(0.0, 1.0);
                  if (mult < targetMultiplier) {
                    targetMultiplier = mult;
                  }
                }
                debugPrint("[ROUNDABOUT_EXIT_WAIT] Car $this exit to (${nextNode.x}, ${nextNode.y}) is blocked; waiting inside.");
              } else {
                // Exit is clear, proceed to reserve exit road
                occupancy.setReservation(this, false);
                hasReservation = true;
              }
            }
            // Role B: Circulating Inside Roundabout
            else {
              // Circulating cars DO NOT need segment reservations!
              hasReservation = true;
              _intersectionWaitingTimer = 0.0;
            }

            // [NEW] Roundabout Deadlock Breaker for blocked Entry (Role A) or Exit (Role C)
            if (!hasReservation) {
              final oldTime = _intersectionWaitingTimer;
              _intersectionWaitingTimer += dt;
              if ((_intersectionWaitingTimer * 2).floor() > (oldTime * 2).floor()) {
                debugPrint("[ROUNDABOUT_WAIT] Car $this waiting at (${nextNode.x}, ${nextNode.y}) - ${_intersectionWaitingTimer.toStringAsFixed(1)}s");
              }

              if (_intersectionWaitingTimer > _deadlockBreakTimeout) {
                final isRoundaboutEntryOrCirc = (nextNode.side != null);
                occupancy.setReservation(this, isRoundaboutEntryOrCirc);
                hasReservation = true;
                _intersectionWaitingTimer = 0.0;
                debugPrint("[ROUNDABOUT_DEADLOCK_BREAK] Car $this broke deadlock at (${nextNode.x}, ${nextNode.y})");
              }
            } else {
              _intersectionWaitingTimer = 0.0;
            }
          } else {
            // ==========================================================
            // STANDARD INTERSECTION / ROAD CONTROLLER
            // ==========================================================
            final isJunction = cell.type == CellType.smartJunction || 
                               cell.type == CellType.trafficLight;
            final isIntersection = cell.connectionType == ConnectionNodeType.intersection || isJunction;
            final isTunnel = cell.isTunnel;
            
            // "Don't Block the Box" (Stage Exit Clear Logic)
            if (myIdx + 2 < path.length) {
              if (isIntersection || isTunnel) {
                final nodeAfterNext = path[myIdx + 2];
                final cellAfter = game.gridManager?.getCell(nodeAfterNext.x, nodeAfterNext.y);
                if (cellAfter != null && cellAfter.isPassable) {
                  final occupancyAfter = game.getOrCreateOccupancy(nodeAfterNext);
                  final sameDirectionCars = occupancyAfter.cars.where((c) => !_isOncomingCar(c)).length;
                  if (sameDirectionCars >= occupancyAfter.maxCars && 
                      !occupancyAfter.isReservedBy(this, false)) {
                    exitBlocked = true;
                  }
                }
              }
            }
            
            final needsReservation = isIntersection || isTunnel;
            
            if (needsReservation) {
              hasReservation = occupancy.isReservedBy(this, false);
            } else {
              hasReservation = true; // Regular roads do not need cell reservations!
            }
            
            final isStandardIntersection = cell.connectionType == ConnectionNodeType.intersection ||
                                           cell.type == CellType.trafficLight;
                                           
            final cellEndProgress = (myIdx + 1 < segmentStartOffsets.length)
                ? segmentStartOffsets[myIdx + 1]
                : _totalLength;
            final progressToNext = cellEndProgress - _distanceTraveled;
            final stopTriggerDist = cellSize * 0.85;

            if (isStandardIntersection && progressToNext < stopTriggerDist) {
              if (!occupancy.waitingCars.contains(this)) {
                occupancy.waitingCars.add(this);
              }
            }

            if (needsReservation && !hasReservation && !exitBlocked) {
              // Check axis allowance if standard intersection
              bool axisAllowed = true;
              if (isStandardIntersection && occupancy.reservedAxis != null) {
                final myAxis = _getMoveAxis(myNode, nextNode);
                axisAllowed = occupancy.reservedAxis == myAxis;
              }
              
              // Check priority rules if standard intersection
              bool hasPriority = true;
              if (isStandardIntersection) {
                final competitors = occupancy.waitingCars.where((c) => c != this).toList();
                if (competitors.isNotEmpty) {
                  final hasOutboundCompetitor = competitors.any((c) => !c.isReturning);
                  final hasReturningCompetitor = competitors.any((c) => c.isReturning);
                  if (!isReturning) {
                    if (occupancy.consecutiveOutbound >= 2 && hasReturningCompetitor) {
                      hasPriority = false;
                    }
                  } else {
                    if (hasOutboundCompetitor && occupancy.consecutiveOutbound < 2) {
                      hasPriority = false;
                    }
                  }
                }
              }
              
              bool canReserve = !occupancy.isReservedBySameLane(this, false);
              
              if (axisAllowed && hasPriority && canReserve && occupancy.cars.length < occupancy.maxCars) {
                occupancy.setReservation(this, false);
                hasReservation = true;
                debugPrint("[ROAD_OCCUPY] Car $this reserved (${nextNode.x}, ${nextNode.y})");
                
                if (isStandardIntersection) {
                  occupancy.reservedAxis = _getMoveAxis(myNode, nextNode);
                  debugPrint("[INTERSECTION_RESERVED] Intersection (${nextNode.x}, ${nextNode.y}) reserved for axis ${occupancy.reservedAxis}");
                }
              }
            }
            
            if (!hasReservation || exitBlocked) {
              if (progressToNext < stopTriggerDist) {
                final mult = (progressToNext / stopTriggerDist).clamp(0.0, 1.0);
                if (mult < targetMultiplier) {
                  targetMultiplier = mult;
                }
                
                final isJunctionOrIntersection = cell.connectionType == ConnectionNodeType.intersection ||
                                                 cell.type == CellType.trafficLight ||
                                                 cell.type == CellType.smartJunction;
                if (isJunctionOrIntersection && !hasReservation) {
                  final oldTime = _intersectionWaitingTimer;
                  _intersectionWaitingTimer += dt;
                  
                  // Print only when crossing 0.5s intervals to avoid flooding the console
                  if ((_intersectionWaitingTimer * 2).floor() > (oldTime * 2).floor()) {
                    debugPrint("[INTERSECTION_WAIT] Car $this waiting at (${nextNode.x}, ${nextNode.y}) - ${_intersectionWaitingTimer.toStringAsFixed(1)}s");
                  }
                  
                  if (_intersectionWaitingTimer > _deadlockBreakTimeout) {
                    occupancy.setReservation(this, nextNode.side != null);
                    if (cell.connectionType == ConnectionNodeType.intersection || cell.type == CellType.trafficLight) {
                      occupancy.reservedAxis = _getMoveAxis(myNode, nextNode);
                    }
                    _intersectionWaitingTimer = 0.0;
                    debugPrint("[DEADLOCK_BREAK] Car $this broke deadlock at (${nextNode.x}, ${nextNode.y})");
                  }
                }
              }
            } else {
              _intersectionWaitingTimer = 0.0;
            }
          }
        }
        } // end of guard block for non-self nextNode
      }
      
      // 2. Safe Follow Distance Checking (from occupancy maps)
      final List<CarComponent> potentialObstacles = [];
      
      final List<GridPosition> searchNodes = [myNode];
      if (myIdx + 1 < path.length) {
        searchNodes.add(path[myIdx + 1]);
        // Roundabout lookahead optimization: if inside a roundabout, look ahead 2 nodes
        // to detect vehicles early and completely eliminate overlaps at high density.
        if (myNode.side != null && myIdx + 2 < path.length) {
          searchNodes.add(path[myIdx + 2]);
        }
      }

      final Set<GridPosition> queried = {};
      for (final node in searchNodes) {
        if (!queried.add(node)) continue;
        final curOccupancy = game.getOrCreateOccupancy(node);
        potentialObstacles.addAll(curOccupancy.cars);
        
        if (node.side != null) {
          // It's a roundabout sub-node. Add all other sub-nodes of the same roundabout
          for (final dir in Direction.values) {
            if (dir != node.side) {
              final otherSubNode = GridPosition(node.x, node.y, dir);
              if (queried.add(otherSubNode)) {
                final otherOccupancy = game.getOrCreateOccupancy(otherSubNode);
                potentialObstacles.addAll(otherOccupancy.cars);
              }
            }
          }
        }
      }
      final myPos = position;
      
      for (final other in potentialObstacles) {
        if (identical(other, this) || other.onExpressLane || other.arrived) continue;

        // Oncoming check: if the other car is moving in the opposite direction along our path, ignore it
        bool isOncoming = false;
        if (other._currentPathIndex + 1 < other.path.length) {
          final otherNext = other.path[other._currentPathIndex + 1];
          for (int i = 0; i <= _currentPathIndex; i++) {
            final p = path[i];
            if (p.x == otherNext.x && p.y == otherNext.y && p.side == otherNext.side) {
              isOncoming = true;
              break;
            }
          }
        }
        if (isOncoming) continue;
        
        final otherIdx = other._currentPathIndex.clamp(0, other.path.length - 1);
        final otherNode = other.path[otherIdx];
        final bothInRoundabout = myNode.side != null && otherNode.side != null;
        
        final myNextNode = myIdx + 1 < path.length ? path[myIdx + 1] : null;
        final myInOrNearRoundabout = myNode.side != null || (myNextNode != null && myNextNode.side != null);
        final otherNextNode = other._currentPathIndex + 1 < other.path.length ? other.path[other._currentPathIndex + 1] : null;
        final otherInOrNearRoundabout = otherNode.side != null || (otherNextNode != null && otherNextNode.side != null);

        final myIsExiting = myNode.side != null && (myNextNode == null || myNextNode.side == null);
        final otherIsExiting = otherNode.side != null && (otherNextNode == null || otherNextNode.side == null);

        if (myInOrNearRoundabout && otherInOrNearRoundabout && !myIsExiting && !otherIsExiting) {
          if (isRoundaboutInner != other.isRoundaboutInner) {
            continue;
          }
        }
        
        bool isAhead = false;
        if (bothInRoundabout) {
          if (otherNode.x == myNode.x && otherNode.y == myNode.y && otherNode.side == myNode.side) {
            isAhead = other._distanceTraveled > _distanceTraveled;
          } else {
            isAhead = _isCellAhead(otherNode);
          }
        } else {
          // Normal road cell check (only x, y coords matter)
          if (otherNode.x == myNode.x && otherNode.y == myNode.y) {
            isAhead = other._distanceTraveled > _distanceTraveled;
          } else {
            isAhead = _isCellAhead(otherNode);
          }
          
          if (isAhead) {
            // Restore heading dot-product check to ignore cars behind or going in opposite directions
            final myFwd = Vector2(cos(angle), sin(angle));
            final toOther = other.position - myPos;
            if (toOther.dot(myFwd) <= 0) {
              continue;
            }
            final otherFwd = Vector2(cos(other.angle), sin(other.angle));
            if (myFwd.dot(otherFwd) < -0.5) {
              continue;
            }
          }
        }
        
        if (!isAhead) continue;
        
        final distSq = myPos.distanceToSquared(other.position);
        final dist = sqrt(distSq);
        
        final safeDist = bothInRoundabout
            ? (isRoundaboutInner ? cellSize * 0.28 : cellSize * 0.48)
            : cellSize * 0.7;
        final slowdownStartDist = safeDist + (bothInRoundabout
            ? (isRoundaboutInner ? cellSize * 0.10 : cellSize * 0.15)
            : cellSize * 0.3);
        
        if (dist < slowdownStartDist) {
          final mult = ((dist - safeDist) / (slowdownStartDist - safeDist)).clamp(0.0, 1.0);
          if (mult < targetMultiplier) {
            targetMultiplier = mult;
          }
        }
      }
      _lastTargetMultiplier = targetMultiplier;
    }

    if (_waitingAtSignal) {
      targetMultiplier = 0.0;
    } else {
      targetMultiplier = _lastTargetMultiplier;

      if (targetMultiplier > 0 &&
          _currentPathIndex + 1 < path.length &&
          path[_currentPathIndex + 1].side == null) {
        final nextPos = path[_currentPathIndex + 1];
        if (game.gridManager!.isValid(nextPos.x, nextPos.y) &&
            game.gridManager!.isRoadCongested(nextPos.x, nextPos.y)) {
           targetMultiplier = min(targetMultiplier, 0.15);
        }
      }
    }

    // --- Lane swap when another car is parked at our destination ---
    _updateLaneTarget();
    final nearRoundabout = _currentPathIndex < path.length && 
        (path[_currentPathIndex].side != null || 
         (_currentPathIndex + 1 < path.length && path[_currentPathIndex + 1].side != null));
    final laneRate = nearRoundabout ? (dt * 12.0) : (dt * 2.5); // Fast swap near/inside roundabout
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
    // Disable the anti-stall minimum floor under two conditions:
    // 1. We are approaching a smart junction (roundabout entry).
    // 2. We are close behind another car (to allow a clean bumper stop).
    // Otherwise, keep the 0.08 floor active to prevent random stalls on open roads.
    final currentNode = path[_currentPathIndex.clamp(0, path.length - 1)];
    final bool isApproachingJunction = currentNode.side == null &&
        (_currentPathIndex + 1 < path.length &&
         path[_currentPathIndex + 1].side != null);
    bool canStop = isApproachingJunction || _lastTargetMultiplier < 0.15;
    if (_currentPathIndex + 1 < path.length) {
      final nextNode = path[_currentPathIndex + 1];
      final cell = game.gridManager?.getCell(nextNode.x, nextNode.y);
      if (cell != null) {
        final isJunctionOrIntersection = cell.connectionType == ConnectionNodeType.intersection ||
                                         cell.type == CellType.trafficLight ||
                                         cell.type == CellType.smartJunction;
        if (isJunctionOrIntersection) {
          final occupancy = game.getOrCreateOccupancy(nextNode);
          final isRoundabout = cell.type == CellType.smartJunction;
          if (!occupancy.isReservedBy(this, isRoundabout)) {
            canStop = true;
          }
        }
      }
    }
    if (!_waitingAtSignal && !arrived && !isWaiting && !canStop) {
      finalMultiplier = max(0.08, _currentSpeedMultiplier);
    }

    final oldPathIndex = _currentPathIndex;
    _updatePosition(dt * finalMultiplier);

    // Hard boundary constraint: do not cross into the next cell if we don't have a reservation or if exit is blocked.
    if (_currentPathIndex + 1 < path.length) {
      final cellEndProgress = (_currentPathIndex + 1 < segmentStartOffsets.length)
          ? segmentStartOffsets[_currentPathIndex + 1]
          : _totalLength;
      
      if (!hasReservation || exitBlocked) {
        if (_distanceTraveled > cellEndProgress) {
          _distanceTraveled = cellEndProgress;
          _currentSpeedMultiplier = 0.0;
          _updatePosition(0); // Update position vector and tangent angle to match the boundary
        }
      }
    }

    _currentPathIndex = _calculatePathIndex(_distanceTraveled);

    if (_currentPathIndex != oldPathIndex) {
      if (path.isNotEmpty && oldPathIndex < path.length && _currentPathIndex < path.length) {
        final oldPos = path[oldPathIndex];
        final newPos = path[_currentPathIndex];
        
        if (oldPos.side == null && newPos.side != null) {
          debugPrint("[ROUNDABOUT_ENTER] Car $this entered roundabout at (${newPos.x}, ${newPos.y}, ${newPos.side!.name})");
        } else if (oldPos.side != null && newPos.side == null) {
          debugPrint("[ROUNDABOUT_EXIT] Car $this exited roundabout to (${newPos.x}, ${newPos.y})");
          _roundaboutInnerLane = null;
        }
      }

      if (path.isNotEmpty && oldPathIndex < path.length) {
        final pos = path[oldPathIndex];
        final RoadOccupancy occupancy = game.getOrCreateOccupancy(pos);
        occupancy.cars.remove(this);
        debugPrint("[ROAD_RELEASE] Car $this left (${pos.x}, ${pos.y})");
        
        occupancy.activeIntersectionCars.remove(this);
        if (occupancy.activeIntersectionCars.isEmpty) {
          occupancy.reservedAxis = null;
          debugPrint("[INTERSECTION_RELEASE] Intersection (${pos.x}, ${pos.y}) released");
        }
      }

      // Clear reservation/waiting state on the old next cell since we moved past/entered it
      if (path.isNotEmpty && oldPathIndex + 1 < path.length) {
        final oldNextPos = path[oldPathIndex + 1];
        final RoadOccupancy oldNextOccupancy = game.getOrCreateOccupancy(oldNextPos);
        oldNextOccupancy.waitingCars.remove(this);
        oldNextOccupancy.clearReservation(this);
      }

      _registerOccupancy();
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

  bool _isCellAhead(GridPosition otherCell) {
    final limit = min(path.length, _currentPathIndex + 4);
    for (int i = _currentPathIndex + 1; i < limit; i++) {
      final p = path[i];
      final eitherIsRoundabout = p.side != null || otherCell.side != null;
      if (eitherIsRoundabout) {
        if (p.x == otherCell.x && p.y == otherCell.y && p.side == otherCell.side) {
          return true;
        }
      } else {
        if (p.x == otherCell.x && p.y == otherCell.y) {
          return true;
        }
      }
    }
    return false;
  }

  bool _isOncomingCar(CarComponent other) {
    if (other.arrived) return false;

    // 1. Path history check: if other's next node is our current node, it's oncoming.
    final myIdx = _currentPathIndex.clamp(0, path.length - 1);
    final myNode = path[myIdx];

    if (other._currentPathIndex + 1 < other.path.length) {
      final otherNext = other.path[other._currentPathIndex + 1];
      if (otherNext.x == myNode.x && otherNext.y == myNode.y && otherNext.side == myNode.side) {
        return true;
      }
    }

    // 2. Heading check: if the cars face opposite directions (dot product is negative)
    final myFwd = Vector2(cos(angle), sin(angle));
    final otherFwd = Vector2(cos(other.angle), sin(other.angle));
    if (myFwd.dot(otherFwd) < -0.5) {
      return true;
    }

    return false;
  }

  Direction _getRoundaboutYieldDirection(Direction enteringSide) {
    switch (enteringSide) {
      case Direction.west:  return Direction.south;
      case Direction.north: return Direction.west;
      case Direction.east:  return Direction.north;
      case Direction.south: return Direction.east;
    }
  }

  Direction getNextClockwise(Direction dir) {
    switch (dir) {
      case Direction.north: return Direction.east;
      case Direction.east:  return Direction.south;
      case Direction.south: return Direction.west;
      case Direction.west:  return Direction.north;
    }
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
        final opacity = (1.0 - ratio) * 0.32;
        final width = size.x * 0.32 * (1.0 - ratio * 0.7);

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
