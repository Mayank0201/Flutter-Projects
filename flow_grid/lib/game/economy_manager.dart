import 'package:flame/components.dart';
import 'flow_grid_game.dart';

class EconomyManager extends Component with HasGameReference<FlowGridGame> {
  double _balance = 1000.0; // Starting budget
  double get balance => _balance;

  // Costs
  static const double costRoad = 10.0;
  static const double costHighway = 50.0;
  static const double costBusStop = 100.0;
  static const double costMetroStation = 500.0;
  static const double costTrafficLight = 30.0;
  static const double costSmartJunction = 80.0;

  // Income
  static const double rewardDelivery = 25.0;
  static const double rewardTransitPassenger = 2.0;

  void addMoney(double amount) {
    _balance += amount;
  }

  bool spendMoney(double amount) {
    if (_balance >= amount) {
      _balance -= amount;
      return true;
    }
    return false;
  }

  void processDeliveryReward(int colorIndex) {
    // Basic reward + bonus for efficiency
    addMoney(rewardDelivery);
  }

  void processTransitFare() {
    addMoney(rewardTransitPassenger);
  }
}
