import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'grid_manager.dart';
import 'components/car_component.dart';

class SaveMetadata {
  final int slotIndex;
  final int mapType;
  final int week;
  final int score;
  final int totalDeliveries;
  final int saveTime;
  final double elapsedTime;

  SaveMetadata({
    required this.slotIndex,
    required this.mapType,
    required this.week,
    required this.score,
    required this.totalDeliveries,
    required this.saveTime,
    required this.elapsedTime,
  });

  Map<String, dynamic> toJson() => {
    'slotIndex': slotIndex,
    'mapType': mapType,
    'week': week,
    'score': score,
    'totalDeliveries': totalDeliveries,
    'saveTime': saveTime,
    'elapsedTime': elapsedTime,
  };

  factory SaveMetadata.fromJson(Map<String, dynamic> json) => SaveMetadata(
    slotIndex: json['slotIndex'],
    mapType: json['mapType'],
    week: json['week'],
    score: json['score'],
    totalDeliveries: json['totalDeliveries'],
    saveTime: json['saveTime'],
    elapsedTime: (json['elapsedTime'] as num).toDouble(),
  );
}

class SaveManager {
  static const String _savePrefix = 'flow_grid_save_slot_';
  static const int maxSlots = 3;

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
    required double cameraZoom,
    required double cameraPosX,
    required double cameraPosY,
    int slotIndex = 0,
    Map<String, dynamic> districtTypes = const {},
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
          'speedMultiplier': cell.speedMultiplier,
          'entrySide': cell.entrySide?.index,
          'isInfrastructureInternal': cell.isInfrastructureInternal,
          'isConnectableEndpoint': cell.isConnectableEndpoint,
          'infrastructureAxis': cell.infrastructureAxis?.index,
          'owner': cell.owner.index,
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

    final now = DateTime.now().millisecondsSinceEpoch;

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
      'cameraZoom': cameraZoom,
      'cameraPosX': cameraPosX,
      'cameraPosY': cameraPosY,
      'inventory': {
        'roads': gridManager.roads,
        'tunnels': gridManager.tunnels,
        'bridges': gridManager.bridges,
        'trafficLights': gridManager.trafficLights,
        'smartJunctions': gridManager.smartJunctions,
        'expressLanes': gridManager.expressLanes,
      },
      'mapType': gridManager.selectedMapType.index,
      'saveTime': now,
      'activeEdges': gridManager.activeEdges.toList(),
      'districtTypes': districtTypes,
    };

    await prefs.setString('$_savePrefix$slotIndex', jsonEncode(data));
  }

  static Future<Map<String, dynamic>?> loadGame({int slotIndex = 0}) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('$_savePrefix$slotIndex');
    if (jsonStr == null) return null;

    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      
      // Basic schema validation
      if (data['grid'] == null || data['gridCols'] == null || data['gridRows'] == null) {
        return null;
      }
      
      return data;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> hasSaveGame({int slotIndex = 0}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('$_savePrefix$slotIndex');
  }

  static Future<int> getNextAvailableSlot() async {
    for (int i = 0; i < maxSlots; i++) {
      if (!await hasSaveGame(slotIndex: i)) return i;
    }
    return 0; // Overwrite first if full (or handle differently)
  }

  static Future<Map<String, dynamic>?> getSaveMetadata(int slotIndex) async {
    final save = await loadGame(slotIndex: slotIndex);
    if (save == null) return null;
    return {
      'week': save['week'],
      'score': save['score'],
      'mapType': save['mapType'],
      'saveTime': save['saveTime'],
      'elapsedTime': save['elapsedTime'],
      'deliveries': save['totalDeliveries'],
    };
  }

  static Future<void> clearSave({int slotIndex = 0}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_savePrefix$slotIndex');
  }
}
