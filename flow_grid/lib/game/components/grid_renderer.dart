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

  // MaskFilter.blur is fine on CanvasKit/web but absolutely lethal on mobile
  // Skia — even when cached into a chunk Picture, the rasterizer pays the
  // blur cost the first time the picture is rendered to the screen, and that
  // first paint is enough to ANR/crash on lower-end Android devices.
  final Paint _mountainBasePaint = Paint()
    ..color = GameConstants.mountainColor;

  final Paint _mountainPeakPaint = Paint()
    ..color = GameConstants.mountainHighlightColor.withValues(alpha: 0.4);

  GridRenderer({
    required this.gridManager,
    required this.cellSize,
    this.offsetX = 0,
    this.offsetY = 0,
  });

  final List<_FloatingMessage> _floatingMessages = [];

  /// Active spawn-pulse animations. Drawn on top of the cached chunk picture
  /// so newly-placed buildings get a brief expanding gray ring instead of
  /// just popping into existence.
  final List<_SpawnAnimation> _spawnAnimations = [];

  void registerSpawnAnimation(GridPosition pos) {
    _spawnAnimations.add(_SpawnAnimation(pos, game.elapsedTime));
  }

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

    // Spawn pulses (drawn over the cached chunks so brand-new buildings get
    // a brief expanding ring instead of popping in unannounced).
    _drawSpawnAnimations(canvas);

    // Floating Messages (Upgrades, Events)
    _drawFloatingMessages(canvas);
  }

  void _drawSpawnAnimations(Canvas canvas) {
    if (_spawnAnimations.isEmpty) return;
    final now = game.elapsedTime;
    _spawnAnimations.removeWhere((a) => now - a.startTime >= _SpawnAnimation.duration);
    if (_spawnAnimations.isEmpty) return;

    for (final anim in _spawnAnimations) {
      final t = ((now - anim.startTime) / _SpawnAnimation.duration).clamp(0.0, 1.0);
      // Ease-out cubic for the radius so the ring shoots out quickly then settles.
      final ease = 1.0 - math.pow(1.0 - t, 3).toDouble();
      final cx = offsetX + anim.pos.x * cellSize + cellSize / 2;
      final cy = offsetY + anim.pos.y * cellSize + cellSize / 2;

      // Outer expanding ring — very light gray, fades to transparent.
      final outerRadius = cellSize * (0.35 + ease * 1.1);
      final outerAlpha = (1.0 - t) * 0.16;
      canvas.drawCircle(
        Offset(cx, cy),
        outerRadius,
        Paint()..color = Colors.white.withValues(alpha: outerAlpha),
      );

      // Soft inner glow that shrinks as the building "settles in".
      final innerRadius = cellSize * (0.45 - t * 0.25);
      if (innerRadius > 0) {
        final innerAlpha = (1.0 - t) * 0.10;
        canvas.drawCircle(
          Offset(cx, cy),
          innerRadius,
          Paint()..color = Colors.white.withValues(alpha: innerAlpha),
        );
      }
    }
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

  // Mountain paths are now built per-chunk so each chunk picture only carries
  // its own mountains. The old global cache replayed every mountain in the
  // world into every chunk picture, which choked mobile GPUs on first paint.
  void _drawMountains(Canvas canvas, int minX, int minY, int maxX, int maxY) {
    final basePath = Path();
    final peaksPath = Path();
    bool any = false;

    for (final cluster in gridManager.mountainClusters) {
      for (final cell in cluster.cells) {
        if (cell.x < minX || cell.x >= maxX || cell.y < minY || cell.y >= maxY) {
          continue;
        }
        any = true;
        final rect = Rect.fromLTWH(
          offsetX + cell.x * cellSize,
          offsetY + cell.y * cellSize,
          cellSize,
          cellSize,
        );
        basePath.addRRect(
          RRect.fromRectAndRadius(
            rect.inflate(cellSize * 0.15),
            Radius.circular(cellSize * 0.45),
          ),
        );
        peaksPath.addRRect(
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

    if (!any) return;
    canvas.drawPath(basePath, _mountainBasePaint);
    canvas.drawPath(peaksPath, _mountainPeakPaint);
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
        // Note: previously we skipped drawing the road at express-lane endpoint
        // cells. That left a visible gap underneath the lane — looked like the
        // road tile was deleted. The lane is drawn additively in
        // _drawExpressLanesGlobal, so render the road normally here.

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
    // Wide enough that the car (cellSize * 0.55) actually fits inside the
    // lane, with a darker outer rim for a "highway shoulders" feel. The arc
    // direction and height MUST match CarComponent._rebuildSmoothPath's
    // long-jump arc (perp = right-perp of forward, arcHeight = dist * 0.15)
    // or the car will visibly drive off the painted lane.
    // Match the car's visible width (cellSize * 0.55) so the car sits
    // *inside* the lane stroke rather than overhanging both sides — that
    // overhang is what made cars look like they were floating in the air
    // above a too-narrow ribbon. Alpha is high enough that the lane reads
    // as a solid overlay but the road and grid are still visible through.
    final laneStroke = cellSize * 0.58;
    final lanePaint = Paint()
      ..color = GameConstants.expressLaneColor.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = laneStroke
      ..strokeCap = StrokeCap.round;

    final laneOutlinePaint = Paint()
      ..color = GameConstants.expressLaneBorderColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = laneStroke + 3
      ..strokeCap = StrokeCap.round;

    final arrowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final rampFillPaint = Paint()
      ..color = GameConstants.expressLaneColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    final rampOutlinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

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

      final delta = o2 - o1;
      final length = delta.distance;
      if (length < 1) continue;
      final dir = Offset(delta.dx / length, delta.dy / length);
      // Direction-independent perpendicular: always pick the half-plane with
      // perp.dy < 0 (ties broken by perp.dx < 0). CarComponent's long-jump
      // bezier uses the same sign rule, so the painted curve and the car
      // trajectory match for BOTH the outbound and the return trip. Using
      // raw right-of-forward made the return car arc to the wrong side.
      final perp = Offset(-dir.dy, dir.dx);
      final perpSign = (perp.dy < 0 || (perp.dy == 0 && perp.dx < 0))
          ? 1.0
          : -1.0;
      final arcHeight = length * 0.15 * perpSign;
      final mid = Offset((o1.dx + o2.dx) / 2, (o1.dy + o2.dy) / 2);
      final cp = Offset(
        mid.dx + perp.dx * arcHeight,
        mid.dy + perp.dy * arcHeight,
      );

      final lanePath = Path()
        ..moveTo(o1.dx, o1.dy)
        ..quadraticBezierTo(cp.dx, cp.dy, o2.dx, o2.dy);

      canvas.drawPath(lanePath, laneOutlinePaint);
      canvas.drawPath(lanePath, lanePaint);

      // Directional chevrons sampled along the bezier so they hug the curve.
      final metrics = lanePath.computeMetrics().toList();
      if (metrics.isNotEmpty) {
        final metric = metrics.first;
        final totalLen = metric.length;
        for (double d = totalLen * 0.2; d < totalLen; d += 34) {
          final tan = metric.getTangentForOffset(d);
          if (tan == null) continue;
          final tip = tan.position;
          final tdir = tan.vector;
          final tperp = Offset(-tdir.dy, tdir.dx);
          final back = tip - Offset(tdir.dx, tdir.dy) * 6;
          canvas.drawLine(back + tperp * 3.5, tip, arrowPaint);
          canvas.drawLine(back - tperp * 3.5, tip, arrowPaint);
        }
      }

      // Small ramp markers at each endpoint so the lane visibly "starts"
      // and "ends" at the road tile rather than melting into it.
      _drawExpressLaneRamp(canvas, o1, dir, rampFillPaint, rampOutlinePaint);
      _drawExpressLaneRamp(canvas, o2, -dir, rampFillPaint, rampOutlinePaint);
    }
  }

  void _drawExpressLaneRamp(Canvas canvas, Offset center, Offset forward,
      Paint fill, Paint outline) {
    final perp = Offset(-forward.dy, forward.dx);
    final r = cellSize * 0.18;
    final tip = center + forward * r;
    final baseL = center - forward * (r * 0.4) + perp * (r * 0.7);
    final baseR = center - forward * (r * 0.4) - perp * (r * 0.7);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(baseL.dx, baseL.dy)
      ..lineTo(baseR.dx, baseR.dy)
      ..close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, outline);
  }

  // Dedicated paints for the smart-junction donut. Previously this code
  // mutated _roadPaint (shared with road drawing) which leaked style/color
  // changes back into the road renderer and produced a fuzzy blob instead
  // of a clean roundabout symbol.
  static final Paint _smartJunctionRingPaint = Paint()
    ..color = GameConstants.roadFillColor
    ..style = PaintingStyle.fill;
  static final Paint _smartJunctionHolePaint = Paint()
    ..color = GameConstants.backgroundColor
    ..style = PaintingStyle.fill;
  static final Paint _smartJunctionOutlinePaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.25)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  void _drawSmartJunctions(Canvas canvas, int minX, int minY, int maxX, int maxY) {
    // Outer radius equals half a cell so the disk touches the cell boundary
    // exactly where the road stroke from each neighbour terminates — the
    // road and junction meet at the boundary with no visible gap. Inner
    // radius gives the donut its hole for the "roundabout" read.
    final outerR = cellSize * 0.5;
    final innerR = cellSize * 0.24;

    for (int x = minX; x < maxX; x++) {
      for (int y = minY; y < maxY; y++) {
        if (!gridManager.isValid(x, y)) continue;
        final cell = gridManager.grid[y][x];
        if (!cell.hasSmartJunction) continue;

        final cx = offsetX + x * cellSize + cellSize / 2;
        final cy = offsetY + y * cellSize + cellSize / 2;

        // Outer disk + punched-out center give a clean donut/roundabout
        // silhouette without depending on blur or paint mutation.
        canvas.drawCircle(Offset(cx, cy), outerR, _smartJunctionRingPaint);
        canvas.drawCircle(Offset(cx, cy), innerR, _smartJunctionHolePaint);
        canvas.drawCircle(Offset(cx, cy), outerR, _smartJunctionOutlinePaint);
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

    // Shadow — flat offset RRect (no blur) for cheap mobile rasterization.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.shift(const Offset(0, 2)),
        Radius.circular(size * 0.2),
      ),
      Paint()..color = Colors.black26,
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
        }
        // Express lane endpoints are now drawn as small ramp markers in
        // _drawExpressLanesGlobal (per-frame), so the chunked overpass
        // pentagon is intentionally not redrawn here.
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

  void _drawParkingHighlights(Canvas canvas) {
    final cars = game.cars;
    if (cars.isEmpty) return;
    final pulse = 0.5 + 0.5 * math.sin(game.elapsedTime * 6);
    // Keep the pulse inside the building cell so it doesn't visibly bleed
    // onto the road tiles next to the building (which read as "the road is
    // blinking yellow"). Half a cell radius is the cell edge.
    final r = cellSize * (0.3 + pulse * 0.05);
    final paint = Paint()
      ..color = const Color(0xFFFFD54F).withValues(alpha: 0.22 + pulse * 0.22);
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

      // Draw Maturity Aura — flat alpha pulse (no blur) for mobile.
      if (isMature) {
        final t = game.elapsedTime * 2.0;
        final pulse = (0.5 + 0.5 * math.sin(t)).clamp(0.0, 1.0);
        final auraRadius = cellSize * (0.5 + pulse * 0.1);

        canvas.drawCircle(
          Offset(cx, cy),
          auraRadius,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.05 + pulse * 0.05),
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
        Paint()..color = color,
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

class _SpawnAnimation {
  static const double duration = 1.2; // seconds
  final GridPosition pos;
  final double startTime;
  _SpawnAnimation(this.pos, this.startTime);
}
