enum Direction { north, east, south, west }

extension DirectionExtension on Direction {
  Direction get opposite {
    switch (this) {
      case Direction.north: return Direction.south;
      case Direction.east: return Direction.west;
      case Direction.south: return Direction.north;
      case Direction.west: return Direction.east;
    }
  }

  Direction rotateCW() {
    switch (this) {
      case Direction.north: return Direction.east;
      case Direction.east: return Direction.south;
      case Direction.south: return Direction.west;
      case Direction.west: return Direction.north;
    }
  }

  Direction rotateCCW() {
    switch (this) {
      case Direction.north: return Direction.west;
      case Direction.east: return Direction.north;
      case Direction.south: return Direction.east;
      case Direction.west: return Direction.south;
    }
  }
}
enum MapRegion { A, B }

enum VehicleType { car, truck, serviceVan }

enum CellType {
  empty,
  road,
  house,
  destination,
  mountain,       // was: water
  tunnel,         // was: bridge
  smartJunction,  // was: roundabout
  trafficLight,
  expresswayNode, // generic node marker if needed, but overpass layer is preferred
}

enum OverpassType { none, start, end }

enum RoadEdgeType { normal, tunnel, expressway }

class GridCell {
  final CellType type;
  final int? colorIndex;
  final bool isPendingDeletion;
  final bool hasTrafficLight;
  final bool isTunnelExtension; // was: isBridgeExtension
  final Direction? entrySide;
  final MapRegion? region;
  
  final bool isReserved;
  
  // NODE-BASED CONNECTIONS (up, right, down, left)
  final bool connUp;
  final bool connDown;
  final bool connLeft;
  final bool connRight;

  final double speedMultiplier; // 1.0 normal, 0.6 near mountain, 2.5 express lane
  final int capacity;           // max cars on this segment (default 5)
  final bool isExpressLane;
  final OverpassType overpass;
  
  // Traffic signal state
  final int signalPhase;     // 0 = N/S green, 1 = E/W green

  GridCell({
    this.type = CellType.empty,
    this.colorIndex,
    this.isPendingDeletion = false,
    this.hasTrafficLight = false,
    this.isTunnelExtension = false,
    this.entrySide,
    this.isReserved = false,
    this.connUp = false,
    this.connDown = false,
    this.connLeft = false,
    this.connRight = false,
    this.speedMultiplier = 1.0,
    this.capacity = 5,
    this.isExpressLane = false,
    this.overpass = OverpassType.none,
    this.signalPhase = 0,
    this.region,
  });

  GridCell copyWith({
    CellType? type,
    int? colorIndex,
    bool? isPendingDeletion,
    bool? hasTrafficLight,
    bool? isTunnelExtension,
    Direction? entrySide,
    bool? isReserved,
    bool? connUp,
    bool? connDown,
    bool? connLeft,
    bool? connRight,
    double? speedMultiplier,
    int? capacity,
    bool? isExpressLane,
    int? signalPhase,
    OverpassType? overpass,
    MapRegion? region,
  }) {
    return GridCell(
      type: type ?? this.type,
      colorIndex: colorIndex ?? this.colorIndex,
      isPendingDeletion: isPendingDeletion ?? this.isPendingDeletion,
      hasTrafficLight: hasTrafficLight ?? this.hasTrafficLight,
      isTunnelExtension: isTunnelExtension ?? this.isTunnelExtension,
      entrySide: entrySide ?? this.entrySide,
      isReserved: isReserved ?? this.isReserved,
      connUp: connUp ?? this.connUp,
      connDown: connDown ?? this.connDown,
      connLeft: connLeft ?? this.connLeft,
      connRight: connRight ?? this.connRight,
      speedMultiplier: speedMultiplier ?? this.speedMultiplier,
      capacity: capacity ?? this.capacity,
      isExpressLane: isExpressLane ?? this.isExpressLane,
      overpass: overpass ?? this.overpass,
      signalPhase: signalPhase ?? this.signalPhase,
      region: region ?? this.region,
    );
  }

  bool get isEmpty => type == CellType.empty;
  bool get isRoad => type == CellType.road || type == CellType.tunnel || type == CellType.trafficLight;
  bool get isHouse => type == CellType.house;
  bool get isDestination => type == CellType.destination;
  bool get isMountain => type == CellType.mountain || type == CellType.tunnel;
  bool get isTunnel => type == CellType.tunnel;
  bool get isExpressLaneNode => overpass != OverpassType.none;
  bool get isSmartJunction => type == CellType.smartJunction;
  bool get isPassable =>
      isRoad ||
      isExpressLaneNode ||
      type == CellType.smartJunction ||
      type == CellType.trafficLight;
}

class GridPosition {
  final int x;
  final int y;
  final Direction? side; // Optional side for sub-nodes (e.g. Smart Junctions)

  const GridPosition(this.x, this.y, [this.side]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GridPosition &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y &&
          side == other.side;

  @override
  int get hashCode => x.hashCode ^ y.hashCode ^ side.hashCode;

  /// Unique key for Map indexing, including sub-node side
  String get key => side == null ? '$x,$y' : '$x,$y-${side!.name}';

  @override
  String toString() => side == null ? '($x, $y)' : '($x, $y, ${side!.name})';

  GridPosition getNeighbor(Direction dir, {int count = 1}) {
    switch (dir) {
      case Direction.north:
        return GridPosition(x, y - count);
      case Direction.east:
        return GridPosition(x + count, y);
      case Direction.south:
        return GridPosition(x, y + count);
      case Direction.west:
        return GridPosition(x - count, y);
    }
  }

  int manhattanDistance(GridPosition other) {
    return (x - other.x).abs() + (y - other.y).abs();
  }
}
