import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../models/game_constants.dart';
import '../../models/grid_cell.dart';
import '../grid_manager.dart';
import '../flow_grid_game.dart';
import '../spawn_controller.dart';

class GridRenderer extends PositionComponent
    with HasGameReference<FlowGridGame> {
  final GridManager gridManager;
  double cellSize;
  double offsetX;
  double offsetY;

  ui.Picture? _staticPicture;
  ui.Picture? _dynamicPicture;
  bool _dynamicDirty = true;

  GridRenderer({
    required this.gridManager,
    required this.cellSize,
    this.offsetX = 0,
    this.offsetY = 0,
  });

  void markDirty() {
    _dynamicDirty = true;
  }

  @override
  void render(Canvas canvas) {
    _staticPicture ??= _buildStaticPicture();
    canvas.drawPicture(_staticPicture!);

    if (_dynamicDirty) {
      _dynamicPicture = _buildDynamicPicture();
      _dynamicDirty = false;
    }
    if (_dynamicPicture != null) {
      canvas.drawPicture(_dynamicPicture!);
    }

    // [NEW] City Reveal Vignette
    _drawCityVignette(canvas);

    // [NEW] Debug Overlay (Issue: Verification)
    // if (game.showDebugOverlay) {
    //   _drawDebugOverlay(canvas);
    // }
  }

  ui.Picture _buildStaticPicture() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawRect(
      Rect.fromLTWH(
        offsetX,
        offsetY,
        gridManager.cols * cellSize,
        gridManager.rows * cellSize,
      ),
      Paint()..color = GameConstants.backgroundColor,
    );


    /*
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
    */

    return recorder.endRecording();
  }

  ui.Picture _buildDynamicPicture() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    _drawMountains(canvas);
    _drawRoadsAndExpressLanes(canvas);
    _drawSmartJunctions(canvas);
    _drawBuildings(canvas);
    _drawInfrastructure(canvas);
    _drawDemandIndicators(canvas);
    _drawExpressLanePreview(canvas);
    _drawRoadPreview(canvas);
    // _drawEntryHelpers(canvas);
    _drawCongestion(canvas);

    
    // print("LOG: road redraw triggered");

    return recorder.endRecording();
  }

  Path? _mountainPathCache;
  Path? _mountainPeaksCache;

  void _drawMountains(Canvas canvas) {
    if (_mountainPathCache == null) {
      _mountainPathCache = Path();
      _mountainPeaksCache = Path();
      
      for (final cluster in gridManager.mountainClusters) {
        // Create a single unified path for the cluster to avoid "gaps"
        for (final cell in cluster.cells) {
          final rect = Rect.fromLTWH(
            offsetX + cell.x * cellSize,
            offsetY + cell.y * cellSize,
            cellSize,
            cellSize,
          );
          
          // Outer blob (overlapping to fill gaps)
          _mountainPathCache!.addRRect(
            RRect.fromRectAndRadius(
              rect.inflate(cellSize * 0.15), // Inflate more to overlap
              Radius.circular(cellSize * 0.45),
            ),
          );

          // Peaks (inner lighter blobs)
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

    final darkBasePaint = Paint()
      ..color = GameConstants.mountainColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
    
    final peakPaint = Paint()
      ..color = GameConstants.mountainHighlightColor.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

    canvas.drawPath(_mountainPathCache!, darkBasePaint);
    canvas.drawPath(_mountainPeaksCache!, peakPaint);
  }

  void _drawRoadsAndExpressLanes(Canvas canvas) {
    final rw = cellSize * 0.4; // Strict road width (0.4 * tileSize)

    // Separate paths for roads and bridges
    final roadPath = Path();
    final tunnelPath = Path();

    for (int y = 0; y < gridManager.rows; y++) {
      for (int x = 0; x < gridManager.cols; x++) {
        final cell = gridManager.getCell(x, y);
        if ((!cell.isRoad && !cell.isExpressLaneNode) || cell.isPendingDeletion) continue;

        // Rule 4: Do not render road + express simultaneously
        if (cell.isExpressLane && (cell.type == CellType.road || cell.type == CellType.tunnel)) continue;

        final cx = offsetX + x * cellSize;
        final cy = offsetY + y * cellSize;
        final midX = cx + cellSize / 2;
        final midY = cy + cellSize / 2;

        final n = cell.connUp;
        final e = cell.connRight;
        final s = cell.connDown;
        final w = cell.connLeft;

        final targetPath = cell.type == CellType.tunnel ? tunnelPath : roadPath;
        int connCount = (n ? 1 : 0) + (e ? 1 : 0) + (s ? 1 : 0) + (w ? 1 : 0);

        if (connCount == 1) {
          targetPath.moveTo(midX, midY);
          if (n) targetPath.lineTo(midX, cy);
          if (e) targetPath.lineTo(cx + cellSize, midY);
          if (s) targetPath.lineTo(midX, cy + cellSize);
          if (w) targetPath.lineTo(cx, midY);
        } else if (connCount == 2) {
          if (n && s) {
            // Vertical straight
            targetPath.moveTo(midX, cy);
            targetPath.lineTo(midX, cy + cellSize);
          } else if (e && w) {
            // Horizontal straight
            targetPath.moveTo(cx, midY);
            targetPath.lineTo(cx + cellSize, midY);
          } else {
            // Corner Curve (90 deg arc)
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
        } else {
          // Junctions (T or Cross) - Star pattern with rounded center for "curved" look
          final r = cellSize * 0.5;
          // Draw the main straight lines if applicable
          if (n && s) {
            targetPath.moveTo(midX, cy);
            targetPath.lineTo(midX, cy + cellSize);
          } else if (n) {
            targetPath.moveTo(midX, cy);
            targetPath.lineTo(midX, midY);
          } else if (s) {
            targetPath.moveTo(midX, midY);
            targetPath.lineTo(midX, cy + cellSize);
          }

          if (e && w) {
            targetPath.moveTo(cx, midY);
            targetPath.lineTo(cx + cellSize, midY);
          } else if (e) {
            targetPath.moveTo(midX, midY);
            targetPath.lineTo(cx + cellSize, midY);
          } else if (w) {
            targetPath.moveTo(cx, midY);
            targetPath.lineTo(midX, midY);
          }

          // Add small rounding arcs at the junction center for the "curved" look
          if (n && e) {
            targetPath.moveTo(midX, midY - r * 0.2);
            targetPath.quadraticBezierTo(midX, midY, midX + r * 0.2, midY);
          }
          if (e && s) {
            targetPath.moveTo(midX + r * 0.2, midY);
            targetPath.quadraticBezierTo(midX, midY, midX, midY + r * 0.2);
          }
          if (s && w) {
            targetPath.moveTo(midX, midY + r * 0.2);
            targetPath.quadraticBezierTo(midX, midY, midX - r * 0.2, midY);
          }
          if (w && n) {
            targetPath.moveTo(midX - r * 0.2, midY);
            targetPath.quadraticBezierTo(midX, midY, midX, midY - r * 0.2);
          }
        }
      }
    }
    
    final roadPaint = Paint()
      ..color = GameConstants.roadFillColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = rw;

    final tunnelPaint = Paint()
      ..color = GameConstants.tunnelColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = rw;

    canvas.drawPath(tunnelPath, tunnelPaint);
    canvas.drawPath(roadPath, roadPaint);

    // 2. Draw Permanent Express Lanes (Top Layer)
    _drawPermanentExpressLanes(canvas);

    // 3. Draw tunnel entrance arches
    /*
    for (final pos in gridManager.infrastructure) {
      final cell = gridManager.getCell(pos.x, pos.y);
      if (cell.type != CellType.tunnel) continue;
      final cx = offsetX + pos.x * cellSize + cellSize / 2;
      final cy = offsetY + pos.y * cellSize + cellSize / 2;
      final archPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: cellSize * 0.5,
          height: cellSize * 0.5,
        ),
        0,
        pi,
        false,
        archPaint,
      );
    }
    */
  }

  void _drawPermanentExpressLanes(Canvas canvas) {
    final rw = (cellSize * 0.4) * 0.8; // Rule 2: Thinner than roads (0.8x)
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

      // Draw thin border then subtle green fill (Rule 3)
      canvas.drawLine(o1, o2, borderPaint);
      canvas.drawLine(o1, o2, lanePaint);

      // Rule 3: Directional Arrows (Subtle)
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

  void _drawSmartJunctions(Canvas canvas) {
    final ringPaint = Paint()
      ..color = GameConstants.roadFillColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final islandPaint = Paint()
      ..color = GameConstants.backgroundColor
      ..style = PaintingStyle.fill;

    for (final pos in gridManager.infrastructure) {
      final cell = gridManager.getCell(pos.x, pos.y);
      if (cell.type != CellType.smartJunction) continue;

      final cx = offsetX + pos.x * cellSize + cellSize / 2;
      final cy = offsetY + pos.y * cellSize + cellSize / 2;
      final radius = cellSize * 0.45;

      // 1. Draw Tangential "Flares" to connect roads smoothly
      final flarePaint = Paint()..color = GameConstants.roadFillColor;
      final flareSize = cellSize * 0.4;

      if (cell.connUp) {
        final p = Path()
          ..moveTo(cx - flareSize / 2, cy - radius)
          ..lineTo(cx + flareSize / 2, cy - radius)
          ..lineTo(cx + flareSize / 2, cy - cellSize / 2)
          ..lineTo(cx - flareSize / 2, cy - cellSize / 2)
          ..close();
        canvas.drawPath(p, flarePaint);
      }
      if (cell.connRight) {
        final p = Path()
          ..moveTo(cx + radius, cy - flareSize / 2)
          ..lineTo(cx + radius, cy + flareSize / 2)
          ..lineTo(cx + cellSize / 2, cy + flareSize / 2)
          ..lineTo(cx + cellSize / 2, cy - flareSize / 2)
          ..close();
        canvas.drawPath(p, flarePaint);
      }
      if (cell.connDown) {
        final p = Path()
          ..moveTo(cx - flareSize / 2, cy + radius)
          ..lineTo(cx + flareSize / 2, cy + radius)
          ..lineTo(cx + flareSize / 2, cy + cellSize / 2)
          ..lineTo(cx - flareSize / 2, cy + cellSize / 2)
          ..close();
        canvas.drawPath(p, flarePaint);
      }
      if (cell.connLeft) {
        final p = Path()
          ..moveTo(cx - radius, cy - flareSize / 2)
          ..lineTo(cx - radius, cy + flareSize / 2)
          ..lineTo(cx - cellSize / 2, cy + flareSize / 2)
          ..lineTo(cx - cellSize / 2, cy - flareSize / 2)
          ..close();
        canvas.drawPath(p, flarePaint);
      }

      // 2. Main circular ring
      canvas.drawCircle(Offset(cx, cy), radius, ringPaint);
      canvas.drawCircle(Offset(cx, cy), radius, borderPaint);

      // 3. Inner island
      canvas.drawCircle(Offset(cx, cy), radius * 0.45, islandPaint);
      canvas.drawCircle(Offset(cx, cy), radius * 0.45, borderPaint);

      // 4. Clockwise flow markers (subtle dashes)

      /*
      for (int i = 0; i < 4; i++) {
        final angle = i * pi / 2 + pi / 4;
        final start = Offset(
          cx + cos(angle) * radius * 0.7,
          cy + sin(angle) * radius * 0.7,
        );
        final end = Offset(
          cx + cos(angle + 0.3) * radius * 0.7,
          cy + sin(angle + 0.3) * radius * 0.7,
        );
        canvas.drawLine(start, end, markerPaint);
      }
      */
    }
  }

  void _drawBuildings(Canvas canvas) {
    final drivewayPaint = Paint()
      ..color = GameConstants.roadFillColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = cellSize * 0.4
      ..strokeCap = StrokeCap.round;

    // First draw all driveway stubs (under buildings)
    for (int y = 0; y < gridManager.rows; y++) {
      for (int x = 0; x < gridManager.cols; x++) {
        final cell = gridManager.getCell(x, y);
        if (!cell.isHouse && !cell.isDestination) continue;

        final cx = offsetX + x * cellSize + cellSize / 2;
        final cy = offsetY + y * cellSize + cellSize / 2;

        final entryDir = cell.entrySide;
        if (entryDir != null) {
          final stubPath = Path();
          // Start the stub at the boundary of the building body (not the center)
          // Body size is cellSize * 0.45, so radius is 0.225
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
      }
    }

    // Then draw building bodies
    for (int y = 0; y < gridManager.rows; y++) {
      for (int x = 0; x < gridManager.cols; x++) {
        final cell = gridManager.getCell(x, y);
        if (!cell.isHouse && !cell.isDestination) continue;

        final cx = offsetX + x * cellSize + cellSize / 2;
        final cy = offsetY + y * cellSize + cellSize / 2;
        final color = GameConstants.buildingColors[cell.colorIndex ?? 0];

        if (cell.isHouse) {
          _drawHouse(canvas, cx, cy, color, BuildingProfile.residential.renderScale);
        } else {
          _drawDestination(canvas, cx, cy, color, cell.entrySide!, BuildingProfile.commercial.renderScale);
        }
      }
    }
  }

  void _drawHouse(Canvas canvas, double cx, double cy, Color color, double scale) {
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
  }

  void _drawDestination(
    Canvas canvas,
    double cx,
    double cy,
    Color color,
    Direction entry,
    double scale,
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
  }

  void _drawInfrastructure(Canvas canvas) {
    // Traffic Lights
    for (final pos in gridManager.infrastructure) {
      final x = pos.x;
      final y = pos.y;
      final cell = gridManager.getCell(x, y);
      if (cell.hasTrafficLight) {
        final opacity = cell.isPendingDeletion ? 0.3 : 1.0;
        // Shift slightly to the side to avoid "disconnecting" the road visually
        final cx = offsetX + x * cellSize + cellSize * 0.7; // Right side of tile
        final cy = offsetY + y * cellSize + cellSize * 0.5;

        // Traffic light housing (pill shape)
        final pillW = cellSize * 0.16;
        final pillH = cellSize * 0.38;
        
        // Base/Pole
        canvas.drawRect(
          Rect.fromLTWH(cx - 1, cy + pillH * 0.2, 2, cellSize * 0.3),
          Paint()..color = Colors.black45.withValues(alpha: opacity),
        );

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(cx, cy),
              width: pillW,
              height: pillH,
            ),
            Radius.circular(pillW / 2),
          ),
          Paint()..color = Colors.black87.withValues(alpha: opacity),
        );

        // Glow effect
        final glowPaint = Paint()
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

        // Red dot (top)
        final redActive = !gridManager.isGreenForDirection(x, y, Direction.north); 
        final redColor = redActive ? Colors.redAccent : Colors.red.withValues(alpha: 0.2);
        
        canvas.drawCircle(
          Offset(cx, cy - pillH * 0.22),
          pillW * 0.35,
          Paint()..color = redColor.withValues(alpha: opacity),
        );

        // Green dot (bottom)
        final greenColor = !redActive ? Colors.greenAccent : Colors.green.withValues(alpha: 0.2);
        canvas.drawCircle(
          Offset(cx, cy + pillH * 0.22),
          pillW * 0.35,
          Paint()..color = greenColor.withValues(alpha: opacity),
        );

        canvas.drawCircle(
          Offset(cx, cy + pillH * 0.22),
          pillW * 0.45,
          glowPaint..color = greenColor.withValues(alpha: 0.3 * opacity),
        );
      } else if (cell.overpass == OverpassType.start ||
          cell.overpass == OverpassType.end) {
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

        canvas.drawPath(
          path,
          Paint()
            ..color = GameConstants.expressLaneColor.withValues(alpha: opacity),
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.8 * opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );

        /*
        final textPainter = TextPainter(
          text: TextSpan(
            text: 'E',
            style: TextStyle(
              color: Colors.white.withValues(alpha: opacity),
              fontSize: cellSize * 0.4,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          Offset(cx - textPainter.width / 2, cy - textPainter.height / 2),
        );
        */
      }
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
        final maxDemand = isMature ? GameConstants.matureMaxDemand : GameConstants.maxDemand;

        for (int i = 0; i < demand; i++) {
          canvas.drawCircle(
            Offset(cx - (demand - 1) * spacing / 2 + i * spacing, indicatorY),
            pipR,
            Paint()
              ..color = i >= maxDemand - 2
                  ? Colors.redAccent.withValues(alpha: 0.8)
                  : (isMature ? Colors.white : Colors.white70).withValues(alpha: isMature ? 0.9 : 0.6),
          );
        }
      }
    }
  }

  void _drawRoadPreview(Canvas canvas) {
    if (game.activeTool != BuildTool.road && game.activeTool != BuildTool.tunnel) return;
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
          ..color = (isValid ? GameConstants.expressLaneColor : Colors.redAccent)
                  .withValues(alpha: 0.4),
      );
      
      // LOG: Preview active
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
        RRect.fromRectAndRadius(
          rect.deflate(2),
          const Radius.circular(6),
        ),
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

    // Draw dark overlay outside the active rectangle
    final paint = Paint()
      ..color = GameConstants.backgroundColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;

    // We can use clipPath to draw everywhere EXCEPT the rect
    final path = Path()
      ..addRect(Rect.fromLTWH(offsetX, offsetY, gridManager.cols * cellSize, gridManager.rows * cellSize))
      ..addRect(rect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Inner soft glow/border for the reveal area
    canvas.drawRect(
      rect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  /// Visualizes playable bounds, mountain center, and cursor for verification (Issue: Debug Overlay)
  void _drawDebugOverlay(Canvas canvas) {
    if (game.spawnController == null) return;
    final sc = game.spawnController!;

    // 1. Red Rectangle: Playable Bounds
    final playableRect = Rect.fromLTRB(
      offsetX + sc.minSpawnX * cellSize,
      offsetY + sc.minSpawnY * cellSize,
      offsetX + (sc.maxSpawnX + 1) * cellSize,
      offsetY + (sc.maxSpawnY + 1) * cellSize,
    );
    canvas.drawRect(
      playableRect,
      Paint()
        ..color = Colors.red.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // 2. White Dashed Line: Mountain Center
    final mountainX = gridManager.mountainX;
    final mx = offsetX + mountainX * cellSize + cellSize / 2;
    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    // Draw simple dashed line
    double dashHeight = 10;
    double gapHeight = 5;
    for (double y = offsetY; y < offsetY + gridManager.rows * cellSize; y += dashHeight + gapHeight) {
      canvas.drawLine(Offset(mx, y), Offset(mx, y + dashHeight), dashPaint);
    }

    // 3. Green Dot: Cursor World Position
    canvas.drawCircle(
      Offset(game.lastMousePosWorld.x, game.lastMousePosWorld.y),
      4.0,
      Paint()..color = Colors.green,
    );

    // 4. Yellow Highlight: Target Grid Cell
    if (game.lastHoverPos != null) {
      final h = game.lastHoverPos!;
      canvas.drawRect(
        Rect.fromLTWH(offsetX + h.x * cellSize, offsetY + h.y * cellSize, cellSize, cellSize),
        Paint()..color = Colors.yellow.withValues(alpha: 0.2),
      );
    }
  }
}
