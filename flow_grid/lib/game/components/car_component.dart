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
import '../grid_manager.dart';
import '../map_generator.dart';

class CarComponent extends PositionComponent
    with HasGameReference<FlowGridGame> {
  /// Gated debug logging for the hot per-car simulation path (occupancy,
  /// reservations, deadlock breaking). Previously every one of these fired
  /// unconditionally, which — with many cars on screen — produced hundreds of
  /// console writes per second and measurably added up in debug/profile builds.
  static void _debugLog(String message) {
    if (GameConstants.debugInfrastructure) debugPrint(message);
  }

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

  /// Parking slot at home (0 or 1) held for the whole round trip, and the
  /// shop stall this trip pulls into. Assigned by the spawner.
  int homeSlot;
  int stallSlot;
  bool _fadeLaneAtStart = false;
  bool _fadeLaneAtEnd = false;

  /// Arc length of the in-lot part of the path (tongue mouth to bay) when
  /// the trip starts or ends at a shop; 0 otherwise. Drives the lot lock and
  /// the reduced lane offset inside the lot.
  double _lotRouteLength = 0.0;
  double _waitTimer = 0.0;
  bool onExpressLane = false;
  double travelTime = 0.0;
  bool _waitingAtSignal = false;
  // Dwell time parked in the shop's lot before heading home.
  static const double maxWaitTime = 2.6;
  String? routeId;
  final List<Vector2> _trailPositions = [];
  static const int _maxTrailPoints = 2;
  double _trailDecayTimer = 0.0;

  // Follow-the-leader
  double _lastTargetMultiplier = 1.0;
  double _currentSpeedMultiplier = 1.0;

  // [FIX] Turning smoothness: the raw per-frame curve-speed multiplier
  // computed in _updatePosition is a snapshot of "how curvy is the path
  // right here" with no memory of the previous frame, so applying it
  // directly to the distance integration could visibly "flinch" (snap
  // slower, then snap back) as the lookahead window crossed the corner
  // geometry. This eases toward that raw target at a bounded rate instead
  // of snapping to it every frame — see _updatePosition.
  double _currentCurveSpeedMultiplier = 1.0;

  // Simulation throttling
  double _simCheckTimer = 0;
  double _congestionMultiplier = 1.0;
  double _terrainSpeed = 1.0;

  // [PERF] The purely-geometric curve-speed *target* needs two
  // PathMetric.getTangentForOffset() probes; the ease toward it is what has
  // to run per frame. Recompute the target on the same 15 Hz bucket as the
  // signal/congestion checks (the eased value still moves every frame, so
  // nothing reads as stepped) and the hot path drops from three tangent
  // lookups per frame to one.
  bool _recomputeCurveTarget = true;
  double _curveSpeedTarget = 1.0;

  // [PERF] Scratch collections for the per-frame follow-the-leader scan.
  // These used to be freshly allocated every frame for every car; with 40+
  // cars on a busy board that is 120+ short-lived collections per frame.
  final List<CarComponent> _obstacleScratch = [];
  final List<GridPosition> _searchNodesScratch = [];
  final Set<GridPosition> _queriedScratch = {};

  /// Per-drone phase for the hover bob, so a row of parked drones doesn't
  /// bob in lockstep. Constant for the life of the instance.
  late final double _bobPhase = (hashCode % 97) * 0.13;

  // Lane offset multiplier on the perpendicular drive-on-the-right offset.
  // +1.0 = right side (default), -1.0 = left side. Smoothly interpolated
  // toward _targetLaneSign so the car visually arcs across the centerline
  // instead of teleporting when it needs to pull alongside a parked car.
  double _currentLaneSign = 1.0;
  double _targetLaneSign = 1.0;
  double _intersectionWaitingTimer = 0.0;
  late final double _deadlockBreakTimeout = 3.0 + Random().nextDouble() * 1.5;
  // Set once _intersectionWaitingTimer times out while this car is purely
  // "exitBlocked" (already holds its own reservation, but the cell two hops
  // ahead is at capacity — the "don't block the box" rule). Previously the
  // timeout/breaker only ever fired for cars still waiting on a reservation;
  // an exitBlocked-only car had no escape at all and could wait forever if
  // that downstream cell never freed up. Cleared once the car actually
  // advances past the contested node.
  bool _boxDeadlockOverride = false;

  CarComponent? _closestObstacle;
  final Set<CarComponent> _ignoredObstacles = {};
  double _deadlockTimer = 0.0;
  double _lotWaitTimer = 0.0;
  double _lotGateOverride = 0.0;
  double _signalWaitTimer = 0.0;

  // [FIX] Guards against double-unregistering (or, worse, a stale trip's
  // cleanup never running at all). `removeFromParent()` defers `onRemove()`
  // to Flame's lifecycle processing; CarPool.getCar() can pop this exact
  // pooled instance and reuseState() it for a brand-new trip in the same
  // frame, before the deferred onRemove() fires. Unregistering synchronously
  // in removeFromParent() (guarded by this flag so onRemove() doesn't run it
  // a second time) ensures the OLD trip's occupancy/reservation is always
  // cleared before the instance can possibly be reused.
  bool _occupancyUnregistered = false;

  // Roundabout dynamic lane tracking
  bool? _roundaboutInnerLane;
  bool get isRoundaboutInner => _roundaboutInnerLane ?? (hashCode % 2 == 0);

  // Acceleration
  // Gentle easing: ~1 s to full speed, soft stops.
  static const double accelerationRate = 1.1;
  static const double decelerationRate = 2.2;
  static const double startupAccelerationBonus = 1.3;

  // [FIX] Restart jitter. The anti-stall floor below used to be a hard
  // on/off switch keyed on `_lastTargetMultiplier < 0.15`: a drone pulling
  // away from a queue crosses that threshold repeatedly (the obstacle scan
  // re-measures the gap to its leader every frame), so the *applied* speed
  // snapped between the ramped value — a few hundredths just after a stop —
  // and the flat 0.08 floor, several times a second. At a 40 px tile and
  // 130 px/s that is a 3 px/s <-> 10 px/s flicker, which reads exactly like
  // the reported stutter. Fade the floor in across a band instead so the
  // applied speed stays continuous in `_lastTargetMultiplier`; on an open
  // road (`_lastTargetMultiplier == 1`) the floor is unchanged at 0.08.
  //
  // These live here rather than in GameConstants because another session
  // owns that file right now; move them there when convenient.
  static const double stallSpeedFloor = 0.08;
  static const double stallFloorFadeLow = 0.15;
  static const double stallFloorFadeHigh = 0.30;

  /// Slack (in path pixels) below which a hard advance cap counts as
  /// "held here": the drone is at the stop line and must not creep.
  static const double _holdEpsilon = 0.01;

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
    this.homeSlot = 0,
    this.stallSlot = 0,
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
    final shortId = hexId.length > 4
        ? hexId.substring(hexId.length - 4)
        : hexId;
    return 'Car#$shortId[col:$colorIndex]';
  }

  void _init({
    int? initialPathIndex,
    double? initialProgress,
    bool? initialReturning,
  }) {
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
    // Pull out from rest (startupAccelerationBonus brings it up quickly);
    // reuseState() already did this for pooled cars, fresh ones popped out
    // at full speed.
    _currentSpeedMultiplier = 0.0;
    _currentCurveSpeedMultiplier = 1.0;
    _curveSpeedTarget = 1.0;
    _recomputeCurveTarget = true;
    _lastTargetMultiplier = 1.0;
    _currentLaneSign = 1.0;
    _targetLaneSign = 1.0;
    _closestObstacle = null;
    _ignoredObstacles.clear();
    _deadlockTimer = 0.0;
    _lotWaitTimer = 0.0;
    _lotGateOverride = 0.0;
    _signalWaitTimer = 0.0;

    // [FIX] Moved ahead of _rebuildSmoothPath/_updatePosition below so
    // `size` is already set to this trip's vehicleType before
    // _updatePosition's lane-offset clamp (_maxSafeLaneOffsetMagnitude)
    // reads it — otherwise it would compute against the component's
    // just-constructed, not-yet-sized default.
    anchor = Anchor.center;
    priority = 10;
    _updateVehicleSize();

    _rebuildSmoothPath();

    // [FIX] Spawn-moment jitter: this used to gate the tangent-based
    // position+angle computation on `initialProgress != null`, which
    // CarPool.getCar() never passes for a brand-new (non-pooled)
    // CarComponent — every fresh outbound spawn fell through to the plain
    // grid-math branch below instead. That branch sets `position` but never
    // sets `angle` (PositionComponent defaults to 0) and applies no lane
    // offset, so the car rendered facing the wrong way and straddling the
    // centerline for its first visible frame(s), then visibly snapped to
    // the correct heading/lane offset the moment the first real
    // _updatePosition(dt) ran. `getPos(0)` inside _rebuildSmoothPath (the
    // smooth path's own start point) uses this exact same grid+door-side
    // formula, so computing the tangent-based position/angle here whenever
    // the smooth path built successfully reproduces the identical start
    // position while additionally setting angle and the standing lane
    // offset up front — matching what reuseState()'s snap-to-start block
    // already does for a pooled/reused car's new trip.
    //
    // [FIX] Spawn crash regression: this originally called
    // `_updatePosition(0)` directly, but that method reads `game.timeScale`
    // unconditionally. `_init()` runs synchronously from the constructor,
    // before the car has ever been added to the Flame component tree
    // (CarPool.getCar() constructs a brand-new CarComponent and only
    // *afterwards* does the caller add it to the game) — and FlowGridGame
    // does not mix in Flame's SingleGameInstance, so
    // HasGameReference.game is only documented as safe from onLoad onward.
    // Calling it earlier hits `_findGameAndCheck()`'s
    // `assert(game != null, ...)` on a still-parentless component, throwing
    // an AssertionError out of every fresh spawn's constructor in debug
    // builds — i.e. no car could ever spawn. reuseState() already avoids
    // this exact trap by inlining the tangent/lane-offset math instead of
    // calling _updatePosition(); do the same here rather than routing
    // through the shared (game-touching) method. Since dt is always 0 at
    // this call site, this is value-for-value identical to what
    // _updatePosition(0) would have produced for position/angle —
    // game.timeScale and the curve/roundabout speed multipliers only ever
    // scale the dt=0 distance delta, contributing nothing.
    if (_totalLength > 0) {
      _distanceTraveled = (initialProgress ?? 0.0) * _totalLength;
      final tangent = _metric?.getTangentForOffset(_distanceTraveled);
      if (tangent != null) {
        final fwd = tangent.vector;
        final lane = _safeLaneOffset() * _laneFade(_distanceTraveled);
        position = Vector2(
          tangent.position.dx - fwd.dy * lane,
          tangent.position.dy + fwd.dx * lane,
        );
        // Drones stay upright: the component never rotates with the path.
        angle = 0;
      }
    } else if (path.isNotEmpty) {
      final startPos = path[0];
      double sx = offsetX + startPos.x * cellSize + cellSize / 2;
      double sy = offsetY + startPos.y * cellSize + cellSize / 2;
      if (startPos.side != null) {
        final r = cellSize * 0.4;
        switch (startPos.side!) {
          case Direction.north:
            sy -= r;
          case Direction.east:
            sx += r;
          case Direction.south:
            sy += r;
          case Direction.west:
            sx -= r;
        }
      }
      position = Vector2(sx, sy);
    }
  }

  @override
  void onMount() {
    super.onMount();
    _registerOccupancy();
  }

  @override
  void removeFromParent() {
    // [FIX] Run occupancy/reservation cleanup for the OLD trip synchronously,
    // before Flame's deferred removal machinery kicks in. This closes the
    // window where CarPool.getCar() could reuse this pooled instance for a
    // new trip before the old trip's onRemove() ever fires.
    _unregisterOccupancyOnce();
    super.removeFromParent();
  }

  @override
  void onRemove() {
    _unregisterOccupancyOnce();
    super.onRemove();
  }

  void _unregisterOccupancyOnce() {
    if (_occupancyUnregistered) return;
    _occupancyUnregistered = true;
    _unregisterOccupancy();
  }

  /// Marks this drone arrived and immediately releases its cell occupancy
  /// and intersection reservations to prevent ghost-car deadlocks.
  void _markArrived() {
    arrived = true;
    _unregisterOccupancyOnce();
  }

  void _registerOccupancy() {
    // A fresh trip is starting (or resuming) for this car instance, so it is
    // safe (and necessary) to allow cleanup to run again the next time this
    // trip ends.
    _occupancyUnregistered = false;
    if (path.isEmpty || _currentPathIndex >= path.length) return;
    final pos = path[_currentPathIndex];
    final cell = game.gridManager?.getCell(pos.x, pos.y);
    if (cell != null && cell.isPassable) {
      final RoadOccupancy occupancy = game.getOrCreateOccupancy(pos);
      if (!occupancy.cars.contains(this)) {
        occupancy.cars.add(this);
        _debugLog("[ROAD_OCCUPY] Car $this entered (${pos.x}, ${pos.y})");
      }
      occupancy.waitingCars.remove(this);

      final cellType = cell.type;
      final connType = cell.connectionType;
      final isJunction =
          cellType == CellType.smartJunction ||
          cellType == CellType.trafficLight;
      final isIntersection =
          connType == ConnectionNodeType.intersection || isJunction;

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
              final axis =
                  (moveDir == Direction.east || moveDir == Direction.west)
                  ? InfrastructureAxis.horizontal
                  : InfrastructureAxis.vertical;
              occupancy.setReservedAxis(axis);
            }
          }
        }
      }
    }
  }

  void _unregisterOccupancy() {
    for (final pos in path) {
      final RoadOccupancy occupancy = game.getOrCreateOccupancy(pos);
      occupancy.cars.remove(this);
      occupancy.waitingCars.remove(this);
      occupancy.activeIntersectionCars.remove(this);
      occupancy.clearReservation(this);
      occupancy.resetIfIdle();
    }
  }

  InfrastructureAxis _getMoveAxis(GridPosition cur, GridPosition next) {
    if (next.x != cur.x) {
      return InfrastructureAxis.horizontal;
    } else {
      return InfrastructureAxis.vertical;
    }
  }

  Direction? _getStepDirection(GridPosition from, GridPosition to) {
    if (to.x > from.x) return Direction.east;
    if (to.x < from.x) return Direction.west;
    if (to.y > from.y) return Direction.south;
    if (to.y < from.y) return Direction.north;
    return null;
  }

  // [FIX] Smart-junction (roundabout) ring sub-nodes are the only path
  // entries that share their (x, y) with a path neighbor — a house/
  // destination entry node also carries a non-null `side` (the door/
  // driveway direction) but appears exactly once in the path, at a cell no
  // other node shares. Callers that need to distinguish "really on/entering
  // a roundabout ring" from "just approaching a building's own door" must
  // use this structural check rather than a bare `side != null` test — see
  // _updateLaneTarget, which previously used the bare test and mis-fired
  // the roundabout dual-lane logic on every building arrival/departure.
  bool _isJunctionNode(int i) {
    if (i < 0 || i >= path.length) return false;
    final p = path[i];
    if (p.side == null) return false;
    final prevSame = i > 0 && path[i - 1].x == p.x && path[i - 1].y == p.y;
    final nextSame =
        i < path.length - 1 && path[i + 1].x == p.x && path[i + 1].y == p.y;
    return prevSame || nextSame;
  }

  void _updateVehicleSize() {
    // Was 0.58 — with a 0.7-cellSize safe following distance between car
    // *centers*, that left only ~0.12 cellSize of actual gap between car
    // edges, so any correctly-spaced queue still visually read as cars
    // touching/overlapping/"stuck". Shrinking the sprite gives queued cars
    // real breathing room without changing the following-distance logic.
    //
    // [FIX] Bumped 0.44 -> 0.49 (~+11%): investigation into the "car looks
    // like a plain cylinder" report found the rendered silhouette is
    // genuinely tiny in typical play (roughly 6-21px wide depending on
    // zoom/DPR) with no filtering and a continuously-arbitrary rotation
    // angle each frame -- at that pixel count, no amount of sprite surface
    // detail (outline, shading) can survive; raw pixel count is the
    // dominant constraint. Verified safe against today's lane-offset clamp
    // (_maxSafeLaneOffsetMagnitude): margin stays positive for every
    // vehicle type at this size, including bus (the tightest case).
    //
    // [FIX] Dialed back 0.49 -> 0.46 per live feedback that cars now read
    // as too big -- the current sprite's bold white windows (much higher
    // contrast than the design this size was originally tuned for) stay
    // legible at this size too, so there's no need to keep the full bump.
    // Cars are roughly a fifth of a tile: small next to a
    // house and tiny next to a 2x2 shop. 0.34 keeps the sprite legible on
    // phones while restoring that size gap.
    final baseSize = cellSize * 0.34;
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
    int homeSlot = 0,
    int stallSlot = 0,
  }) {
    this.path = path;
    this.colorIndex = colorIndex;
    this.spawnHousePos = spawnHousePos;
    this.targetDest = targetDest;
    this.vehicleType = vehicleType;
    this.routeId = routeId;
    this.homeSlot = homeSlot;
    this.stallSlot = stallSlot;

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
    _currentCurveSpeedMultiplier = 1.0;
    _curveSpeedTarget = 1.0;
    _recomputeCurveTarget = true;
    _lastTargetMultiplier = 1.0;
    _currentLaneSign = 1.0;
    _targetLaneSign = 1.0;
    _roundaboutInnerLane = null;
    _intersectionWaitingTimer = 0.0;
    _closestObstacle = null;
    _ignoredObstacles.clear();
    _deadlockTimer = 0.0;
    _lotWaitTimer = 0.0;
    _lotGateOverride = 0.0;
    _signalWaitTimer = 0.0;

    priority = 10;
    _rebuildSmoothPath();

    // [FIX] Moved ahead of the snap-to-start block below so `size` already
    // reflects the NEW trip's vehicleType (a pooled car reused for a
    // different vehicle type would otherwise compute the snap's safe lane
    // offset against the previous trip's stale size).
    _updateVehicleSize();

    // Snap to the new path's starting cell so a reused-from-pool car doesn't
    // render at its previous trip's endpoint before the first update tick.
    if (path.isNotEmpty && _totalLength > 0) {
      final tangent = _metric?.getTangentForOffset(0);
      if (tangent != null) {
        final fwd = tangent.vector;
        final lane = _safeLaneOffset() * _laneFade(_distanceTraveled);
        position = Vector2(
          tangent.position.dx - fwd.dy * lane,
          tangent.position.dy + fwd.dx * lane,
        );
        // Drones stay upright: the component never rotates with the path.
        angle = 0;
      }
    } else if (path.isNotEmpty) {
      final startPos = path[0];
      position = Vector2(
        offsetX + startPos.x * cellSize + cellSize / 2,
        offsetY + startPos.y * cellSize + cellSize / 2,
      );
    }
  }

  /// Cars don't vanish at the door: the smooth path already ends on the
  /// parking spot (see the spurs in _rebuildSmoothPath), so this only snaps
  /// away the last bit of float error and squares the car up in its bay.
  void _parkAtCurrentEnd() {
    if (path.isEmpty) return;
    final i = path.length - 1;
    if (!_parksAt(i)) return;
    final spot = _parkingSpotFor(i);
    position = Vector2(spot.dx, spot.dy);
    angle = 0;
  }

  bool get _usesParking =>
      vehicleType != VehicleType.bus && vehicleType != VehicleType.emergency;

  /// True when path node [i] (first or last) is a building this car parks
  /// at: its own house on the home end, its shop on the delivery end.
  bool _parksAt(int i) {
    if (!_usesParking || path.isEmpty) return false;
    if (i != 0 && i != path.length - 1) return false;
    final p = path[i];
    if (p.side == null || _isJunctionNode(i)) return false;
    final isHome = p.x == spawnHousePos.x && p.y == spawnHousePos.y;
    final isDest = p.x == targetDest.x && p.y == targetDest.y;
    if (i == 0) return isReturning ? isDest : isHome;
    return isReturning ? isHome : isDest;
  }

  Offset _parkingSpotFor(int i) {
    final p = path[i];
    if (p.x == spawnHousePos.x && p.y == spawnHousePos.y) {
      final spot = homeSpotFor(
        p.x,
        p.y,
        p.side!,
        cellSize,
        offsetX,
        offsetY,
        homeSlot,
      );
      return Offset(spot.$1.x, spot.$1.y);
    }
    return stallFor(p.x, p.y, p.side!, cellSize, offsetX, offsetY, stallSlot);
  }

  /// Lane offset multiplier. 1 on the road; inside a shop lot it drops to
  /// [GameConstants.lotLaneScale] so drones going in and coming out keep to
  /// opposite sides of the corridor; over the last
  /// [GameConstants.parkingLaneFadeTiles] before a spot (and the first after
  /// one) it eases to 0 so the drone sits centred in its bay.
  double _laneFade(double d) {
    if (!_fadeLaneAtStart && !_fadeLaneAtEnd) return 1.0;
    final w = cellSize * GameConstants.parkingLaneFadeTiles;
    final lot = _lotRouteLength;
    if (w <= 0) return 1.0;
    double f = 1.0;
    if (_fadeLaneAtStart) {
      f = min(f, (d / w).clamp(0.0, 1.0));
      if (_startsAtShop && d < lot) f = min(f, GameConstants.lotLaneScale);
    }
    if (_fadeLaneAtEnd) {
      final left = _totalLength - d;
      f = min(f, (left / w).clamp(0.0, 1.0));
      if (_endsAtShop && left < lot) f = min(f, GameConstants.lotLaneScale);
    }
    return f;
  }

  bool get _startsAtShop =>
      path.isNotEmpty &&
      !(path.first.x == spawnHousePos.x && path.first.y == spawnHousePos.y);
  bool get _endsAtShop =>
      path.isNotEmpty &&
      !(path.last.x == spawnHousePos.x && path.last.y == spawnHousePos.y);

  static Vector2 _unit(Direction d) {
    switch (d) {
      case Direction.north:
        return Vector2(0, -1);
      case Direction.south:
        return Vector2(0, 1);
      case Direction.east:
        return Vector2(1, 0);
      case Direction.west:
        return Vector2(-1, 0);
    }
  }

  /// Direction the shop's parking strip runs (along the lot face the
  /// driveway meets), for the shop anchored with entry side [entry].
  static Vector2 stripDir(Direction entry) {
    final ext = GridManager.destinationExtent(entry);
    final vertical = entry == Direction.north || entry == Direction.south;
    return vertical
        ? Vector2(ext.x.toDouble(), 0)
        : Vector2(0, ext.y.toDouble());
  }

  /// A point in the shop anchored at ([x],[y]): [along] tiles from the
  /// anchor centre toward the road, [strip] tiles down the parking strip.
  static Offset shopPoint(
    int x,
    int y,
    Direction entry,
    double cellSize,
    double offsetX,
    double offsetY,
    double along,
    double strip,
  ) {
    final e = _unit(entry);
    final t = stripDir(entry);
    final ax = offsetX + x * cellSize + cellSize / 2;
    final ay = offsetY + y * cellSize + cellSize / 2;
    return Offset(
      ax + (e.x * along + t.x * strip) * cellSize,
      ay + (e.y * along + t.y * strip) * cellSize,
    );
  }

  /// Strip offset of bay [index] (0 or 1).
  static double bayStrip(int index) =>
      GameConstants.shopBayFirst +
      (index % GameConstants.shopBays) * GameConstants.shopBayPitch;

  /// Centre of bay [index] on the shop anchored at ([x],[y]). Shared with
  /// GridRenderer so the painted bay lines match where cars stop.
  static Offset stallFor(
    int x,
    int y,
    Direction entry,
    double cellSize,
    double offsetX,
    double offsetY,
    int index,
  ) => shopPoint(
    x,
    y,
    entry,
    cellSize,
    offsetX,
    offsetY,
    GameConstants.shopBayAlong,
    bayStrip(index),
  );

  /// The in-lot route between the tongue mouth and bay [index], listed from
  /// the tongue inward: corridor entry on the axis, corridor beside the
  /// bay, bay centre.
  static List<Offset> shopRoute(
    int x,
    int y,
    Direction entry,
    double cellSize,
    double offsetX,
    double offsetY,
    int index,
  ) {
    final corr = GameConstants.shopCorridorAlong;
    final strip = bayStrip(index);
    Offset pt(double a, double t) =>
        shopPoint(x, y, entry, cellSize, offsetX, offsetY, a, t);
    return [
      pt(0.5, 0),
      pt(corr, 0),
      pt(corr, strip),
      pt(GameConstants.shopBayAlong, strip),
    ];
  }

  static double _polylineLength(List<Offset> pts) {
    double len = 0;
    for (int i = 1; i < pts.length; i++) {
      len += (pts[i] - pts[i - 1]).distance;
    }
    return len;
  }

  /// True while this drone is driving inside a shop lot (past the tongue
  /// mouth on the way in, or not yet out of it on the way out). Parked
  /// drones and drones held at the gate do not count.
  bool get _movingInsideLot {
    if (arrived || isWaiting || _lotRouteLength <= 0) return false;
    if (!isReturning && _endsAtShop) {
      return _totalLength - _distanceTraveled < _lotRouteLength - 0.5;
    }
    if (isReturning && _startsAtShop) {
      return _distanceTraveled > 0.5 && _distanceTraveled < _lotRouteLength;
    }
    return false;
  }

  /// Spacing between drones queued for the same shop lot.
  double get _lotFollowGap => cellSize * 0.55;

  /// How many other outbound drones bound for the same shop are nearer to it
  /// than this one, so a queue can space itself out along the trace.
  int _lotQueueAhead() {
    final myRemaining = _totalLength - _distanceTraveled;
    int n = 0;
    for (final other in game.cars) {
      if (identical(other, this) || other.arrived || other.isReturning) {
        continue;
      }
      if (other._lotRouteLength <= 0) continue;
      if (other.targetDest.x != targetDest.x ||
          other.targetDest.y != targetDest.y) {
        continue;
      }
      if (other._totalLength - other._distanceTraveled < myRemaining) n++;
    }
    return n;
  }

  /// Returns the other car currently moving inside the destination shop's lot, if any.
  CarComponent? _blockingLotCar() {
    for (final other in game.cars) {
      if (identical(other, this) || other.arrived) continue;
      if (_ignoredObstacles.contains(other)) continue;
      if (other.targetDest.x != targetDest.x ||
          other.targetDest.y != targetDest.y) {
        continue;
      }
      if (other._movingInsideLot) return other;
    }
    return null;
  }

  /// True while this drone is physically located within the destination shop's lot
  /// (parked, dwelling, or still traversing the lot corridor).
  bool get isInsideShopLot {
    if (arrived || _lotRouteLength <= 0) return false;
    if (!isReturning && _endsAtShop) {
      return _totalLength - _distanceTraveled <= _lotRouteLength;
    }
    if (isReturning && _startsAtShop) {
      return _distanceTraveled < _lotRouteLength;
    }
    return false;
  }

  /// True while this drone is standing on a parking spot — a shop bay or a
  /// home pad — which sits off the trace, so it must not block traffic.
  ///
  /// [FIX] Queueing: the obstacle scan used to skip every `isWaiting` drone
  /// on the assumption that waiting == parked. That is not true for a bus
  /// dwelling at a stop, which sits squarely ON the trace: followers drove
  /// straight through it. `_fadeLaneAtEnd` is set by _rebuildSmoothPath
  /// exactly when this trip's path ends on a parking spot (a bus/emergency
  /// trip never does — see _parksAt/_usesParking), so pairing it with
  /// "reached the end of the path" is precisely the off-trace case.
  bool get _isParkedOffTrace =>
      isWaiting && _fadeLaneAtEnd && _distanceTraveled >= _totalLength - 0.5;

  // --- Heading -------------------------------------------------------------
  // Drones are saucers with no nose, so `angle` is pinned to 0 for every one
  // of them (see _updatePosition). Anything that needs to know which way a
  // drone is *travelling* must therefore ask the path, not the component.
  //
  // [FIX] Queueing: the follow-the-leader scan derived facing from
  // `cos(angle)`/`sin(angle)`, which after the no-rotation change means every
  // drone is treated as pointing due east. Its "is the obstacle in front of
  // me" dot product then rejected every leader that was not to the east, so
  // drones travelling west/north/south never saw the drone ahead at all and
  // drove into it; and its "is the obstacle oncoming" dot product was a
  // constant 1.0, so nothing was ever classified as oncoming. Both now read
  // the path tangent instead.
  double _headingX = 1.0;
  double _headingY = 0.0;
  double _headingAt = double.nan;

  /// Unit forward vector along the path at this drone's current progress.
  /// Cached against `_distanceTraveled`, so a scan that probes several
  /// neighbours costs at most one tangent lookup per drone per frame.
  void _refreshHeading() {
    if (_headingAt == _distanceTraveled) return;
    _headingAt = _distanceTraveled;
    final metric = _metric;
    if (metric == null || _totalLength <= 0) {
      _setHeadingFromNodes();
      return;
    }
    final tangent = metric.getTangentForOffset(
      _distanceTraveled.clamp(0.0, _totalLength),
    );
    if (tangent == null) {
      _setHeadingFromNodes();
      return;
    }
    _setHeading(tangent.vector.dx, tangent.vector.dy);
  }

  void _setHeading(double dx, double dy) {
    final len = sqrt(dx * dx + dy * dy);
    if (len > 1e-6) {
      _headingX = dx / len;
      _headingY = dy / len;
      return;
    }
    _setHeadingFromNodes();
  }

  /// Fallback for a degenerate/absent tangent: the direction of the grid
  /// edge the drone is currently on.
  void _setHeadingFromNodes() {
    if (path.length < 2) return;
    final i = _currentPathIndex.clamp(0, path.length - 1);
    final int a = i + 1 < path.length ? i : i - 1;
    if (a < 0 || a + 1 >= path.length) return;
    final dx = (path[a + 1].x - path[a].x).toDouble();
    final dy = (path[a + 1].y - path[a].y).toDouble();
    final len = sqrt(dx * dx + dy * dy);
    if (len > 1e-6) {
      _headingX = dx / len;
      _headingY = dy / len;
    }
  }

  /// How far this drone may advance along the path this frame, and whether
  /// it is being held right on that line (so the caller can ask the normal
  /// deceleration ramp for a speed of zero instead of hard-zeroing the
  /// multiplier — see the restart-jitter note on [_updatePosition]).
  ///
  /// [dt] is the real frame delta, not the speed-scaled one.
  (double, bool) _advanceCap(
    double dt,
    bool hasReservation,
    bool exitBlocked, {
    double obstacleGap = double.infinity,
  }) {
    double cap = obstacleGap;

    // Don't cross into the next cell without a reservation, and don't block
    // the box.
    if ((!hasReservation || exitBlocked) &&
        _currentPathIndex + 1 < path.length) {
      final cellEndProgress =
          (_currentPathIndex + 1 < segmentStartOffsets.length)
          ? segmentStartOffsets[_currentPathIndex + 1]
          : _totalLength;
      if (cellEndProgress > _distanceTraveled - cellSize * 0.1) {
        cap = min(cap, max(0.0, cellEndProgress - _distanceTraveled));
      }
    }

    // One drone moves inside a shop lot at a time. _blockingLotCar() is an O(cars)
    // scan, so — as the old inline check did — only consult it once the gate
    // is within this frame's reach.
    if (_lotRouteLength > 0) {
      final reach = max(cellSize * 0.25, dt * speed * game.timeScale * 3.0);
      if (!isReturning && _endsAtShop) {
        // Gate on the driveway tile, half a tile short of the tongue mouth.
        // Every drone bound for this shop shares the same path end, so they
        // all used to hold on the SAME spot and render on top of each other.
        // Each one now stops a follow-distance further back than the drones
        // already ahead of it, forming a line along the trace.
        final base = _totalLength - _lotRouteLength - cellSize * 0.5;
        // Look far enough ahead to catch the back of that queue, not just
        // this frame's travel.
        if (_distanceTraveled > base - reach - _lotFollowGap * 4) {
          final blocker = _blockingLotCar();
          if (blocker != null) {
            _closestObstacle ??= blocker;
            if (_lotGateOverride > 0) {
              _lotGateOverride -= dt;
              // Sustained override window: allow drone to push through the gate
            } else if (_lotWaitTimer > 2.0) {
              // Deadlock timeout! Grant sustained override to push through gate
              _lotGateOverride = 2.5;
              _lotWaitTimer = 0.0;
              _ignoredObstacles.add(blocker);
              _debugLog(
                "[LOT_DEADLOCK_BREAK] Car $this broke lot gate hold for dest (${targetDest.x}, ${targetDest.y})",
              );
            } else {
              _lotWaitTimer += dt;
              final queuePos = _lotQueueAhead().clamp(0, 5);
              final gate = base - queuePos * _lotFollowGap;
              final room = gate - _distanceTraveled;
              if (room >= 0 && room < reach) {
                cap = min(cap, room);
              } else if (room < 0 && _distanceTraveled >= gate - cellSize * 0.15) {
                cap = 0.0;
              }
            }
          } else {
            _lotWaitTimer = 0.0;
            _lotGateOverride = 0.0;
          }
        }
      } else if (isReturning && _startsAtShop && _distanceTraveled <= 0.5) {
        final blocker = _blockingLotCar();
        if (blocker != null) {
          _closestObstacle ??= blocker;
          if (_lotGateOverride > 0) {
            _lotGateOverride -= dt;
            // Sustained override window: allow drone to pull out of bay
          } else if (_lotWaitTimer > 2.0) {
            // Deadlock timeout! Grant sustained override to pull out of bay
            _lotGateOverride = 2.5;
            _lotWaitTimer = 0.0;
            _ignoredObstacles.add(blocker);
            _debugLog(
              "[LOT_DEADLOCK_BREAK] Returning Car $this broke lot exit hold for dest (${targetDest.x}, ${targetDest.y})",
            );
          } else {
            _lotWaitTimer += dt;
            cap = 0.0;
          }
        } else {
          _lotWaitTimer = 0.0;
          _lotGateOverride = 0.0;
        }
      }
    }

    return (cap, cap <= _holdEpsilon);
  }

  /// Appends [pts] to both paths from [from] as straight runs joined by
  /// rounded corners of radius up to [rMax] (kappa cubics, like the road
  /// corners). Returns the new pen position.
  static Offset _appendRoundedPolyline(
    ui.Path a,
    ui.Path b,
    Offset from,
    List<Offset> pts,
    double rMax,
  ) {
    const kappa = 0.5522847498;
    final all = <Offset>[from, ...pts];
    for (int k = 1; k < all.length - 1; k++) {
      final dIn = all[k] - all[k - 1];
      final dOut = all[k + 1] - all[k];
      final lIn = dIn.distance;
      final lOut = dOut.distance;
      if (lIn < 1e-6 || lOut < 1e-6) continue;
      final uIn = dIn / lIn;
      final uOut = dOut / lOut;
      final cross = (uIn.dx * uOut.dy - uIn.dy * uOut.dx).abs();
      final dot = uIn.dx * uOut.dx + uIn.dy * uOut.dy;
      if (cross < 1e-3 && dot > 0) continue; // straight through
      final r = min(rMax, min(lIn, lOut) * 0.5);
      final s0 = all[k] - uIn * r;
      final s1 = all[k] + uOut * r;
      final cp1 = s0 + uIn * (r * kappa);
      final cp2 = s1 - uOut * (r * kappa);
      a.lineTo(s0.dx, s0.dy);
      b.lineTo(s0.dx, s0.dy);
      a.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, s1.dx, s1.dy);
      b.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, s1.dx, s1.dy);
    }
    final last = all.last;
    a.lineTo(last.dx, last.dy);
    b.lineTo(last.dx, last.dy);
    return last;
  }

  /// Cubic S-bend from [from] to [to] with both tangents along [dir].
  static void _appendSBend(
    ui.Path a,
    ui.Path b,
    Offset from,
    Offset to,
    Offset dir,
  ) {
    final len = (to - from).distance;
    final cp1 = from + dir * (len * 0.45);
    final cp2 = to - dir * (len * 0.45);
    a.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, to.dx, to.dy);
    b.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, to.dx, to.dy);
  }

  /// Where car number [slot] of the house at ([x],[y]) sits when it is
  /// home: side by side on the apron in front of the block, nose toward the
  /// house. Returns (position, heading). Pure geometry, see [stallFor].
  static (Vector2, double) homeSpotFor(
    int x,
    int y,
    Direction entry,
    double cellSize,
    double offsetX,
    double offsetY,
    int slot,
  ) {
    final e = _unit(entry);
    final cx = offsetX + x * cellSize + cellSize / 2;
    final cy = offsetY + y * cellSize + cellSize / 2;
    final side = (slot % GameConstants.homeParkingSlots) == 0 ? -1.0 : 1.0;
    final along = cellSize * GameConstants.homeParkingAlong;
    final lat = cellSize * GameConstants.homeParkingLateral * side;
    return (
      Vector2(cx + e.x * along - e.y * lat, cy + e.y * along + e.x * lat),
      atan2(-e.y, -e.x),
    );
  }

  /// [homeSpotFor] looked up from the grid. Shared with GridRenderer so the
  /// parked glyphs it draws for idle slots land exactly where cars park.
  static (Vector2, double)? homeParkingSpot(
    GridManager gm,
    GridPosition house,
    double cellSize,
    double offsetX,
    double offsetY,
    int slot,
  ) {
    if (!gm.isValid(house.x, house.y)) return null;
    final entry = gm.getCell(house.x, house.y).entrySide;
    if (entry == null) return null;
    return homeSpotFor(
      house.x,
      house.y,
      entry,
      cellSize,
      offsetX,
      offsetY,
      slot,
    );
  }

  double get _vehicleSpeedMultiplier {
    switch (vehicleType) {
      case VehicleType.car:
        return 1.0;
      case VehicleType.truck:
        return GameConstants.truckSpeedMultiplier;
      case VehicleType.serviceVan:
        return GameConstants.serviceVanSpeedMultiplier;
      case VehicleType.bus:
        return 0.7;
      case VehicleType.emergency:
        return 1.8;
    }
  }

  void _rebuildSmoothPath() {
    _smoothPath = ui.Path();
    // The curve under the drone just changed, so any cached heading taken at
    // the current arc length is stale even if that arc length is unchanged.
    _headingAt = double.nan;

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
    // path build and left the car invisible on the road). Shared with
    // _updateLaneTarget/_maxSafeLaneOffsetMagnitude via _isJunctionNode so
    // both use the exact same definition of "real junction node".
    bool isJunctionNodeAt(int i) => _isJunctionNode(i);

    Offset getPos(int i) {
      final p = path[i];
      final midX = offsetX + p.x * cellSize + cellSize / 2;
      final midY = offsetY + p.y * cellSize + cellSize / 2;
      if (p.side == null) return Offset(midX, midY);

      // [FIX] House-entry: the very last path node is always the
      // destination/home building's own cell (see the outbound-path splice
      // in flow_grid_game.dart._updateTrafficSimulation, and the
      // return-path build in _onArrivedAtDestination/startReturnTrip
      // below) — never a mid-route junction sub-node. Every OTHER
      // `side`-bearing node uses the door/hub offset below because the car
      // is only passing through it. Applying that same offset to the
      // terminal node instead pulled the rendered curve's endpoint back to
      // the tile's near edge, so a car looked like it stopped short of (or
      // vanished on) the road instead of visibly continuing onto the
      // building tile itself. Drive the final node all the way to the tile
      // center.
      if (i == path.length - 1 && !isJunctionNodeAt(i)) {
        return Offset(midX, midY);
      }

      // Junction sub-nodes sit on the enlarged hub ring so the smooth-path
      // bezier matches the wider visible donut; building entries keep the
      // tighter 0.4 offset so the parking position lands at the door.
      final r = isJunctionNodeAt(i)
          ? cellSize * GameConstants.junctionRingRadius
          : cellSize * 0.4;
      switch (p.side!) {
        case Direction.north:
          return Offset(midX, midY - r);
        case Direction.east:
          return Offset(midX + r, midY);
        case Direction.south:
          return Offset(midX, midY + r);
        case Direction.west:
          return Offset(midX - r, midY);
      }
    }

    // Side angle in canvas (y-down) coords: 0=east, pi/2=south, pi=west,
    // -pi/2=north. Used by the smart-junction arc.
    double sideAngle(Direction d) {
      switch (d) {
        case Direction.east:
          return 0.0;
        case Direction.south:
          return pi / 2;
        case Direction.west:
          return pi;
        case Direction.north:
          return 1.5 * pi;
      }
    }

    double normalizeAngle(double angle) {
      double a = angle % (2 * pi);
      if (a < 0) a += 2 * pi;
      return a;
    }

    Offset getJunctionControlPoint(
      double cx,
      double cy,
      Direction d,
      double cpDist,
    ) {
      switch (d) {
        case Direction.east:
          return Offset(cx + cpDist, cy);
        case Direction.south:
          return Offset(cx, cy + cpDist);
        case Direction.west:
          return Offset(cx - cpDist, cy);
        case Direction.north:
          return Offset(cx, cy - cpDist);
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

    // Parking spurs. A trip that begins or ends at a parking spot drives a
    // curve between the spot and the driveway tile instead of teleporting
    // between the spot and the tile centre.
    final Offset? startSpot = _parksAt(0) ? _parkingSpotFor(0) : null;
    final Offset? endSpot = _parksAt(path.length - 1)
        ? _parkingSpotFor(path.length - 1)
        : null;
    _fadeLaneAtStart = startSpot != null;
    _fadeLaneAtEnd = endSpot != null;
    _lotRouteLength = 0.0;
    final int n = path.length;

    final start = startSpot ?? getPos(0);
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

      // Pull out of the parking spot. Ends on the driveway axis at the
      // point the plain corner logic below starts from (0.7 tiles out, the
      // midpoint of door and stub), so the corner at the stub is unchanged.
      if (i == 0 && startSpot != null) {
        final e = _unit(p1.side!);
        final eO = Offset(e.x, e.y);
        final axis = Offset(
          offsetX + p1.x * cellSize + cellSize / 2 + e.x * cellSize * 0.7,
          offsetY + p1.y * cellSize + cellSize / 2 + e.y * cellSize * 0.7,
        );
        final isHome = p1.x == spawnHousePos.x && p1.y == spawnHousePos.y;
        if (isHome) {
          _appendSBend(_smoothPath, segPath, currentPenPos, axis, eO);
        } else {
          final full = shopRoute(
            p1.x,
            p1.y,
            p1.side!,
            cellSize,
            offsetX,
            offsetY,
            stallSlot,
          );
          _lotRouteLength = _polylineLength(full);
          final route = full.reversed.skip(1).toList();
          _appendRoundedPolyline(
            _smoothPath,
            segPath,
            currentPenPos,
            [...route, axis],
            cellSize * GameConstants.parkingCornerRadius,
          );
        }
        currentPenPos = axis;
      }

      // Pull in: from the last road tile, round the stub corner, then
      // either S-bend onto the home apron or follow the shop's in-lot
      // route to the bay. Arrives nose toward the building.
      if (endSpot != null &&
          i == n - 3 &&
          !isLongJumpAt(i) &&
          !isJunctionTransitionAt(i) &&
          !(p1.side != null && isJunctionNodeAt(i))) {
        final bNode = path[i + 2];
        final e = _unit(bNode.side!);
        final inDir = Offset(-e.x, -e.y);
        final bcx = offsetX + bNode.x * cellSize + cellSize / 2;
        final bcy = offsetY + bNode.y * cellSize + cellSize / 2;
        final isHome = bNode.x == spawnHousePos.x && bNode.y == spawnHousePos.y;
        final r = cellSize * GameConstants.parkingCornerRadius;
        if (isHome) {
          final axis = Offset(
            bcx + e.x * cellSize * 0.7,
            bcy + e.y * cellSize * 0.7,
          );
          final pen = _appendRoundedPolyline(
            _smoothPath,
            segPath,
            currentPenPos,
            [c2, axis],
            cellSize * 0.3,
          );
          _appendSBend(_smoothPath, segPath, pen, endSpot, inDir);
        } else {
          final route = shopRoute(
            bNode.x,
            bNode.y,
            bNode.side!,
            cellSize,
            offsetX,
            offsetY,
            stallSlot,
          );
          _lotRouteLength = _polylineLength(route);
          _appendRoundedPolyline(_smoothPath, segPath, currentPenPos, [
            c2,
            ...route,
          ], r);
        }
        currentPenPos = endSpot;
      }
      // Last hop into the spot from wherever the previous segment left the
      // pen (very short trips, or a special segment just before the stub).
      else if (endSpot != null && i == n - 2) {
        if ((endSpot - currentPenPos).distance > 0.5) {
          final e = _unit(p2.side!);
          final inDir = Offset(-e.x, -e.y);
          final isHome = p2.x == spawnHousePos.x && p2.y == spawnHousePos.y;
          if (isHome) {
            _appendSBend(_smoothPath, segPath, currentPenPos, endSpot, inDir);
          } else {
            final route = shopRoute(
              p2.x,
              p2.y,
              p2.side!,
              cellSize,
              offsetX,
              offsetY,
              stallSlot,
            );
            _lotRouteLength = _polylineLength(route);
            _appendRoundedPolyline(
              _smoothPath,
              segPath,
              currentPenPos,
              route,
              cellSize * GameConstants.parkingCornerRadius,
            );
          }
        }
        currentPenPos = endSpot;
      }
      // Long jump (express lane): bezier with a perpendicular arc.
      else if (isLongJumpAt(i)) {
        final delta = c2 - c1;
        final dist = delta.distance;
        final mid = (c1 + c2) / 2;
        final unitDir = delta / dist;
        final perp = Offset(-unitDir.dy, unitDir.dx);
        final perpSign = (perp.dy < 0 || (perp.dy == 0 && perp.dx < 0))
            ? 1.0
            : -1.0;
        // Must match the painted trace (GridRenderer._drawExpressLanesForChunk
        // uses the same constant) or drones fly off it.
        final arcHeight = dist * GameConstants.expressLaneArc * perpSign;
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
        final ringR = cellSize * GameConstants.junctionRingRadius;
        final rect = Rect.fromCircle(center: Offset(cx, cy), radius: ringR);

        final bool prevIsEntry =
            i > 0 && (path[i - 1].side == null && path[i].side != null);
        final bool nextIsExit =
            i + 1 < path.length - 1 &&
            (path[i + 1].side != null && path[i + 2].side == null);

        const alpha = pi / 6;
        final startAngle = sideAngle(p1.side!) + (prevIsEntry ? alpha : 0.0);
        final endAngle = sideAngle(p2.side!) - (nextIsExit ? alpha : 0.0);

        final sweepAngle = normalizeAngle(endAngle - startAngle);
        _smoothPath.arcTo(rect, startAngle, sweepAngle, false);
        segPath.arcTo(rect, startAngle, sweepAngle, false);
        currentPenPos = Offset(
          cx + ringR * cos(endAngle),
          cy + ringR * sin(endAngle),
        );
      }
      // Entry transition for smart junctions.
      // [FIX] House-entry: gated on isJunctionNodeAt(i + 1) so this only
      // fires for a genuine smart-junction entry sub-node. Previously it
      // matched ANY transition from a plain road node into a `side`-bearing
      // node — which also covers arriving at a plain house/destination
      // building on the final path segment, since buildings carry a `side`
      // too (their entrySide). That meant every arrival was rendered using
      // the smart-junction hub-ring math (a fixed cellSize*0.75 radius
      // around the building's own cell, offset by the junction merge
      // angle) instead of the door/tile-center point getPos() computes
      // above — so the rendered curve ended up well off to the side of,
      // and short of, the building. Excluding non-junction nodes here lets
      // those fall through to the plain line/corner logic below instead,
      // which uses getPos() (and its terminal-node tile-center fix above)
      // correctly.
      else if (p1.side == null && p2.side != null && isJunctionNodeAt(i + 1)) {
        final cx = offsetX + p2.x * cellSize + cellSize / 2;
        final cy = offsetY + p2.y * cellSize + cellSize / 2;
        final r = cellSize * GameConstants.junctionRingRadius;
        const alpha = pi / 6;

        final startPoint = c2 + (c1 - c2) * 0.5;
        final targetAngle = sideAngle(p2.side!) + alpha;
        final endPoint = Offset(
          cx + r * cos(targetAngle),
          cy + r * sin(targetAngle),
        );

        final cpDist = r / cos(alpha);
        final cp = getJunctionControlPoint(cx, cy, p2.side!, cpDist);

        _smoothPath.lineTo(startPoint.dx, startPoint.dy);
        _smoothPath.quadraticBezierTo(cp.dx, cp.dy, endPoint.dx, endPoint.dy);

        segPath.lineTo(startPoint.dx, startPoint.dy);
        segPath.quadraticBezierTo(cp.dx, cp.dy, endPoint.dx, endPoint.dy);
        currentPenPos = endPoint;
      }
      // Exit transition for smart junctions.
      // [FIX] Spawn wobble: this branch had no structural check, so it also
      // fired for i == 0 on every trip -- the house/destination DOOR node
      // carries a non-null `side` too -- and drew the car's very first
      // segment as a roundabout-exit bezier swung through a control point
      // ~0.87 cells off the driveway. The car visibly swerved while pulling
      // out of the building. Gate it on a real junction node like the entry
      // branch above already does.
      else if (p1.side != null && p2.side == null && isJunctionNodeAt(i)) {
        final cx = offsetX + p1.x * cellSize + cellSize / 2;
        final cy = offsetY + p1.y * cellSize + cellSize / 2;
        final r = cellSize * GameConstants.junctionRingRadius;
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
        final nextSpecial =
            isLongJumpAt(i + 1) || isJunctionTransitionAt(i + 1);
        if (!nextSpecial && i < path.length - 2) {
          final p3 = path[i + 2];
          final c3 = getPos(i + 2);
          bool isStraight =
              (p1.x == p2.x &&
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
            final cornerEnd = c2 + (c3 - c2) * 0.5;
            // [FIX] Turning smoothness: a quadratic bezier with its single
            // control point pinned to the raw grid-corner (c2) pulls the
            // curve in noticeably closer to that corner than a true
            // circular arc through the same tangent points would — so a
            // 90-degree grid turn read more like a rounded-off right angle
            // than a wide, gentle sweep. A cubic bezier whose control
            // points sit along the incoming/outgoing straight segments,
            // offset by the standard ~0.5523 "kappa" constant used to
            // approximate a circular quarter-arc, stays tangent-continuous
            // with the straight sections at cornerStart/cornerEnd (same as
            // before) but bows the curve out into a much closer-to-circular
            // arc — without changing how much of the segment is spent on
            // the curve.
            const kappa = 0.5522847498;
            final cp1 = cornerStart + (c2 - cornerStart) * kappa;
            final cp2 = cornerEnd + (c2 - cornerEnd) * kappa;
            _smoothPath.lineTo(cornerStart.dx, cornerStart.dy);
            segPath.lineTo(cornerStart.dx, cornerStart.dy);
            _smoothPath.cubicTo(
              cp1.dx,
              cp1.dy,
              cp2.dx,
              cp2.dy,
              cornerEnd.dx,
              cornerEnd.dy,
            );
            segPath.cubicTo(
              cp1.dx,
              cp1.dy,
              cp2.dx,
              cp2.dy,
              cornerEnd.dx,
              cornerEnd.dy,
            );
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

  /// Advances along the smooth path. [maxAdvance] is a hard cap on this
  /// call's arc-length step, in path pixels.
  ///
  /// [FIX] Restart jitter: the caller used to integrate first and then, if
  /// the drone had crossed a stop line it was not allowed to cross, rewind
  /// `_distanceTraveled` to the boundary, zero `_currentSpeedMultiplier`
  /// and call this method a second time with dt == 0 to re-place the
  /// sprite. That did two harmful things every frame the drone sat at a
  /// stop line: it re-ran the whole tangent/lane pipeline twice, and it
  /// destroyed the acceleration ramp (`_currentSpeedMultiplier` back to 0)
  /// while the accel block upstream kept rebuilding it — so the drone's
  /// speed sawtoothed instead of easing away. Passing the allowed step in
  /// means the drone never overshoots and never has to be yanked back.
  void _updatePosition(double dt, {double maxAdvance = double.infinity}) {
    if (_totalLength <= 0) return;

    // Stage 6: Curve / Turn Speeds
    //
    // [FIX] Turning smoothness: this used to feed the freshly-computed,
    // purely-geometric multiplier straight into the distance integration
    // every single frame. That raw value is only a snapshot of "how curvy
    // is the path right here, right now" with no memory of the previous
    // frame — as the fixed lookahead window slid across the (fairly short)
    // corner geometry it could swing from ~1.0 down to its floor and back
    // within a couple of frames, which read live as an abrupt slowdown/
    // speedup "flinch" right at the turn instead of a gradual ease.
    // _currentCurveSpeedMultiplier now eases toward this target at a
    // bounded rate per second so the change reads as continuous. The
    // lookahead distance is also widened slightly (roughly matching how
    // far the corner-cut geometry itself now extends — see
    // _rebuildSmoothPath) so the car starts anticipating a turn a little
    // earlier, giving the ease more room to work with before the tightest
    // part of the curve.
    if (_recomputeCurveTarget) {
      _recomputeCurveTarget = false;
      final tangent = _metric!.getTangentForOffset(_distanceTraveled);
      double target = 1.0;
      if (tangent != null) {
        final nextOffset = min(
          _totalLength,
          _distanceTraveled + cellSize * 0.9,
        );
        final nextTangent = _metric!.getTangentForOffset(nextOffset);
        if (nextTangent != null) {
          double turnAngleDiff = (nextTangent.angle - tangent.angle).abs();
          if (turnAngleDiff > pi) {
            turnAngleDiff = 2 * pi - turnAngleDiff;
          }
          target = 1.0 - (turnAngleDiff / (pi / 2) * 0.45).clamp(0.0, 0.45);
        }
      }
      _curveSpeedTarget = target;
    }
    final targetCurveSpeedMultiplier = _curveSpeedTarget;
    if (dt > 0) {
      const curveSpeedEaseRate = 4.0; // convergence rate, per second
      final diff = targetCurveSpeedMultiplier - _currentCurveSpeedMultiplier;
      final maxStep = curveSpeedEaseRate * dt;
      _currentCurveSpeedMultiplier = diff.abs() <= maxStep
          ? targetCurveSpeedMultiplier
          : _currentCurveSpeedMultiplier + maxStep * diff.sign;
    }
    final curveSpeedMultiplier = _currentCurveSpeedMultiplier;

    // Leaving a parking spot the car faces the building; swing round on the
    // spot first, then drive. Without the hold it slid sideways while turning.

    // Rule 7: Curve Speed Reduction inside roundabout (~80% speed)
    // [FIX] Was a bare `side != null` check, which is also true on a plain
    // house/destination entry node — so every car got an unintended ~20%
    // speed dip driving its final approach into (and initial pull-out from)
    // every building, not just while actually on a roundabout ring. Use the
    // same structural junction check as _updateLaneTarget.
    double roundaboutSpeedMultiplier = 1.0;
    if (_currentPathIndex < path.length && _isJunctionNode(_currentPathIndex)) {
      roundaboutSpeedMultiplier = 0.80;
    }

    double advance =
        dt *
        speed *
        game.timeScale *
        curveSpeedMultiplier *
        roundaboutSpeedMultiplier;
    // Hard stop lines (unreserved cell ahead, blocked box, shop-lot gate)
    // arrive as a cap computed by the caller *before* this integration, so
    // the drone stops exactly on the line instead of overshooting and being
    // rewound. See _advanceCap().
    if (advance > maxAdvance) advance = max(0.0, maxAdvance);
    _distanceTraveled += advance;
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
      // The scan asks for this every frame; it is free here because the
      // tangent is already in hand.
      _headingAt = _distanceTraveled;
      _setHeading(fwd.dx, fwd.dy);
      final lane = _safeLaneOffset() * _laneFade(_distanceTraveled);

      position = Vector2(
        finalTangent.position.dx - fwd.dy * lane,
        finalTangent.position.dy + fwd.dx * lane,
      );
      angle = 0; // drones stay upright
    }
  }

  // [FIX] "Cars not fully on roads": this offset used to be a flat
  // `cellSize * 0.22 * _currentLaneSign` with no relationship at all to how
  // wide the road is actually painted in grid_renderer.dart, or to how wide
  // the car itself renders (see render(): rendered width =
  // size.x / game.vehicleSpriteAspect). Regular/tunnel/bridge/ice/dirt road
  // fill is drawn cellSize*0.64 wide (_roadPaint et al. — was 0.48 before
  // the 2026-09-01 road-width widening) — i.e. cellSize*0.32 from centerline
  // to painted edge — so a lane offset of 0.22 alone still leaves the car's
  // own half-width room to fit before the painted edge (see
  // _maxSafeLaneOffsetMagnitude for the exact numbers; worse before the
  // widening for the wider truck/bus footprints). The smart-junction donut
  // ring is painted wider still (outerR/innerR give cellSize*0.38 half-width
  // either side of the FIXED r=0.75 centerline the path follows — see
  // _drawSmartJunctions; that r=0.75 is a pathing constant, unrelated to
  // road paint width, and was not changed by the widening), so it gets its
  // own, larger, margin.
  //
  // [ROAD WIDTH 2026-09-01] The 0.22 raw target below is deliberately left
  // unchanged: even after widening, it still exceeds
  // _maxSafeLaneOffsetMagnitude() on both plain roads (new max ≈0.179) and
  // junction rings (new max ≈0.237), so the clamp below — not this raw
  // value — is still what actually determines the applied lane offset in
  // both cases. (It would stop being true, and this raw value would start
  // silently capping the benefit of any further road widening, somewhere
  // above roughly cellSize*0.72 total road width — comfortably above the
  // 0.64 chosen here.)
  //
  // Clamp the offset's magnitude (never its sign, so drive-on-the-right /
  // roundabout inner-outer lane behavior is unchanged whenever it already
  // fits) to whatever margin is actually available at the car's current
  // location for its actual rendered width.
  double _safeLaneOffset() {
    final raw = cellSize * 0.185 * _currentLaneSign;
    final maxMagnitude = _maxSafeLaneOffsetMagnitude();
    if (raw.abs() <= maxMagnitude) return raw;
    return maxMagnitude * raw.sign;
  }

  double _maxSafeLaneOffsetMagnitude() {
    // Vehicles are circular saucers/drones with radius `size.x * GameConstants.droneRadius`.
    final vehicleRadius = size.x * GameConstants.droneRadius;

    // Road half-width including the outer edge stroke
    final surfaceHalfWidth =
        cellSize * (GameConstants.roadWidth / 2 + GameConstants.roadEdge);

    const marginFactor = 0.98;
    return max(0.0, surfaceHalfWidth * marginFactor - vehicleRadius);
  }

  /// Sets [_targetLaneSign] to -1 when this car is about to arrive at a
  /// destination that already has a parked car, so it pulls into the other
  /// lane instead of stacking on top. Reverts to +1 (right side) otherwise.
  void _updateLaneTarget() {
    // --- Roundabout/Smart Junction Lane Alignment ---
    // [FIX] This used to test `side != null` directly, which is also true
    // for a plain house/destination entry node (its door/driveway `side`),
    // not just genuine roundabout ring sub-nodes. That made every car treat
    // its final approach into (and departure from) a building as if it were
    // entering a roundabout: _targetLaneSign snapped to a fixed +-0.85 (via
    // isRoundaboutInner, deterministic per car) at the fast near-junction
    // ease rate (dt*12 vs dt*2.5 — see below), producing a sharp, arbitrary
    // sideways swerve right as the car neared/left the building instead of
    // the intended gentle parked-car-avoidance swap (which only ever
    // engages within the last 3 path nodes, further down this method).
    // _isJunctionNode requires the node to share its (x, y) with a path
    // neighbor, which is only ever true for actual roundabout sub-nodes.
    bool nearJunction = false;
    if (_currentPathIndex < path.length) {
      if (_isJunctionNode(_currentPathIndex)) {
        nearJunction = true;
      } else if (_currentPathIndex + 1 < path.length &&
          _isJunctionNode(_currentPathIndex + 1)) {
        nearJunction = true;
      }
    }

    if (nearJunction) {
      // Rule 8: Dual-lane illusion — each car is dynamically or deterministically assigned to the
      // inner or outer orbital lane. On a clockwise circle the right-perpendicular points inward,
      // so +0.85 → inner lane, −0.85 → outer.
      // [FIX] Was +0.85 / -0.85: every car swung across to the far side of
      // the road on approach, which read as a swerve into the roundabout.
      // Both ring lanes now stay on the driving side of the centreline.
      _targetLaneSign = isRoundaboutInner ? 0.55 : 1.0;
      return;
    }

    // Waiting cars sit in stalls off the road, so there is nothing to pull
    // alongside at the destination any more: keep to the driving side.
    _targetLaneSign = 1.0;
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
    _closestObstacle = null;
    _ignoredObstacles.clear();
    _deadlockTimer = 0.0;
    _lotWaitTimer = 0.0;

    // [FIX] Return-trip cornering looked visibly wrong compared to the
    // outbound leg. Both _init() and reuseState() reset the per-car lane-
    // offset/curve-speed easing state to neutral before a trip's smooth
    // path is (re)built, but this method never did — it rebuilt the spline
    // while leaving whatever _currentLaneSign/_currentCurveSpeedMultiplier/
    // _roundaboutInnerLane/_currentSpeedMultiplier the car happened to end
    // its outbound leg with. A car that had drifted toward the left lane
    // to avoid double-parking at a busy destination (_targetLaneSign =
    // -1.0, see _updateLaneTarget) or hadn't yet finished easing out of a
    // roundabout's inner/outer lane offset carried that stale sideways
    // offset straight into the brand-new return spline: _updatePosition
    // renders the car offset from the fresh tangent by
    // `cellSize * 0.22 * _currentLaneSign`, so it popped out to the wrong
    // side of the new path and had to swerve back over about a second
    // while still cornering out of the destination's driveway — reading
    // exactly like a wrong/weird turning angle right at the start of the
    // return leg (an outbound trip never shows this because _init()/
    // reuseState() always start it from _currentLaneSign == 1.0). Reset
    // the same easing state those two entry points do so every trip,
    // outbound or return, starts its cornering from the same neutral
    // baseline.
    _currentLaneSign = 1.0;
    _targetLaneSign = 1.0;
    _currentCurveSpeedMultiplier = 1.0;
    _curveSpeedTarget = 1.0;
    _recomputeCurveTarget = true;
    _currentSpeedMultiplier = 0.0;
    _lastTargetMultiplier = 1.0;
    _roundaboutInnerLane = null;
    _intersectionWaitingTimer = 0.0;

    _rebuildSmoothPath();
    _registerOccupancy();
  }

  void recalculatePath() {
    if (arrived || path.length < 2 || _currentPathIndex + 1 >= path.length) {
      return;
    }

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
        final homeDriveway =
            gm.buildingDriveways['${spawnHousePos.x},${spawnHousePos.y}'];
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
      _markArrived();
      return;
    }

    // Unregister old occupancy
    _unregisterOccupancy();

    // [FIX] Capture how far the car has progressed *into* its current
    // segment (the grid edge from path[_currentPathIndex] to nextNode)
    // before we rebuild the smooth path. This portion of the route is
    // provably unchanged by the edit — only nextNode onward can differ —
    // so we can carry the car's progress forward analytically instead of
    // re-locating it with a Euclidean nearest-point search below.
    final oldCurrentIndex = _currentPathIndex;
    final oldOffsetAtCurrent =
        (oldCurrentIndex >= 0 && oldCurrentIndex < segmentStartOffsets.length)
        ? segmentStartOffsets[oldCurrentIndex]
        : _distanceTraveled;
    final excessIntoCurrentSegment = max(
      0.0,
      _distanceTraveled - oldOffsetAtCurrent,
    );

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
      path = [...prefix, ...newSubPath, path.last];
    }

    // Rebuild smooth path (the geometry under the car changed, so the
    // cached curve-speed target is stale — take a fresh reading).
    _rebuildSmoothPath();
    _recomputeCurveTarget = true;

    // [FIX] Re-derive the new arc-length distance analytically from the
    // unchanged prefix, instead of re-locating the car via a Euclidean
    // nearest-point search across the whole new spline.
    //
    // The old search sampled the new curve within +/-2 cellSizes of the old
    // distance and picked whichever point minimized on-screen distance to
    // the car's OLD position. That is lossy in two ways: (1) rebuilding the
    // spline for the full (unchanged-prefix + new-suffix) path can reshape
    // the curve right around the car — corner-cutting for the current
    // segment looks ahead one extra node (see the isStraight/nextSpecial
    // checks in _rebuildSmoothPath), and that lookahead node is exactly the
    // one a topology edit is most likely to change — so the "closest point"
    // search was chasing a target that had itself shifted; and (2) near
    // roundabouts/curves the path can pass close to itself (concentric
    // lanes), so a purely spatial search could snap the car onto a nearby
    // but semantically wrong point (wrong lane/lap), which matches the
    // "worse on curves/roundabouts" symptom.
    //
    // Since path[0.._currentPathIndex] (the prefix) is byte-identical to the
    // old path, and nextNode (path[_currentPathIndex + 1]) is unchanged too,
    // the new segmentStartOffsets[oldCurrentIndex] is arc-length-equivalent
    // to the old one. Re-applying the car's already-measured excess distance
    // into its current segment on top of that offset carries its progress
    // forward exactly, without needing to search for anything.
    final newIndex = segmentStartOffsets.isEmpty
        ? 0
        : oldCurrentIndex.clamp(0, segmentStartOffsets.length - 1);
    final newOffsetAtCurrent = segmentStartOffsets.isEmpty
        ? 0.0
        : segmentStartOffsets[newIndex];
    _distanceTraveled = _totalLength > 0
        ? (newOffsetAtCurrent + excessIntoCurrentSegment).clamp(
            0.0,
            _totalLength,
          )
        : 0.0;

    // Update path index and register occupancy
    _currentPathIndex = _calculatePathIndex(_distanceTraveled);
    _registerOccupancy();
  }

  void _onArrivedAtDestination() {
    if (vehicleType == VehicleType.emergency) {
      if (routeId != null) {
        game.emergencyManager.resolveEvent(routeId!);
      }
      _markArrived();
      return;
    }

    final gm = game.gridManager;
    if (gm == null) {
      _markArrived();
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
    final destDriveway =
        gm.buildingDriveways['${targetDest.x},${targetDest.y}'];
    final homeDriveway =
        gm.buildingDriveways['${spawnHousePos.x},${spawnHousePos.y}'];
    if (destDriveway == null || homeDriveway == null) {
      _markArrived();
      return;
    }

    final returnRoadPath = Pathfinder.findPath(gm, destDriveway, homeDriveway);
    if (returnRoadPath == null || returnRoadPath.isEmpty) {
      _markArrived();
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
      _markArrived();
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

  /// [FIX] Counterpart to [toJson] — previously missing entirely, so cars
  /// serialized into a save file could never be restored and every vehicle
  /// in transit silently vanished on resume. Restores position/route/color
  /// (and best-effort progress along that route) using the same
  /// [initialPathIndex]/[initialProgress]/[initialReturning] hooks the
  /// constructor already exposed for exactly this purpose.
  factory CarComponent.fromJson(
    Map<String, dynamic> json, {
    required double cellSize,
    required double offsetX,
    required double offsetY,
  }) {
    final pathJson = json['path'] as List<dynamic>? ?? const [];
    final path = pathJson.map((p) {
      final m = p as Map<String, dynamic>;
      return GridPosition(m['x'] as int, m['y'] as int);
    }).toList();

    final spawnJson = json['spawnHousePos'] as Map<String, dynamic>;
    final targetJson = json['targetDest'] as Map<String, dynamic>;

    final vehicleTypeIndex = json['vehicleType'] as int? ?? 0;
    final vehicleType = VehicleType
        .values[vehicleTypeIndex.clamp(0, VehicleType.values.length - 1)];

    return CarComponent(
      colorIndex: json['colorIndex'] as int? ?? 0,
      path: path,
      cellSize: cellSize,
      offsetX: offsetX,
      offsetY: offsetY,
      spawnHousePos: GridPosition(spawnJson['x'] as int, spawnJson['y'] as int),
      targetDest: GridPosition(targetJson['x'] as int, targetJson['y'] as int),
      vehicleType: vehicleType,
      initialPathIndex: json['currentPathIndex'] as int?,
      initialProgress: (json['progress'] as num?)?.toDouble(),
      initialReturning: json['isReturning'] as bool?,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.paused || game.timeScale == 0.0) return;

    final isStopped =
        _currentSpeedMultiplier < 0.05 ||
        _waitingAtSignal ||
        isWaiting ||
        arrived;

    // Dynamically limit max trail length as speed decreases
    final speedFactor = arrived
        ? 0.0
        : (_currentSpeedMultiplier / 1.0).clamp(0.0, 1.0);
    final int activeMaxPoints = (isStopped || arrived)
        ? 0
        : (_maxTrailPoints * speedFactor).round();

    if (GameConstants.carTrails && !arrived && !isWaiting && !isStopped) {
      if (_trailPositions.isEmpty ||
          _trailPositions.first.distanceToSquared(position) > 0.05) {
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
      _markArrived();
      return;
    }

    travelTime += dt * game.timeScale;

    // Bus stop logic
    if (vehicleType == VehicleType.bus && !isWaiting && !arrived) {
      final currentCellPos = _getCurrentGridPos();
      final cell = game.gridManager!.getCell(
        currentCellPos.x,
        currentCellPos.y,
      );
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
            _markArrived();
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
        _parkAtCurrentEnd();
        return;
      }
      _markArrived();
      return;
    }

    // --- Throttled Signal & Congestion Checks (15Hz) ---
    _simCheckTimer += dt;
    if (_simCheckTimer >= 1 / 15) {
      _simCheckTimer = 0;
      // [PERF] Curve-speed target rides the same bucket; the ease toward it
      // still runs per frame, so nothing reads as stepped.
      _recomputeCurveTarget = true;

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

          if (moveDir != null &&
              !game.gridManager!.isGreenForDirection(
                nextPos.x,
                nextPos.y,
                moveDir,
              )) {
            final signalWorldX = offsetX + nextPos.x * cellSize + cellSize / 2;
            final signalWorldY = offsetY + nextPos.y * cellSize + cellSize / 2;
            if (position.distanceToSquared(
                  Vector2(signalWorldX, signalWorldY),
                ) <
                cellSize * cellSize) {
              _signalWaitTimer += dt;
              if (_signalWaitTimer > 6.0) {
                // Escape hatch: signal deadlock / prolonged red phase timeout
                _waitingAtSignal = false;
                _signalWaitTimer = 0.0;
                _debugLog(
                  "[SIGNAL_ESCAPE] Car $this overrode signal hold at (${nextPos.x}, ${nextPos.y})",
                );
              } else {
                _waitingAtSignal = true;
              }
            } else {
              _signalWaitTimer = 0.0;
            }
          } else {
            _signalWaitTimer = 0.0;
          }
        } else {
          _signalWaitTimer = 0.0;
        }
      } else {
        _signalWaitTimer = 0.0;
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

        if (game.selectedMapType == MapType.savanna &&
            curCell.type == CellType.road &&
            curCell.owner == InfrastructureOwner.player) {
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

        final isBlocked =
            game.floodedRoads.contains(curPos) ||
            game.activeEventTiles.contains(curPos);
        if (isBlocked) {
          speedMult = 0.0;
        }

        _terrainSpeed = speedMult;
        onExpressLane =
            curCell.isExpressLaneNode ||
            _terrainSpeed >= GameConstants.expressLaneSpeed;
      }
    }

    // --- Follow-the-leader, Road Occupancy, and Reservations ---
    _closestObstacle = null;
    double targetMultiplier = 1.0;
    bool hasReservation = true;
    bool exitBlocked = false;
    double minObstacleGap = double.infinity;

    if (!onExpressLane && !_waitingAtSignal) {
      final myIdx = _currentPathIndex.clamp(0, path.length - 1);
      final myNode = path[myIdx];

      // 1. Check occupancy & reservations for the next cell
      if (myIdx + 1 < path.length) {
        final nextNode = path[myIdx + 1];

        // Guard: skip if nextNode is the same grid cell as myNode (degenerate path).
        // This prevents self-reservation deadlocks. The path dedup in _rebuildSmoothPath
        // should handle this, but belt-and-suspenders here for safety.
        if (nextNode.x == myNode.x &&
            nextNode.y == myNode.y &&
            nextNode.side == myNode.side) {
          // Skip to outer block — no reservation needed, the car will advance naturally.
        } else {
          final cell = game.gridManager?.getCell(nextNode.x, nextNode.y);

          if (cell != null && cell.isPassable) {
            final occupancy = game.getOrCreateOccupancy(nextNode);

            // [FIX] Was a bare `side != null` check — the same
            // house/destination-entry misclassification f62e666 fixed in
            // _updateLaneTarget and the Rule 7 speed check (a plain
            // building's entry node also carries a non-null `side`, but is
            // not part of any roundabout). In practice this branch is only
            // ever reached for a `nextNode`/`myNode` whose cell
            // `isPassable` (see the guard above) — buildings never are —
            // so this specific misclassification could not actually fire.
            // Using the shared structural check anyway keeps this the only
            // remaining "is this really a roundabout node" test in the file
            // still relying on the bare, reintroducible-by-copy-paste
            // pattern, now that a passable exception (e.g. a walk-through
            // building) would otherwise silently resurrect the bug here.
            final isRoundaboutNode =
                _isJunctionNode(myIdx) || _isJunctionNode(myIdx + 1);

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

                  int innerCars = occupancy.cars
                      .where((c) => c.isRoundaboutInner)
                      .length;
                  int outerCars = occupancy.cars
                      .where((c) => !c.isRoundaboutInner)
                      .length;

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
                  _debugLog(
                    "[ROUNDABOUT_LANE_CHOOSE] Car $this selected lane: ${_roundaboutInnerLane! ? 'INNER' : 'OUTER'}",
                  );
                }

                final alreadyReserved = occupancy.isReservedBy(this, true);
                if (alreadyReserved) {
                  hasReservation = true;
                } else {
                  bool roundaboutEntryAllowed = true;

                  // 1. Check Entry Occupancy
                  bool entryOccupied = occupancy.isReservedBySameLane(
                    this,
                    true,
                  );
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
                    _closestObstacle = isRoundaboutInner
                        ? occupancy.reservedByInner
                        : occupancy.reservedByOuter;
                    _closestObstacle ??= occupancy.cars
                        .where((c) => c.isRoundaboutInner == isRoundaboutInner)
                        .firstOrNull;
                    _debugLog(
                      "[ROUNDABOUT_BLOCKED] Car $this blocked at entry (${nextNode.x}, ${nextNode.y}) because same-lane entry segment is occupied/reserved.",
                    );
                  }

                  // 2. Check 1st Upstream Segment (Yield) — yield to continuing same-lane cars inside roundabout
                  if (roundaboutEntryAllowed) {
                    final yieldDir = _getRoundaboutYieldDirection(
                      nextNode.side!,
                    );
                    final sidePos = GridPosition(
                      nextNode.x,
                      nextNode.y,
                      yieldDir,
                    );
                    final sideOcc = game.getOrCreateOccupancy(sidePos);
                    bool hasSameLaneCar = false;
                    for (final c in sideOcc.cars) {
                      final cNextNode = c._currentPathIndex + 1 < c.path.length
                          ? c.path[c._currentPathIndex + 1]
                          : null;
                      final cIsContinuing =
                          cNextNode != null && cNextNode.side != null;
                      if (cIsContinuing &&
                          c.isRoundaboutInner == isRoundaboutInner) {
                        hasSameLaneCar = true;
                        break;
                      }
                    }
                    if (hasSameLaneCar) {
                      roundaboutEntryAllowed = false;
                      _closestObstacle = sideOcc.cars
                          .where(
                            (c) => c.isRoundaboutInner == isRoundaboutInner,
                          )
                          .firstOrNull;
                      _debugLog(
                        "[ROUNDABOUT_YIELD] Car $this yielding to same-lane car inside roundabout at segment (${sidePos.x}, ${sidePos.y}, ${sidePos.side!.name})",
                      );
                    }
                  }

                  // 3. Entry Spacing Cooldown (Rule 6)
                  if (roundaboutEntryAllowed) {
                    final gameTime = game.elapsedTime;
                    final isInner = isRoundaboutInner;
                    final lastEntry = isInner
                        ? occupancy.lastEntryTimeInner
                        : occupancy.lastEntryTimeOuter;
                    if (gameTime - lastEntry < 0.3) {
                      roundaboutEntryAllowed = false;
                      _closestObstacle ??= occupancy.cars.firstOrNull ?? occupancy.reservedBy;
                      _debugLog(
                        "[ROUNDABOUT_BLOCKED] Car $this entry spacing cooldown active on (${nextNode.x}, ${nextNode.y})",
                      );
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
                    occupancy.clearReservation(
                      this,
                    ); // Cleanly release reservation if blocked
                    _roundaboutInnerLane =
                        null; // Reset lane choice so we can try the other lane next frame
                    if (progressToNext < stopTriggerDist) {
                      final mult = (progressToNext / stopTriggerDist).clamp(
                        0.0,
                        1.0,
                      );
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
                final sameDirectionCars = occupancy.cars
                    .where((c) => !_isOncomingCar(c));
                final hasStalledCarAhead = sameDirectionCars.any(
                  (c) =>
                      c.arrived ||
                      c._currentSpeedMultiplier < 0.2 ||
                      c.isWaiting,
                );
                final isOverCapacity =
                    sameDirectionCars.length >= occupancy.maxCars;
                if ((hasStalledCarAhead || isOverCapacity) &&
                    !occupancy.isReservedBy(this, false)) {
                  exitAllowed = false;
                }

                if (!exitAllowed) {
                  // If exit is blocked, we slow down inside the roundabout using standard safe distance,
                  // rather than inserting clockwise nodes which bloats paths and causes mutual locks.
                  hasReservation = false;
                  _closestObstacle = occupancy.reservedBy;
                  _closestObstacle ??= occupancy.cars
                      .where((c) => !_isOncomingCar(c))
                      .firstOrNull;
                  if (progressToNext < stopTriggerDist) {
                    final mult = (progressToNext / stopTriggerDist).clamp(
                      0.0,
                      1.0,
                    );
                    if (mult < targetMultiplier) {
                      targetMultiplier = mult;
                    }
                  }
                  _debugLog(
                    "[ROUNDABOUT_EXIT_WAIT] Car $this exit to (${nextNode.x}, ${nextNode.y}) is blocked; waiting inside.",
                  );
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
                if ((_intersectionWaitingTimer * 2).floor() >
                    (oldTime * 2).floor()) {
                  _debugLog(
                    "[ROUNDABOUT_WAIT] Car $this waiting at (${nextNode.x}, ${nextNode.y}) - ${_intersectionWaitingTimer.toStringAsFixed(1)}s",
                  );
                }

                if (_intersectionWaitingTimer > _deadlockBreakTimeout) {
                  final hasMovingCarInside = occupancy.cars.any(
                    (c) =>
                        !c.arrived &&
                        c != this &&
                        c._currentSpeedMultiplier > 0.05,
                  );
                  if (!hasMovingCarInside) {
                    final isRoundaboutEntryOrCirc = (nextNode.side != null);
                    occupancy.setReservation(this, isRoundaboutEntryOrCirc);
                    hasReservation = true;
                    _boxDeadlockOverride = true;
                    if (_closestObstacle != null) {
                      _ignoredObstacles.add(_closestObstacle!);
                    }
                    _intersectionWaitingTimer = 0.0;
                    _debugLog(
                      "[ROUNDABOUT_DEADLOCK_BREAK] Car $this broke deadlock at (${nextNode.x}, ${nextNode.y})",
                    );
                  }
                }
              } else {
                _intersectionWaitingTimer = 0.0;
              }
            } else {
              // ==========================================================
              // STANDARD INTERSECTION / ROAD CONTROLLER
              // ==========================================================
              final isJunction =
                  cell.type == CellType.smartJunction ||
                  cell.type == CellType.trafficLight;
              final isIntersection =
                  cell.connectionType == ConnectionNodeType.intersection ||
                  isJunction;
              final isTunnel = cell.isTunnel;

              // "Don't Block the Box" (Stage Exit Clear Logic)
              if (myIdx + 2 < path.length) {
                if (isIntersection || isTunnel) {
                  final nodeAfterNext = path[myIdx + 2];
                  final cellAfter = game.gridManager?.getCell(
                    nodeAfterNext.x,
                    nodeAfterNext.y,
                  );
                  if (cellAfter != null && cellAfter.isPassable) {
                    final occupancyAfter = game.getOrCreateOccupancy(
                      nodeAfterNext,
                    );
                    final sameDirectionCars = occupancyAfter.cars
                        .where((c) => !_isOncomingCar(c));
                    final hasStalledCarAhead = sameDirectionCars.any(
                      (c) =>
                          c.arrived ||
                          c._currentSpeedMultiplier < 0.2 ||
                          c.isWaiting,
                    );
                    final isOverCapacity =
                        sameDirectionCars.length >= occupancyAfter.maxCars;
                    if ((hasStalledCarAhead || isOverCapacity) &&
                        !occupancyAfter.isReservedBy(this, false) &&
                        !_boxDeadlockOverride) {
                      exitBlocked = true;
                      _closestObstacle = occupancyAfter.reservedBy;
                      _closestObstacle ??= sameDirectionCars.firstOrNull;
                    }
                  }
                }
              }

              final needsReservation = isIntersection || isTunnel;

              if (needsReservation) {
                hasReservation = occupancy.isReservedBy(this, false);
              } else {
                hasReservation =
                    true; // Regular roads do not need cell reservations!
              }

              final isStandardIntersection =
                  cell.connectionType == ConnectionNodeType.intersection ||
                  cell.type == CellType.trafficLight;

              final cellEndProgress = (myIdx + 1 < segmentStartOffsets.length)
                  ? segmentStartOffsets[myIdx + 1]
                  : _totalLength;
              final progressToNext = cellEndProgress - _distanceTraveled;
              final stopTriggerDist = cellSize * 0.85;

              // Clean dead cars and idle state up front
              occupancy.waitingCars.removeWhere((c) => c.arrived);
              occupancy.cars.removeWhere((c) => c.arrived);
              occupancy.activeIntersectionCars.removeWhere((c) => c.arrived);
              occupancy.resetIfIdle();

              if (isStandardIntersection && progressToNext < stopTriggerDist) {
                if (!occupancy.waitingCars.contains(this)) {
                  occupancy.waitingCars.add(this);
                }
              }

              if (needsReservation && !hasReservation && !exitBlocked) {
                _closestObstacle = occupancy.reservedBy;
                _closestObstacle ??= occupancy.cars.firstOrNull;

                // Check axis allowance if standard intersection
                bool axisAllowed = true;
                if (isStandardIntersection && occupancy.reservedAxis != null) {
                  final hasActiveTraffic = occupancy.activeIntersectionCars
                          .any((c) => !c.arrived) ||
                      (occupancy.reservedBy != null &&
                          !occupancy.reservedBy!.arrived);
                  if (!hasActiveTraffic) {
                    occupancy.resetIfIdle();
                    axisAllowed = true;
                  } else {
                    final myAxis = _getMoveAxis(myNode, nextNode);
                    if (occupancy.reservedAxis == myAxis) {
                      bool hasCrossAxisWaiting = false;
                      for (final c in occupancy.waitingCars) {
                        if (c == this || c.arrived) continue;
                        if (c._currentPathIndex + 1 < c.path.length &&
                            c.path[c._currentPathIndex + 1] == nextNode) {
                          final cCellEnd =
                              (c._currentPathIndex + 1 <
                                      c.segmentStartOffsets.length)
                                  ? c.segmentStartOffsets[c._currentPathIndex +
                                      1]
                                  : c._totalLength;
                          final cDistToLine = cCellEnd - c._distanceTraveled;
                          if (cDistToLine < cellSize * 0.45) {
                            final cAxis = _getMoveAxis(
                              c.path[c._currentPathIndex],
                              c.path[c._currentPathIndex + 1],
                            );
                            if (cAxis != myAxis) {
                              hasCrossAxisWaiting = true;
                              break;
                            }
                          }
                        }
                      }
                      if (hasCrossAxisWaiting &&
                          occupancy.consecutiveAxisCars >= 2) {
                        axisAllowed = false;
                      }
                    } else {
                      axisAllowed = false;
                    }
                  }
                }

                // Check priority rules if standard intersection
                bool hasPriority = true;
                if (isStandardIntersection) {
                  bool hasOutboundCompetitor = false;
                  bool hasReturningCompetitor = false;
                  for (final c in occupancy.waitingCars) {
                    if (c == this || c.arrived) continue;
                    if (c._currentPathIndex + 1 < c.path.length &&
                        c.path[c._currentPathIndex + 1] == nextNode) {
                      final cCellEnd =
                          (c._currentPathIndex + 1 <
                                  c.segmentStartOffsets.length)
                              ? c.segmentStartOffsets[c._currentPathIndex + 1]
                              : c._totalLength;
                      final cDistToLine = cCellEnd - c._distanceTraveled;
                      if (cDistToLine < cellSize * 0.45) {
                        if (c.isReturning) {
                          hasReturningCompetitor = true;
                        } else {
                          hasOutboundCompetitor = true;
                        }
                      }
                    }
                  }
                  if (hasOutboundCompetitor || hasReturningCompetitor) {
                    if (!isReturning) {
                      if (occupancy.consecutiveOutbound >= 2 &&
                          hasReturningCompetitor) {
                        hasPriority = false;
                      }
                    } else {
                      if (hasOutboundCompetitor &&
                          occupancy.consecutiveOutbound < 2) {
                        hasPriority = false;
                      }
                    }
                  }
                }

                bool intersectionBusy = false;
                if (isStandardIntersection && occupancy.cars.isNotEmpty) {
                  final anyStalled = occupancy.cars.any(
                    (c) =>
                        c.arrived ||
                        c._currentSpeedMultiplier < 0.1 ||
                        c.isWaiting,
                  );
                  if (anyStalled) {
                    intersectionBusy = true;
                  } else {
                    final insideCar = occupancy.cars.first;
                    final myMoveDir = _getStepDirection(myNode, nextNode);
                    final myNextDir = (myIdx + 2 < path.length)
                        ? _getStepDirection(nextNode, path[myIdx + 2])
                        : myMoveDir;
                    final isMyMoveStraight = myMoveDir == myNextDir;

                    final insideIdx = insideCar._currentPathIndex.clamp(
                      0,
                      insideCar.path.length - 1,
                    );
                    final insideMoveDir =
                        (insideIdx + 1 < insideCar.path.length)
                            ? _getStepDirection(
                                insideCar.path[insideIdx],
                                insideCar.path[insideIdx + 1],
                              )
                            : null;
                    final insideNextDir =
                        (insideIdx + 2 < insideCar.path.length)
                            ? _getStepDirection(
                                insideCar.path[insideIdx + 1],
                                insideCar.path[insideIdx + 2],
                              )
                            : insideMoveDir;
                    final isInsideStraight = insideMoveDir == insideNextDir;

                    final isSameDirection = myMoveDir == insideMoveDir;
                    final isSamePathPlatoon =
                        isSameDirection && (myNextDir == insideNextDir);
                    final isOpposingStraight =
                        insideCar._isOncomingCar(this) &&
                        isInsideStraight &&
                        isMyMoveStraight;

                    if (!isSamePathPlatoon && !isOpposingStraight) {
                      intersectionBusy = true;
                    }
                  }
                }

                final myAxis = _getMoveAxis(myNode, nextNode);
                final sameAxisPlatoon = isStandardIntersection &&
                    occupancy.reservedAxis == myAxis &&
                    !intersectionBusy;

                bool canReserve =
                    sameAxisPlatoon ||
                    (!intersectionBusy &&
                        !occupancy.isReservedBySameLane(this, false));

                if (axisAllowed &&
                    hasPriority &&
                    canReserve &&
                    occupancy.cars.length < occupancy.maxCars) {
                  if (occupancy.reservedBy == null ||
                      occupancy.reservedBy == this) {
                    occupancy.setReservation(this, false);
                  }
                  hasReservation = true;
                  _closestObstacle = null;
                  _debugLog(
                    "[ROAD_OCCUPY] Car $this reserved (${nextNode.x}, ${nextNode.y})",
                  );

                  if (isStandardIntersection) {
                    occupancy.setReservedAxis(myAxis);
                    _debugLog(
                      "[INTERSECTION_RESERVED] Intersection (${nextNode.x}, ${nextNode.y}) reserved for axis ${occupancy.reservedAxis}",
                    );
                  }
                }
              }

              if (!hasReservation || exitBlocked) {
                if (progressToNext < stopTriggerDist) {
                  final mult = (progressToNext / stopTriggerDist).clamp(
                    0.0,
                    1.0,
                  );
                  if (mult < targetMultiplier) {
                    targetMultiplier = mult;
                  }

                  final isJunctionOrIntersection =
                      cell.connectionType == ConnectionNodeType.intersection ||
                      cell.type == CellType.trafficLight ||
                      cell.type == CellType.smartJunction;
                  if (isJunctionOrIntersection &&
                      (!hasReservation || exitBlocked)) {
                    final oldTime = _intersectionWaitingTimer;
                    _intersectionWaitingTimer += dt;

                    // Print only when crossing 0.5s intervals to avoid flooding the console
                    if ((_intersectionWaitingTimer * 2).floor() >
                        (oldTime * 2).floor()) {
                      _debugLog(
                        "[INTERSECTION_WAIT] Car $this waiting at (${nextNode.x}, ${nextNode.y}) - ${_intersectionWaitingTimer.toStringAsFixed(1)}s",
                      );
                    }

                    if (_intersectionWaitingTimer > _deadlockBreakTimeout) {
                      if (occupancy.cars.isEmpty) {
                        if (!hasReservation) {
                          occupancy.setReservation(this, nextNode.side != null);
                          if (cell.connectionType ==
                                  ConnectionNodeType.intersection ||
                              cell.type == CellType.trafficLight) {
                            final axis = _getMoveAxis(
                              myNode,
                              nextNode,
                            );
                            occupancy.setReservedAxis(axis);
                          }
                        }
                        hasReservation = true;
                        _boxDeadlockOverride = true;
                        if (_closestObstacle != null) {
                          _ignoredObstacles.add(_closestObstacle!);
                        }
                        _intersectionWaitingTimer = 0.0;
                        _debugLog(
                          "[DEADLOCK_BREAK] Car $this broke deadlock at (${nextNode.x}, ${nextNode.y})",
                        );
                      }
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
      // [PERF] Reused scratch collections — see the field declarations.
      final List<CarComponent> potentialObstacles = _obstacleScratch..clear();

      final List<GridPosition> searchNodes = _searchNodesScratch..clear();
      searchNodes.add(myNode);
      final lookaheadLimit = min(path.length, myIdx + 4);
      for (int i = myIdx + 1; i < lookaheadLimit; i++) {
        searchNodes.add(path[i]);
      }

      final Set<GridPosition> queried = _queriedScratch..clear();
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
      // [PERF] Hoisted out of the obstacle loop and kept as scalars: this
      // used to build two Vector2s (and two cos/sin pairs) per candidate
      // obstacle per frame. Identical arithmetic.
      // [FIX] Queueing: from the path tangent, not from `angle` — drones
      // never rotate, so cos/sin of `angle` made every drone "face east".
      _refreshHeading();
      final myFwdX = _headingX;
      final myFwdY = _headingY;

      minObstacleGap = double.infinity;

      for (final other in potentialObstacles) {
        if (identical(other, this) || other.onExpressLane || other.arrived) {
          continue;
        }
        // Parked drones sit in a bay or on a pad, off the trace. A drone
        // that is merely held (lot gate) or dwelling at a bus stop is still
        // standing on the trace and must still block.
        if (other._isParkedOffTrace) continue;
        if (_isOncomingCar(other)) {
          // Head-on traffic stays in its own lane on straight roads. In tight
          // curves, U-dips, or narrow corners, check if the oncoming car is
          // physically close to prevent visual overlap/clipping.
          final toOtherX = other.position.x - myPos.x;
          final toOtherY = other.position.y - myPos.y;
          final distSq = toOtherX * toOtherX + toOtherY * toOtherY;
          final myRadius = size.x * GameConstants.droneRadius;
          final otherRadius = other.size.x * GameConstants.droneRadius;
          final minPassClearance = myRadius + otherRadius + 1.5;

          if (distSq < minPassClearance * minPassClearance) {
            final dist = sqrt(distSq);
            final ahead = toOtherX * myFwdX + toOtherY * myFwdY;
            if (ahead > 0) {
              // Yield deterministically so exactly one car pauses while the other clears the curve
              final shouldYield = hashCode < other.hashCode;
              if (shouldYield) {
                final gap = max(0.0, dist - minPassClearance);
                if (gap < minObstacleGap) {
                  minObstacleGap = gap;
                }
                targetMultiplier = min(targetMultiplier, 0.0);
                _closestObstacle = other;
              }
            }
          }
          continue;
        }

        final otherIdx = other._currentPathIndex.clamp(
          0,
          other.path.length - 1,
        );
        final otherNode = other.path[otherIdx];
        final bothInRoundabout = myNode.side != null && otherNode.side != null;

        final myNextNode = myIdx + 1 < path.length ? path[myIdx + 1] : null;
        final myInOrNearRoundabout =
            myNode.side != null ||
            (myNextNode != null && myNextNode.side != null);
        final otherNextNode = other._currentPathIndex + 1 < other.path.length
            ? other.path[other._currentPathIndex + 1]
            : null;
        final otherInOrNearRoundabout =
            otherNode.side != null ||
            (otherNextNode != null && otherNextNode.side != null);

        final myIsExiting =
            myNode.side != null &&
            (myNextNode == null || myNextNode.side == null);
        final otherIsExiting =
            otherNode.side != null &&
            (otherNextNode == null || otherNextNode.side == null);

        if (myInOrNearRoundabout &&
            otherInOrNearRoundabout &&
            !myIsExiting &&
            !otherIsExiting) {
          if (myNode.side != null || otherNode.side != null) {
            if (isRoundaboutInner != other.isRoundaboutInner) {
              continue;
            }
          }
        }

        // Where the other drone sits relative to the way *I* am travelling.
        final toOtherX = other.position.x - myPos.x;
        final toOtherY = other.position.y - myPos.y;
        final ahead = toOtherX * myFwdX + toOtherY * myFwdY;

        // Head-on traffic is separated by the lane offset, never by braking.
        other._refreshHeading();
        final dot = myFwdX * other._headingX + myFwdY * other._headingY;
        if (dot < -0.5) {
          continue;
        }

        final bool sameCell = bothInRoundabout
            ? (otherNode.x == myNode.x &&
                  otherNode.y == myNode.y &&
                  otherNode.side == myNode.side)
            : (otherNode.x == myNode.x && otherNode.y == myNode.y);

        bool isAhead;
        if (sameCell) {
          final myNext = (_currentPathIndex + 1 < path.length)
              ? path[_currentPathIndex + 1]
              : null;
          final otherNext = (otherIdx + 1 < other.path.length)
              ? other.path[otherIdx + 1]
              : null;

          if (myNext != null &&
              otherNext != null &&
              myNext.x == otherNext.x &&
              myNext.y == otherNext.y &&
              myNext.side == otherNext.side) {
            // Both cars are exiting to the exact same cell (same path / following).
            // The one further along the path towards the next cell is ahead.
            final myDistToNext =
                _currentPathIndex + 1 < segmentStartOffsets.length
                ? segmentStartOffsets[_currentPathIndex + 1] - _distanceTraveled
                : _totalLength - _distanceTraveled;
            final otherDistToNext =
                otherIdx + 1 < other.segmentStartOffsets.length
                ? other.segmentStartOffsets[otherIdx + 1] -
                    other._distanceTraveled
                : other._totalLength - other._distanceTraveled;
            isAhead = otherDistToNext < myDistToNext;
          } else if (dot.abs() <= 0.5) {
            // Perpendicular crossing in the same cell
            if (ahead > cellSize * 0.1) {
              isAhead = true;
            } else if (ahead < -cellSize * 0.1) {
              isAhead = false;
            } else {
              isAhead = other.hashCode > hashCode;
            }
          } else {
            final eps = cellSize * 0.02;
            isAhead = ahead > eps || (ahead > -eps && other.hashCode > hashCode);
          }
        } else {
          isAhead = _isCellAhead(otherNode) && ahead > -cellSize * 0.35;
        }

        if (!isAhead) continue;

        final distSq = myPos.distanceToSquared(other.position);
        final dist = sqrt(distSq);

        final isIgnored = _ignoredObstacles.contains(other);
        final baseSafeDist = bothInRoundabout
            ? (isRoundaboutInner ? cellSize * 0.42 : cellSize * 0.55)
            : cellSize * 0.7;
        final safeDist = isIgnored ? cellSize * 0.40 : baseSafeDist;
        final slowdownStartDist =
            safeDist +
            (bothInRoundabout
                ? (isRoundaboutInner ? cellSize * 0.15 : cellSize * 0.20)
                : (isIgnored ? cellSize * 0.15 : cellSize * 0.3));

        final minBumperDist = bothInRoundabout
            ? cellSize * 0.38
            : (isIgnored ? cellSize * 0.38 : cellSize * 0.45);
        final gap = max(0.0, dist - minBumperDist);
        if (gap < minObstacleGap) {
          minObstacleGap = gap;
        }

        if (dist <= minBumperDist) {
          targetMultiplier = 0.0;
          _closestObstacle = other;
        } else if (dist < slowdownStartDist) {
          double mult;
          if (dist <= safeDist) {
            mult = isIgnored ? 0.15 : 0.0;
          } else {
            mult = ((dist - safeDist) / (slowdownStartDist - safeDist))
                .clamp(0.0, 1.0);
          }
          // If the leader is actively moving, smoothly pace behind them rather than
          // slamming to a dead stop in place, preventing open-road stop-and-go stutter.
          final smoothedMult =
              (other._currentSpeedMultiplier > 0.15 && dist > safeDist * 0.65)
              ? max(mult, other._currentSpeedMultiplier * 0.6)
              : mult;
          if (smoothedMult < targetMultiplier) {
            targetMultiplier = smoothedMult;
            _closestObstacle = other;
          }
        }
      }

      // --- Universal 2D Physical Collision Guard ---
      // Regardless of grid occupancy maps, path lookaheads, or junction states,
      // no two drones may ever penetrate each other in 2D world space.
      final myRadius = size.x * GameConstants.droneRadius;
      final guardRadiusSq = (cellSize * 0.95) * (cellSize * 0.95);

      for (final other in game.cars) {
        if (identical(other, this) ||
            other.arrived ||
            other._isParkedOffTrace ||
            _ignoredObstacles.contains(other)) {
          continue;
        }
        final dx = other.position.x - myPos.x;
        final dy = other.position.y - myPos.y;
        final distSq = dx * dx + dy * dy;
        if (distSq > guardRadiusSq) continue;

        final otherRadius = other.size.x * GameConstants.droneRadius;
        final dot = myFwdX * other._headingX + myFwdY * other._headingY;
        final isOncoming = dot < -0.3 || _isOncomingCar(other);

        if (isOncoming) {
          // Oncoming cars stay in their respective right-hand lanes.
          // Only guard against collision if they are encroaching on each other in curves.
          final passClearance = myRadius + otherRadius + 1.5;
          if (distSq < passClearance * passClearance) {
            final ahead = dx * myFwdX + dy * myFwdY;
            if (ahead > 0) {
              final shouldYield = hashCode < other.hashCode;
              if (shouldYield) {
                final dist = sqrt(distSq);
                final gap = max(0.0, dist - passClearance);
                if (gap < minObstacleGap) minObstacleGap = gap;
                targetMultiplier = 0.0;
                _closestObstacle = other;
              }
            }
          }
          continue;
        }

        // Check if both cars are in roundabout and on different lanes
        final otherIdx =
            other._currentPathIndex.clamp(0, other.path.length - 1);
        final otherNode = other.path[otherIdx];
        final myNextNode = myIdx + 1 < path.length ? path[myIdx + 1] : null;
        final otherNextNode = otherIdx + 1 < other.path.length
            ? other.path[otherIdx + 1]
            : null;
        final myInOrNearRoundabout =
            myNode.side != null ||
            (myNextNode != null && myNextNode.side != null);
        final otherInOrNearRoundabout =
            otherNode.side != null ||
            (otherNextNode != null && otherNextNode.side != null);
        final myIsExiting =
            myNode.side != null &&
            (myNextNode == null || myNextNode.side == null);
        final otherIsExiting =
            otherNode.side != null &&
            (otherNextNode == null || otherNextNode.side == null);

        if (myInOrNearRoundabout &&
            otherInOrNearRoundabout &&
            !myIsExiting &&
            !otherIsExiting) {
          if (myNode.side != null || otherNode.side != null) {
            if (isRoundaboutInner != other.isRoundaboutInner) {
              continue;
            }
          }
        }

        // For same-direction or converging/merging traffic:
        final ahead = dx * myFwdX + dy * myFwdY;
        if (ahead > 0.5) {
          // Check lateral cross-track distance. If the other vehicle is in an adjacent lane,
          // parking bay, or driveway off to the side, it does not block my forward path.
          final lateral = (dx * (-myFwdY) + dy * myFwdX).abs();
          final maxInLaneLateral = (myRadius + otherRadius) * 0.65; // ~7.8 px
          if (lateral > maxInLaneLateral) {
            continue;
          }

          final otherFwdX = other._headingX;
          final otherFwdY = other._headingY;
          final otherSeesMeAhead = (-dx * otherFwdX - dy * otherFwdY) > 0.5;
          if (otherSeesMeAhead && hashCode > other.hashCode) {
            // Tie-break: exactly one car proceeds while the other yields
            continue;
          }

          final requiredDist = myRadius + otherRadius + 1.5;
          final dist = sqrt(distSq);
          final physicalGap = max(0.0, dist - requiredDist);
          if (physicalGap < minObstacleGap) {
            minObstacleGap = physicalGap;
          }
          if (dist <= requiredDist) {
            targetMultiplier = 0.0;
            _closestObstacle = other;
          } else if (dist < requiredDist + cellSize * 0.20) {
            final slowFactor =
                ((dist - requiredDist) / (cellSize * 0.20)).clamp(0.0, 1.0);
            if (slowFactor < targetMultiplier) {
              targetMultiplier = slowFactor;
              _closestObstacle = other;
            }
          }
        }
      }

      _lastTargetMultiplier = targetMultiplier;
    }

    if (onExpressLane) {
      _lastTargetMultiplier = 1.0;
      targetMultiplier = 1.0;
    } else if (_waitingAtSignal) {
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
    final nearRoundabout =
        _currentPathIndex < path.length &&
        (path[_currentPathIndex].side != null ||
            (_currentPathIndex + 1 < path.length &&
                path[_currentPathIndex + 1].side != null));
    final laneRate = nearRoundabout
        ? (dt * 12.0)
        : (dt * 6.0); // Fast swap near/inside roundabout, responsive return on road
    final laneDiff = _targetLaneSign - _currentLaneSign;
    if (laneDiff.abs() <= laneRate) {
      _currentLaneSign = _targetLaneSign;
    } else {
      _currentLaneSign += laneDiff > 0 ? laneRate : -laneRate;
    }

    // --- Hard stop lines, resolved before anything is integrated ---
    // (unreserved next cell, blocked box, shop-lot gate, obstacle bumper gap).
    // `heldAtLine` means the drone is standing on the line right now.
    final (double maxAdvance, bool heldAtLine) = _advanceCap(
      dt,
      hasReservation,
      exitBlocked,
      obstacleGap: minObstacleGap,
    );

    // --- Acceleration/Deceleration ---
    // [FIX] Restart jitter: while held on a stop line the speed multiplier
    // used to be slammed to 0 after the fact (by the old rewind block and by
    // the lot gate inside _updatePosition) on the same frames the ramp below
    // was building it back up. Ask the ramp for zero instead, so the drone
    // decelerates into the line once and then simply holds — and pulls away
    // from a single, continuous baseline.
    final baseTarget = heldAtLine
        ? 0.0
        : targetMultiplier *
              _vehicleSpeedMultiplier *
              _terrainSpeed *
              _congestionMultiplier;
    if (_currentSpeedMultiplier < baseTarget) {
      double rate = accelerationRate;
      if (_currentSpeedMultiplier < 0.1) rate *= startupAccelerationBonus;
      if (game.activeEvent == 'dustStorm') {
        rate *= 0.3; // Much slower acceleration in thick dust
      }
      _currentSpeedMultiplier = min(
        baseTarget,
        _currentSpeedMultiplier + rate * dt,
      );
    } else if (_currentSpeedMultiplier > baseTarget) {
      _currentSpeedMultiplier = max(
        baseTarget,
        _currentSpeedMultiplier - decelerationRate * dt,
      );
    }

    double finalMultiplier = _currentSpeedMultiplier;
    // Disable the anti-stall minimum floor under two conditions:
    // 1. We are approaching a smart junction (roundabout entry) or an
    //    intersection this drone has not reserved — a hard "may stop dead".
    // 2. We are close behind another car (to allow a clean bumper stop) —
    //    this one is now a fade rather than a switch, see below.
    // Otherwise, keep the 0.08 floor active to prevent random stalls on open roads.
    final currentNode = path[_currentPathIndex.clamp(0, path.length - 1)];
    final bool isApproachingJunction =
        currentNode.side == null &&
        (_currentPathIndex + 1 < path.length &&
            path[_currentPathIndex + 1].side != null);
    bool canStop = isApproachingJunction;
    if (_currentPathIndex + 1 < path.length) {
      final nextNode = path[_currentPathIndex + 1];
      final cell = game.gridManager?.getCell(nextNode.x, nextNode.y);
      if (cell != null) {
        final isJunctionOrIntersection =
            cell.connectionType == ConnectionNodeType.intersection ||
            cell.type == CellType.trafficLight ||
            cell.type == CellType.smartJunction;
        if (isJunctionOrIntersection) {
          final occupancy = game.getOrCreateOccupancy(nextNode);
          final isRoundabout = cell.type == CellType.smartJunction;
          if (!occupancy.isReservedBy(this, isRoundabout) && !hasReservation) {
            canStop = true;
          }
        }
      }
    }
    // [FIX] Restart jitter: the floor now fades in across
    // [stallFloorFadeLow] .. [stallFloorFadeHigh] instead of switching on at
    // a single threshold, and it is off entirely while the drone is held on
    // a stop line. Previously `canStop` flipped frame to frame as the
    // obstacle scan re-measured the gap to the leader, so the applied speed
    // jumped between the ramped value and a flat 0.08 several times a
    // second — the visible stutter. On an open road the floor is unchanged.
    if (!_waitingAtSignal &&
        !arrived &&
        !isWaiting &&
        !heldAtLine &&
        !canStop) {
      final fade =
          ((_lastTargetMultiplier - stallFloorFadeLow) /
                  (stallFloorFadeHigh - stallFloorFadeLow))
              .clamp(0.0, 1.0);
      final floor = stallSpeedFloor * fade;
      if (floor > finalMultiplier) finalMultiplier = floor;
    }

    final oldPathIndex = _currentPathIndex;
    _updatePosition(dt * finalMultiplier, maxAdvance: maxAdvance);

    _currentPathIndex = _calculatePathIndex(_distanceTraveled);

    if (_currentPathIndex != oldPathIndex) {
      _ignoredObstacles.removeWhere(
        (o) =>
            o.arrived ||
            position.distanceToSquared(o.position) >
                (cellSize * 1.6) * (cellSize * 1.6),
      );
      // The car has moved past the node the override applied to; the next
      // "don't block the box" check is against a different downstream cell
      // and should be evaluated fresh rather than staying force-overridden.
      final currentCell = game.gridManager?.getCell(
        path[_currentPathIndex].x,
        path[_currentPathIndex].y,
      );
      final currentPos = path[_currentPathIndex];
      final stillInJunction =
          currentPos.side != null ||
          (currentCell != null &&
              (currentCell.connectionType == ConnectionNodeType.intersection ||
                  currentCell.type == CellType.trafficLight ||
                  currentCell.type == CellType.smartJunction ||
                  currentCell.isTunnel));
      if (!stillInJunction) {
        _boxDeadlockOverride = false;
      }
      if (path.isNotEmpty &&
          oldPathIndex < path.length &&
          _currentPathIndex < path.length) {
        final oldPos = path[oldPathIndex];
        final newPos = path[_currentPathIndex];

        if (oldPos.side == null && newPos.side != null) {
          _debugLog(
            "[ROUNDABOUT_ENTER] Car $this entered roundabout at (${newPos.x}, ${newPos.y}, ${newPos.side!.name})",
          );
        } else if (oldPos.side != null && newPos.side == null) {
          _debugLog(
            "[ROUNDABOUT_EXIT] Car $this exited roundabout to (${newPos.x}, ${newPos.y})",
          );
          _roundaboutInnerLane = null;
        }
      }

      if (path.isNotEmpty && oldPathIndex < path.length) {
        final pos = path[oldPathIndex];
        final RoadOccupancy occupancy = game.getOrCreateOccupancy(pos);
        occupancy.cars.remove(this);
        occupancy.clearReservation(this);
        _debugLog("[ROAD_RELEASE] Car $this left (${pos.x}, ${pos.y})");

        occupancy.activeIntersectionCars.remove(this);
        if (occupancy.activeIntersectionCars.isEmpty) {
          occupancy.reservedAxis = null;
          occupancy.consecutiveAxisCars = 0;
          _debugLog(
            "[INTERSECTION_RELEASE] Intersection (${pos.x}, ${pos.y}) released",
          );
        }
      }

      // Clear waiting state on the old next cell since we moved past/entered it
      if (path.isNotEmpty && oldPathIndex + 1 < path.length) {
        final oldNextPos = path[oldPathIndex + 1];
        final RoadOccupancy oldNextOccupancy = game.getOrCreateOccupancy(
          oldNextPos,
        );
        oldNextOccupancy.waitingCars.remove(this);
      }

      _registerOccupancy();
    }

    if (_currentSpeedMultiplier > 0.6) {
      _ignoredObstacles.removeWhere(
        (o) =>
            o.arrived ||
            position.distanceToSquared(o.position) >
                (cellSize * 1.6) * (cellSize * 1.6),
      );
    }

    // --- Deadlock Cycle Detection & Resolution ---
    final isStuck = _currentSpeedMultiplier < 0.05 && !isWaiting && !arrived;
    if (isStuck &&
        (_isInDeadlockCycle() || _deadlockTimer > _deadlockBreakTimeout * 1.5)) {
      _deadlockTimer += dt;
      if (_deadlockTimer > _deadlockBreakTimeout) {
        if (_closestObstacle != null) {
          _ignoredObstacles.add(_closestObstacle!);
          _debugLog(
            "[DEADLOCK_BREAK] Car $this ignoring obstacle $_closestObstacle to break deadlock",
          );
        }
        if (_currentPathIndex + 1 < path.length) {
          final nextNode = path[_currentPathIndex + 1];
          final cell = game.gridManager?.getCell(nextNode.x, nextNode.y);
          if (cell != null) {
            final occupancy = game.getOrCreateOccupancy(nextNode);
            final isRoundabout = cell.type == CellType.smartJunction;
            occupancy.setReservation(this, isRoundabout);
            _boxDeadlockOverride = true;
            _debugLog(
              "[DEADLOCK_BREAK] Car $this forcing reservation on (${nextNode.x}, ${nextNode.y}) to break deadlock",
            );
          }
        }
        _deadlockTimer = 0.0;
      }
    } else if (isStuck) {
      _deadlockTimer += dt;
    } else {
      _deadlockTimer = 0.0;
    }
  }

  bool _isInDeadlockCycle() {
    CarComponent? slow = this;
    CarComponent? fast = _closestObstacle;

    while (fast != null && fast != slow) {
      slow = slow?._closestObstacle;
      fast = fast._closestObstacle?._closestObstacle;
    }

    if (fast == null) return false;

    // fast is a node inside the cycle.
    // Verify that `this` car is an actual element of the circular deadlock,
    // and not just a linear queue/tail leading into it.
    if (fast == this) return true;
    CarComponent? curr = fast._closestObstacle;
    while (curr != null && curr != fast) {
      if (curr == this) return true;
      curr = curr._closestObstacle;
    }

    return false;
  }

  GridPosition _getCurrentGridPos() {
    final x = ((position.x - offsetX) / cellSize).floor();
    final y = ((position.y - offsetY) / cellSize).floor();
    return GridPosition(
      x.clamp(0, (game.gridManager?.cols ?? 1) - 1),
      y.clamp(0, (game.gridManager?.rows ?? 1) - 1),
    );
  }

  bool _isCellAhead(GridPosition otherCell) {
    final limit = min(path.length, _currentPathIndex + 4);
    for (int i = _currentPathIndex + 1; i < limit; i++) {
      final p = path[i];
      final eitherIsRoundabout = p.side != null || otherCell.side != null;
      if (eitherIsRoundabout) {
        if (p.x == otherCell.x &&
            p.y == otherCell.y &&
            p.side == otherCell.side) {
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

  @visibleForTesting
  bool isOncomingCar(CarComponent other) => _isOncomingCar(other);

  bool _isOncomingCar(CarComponent other) {
    if (other.arrived) return false;

    // 1. Path history check: if other is traversing the same segment in reverse
    // (I am going A -> B, other is going B -> A).
    final myIdx = _currentPathIndex.clamp(0, path.length - 1);
    final myNode = path[myIdx];
    final myNext = (myIdx + 1 < path.length) ? path[myIdx + 1] : null;

    final otherIdx = other._currentPathIndex.clamp(0, other.path.length - 1);
    final otherNode = other.path[otherIdx];
    final otherNext =
        (otherIdx + 1 < other.path.length) ? other.path[otherIdx + 1] : null;

    if (myNext != null && otherNext != null) {
      if (otherNext.x == myNode.x &&
          otherNext.y == myNode.y &&
          otherNext.side == myNode.side &&
          otherNode.x == myNext.x &&
          otherNode.y == myNext.y &&
          otherNode.side == myNext.side) {
        return true;
      }
    }

    // 2. Heading check: if the drones travel in opposite directions (dot
    // product is negative).
    // [PERF] Scalar dot product — this is called from `.where()` filters that
    // run per frame at every intersection, and used to allocate two Vector2s
    // per call.
    // [FIX] Queueing: was cos/sin of `angle`, which is pinned to 0 for every
    // drone, so this dot product was a constant 1.0 and no drone was ever
    // classified as oncoming. Facing comes from the path tangent now.
    _refreshHeading();
    other._refreshHeading();
    if (_headingX * other._headingX + _headingY * other._headingY < -0.3) {
      return true;
    }

    return false;
  }

  Direction _getRoundaboutYieldDirection(Direction enteringSide) {
    switch (enteringSide) {
      case Direction.west:
        return Direction.south;
      case Direction.north:
        return Direction.west;
      case Direction.east:
        return Direction.north;
      case Direction.south:
        return Direction.east;
    }
  }

  Direction getNextClockwise(Direction dir) {
    switch (dir) {
      case Direction.north:
        return Direction.east;
      case Direction.east:
        return Direction.south;
      case Direction.south:
        return Direction.west;
      case Direction.west:
        return Direction.north;
    }
  }

  // ============================================================
  // RENDERING — single sprite from the shared 1x6 vehicle atlas.
  // One drawImageRect call per car; all 6 colors share one GPU texture.
  // ============================================================

  @override
  void render(Canvas canvas) {
    // Cars hide immediately on arrival at either end of the trip — same
    // behavior for a delivery (destination) as for a return home (house).
    // A visible parking-stall offset was tried for destinations but reverted
    // per user request; keep both cases simple and consistent.
    if (arrived) return;
    // Waiting cars stay visible: they are parked (see _parkAtCurrentEnd).

    // 1. Draw trailing paths in local space (before saving/translating/rotating canvas)
    final baseColor = GameConstants.getBuildingColor(colorIndex);
    if (GameConstants.carTrails && _trailPositions.length >= 2) {
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

    // Vehicles are hover drones gliding above the traces. The render canvas
    // origin is the component's top-left, so the drone sits at size/2.
    drawDrone(
      canvas,
      Offset(size.x / 2, size.y / 2),
      size.x * GameConstants.droneRadius,
      baseColor,
      game.elapsedTime + _bobPhase,
    );
  }

  /// The drone glyph: a domed disc in the house colour hovering above the
  /// board. It bobs gently with [t] (seconds plus a per-drone phase): the
  /// body rises and falls while the shadow beneath it shrinks and grows, so
  /// even a parked drone feels alive. No nose, so heading never matters.
  /// Shared with GridRenderer's parked pass so both match. [r] is the disc
  /// radius.
  static void drawDrone(
    Canvas canvas,
    Offset c0,
    double r,
    Color color,
    double t,
  ) {
    final bob = sin(t * 2.6);
    final c = Offset(c0.dx, c0.dy - r * 0.10 * bob);
    final tones = _tonesFor(color);

    // [PERF] Hover shadow. This used to be a single oval painted through a
    // MaskFilter.blur — one real blur per drone per frame, for every moving
    // drone AND every idle parking slot (GridRenderer._drawParkedCars draws
    // the same glyph). On Flutter web that is the single most expensive
    // thing in the frame at 40+ drones. Two stacked flat translucent ovals
    // (a wide faint one under a tighter darker one) give the same soft
    // "hovering above the board" read for the cost of two plain fills.
    final shadowScale = 1.0 - 0.12 * bob;
    final sc = Offset(c0.dx, c0.dy + r * 1.05);
    canvas.drawOval(
      Rect.fromCenter(
        center: sc,
        width: r * 2.7 * shadowScale,
        height: r * 1.3 * shadowScale,
      ),
      _shadowOuterPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: sc,
        width: r * 1.9 * shadowScale,
        height: r * 0.9 * shadowScale,
      ),
      _shadowInnerPaint,
    );
    // Glow.
    canvas.drawCircle(c, r * 2.1, _glowOuterPaint..color = tones.glowOuter);
    canvas.drawCircle(c, r * 1.45, _glowInnerPaint..color = tones.glowInner);
    // Saucer: flat disc with a darker rim and a thin light edge on top.
    final disc = Rect.fromCenter(center: c, width: r * 2.0, height: r * 1.3);
    canvas.drawOval(disc, _rimPaint..color = tones.dark);
    final body = disc.deflate(r * 0.15);
    canvas.drawOval(body, _bodyPaint..color = color);
    canvas.drawArc(
      body,
      pi,
      pi,
      false,
      _edgePaint
        ..color = tones.edge
        ..strokeWidth = r * 0.10,
    );
    // Dome on top with a highlight.
    final dome = Rect.fromCenter(
      center: Offset(c.dx, c.dy - r * 0.25),
      width: r * 1.05,
      height: r * 0.9,
    );
    canvas.drawOval(dome, _domePaint..color = tones.light);
    canvas.drawCircle(
      Offset(c.dx - r * 0.18, c.dy - r * 0.42),
      r * 0.17,
      _highlightPaint,
    );
  }

  // [PERF] Reused paints for the drone glyph. Every call used to allocate
  // eight Paint objects (and several Colors); at 40+ drones times 60 fps
  // that is thousands of short-lived objects a second. Canvas draw calls
  // snapshot the paint immediately, so mutating and reusing them is safe.
  static final Paint _shadowOuterPaint = Paint()
    ..color = const Color(0x1F000000);
  static final Paint _shadowInnerPaint = Paint()
    ..color = const Color(0x38000000);
  static final Paint _glowOuterPaint = Paint();
  static final Paint _glowInnerPaint = Paint();
  static final Paint _rimPaint = Paint();
  static final Paint _bodyPaint = Paint();
  static final Paint _edgePaint = Paint()..style = PaintingStyle.stroke;
  static final Paint _domePaint = Paint();
  static final Paint _highlightPaint = Paint()..color = const Color(0xD9FFFFFF);

  /// Derived tints for one drone colour. There are only a handful of house
  /// colours, so the Color.lerp/withValues work is done once each.
  static final Map<Color, _DroneTones> _droneTones = {};

  static _DroneTones _tonesFor(Color color) {
    final cached = _droneTones[color];
    if (cached != null) return cached;
    final dark = Color.lerp(color, const Color(0xFF10181B), 0.42)!;
    final light = Color.lerp(color, Colors.white, 0.42)!;
    final tones = _DroneTones(
      dark: dark,
      light: light,
      edge: light.withValues(alpha: 0.7),
      glowOuter: color.withValues(alpha: 0.10),
      glowInner: color.withValues(alpha: 0.16),
    );
    _droneTones[color] = tones;
    return tones;
  }
}

class _DroneTones {
  const _DroneTones({
    required this.dark,
    required this.light,
    required this.edge,
    required this.glowOuter,
    required this.glowInner,
  });

  final Color dark;
  final Color light;
  final Color edge;
  final Color glowOuter;
  final Color glowInner;
}
