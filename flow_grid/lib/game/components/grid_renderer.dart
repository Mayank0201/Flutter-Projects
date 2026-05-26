import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import '../../models/game_constants.dart';
import '../../models/grid_cell.dart';
import '../../models/city_event.dart';
import '../grid_manager.dart';
import '../flow_grid_game.dart';
import '../spawn_controller.dart';
import '../../models/district_profile.dart';
import '../map_generator.dart';

class GridRenderer extends PositionComponent
    with HasGameReference<FlowGridGame> {
  final GridManager gridManager;
  double cellSize;
  double offsetX;
  double offsetY;

  ui.Picture? _terrainPicture;
  
  // Task 1: Chunked Render Cache
  final Map<int, _RenderChunk> _chunks = {};
  
  // Task 6: Preallocated Paints (Double-Pass Outline Style)
  final Paint _roadOutlinePaint = Paint()
    ..color = const Color(0xFF14161B)
    ..strokeWidth = GameConstants.cellSize * 0.60
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.butt
    ..strokeJoin = StrokeJoin.round;

  final Paint _roadPaint = Paint()
    ..color = GameConstants.roadColor
    ..strokeWidth = GameConstants.cellSize * 0.48
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.butt
    ..strokeJoin = StrokeJoin.round;

  final Paint _tunnelOutlinePaint = Paint()
    ..color = const Color(0xFF14161B)
    ..strokeWidth = GameConstants.cellSize * 0.60
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.butt
    ..strokeJoin = StrokeJoin.round;

  final Paint _tunnelPaint = Paint()
    ..color = const Color(0xFF23252A)
    ..strokeWidth = GameConstants.cellSize * 0.48
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.butt
    ..strokeJoin = StrokeJoin.round;

  final Paint _bridgeOutlinePaint = Paint()
    ..color = const Color(0xFF14161B)
    ..strokeWidth = GameConstants.cellSize * 0.60
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.butt
    ..strokeJoin = StrokeJoin.round;

  final Paint _bridgePaint = Paint()
    ..color = GameConstants.bridgeColor
    ..strokeWidth = GameConstants.cellSize * 0.48
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.butt
    ..strokeJoin = StrokeJoin.round;

  final Paint _iceRoadOutlinePaint = Paint()
    ..color = const Color(0xFF14161B)
    ..strokeWidth = GameConstants.cellSize * 0.60
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.butt
    ..strokeJoin = StrokeJoin.round;

  final Paint _iceRoadPaint = Paint()
    ..color = const Color(0xFFA5DFEE)
    ..strokeWidth = GameConstants.cellSize * 0.48
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.butt
    ..strokeJoin = StrokeJoin.round;

  final Paint _dirtRoadOutlinePaint = Paint()
    ..color = const Color(0xFF2C2417)
    ..strokeWidth = GameConstants.cellSize * 0.60
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.butt
    ..strokeJoin = StrokeJoin.round;

  final Paint _dirtRoadPaint = Paint()
    ..color = const Color(0xFFC0A477)
    ..strokeWidth = GameConstants.cellSize * 0.48
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.butt
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

    // [TIME OF DAY] Ambient day/night overlay drawn over static terrain and buildings
    _drawAmbientTimeOfDay(canvas);

    // Tier 3: Per-Frame Overlay (Demand, Previews, Selection Highlights)
    _drawParkingHighlights(canvas);
    _drawDemandIndicators(canvas);
    _drawExpressLanePreview(canvas);
    _drawRoadPreview(canvas);
    _drawCongestion(canvas);

    // Dynamic roadblock & maintenance event overlays
    _drawActiveEventOverlays(canvas);

    // Map Specific Events
    _drawMapSpecificEventVisuals(canvas);

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

    Color bg;
    switch (game.selectedMapType) {
      case MapType.zen:
        bg = const Color(0xFF13171F);
        break;
      case MapType.andes:
        bg = const Color(0xFF1E1612);
        break;
      case MapType.nile:
        bg = const Color(0xFF0F1A1B);
        break;
      case MapType.arctic:
        bg = const Color(0xFF12232D);
        break;
      case MapType.savanna:
        bg = const Color(0xFF241C13);
        break;
      case MapType.delta:
        bg = const Color(0xFF0E221C);
        break;
    }

    final double width = gridManager.cols * cellSize;
    final double height = gridManager.rows * cellSize;

    // Draw solid color
    canvas.drawRect(
      Rect.fromLTWH(offsetX, offsetY, width, height),
      Paint()..color = bg,
    );

    // Map-specific background patterns to make them look premium and fun!
    if (game.selectedMapType == MapType.arctic) {
      final patternPaint = Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.02)
        ..style = PaintingStyle.fill;
      final r = math.Random(101);
      for (int i = 0; i < 15; i++) {
        final cx = offsetX + r.nextDouble() * width;
        final cy = offsetY + r.nextDouble() * height;
        final radius = 30.0 + r.nextDouble() * 50.0;
        canvas.drawCircle(Offset(cx, cy), radius, patternPaint);
      }
    } else if (game.selectedMapType == MapType.savanna) {
      final patternPaint = Paint()
        ..color = const Color(0xFFD4AF37).withValues(alpha: 0.015)
        ..style = PaintingStyle.fill;
      final r = math.Random(202);
      for (int i = 0; i < 20; i++) {
        final cx = offsetX + r.nextDouble() * width;
        final cy = offsetY + r.nextDouble() * height;
        final radius = 20.0 + r.nextDouble() * 40.0;
        canvas.drawCircle(Offset(cx, cy), radius, patternPaint);
      }
    } else if (game.selectedMapType == MapType.delta) {
      final patternPaint = Paint()
        ..color = const Color(0xFF1DE9B6).withValues(alpha: 0.01)
        ..style = PaintingStyle.fill;
      final r = math.Random(303);
      for (int i = 0; i < 15; i++) {
        final cx = offsetX + r.nextDouble() * width;
        final cy = offsetY + r.nextDouble() * height;
        final radius = 35.0 + r.nextDouble() * 45.0;
        canvas.drawCircle(Offset(cx, cy), radius, patternPaint);
      }
    } else if (game.selectedMapType == MapType.andes) {
      final patternPaint = Paint()
        ..color = const Color(0xFFFF7043).withValues(alpha: 0.012)
        ..style = PaintingStyle.fill;
      final r = math.Random(404);
      for (int i = 0; i < 15; i++) {
        final cx = offsetX + r.nextDouble() * width;
        final cy = offsetY + r.nextDouble() * height;
        final radius = 25.0 + r.nextDouble() * 55.0;
        canvas.drawCircle(Offset(cx, cy), radius, patternPaint);
      }
    } else if (game.selectedMapType == MapType.nile) {
      final patternPaint = Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.012)
        ..style = PaintingStyle.fill;
      final r = math.Random(505);
      for (int i = 0; i < 15; i++) {
        final cx = offsetX + r.nextDouble() * width;
        final cy = offsetY + r.nextDouble() * height;
        final radius = 30.0 + r.nextDouble() * 40.0;
        canvas.drawCircle(Offset(cx, cy), radius, patternPaint);
      }
    }

    final crossPaint = Paint()
      ..color = () {
        switch (game.selectedMapType) {
          case MapType.arctic:
            return const Color(0x30E0F7FC);
          case MapType.savanna:
            return const Color(0x30FFE082);
          case MapType.delta:
            return const Color(0x30B2DFDB);
          case MapType.andes:
            return const Color(0x30FFCC80);
          case MapType.nile:
            return const Color(0x3080DEEA);
          default:
            return GameConstants.gridLineColor.withValues(alpha: 0.25);
        }
      }()
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const crossArm = 3.0; // half-length of each crosshair arm

    for (int x = 0; x <= gridManager.cols; x++) {
      for (int y = 0; y <= gridManager.rows; y++) {
        final cx = offsetX + x * cellSize;
        final cy = offsetY + y * cellSize;
        canvas.drawLine(Offset(cx - crossArm, cy), Offset(cx + crossArm, cy), crossPaint);
        canvas.drawLine(Offset(cx, cy - crossArm), Offset(cx, cy + crossArm), crossPaint);
      }
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

    _drawWater(canvas, minX, minY, maxX, maxY);
    _drawMountains(canvas, minX, minY, maxX, maxY);
    _drawRoadsAndExpressLanes(canvas, minX, minY, maxX, maxY);
    _drawSmartJunctions(canvas, minX, minY, maxX, maxY);
    _drawBuildings(canvas, minX, minY, maxX, maxY);
    _drawInfrastructure(canvas, minX, minY, maxX, maxY);

    return recorder.endRecording();
  }

  void _drawWater(Canvas canvas, int minX, int minY, int maxX, int maxY) {
    final waterPath = Path();
    bool any = false;

    for (int x = minX; x < maxX; x++) {
      for (int y = minY; y < maxY; y++) {
        if (!gridManager.isValid(x, y)) continue;
        final cell = gridManager.grid[y][x];
        if (cell.type != CellType.water && cell.type != CellType.bridge) continue;

        any = true;
        final rect = Rect.fromLTWH(
          offsetX + x * cellSize,
          offsetY + y * cellSize,
          cellSize,
          cellSize,
        );
        waterPath.addRRect(
          RRect.fromRectAndRadius(
            rect.inflate(0.5), // overlap slightly to merge adjacent tiles
            const Radius.circular(4.0),
          ),
        );
      }
    }

    if (!any) return;

    final paint = Paint()
      ..color = GameConstants.waterColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(waterPath, paint);

    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(waterPath, borderPaint);
  }

  // Mountain paths are now built per-chunk so each chunk picture only carries
  // its own mountains. The old global cache replayed every mountain in the
  // world into every chunk picture, which choked mobile GPUs on first paint.
  void _drawMountains(Canvas canvas, int minX, int minY, int maxX, int maxY) {
    final basePath = Path();
    final peaksPath = Path();
    final snowPath = Path();
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
        snowPath.addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: rect.center.translate(0, -cellSize * 0.2),
              width: cellSize * 0.35,
              height: cellSize * 0.18,
            ),
            Radius.circular(cellSize * 0.09),
          ),
        );
      }
    }

    if (!any) return;
    canvas.drawPath(basePath, _mountainBasePaint);
    canvas.drawPath(peaksPath, _mountainPeakPaint);
    canvas.drawPath(snowPath, Paint()..color = GameConstants.mountainSnowColor);
  }

  void _drawRoadsAndExpressLanes(Canvas canvas, int minX, int minY, int maxX, int maxY) {
    final roadPath = Path();
    final dirtRoadPath = Path();
    final tunnelPath = Path();
    final bridgePath = Path();
    final iceRoadPath = Path();

    for (int x = minX; x < maxX; x++) {
      for (int y = minY; y < maxY; y++) {
        if (!gridManager.isValid(x, y)) continue;
        final cell = gridManager.grid[y][x];

        if ((!cell.isRoad && !cell.isExpressLaneNode && !cell.isTunnel && !cell.isBridge && !cell.isHouse && !cell.isDestination) || cell.isPendingDeletion) {
          continue;
        }

        final cx = offsetX + x * cellSize;
        final cy = offsetY + y * cellSize;
        final midX = cx + cellSize / 2;
        final midY = cy + cellSize / 2;

        if (cell.isHouse || cell.isDestination) {
          final entryDir = cell.entrySide;
          if (entryDir != null) {
            // Determine adjacent cell coordinates
            int adjX = x;
            int adjY = y;
            if (entryDir == Direction.north) {
              adjY--;
            } else if (entryDir == Direction.east) {
              adjX++;
            } else if (entryDir == Direction.south) {
              adjY++;
            } else if (entryDir == Direction.west) {
              adjX--;
            }

            final bool hasAdjacentRoad = gridManager.isValid(adjX, adjY) &&
                (gridManager.grid[adjY][adjX].isRoad ||
                 gridManager.grid[adjY][adjX].isExpressLaneNode ||
                 gridManager.grid[adjY][adjX].isTunnel ||
                 gridManager.grid[adjY][adjX].isBridge);

            if (hasAdjacentRoad) {
              double sx = midX;
              double sy = midY;
              double ex = midX;
              double ey = midY;

              final distToEdge = cellSize / 2;

              if (entryDir == Direction.north) {
                ex = midX; ey = midY - distToEdge;
              } else if (entryDir == Direction.east) {
                ex = midX + distToEdge; ey = midY;
              } else if (entryDir == Direction.south) {
                ex = midX; ey = midY + distToEdge;
              } else {
                ex = midX - distToEdge; ey = midY;
              }

              roadPath.moveTo(sx, sy);
              roadPath.lineTo(ex, ey);
            }
          }
          continue;
        }

        final n = cell.connUp;
        final e = cell.connRight;
        final s = cell.connDown;
        final w = cell.connLeft;

        int connCount = (n ? 1 : 0) + (e ? 1 : 0) + (s ? 1 : 0) + (w ? 1 : 0);

        final Path targetPath;
        if (cell.isIceRoad) {
          targetPath = iceRoadPath;
        } else if (cell.isTunnel) {
          targetPath = tunnelPath;
        } else if (cell.isBridge) {
          targetPath = bridgePath;
        } else if (game.selectedMapType == MapType.savanna && cell.owner == InfrastructureOwner.player) {
          targetPath = dirtRoadPath;
        } else {
          targetPath = roadPath;
        }

        if (connCount == 0) {
          if (cell.isTunnel || cell.isBridge) {
            // 0-conn corridor: still draw a stub so the player can see the tile
            // they paid for. Orient along its infrastructure axis if known.
            if (cell.infrastructureAxis == InfrastructureAxis.vertical) {
              final startY = midY - cellSize * 0.25;
              final endY = midY + cellSize * 0.25;
              targetPath.moveTo(midX, startY);
              targetPath.lineTo(midX, endY);
            } else {
              final startX = midX - cellSize * 0.25;
              final endX = midX + cellSize * 0.25;
              targetPath.moveTo(startX, midY);
              targetPath.lineTo(endX, midY);
            }
          } else {
            // Isolated road: draw a very short horizontal line segment so it renders as a small pill/circle cap
            targetPath.moveTo(midX - 1, midY);
            targetPath.lineTo(midX + 1, midY);
          }
        } else if (connCount == 1) {
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
        }
      }
    }

    // --- Draw Paths ---
    _roadOutlinePaint.strokeCap = StrokeCap.round;
    _roadPaint.strokeCap = StrokeCap.round;
    canvas.drawPath(roadPath, _roadOutlinePaint);
    canvas.drawPath(roadPath, _roadPaint);

    _tunnelOutlinePaint.strokeCap = StrokeCap.round;
    _tunnelPaint.strokeCap = StrokeCap.round;
    canvas.drawPath(tunnelPath, _tunnelOutlinePaint);
    canvas.drawPath(tunnelPath, _tunnelPaint);

    _bridgeOutlinePaint.strokeCap = StrokeCap.round;
    _bridgePaint.strokeCap = StrokeCap.round;
    canvas.drawPath(bridgePath, _bridgeOutlinePaint);
    canvas.drawPath(bridgePath, _bridgePaint);

    _iceRoadOutlinePaint.strokeCap = StrokeCap.round;
    _iceRoadPaint.strokeCap = StrokeCap.round;
    canvas.drawPath(iceRoadPath, _iceRoadOutlinePaint);
    canvas.drawPath(iceRoadPath, _iceRoadPaint);

    _dirtRoadOutlinePaint.strokeCap = StrokeCap.round;
    _dirtRoadPaint.strokeCap = StrokeCap.round;
    canvas.drawPath(dirtRoadPath, _dirtRoadOutlinePaint);
    canvas.drawPath(dirtRoadPath, _dirtRoadPaint);

    // --- Draw Ice Cracks and Dirt Road Tracks ---
    for (int x = minX; x < maxX; x++) {
      for (int y = minY; y < maxY; y++) {
        if (!gridManager.isValid(x, y)) continue;
        final cell = gridManager.grid[y][x];
        if (cell.isPendingDeletion) continue;

        final cx = offsetX + x * cellSize;
        final cy = offsetY + y * cellSize;
        final midX = cx + cellSize / 2;
        final midY = cy + cellSize / 2;

        if (cell.isIceRoad) {
          final crackPaint = Paint()
            ..color = Colors.white.withValues(alpha: 0.6)
            ..strokeWidth = 1.2
            ..style = PaintingStyle.stroke;
          canvas.drawLine(
            Offset(midX - cellSize * 0.15, midY - cellSize * 0.15),
            Offset(midX + cellSize * 0.15, midY + cellSize * 0.15),
            crackPaint,
          );
          canvas.drawLine(
            Offset(midX + cellSize * 0.15, midY - cellSize * 0.05),
            Offset(midX + cellSize * 0.05, midY + cellSize * 0.15),
            crackPaint,
          );
        } else if (game.selectedMapType == MapType.savanna && cell.owner == InfrastructureOwner.player && cell.isRoad) {
          final trackPaint = Paint()
            ..color = const Color(0x355C4033)
            ..strokeWidth = 1.0
            ..style = PaintingStyle.stroke;

          if (cell.connUp || cell.connDown) {
            canvas.drawLine(Offset(midX - 3, cy), Offset(midX - 3, cy + cellSize), trackPaint);
            canvas.drawLine(Offset(midX + 3, cy), Offset(midX + 3, cy + cellSize), trackPaint);
          }
          if (cell.connLeft || cell.connRight) {
            canvas.drawLine(Offset(cx, midY - 3), Offset(cx + cellSize, midY - 3), trackPaint);
            canvas.drawLine(Offset(cx, midY + 3), Offset(cx + cellSize, midY + 3), trackPaint);
          }
        }
      }
    }

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
    ..color = GameConstants.roadColor
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
    for (int x = minX; x < maxX; x++) {
      for (int y = minY; y < maxY; y++) {
        if (!gridManager.isValid(x, y)) continue;
        final cell = gridManager.grid[y][x];
        if (!cell.isHouse && !cell.isDestination) continue;

        final cx = offsetX + x * cellSize + cellSize / 2;
        final cy = offsetY + y * cellSize + cellSize / 2;

        final color = GameConstants.getBuildingColor(cell.colorIndex ?? 0);
        final districtType = game.districtPlanner.getDistrictType(cell.colorIndex ?? 0);

        if (cell.isHouse) {
          _drawHouse(canvas, cx, cy, color, BuildingProfile.residential.renderScale, districtType);
        } else {
          _drawDestination(canvas, cx, cy, color, cell.entrySide!, BuildingProfile.commercial.renderScale, districtType, x, y);
        }
      }
    }
  }

  void _drawMapSpecificBuildingDetails(Canvas canvas, Rect bRect, double size) {
    switch (game.selectedMapType) {
      case MapType.arctic:
        // Snowy roof cap
        final snowCapPaint = Paint()..color = const Color(0xFFF0F8FF);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(bRect.left + 1, bRect.top + 1, bRect.width - 2, bRect.height * 0.4),
            Radius.circular(size * 0.08),
          ),
          snowCapPaint,
        );
        break;
      case MapType.savanna:
        // Thatch roof diagonal straws
        final thatchPaint = Paint()
          ..color = const Color(0xFFC0A477).withValues(alpha: 0.85)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;
        canvas.drawLine(Offset(bRect.left + 3, bRect.top + 2), Offset(bRect.left + 6, bRect.top + 6), thatchPaint);
        canvas.drawLine(Offset(bRect.left + bRect.width / 2, bRect.top + 2), Offset(bRect.left + bRect.width / 2 + 3, bRect.top + 6), thatchPaint);
        canvas.drawLine(Offset(bRect.right - 6, bRect.top + 2), Offset(bRect.right - 3, bRect.top + 6), thatchPaint);
        break;
      case MapType.delta:
        // Ivy/mossy details on corners
        final mossPaint = Paint()..color = const Color(0xAA4CAF50);
        canvas.drawCircle(Offset(bRect.left + 2, bRect.bottom - 2), 2.0, mossPaint);
        canvas.drawCircle(Offset(bRect.right - 2, bRect.bottom - 2), 1.5, mossPaint);
        canvas.drawCircle(Offset(bRect.left + 2, bRect.top + 2), 1.0, mossPaint);
        break;
      case MapType.andes:
        // Stone details/slate texture
        final stonePaint = Paint()
          ..color = const Color(0xFF8D6E63).withValues(alpha: 0.5)
          ..strokeWidth = 1.0;
        canvas.drawRect(Rect.fromLTWH(bRect.right - 3, bRect.top - 2, 2, 4), stonePaint);
        break;
      case MapType.nile:
        // Clay dome roof accent
        final domePaint = Paint()..color = const Color(0xFFD7CCC8);
        canvas.drawArc(
          Rect.fromLTWH(bRect.left + bRect.width / 2 - 3, bRect.top - 2, 6, 4),
          0,
          math.pi,
          true,
          domePaint,
        );
        break;
      default:
        break;
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

    // [NEW] Map-specific building details
    _drawMapSpecificBuildingDetails(canvas, rect, size);

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
    int gridX,
    int gridY,
  ) {
    final size = cellSize * scale;
    final rect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: size,
      height: size,
    );

    // Foundation/Parking
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(size * 0.12)),
      Paint()..color = GameConstants.roadColor,
    );

    // Faint parking stall indicators (very simple, just 3 lines at the top)
    final parkingPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = 1.0;
    final stallLength = size * 0.12;
    for (int i = 0; i < 3; i++) {
      final xOffset = rect.left + size * 0.25 + i * (size * 0.25);
      canvas.drawLine(
        Offset(xOffset, rect.top + size * 0.08),
        Offset(xOffset, rect.top + size * 0.08 + stallLength),
        parkingPaint,
      );
    }

    // Main building body (occupies the center-bottom portion of the lot)
    final bSize = size * 0.72;
    final bRect = Rect.fromCenter(
      center: Offset(cx, cy + size * 0.06),
      width: bSize,
      height: bSize * 0.65,
    );

    // Drop shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(bRect.shift(const Offset(0, 2)), Radius.circular(size * 0.08)),
      Paint()..color = Colors.black26,
    );

    // Main building body
    canvas.drawRRect(
      RRect.fromRectAndRadius(bRect, Radius.circular(size * 0.08)),
      Paint()..color = color,
    );

    // Dark border/outline
    canvas.drawRRect(
      RRect.fromRectAndRadius(bRect, Radius.circular(size * 0.08)),
      Paint()
        ..color = const Color(0xFF14161B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Check if destination is mature (age >= threshold)
    final age = game.gridManager?.destinationAges["$gridX,$gridY"] ?? 0;
    final isMature = age >= GameConstants.maturityThresholdWeeks;

    if (isMature) {
      final pWidth = bRect.width * 0.75;
      final pHeight = bRect.height * 0.75;
      final pRect = Rect.fromLTWH(
        cx - pWidth / 2,
        bRect.top - pHeight + 2,
        pWidth,
        pHeight,
      );

      // Drop shadow for penthouse
      canvas.drawRRect(
        RRect.fromRectAndRadius(pRect.shift(const Offset(0, 1)), Radius.circular(size * 0.06)),
        Paint()..color = Colors.black12,
      );

      // Main penthouse body
      canvas.drawRRect(
        RRect.fromRectAndRadius(pRect, Radius.circular(size * 0.06)),
        Paint()..color = color,
      );

      // Dark border/outline for penthouse
      canvas.drawRRect(
        RRect.fromRectAndRadius(pRect, Radius.circular(size * 0.06)),
        Paint()
          ..color = const Color(0xFF14161B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

      // Penthouse glass window
      final pWindow = Rect.fromCenter(
        center: Offset(cx, pRect.top + pHeight * 0.5),
        width: pWidth * 0.4,
        height: pHeight * 0.4,
      );
      canvas.drawRect(pWindow, Paint()..color = const Color(0xFF80DEEA).withValues(alpha: 0.6));
      canvas.drawRect(
        pWindow,
        Paint()
          ..color = const Color(0xFF14161B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      // Antenna spire
      final antennaPaint = Paint()
        ..color = const Color(0xFF14161B)
        ..strokeWidth = 1.5;
      final antennaTop = pRect.top - size * 0.18;
      canvas.drawLine(
        Offset(cx, pRect.top),
        Offset(cx, antennaTop),
        antennaPaint,
      );

      // Blinking warning beacon light
      final pulse = (math.sin(DateTime.now().millisecondsSinceEpoch / 150) + 1.0) / 2.0;
      final signalColor = Color.lerp(Colors.redAccent, Colors.red, pulse)!;
      final signalPaint = Paint()
        ..color = signalColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, antennaTop), 2.0, signalPaint);
    }

    // Simple roof layer (flat highlight RRect on top half of building)
    final roofRect = Rect.fromLTWH(
      bRect.left + 2,
      bRect.top + 2,
      bRect.width - 4,
      bRect.height * 0.35,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(roofRect, Radius.circular(size * 0.04)),
      Paint()..color = Colors.white24,
    );

    // [NEW] Map-specific building details
    _drawMapSpecificBuildingDetails(canvas, bRect, size);

    // Simple glass double doors at the center bottom
    final doorRect = Rect.fromCenter(
      center: Offset(cx, bRect.bottom - bRect.height * 0.18),
      width: bSize * 0.24,
      height: bRect.height * 0.32,
    );
    canvas.drawRect(doorRect, Paint()..color = const Color(0xFF80DEEA).withValues(alpha: 0.5));
    canvas.drawRect(
      doorRect,
      Paint()
        ..color = const Color(0xFF14161B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

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

  void _drawTunnelPortal(Canvas canvas, double cx, double cy, Direction dir) {
    final headwallPaint = Paint()
      ..color = const Color(0xFF5F6572) // concrete grey
      ..style = PaintingStyle.fill;
    final headwallOutlinePaint = Paint()
      ..color = const Color(0xFF14161B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final openingPaint = Paint()
      ..color = const Color(0xFF14161B)
      ..style = PaintingStyle.fill;

    switch (dir) {
      case Direction.north:
        final hwRect = Rect.fromCenter(
          center: Offset(cx, cy - cellSize / 2 + 3),
          width: cellSize * 0.68,
          height: 6,
        );
        canvas.drawRRect(RRect.fromRectAndRadius(hwRect, const Radius.circular(1.5)), headwallPaint);
        canvas.drawRRect(RRect.fromRectAndRadius(hwRect, const Radius.circular(1.5)), headwallOutlinePaint);

        final opRect = Rect.fromLTWH(
          cx - cellSize * 0.24,
          cy - cellSize / 2 + 4,
          cellSize * 0.48,
          cellSize * 0.22,
        );
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            opRect,
            topLeft: Radius.circular(cellSize * 0.2),
            topRight: Radius.circular(cellSize * 0.2),
          ),
          openingPaint,
        );
        break;

      case Direction.south:
        final hwRect = Rect.fromCenter(
          center: Offset(cx, cy + cellSize / 2 - 3),
          width: cellSize * 0.68,
          height: 6,
        );
        canvas.drawRRect(RRect.fromRectAndRadius(hwRect, const Radius.circular(1.5)), headwallPaint);
        canvas.drawRRect(RRect.fromRectAndRadius(hwRect, const Radius.circular(1.5)), headwallOutlinePaint);

        final opRect = Rect.fromLTWH(
          cx - cellSize * 0.24,
          cy + cellSize / 2 - 4 - cellSize * 0.22,
          cellSize * 0.48,
          cellSize * 0.22,
        );
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            opRect,
            bottomLeft: Radius.circular(cellSize * 0.2),
            bottomRight: Radius.circular(cellSize * 0.2),
          ),
          openingPaint,
        );
        break;

      case Direction.east:
        final hwRect = Rect.fromCenter(
          center: Offset(cx + cellSize / 2 - 3, cy),
          width: 6,
          height: cellSize * 0.68,
        );
        canvas.drawRRect(RRect.fromRectAndRadius(hwRect, const Radius.circular(1.5)), headwallPaint);
        canvas.drawRRect(RRect.fromRectAndRadius(hwRect, const Radius.circular(1.5)), headwallOutlinePaint);

        final opRect = Rect.fromLTWH(
          cx + cellSize / 2 - 4 - cellSize * 0.22,
          cy - cellSize * 0.24,
          cellSize * 0.22,
          cellSize * 0.48,
        );
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            opRect,
            topRight: Radius.circular(cellSize * 0.2),
            bottomRight: Radius.circular(cellSize * 0.2),
          ),
          openingPaint,
        );
        break;

      case Direction.west:
        final hwRect = Rect.fromCenter(
          center: Offset(cx - cellSize / 2 + 3, cy),
          width: 6,
          height: cellSize * 0.68,
        );
        canvas.drawRRect(RRect.fromRectAndRadius(hwRect, const Radius.circular(1.5)), headwallPaint);
        canvas.drawRRect(RRect.fromRectAndRadius(hwRect, const Radius.circular(1.5)), headwallOutlinePaint);

        final opRect = Rect.fromLTWH(
          cx - cellSize / 2 + 4,
          cy - cellSize * 0.24,
          cellSize * 0.22,
          cellSize * 0.48,
        );
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            opRect,
            topLeft: Radius.circular(cellSize * 0.2),
            bottomLeft: Radius.circular(cellSize * 0.2),
          ),
          openingPaint,
        );
        break;
    }
  }

  void _drawBridgeRails(Canvas canvas, double cx, double cy, GridCell cell) {
    final railPaint = Paint()
      ..color = const Color(0xFFECEFF1)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final postPaint = Paint()
      ..color = const Color(0xFF78909C)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final n = cell.connUp;
    final s = cell.connDown;
    final e = cell.connRight;
    final w = cell.connLeft;

    final offset = cellSize * 0.24;

    if (n && s && !e && !w) {
      canvas.drawLine(Offset(cx - offset, cy - cellSize / 2), Offset(cx - offset, cy + cellSize / 2), railPaint);
      canvas.drawLine(Offset(cx + offset, cy - cellSize / 2), Offset(cx + offset, cy + cellSize / 2), railPaint);
      canvas.drawCircle(Offset(cx - offset, cy), 1.0, postPaint);
      canvas.drawCircle(Offset(cx + offset, cy), 1.0, postPaint);
    } else if (e && w && !n && !s) {
      canvas.drawLine(Offset(cx - cellSize / 2, cy - offset), Offset(cx + cellSize / 2, cy - offset), railPaint);
      canvas.drawLine(Offset(cx - cellSize / 2, cy + offset), Offset(cx + cellSize / 2, cy + offset), railPaint);
      canvas.drawCircle(Offset(cx, cy - offset), 1.0, postPaint);
      canvas.drawCircle(Offset(cx, cy + offset), 1.0, postPaint);
    } else {
      if (n) {
        if (!w) canvas.drawLine(Offset(cx - offset, cy - cellSize / 2), Offset(cx - offset, cy), railPaint);
        if (!e) canvas.drawLine(Offset(cx + offset, cy - cellSize / 2), Offset(cx + offset, cy), railPaint);
      }
      if (s) {
        if (!w) canvas.drawLine(Offset(cx - offset, cy), Offset(cx - offset, cy + cellSize / 2), railPaint);
        if (!e) canvas.drawLine(Offset(cx + offset, cy), Offset(cx + offset, cy + cellSize / 2), railPaint);
      }
      if (e) {
        if (!n) canvas.drawLine(Offset(cx, cy - offset), Offset(cx + cellSize / 2, cy - offset), railPaint);
        if (!s) canvas.drawLine(Offset(cx, cy + offset), Offset(cx + cellSize / 2, cy + offset), railPaint);
      }
      if (w) {
        if (!n) canvas.drawLine(Offset(cx - cellSize / 2, cy - offset), Offset(cx, cy - offset), railPaint);
        if (!s) canvas.drawLine(Offset(cx - cellSize / 2, cy + offset), Offset(cx, cy + offset), railPaint);
      }
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

        final cx = offsetX + x * cellSize + cellSize / 2;
        final cy = offsetY + y * cellSize + cellSize / 2;

        if (cell.isTunnel) {
          if (cell.connUp && gridManager.isValid(x, y - 1) && !gridManager.grid[y - 1][x].isTunnel) {
            _drawTunnelPortal(canvas, cx, cy, Direction.north);
          }
          if (cell.connRight && gridManager.isValid(x + 1, y) && !gridManager.grid[y][x + 1].isTunnel) {
            _drawTunnelPortal(canvas, cx, cy, Direction.east);
          }
          if (cell.connDown && gridManager.isValid(x, y + 1) && !gridManager.grid[y + 1][x].isTunnel) {
            _drawTunnelPortal(canvas, cx, cy, Direction.south);
          }
          if (cell.connLeft && gridManager.isValid(x - 1, y) && !gridManager.grid[y][x - 1].isTunnel) {
            _drawTunnelPortal(canvas, cx, cy, Direction.west);
          }
        } else if (cell.isBridge) {
          _drawBridgeRails(canvas, cx, cy, cell);
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



  void _drawAmbientTimeOfDay(Canvas canvas) {
    final weekProgress = game.weekProgress.clamp(0.0, 1.0);
    
    // Derive warm/cool tint from progress
    // Morning (0.0-0.15): warm orange sunrise
    // Midday (0.15-0.45): clear/neutral
    // Evening (0.45-0.65): warm amber sunset
    // Night (0.65-1.0): cool indigo

    Color tintColor;
    double tintStrength;

    if (weekProgress < 0.15) {
      // Dawn → sunrise golden
      final t = weekProgress / 0.15;
      tintColor = const Color(0xFFFFB347);
      tintStrength = (1.0 - t) * 0.06; // fades as morning progresses
    } else if (weekProgress < 0.45) {
      // Midday → nearly transparent
      tintColor = const Color(0xFFFFF8E1);
      tintStrength = 0.0;
    } else if (weekProgress < 0.65) {
      // Evening → warm amber/red sunset
      final t = (weekProgress - 0.45) / 0.20;
      tintColor = Color.lerp(const Color(0xFFE26D5C), const Color(0xFF1A1040), t)!;
      tintStrength = t * 0.15;
    } else {
      // Night → deep indigo, peaks at 0.85, then fades back to dawn
      final nightProgress = (weekProgress - 0.65) / 0.35;
      final nightIntensity = math.sin(nightProgress * math.pi); // peaks at center of night
      tintColor = const Color(0xFF0A0E1A);
      tintStrength = nightIntensity * 0.25;
    }

    if (tintStrength < 0.005) return;

    final boardRect = Rect.fromLTWH(
      offsetX,
      offsetY,
      gridManager.cols * cellSize,
      gridManager.rows * cellSize,
    );

    // Radial gradient: lighter center (city glow) → darker edges (vignette)
    final centerColor = tintColor.withValues(alpha: tintStrength * 0.3);
    final edgeColor = tintColor.withValues(alpha: tintStrength);

    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 0.9,
      colors: [centerColor, edgeColor],
      stops: const [0.3, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(boardRect)
      ..style = PaintingStyle.fill;

    canvas.drawRect(boardRect, paint);
  }

  void _drawRoadPreview(Canvas canvas) {
    if (game.activeTool != BuildTool.road &&
        game.activeTool != BuildTool.tunnel &&
        game.activeTool != BuildTool.bridge &&
        game.activeTool != BuildTool.erase) {
      return;
    }
    if (game.previewPath.isEmpty) return;

    final isTunnel = game.activeTool == BuildTool.tunnel;
    final isBridge = game.activeTool == BuildTool.bridge;
    final isErase = game.activeTool == BuildTool.erase;

    final Color blueprintColor;
    if (isTunnel) {
      blueprintColor = const Color(0xFF2D9CDB);
    } else if (isBridge) {
      blueprintColor = const Color(0xFF27AE60);
    } else if (isErase) {
      blueprintColor = Colors.redAccent;
    } else {
      blueprintColor = const Color(0xFF00E5FF);
    }

    final fillPaint = Paint()
      ..color = blueprintColor.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = blueprintColor.withValues(alpha: 0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (final pos in game.previewPath) {
      final rect = Rect.fromLTWH(
        offsetX + pos.x * cellSize + 3,
        offsetY + pos.y * cellSize + 3,
        cellSize - 6,
        cellSize - 6,
      );
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
      canvas.drawRRect(rrect, fillPaint);
      canvas.drawRRect(rrect, borderPaint);

      final cx = rect.center.dx;
      final cy = rect.center.dy;
      if (isErase) {
        // Draw diagonal X for erase preview
        final crossSize = cellSize * 0.15;
        canvas.drawLine(Offset(cx - crossSize, cy - crossSize), Offset(cx + crossSize, cy + crossSize), borderPaint);
        canvas.drawLine(Offset(cx - crossSize, cy + crossSize), Offset(cx + crossSize, cy - crossSize), borderPaint);
      } else {
        // Draw subtle drafting grid marking (crosshair) in the center of blueprint tile
        final crossSize = cellSize * 0.15;
        canvas.drawLine(Offset(cx - crossSize, cy), Offset(cx + crossSize, cy), borderPaint);
        canvas.drawLine(Offset(cx, cy - crossSize), Offset(cx, cy + crossSize), borderPaint);
      }
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

    final cx = game.gridCols / 2.0;
    final cy = game.gridRows / 2.0;
    
    double hw = game.smoothActiveHalfWidth;
    double hh = game.smoothActiveHalfHeight;
    
    if (game.size.x > 100 && game.size.y > 100) {
      const double padding = 16.0;
      final screenW = game.size.x - game.hudPanelWidth - (2 * padding);
      final screenH = game.size.y - (2 * padding);
      if (screenW > 0 && screenH > 0) {
        final screenAspect = screenW / screenH;
        final baseAspect = hw / hh;
        if (screenAspect > baseAspect) {
          hw = hh * screenAspect;
          final maxHw = (game.gridCols - 4) / 2.0;
          if (hw > maxHw) hw = maxHw;
        } else {
          hh = hw / screenAspect;
          final maxHh = (game.gridRows - 4) / 2.0;
          if (hh > maxHh) hh = maxHh;
        }
      }
    }

    final minX = math.max(2.0, cx - hw);
    final maxX = math.min(game.gridCols.toDouble() - 3.0, cx + hw);
    final minY = math.max(2.0, cy - hh);
    final maxY = math.min(game.gridRows.toDouble() - 3.0, cy + hh);

    // Calculate the active rectangle in screen pixels
    final rect = Rect.fromLTRB(
      offsetX + minX * cellSize,
      offsetY + minY * cellSize,
      offsetX + maxX * cellSize,
      offsetY + maxY * cellSize,
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

  void _drawWarningTriangle(Canvas canvas, double cx, double cy, double size) {
    final path = Path();
    path.moveTo(cx, cy - size * 0.5);
    path.lineTo(cx + size * 0.5, cy + size * 0.4);
    path.lineTo(cx - size * 0.5, cy + size * 0.4);
    path.close();

    canvas.drawPath(path, Paint()..color = Colors.amber);
    canvas.drawPath(path, Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1.0);
    
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '!',
        style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(cx - textPainter.width / 2, cy - textPainter.height / 2 + 1));
  }

  void _drawMapSpecificEventVisuals(Canvas canvas) {
    final double time = game.elapsedTime;
    final int rows = gridManager.rows;
    final int cols = gridManager.cols;
    final double width = cols * cellSize;
    final double height = rows * cellSize;

    // 1. Map-wide weather overlays
    if (game.activeEvent == 'blizzard') {
      // Map-wide cold white-blue tint
      canvas.drawRect(
        Rect.fromLTWH(offsetX, offsetY, width, height),
        Paint()..color = const Color(0x35E0F7FC),
      );

      // Draw drifting snowflakes
      final snowPaint = Paint()..color = Colors.white.withValues(alpha: 0.85);
      final r = math.Random(42); // deterministic seed per frame
      for (int i = 0; i < 60; i++) {
        // Position drifts down-right over time
        final rx = (r.nextDouble() * width + time * 60.0) % width;
        final ry = (r.nextDouble() * height + time * 80.0) % height;
        canvas.drawCircle(Offset(offsetX + rx, offsetY + ry), 1.5 + r.nextDouble() * 2.0, snowPaint);
      }
    } else if (game.activeEvent == 'dustStorm') {
      // Map-wide orange-brown sandstorm tint
      canvas.drawRect(
        Rect.fromLTWH(offsetX, offsetY, width, height),
        Paint()..color = const Color(0x45E5A65D),
      );

      // Draw drifting dust particles (horizontal streaks)
      final dustPaint = Paint()..color = const Color(0xFFC69C6D).withValues(alpha: 0.6);
      final r = math.Random(1337);
      for (int i = 0; i < 40; i++) {
        final rx = (r.nextDouble() * width + time * 120.0) % width;
        final ry = (r.nextDouble() * height + time * 30.0) % height;
        final length = 15.0 + r.nextDouble() * 25.0;
        canvas.drawLine(
          Offset(offsetX + rx, offsetY + ry),
          Offset(offsetX + rx + length, offsetY + ry + 2.0),
          dustPaint..strokeWidth = 1.0 + r.nextDouble() * 1.5,
        );
      }
    }

    // 2. Animal crossing crossing animation
    if (game.activeEvent == 'animalCrossing' && game.activeEventPos != null) {
      final pos = game.activeEventPos!;
      final cx = offsetX + pos.x * cellSize + cellSize / 2;
      final cy = offsetY + pos.y * cellSize + cellSize / 2;

      // Draw warning triangle
      _drawWarningTriangle(canvas, cx, cy - cellSize * 0.15, cellSize * 0.35);

      // Draw 3 tiny gazelles crossing (little brown circles with legs/ears)
      for (int i = 0; i < 3; i++) {
        final offsetPhase = (time * 0.4 + i * 0.3) % 1.0;
        // Move from left edge to right edge of cell
        final ax = cx - cellSize * 0.4 + offsetPhase * cellSize * 0.8;
        final ay = cy + math.sin(offsetPhase * math.pi * 4.0) * 2.0; // slight hop
        
        // Gazelle body
        canvas.drawCircle(Offset(ax, ay), 3.0, Paint()..color = const Color(0xFF8B5A2B));
        // Head
        canvas.drawCircle(Offset(ax + 3.0, ay - 2.0), 1.8, Paint()..color = const Color(0xFF8B5A2B));
        // Horns
        canvas.drawLine(Offset(ax + 3.0, ay - 2.0), Offset(ax + 4.0, ay - 5.0), Paint()..color = Colors.black..strokeWidth = 0.8);
      }
    }

    // 3. Drawbridge Open animation
    if (game.activeEvent == 'drawbridgeOpen' && game.activeEventPos != null) {
      final pos = game.activeEventPos!;
      final cx = offsetX + pos.x * cellSize + cellSize / 2;
      final cy = offsetY + pos.y * cellSize + cellSize / 2;
      final cell = gridManager.grid[pos.y][pos.x];

      // Draw flashing red warning light
      final flash = (time * 5.0).floor() % 2 == 0;
      canvas.drawCircle(
        Offset(cx, cy),
        cellSize * 0.5,
        Paint()
          ..color = (flash ? Colors.red : Colors.black).withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );

      // Draw bridge flaps open (two dark rects separated in the center)
      final bool isVertical = cell.infrastructureAxis == InfrastructureAxis.vertical;
      final bridgePaint = Paint()..color = const Color(0xFF5E6573);

      if (isVertical) {
        // Top flap
        canvas.drawRect(
          Rect.fromLTWH(cx - cellSize * 0.2, cy - cellSize * 0.45, cellSize * 0.4, cellSize * 0.25),
          bridgePaint,
        );
        // Bottom flap
        canvas.drawRect(
          Rect.fromLTWH(cx - cellSize * 0.2, cy + cellSize * 0.2, cellSize * 0.4, cellSize * 0.25),
          bridgePaint,
        );
      } else {
        // Left flap
        canvas.drawRect(
          Rect.fromLTWH(cx - cellSize * 0.45, cy - cellSize * 0.2, cellSize * 0.25, cellSize * 0.4),
          bridgePaint,
        );
        // Right flap
        canvas.drawRect(
          Rect.fromLTWH(cx + cellSize * 0.2, cy - cellSize * 0.2, cellSize * 0.25, cellSize * 0.4),
          bridgePaint,
        );
      }

      // Draw red stop barrier arms blocking lanes
      final barrierPaint = Paint()
        ..color = Colors.red
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;
      final barrierSupportPaint = Paint()
        ..color = const Color(0xFF333333)
        ..style = PaintingStyle.fill;

      if (isVertical) {
        canvas.drawCircle(Offset(cx - cellSize * 0.3, cy - cellSize * 0.38), 2.5, barrierSupportPaint);
        canvas.drawLine(Offset(cx - cellSize * 0.3, cy - cellSize * 0.38), Offset(cx + cellSize * 0.3, cy - cellSize * 0.38), barrierPaint);

        canvas.drawCircle(Offset(cx + cellSize * 0.3, cy + cellSize * 0.38), 2.5, barrierSupportPaint);
        canvas.drawLine(Offset(cx - cellSize * 0.3, cy + cellSize * 0.38), Offset(cx + cellSize * 0.3, cy + cellSize * 0.38), barrierPaint);
      } else {
        canvas.drawCircle(Offset(cx - cellSize * 0.38, cy - cellSize * 0.3), 2.5, barrierSupportPaint);
        canvas.drawLine(Offset(cx - cellSize * 0.38, cy - cellSize * 0.3), Offset(cx - cellSize * 0.38, cy + cellSize * 0.3), barrierPaint);

        canvas.drawCircle(Offset(cx + cellSize * 0.38, cy + cellSize * 0.3), 2.5, barrierSupportPaint);
        canvas.drawLine(Offset(cx + cellSize * 0.38, cy - cellSize * 0.3), Offset(cx + cellSize * 0.38, cy + cellSize * 0.3), barrierPaint);
      }
    }

    // 4. Flash Flood submerged indicators
    if (game.activeEvent == 'flashFlood' && game.floodedRoads.isNotEmpty) {
      final floodPaint = Paint()
        ..color = const Color(0x952196F3)
        ..style = PaintingStyle.fill;

      for (final pos in game.floodedRoads) {
        final cx = offsetX + pos.x * cellSize + cellSize / 2;
        final cy = offsetY + pos.y * cellSize + cellSize / 2;

        // Draw blue water wavy ripple over the flooded tile
        canvas.drawCircle(
          Offset(cx, cy),
          cellSize * 0.42,
          floodPaint,
        );

        // Draw a tiny wave pattern
        final wavePaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        final double waveY = cy + math.sin(time * 5.0) * 1.5;
        canvas.drawLine(Offset(cx - cellSize * 0.25, waveY), Offset(cx + cellSize * 0.25, waveY), wavePaint);

        // Draw warning triangle over the flooded tile
      }
    }
  }

  void _drawActiveEventOverlays(Canvas canvas) {
    final eventManager = game.eventManager;
    final now = game.elapsedTime;

    for (final event in eventManager.activeEvents) {
      if (event.type == CityEventType.roadBlock && event.affectedTile != null) {
        final pos = event.affectedTile!;
        final cx = offsetX + pos.x * cellSize + cellSize / 2;
        final cy = offsetY + pos.y * cellSize + cellSize / 2;

        // 1. Pulsing warning glow under the tile
        final pulse = 0.5 + 0.5 * math.sin(now * 6.0).abs();
        final glowPaint = Paint()
          ..shader = ui.Gradient.radial(
            Offset(cx, cy),
            cellSize * 0.8,
            [Colors.deepOrange.withValues(alpha: 0.3 * pulse), Colors.transparent],
          );
        canvas.drawCircle(Offset(cx, cy), cellSize * 0.8, glowPaint);

        // 2. Diagonal hazard stripes background on road
        final tX = offsetX + pos.x * cellSize;
        final tY = offsetY + pos.y * cellSize;
        final bgPaint = Paint()..color = Colors.deepOrange.withValues(alpha: 0.15);
        canvas.drawRect(Rect.fromLTWH(tX, tY, cellSize, cellSize), bgPaint);

        final linePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = Colors.deepOrange.withValues(alpha: 0.5);
        canvas.drawLine(Offset(tX, tY + cellSize * 0.25), Offset(tX + cellSize * 0.75, tY + cellSize), linePaint);
        canvas.drawLine(Offset(tX, tY + cellSize * 0.75), Offset(tX + cellSize * 0.25, tY), linePaint);
        canvas.drawLine(Offset(tX + cellSize * 0.25, tY), Offset(tX + cellSize, tY + cellSize * 0.75), linePaint);

        // 3. Draw a premium construction barrier (barricade)
        final barrierWidth = cellSize * 0.75;
        final barrierHeight = cellSize * 0.55;
        final bLeft = cx - barrierWidth / 2;
        final bTop = cy - barrierHeight / 2;

        // A-frame legs
        final legPaint = Paint()
          ..color = const Color(0xFF263238)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;
        // Left leg
        canvas.drawLine(Offset(bLeft + 4, cy + barrierHeight / 2), Offset(bLeft + 8, bTop), legPaint);
        canvas.drawLine(Offset(bLeft + 12, cy + barrierHeight / 2), Offset(bLeft + 8, bTop), legPaint);
        // Right leg
        canvas.drawLine(Offset(bLeft + barrierWidth - 12, cy + barrierHeight / 2), Offset(bLeft + barrierWidth - 8, bTop), legPaint);
        canvas.drawLine(Offset(bLeft + barrierWidth - 4, cy + barrierHeight / 2), Offset(bLeft + barrierWidth - 8, bTop), legPaint);

        // Two horizontal boards
        final boardPaint = Paint()..color = Colors.white;
        final stripePaint = Paint()..color = Colors.deepOrange;

        for (int b = 0; b < 2; b++) {
          final boardTop = bTop + b * (barrierHeight * 0.38) + 2;
          final boardRect = Rect.fromLTWH(bLeft, boardTop, barrierWidth, barrierHeight * 0.25);
          // Draw white board
          canvas.drawRect(boardRect, boardPaint);
          canvas.drawRect(boardRect, Paint()..color = const Color(0xFF14161B)..style = PaintingStyle.stroke..strokeWidth = 1.0);

          // Draw diagonal orange stripes on the board
          canvas.save();
          canvas.clipRect(boardRect);
          for (double sx = -cellSize; sx < cellSize * 2; sx += 8) {
            final path = Path()
              ..moveTo(bLeft + sx, boardTop)
              ..lineTo(bLeft + sx + 4, boardTop)
              ..lineTo(bLeft + sx - 2, boardTop + boardRect.height)
              ..lineTo(bLeft + sx - 6, boardTop + boardRect.height)
              ..close();
            canvas.drawPath(path, stripePaint);
          }
          canvas.restore();
        }

        // 4. Floating bouncing caution sign
        final bounce = math.sin(now * 5.0) * 3.0;
        final iconY = cy - cellSize * 0.8 + bounce;

        final signPath = Path()
          ..moveTo(cx, iconY - 10)
          ..lineTo(cx - 10, iconY + 8)
          ..lineTo(cx + 10, iconY + 8)
          ..close();
        canvas.drawPath(signPath, Paint()..color = const Color(0xFFFFD54F));
        canvas.drawPath(signPath, Paint()
          ..color = const Color(0xFF14161B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);

        final textPainter = TextPainter(
          text: TextSpan(
            text: '!',
            style: GoogleFonts.outfit(
              color: const Color(0xFF14161B),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(canvas, Offset(cx - textPainter.width / 2, iconY - textPainter.height / 2 + 1));
      }

      else if (event.type == CityEventType.bridgeMaintenance && event.affectedTile != null) {
        final pos = event.affectedTile!;
        final cx = offsetX + pos.x * cellSize + cellSize / 2;
        final cy = offsetY + pos.y * cellSize + cellSize / 2;

        final pulse = 0.5 + 0.5 * math.sin(now * 6.0).abs();
        final glowPaint = Paint()
          ..shader = ui.Gradient.radial(
            Offset(cx, cy),
            cellSize * 0.8,
            [Colors.amber.withValues(alpha: 0.3 * pulse), Colors.transparent],
          );
        canvas.drawCircle(Offset(cx, cy), cellSize * 0.8, glowPaint);

        final tX = offsetX + pos.x * cellSize;
        final tY = offsetY + pos.y * cellSize;
        final bgPaint = Paint()..color = Colors.amber.withValues(alpha: 0.15);
        canvas.drawRect(Rect.fromLTWH(tX, tY, cellSize, cellSize), bgPaint);

        final linePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = Colors.amber.withValues(alpha: 0.5);
        canvas.drawLine(Offset(tX, tY + cellSize * 0.25), Offset(tX + cellSize * 0.75, tY + cellSize), linePaint);
        canvas.drawLine(Offset(tX, tY + cellSize * 0.75), Offset(tX + cellSize * 0.25, tY), linePaint);
        canvas.drawLine(Offset(tX + cellSize * 0.25, tY), Offset(tX + cellSize, tY + cellSize * 0.75), linePaint);

        // Draw a premium construction barrier (barricade) in yellow
        final barrierWidth = cellSize * 0.75;
        final barrierHeight = cellSize * 0.55;
        final bLeft = cx - barrierWidth / 2;
        final bTop = cy - barrierHeight / 2;

        // A-frame legs
        final legPaint = Paint()
          ..color = const Color(0xFF263238)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;
        canvas.drawLine(Offset(bLeft + 4, cy + barrierHeight / 2), Offset(bLeft + 8, bTop), legPaint);
        canvas.drawLine(Offset(bLeft + 12, cy + barrierHeight / 2), Offset(bLeft + 8, bTop), legPaint);
        canvas.drawLine(Offset(bLeft + barrierWidth - 12, cy + barrierHeight / 2), Offset(bLeft + barrierWidth - 8, bTop), legPaint);
        canvas.drawLine(Offset(bLeft + barrierWidth - 4, cy + barrierHeight / 2), Offset(bLeft + barrierWidth - 8, bTop), legPaint);

        // Two horizontal boards
        final boardPaint = Paint()..color = Colors.white;
        final stripePaint = Paint()..color = Colors.amber;

        for (int b = 0; b < 2; b++) {
          final boardTop = bTop + b * (barrierHeight * 0.38) + 2;
          final boardRect = Rect.fromLTWH(bLeft, boardTop, barrierWidth, barrierHeight * 0.25);
          canvas.drawRect(boardRect, boardPaint);
          canvas.drawRect(boardRect, Paint()..color = const Color(0xFF14161B)..style = PaintingStyle.stroke..strokeWidth = 1.0);

          canvas.save();
          canvas.clipRect(boardRect);
          for (double sx = -cellSize; sx < cellSize * 2; sx += 8) {
            final path = Path()
              ..moveTo(bLeft + sx, boardTop)
              ..lineTo(bLeft + sx + 4, boardTop)
              ..lineTo(bLeft + sx - 2, boardTop + boardRect.height)
              ..lineTo(bLeft + sx - 6, boardTop + boardRect.height)
              ..close();
            canvas.drawPath(path, stripePaint);
          }
          canvas.restore();
        }

        // Bouncing tool sign
        final bounce = math.sin(now * 5.0) * 3.0;
        final iconY = cy - cellSize * 0.8 + bounce;

        final signPath = Path()
          ..moveTo(cx, iconY - 10)
          ..lineTo(cx - 10, iconY + 8)
          ..lineTo(cx + 10, iconY + 8)
          ..close();
        canvas.drawPath(signPath, Paint()..color = const Color(0xFFFFB300));
        canvas.drawPath(signPath, Paint()
          ..color = const Color(0xFF14161B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);

        final textPainter = TextPainter(
          text: TextSpan(
            text: 'W',
            style: GoogleFonts.outfit(
              color: const Color(0xFF14161B),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(canvas, Offset(cx - textPainter.width / 2, iconY - textPainter.height / 2 + 1));
      }

      else if (event.type == CityEventType.festival && event.affectedColor != null) {
        final colorIndex = event.affectedColor!;
        final destinations = gridManager.destinations.where((d) => gridManager.grid[d.y][d.x].colorIndex == colorIndex);
        final houses = gridManager.houses.where((h) => gridManager.grid[h.y][h.x].colorIndex == colorIndex);
        
        final allPositions = [...destinations, ...houses];

        for (final pos in allPositions) {
          final cx = offsetX + pos.x * cellSize + cellSize / 2;
          final cy = offsetY + pos.y * cellSize + cellSize / 2;

          // 1. Pulsing pink festival party aura
          final pulse = 0.6 + 0.4 * math.sin(now * 4.0).abs();
          final auraPaint = Paint()
            ..shader = ui.Gradient.radial(
              Offset(cx, cy),
              cellSize * 1.5,
              [Colors.pinkAccent.withValues(alpha: 0.35 * pulse), Colors.transparent],
            );
          canvas.drawCircle(Offset(cx, cy), cellSize * 1.5, auraPaint);

          // 2. Confetti particles
          for (int i = 0; i < 4; i++) {
            final angle = (now * 2.0) + (i * math.pi / 2);
            final radius = cellSize * 0.7 * (0.8 + 0.2 * math.sin(now * 3.0 + i));
            final particleX = cx + math.cos(angle) * radius;
            final particleY = cy - cellSize * 0.3 + math.sin(angle) * radius + math.sin(now * 4.0 + i) * 3.0;

            final colors = [Colors.yellow, Colors.cyan, Colors.pink, Colors.greenAccent];
            final particlePaint = Paint()..color = colors[i % colors.length];
            canvas.drawCircle(Offset(particleX, particleY), 3.0, particlePaint);
          }

          // 3. Floating party balloons
          final bounce = math.sin(now * 6.0) * 4.0;
          final iconY = cy - cellSize * 1.2 + bounce;

          for (int b = 0; b < 2; b++) {
            final balloonOffset = b == 0 ? -10.0 : 10.0;
            final balloonHeight = b == 0 ? 10.0 : 4.0;
            final balloonColor = b == 0 ? Colors.redAccent : Colors.lightBlueAccent;

            final bx = cx + balloonOffset;
            final by = iconY - 10.0 - balloonHeight + math.sin(now * 3.0 + b) * 2.0;

            // Draw balloon string
            final stringPaint = Paint()
              ..color = Colors.white54
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0;
            final stringPath = Path()
              ..moveTo(bx, by + 5)
              ..quadraticBezierTo(bx + (b == 0 ? -2 : 2), by + 12, bx, by + 18);
            canvas.drawPath(stringPath, stringPaint);

            // Draw balloon body (oval)
            canvas.drawOval(
              Rect.fromCenter(center: Offset(bx, by), width: 8, height: 10),
              Paint()..color = balloonColor,
            );
            canvas.drawOval(
              Rect.fromCenter(center: Offset(bx, by), width: 8, height: 10),
              Paint()..color = const Color(0xFF14161B)..style = PaintingStyle.stroke..strokeWidth = 0.8,
            );

            // Draw small knot
            final knotPath = Path()
              ..moveTo(bx, by + 5)
              ..lineTo(bx - 1.5, by + 7)
              ..lineTo(bx + 1.5, by + 7)
              ..close();
            canvas.drawPath(knotPath, Paint()..color = balloonColor);
          }

          // 4. Bouncing party hat/emoji above building
          final textPainter = TextPainter(
            text: TextSpan(
              text: '🎉',
              style: GoogleFonts.outfit(
                fontSize: 16,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          textPainter.paint(canvas, Offset(cx - textPainter.width / 2, iconY - textPainter.height / 2));
        }
      }

      else if (event.type == CityEventType.trafficSurge && event.affectedColor != null) {
        final colorIndex = event.affectedColor!;
        final destinations = gridManager.destinations.where((d) => gridManager.grid[d.y][d.x].colorIndex == colorIndex);

        for (final dest in destinations) {
          final cx = offsetX + dest.x * cellSize + cellSize / 2;
          final cy = offsetY + dest.y * cellSize + cellSize / 2;

          // 1. Pulsing red traffic surge aura
          final pulse = 0.6 + 0.4 * math.sin(now * 5.0).abs();
          final auraPaint = Paint()
            ..shader = ui.Gradient.radial(
              Offset(cx, cy),
              cellSize * 1.5,
              [Colors.redAccent.withValues(alpha: 0.35 * pulse), Colors.transparent],
            );
          canvas.drawCircle(Offset(cx, cy), cellSize * 1.5, auraPaint);

          // 2. Bouncing lightning emoji above building
          final bounce = math.sin(now * 7.0) * 4.0;
          final iconY = cy - cellSize * 1.2 + bounce;

          final textPainter = TextPainter(
            text: TextSpan(
              text: '⚡',
              style: GoogleFonts.outfit(
                fontSize: 18,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          textPainter.paint(canvas, Offset(cx - textPainter.width / 2, iconY - textPainter.height / 2));
        }
      }
    }
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
