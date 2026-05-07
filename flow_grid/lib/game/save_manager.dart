import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'grid_manager.dart';
import 'components/car_component.dart';

class SaveManager {
  static const String _saveKey = 'flow_grid_save';

  static Future<void> saveGame(
    GridManager gridManager,
    int week,
    int score,
    int totalDeliveries, {
    required double weekTimer,
    required double spawnTimer,
    required int activeColorCount,
    required int zoomLevel,
    required double elapsedTime,
    required Map<String, int> houseCarCounts,
    required List<CarComponent> cars,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Serialize grid
    final gridData = <List<Map<String, dynamic>>>[];
    for (int y = 0; y < gridManager.rows; y++) {
      final row = <Map<String, dynamic>>[];
      for (int x = 0; x < gridManager.cols; x++) {
        final cell = gridManager.grid[y][x];
        row.add({
          'type': cell.type.index,
          'colorIndex': cell.colorIndex,
          'isPendingDeletion': cell.isPendingDeletion,
          'isTunnelExtension': cell.isTunnelExtension,
          'hasTrafficLight': cell.hasTrafficLight,
        });
      }
      gridData.add(row);
    }

    // Serialize express lanes
    final expressLanesData = gridManager.placedExpressLanes.map((pair) {
      return [
        {'x': pair[0].x, 'y': pair[0].y},
        {'x': pair[1].x, 'y': pair[1].y},
      ];
    }).toList();

    // Serialize driveways
    final drivewaysData = gridManager.buildingDriveways.map((key, value) {
      return MapEntry(key, {'x': value.x, 'y': value.y});
    });

    // Serialize demand state
    final demandData = <String, dynamic>{};
    final claimedDemandData = <String, dynamic>{};
    final demandTimerData = <String, dynamic>{};
    final overflowLevelData = <String, dynamic>{};
    final destinationAgeData = <String, dynamic>{};
    final houseCarTimerData = <String, dynamic>{};

    gridManager.demand.forEach((k, v) => demandData[k] = v);
    gridManager.claimedDemand.forEach((k, v) => claimedDemandData[k] = v);
    gridManager.demandTimers.forEach((k, v) => demandTimerData[k] = v);
    gridManager.overflowLevels.forEach((k, v) => overflowLevelData[k] = v);
    gridManager.destinationAges.forEach((k, v) => destinationAgeData[k] = v);
    gridManager.houseCarTimers.forEach((k, v) => houseCarTimerData[k] = v);

    // Serialize cars
    final carsData = cars
        .where((c) => !c.arrived)
        .map((c) => c.toJson())
        .toList();

    final data = {
      'gridCols': gridManager.cols,
      'gridRows': gridManager.rows,
      'grid': gridData,
      'placedExpressLanes': expressLanesData,
      'driveways': drivewaysData,
      'week': week,
      'score': score,
      'totalDeliveries': totalDeliveries,
      'weekTimer': weekTimer,
      'spawnTimer': spawnTimer,
      'activeColorCount': activeColorCount,
      'zoomLevel': zoomLevel,
      'elapsedTime': elapsedTime,
      'houseCarCounts': houseCarCounts,
      'demand': demandData,
      'claimedDemand': claimedDemandData,
      'demandTimers': demandTimerData,
      'overflowLevels': overflowLevelData,
      'destinationAges': destinationAgeData,
      'houseCarTimers': houseCarTimerData,
      'cars': carsData,
      'inventory': {
        'roads': gridManager.roads,
        'tunnels': gridManager.tunnels,
        'trafficLights': gridManager.trafficLights,
        'smartJunctions': gridManager.smartJunctions,
        'expressLanes': gridManager.expressLanes,
      },
    };

    await prefs.setString(_saveKey, jsonEncode(data));
  }

  static Future<Map<String, dynamic>?> loadGame() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_saveKey);
    if (jsonStr == null) return null;

    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> hasSaveGame() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_saveKey);
  }

  static Future<void> clearSave() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_saveKey);
  }
}
