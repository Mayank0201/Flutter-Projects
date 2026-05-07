import 'grid_cell.dart';

class BusStop {
  final GridPosition position;
  final String routeId;
  int waitingPassengers;

  BusStop({
    required this.position,
    required this.routeId,
    this.waitingPassengers = 0,
  });
}

class BusRoute {
  final String id;
  final String name;
  final List<GridPosition> stops;
  final List<GridPosition> path; // Pre-calculated path connecting all stops
  final List<int> colorIndices; // Which district colors it serves
  int passengerCount;

  BusRoute({
    required this.id,
    required this.name,
    required this.stops,
    required this.path,
    this.colorIndices = const [],
    this.passengerCount = 0,
  });

  bool servesColor(int colorIndex) => colorIndices.contains(colorIndex);
}
