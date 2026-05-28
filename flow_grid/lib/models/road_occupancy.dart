import '../game/components/car_component.dart';
import 'grid_cell.dart';

class RoadOccupancy {
  final List<CarComponent> cars = [];
  CarComponent? reservedBy;
  int maxCars = 2;

  // Entry spacing cooldown for roundabouts
  double lastEntryTime = 0.0;
  double lastEntryTimeInner = 0.0;
  double lastEntryTimeOuter = 0.0;

  // Roundabout specific lane-based reservations
  CarComponent? reservedByInner;
  CarComponent? reservedByOuter;

  // Intersection Reservation
  InfrastructureAxis? reservedAxis;
  final List<CarComponent> activeIntersectionCars = [];

  // Waiting queue for this cell/intersection
  final List<CarComponent> waitingCars = [];

  // Alternating priority tracking
  bool lastPassedWasOutbound = false;
  int consecutiveOutbound = 0;
  int consecutiveReturning = 0;

  // Helper methods to manage reservations
  bool isReservedBySameLane(CarComponent car, bool isRoundabout) {
    if (isRoundabout) {
      final isInner = car.isRoundaboutInner;
      final sameLaneRes = isInner ? reservedByInner : reservedByOuter;
      return sameLaneRes != null && sameLaneRes != car;
    } else {
      return reservedBy != null && reservedBy != car;
    }
  }

  bool isReservedBy(CarComponent car, bool isRoundabout) {
    if (isRoundabout) {
      final isInner = car.isRoundaboutInner;
      return (isInner ? reservedByInner : reservedByOuter) == car;
    } else {
      return reservedBy == car;
    }
  }

  void setReservation(CarComponent car, bool isRoundabout) {
    if (isRoundabout) {
      final isInner = car.isRoundaboutInner;
      if (isInner) {
        reservedByInner = car;
      } else {
        reservedByOuter = car;
      }
    } else {
      reservedBy = car;
    }
  }

  void clearReservation(CarComponent car) {
    if (reservedBy == car) {
      reservedBy = null;
    }
    if (reservedByInner == car) {
      reservedByInner = null;
    }
    if (reservedByOuter == car) {
      reservedByOuter = null;
    }
  }
}
