import 'components/car_component.dart';
import '../models/grid_cell.dart';

class CarPool {
  final List<CarComponent> _availableCars = [];
  
  CarComponent getCar({
    required int colorIndex,
    required List<GridPosition> path,
    required double cellSize,
    required GridPosition spawnHousePos,
    required GridPosition targetDest,
    double offsetX = 0,
    double offsetY = 0,
    VehicleType vehicleType = VehicleType.car,
    String? routeId,
  }) {
    if (_availableCars.isNotEmpty) {
      final car = _availableCars.removeLast();
      car.reuseState(
        path: path,
        colorIndex: colorIndex,
        spawnHousePos: spawnHousePos,
        targetDest: targetDest,
        vehicleType: vehicleType,
        routeId: routeId,
      );
      return car;
    } else {
      return CarComponent(
        colorIndex: colorIndex,
        path: path,
        cellSize: cellSize,
        spawnHousePos: spawnHousePos,
        targetDest: targetDest,
        offsetX: offsetX,
        offsetY: offsetY,
        vehicleType: vehicleType,
        routeId: routeId,
      );
    }
  }

  void returnCar(CarComponent car) {
    _availableCars.add(car);
  }
}
