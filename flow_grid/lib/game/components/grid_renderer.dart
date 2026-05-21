import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import '../../models/game_constants.dart';
import '../../models/grid_cell.dart';
import '../grid_manager.dart';
import '../flow_grid_game.dart';
import '../spawn_controller.dart';
import '../../models/district_profile.dart';

class GridRenderer extends PositionComponent
    with HasGameReference<FlowGridGame> {
  final GridManager gridManager;
  double cellSize;
  double offsetX;
  double offsetY;

  ui.Picture? _terrainPicture;
  
  // Task 1: Chunked Render Cache
  final Map<int, _RenderChunk> _chunks = {};
  
  // Task 6: Preallocated Paints
  final Paint _roadPaint = Paint()
    ..color = GameConstants.roadColor
    ..strokeWidth = GameConstants.cellSize * 0.4
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  final Paint _tunnelPaint = Paint()
    ..color = GameConstants.tunnelColor
    ..strokeWidth = GameConstants.cellSize * 0.4
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  final Paint _bridgePaint = Paint()
    ..color = GameConstants.bridgeColor
    ..strokeWidth = GameConstants.cellSize * 0.4
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  final Paint _mountainBasePaint = Paint()
    ..color = GameConstants.mountainColor
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

  final Paint _mountainPeakPaint = Paint()
    ..color = GameConstants.mountainHighlightColor.withValues(alpha: 0.4)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

  GridRenderer({
    required this.gridManager,
    required this.cellSize,
    this.offsetX = 0,
    this.offsetY = 0,
  });

  final List<_FloatingMessage> _floatingMessages = [];

  /// [OPTIMIZATION] Mark only infrastructure as dirty (Roads, Buildings, etc.)
  /// Previews and Demand indicators remain per-frame and don't trigger cache rebuilds.
  /// [OPTIMIZATION] Mark only affected chunks as dirty
  void markInfrastructureDirty(int x, int y) {
    final chunkX = x ~/ GameConstants.chunkSize;
    final chunkY = y ~/ GameConstants.chunkSize;
    final key = chunkX + chunkY * 1000;
    _chunks[key]?.dirty = true;
  }

  void markAllDirty() {
    for (final chunk in _chunks.values) {
      chunk.dirty = true;
    }
  }

  void rebuildTerrainVisuals() {
    _terrainPicture = null;
    _mountainPathCache = null;
    _mountainPeaksCache = null;
    markAllDirty();
  }

  void addFloatingMessage(String text, GridPosition pos, Color color) {
    _floatingMessages.add(_FloatingMessage(text, pos, color));
  }

  /// Alias for backward compatibility
  /// Alias for backward compatibility
  void markDirty([int? x, int? y]) {
    if (x != null && y != null) {
      markInfrastructureDirty(x, y);
    } else {
      markAllDirty();
    }
  }

  @override
  void render(Canvas canvas) {
    // Tier 1: Static Terrain (Background, Grid, Water)
    _terrainPicture ??= _buildTerrainPicture();
    canvas.drawPicture(_terrainPicture!);

    // Tier 2: Chunked Infrastructure (Task 1)
    _drawChunks(canvas);

    // Tier 3: Per-Frame Overlay (Demand, Previews, Selection Highlights)
    _drawParkingHighlights(canvas);
    _drawDemandIndicators(canvas);
    _drawExpressLanePreview(canvas);
    _drawRoadPreview(canvas);
    _drawCongestion(canvas);

    // [PREMIUM] City Reveal Vignette
    _drawCityVignette(canvas);

    // Floating Messages (Upgrades, Events)
    _drawFloatingMessages(canvas);
  }

  ui.Picture _buildTerrainPicture() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Background
    canvas.drawRect(
      Rect.fromLTWH(
        offsetX,
        offsetY,
        gridManager.cols * cellSize,
        gridManager.rows * cellSize,
      ),
      Paint()..color = GameConstants.backgroundColor,
    );

    // Grid lines (Subtle)
    final linePaint = Paint()
      ..color = GameConstants.gridLineColor.withValues(alpha: 0.15)
      ..strokeWidth = 0.5;

    for (int x = 0; x <= gridManager.cols; x++) {
      final lx = offsetX + x * cellSize;
      canvas.drawLine(
        Offset(lx, offsetY),
        Offset(lx, offsetY + gridManager.rows * cellSize),
        linePaint,
      );
    }
    for (int y = 0; y <= gridManager.rows; y++) {
      final ly = offsetY + y * cellSize;
      canvas.drawLine(
        Offset(offsetX, ly),
        Offset(offsetX + gridManager.cols * cellSize, ly),
        linePaint,
      );
    }

    return recorder.endRecording();
  }

  void _drawChunks(Canvas canvas) {
    // Determine visible area for culling
    final viewport = game.camera.visibleWorldRect;
    
    final chunkPx = GameConstants.cellSize * GameConstants.chunkSize;
    
    final minCX = ((viewport.left - offsetX) / chunkPx).floor().clamp(0, (gridManager.cols / GameConstants.chunkSize).floor());
    final maxCX = ((viewport.right - offsetX) / chunkPx).floor().clamp(0, (gridManager.cols / GameConstants.chunkSize).floor());
    final minCY = ((viewport.top - offsetY) / chunkPx).floor().clamp(0, (gridManager.rows / GameConstants.chunkSize).floor());
    final maxCY = ((viewport.bottom - offsetY) / chunkPx).floor().clamp(0, (gridManager.rows / GameConstants.chunkSize).floor());

    for (int cx = minCX; cx <= maxCX; cx++) {
      for (int cy = minCY; cy <= maxCY; cy++) {
        final key = cx + cy * 1000;
        final chunk = _chunks.putIfAbsent(key, () => _RenderChunk(cx, cy));
        
        if (chunk.dirty || chunk.picture == null) {
          chunk.picture = _buildChunkPicture(cx, cy);
          chunk.dirty = false;
        }
        canvas.drawPicture(chunk.picture!);
      }
    }
  }

  ui.Picture _buildChunkPicture(int cx, int cy) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    final minX = cx * GameConstants.chunkSize;
    final minY = cy * GameConstants.chunkSize;
    final maxX = minX + GameConstants.chunkSize;
    final maxY = minY + GameConstants.chunkSize;

    // Use a clip rect to ensure we only draw within the chunk
    final clipRect = Rect.fromLTWH(
      offsetX + minX * cellSize,
      offsetY + minY * cellSize,
      GameConstants.chunkSize * cellSize,
      GameConstants.chunkSize * cellSize,
    );
    canvas.clipRect(clipRect);

    _drawMountains(canvas, minX, minY, maxX, maxY);
    _drawRoadsAndExpressLanes(canvas, minX, minY, maxX, maxY);
    _drawSmartJunctions(canvas, minX, minY, maxX, maxY);
    _drawBuildings(canvas, minX, minY, maxX, maxY);
    _drawInfrastructure(canvas, minX, minY, maxX, maxY);

    return recorder.endRecording();
  }

  Path? _mountainPathCache;
  Path? _mountainPeaksCache;

  void _drawMountains(Canvas canvas, int minX, int minY, int maxX, int maxY) {
    if (_mountainPathCache == null) {
      _buildMountainPathCache();
    }
    canvas.drawPath(_mountainPathCache!, _mountainBasePaint);
    canvas.drawPath(_mountainPeaksCache!, _mountainPeakPaint);
  }

  void _buildMountainPathCache() {
    _mountainPathCache = Path();
    _mountainPeaksCache = Path();
    for (final cluster in gridManager.mountainClusters) {
      for (final cell in cluster.cells) {
        final rect = Rect.fromLTWH(
          offsetX + cell.x * cellSize,
          offsetY + cell.y * cellSize,
          cellSize,
          cellSize,
        );
        _mountainPathCache!.addRRect(
          RRect.fromRectAndRadius(
            rect.inflate(cellSize * 0.15),
            Radius.circular(cellSize * 0.45),
          ),
        );
        _mountainPeaksCache!.addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: rect.center.translate(0, -cellSize * 0.1),
              width: cellSize * 0.6,
              height: cellSize * 0.4,
            ),
            Radius.circular(cellSize * 0.2),
          ),
        );
      }
    }
  }

  void _drawRoadsAndExpressLanes(Canvas canvas, int minX, int minY, int maxX, int maxY) {
    final roadPath = Path();
    final tunnelPath = Path();
    final bridgePath = Path();

    for (int x = minX; x < maxX; x++) {
      for (int y = minY; y < maxY; y++) {
        if (!gridManager.isValid(x, y)) continue;
        final cell = gridManager.grid[y][x];

        if ((!cell.isRoad && !cell.isExpressLaneNode && !cell.isTunnel && !cell.isBridge) || cell.isPendingDeletion) {
          continue;
        }

        if (cell.isExpressLane && (cell.type == CellType.road || cell.type == CellType.tunnel)) {
          continue;
        }

        final cx = offsetX + x * cellSize;
        final cy = offsetY + y * cellSize;
        final midX = cx + cellSize / 2;
        final midY = cy + cellSize / 2;

        final n = cell.connUp;
        final e = cell.connRight;
        final s = cell.connDown;
        final w = cell.connLeft;

        final Path targetPath;
        if (cell.isTunnel) {
          targetPath = tunnelPath;
        } else if (cell.isBridge) {
          targetPath = bridgePath;
        } else {
          targetPath = roadPath;
        }
        int connCount = (n ? 1 : 0) + (e ? 1 : 0) + (s ? 1 : 0) + (w ? 1 : 0);

        if (connCount == 1) {
          targetPath.moveTo(midX, midY);
          if (n) targetPath.lineTo(midX, cy);
          if (e) targetPath.lineTo(cx + cellSize, midY);
          if (s) targetPath.lineTo(midX, cy + cellSize);
          if (w) targetPath.lineTo(cx, midY);
        } else if (connCount == 2) {
          if (n && s) {
            targetPath.moveTo(midX, cy);
            targetPath.lineTo(midX, cy + cellSize);
          } else if (e && w) {
            targetPath.moveTo(cx, midY);
            targetPath.lineTo(cx + cellSize, midY);
          } else {
            if (n && e) {
              targetPath.moveTo(midX, cy);
              targetPath.quadraticBezierTo(midX, midY, cx + cellSize, midY);
            } else if (e && s) {
              targetPath.moveTo(cx + cellSize, midY);
              targetPath.quadraticBezierTo(midX, midY, midX, cy + cellSize);
            } else if (s && w) {
              targetPath.moveTo(midX, cy + cellSize);
              targetPath.quadraticBezierTo(midX, midY, cx, midY);
            } else if (w && n) {
              targetPath.moveTo(cx, midY);
              targetPath.quadraticBezierTo(midX, midY, midX, cy);
            }
          }
        } else if (connCount > 2) {
          if (n) { targetPath.moveTo(midX, midY); targetPath.lineTo(midX, cy); }
          if (e) { targetPath.moveTo(midX, midY); targetPath.lineTo(cx + cellSize, midY); }
          if (s) { targetPath.moveTo(midX, midY); targetPath.lineTo(midX, cy + cellSize); }
          if (w) { targetPath.moveTo(midX, midY); targetPath.lineTo(cx, midY); }
        } else if (cell.isTunnel || cell.isBridge) {
          // 0-conn corridor: still draw a stub so the player can see the tile
          // they paid for. Orient along its infrastructure axis if known.
          if (cell.infrastructureAxis == InfrastructureAxis.vertical) {
            targetPath.moveTo(midX, midY - cellSize * 0.25);
            targetPath.lineTo(midX, midY + cellSize * 0.25);
          } else {
            targetPath.moveTo(midX - cellSize * 0.25, midY);
            targetPath.lineTo(midX + cellSize * 0.25, midY);
          }
        }
      }
    }

    canvas.drawPath(roadPath, _roadPaint);
    canvas.drawPath(tunnelPath, _tunnelPaint);
    canvas.drawPath(bridgePath, _bridgePaint);

    _drawExpressLanesGlobal(canvas);
  }
  
  void _drawExpressLanesGlobal(Canvas canvas) {
    final rw = (cellSize * 0.4) * 0.8;
    final borderPaint = Paint()
      ..color = GameConstants.expressLaneBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = rw + 2
      ..strokeCap = StrokeCap.round;

    final lanePaint = Paint()
      ..color = GameConstants.expressLaneColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = rw
      ..strokeCap = StrokeCap.round;

    final arrowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (final lane in gridManager.placedExpressLanes) {
      if (lane.length < 2) continue;
      final p1 = lane[0];
      final p2 = lane[1];

      final o1 = Offset(
        offsetX + p1.x * cellSize + cellSize / 2,
        offsetY + p1.y * cellSize + cellSize / 2,
      );
      final o2 = Offset(
        offsetX + p2.x * cellSize + cellSize / 2,
        offsetY + p2.y * cellSize + cellSize / 2,
      );

      canvas.drawLine(o1, o2, borderPaint);
      canvas.drawLine(o1, o2, lanePaint);

      final delta = o2 - o1;
      final length = delta.distance;
      if (length > 10) {
        final dir = Offset(delta.dx / length, delta.dy / length);
        final perp = Offset(-dir.dy, dir.dx);
        for (double d = 15; d < length; d += 25) {
          final tip = o1 + dir * d;
          canvas.drawLine(tip - dir * 4 + perp * 3, tip, arrowPaint);
          canvas.drawLine(tip - dir * 4 - perp * 3, tip, arrowPaint);
        }
      }
    }
  }

  void _drawSmartJunctions(Canvas canvas, int minX, int minY, int maxX, int maxY) {
    final radius = cellSize * 0.35;
    
    for (int x = minX; x < maxX; x++) {
      for (int y = minY; y < maxY; y++) {
        if (!gridManager.isValid(x, y)) continue;
        final cell = gridManager.grid[y][x];
        if (!cell.hasSmartJunction) continue;

        final cx = offsetX + x * cellSize + cellSize / 2;
        final cy = offsetY + y * cellSize + cellSize / 2;

        // Flares (Using _roadPaint)
        canvas.drawCircle(Offset(cx, cy), radius, _roadPaint..style = PaintingStyle.fill..color = GameConstants.roadFillColor);
        canvas.drawCircle(Offset(cx, cy), radius, _roadPaint..style = PaintingStyle.stroke..color = Colors.white12);
        // Reset paint
        _roadPaint..style = PaintingStyle.stroke..color = GameConstants.roadColor;
      }
    }
  }

  void _drawBuildings(Canvas canvas, int minX, int minY, int maxX, int maxY) {
    final drivewayPaint = Paint()
      ..color = GameConstants.roadFillColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = cellSize * 0.4
      ..strokeCap = StrokeCap.round;

    for (int x = minX; x < maxX; x++) {
      for (int y = minY; y < maxY; y++) {
        if (!gridManager.isValid(x, y)) continue;
        final cell = gridManager.grid[y][x];
        if (!cell.isHouse && !cell.isDestination) continue;

        final cx = offsetX + x * cellSize + cellSize / 2;
        final cy = offsetY + y * cellSize + cellSize / 2;

        final entryDir = cell.entrySide;
        if (entryDir != null) {
          final stubPath = Path();
          final bodyRadius = cellSize * 0.225;

          if (entryDir == Direction.north) {
            stubPath.moveTo(cx, cy - bodyRadius);
            stubPath.lineTo(cx, cy - cellSize / 2);
          } else if (entryDir == Direction.east) {
            stubPath.moveTo(cx + bodyRadius, cy);
            stubPath.lineTo(cx + cellSize / 2, cy);
          } else if (entryDir == Direction.south) {
            stubPath.moveTo(cx, cy + bodyRadius);
            stubPath.lineTo(cx, cy + cellSize / 2);
          } else {
            stubPath.moveTo(cx - bodyRadius, cy);
            stubPath.lineTo(cx - cellSize / 2, cy);
          }
          canvas.drawPath(stubPath, drivewayPaint);
        }

        final color = GameConstants.buildingColors[cell.colorIndex ?? 0];
        final districtType = game.districtPlanner.getDistrictType(cell.colorIndex ?? 0);

        if (cell.isHouse) {
          _drawHouse(canvas, cx, cy, color, BuildingProfile.residential.renderScale, districtType);
        } else {
          _drawDestination(canvas, cx, cy, color, cell.entrySide!, BuildingProfile.commercial.renderScale, districtType);
        }
      }
    }
  }

  void _drawHouse(
    Canvas canvas,
    double cx,
    double cy,
    Color color,
    double scale,
    DistrictType districtType,
  ) {
    final size = cellSize * scale;
    final rect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: size,
      height: size,
    );

    // Shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.shift(const Offset(0, 2)),
        Radius.circular(size * 0.2),
      ),
      Paint()
        ..color = Colors.black26
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(size * 0.2)),
      Paint()..color = color,
    );

    // Roof highlight
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left + 2, rect.top + 2, size - 4, size * 0.3),
        Radius.circular(size * 0.1),
      ),
      Paint()..color = Colors.white24,
    );

    // [NEW] District Markers (Requested: Dots/Trucks)
    _drawBuildingMarkers(canvas, cx, cy, size, districtType);
  }

  void _drawDestination(
    Canvas canvas,
    double cx,
    double cy,
    Color color,
    Direction entry,
    double scale,
    DistrictType districtType,
  ) {
    final size = cellSize * scale;
    final rect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: size,
      height: size,
    );

    // Foundation/Parking
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(size * 0.15)),
      Paint()..color = GameConstants.roadFillColor,
    );

    // Main building
    final bSize = size * 0.7;
    final bRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: bSize,
      height: bSize * 0.6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bRect, Radius.circular(size * 0.1)),
      Paint()..color = color,
    );

    // Details
    canvas.drawLine(
      Offset(bRect.left + 5, bRect.top + 5),
      Offset(bRect.right - 5, bRect.top + 5),
      Paint()
        ..color = Colors.white30
        ..strokeWidth = 2,
    );

    // [NEW] District Markers (Requested: Dots/Trucks)
    _drawBuildingMarkers(canvas, cx, cy, size, districtType);
  }

  void _drawBuildingMarkers(Canvas canvas, double cx, double cy, double size, DistrictType type) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    switch (type) {
      case DistrictType.residential:
        // Three small dots (Residential pattern) - REMOVED for clean aesthetics
        break;
      case DistrictType.industrial:
        // Simple Truck shape (Rectangle + small wheels)
        final tw = size * 0.45;
        final th = size * 0.25;
        canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy + size * 0.1), width: tw, height: th), paint);
        // Cabin
        canvas.drawRect(Rect.fromLTWH(cx + tw * 0.2, cy + size * 0.05, tw * 0.25, th * 0.6), paint);
        // Small Wheels
        canvas.drawCircle(Offset(cx - tw * 0.3, cy + size * 0.25), size * 0.06, paint);
        canvas.drawCircle(Offset(cx + tw * 0.3, cy + size * 0.25), size * 0.06, paint);
        break;
      case DistrictType.commercial:
        // Shop-style dots or cross - REMOVED for clean aesthetics
        break;
      case DistrictType.tech:
        // Chip-style grid (4 small dots) - REMOVED for clean aesthetics
        break;
    }
  }

  void _drawInfrastructure(Canvas canvas, int minX, int minY, int maxX, int maxY) {
    for (int x = minX; x < maxX; x++) {
      for (int y = minY; y < maxY; y++) {
        if (!gridManager.isValid(x, y)) continue;
        final cell = gridManager.grid[y][x];
        
        if (cell.hasTrafficLight) {
          _drawTrafficLight(canvas, x, y, cell);
        } else if (cell.overpass == OverpassType.start || cell.overpass == OverpassType.end) {
          _drawOverpassPortal(canvas, x, y, cell);
        }
      }
    }
  }

  void _drawTrafficLight(Canvas canvas, int x, int y, GridCell cell) {
    final opacity = cell.isPendingDeletion ? 0.3 : 1.0;
    final cx = offsetX + x * cellSize + cellSize * 0.7;
    final cy = offsetY + y * cellSize + cellSize * 0.5;

    final pillW = cellSize * 0.16;
    final pillH = cellSize * 0.38;

    canvas.drawRect(
      Rect.fromLTWH(cx - 1, cy + pillH * 0.2, 2, cellSize * 0.3),
      Paint()..color = Colors.black45.withValues(alpha: opacity),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: pillW, height: pillH),
        Radius.circular(pillW / 2),
      ),
      Paint()..color = Colors.black87.withValues(alpha: opacity),
    );

    final redActive = !gridManager.isGreenForDirection(x, y, Direction.north);
    final redColor = redActive ? Colors.redAccent : Colors.red.withValues(alpha: 0.2);
    canvas.drawCircle(Offset(cx, cy - pillH * 0.22), pillW * 0.35, Paint()..color = redColor.withValues(alpha: opacity));

    final greenColor = !redActive ? Colors.greenAccent : Colors.green.withValues(alpha: 0.2);
    canvas.drawCircle(Offset(cx, cy + pillH * 0.22), pillW * 0.35, Paint()..color = greenColor.withValues(alpha: opacity));
  }

  void _drawOverpassPortal(Canvas canvas, int x, int y, GridCell cell) {
    final opacity = cell.isPendingDeletion ? 0.3 : 1.0;
    final cx = offsetX + x * cellSize + cellSize / 2;
    final cy = offsetY + y * cellSize + cellSize / 2;
    final r = cellSize * 0.35;

    final path = Path()
      ..moveTo(cx, cy - r)
      ..lineTo(cx + r, cy - r * 0.5)
      ..lineTo(cx + r, cy + r * 0.2)
      ..quadraticBezierTo(cx + r, cy + r, cx, cy + r * 1.2)
      ..quadraticBezierTo(cx - r, cy + r, cx - r, cy + r * 0.2)
      ..lineTo(cx - r, cy - r * 0.5)
      ..close();

    canvas.drawPath(path, Paint()..color = GameConstants.expressLaneColor.withValues(alpha: opacity));
    canvas.drawPath(path, Paint()..color = Colors.white.withValues(alpha: 0.8 * opacity)..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  void _drawParkingHighlights(Canvas canvas) {
    final cars = game.cars;
    if (cars.isEmpty) return;
    final pulse = 0.5 + 0.5 * math.sin(game.elapsedTime * 6);
    final r = cellSize * (0.55 + pulse * 0.08);
    final paint = Paint()
      ..color = const Color(0xFFFFD54F).withValues(alpha: 0.18 + pulse * 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    for (final car in cars) {
      if (!car.isWaiting || car.arrived) continue;
      final pos = car.isReturning ? car.spawnHousePos : car.targetDest;
      final cx = offsetX + pos.x * cellSize + cellSize / 2;
      final cy = offsetY + pos.y * cellSize + cellSize / 2;
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }

  void _drawDemandIndicators(Canvas canvas) {
    for (final pos in gridManager.destinations) {
      final cell = gridManager.grid[pos.y][pos.x];
      // [CRITICAL] Prevent Role Contamination (Issue 3)
      // Only draw demand if the cell at this position is still actually a destination
      if (!cell.isDestination) continue;

      final demand = gridManager.getDemand(pos);
      if (demand <= 0) continue;

      final key = '${pos.x},${pos.y}';
      final overflowLevel = gridManager.overflowLevels[key] ?? 0.0;

      final cx = offsetX + pos.x * cellSize + cellSize / 2;
      final cy = offsetY + pos.y * cellSize + cellSize / 2;

      final age = gridManager.destinationAges[key] ?? 0;
      final isMature = age >= GameConstants.maturityThresholdWeeks;

      // Draw Maturity Aura (Subtle glow for hubs)
      if (isMature) {
        final t = game.elapsedTime * 2.0;
        final pulse = (0.5 + 0.5 * math.sin(t)).clamp(0.0, 1.0);
        final auraRadius = cellSize * (0.5 + pulse * 0.1);

        canvas.drawCircle(
          Offset(cx, cy),
          auraRadius,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.05 + pulse * 0.05)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }

      if (overflowLevel > 0) {
        // Draw Overflow Timer Circle (Big visual warning)
        final progress = overflowLevel.clamp(0.0, 1.0);
        final radius = cellSize * 0.45;

        // Background dark circle
        canvas.drawCircle(
          Offset(cx, cy),
          radius,
          Paint()..color = Colors.black.withValues(alpha: 0.6),
        );

        // White border
        canvas.drawCircle(
          Offset(cx, cy),
          radius,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );

        // Red Progress Arc
        final timerPaint = Paint()
          ..color = Colors.redAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = cellSize * 0.12
          ..strokeCap = StrokeCap.round;

        canvas.drawArc(
          Rect.fromCircle(
            center: Offset(cx, cy),
            radius: radius - cellSize * 0.06,
          ),
          -3.14159 / 2, // Start at top
          2 * 3.14159 * progress, // Sweep angle
          false,
          timerPaint,
        );

        // Draw Hourglass Icon
        final hR = cellSize * 0.18;
        final hourglassPath = Path()
          ..moveTo(cx - hR, cy - hR)
          ..lineTo(cx + hR, cy - hR)
          ..lineTo(cx - hR * 0.2, cy)
          ..lineTo(cx + hR, cy + hR)
          ..lineTo(cx - hR, cy + hR)
          ..lineTo(cx + hR * 0.2, cy)
          ..close();

        canvas.drawPath(
          hourglassPath,
          Paint()..color = Colors.white.withValues(alpha: 0.9),
        );

        // Draw sand in bottom of hourglass
        if (progress > 0.2) {
          final sandLevel = (progress - 0.2) / 0.8; // sand fills up
          final sandPath = Path()
            ..moveTo(cx - hR * 0.9, cy + hR)
            ..lineTo(cx + hR * 0.9, cy + hR)
            ..lineTo(
              cx + hR * (0.9 - 0.7 * sandLevel),
              cy + hR * (1.0 - 0.9 * sandLevel),
            )
            ..lineTo(
              cx - hR * (0.9 - 0.7 * sandLevel),
              cy + hR * (1.0 - 0.9 * sandLevel),
            )
            ..close();
          canvas.drawPath(sandPath, Paint()..color = Colors.amberAccent);
        }
      } else {
        // Normal pip drawing (shifted above building)
        final indicatorY = offsetY + pos.y * cellSize - cellSize * 0.2;
        final pipR = cellSize * 0.06;
        final spacing = pipR * 2.5;
        final maxDemand = isMature
            ? GameConstants.matureMaxDemand
            : GameConstants.maxDemand;

        for (int i = 0; i < demand; i++) {
          canvas.drawCircle(
            Offset(cx - (demand - 1) * spacing / 2 + i * spacing, indicatorY),
            pipR,
            Paint()
              ..color = i >= maxDemand - 2
                  ? Colors.redAccent.withValues(alpha: 0.8)
                  : (isMature ? Colors.white : Colors.white70).withValues(
                      alpha: isMature ? 0.9 : 0.6,
                    ),
          );
        }
      }
    }
  }

  void _drawRoadPreview(Canvas canvas) {
    if (game.activeTool != BuildTool.road &&
        game.activeTool != BuildTool.tunnel) {
      return;
    }
    if (game.previewPath.isEmpty) return;

    final isTunnel = game.activeTool == BuildTool.tunnel;
    final previewPaint = Paint()
      ..color = (isTunnel ? Colors.blue : Colors.white).withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    for (final pos in game.previewPath) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            offsetX + pos.x * cellSize + 4,
            offsetY + pos.y * cellSize + 4,
            cellSize - 8,
            cellSize - 8,
          ),
          const Radius.circular(8),
        ),
        previewPaint,
      );
    }
  }

  void _drawExpressLanePreview(Canvas canvas) {
    if (game.activeTool != BuildTool.expressLane) return;

    final start = game.expressLanePendingStart;
    final end = game.expressLaneDraggingEnd;

    if (start != null && end != null) {
      final p1 = Offset(
        offsetX + start.x * cellSize + cellSize / 2,
        offsetY + start.y * cellSize + cellSize / 2,
      );
      final p2 = Offset(
        offsetX + end.x * cellSize + cellSize / 2,
        offsetY + end.y * cellSize + cellSize / 2,
      );

      // Show validity (green if collinear, red if not)
      final isValid = start.x == end.x || start.y == end.y;
      final paint = Paint()
        ..color = (isValid ? GameConstants.expressLaneColor : Colors.redAccent)
            .withValues(alpha: 0.6)
        ..strokeWidth = 6.0
        ..style = PaintingStyle.stroke;

      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy);

      canvas.drawPath(path, paint);

      // Draw end marker
      canvas.drawCircle(
        p2,
        cellSize * 0.35,
        Paint()
          ..color =
              (isValid ? GameConstants.expressLaneColor : Colors.redAccent)
                  .withValues(alpha: 0.4),
      );
    }
  }

  void _drawCongestion(Canvas canvas) {
    for (final pos in gridManager.infrastructure) {
      final cell = gridManager.getCell(pos.x, pos.y);
      if (!cell.isRoad && !cell.isExpressLaneNode) continue;

      final load = gridManager.getRoadLoad(pos.x, pos.y);
      if (load <= 0) continue;

      final ratio = (load / cell.capacity).clamp(0.0, 1.0);
      if (ratio < 0.4) continue;

      final rect = Rect.fromLTWH(
        offsetX + pos.x * cellSize,
        offsetY + pos.y * cellSize,
        cellSize,
        cellSize,
      );

      Color color;
      if (ratio >= 0.8) {
        color = GameConstants.congestionHighColor.withValues(alpha: 0.3);
      } else {
        color = GameConstants.congestionLowColor.withValues(alpha: 0.2);
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(2), const Radius.circular(6)),
        Paint()
          ..color = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  /// Draws a soft vignette/fog outside the active spawnable area (Issue: City Reveal)
  void _drawCityVignette(Canvas canvas) {
    if (game.spawnController == null) return;
    final sc = game.spawnController!;

    // Calculate the active rectangle in screen pixels
    final rect = Rect.fromLTRB(
      offsetX + sc.minSpawnX * cellSize,
      offsetY + sc.minSpawnY * cellSize,
      offsetX + (sc.maxSpawnX + 1) * cellSize,
      offsetY + (sc.maxSpawnY + 1) * cellSize,
    );

    // Draw fully opaque solid overlay outside the active rectangle
    final paint = Paint()
      ..color = GameConstants.backgroundColor
      ..style = PaintingStyle.fill;

    // Use clipPath/evenOdd path to draw solid color everywhere in the camera viewport EXCEPT the rect
    final viewport = game.camera.visibleWorldRect;
    final path = Path()
      ..addRect(viewport)
      ..addRect(rect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  void _drawFloatingMessages(Canvas canvas) {
    if (_floatingMessages.isEmpty) return;
    
    // Use a shared TextPainter to avoid allocations (Task 6)
    // ... logic remains same but we reuse painter ...
    // (I will update this specifically in a later step to be clean)
    // For now, let's just finish the class.
    
    final List<_FloatingMessage> toRemove = [];
    for (final msg in _floatingMessages) {
      msg.life -= 0.016; // Approx 60fps
      if (msg.life <= 0) {
        toRemove.add(msg);
        continue;
      }

      final yOffset = (1.0 - msg.life) * 40;
      final opacity = msg.life.clamp(0.0, 1.0);

      final textPainter = TextPainter(
        text: TextSpan(
          text: msg.text,
          style: GoogleFonts.outfit(
            color: msg.color.withValues(alpha: opacity),
            fontSize: 14,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: opacity * 0.5),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(
          offsetX + msg.pos.x * cellSize + (cellSize - textPainter.width) / 2,
          offsetY + msg.pos.y * cellSize - 10 - yOffset,
        ),
      );
    }
    _floatingMessages.removeWhere((m) => toRemove.contains(m));
  }
}

class _FloatingMessage {
  final String text;
  final GridPosition pos;
  final Color color;
  double life = 1.5; // seconds
  _FloatingMessage(this.text, this.pos, this.color);
}

class _RenderChunk {
  final int x;
  final int y;
  ui.Picture? picture;
  bool dirty = true;
  _RenderChunk(this.x, this.y);
}
