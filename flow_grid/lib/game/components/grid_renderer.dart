import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import '../../models/game_constants.dart';
import 'car_component.dart';
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

  // [PERF] Mountains are stored as a flat, unindexed
  // `List<MountainCluster>` on GridManager (each cluster a `Set<GridPosition>`
  // with no spatial bucketing). _drawMountains used to loop over EVERY
  // cluster/cell in the whole map on every single chunk rebuild, just to
  // filter down to the handful of cells that actually fall in that one
  // chunk -- O(total mountain cells) of wasted work per chunk, and chunk
  // rebuilds happen on every road/tunnel/bridge edit (`markInfrastructureDirty`)
  // during normal play. Fine on Zen (few mountains) but reported as real,
  // reproducible lag/freezing on the Andes map (mountain-dense by design) --
  // confirmed independently by a `Page.captureScreenshot` CDP timeout while
  // playtesting live. This lazily-built index buckets mountain cells by
  // chunk key ONCE, so `_drawMountains` only ever touches cells that are
  // actually in the chunk being built. Invalidated in `markAllDirty()` --
  // every code path that changes mountain data (`rebuildMountain`,
  // `reconstructTerrainState` on GridManager) already funnels through a
  // `gridRenderer.markDirty()`/`markAllDirty()` call to force a full
  // re-render, so hooking the same signal keeps this correct without
  // GridManager needing to know the renderer caches anything.
  Map<int, List<GridPosition>>? _mountainCellsByChunk;

  // [PERF] Same family of bug as `_mountainCellsByChunk` above, found while
  // fixing that one: `gridManager.placedExpressLanes` is a flat, unindexed
  // `List<List<GridPosition>>` (each a 2-element [start, end] pair) with NO
  // spatial bucketing. The old `_drawExpressLanesGlobal` looped over EVERY
  // placed express lane on every single chunk rebuild, unconditionally
  // building and drawing (real Path construction + 2x drawPath + chevron
  // sampling + 2 ramp triangles) each lane's full curve into every chunk's
  // Picture -- `canvas.clipRect()` in `_buildChunkPicture` hid the visual
  // overdraw, but every chunk fully paid the CPU cost of every lane on the
  // map, same as the mountain bug: O(total lanes) of wasted work per chunk.
  //
  // Unlike a mountain cell (which belongs to exactly one chunk), an express
  // lane is a long-jump ARC between two, possibly distant, grid positions --
  // it can visibly pass through a chunk's screen rect without either
  // endpoint's cell being inside that chunk's [minX,maxX)x[minY,maxY) range.
  // A naive "only draw a lane in the chunk(s) containing an endpoint" filter
  // would make the lane vanish in every chunk it merely passes through, a
  // real visible regression. So this index buckets each lane under EVERY
  // chunk its actual bounding box overlaps (may be 1, 2, or more chunks per
  // lane), where the bounding box is computed from the same
  // arcHeight = length * 0.15 * perpSign curve construction
  // `_drawExpressLanesForChunk` (and CarComponent._rebuildSmoothPath) use,
  // not just the straight line between the two endpoints -- see
  // `_expressLaneBounds()` for the exact box (and why it's provably
  // conservative: a quadratic bezier always lies within the convex hull of
  // its three control points, so the box around {start, controlPoint, end}
  // padded by the stroke half-width can never clip off part of the curve).
  //
  // Invalidated in `markAllDirty()`, same as `_mountainCellsByChunk` --
  // every place `placedExpressLanes` is mutated (`placeExpressLane` via
  // `onScaleEnd`'s express-lane branch -> `_cleanupInput()`;
  // `removeInfrastructure`'s express-lane branch via the erase tool's
  // `eraseCell` -> `_handleBuild` -> always followed, in the same
  // synchronous `executeUndoableAction` call, by `_applyEraseRefunds()`;
  // `undo()`; and `loadFromSave`/snapshot-restore, which always run against
  // a brand-new `GridRenderer` instance per `flow_grid_game.dart`'s
  // `removeFromParent()` + fresh `GridRenderer(...)` construction on every
  // resume/new-game) already ends with a no-arg `gridRenderer.markDirty()`
  // (= `markAllDirty()`) before the next render, in the same call stack as
  // the mutation itself -- confirmed by reading every call site, not
  // assumed. So hooking this index to the same signal as the mountain index
  // is correct, not just "conservative."
  Map<int, List<List<GridPosition>>>? _expressLaneChunkIndex;

  // Task 6: Preallocated Paints (Double-Pass Outline Style)
  //
  // [ROAD WIDTH] Widened 2026-09-01 from fill 0.48 / outline 0.60 to fill
  // 0.64 / outline 0.76 (inlined below on every Paint — there is no shared
  // named constant, so any future change here must touch all ten fill/
  // outline strokeWidths), chasing a roughly 3x
  // road-to-car width ratio. Full 3x would be cellSize*0.79 (3x the
  // car's actual painted silhouette, cellSize*0.2634 — see
  // `_maxSafeLaneOffsetMagnitude` in car_component.dart) but that pushes
  // the tunnel-portal headwall to ~0.99*cellSize (near-zero clearance to
  // the tile edge) and measurably deepens the smart-junction ring's
  // pre-existing bleed into DIAGONAL neighbor tiles (not covered by the
  // orthogonal-only building clip in `_drawSmartJunctions`). 0.64 is a
  // deliberately conservative middle ground: still a meaningful jump
  // (ratio-to-car goes from ~1.82x to ~2.43x, vs. today's 1.82x) while
  // keeping every derived margin comfortably inside its tile — see the
  // fix/qa-issues commit message for the full numeric verification.
  //
  // Every fill/outline pair below MUST stay in sync (kept as a fixed
  // +0.12*cellSize outline margin over the fill, matching the original
  // 0.60/0.48 relationship) — and so must:
  //   - `_drawSmartJunctions`' outerR/innerR/glowR (ring thickness == this
  //     outline width, centered on the fixed r=0.75 driving centerline)
  //   - `_drawTunnelPortal`'s opening width/offset and headwall width
  //   - `_drawBridgeRails`' rail offset (must sit at the new curb edge)
  //   - `_drawExpressLanesForChunk`'s laneStroke (kept wider than the road,
  //     via the shared `_expressLaneStrokeFactor` constant)
  //   - car_component.dart's `_maxSafeLaneOffsetMagnitude` surfaceHalfWidth
  //     constants (must equal the new half-widths or the lane-separation
  //     fix from earlier today silently loses most of its benefit)
  final Paint _drivewayOutlinePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.butt;
  final Paint _drivewayPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.butt;
  final Paint _roadOutlinePaint = Paint()
    ..color = GameConstants.roadEdgeColor
    ..strokeWidth =
        GameConstants.cellSize * (GameConstants.roadWidth + 2 * GameConstants.roadEdge)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.butt
    ..strokeJoin = StrokeJoin.round;

  final Paint _roadPaint = Paint()
    ..color = GameConstants.roadColor
    ..strokeWidth = GameConstants.cellSize * GameConstants.roadWidth
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.butt
    ..strokeJoin = StrokeJoin.round;

  /// Dashed edge line used for tunnels.
  final Paint _tunnelDashPaint = Paint()
    ..color = GameConstants.roadEdgeColor
    ..strokeWidth = GameConstants.cellSize * GameConstants.roadEdge * 2
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.butt;

  final Paint _tunnelPaint = Paint()
    ..color = const Color(0xFF1E222A)
    ..strokeWidth = GameConstants.cellSize * GameConstants.roadWidth
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.butt
    ..strokeJoin = StrokeJoin.round;

  final Paint _bridgeOutlinePaint = Paint()
    ..color = GameConstants.roadEdgeColor
    ..strokeWidth =
        GameConstants.cellSize * (GameConstants.roadWidth + 2 * GameConstants.roadEdge)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.butt
    ..strokeJoin = StrokeJoin.round;

  final Paint _bridgePaint = Paint()
    ..color = GameConstants.bridgeColor
    ..strokeWidth = GameConstants.cellSize * GameConstants.roadWidth
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.butt
    ..strokeJoin = StrokeJoin.round;

  final Paint _iceRoadOutlinePaint = Paint()
    ..color = GameConstants.roadEdgeColor
    ..strokeWidth =
        GameConstants.cellSize * (GameConstants.roadWidth + 2 * GameConstants.roadEdge)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.butt
    ..strokeJoin = StrokeJoin.round;

  final Paint _iceRoadPaint = Paint()
    ..color = const Color(0xFFA5DFEE)
    ..strokeWidth = GameConstants.cellSize * GameConstants.roadWidth
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.butt
    ..strokeJoin = StrokeJoin.round;

  final Paint _dirtRoadOutlinePaint = Paint()
    ..color = const Color(0xFF8C7A5A)
    ..strokeWidth =
        GameConstants.cellSize * (GameConstants.roadWidth + 2 * GameConstants.roadEdge)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.butt
    ..strokeJoin = StrokeJoin.round;

  final Paint _dirtRoadPaint = Paint()
    ..color = const Color(0xFFC0A477)
    ..strokeWidth = GameConstants.cellSize * GameConstants.roadWidth
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.butt
    ..strokeJoin = StrokeJoin.round;

  // MaskFilter.blur is fine on CanvasKit/web but absolutely lethal on mobile
  // Skia — even when cached into a chunk Picture, the rasterizer pays the
  // blur cost the first time the picture is rendered to the screen, and that
  // first paint is enough to ANR/crash on lower-end Android devices.
  // Smart junction / roundabout donut paints
  static final Paint _smartJunctionRingPaint = Paint()
    ..color = GameConstants.roadColor
    ..style = PaintingStyle.fill;

  // Slightly darker fill for the center island — gives the hub a distinct identity.
  // Subtle white glow ring drawn just outside the asphalt to give the hub a
  // soft highlight without expensive blur operations.
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
    // [PERF] Every caller of markAllDirty() is, by definition, saying "the
    // whole map's rendered state may have changed" -- the only place mountain
    // data itself can actually change (GridManager.rebuildMountain /
    // reconstructTerrainState) already goes through this same call, so
    // invalidating the mountain-chunk index here (rather than needing
    // GridManager to know about it) keeps it correct for free. It's rebuilt
    // lazily, once, the next time any chunk with mountains is drawn.
    _mountainCellsByChunk = null;
    // Same reasoning for the express-lane chunk index -- see its field
    // comment for why every `placedExpressLanes` mutation site already
    // funnels through a no-arg `markDirty()` (= `markAllDirty()`) call.
    _expressLaneChunkIndex = null;
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
    if (GameConstants.ambientTimeOfDayTint) _drawAmbientTimeOfDay(canvas);

    // Tier 3: Per-Frame Overlay (Demand, Previews, Selection Highlights)
    if (GameConstants.parkingHighlights) _drawParkingHighlights(canvas);
    _drawDemandIndicators(canvas);
    _drawParkedCars(canvas);
    _drawExpressLanePreview(canvas);
    _drawRoadPreview(canvas);
    // _drawCongestion(canvas);

    // Dynamic roadblock & maintenance event overlays
    _drawActiveEventOverlays(canvas);

    // Emergency event overlays
    _drawEmergencyOverlays(canvas);

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
    _spawnAnimations.removeWhere(
      (a) => now - a.startTime >= _SpawnAnimation.duration,
    );
    if (_spawnAnimations.isEmpty) return;

    // Pop-in: the cached building is hidden under a
    // ground-coloured veil while a live copy scales up with a small
    // overshoot, then the veil drops and the cached one shows through.
    final ground = _mapBackgroundColor;
    for (final anim in _spawnAnimations) {
      if (!gridManager.isValid(anim.pos.x, anim.pos.y)) continue;
      final cell = gridManager.grid[anim.pos.y][anim.pos.x];
      if (!cell.isHouse && !cell.isDestinationAnchor) continue;
      final t = ((now - anim.startTime) / _SpawnAnimation.duration).clamp(
        0.0,
        1.0,
      );
      const c1 = 1.70158;
      const c3 = c1 + 1.0;
      final u = t - 1.0;
      final scale = (1.0 + c3 * u * u * u + c1 * u * u).clamp(0.0, 1.3);

      for (final fp in gridManager.footprintOf(anim.pos)) {
        canvas.drawRect(
          Rect.fromLTWH(
            offsetX + fp.x * cellSize - 1,
            offsetY + fp.y * cellSize - 1,
            cellSize + 2,
            cellSize + 2,
          ),
          Paint()..color = ground,
        );
      }

      final color = GameConstants.getBuildingColor(cell.colorIndex ?? 0);
      final districtType = game.districtPlanner.getDistrictType(
        cell.colorIndex ?? 0,
      );
      final cx = offsetX + anim.pos.x * cellSize + cellSize / 2;
      final cy = offsetY + anim.pos.y * cellSize + cellSize / 2;
      canvas.save();
      if (cell.isHouse) {
        canvas.translate(cx, cy);
        canvas.scale(scale);
        canvas.translate(-cx, -cy);
        _drawHouse(
          canvas,
          cx,
          cy,
          color,
          BuildingProfile.residential.renderScale,
          districtType,
          cell.entrySide,
        );
      } else {
        final entry = cell.entrySide!;
        final ext = GridManager.destinationExtent(entry);
        final n = GameConstants.destinationFootprintSize;
        final bx = cx + ext.x * cellSize * (n - 1) / 2;
        final by = cy + ext.y * cellSize * (n - 1) / 2;
        canvas.translate(bx, by);
        canvas.scale(scale);
        canvas.translate(-bx, -by);
        _drawDestination(
          canvas,
          bx,
          by,
          color,
          entry,
          BuildingProfile.commercial.renderScale * n,
          districtType,
          anim.pos.x,
          anim.pos.y,
        );
      }
      canvas.restore();
    }
  }

  /// Idle houses show their car parked on the driveway (a house always has
  /// its car home when it isn't out on a trip).
  void _drawParkedCars(Canvas canvas) {
    final sprites = game.vehicleSprites;
    if (sprites.isEmpty) return;
    final viewport = game.camera.visibleWorldRect.inflate(cellSize);
    // Slots currently out on a trip, per house.
    final out = <String, Set<int>>{};
    for (final car in game.cars) {
      if (car.arrived) continue;
      out
          .putIfAbsent(
            '${car.spawnHousePos.x},${car.spawnHousePos.y}',
            () => <int>{},
          )
          .add(car.homeSlot);
    }
    final length = cellSize * 0.34;
    final width = length / game.vehicleSpriteAspect;
    for (final house in gridManager.houses) {
      final taken = out['${house.x},${house.y}'] ?? const <int>{};
      final cell = gridManager.grid[house.y][house.x];
      final sprite = sprites[(cell.colorIndex ?? 0) % sprites.length];
      for (int slot = 0; slot < GameConstants.homeParkingSlots; slot++) {
        if (taken.contains(slot)) continue;
        final spot = CarComponent.homeParkingSpot(
          gridManager,
          house,
          cellSize,
          offsetX,
          offsetY,
          slot,
        );
        if (spot == null) continue;
        final p = Offset(spot.$1.x, spot.$1.y);
        if (!viewport.contains(p)) continue;
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.rotate(spot.$2 + math.pi / 2);
        sprite.render(
          canvas,
          position: Vector2(-width / 2, -length / 2),
          size: Vector2(width, length),
          overridePaint: _parkedCarPaint,
        );
        canvas.restore();
      }
    }
  }

  static final Paint _parkedCarPaint = Paint()
    ..filterQuality = FilterQuality.medium
    ..isAntiAlias = true;

  /// The actual visible board background for the current map -- each
  /// MapType has its own distinct tint (Andes' is a warm dark brown,
  /// nothing like the others), NOT the generic GameConstants.backgroundColor.
  /// Extracted so anything else that needs to blend into "empty terrain"
  /// (e.g. the fog-of-war reveal overlay below) uses the SAME color this
  /// method actually paints, instead of a hardcoded fallback that visibly
  /// mismatches on every map except whichever one it happened to be tuned
  /// against.
  Color get _mapBackgroundColor {
    switch (game.selectedMapType) {
      case MapType.zen:
        return const Color(0xFF2A3A40);
      case MapType.andes:
        return const Color(0xFF3F3731);
      case MapType.nile:
        return const Color(0xFF2C4448);
      case MapType.arctic:
        return const Color(0xFF35434E);
      case MapType.savanna:
        return const Color(0xFF443C31);
      case MapType.delta:
        return const Color(0xFF2B4038);
    }
  }

  ui.Picture _buildTerrainPicture() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final bg = _mapBackgroundColor;

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

    // Ambient ground: a few big, very soft darker "hill" blobs and a couple
    // of lighter ones, like soft terrain shading behind the map.
    // Same seed per map so the landscape is stable across chunk rebuilds.
    final hills = math.Random(game.selectedMapType.index * 7919 + 11);
    // Each blob is three concentric discs at low alpha so its edge fades
    // instead of reading as a hard circle.
    final darkHill = Paint()..color = Colors.black.withValues(alpha: 0.03);
    final lightHill = Paint()..color = Colors.white.withValues(alpha: 0.012);
    void blob(double hx, double hy, double r, Paint paint) {
      canvas.drawCircle(Offset(hx, hy), r, paint);
      canvas.drawCircle(Offset(hx, hy), r * 0.78, paint);
      canvas.drawCircle(Offset(hx, hy), r * 0.55, paint);
    }
    for (int i = 0; i < 14; i++) {
      final hx = offsetX + hills.nextDouble() * width;
      final hy = offsetY + hills.nextDouble() * height;
      final r = cellSize * (2.5 + hills.nextDouble() * 4.0);
      // Two overlapping lumps per blob so they read as terrain, not dots.
      blob(hx, hy, r, darkHill);
      blob(hx + r * 0.6, hy + r * 0.25, r * 0.75, darkHill);
    }
    for (int i = 0; i < 6; i++) {
      final hx = offsetX + hills.nextDouble() * width;
      final hy = offsetY + hills.nextDouble() * height;
      final r = cellSize * (2.0 + hills.nextDouble() * 3.0);
      blob(hx, hy, r, lightHill);
    }

    // The ground is flat otherwise: no grid marks in the play area.

    return recorder.endRecording();
  }

  void _drawChunks(Canvas canvas) {
    // Determine visible area for culling
    final viewport = game.camera.visibleWorldRect;

    final chunkPx = GameConstants.cellSize * GameConstants.chunkSize;

    final minCX = ((viewport.left - offsetX) / chunkPx).floor().clamp(
      0,
      (gridManager.cols / GameConstants.chunkSize).floor(),
    );
    final maxCX = ((viewport.right - offsetX) / chunkPx).floor().clamp(
      0,
      (gridManager.cols / GameConstants.chunkSize).floor(),
    );
    final minCY = ((viewport.top - offsetY) / chunkPx).floor().clamp(
      0,
      (gridManager.rows / GameConstants.chunkSize).floor(),
    );
    final maxCY = ((viewport.bottom - offsetY) / chunkPx).floor().clamp(
      0,
      (gridManager.rows / GameConstants.chunkSize).floor(),
    );

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
    _drawTrees(canvas, minX, minY, maxX, maxY);
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
        if (cell.type != CellType.water && cell.type != CellType.bridge) {
          continue;
        }

        any = true;
        final rect = Rect.fromLTWH(
          offsetX + x * cellSize,
          offsetY + y * cellSize,
          cellSize,
          cellSize,
        );
        // Inflate more than the corner radius needs so neighbouring tiles
        // overlap into one continuous body of water (no scalloped seams).
        waterPath.addRRect(
          RRect.fromRectAndRadius(
            rect.inflate(cellSize * 0.12),
            Radius.circular(cellSize * 0.28),
          ),
        );
      }
    }

    if (!any) return;

    // Shoreline first, fill on top: the fill covers every interior stroke,
    // so only the outer coastline keeps its pale edge.
    final borderPaint = Paint()
      ..color = GameConstants.waterEdgeColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = cellSize * 0.12;
    canvas.drawPath(waterPath, borderPaint);
    final paint = Paint()
      ..color = GameConstants.waterColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(waterPath, paint);
  }

  /// Lazily builds (or reuses) the chunk-bucketed mountain-cell index. See
  /// the `_mountainCellsByChunk` field comment for why this exists.
  Map<int, List<GridPosition>> _ensureMountainIndex() {
    final existing = _mountainCellsByChunk;
    if (existing != null) return existing;

    final index = <int, List<GridPosition>>{};
    for (final cluster in gridManager.mountainClusters) {
      for (final cell in cluster.cells) {
        final chunkX = cell.x ~/ GameConstants.chunkSize;
        final chunkY = cell.y ~/ GameConstants.chunkSize;
        final key = chunkX + chunkY * 1000;
        (index[key] ??= []).add(cell);
      }
    }
    _mountainCellsByChunk = index;
    return index;
  }

  // Mountain paths are built per-chunk so each chunk picture only carries
  // its own mountains (drawing-side cost). [PERF] Which cells belong to
  // THIS chunk is now a direct index lookup via `_ensureMountainIndex()`,
  // not a full scan-and-filter over every mountain cluster in the whole
  // map on every chunk build -- see that index's field comment for the
  // Andes-map lag this fixed.
  /// Scattered trees (an olive oval canopy with a lighter cap and a tiny
  /// trunk) on empty tiles. Placement is a hash of the cell, so it is
  /// stable, and a tree simply disappears when something is built on its
  /// tile because the chunk is repainted from the grid.
  void _drawTrees(Canvas canvas, int minX, int minY, int maxX, int maxY) {
    final seed = game.selectedMapType.index * 1000003 + 17;
    final canopy = Paint()..color = GameConstants.treeColor;
    final cap = Paint()..color = GameConstants.treeHighlightColor;
    final trunk = Paint()
      ..color = GameConstants.treeTrunkColor
      ..strokeWidth = cellSize * 0.05
      ..strokeCap = StrokeCap.round;
    final shadow = Paint()
      ..color = GameConstants.buildingShadowColor
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, cellSize * 0.05);
    for (int x = minX; x < maxX; x++) {
      for (int y = minY; y < maxY; y++) {
        if (!gridManager.isValid(x, y)) continue;
        final cell = gridManager.grid[y][x];
        if (!cell.isEmpty) continue;
        int h = (x * 73856093) ^ (y * 19349663) ^ seed;
        h = (h ^ (h >> 13)) * 0x5bd1e995;
        h = h ^ (h >> 15);
        final u = (h & 0xFFFF) / 65535.0;
        if (u > 0.045) continue;
        final v = ((h >> 16) & 0xFFFF) / 65535.0;
        final cx = offsetX + x * cellSize + cellSize * (0.35 + v * 0.3);
        final cy = offsetY + y * cellSize + cellSize * (0.35 + u * 6.0);
        final r = cellSize * (0.15 + v * 0.05);
        final body = Rect.fromCenter(center: Offset(cx, cy), width: r * 2.2, height: r * 1.7);
        canvas.drawOval(body.shift(Offset(0, r * 0.35)), shadow);
        canvas.drawLine(Offset(cx, cy + r * 0.6), Offset(cx, cy + r * 1.15), trunk);
        canvas.drawOval(body, canopy);
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx - r * 0.25, cy - r * 0.3), width: r * 1.1, height: r * 0.7),
          cap,
        );
      }
    }
  }

  void _drawMountains(Canvas canvas, int minX, int minY, int maxX, int maxY) {
    final basePath = Path();
    final peaksPath = Path();
    final snowPath = Path();
    bool any = false;

    final chunkX = minX ~/ GameConstants.chunkSize;
    final chunkY = minY ~/ GameConstants.chunkSize;
    final chunkKey = chunkX + chunkY * 1000;
    final cellsInChunk = _ensureMountainIndex()[chunkKey];
    if (cellsInChunk != null) {
      for (final cell in cellsInChunk) {
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
    // Hills: darker lumps of the ground colour with a
    // slightly lighter crown, and a long shadow like the buildings cast.
    _drawLongShadow(canvas, basePath, cellSize * 0.5);
    canvas.drawPath(basePath, Paint()..color = Colors.black.withValues(alpha: 0.28));
    canvas.drawPath(peaksPath, Paint()..color = Colors.white.withValues(alpha: 0.05));
    // snowPath intentionally unused now.
    snowPath.reset();
  }

  /// Whether the cell one step past (x, y) in `entryDir` is a road-ish tile
  /// (plain road, express-lane node, tunnel, bridge, or smart junction) --
  /// i.e. whether a house/destination's driveway stub actually gets drawn
  /// on that side. Shared by `_drawRoadsAndExpressLanes` (decides whether to
  /// paint the stub at all) and `_drawHouse` (decides whether to grow the
  /// house's own footprint to meet that stub) so the two can never disagree
  /// about whether a given side is actually connected.
  bool _hasAdjacentRoad(int x, int y, Direction entryDir) {
    int adjX = x;
    int adjY = y;
    switch (entryDir) {
      case Direction.north:
        adjY--;
        break;
      case Direction.east:
        adjX++;
        break;
      case Direction.south:
        adjY++;
        break;
      case Direction.west:
        adjX--;
        break;
    }

    if (!gridManager.isValid(adjX, adjY)) return false;
    final adj = gridManager.grid[adjY][adjX];
    return adj.isRoad ||
        adj.isExpressLaneNode ||
        adj.isTunnel ||
        adj.isBridge ||
        adj.isSmartJunction;
  }

  void _drawRoadsAndExpressLanes(
    Canvas canvas,
    int minX,
    int minY,
    int maxX,
    int maxY,
  ) {
    final roadPath = Path();
    // Building driveway necks: drawn narrower than the road so a house
    // (0.6 of a tile) covers them cleanly — a little nub.
    final drivewayPath = Path();
    final dirtRoadPath = Path();
    final tunnelPath = Path();
    final bridgePath = Path();
    final iceRoadPath = Path();

    for (int x = minX; x < maxX; x++) {
      for (int y = minY; y < maxY; y++) {
        if (!gridManager.isValid(x, y)) continue;
        final cell = gridManager.grid[y][x];

        if ((!cell.isRoad &&
                !cell.isExpressLaneNode &&
                !cell.isTunnel &&
                !cell.isBridge &&
                !cell.isHouse &&
                !cell.isDestination) ||
            cell.isPendingDeletion) {
          continue;
        }

        final cx = offsetX + x * cellSize;
        final cy = offsetY + y * cellSize;
        final midX = cx + cellSize / 2;
        final midY = cy + cellSize / 2;

        if (cell.isHouse || cell.isDestination) {
          // Houses get a full-width apron from _drawHouse; only shops
          // need the narrow neck.
          final entryDir = cell.isHouse ? null : cell.entrySide;
          if (entryDir != null) {
            if (_hasAdjacentRoad(x, y, entryDir)) {
              double sx = midX;
              double sy = midY;
              double ex = midX;
              double ey = midY;

              final distToEdge = cellSize / 2;

              if (entryDir == Direction.north) {
                ex = midX;
                ey = midY - distToEdge;
              } else if (entryDir == Direction.east) {
                ex = midX + distToEdge;
                ey = midY;
              } else if (entryDir == Direction.south) {
                ex = midX;
                ey = midY + distToEdge;
              } else {
                ex = midX - distToEdge;
                ey = midY;
              }

              drivewayPath.moveTo(sx, sy);
              drivewayPath.lineTo(ex, ey);
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
        } else if (game.selectedMapType == MapType.savanna &&
            cell.owner == InfrastructureOwner.player) {
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
          if (n) {
            targetPath.moveTo(midX, midY);
            targetPath.lineTo(midX, cy);
          }
          if (e) {
            targetPath.moveTo(midX, midY);
            targetPath.lineTo(cx + cellSize, midY);
          }
          if (s) {
            targetPath.moveTo(midX, midY);
            targetPath.lineTo(midX, cy + cellSize);
          }
          if (w) {
            targetPath.moveTo(midX, midY);
            targetPath.lineTo(cx, midY);
          }
        }
      }
    }

    // --- Draw Paths ---
    _roadOutlinePaint.strokeCap = StrokeCap.round;
    _roadPaint.strokeCap = StrokeCap.round;
    canvas.drawPath(roadPath, _roadOutlinePaint);
    canvas.drawPath(roadPath, _roadPaint);
    _drivewayOutlinePaint
      ..color = _roadOutlinePaint.color
      ..strokeWidth = cellSize * (0.34 + 2 * GameConstants.roadEdge);
    _drivewayPaint
      ..color = _roadPaint.color
      ..strokeWidth = cellSize * 0.34;
    canvas.drawPath(drivewayPath, _drivewayOutlinePaint);
    canvas.drawPath(drivewayPath, _drivewayPaint);

    // Tunnel: the road's edges turn into a dashed line where
    // it passes under the mountain, nothing else.
    _tunnelPaint.strokeCap = StrokeCap.butt;
    canvas.drawPath(tunnelPath, _tunnelPaint);
    _drawDashedPath(
      canvas,
      tunnelPath,
      _tunnelDashPaint,
      cellSize * 0.18,
      cellSize * 0.12,
    );

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
        } else if (game.selectedMapType == MapType.savanna &&
            cell.owner == InfrastructureOwner.player &&
            cell.isRoad) {
          final trackPaint = Paint()
            ..color = const Color(0x355C4033)
            ..strokeWidth = 1.0
            ..style = PaintingStyle.stroke;

          if (cell.connUp || cell.connDown) {
            canvas.drawLine(
              Offset(midX - 3, cy),
              Offset(midX - 3, cy + cellSize),
              trackPaint,
            );
            canvas.drawLine(
              Offset(midX + 3, cy),
              Offset(midX + 3, cy + cellSize),
              trackPaint,
            );
          }
          if (cell.connLeft || cell.connRight) {
            canvas.drawLine(
              Offset(cx, midY - 3),
              Offset(cx + cellSize, midY - 3),
              trackPaint,
            );
            canvas.drawLine(
              Offset(cx, midY + 3),
              Offset(cx + cellSize, midY + 3),
              trackPaint,
            );
          }
        }
      }
    }

    _drawExpressLanesForChunk(canvas, minX, minY, maxX, maxY);
  }

  // Stroke-width factor shared between the actual draw (`laneStroke` below)
  // and `_expressLaneBounds()`'s padding, so the two can never drift apart
  // and silently under-pad the bounding box.
  static const double _expressLaneStrokeFactor = 0.74;

  /// Lazily builds (or reuses) the chunk-bucketed express-lane index. See
  /// the `_expressLaneChunkIndex` field comment for why this exists and why
  /// a lane can (and often does) belong to more than one chunk's bucket.
  Map<int, List<List<GridPosition>>> _ensureExpressLaneIndex() {
    final existing = _expressLaneChunkIndex;
    if (existing != null) return existing;

    final index = <int, List<List<GridPosition>>>{};
    final chunkPx = GameConstants.chunkSize * cellSize;
    for (final lane in gridManager.placedExpressLanes) {
      if (lane.length < 2) continue;
      final bounds = _expressLaneBounds(lane[0], lane[1]);
      if (bounds == null) continue;

      final minCX = ((bounds.left - offsetX) / chunkPx).floor();
      final maxCX = ((bounds.right - offsetX) / chunkPx).floor();
      final minCY = ((bounds.top - offsetY) / chunkPx).floor();
      final maxCY = ((bounds.bottom - offsetY) / chunkPx).floor();

      for (int cx = minCX; cx <= maxCX; cx++) {
        for (int cy = minCY; cy <= maxCY; cy++) {
          final key = cx + cy * 1000;
          (index[key] ??= []).add(lane);
        }
      }
    }
    _expressLaneChunkIndex = index;
    return index;
  }

  /// Conservative pixel-space bounding box for one express lane's painted
  /// curve (arc + stroke + ramp markers), used only to decide which
  /// chunk(s) the lane must be drawn into -- NOT used for the actual paint
  /// geometry, which `_drawExpressLanesForChunk` still computes itself from
  /// `lane[0]`/`lane[1]` so the two can never disagree on the curve shape.
  ///
  /// Reproduces the exact same arc construction as `_drawExpressLanesForChunk`
  /// (and CarComponent._rebuildSmoothPath's long-jump bezier): a quadratic
  /// bezier from o1 to o2 with control point `cp` offset perpendicular by
  /// `length * 0.15`. A quadratic bezier is a convex combination of its
  /// three control points at every t (weights (1-t)^2, 2t(1-t), t^2, which
  /// are all >= 0 and sum to 1), so the WHOLE curve is guaranteed to lie
  /// inside the bounding box of {o1, cp, o2} -- no need to solve for the
  /// curve's exact extrema. That box is then padded by the widest stroke's
  /// half-width (the outline paint, laneStroke + 3) plus a further
  /// cellSize*0.3 margin, comfortably covering the round stroke caps and the
  /// small ramp-marker triangles drawn just past each endpoint (their
  /// maximum reach beyond the raw curve is cellSize*0.126 sideways / 0.072
  /// outward -- see `_drawExpressLaneRamp` -- well inside that margin).
  Rect? _expressLaneBounds(GridPosition p1, GridPosition p2) {
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

    final outlineStroke = cellSize * _expressLaneStrokeFactor + 3;
    final pad = outlineStroke / 2 + cellSize * 0.3;

    if (length < 1) {
      // Degenerate (near-zero-length) lane; still needs a real box to be
      // bucketed correctly instead of silently vanishing.
      return Rect.fromCircle(center: o1, radius: pad);
    }

    final dir = Offset(delta.dx / length, delta.dy / length);
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

    final minX = math.min(o1.dx, math.min(o2.dx, cp.dx));
    final maxX = math.max(o1.dx, math.max(o2.dx, cp.dx));
    final minY = math.min(o1.dy, math.min(o2.dy, cp.dy));
    final maxY = math.max(o1.dy, math.max(o2.dy, cp.dy));

    return Rect.fromLTRB(minX - pad, minY - pad, maxX + pad, maxY + pad);
  }

  // Renamed from `_drawExpressLanesGlobal`: that name was accurate when it
  // looped over the entire map's lanes on every chunk (the bug fixed here).
  // Now it draws only the lanes relevant to THIS chunk -- looked up via
  // `_ensureExpressLaneIndex()`, which buckets each lane's conservative
  // pixel-space bounding box (see `_expressLaneBounds()`) under every chunk
  // it overlaps, so a lane that passes through a chunk without either
  // endpoint landing inside it still gets drawn (and correctly clipped) in
  // that middle chunk's Picture -- see the fix/qa-issues commit message for
  // the worked (0,0)->(1,0)->(2,0) example this was checked against.
  void _drawExpressLanesForChunk(
    Canvas canvas,
    int minX,
    int minY,
    int maxX,
    int maxY,
  ) {
    final chunkX = minX ~/ GameConstants.chunkSize;
    final chunkY = minY ~/ GameConstants.chunkSize;
    final chunkKey = chunkX + chunkY * 1000;
    final lanes = _ensureExpressLaneIndex()[chunkKey];
    if (lanes == null || lanes.isEmpty) return;

    // Wide enough that the car actually fits inside the lane, with a darker
    // outer rim for a "highway shoulders" feel. The arc direction and height
    // MUST match CarComponent._rebuildSmoothPath's long-jump arc (perp =
    // right-perp of forward, arcHeight = dist * 0.15) or the car will
    // visibly drive off the painted lane.
    //
    // [ROAD WIDTH 2026-09-01] Kept at the road fill width + 0.10*cellSize —
    // the same margin the original 0.58 had over the old 0.48 road fill —
    // so the express-lane ribbon stays visibly WIDER than the plain road it
    // connects to at each end, matching how it read before the widening.
    // Left independent of the car's own painted width (still comfortably
    // covers it either way; see _maxSafeLaneOffsetMagnitude in
    // car_component.dart for that real number, cellSize*0.2634).
    // Express lane: a violet band a bit wider than a road, pale
    // diagonal dashes along it, and a round white ramp badge at each end.
    final laneStroke = cellSize * GameConstants.roadWidth * 1.3;
    final lanePaint = Paint()
      ..color = GameConstants.expressLaneColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = laneStroke
      ..strokeCap = StrokeCap.round;

    final laneOutlinePaint = Paint()
      ..color = GameConstants.expressLaneBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = laneStroke + cellSize * GameConstants.roadEdge * 2
      ..strokeCap = StrokeCap.round;

    final arrowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = cellSize * 0.10
      ..strokeCap = StrokeCap.butt;

    final rampFillPaint = Paint()..color = Colors.white;
    final rampOutlinePaint = Paint()
      ..color = const Color(0xFF1B1F27)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final lane in lanes) {
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
        // Pale slanted dashes across the band (the express-lane texture).
        final half = laneStroke * 0.42;
        for (double d = cellSize * 0.5; d < totalLen - cellSize * 0.4; d += cellSize * 0.42) {
          final tan = metric.getTangentForOffset(d);
          if (tan == null) continue;
          final c = tan.position;
          final tdir = tan.vector;
          final tperp = Offset(-tdir.dy, tdir.dx);
          final slant = Offset(tdir.dx, tdir.dy) * (half * 0.6);
          canvas.drawLine(c + tperp * half - slant, c - tperp * half + slant, arrowPaint);
        }
      }

      // Small ramp markers at each endpoint so the lane visibly "starts"
      // and "ends" at the road tile rather than melting into it.
      _drawExpressLaneRamp(canvas, o1, dir, rampFillPaint, rampOutlinePaint);
      _drawExpressLaneRamp(canvas, o2, -dir, rampFillPaint, rampOutlinePaint);
    }
  }

  void _drawExpressLaneRamp(
    Canvas canvas,
    Offset center,
    Offset forward,
    Paint fill,
    Paint outline,
  ) {
    // Round white badge with a dark centre dot: the on-ramp marker.
    final r = cellSize * 0.17;
    canvas.drawCircle(center, r, fill);
    canvas.drawCircle(center, r, outline);
    canvas.drawCircle(center, r * 0.32, Paint()..color = const Color(0xFF1B1F27));
  }

  // Orthogonal neighbor offsets shared by the building-adjacency clip below.
  static const _kOrthogonalOffsets = [
    [0, -1],
    [1, 0],
    [0, 1],
    [-1, 0],
  ];

  void _drawSmartJunctions(
    Canvas canvas,
    int minX,
    int minY,
    int maxX,
    int maxY,
  ) {
    // Larger hub design — outerR/innerR are centered on the FIXED r=0.75
    // driving centerline that car_component.dart's _rebuildSmoothPath
    // actually uses (multiple hard-coded cellSize*0.75 references there —
    // that radius is a pathing/timing constant and is NOT changed by the
    // 2026-09-01 road-width widening). Only the ring's radial THICKNESS
    // (outerR - innerR) moves, and it is kept equal to the road outline
    // width (0.76, was 0.60) so the ring reads as exactly as thick as the
    // visible road (fill + dark border) feeding into it — same relationship
    // the original 1.05/0.45 numbers had (0.60 ring thickness == the old
    // 0.60 outline width). The ring extends into adjacent cells, covering
    // road stubs cleanly.
    // Ring is one road-width wide, centred on the r = 0.75 centreline the
    // cars actually drive (a pathing constant, see CarComponent).
    final ringHalfThickness = GameConstants.roadWidth / 2;
    const ringR = GameConstants.junctionRingRadius;
    final outerR = cellSize * (ringR + ringHalfThickness);
    final innerR = cellSize * (ringR - ringHalfThickness);
    final glowR = outerR + cellSize * GameConstants.roadEdge * 2;
    final edge = Paint()
      ..color = GameConstants.roadEdgeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = cellSize * GameConstants.roadEdge * 2;
    final island = Paint()..color = _mapBackgroundColor;

    for (int x = minX; x < maxX; x++) {
      for (int y = minY; y < maxY; y++) {
        if (!gridManager.isValid(x, y)) continue;
        final cell = gridManager.grid[y][x];
        if (!cell.hasSmartJunction) continue;

        final cx = offsetX + x * cellSize + cellSize / 2;
        final cy = offsetY + y * cellSize + cellSize / 2;
        final center = Offset(cx, cy);

        // The bleed above (up to glowR ≈ 1.10×cellSize from center) reaches
        // well past this tile into each orthogonal neighbor — intentional,
        // so the asphalt merges cleanly with connecting road stubs instead of
        // leaving a seam. But when a neighbor is a house/destination rather
        // than a road, that same bleed would paint into the building's own
        // tile. Clip those specific neighbor tiles out of the bleed so the
        // asphalt stops cleanly at the shared tile edge — the same kind of
        // hard, tile-aligned boundary already used elsewhere in this renderer
        // (chunk clip rects, destination lot growth) — while every other
        // direction keeps the full, intentional bleed.
        List<Rect>? buildingNeighborRects;
        for (final off in _kOrthogonalOffsets) {
          final nx = x + off[0];
          final ny = y + off[1];
          if (!gridManager.isValid(nx, ny)) continue;
          final neighbor = gridManager.grid[ny][nx];
          if (neighbor.isHouse || neighbor.isDestination) {
            (buildingNeighborRects ??= []).add(
              Rect.fromLTWH(
                offsetX + nx * cellSize,
                offsetY + ny * cellSize,
                cellSize,
                cellSize,
              ),
            );
          }
        }

        final needsClip = buildingNeighborRects != null;
        if (needsClip) {
          canvas.save();
          final clipPath = Path()
            ..addRect(Rect.fromCircle(center: center, radius: glowR + 1))
            ..fillType = PathFillType.evenOdd;
          for (final rect in buildingNeighborRects) {
            clipPath.addRect(rect);
          }
          canvas.clipPath(clipPath);
        }

        // Layer 1 — soft glow bloom (drawn first, underneath everything)

        // Layer 2 — asphalt ring (full disk, then island punches the hole via island paint)
        canvas.drawCircle(center, outerR, _smartJunctionRingPaint);

        // Layer 3 — center island (slightly darker than background)
        canvas.drawCircle(center, innerR, island);

        // Layer 4 — outer edge crisp white outline
        canvas.drawCircle(center, outerR, edge);

        // Layer 5 — inner edge soft outline (island border)
        canvas.drawCircle(center, innerR, edge);
        // The little roundabout glyph in the island.
        canvas.drawCircle(center, innerR * 0.42, edge);

        if (needsClip) {
          canvas.restore();
        }
      }
    }
  }

  void _drawBuildings(Canvas canvas, int minX, int minY, int maxX, int maxY) {
    // Start one cell early: a 2x2 destination anchored just outside this
    // chunk still has part cells inside it (the chunk clip trims the rest).
    for (int x = minX - 1; x < maxX; x++) {
      for (int y = minY - 1; y < maxY; y++) {
        if (!gridManager.isValid(x, y)) continue;
        final cell = gridManager.grid[y][x];
        if (!cell.isHouse && !cell.isDestinationAnchor) continue;
        if (cell.isHouse && (x < minX || y < minY)) continue;

        final cx = offsetX + x * cellSize + cellSize / 2;
        final cy = offsetY + y * cellSize + cellSize / 2;

        final color = GameConstants.getBuildingColor(cell.colorIndex ?? 0);
        final districtType = game.districtPlanner.getDistrictType(
          cell.colorIndex ?? 0,
        );

        if (cell.isHouse) {
          _drawHouse(
            canvas,
            cx,
            cy,
            color,
            BuildingProfile.residential.renderScale,
            districtType,
            cell.entrySide,
          );
        } else {
          final entry = cell.entrySide!;
          final ext = GridManager.destinationExtent(entry);
          final n = GameConstants.destinationFootprintSize;
          // Centre of the whole block, not of the anchor cell.
          final bx = cx + ext.x * cellSize * (n - 1) / 2;
          final by = cy + ext.y * cellSize * (n - 1) / 2;
          _drawDestination(
            canvas,
            bx,
            by,
            color,
            entry,
            BuildingProfile.commercial.renderScale * n,
            districtType,
            x,
            y,
          );
        }
      }
    }
  }

  /// Long soft shadow every building casts toward the bottom-right, like
  /// A single light source. Drawn into one alpha layer so the
  /// overlapping copies don't stack up darker.
  /// Short, soft drop shadow straight below [shape], offset by [length]:
  /// a lit-from-above look. (Name kept from the earlier long cast shadow.)
  void _drawLongShadow(Canvas canvas, Path shape, double length) {
    final p = Paint()
      ..color = GameConstants.buildingShadowColor
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, length * 0.5);
    canvas.drawPath(shape.shift(Offset(0, length)), p);
  }

  /// A building block: flat top face of the colour, a darker band along
  /// the bottom for thickness, long shadow underneath.
  void _drawBlock(Canvas canvas, Rect rect, double radius, Color color, Color side) {
    final band = rect.height * 0.16;
    final full = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final top = RRect.fromRectAndRadius(
      Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height - band),
      Radius.circular(radius),
    );
    _drawLongShadow(
      canvas,
      Path()..addRRect(full),
      rect.width * GameConstants.buildingShadowLength,
    );
    canvas.drawRRect(full, Paint()..color = side);
    canvas.drawRRect(top, Paint()..color = color);
  }

  void _drawHouse(
    Canvas canvas,
    double cx,
    double cy,
    Color color,
    double scale,
    DistrictType districtType,
    Direction? entrySide,
  ) {
    final size = cellSize * scale * GameConstants.houseBlockScale;
    double bx = cx;
    double by = cy;
    if (entrySide != null) {
      // Block sits at the back of its tile; a pavement apron exactly one
      // road wide runs from the block face to the tile edge, where it meets
      // the driveway stub. The house's two cars park on it
      // (CarComponent.homeParkingSpot).
      final e = _dirOffset(entrySide);
      final shift = cellSize * GameConstants.houseBlockBackShift;
      bx = cx - e.dx * shift;
      by = cy - e.dy * shift;
      final halfW = cellSize * GameConstants.roadWidth / 2;
      final edge = cellSize * GameConstants.roadEdge;
      final a0 = size / 2 - shift - cellSize * 0.06; // tucked under the block
      final a1 = cellSize / 2; // tile edge
      // Rectangle [from]..[to] along the entry axis, [hw] half-wide across.
      Rect apron(double hw, double from, double to) {
        if (e.dx != 0) {
          final x0 = cx + e.dx * from;
          final x1 = cx + e.dx * to;
          return Rect.fromLTRB(math.min(x0, x1), cy - hw, math.max(x0, x1), cy + hw);
        }
        final y0 = cy + e.dy * from;
        final y1 = cy + e.dy * to;
        return Rect.fromLTRB(cx - hw, math.min(y0, y1), cx + hw, math.max(y0, y1));
      }
      canvas.drawRect(
        apron(halfW + edge, a0, a1),
        Paint()..color = GameConstants.roadEdgeColor,
      );
      canvas.drawRect(
        apron(halfW, a0, a1 + cellSize * 0.03),
        Paint()..color = GameConstants.roadColor,
      );
    }
    final rect = Rect.fromCenter(center: Offset(bx, by), width: size, height: size);
    final idx = GameConstants.buildingColors.indexOf(color);
    final side = idx >= 0
        ? GameConstants.getBuildingDarkColor(idx)
        : _bevelShade(color);
    _drawBlock(canvas, rect, size * 0.22, color, side);
  }

  static Offset _dirOffset(Direction d) {
    switch (d) {
      case Direction.north:
        return const Offset(0, -1);
      case Direction.south:
        return const Offset(0, 1);
      case Direction.east:
        return const Offset(1, 0);
      case Direction.west:
        return const Offset(-1, 0);
    }
  }

  /// Darker same-hue shade used for the "thickness" band under a building.
  static Color _bevelShade(Color c) =>
      Color.lerp(c, const Color(0xFF14161B), GameConstants.buildingBevelMix)!;

  /// Shop: a pavement lot card (road fill, light edge line)
  /// with the driveway running into it, hatch marks on the free tarmac, and
  /// a big bevelled block of the district colour casting its long shadow.
  /// Called with the CENTRE of the 2x2 block and a scale that already
  /// includes the footprint size; [gridX]/[gridY] are the anchor cell.
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
    final age = game.gridManager?.destinationAges["$gridX,$gridY"] ?? 0;
    final maturityProgress = (age / GameConstants.maturityThresholdWeeks)
        .clamp(0.0, 1.0);

    final lotScale =
        GameConstants.lotMinScale +
        (GameConstants.lotMaxScale - GameConstants.lotMinScale) *
            maturityProgress;
    final lotSize = size * lotScale;
    final lotRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: lotSize,
      height: lotSize,
    );
    final lotRRect = RRect.fromRectAndRadius(lotRect, Radius.circular(lotSize * 0.12));
    final edgeW = cellSize * GameConstants.roadEdge * 2;

    // Card: pavement fill with the same light edge the roads have.
    canvas.drawRRect(lotRRect, Paint()..color = GameConstants.lotColor);
    canvas.drawRRect(
      lotRRect,
      Paint()
        ..color = GameConstants.roadEdgeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = edgeW,
    );

    // Driveway runs into the card: fill over the edge line, then the two
    // side lines so the road's own edges continue onto the lot.
    final ax = offsetX + gridX * cellSize + cellSize / 2;
    final ay = offsetY + gridY * cellSize + cellSize / 2;
    final roadW = cellSize * GameConstants.roadWidth;
    final reach = (size - lotSize) / 2 + cellSize * 0.10 + edgeW;
    final Rect tongue;
    final edge = Paint()
      ..color = GameConstants.roadEdgeColor
      ..strokeWidth = edgeW;
    switch (entry) {
      case Direction.north:
        tongue = Rect.fromLTWH(ax - roadW / 2, lotRect.top - reach, roadW, reach + cellSize * 0.06);
        canvas.drawRect(tongue, Paint()..color = GameConstants.roadColor);
        canvas.drawLine(Offset(tongue.left, tongue.top), Offset(tongue.left, lotRect.top), edge);
        canvas.drawLine(Offset(tongue.right, tongue.top), Offset(tongue.right, lotRect.top), edge);
        break;
      case Direction.south:
        tongue = Rect.fromLTWH(ax - roadW / 2, lotRect.bottom - cellSize * 0.06, roadW, reach + cellSize * 0.06);
        canvas.drawRect(tongue, Paint()..color = GameConstants.roadColor);
        canvas.drawLine(Offset(tongue.left, lotRect.bottom), Offset(tongue.left, tongue.bottom), edge);
        canvas.drawLine(Offset(tongue.right, lotRect.bottom), Offset(tongue.right, tongue.bottom), edge);
        break;
      case Direction.east:
        tongue = Rect.fromLTWH(lotRect.right - cellSize * 0.06, ay - roadW / 2, reach + cellSize * 0.06, roadW);
        canvas.drawRect(tongue, Paint()..color = GameConstants.roadColor);
        canvas.drawLine(Offset(lotRect.right, tongue.top), Offset(tongue.right, tongue.top), edge);
        canvas.drawLine(Offset(lotRect.right, tongue.bottom), Offset(tongue.right, tongue.bottom), edge);
        break;
      case Direction.west:
        tongue = Rect.fromLTWH(lotRect.left - reach, ay - roadW / 2, reach + cellSize * 0.06, roadW);
        canvas.drawRect(tongue, Paint()..color = GameConstants.roadColor);
        canvas.drawLine(Offset(tongue.left, tongue.top), Offset(lotRect.left, tongue.top), edge);
        canvas.drawLine(Offset(tongue.left, tongue.bottom), Offset(lotRect.left, tongue.bottom), edge);
        break;
    }

    // The block sits toward the far corner from the driveway so the tarmac
    // in front of it stays open, like a real forecourt.
    final ext = GridManager.destinationExtent(entry);
    // Block pushed to the far corner, leaving a strip on the entry side
    // wide enough for two bays plus the corridor cars use to reach them.
    final bSize = lotSize * 0.50;
    final shift = lotSize * 0.12;
    final bRect = Rect.fromCenter(
      center: Offset(cx + ext.x * shift, cy + ext.y * shift),
      width: bSize,
      height: bSize,
    );
    final idx = GameConstants.buildingColors.indexOf(color);
    final side = idx >= 0
        ? GameConstants.getBuildingDarkColor(idx)
        : _bevelShade(color);

    // Two painted parking stalls on the open strip by the driveway; cars
    // pull into exactly these (CarComponent.stallCenter).
    final stallPaint = Paint()
      ..color = GameConstants.roadEdgeColor.withValues(alpha: 0.6)
      ..strokeWidth = cellSize * 0.04
      ..strokeCap = StrokeCap.round;
    // Bay lines: three strokes along the entry axis dividing the strip
    // into the two bays cars pull into (CarComponent.stallFor).
    final len = cellSize * 0.42;
    final half = GameConstants.shopBayPitch / 2;
    for (int k = 0; k < 3; k++) {
      final strip = CarComponent.bayStrip(0) - half + k * GameConstants.shopBayPitch;
      final a = CarComponent.shopPoint(gridX, gridY, entry, cellSize, offsetX, offsetY,
          GameConstants.shopBayAlong - 0.5 * len / cellSize, strip);
      final b = CarComponent.shopPoint(gridX, gridY, entry, cellSize, offsetX, offsetY,
          GameConstants.shopBayAlong + 0.5 * len / cellSize, strip);
      canvas.drawLine(a, b, stallPaint);
    }

    _drawBlock(canvas, bRect, bSize * 0.14, color, side);

    // White parcel chip on the block: the destination mark.
    _drawParcel(canvas, Offset(bRect.left + bSize * 0.22, bRect.top + bSize * 0.02), cellSize * 0.30, Colors.white);
  }

  /// Parcel-chip glyph: a small rounded box with a ground-coloured strap
  /// across it, standing on [base] (bottom centre), [h] tall. Reads as
  /// "a delivery is waiting here".
  void _drawParcel(Canvas canvas, Offset base, double h, Color color) {
    final w = h * 0.82;
    final bh = h * 0.68;
    final box = Rect.fromLTWH(base.dx - w / 2, base.dy - bh, w, bh);
    final rr = RRect.fromRectAndRadius(box, Radius.circular(w * 0.18));
    canvas.drawRRect(rr, Paint()..color = color);
    // Strap and flap line in the ground colour so they read as cut-outs.
    final strap = Paint()
      ..color = _mapBackgroundColor
      ..strokeWidth = w * 0.14
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(base.dx, box.top + bh * 0.12),
      Offset(base.dx, box.bottom - bh * 0.12),
      strap,
    );
    canvas.drawLine(
      Offset(box.left + w * 0.14, box.top + bh * 0.34),
      Offset(box.right - w * 0.14, box.top + bh * 0.34),
      strap..strokeWidth = w * 0.09,
    );
  }

  // [ROAD WIDTH 2026-09-01] The opening (dark hole) width/offset below track
  // the road fill width exactly (0.64, was 0.48; offset is always half of
  // that) so the portal's dark hole continues to exactly match the width of
  // the tunnel road painted through it. The headwall (concrete surround)
  // keeps the same +0.20*cellSize margin over the opening it had before
  // (0.68 = 0.48+0.20, now 0.84 = 0.64+0.20) — margin to the tile edge
  // shrinks from 16% to 8% of cellSize per side as a result (still positive,
  // but this is the tightest-margin change in the whole widening; flagged
  // as a residual visual-check item since a tunnel portal can be immediately
  // adjacent to other infrastructure and this was not checked in a browser).
  /// Stroke [path] as dashes: two parallel dashed lines, one on each edge of
  /// the road (offset by half the road width), so the dashed look sits on
  /// the road's outline rather than its centre.
  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint,
    double dash,
    double gap,
  ) {
    final half = cellSize * GameConstants.roadWidth / 2;
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        final end = math.min(d + dash, metric.length);
        final t0 = metric.getTangentForOffset(d);
        final t1 = metric.getTangentForOffset(end);
        if (t0 != null && t1 != null) {
          final n0 = Offset(-t0.vector.dy, t0.vector.dx) * half;
          final n1 = Offset(-t1.vector.dy, t1.vector.dx) * half;
          canvas.drawLine(t0.position + n0, t1.position + n1, paint);
          canvas.drawLine(t0.position - n0, t1.position - n1, paint);
        }
        d += dash + gap;
      }
    }
  }

  void _drawTunnelPortal(Canvas canvas, double cx, double cy, Direction dir) {
    // Tunnels read through their dashed edges alone; the
    // old concrete headwall portal is gone.
  }

  /// Bridge: the road simply continues over the water, and a
  /// pair of short dark tick marks across it at each shore says "bridge".
  void _drawBridgeRails(Canvas canvas, double cx, double cy, GridCell cell) {
    final tick = Paint()
      ..color = const Color(0xFF171A21)
      ..strokeWidth = cellSize * 0.07
      ..strokeCap = StrokeCap.round;
    final half = cellSize * (GameConstants.roadWidth / 2 + GameConstants.roadEdge + 0.05);
    final inset = cellSize * 0.10;
    final x = ((cx - offsetX) / cellSize).floor();
    final y = ((cy - offsetY) / cellSize).floor();
    bool shore(int nx, int ny) =>
        !gridManager.isValid(nx, ny) ||
        (!gridManager.grid[ny][nx].isBridge &&
            gridManager.grid[ny][nx].type != CellType.water);
    if (cell.connUp && shore(x, y - 1)) {
      final ty = cy - cellSize / 2 + inset;
      canvas.drawLine(Offset(cx - half, ty), Offset(cx + half, ty), tick);
    }
    if (cell.connDown && shore(x, y + 1)) {
      final ty = cy + cellSize / 2 - inset;
      canvas.drawLine(Offset(cx - half, ty), Offset(cx + half, ty), tick);
    }
    if (cell.connLeft && shore(x - 1, y)) {
      final tx = cx - cellSize / 2 + inset;
      canvas.drawLine(Offset(tx, cy - half), Offset(tx, cy + half), tick);
    }
    if (cell.connRight && shore(x + 1, y)) {
      final tx = cx + cellSize / 2 - inset;
      canvas.drawLine(Offset(tx, cy - half), Offset(tx, cy + half), tick);
    }
  }

  void _drawInfrastructure(
    Canvas canvas,
    int minX,
    int minY,
    int maxX,
    int maxY,
  ) {
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
          if (cell.connUp &&
              gridManager.isValid(x, y - 1) &&
              !gridManager.grid[y - 1][x].isTunnel) {
            _drawTunnelPortal(canvas, cx, cy, Direction.north);
          }
          if (cell.connRight &&
              gridManager.isValid(x + 1, y) &&
              !gridManager.grid[y][x + 1].isTunnel) {
            _drawTunnelPortal(canvas, cx, cy, Direction.east);
          }
          if (cell.connDown &&
              gridManager.isValid(x, y + 1) &&
              !gridManager.grid[y + 1][x].isTunnel) {
            _drawTunnelPortal(canvas, cx, cy, Direction.south);
          }
          if (cell.connLeft &&
              gridManager.isValid(x - 1, y) &&
              !gridManager.grid[y][x - 1].isTunnel) {
            _drawTunnelPortal(canvas, cx, cy, Direction.west);
          }
        } else if (cell.isBridge) {
          _drawBridgeRails(canvas, cx, cy, cell);
        }
      }
    }
  }

  // [ROAD WIDTH] Redesigned 2026-09-01 alongside the road-width widening
  // above. OLD DESIGN (see git history for the exact code): a free-standing
  // black "traffic light box" — an opaque rounded pill plus a short dark
  // pole stub beneath it — planted off-center in the tile at a fixed
  // cellSize*0.7 offset, lit by two saturated bulb dots (Colors.redAccent /
  // Colors.greenAccent, dimmed to Colors.red/green at 0.2 alpha when off).
  // Two problems: (1) it was a literal miniature real-world traffic-signal
  // icon — thick black outline, saturated red/green bulbs — while every
  // other piece of infrastructure here is flat/near-flat with soft
  // alpha-layered glows and deliberately desaturated colors (see the
  // congestionLowColor/HighColor comment below, which explicitly rejects
  // "flat-UI traffic-light yellow/red", and the smart-junction ring's
  // glow, which is built from flat alpha circles, never MaskFilter.blur —
  // see `_mountainBasePaint`'s comment above for why blur is avoided here).
  // (2) its size and cellSize*0.7 offset were never tied to the actual road
  // paint width, so widening the road (fill 0.48->0.64, outline 0.60->0.76)
  // left the box sitting on top of the now-wider paved lane instead of
  // clear of it — a dark pole appearing to stand in traffic.
  //
  // NEW DESIGN: a flat "+" pair of short lane-aligned bars painted directly
  // on the road surface at the intersection center — the same idiom the
  // (currently disabled) `_drawCongestion` road-tint overlay uses below:
  // signal state is shown by marking the road itself, not by standing an
  // object on it. Bar length/thickness are fractions of cellSize, so they
  // track the live road width automatically. The NS bar and EW bar glow in
  // the same soft, desaturated green already used for "traffic may flow
  // here" (GameConstants.expressLaneColor) when that axis has the
  // right-of-way, and sit as a barely-visible neutral tick (roadColor at
  // low alpha) when it doesn't — no red, keeping the same restraint the
  // congestion colors already apply. Direction stays unambiguous: a lit
  // vertical bar means N/S traffic is moving, a lit horizontal bar means
  // E/W traffic is moving, and — unlike the old design, which only ever
  // read Direction.north and inferred the rest — both bars can light up
  // together for the low-traffic "everyone gets a green" case that
  // `isGreenForDirection` already returns (nsCount + ewCount <= 1).
  void _drawTrafficLight(Canvas canvas, int x, int y, GridCell cell) {
    final opacity = cell.isPendingDeletion ? 0.3 : 1.0;
    final cx = offsetX + x * cellSize + cellSize / 2;
    final cy = offsetY + y * cellSize + cellSize / 2;

    final nsGreen = gridManager.isGreenForDirection(x, y, Direction.north);
    final ewGreen = gridManager.isGreenForDirection(x, y, Direction.east);
    final green = const Color(0xFF5AC878).withValues(alpha: opacity);
    final red = const Color(0xFFF04A5E).withValues(alpha: opacity);
    final rim = Paint()
      ..color = const Color(0xFF1B1F27).withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // One lamp per approach, sitting on the right-hand side of that lane at
    // the stop line — red/green lamp pairs.
    final d = cellSize * 0.30; // distance from centre to the stop line
    final o = cellSize * 0.14; // lateral offset to the lane's right side
    final r = cellSize * 0.07;
    void lamp(double lx, double ly, bool isGreen) {
      canvas.drawCircle(Offset(lx, ly), r, Paint()..color = isGreen ? green : red);
      canvas.drawCircle(Offset(lx, ly), r, rim);
    }
    if (cell.connUp) lamp(cx + o, cy - d, nsGreen); // southbound approach
    if (cell.connDown) lamp(cx - o, cy + d, nsGreen); // northbound approach
    if (cell.connRight) lamp(cx + d, cy + o, ewGreen); // westbound approach
    if (cell.connLeft) lamp(cx - d, cy - o, ewGreen); // eastbound approach
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
    // [PERF] Unlike the building bodies drawn into _buildChunkPicture (cached
    // per-chunk and only rebuilt when dirty), this loop runs unconditionally
    // every single frame with no caching. Left unculled, its cost scales with
    // the TOTAL number of destinations on the map -- not with what's actually
    // on screen or with active car count -- and each destination can cost
    // several drawCircle/drawArc/drawPath calls (more when mature or in
    // overflow). That's invisible on a small early map but grows steadily
    // through week 2-3+ as more destinations are placed (e.g. Andes), which
    // matches reported lag that static review of per-car/per-frame code
    // alone didn't explain. Cull to the visible viewport, same approach
    // _drawChunks already uses for the cached chunk pictures.
    final viewport = game.camera.visibleWorldRect.inflate(cellSize);
    for (final pos in gridManager.destinations) {
      final cell = gridManager.grid[pos.y][pos.x];
      // [CRITICAL] Prevent Role Contamination (Issue 3)
      // Only draw demand if the cell at this position is still actually a destination
      if (!cell.isDestination) continue;

      final fpN = GameConstants.destinationFootprintSize;
      final ext = cell.entrySide != null
          ? GridManager.destinationExtent(cell.entrySide!)
          : GridPosition(0, 0);
      final cx =
          offsetX +
          pos.x * cellSize +
          cellSize / 2 +
          ext.x * cellSize * (fpN - 1) / 2;
      final cy =
          offsetY +
          pos.y * cellSize +
          cellSize / 2 +
          ext.y * cellSize * (fpN - 1) / 2;
      if (!viewport.contains(Offset(cx, cy))) continue;

      final demand = gridManager.getDemand(pos);
      if (demand <= 0) continue;

      final key = '${pos.x},${pos.y}';
      final overflowLevel = gridManager.overflowLevels[key] ?? 0.0;

      final age = gridManager.destinationAges[key] ?? 0;
      final maturityProgress = (age / GameConstants.maturityThresholdWeeks)
          .clamp(0.0, 1.0);
      final isMature = maturityProgress >= 1.0;

      // Draw Maturity Aura — flat alpha pulse (no blur) for mobile. Fades in
      // smoothly with maturityProgress instead of popping on at the mature
      // threshold.
      if (GameConstants.maturityAura && maturityProgress > 0) {
        final t = game.elapsedTime * 2.0;
        final pulse = (0.5 + 0.5 * math.sin(t)).clamp(0.0, 1.0);
        final auraRadius = cellSize * (0.5 + pulse * 0.1 * maturityProgress);

        canvas.drawCircle(
          Offset(cx, cy),
          auraRadius,
          Paint()
            ..color = Colors.white.withValues(
              alpha: (0.05 + pulse * 0.05) * maturityProgress,
            ),
        );
      }

      if (overflowLevel > 0) {
        // Overflow timer: a thin gauge bar above the parcel chips that
        // fills red as the shop runs out of patience.
        final progress = overflowLevel.clamp(0.0, 1.0);
        final w = cellSize * fpN * 0.78;
        final y = cy - cellSize * fpN / 2 - cellSize * 0.50;
        final track = Paint()
          ..color = Colors.white.withValues(alpha: 0.28)
          ..strokeWidth = cellSize * 0.08
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(cx - w / 2, y), Offset(cx + w / 2, y), track);
        if (progress > 0.01) {
          canvas.drawLine(
            Offset(cx - w / 2, y),
            Offset(cx - w / 2 + w * progress, y),
            Paint()
              ..color = const Color(0xFFF04A5E)
              ..strokeWidth = cellSize * 0.08
              ..strokeCap = StrokeCap.round,
          );
        }
      }
      {
        // Parcel chips sit just above the block.
        final indicatorY = cy - cellSize * fpN / 2 - cellSize * 0.2;
        final pinH = cellSize * 0.34;
        final spacing = cellSize * 0.22;
        final maxDemand = isMature
            ? GameConstants.matureMaxDemand
            : GameConstants.maxDemand;

        for (int i = 0; i < demand; i++) {
          _drawParcel(
            canvas,
            Offset(cx - (demand - 1) * spacing / 2 + i * spacing, indicatorY + pinH * 0.5),
            pinH,
            i >= maxDemand - 2 ? const Color(0xFFF04A5E) : Colors.white,
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
      tintColor = Color.lerp(
        const Color(0xFFE26D5C),
        const Color(0xFF1A1040),
        t,
      )!;
      tintStrength = t * 0.15;
    } else {
      // Night → deep indigo, peaks at 0.85, then fades back to dawn
      final nightProgress = (weekProgress - 0.65) / 0.35;
      final nightIntensity = math.sin(
        nightProgress * math.pi,
      ); // peaks at center of night
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
        canvas.drawLine(
          Offset(cx - crossSize, cy - crossSize),
          Offset(cx + crossSize, cy + crossSize),
          borderPaint,
        );
        canvas.drawLine(
          Offset(cx - crossSize, cy + crossSize),
          Offset(cx + crossSize, cy - crossSize),
          borderPaint,
        );
      } else {
        // Draw subtle drafting grid marking (crosshair) in the center of blueprint tile
        final crossSize = cellSize * 0.15;
        canvas.drawLine(
          Offset(cx - crossSize, cy),
          Offset(cx + crossSize, cy),
          borderPaint,
        );
        canvas.drawLine(
          Offset(cx, cy - crossSize),
          Offset(cx, cy + crossSize),
          borderPaint,
        );
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

  // void _drawCongestion(Canvas canvas) {
  //   for (final pos in gridManager.infrastructure) {
  //     final cell = gridManager.getCell(pos.x, pos.y);
  //     if (!cell.isRoad && !cell.isExpressLaneNode) continue;
  //
  //     final load = gridManager.getRoadLoad(pos.x, pos.y);
  //     if (load <= 0) continue;
  //
  //     final ratio = (load / cell.capacity).clamp(0.0, 1.0);
  //     if (ratio < 0.4) continue;
  //
  //     final rect = Rect.fromLTWH(
  //       offsetX + pos.x * cellSize,
  //       offsetY + pos.y * cellSize,
  //       cellSize,
  //       cellSize,
  //     );
  //
  //     Color color;
  //     if (ratio >= 0.8) {
  //       color = GameConstants.congestionHighColor.withValues(alpha: 0.3);
  //     } else {
  //       color = GameConstants.congestionLowColor.withValues(alpha: 0.2);
  //     }
  //     canvas.drawRRect(
  //       RRect.fromRectAndRadius(rect.deflate(2), const Radius.circular(6)),
  //       Paint()..color = color,
  //     );
  //   }
  // }

  /// Draws a soft vignette/fog outside the active spawnable area (Issue: City Reveal)
  void _drawCityVignette(Canvas canvas) {
    if (game.spawnController == null) return;

    final cx = game.gridCols / 2.0;
    final cy = game.gridRows / 2.0;

    final dims = game.getSmoothActiveHalfDimensions();
    final hw = dims.x;
    final hh = dims.y;

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

    // Draw fully opaque solid overlay outside the active rectangle. [FIX]
    // Was GameConstants.backgroundColor (a generic dark navy) instead of
    // this map's actual terrain background (_mapBackgroundColor) -- visibly
    // mismatched on every map whose tint differs from that generic navy
    // (Andes, Savanna, etc.), showing as an obvious seam at the reveal edge.
    final paint = Paint()
      ..color = _mapBackgroundColor
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
    final textPainter = TextPainter(
      text: TextSpan(
        text: '⚠️',
        style: GoogleFonts.outfit(color: Colors.amber, fontSize: size),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(cx - textPainter.width / 2, cy - textPainter.height / 2),
    );
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
        Paint()..color = const Color(0x20E0F7FC),
      );

      // Draw drifting snowflakes (halved for performance and clean aesthetic)
      final snowPaint = Paint()..color = Colors.white.withValues(alpha: 0.7);
      final r = math.Random(42);
      for (int i = 0; i < 30; i++) {
        final rx = (r.nextDouble() * width + time * 40.0) % width;
        final ry = (r.nextDouble() * height + time * 50.0) % height;
        canvas.drawCircle(
          Offset(offsetX + rx, offsetY + ry),
          1.0 + r.nextDouble() * 1.5,
          snowPaint,
        );
      }
    } else if (game.activeEvent == 'dustStorm') {
      // Map-wide orange-brown sandstorm tint
      canvas.drawRect(
        Rect.fromLTWH(offsetX, offsetY, width, height),
        Paint()..color = const Color(0x25E5A65D),
      );

      // Draw drifting dust particles (halved)
      final dustPaint = Paint()
        ..color = const Color(0xFFC69C6D).withValues(alpha: 0.4);
      final r = math.Random(1337);
      for (int i = 0; i < 20; i++) {
        final rx = (r.nextDouble() * width + time * 80.0) % width;
        final ry = (r.nextDouble() * height + time * 20.0) % height;
        final length = 10.0 + r.nextDouble() * 15.0;
        canvas.drawLine(
          Offset(offsetX + rx, offsetY + ry),
          Offset(offsetX + rx + length, offsetY + ry + 1.0),
          dustPaint..strokeWidth = 0.8 + r.nextDouble() * 1.0,
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
        final ax = cx - cellSize * 0.4 + offsetPhase * cellSize * 0.8;
        final ay = cy + math.sin(offsetPhase * math.pi * 4.0) * 1.5;

        canvas.drawCircle(
          Offset(ax, ay),
          2.0,
          Paint()..color = const Color(0xFF8B5A2B),
        );
        canvas.drawCircle(
          Offset(ax + 2.0, ay - 1.2),
          1.2,
          Paint()..color = const Color(0xFF8B5A2B),
        );
      }
    }

    // 3. Drawbridge Open animation
    if (game.activeEvent == 'drawbridgeOpen' && game.activeEventPos != null) {
      final pos = game.activeEventPos!;
      final cx = offsetX + pos.x * cellSize + cellSize / 2;
      final cy = offsetY + pos.y * cellSize + cellSize / 2;
      final cell = gridManager.grid[pos.y][pos.x];

      // Draw flashing red warning light (minimalist)
      final flash = (time * 4.0).floor() % 2 == 0;
      canvas.drawCircle(
        Offset(cx, cy),
        cellSize * 0.45,
        Paint()
          ..color = (flash ? Colors.redAccent : Colors.transparent).withValues(
            alpha: 0.25,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

      // Draw bridge flaps open (two dark rects separated in the center)
      final bool isVertical =
          cell.infrastructureAxis == InfrastructureAxis.vertical;
      final bridgePaint = Paint()..color = const Color(0xFF424953);

      if (isVertical) {
        canvas.drawRect(
          Rect.fromLTWH(
            cx - cellSize * 0.15,
            cy - cellSize * 0.4,
            cellSize * 0.3,
            cellSize * 0.2,
          ),
          bridgePaint,
        );
        canvas.drawRect(
          Rect.fromLTWH(
            cx - cellSize * 0.15,
            cy + cellSize * 0.2,
            cellSize * 0.3,
            cellSize * 0.2,
          ),
          bridgePaint,
        );
      } else {
        canvas.drawRect(
          Rect.fromLTWH(
            cx - cellSize * 0.4,
            cy - cellSize * 0.15,
            cellSize * 0.2,
            cellSize * 0.3,
          ),
          bridgePaint,
        );
        canvas.drawRect(
          Rect.fromLTWH(
            cx + cellSize * 0.2,
            cy - cellSize * 0.15,
            cellSize * 0.2,
            cellSize * 0.3,
          ),
          bridgePaint,
        );
      }

      // Draw simple red barrier line
      final barrierPaint = Paint()
        ..color = Colors.redAccent
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      if (isVertical) {
        canvas.drawLine(
          Offset(cx - cellSize * 0.25, cy - cellSize * 0.3),
          Offset(cx + cellSize * 0.25, cy - cellSize * 0.3),
          barrierPaint,
        );
        canvas.drawLine(
          Offset(cx - cellSize * 0.25, cy + cellSize * 0.3),
          Offset(cx + cellSize * 0.25, cy + cellSize * 0.3),
          barrierPaint,
        );
      } else {
        canvas.drawLine(
          Offset(cx - cellSize * 0.3, cy - cellSize * 0.25),
          Offset(cx - cellSize * 0.3, cy + cellSize * 0.25),
          barrierPaint,
        );
        canvas.drawLine(
          Offset(cx + cellSize * 0.3, cy - cellSize * 0.25),
          Offset(cx + cellSize * 0.3, cy + cellSize * 0.25),
          barrierPaint,
        );
      }
    }

    // 4. Flash Flood submerged indicators
    if (game.activeEvent == 'flashFlood' && game.floodedRoads.isNotEmpty) {
      final floodPaint = Paint()
        ..color = const Color(0x602196F3)
        ..style = PaintingStyle.fill;

      for (final pos in game.floodedRoads) {
        final cx = offsetX + pos.x * cellSize + cellSize / 2;
        final cy = offsetY + pos.y * cellSize + cellSize / 2;

        canvas.drawCircle(Offset(cx, cy), cellSize * 0.4, floodPaint);

        final wavePaint = Paint()
          ..color = const Color(0xB02196F3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(Offset(cx - 5, cy - 2), Offset(cx - 1, cy), wavePaint);
        canvas.drawLine(Offset(cx - 1, cy), Offset(cx + 3, cy - 2), wavePaint);

        canvas.drawLine(
          Offset(cx - 3, cy + 2),
          Offset(cx + 1, cy + 4),
          wavePaint,
        );
        canvas.drawLine(
          Offset(cx + 1, cy + 4),
          Offset(cx + 5, cy + 2),
          wavePaint,
        );
      }
    }
  }

  void _drawActiveEventOverlays(Canvas canvas) {
    final eventManager = game.eventManager;

    for (final event in eventManager.activeEvents) {
      if (event.type == CityEventType.roadBlock && event.affectedTile != null) {
        final pos = event.affectedTile!;
        final cx = offsetX + pos.x * cellSize + cellSize / 2;
        final cy = offsetY + pos.y * cellSize + cellSize / 2;
        // Vector orange roadblock barricade
        final barrierW = cellSize * 0.5;
        final barrierH = cellSize * 0.22;
        final bRect = Rect.fromCenter(
          center: Offset(cx, cy),
          width: barrierW,
          height: barrierH,
        );

        // Base feet
        final footPaint = Paint()
          ..color = Colors.grey
          ..style = PaintingStyle.fill;
        canvas.drawRect(
          Rect.fromLTWH(cx - barrierW * 0.4, cy + barrierH * 0.3, 2, 4),
          footPaint,
        );
        canvas.drawRect(
          Rect.fromLTWH(cx + barrierW * 0.4 - 2, cy + barrierH * 0.3, 2, 4),
          footPaint,
        );

        // Barricade board
        final boardPaint = Paint()
          ..color = Colors.deepOrange
          ..style = PaintingStyle.fill;
        canvas.drawRect(bRect, boardPaint);

        // White stripes
        final stripePaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        for (int i = 0; i < 3; i++) {
          final sx = bRect.left + (i * 2 + 1) * (barrierW / 6.0);
          canvas.drawRect(
            Rect.fromLTWH(sx - 1.5, bRect.top, 3.0, barrierH),
            stripePaint,
          );
        }
      } else if (event.type == CityEventType.bridgeMaintenance &&
          event.affectedTile != null) {
        final pos = event.affectedTile!;
        final cx = offsetX + pos.x * cellSize + cellSize / 2;
        final cy = offsetY + pos.y * cellSize + cellSize / 2;

        // Minimalist vector wrench
        final wrenchPaint = Paint()
          ..color = Colors.blueGrey
          ..style = PaintingStyle.fill;

        // Wrench handle
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(cx, cy),
            width: 3,
            height: cellSize * 0.4,
          ),
          wrenchPaint,
        );
        // Wrench jaw (head)
        canvas.drawCircle(Offset(cx, cy - cellSize * 0.15), 4.5, wrenchPaint);
        canvas.drawCircle(
          Offset(cx, cy - cellSize * 0.15),
          1.8,
          Paint()
            ..color = GameConstants.backgroundColor
            ..style = PaintingStyle.fill,
        );
        // Clip notch
        canvas.drawRect(
          Rect.fromLTWH(cx - 1, cy - cellSize * 0.15 - 5, 2, 4),
          Paint()..color = GameConstants.backgroundColor,
        );
      } else if (event.type == CityEventType.festival &&
          event.affectedColor != null) {
        final colorIndex = event.affectedColor!;
        final destinations = gridManager.destinations.where(
          (d) => gridManager.grid[d.y][d.x].colorIndex == colorIndex,
        );
        final houses = gridManager.houses.where(
          (h) => gridManager.grid[h.y][h.x].colorIndex == colorIndex,
        );
        final allPositions = [...destinations, ...houses];

        for (final pos in allPositions) {
          final cx = offsetX + pos.x * cellSize + cellSize / 2;
          final cy = offsetY + pos.y * cellSize + cellSize / 2;

          // Simple, very soft pink ring
          final ringPaint = Paint()
            ..color = Colors.pinkAccent.withValues(alpha: 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2;
          canvas.drawCircle(Offset(cx, cy), cellSize * 0.65, ringPaint);

          // Vector festival indicator: 3 tiny colorful dots clustered
          final dot1 = Offset(cx, cy - cellSize * 0.65);
          final dot2 = Offset(cx - 3.5, cy - cellSize * 0.55);
          final dot3 = Offset(cx + 3.5, cy - cellSize * 0.55);

          canvas.drawCircle(
            dot1,
            2.0,
            Paint()..color = const Color(0xFFF48FB1),
          ); // pink
          canvas.drawCircle(
            dot2,
            1.8,
            Paint()..color = const Color(0xFFCE93D8),
          ); // purple
          canvas.drawCircle(
            dot3,
            2.0,
            Paint()..color = const Color(0xFFFFE082),
          ); // gold
        }
      } else if (event.type == CityEventType.trafficSurge &&
          event.affectedColor != null) {
        final colorIndex = event.affectedColor!;
        final destinations = gridManager.destinations.where(
          (d) => gridManager.grid[d.y][d.x].colorIndex == colorIndex,
        );

        for (final dest in destinations) {
          final cx = offsetX + dest.x * cellSize + cellSize / 2;
          final cy = offsetY + dest.y * cellSize + cellSize / 2;

          // Soft red ring
          final ringPaint = Paint()
            ..color = Colors.redAccent.withValues(alpha: 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2;
          canvas.drawCircle(Offset(cx, cy), cellSize * 0.65, ringPaint);

          // Minimalist lightning bolt path
          final path = Path()
            ..moveTo(cx + 1, cy - cellSize * 0.75)
            ..lineTo(cx - 2, cy - cellSize * 0.60)
            ..lineTo(cx, cy - cellSize * 0.60)
            ..lineTo(cx - 1, cy - cellSize * 0.45)
            ..lineTo(cx + 2, cy - cellSize * 0.63)
            ..lineTo(cx, cy - cellSize * 0.63)
            ..close();
          canvas.drawPath(
            path,
            Paint()
              ..color = Colors.amber
              ..style = PaintingStyle.fill,
          );
        }
      }
    }
  }

  void _drawEmergencyOverlays(Canvas canvas) {
    if (game.phase != GamePhase.playing) return;
    final eventManager = game.emergencyManager;
    final now = game.elapsedTime;

    for (final event in eventManager.activeEvents) {
      final pos = event.location;
      final cx = offsetX + pos.x * cellSize + cellSize / 2;
      final cy = offsetY + pos.y * cellSize + cellSize / 2;

      // Gentle, slow pulsing alpha for a thin red circle around the destination
      final pulseAlpha = 0.25 + 0.15 * math.sin(now * 3.0);
      final ringPaint = Paint()
        ..color = Colors.redAccent.withValues(alpha: pulseAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(Offset(cx, cy), cellSize * 0.7, ringPaint);

      // A very subtle, flat red warning dot or tiny 🚨 sign above the building, no bouncing
      final iconY = cy - cellSize * 0.75;
      final pct = (event.timeout / 60.0).clamp(0.0, 1.0);

      // Red Cross vector shape (Plus Sign)
      final crossPaint = Paint()
        ..color = Colors.redAccent
        ..style = PaintingStyle.fill;
      final crossW = cellSize * 0.3;
      final crossThick = cellSize * 0.08;

      // Horizontal bar
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(cx, iconY),
          width: crossW,
          height: crossThick,
        ),
        crossPaint,
      );
      // Vertical bar
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(cx, iconY),
          width: crossThick,
          height: crossW,
        ),
        crossPaint,
      );

      // Neat, tiny linear progress line right above the icon
      final barWidth = cellSize * 0.5;
      final barHeight = 2.0;
      final bx = cx - barWidth / 2;
      final by = iconY - 8.0;

      canvas.drawRect(
        Rect.fromLTWH(bx, by, barWidth, barHeight),
        Paint()..color = Colors.white12,
      );
      canvas.drawRect(
        Rect.fromLTWH(bx, by, barWidth * pct, barHeight),
        Paint()..color = Colors.redAccent,
      );
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
  static const double duration = 0.8; // seconds
  final GridPosition pos;
  final double startTime;
  _SpawnAnimation(this.pos, this.startTime);
}
