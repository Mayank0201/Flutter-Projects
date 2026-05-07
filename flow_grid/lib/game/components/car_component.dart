import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/material.dart';
import '../../models/game_constants.dart';
import '../../models/grid_cell.dart';
import '../../game/flow_grid_game.dart';

class CarComponent extends PositionComponent with HasGameReference<FlowGridGame> {
  final int colorIndex;
  List<GridPosition> path;
  final double cellSize;
  final double offsetX;
  final double offsetY;
  final double speed;
  final GridPosition spawnHousePos;
  final GridPosition targetDest;
  final VehicleType vehicleType;

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

  // Follow-the-leader constants

  double _collisionCheckTimer = 0;
  double _lastSpeedMultiplier = 1.0;

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
    int? initialPathIndex,
    double? initialProgress,
    bool? initialReturning,
  }) {
    _currentPathIndex = initialPathIndex ?? 0;
    isReturning = initialReturning ?? false;

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
    
    final baseSize = cellSize * 0.22;
    switch (vehicleType) {
      case VehicleType.car:
        size = Vector2(baseSize, baseSize);
      case VehicleType.truck:
        size = Vector2(baseSize * 1.3, baseSize * 1.1);
      case VehicleType.serviceVan:
        size = Vector2(baseSize * 1.1, baseSize * 0.95);
    }
    anchor = Anchor.center;
    priority = 10;
  }

  double get _vehicleSpeedMultiplier {
    switch (vehicleType) {
      case VehicleType.car: return 1.0;
      case VehicleType.truck: return GameConstants.truckSpeedMultiplier;
      case VehicleType.serviceVan: return GameConstants.serviceVanSpeedMultiplier;
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
    'distanceTraveled': _distanceTraveled,
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

    if (isWaiting) {
      _waitTimer += dt * game.timeScale;
      if (_waitTimer >= maxWaitTime) {
        isWaiting = false;
        arrived = true;
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

    // --- Traffic Signal Check ---
    _waitingAtSignal = false;
    if (_currentPathIndex + 1 < path.length && game.gridManager != null) {
      final nextPos = path[_currentPathIndex + 1];
      if (game.gridManager!.isValid(nextPos.x, nextPos.y)) {
        final nextCell = game.gridManager!.grid[nextPos.y][nextPos.x];
        if (nextCell.hasTrafficLight && nextPos.side == null) {
          // Determine travel direction
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
            // RED signal — only stop if we're close to the signal tile
            final signalWorldX = offsetX + nextPos.x * cellSize + cellSize / 2;
            final signalWorldY = offsetY + nextPos.y * cellSize + cellSize / 2;
            final distToSignal = position.distanceTo(Vector2(signalWorldX, signalWorldY));
            if (distToSignal < cellSize * 0.8) {
              _waitingAtSignal = true;
            }
          }
        }
      }
    }

    // --- Determine if on express lane ---
    onExpressLane = false;
    double terrainSpeed = 1.0;
    if (_currentPathIndex < path.length && game.gridManager != null) {
      final curPos = path[_currentPathIndex];
      if (game.gridManager!.isValid(curPos.x, curPos.y)) {
        final curCell = game.gridManager!.grid[curPos.y][curPos.x];
        terrainSpeed = curCell.speedMultiplier;
        onExpressLane = curCell.isExpressLaneNode || terrainSpeed >= GameConstants.expressLaneSpeed;
      }
    }

    // Dynamic rendering priority
    priority = onExpressLane ? 20 : 10;

    // --- Congestion slowdown ---
    double congestionMultiplier = 1.0;
    if (game.gridManager != null && _currentPathIndex < path.length) {
      final curPos = path[_currentPathIndex];
      if (game.gridManager!.isValid(curPos.x, curPos.y) && game.gridManager!.isRoadCongested(curPos.x, curPos.y)) {
        congestionMultiplier = 0.5;
      }
    }

    // --- Follow-the-leader speed modulation ---
    double speedMultiplier = 1.0;
    _collisionCheckTimer += dt;
    if (_collisionCheckTimer >= 0.033) { // 30 FPS collision check rate
      _collisionCheckTimer = 0;
      if (!onExpressLane && !_waitingAtSignal) {
        final myPos = position;
        final forward = Vector2(cos(angle), sin(angle));
        final minGap = cellSize * 0.6; // Rule: MIN_GAP = 0.6 * tileSize
        double closestAheadDist = double.infinity;

        final myGridPos = path[_currentPathIndex.clamp(0, path.length - 1)];
        final gWidth = game.gridWidth;

        // Check neighboring grid cells for other cars
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            final key = (myGridPos.x + dx) + (myGridPos.y + dy) * gWidth;
            final others = game.carGrid[key];
            if (others == null) continue;

            for (final other in others) {
              if (identical(other, this) || other.onExpressLane || other.arrived) continue;

              final distSq = myPos.distanceToSquared(other.position);
              if (distSq > (cellSize * 1.5) * (cellSize * 1.5)) continue; 
              
              final toOther = other.position - myPos;
              final dotProduct = toOther.x * forward.x + toOther.y * forward.y;
              if (dotProduct <= 0) continue; // Only care about cars ahead

              final dist = sqrt(distSq);
              if (dist < closestAheadDist) {
                closestAheadDist = dist;
              }
            }
          }
        }

        if (closestAheadDist < minGap) {
          // Rule: speed = baseSpeed * (distance / MIN_GAP)
          _lastSpeedMultiplier = (closestAheadDist / minGap).clamp(0.0, 1.0);
        } else {
          _lastSpeedMultiplier = 1.0;
        }
      }
    }
    speedMultiplier = _lastSpeedMultiplier;

    if (_waitingAtSignal) {
      speedMultiplier = 0.0; // Full stop at red signal
    }

    final effectiveMultiplier = speedMultiplier * _vehicleSpeedMultiplier * terrainSpeed * congestionMultiplier;
    
    // RULE: Creep Speed - ensure cars never stay at exactly 0 speed unless at a red light
    double finalMultiplier = effectiveMultiplier;
    if (!_waitingAtSignal && !arrived && !isWaiting) {
      finalMultiplier = max(0.02, effectiveMultiplier);
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

  @override
  void render(Canvas canvas) {
    final color = GameConstants.buildingColors[colorIndex];
    final darkColor = GameConstants.getBuildingDarkColor(colorIndex);
    final carSize = size.x;

    switch (vehicleType) {
      case VehicleType.car:
        _renderCar(canvas, color, darkColor, carSize);
      case VehicleType.truck:
        _renderTruck(canvas, color, darkColor, carSize);
      case VehicleType.serviceVan:
        _renderVan(canvas, color, darkColor, carSize);
    }
  }

  void _renderCar(Canvas canvas, Color color, Color darkColor, double carSize) {
    final bodyBase = Color.lerp(color, const Color(0xFFD0D3DA), 0.4)!;
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: carSize, height: carSize * 0.7),
      Radius.circular(carSize * 0.2),
    );

    canvas.drawRRect(bodyRect.shift(const Offset(1, 2)), Paint()..color = Colors.black.withValues(alpha: 0.25));
    canvas.drawRRect(bodyRect, Paint()..color = bodyBase);
    canvas.drawRRect(bodyRect, Paint()..color = darkColor..style = PaintingStyle.stroke..strokeWidth = 1.5);

    final windshieldRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(carSize * 0.15, 0), width: carSize * 0.35, height: carSize * 0.5),
      Radius.circular(carSize * 0.08),
    );
    canvas.drawRRect(windshieldRect, Paint()..color = GameConstants.carWindowColor);

    final lightPaint = Paint()..color = Colors.white.withValues(alpha: 0.7);
    canvas.drawCircle(Offset(carSize * 0.4, -carSize * 0.2), 1.5, lightPaint);
    canvas.drawCircle(Offset(carSize * 0.4, carSize * 0.2), 1.5, lightPaint);
  }

  void _renderTruck(Canvas canvas, Color color, Color darkColor, double carSize) {
    final bodyBase = Color.lerp(color, const Color(0xFF8A8D95), 0.5)!;
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: carSize * 1.1, height: carSize * 0.8),
      Radius.circular(carSize * 0.15),
    );
    canvas.drawRRect(bodyRect.shift(const Offset(1, 2)), Paint()..color = Colors.black.withValues(alpha: 0.3));
    canvas.drawRRect(bodyRect, Paint()..color = bodyBase);
    canvas.drawRRect(bodyRect, Paint()..color = darkColor..style = PaintingStyle.stroke..strokeWidth = 2.0);

    // Cargo area
    final cargoRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(-carSize * 0.15, 0), width: carSize * 0.5, height: carSize * 0.65),
      Radius.circular(carSize * 0.05),
    );
    canvas.drawRRect(cargoRect, Paint()..color = darkColor.withValues(alpha: 0.6));

    final lightPaint = Paint()..color = Colors.amber.withValues(alpha: 0.8);
    canvas.drawCircle(Offset(carSize * 0.5, -carSize * 0.25), 2.0, lightPaint);
    canvas.drawCircle(Offset(carSize * 0.5, carSize * 0.25), 2.0, lightPaint);
  }

  void _renderVan(Canvas canvas, Color color, Color darkColor, double carSize) {
    final bodyBase = Color.lerp(color, const Color(0xFFE8E8E8), 0.3)!;
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: carSize, height: carSize * 0.75),
      Radius.circular(carSize * 0.18),
    );
    canvas.drawRRect(bodyRect.shift(const Offset(1, 2)), Paint()..color = Colors.black.withValues(alpha: 0.25));
    canvas.drawRRect(bodyRect, Paint()..color = bodyBase);
    
    // Color stripe accent
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: carSize * 0.9, height: carSize * 0.12),
      Paint()..color = color,
    );

    canvas.drawRRect(bodyRect, Paint()..color = darkColor..style = PaintingStyle.stroke..strokeWidth = 1.5);

    final windshieldRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(carSize * 0.2, 0), width: carSize * 0.3, height: carSize * 0.55),
      Radius.circular(carSize * 0.06),
    );
    canvas.drawRRect(windshieldRect, Paint()..color = GameConstants.carWindowColor);

    final lightPaint = Paint()..color = Colors.white.withValues(alpha: 0.7);
    canvas.drawCircle(Offset(carSize * 0.4, -carSize * 0.2), 1.5, lightPaint);
    canvas.drawCircle(Offset(carSize * 0.4, carSize * 0.2), 1.5, lightPaint);
  }
}
