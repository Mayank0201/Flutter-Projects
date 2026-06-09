enum InteractionState { idle, preview, commit }
enum Direction { north, east, south, west }
enum InfrastructureAxis { horizontal, vertical }
enum ConnectionNodeType {
  buildingEntrance,
  infrastructureConnector,
  intersection,
  corridorInternal,
  none
}

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

enum VehicleType { car, truck, serviceVan, bus, emergency }

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
  water,          // Large rivers/waterways
  bridge,         // Infrastructure for water crossings
  metroTrack,     // [NEW] Underground/Surface Metro
  elevatedRail,   // [NEW] High-capacity rail
  highway,        // [NEW] High-speed surface road
}

enum OverpassType { none, start, end }

enum RoadEdgeType { normal, tunnel, expressway }

enum InfrastructureOwner { none, player, systemGenerated, eventGenerated }

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
  final bool isInfrastructureInternal;
  final bool isConnectableEndpoint;
  final InfrastructureAxis? infrastructureAxis;
  final int roadLevel; // 0: Street, 1: Avenue, 2: Highway
  
  // [NEW] Transit & Road Management
  final bool isBusStop;
  final bool isBusLane;
  final bool isOneWay;
  final Direction? oneWayDirection;
  final String? busRouteId;
  final bool isMetroStation;
  final bool isPriority;
  
  // [NEW] Mega City Systems
  final double satisfaction; // 0.0 (miserable) to 1.0 (perfect)
  final String? sectorId;    // Identification of regional expansion sector
  final bool isHighway;
  final bool isElevatedRail;
  final InfrastructureOwner owner;
  final InfrastructureOwner upgradeOwner;
  final bool isIceRoad;

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
    this.isInfrastructureInternal = false,
    this.isConnectableEndpoint = false,
    this.infrastructureAxis,
    this.roadLevel = 0, // 0: Street, 1: Avenue, 2: Highway
    this.isBusStop = false,
    this.isBusLane = false,
    this.isOneWay = false,
    this.oneWayDirection,
    this.busRouteId,
    this.isMetroStation = false,
    this.isPriority = false,
    this.satisfaction = 1.0,
    this.sectorId,
    this.isHighway = false,
    this.isElevatedRail = false,
    this.owner = InfrastructureOwner.none,
    this.upgradeOwner = InfrastructureOwner.none,
    this.isIceRoad = false,
  });

  bool get hasSmartJunction => type == CellType.smartJunction;

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
    bool? isInfrastructureInternal,
    bool? isConnectableEndpoint,
    InfrastructureAxis? infrastructureAxis,
    int? roadLevel,
    bool? isBusStop,
    bool? isBusLane,
    bool? isOneWay,
    Direction? oneWayDirection,
    String? busRouteId,
    bool? isMetroStation,
    bool? isPriority,
    double? satisfaction,
    String? sectorId,
    bool? isHighway,
    bool? isElevatedRail,
    InfrastructureOwner? owner,
    InfrastructureOwner? upgradeOwner,
    bool? isIceRoad,
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
      isInfrastructureInternal: isInfrastructureInternal ?? this.isInfrastructureInternal,
      isConnectableEndpoint: isConnectableEndpoint ?? this.isConnectableEndpoint,
      infrastructureAxis: infrastructureAxis ?? this.infrastructureAxis,
      roadLevel: roadLevel ?? this.roadLevel,
      isBusStop: isBusStop ?? this.isBusStop,
      isBusLane: isBusLane ?? this.isBusLane,
      isOneWay: isOneWay ?? this.isOneWay,
      oneWayDirection: oneWayDirection ?? this.oneWayDirection,
      busRouteId: busRouteId ?? this.busRouteId,
      isMetroStation: isMetroStation ?? this.isMetroStation,
      isPriority: isPriority ?? this.isPriority,
      satisfaction: satisfaction ?? this.satisfaction,
      sectorId: sectorId ?? this.sectorId,
      isHighway: isHighway ?? this.isHighway,
      isElevatedRail: isElevatedRail ?? this.isElevatedRail,
      owner: owner ?? this.owner,
      upgradeOwner: upgradeOwner ?? this.upgradeOwner,
      isIceRoad: isIceRoad ?? this.isIceRoad,
    );
  }

  bool get isEmpty => type == CellType.empty;
  bool get isRoad => type == CellType.road || type == CellType.tunnel || type == CellType.bridge || type == CellType.trafficLight;
  bool get isHouse => type == CellType.house;
  bool get isDestination => type == CellType.destination;
  bool get isMountain => type == CellType.mountain;
  bool get isTunnel => type == CellType.tunnel;
  bool get isBridge => type == CellType.bridge;
  bool get isWater => type == CellType.water;
  bool get isExpressLaneNode => overpass != OverpassType.none;
  bool get isSmartJunction => type == CellType.smartJunction;
  bool get isMetro => isMetroStation;
  
  ConnectionNodeType get connectionType {
    if (isConnectableEndpoint) return ConnectionNodeType.infrastructureConnector;
    if (isInfrastructureInternal) return ConnectionNodeType.corridorInternal;
    if (type == CellType.road) {
      int count = 0;
      if (connUp) count++;
      if (connDown) count++;
      if (connLeft) count++;
      if (connRight) count++;
      if (count >= 3) {
        return ConnectionNodeType.intersection;
      }
    }
    return ConnectionNodeType.none;
  }

  bool get isPassable =>
      isRoad ||
      isExpressLaneNode ||
      isHighway ||
      isElevatedRail ||
      type == CellType.metroTrack ||
      type == CellType.elevatedRail ||
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
