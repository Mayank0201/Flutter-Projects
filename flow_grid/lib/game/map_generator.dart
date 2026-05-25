import 'grid_manager.dart';
import 'generators/zen_generator.dart';
import 'generators/andes_generator.dart';
import 'generators/nile_generator.dart';
import 'generators/arctic_generator.dart';
import 'generators/savanna_generator.dart';
import 'generators/delta_generator.dart';

enum MapType {
  zen,
  andes,
  nile,
  arctic,
  savanna,
  delta,
}

class MapConfig {
  final int startingRoads;
  final int startingTunnels;
  final int startingBridges;
  final int startingTrafficLights;
  final int startingSmartJunctions;
  final int startingExpressLanes;

  const MapConfig({
    this.startingRoads = 20,
    this.startingTunnels = 0,
    this.startingBridges = 0,
    this.startingTrafficLights = 0,
    this.startingSmartJunctions = 0,
    this.startingExpressLanes = 0,
  });
}

abstract class MapGenerator {
  String get name;
  String get description;
  MapConfig get config;
  
  void generateInitialTerrain(GridManager grid, {int? minX, int? maxX, int? minY, int? maxY});
  
  // Called on weekly expansion if needed
  void generateExpansion(GridManager grid, int week);

  bool validatePlayability(GridManager grid) {
    // Basic check: Ensure there are enough empty cells and no total partition
    return true;
  }
}

class MapGeneratorFactory {
  static MapGenerator getGenerator(MapType type) {
    switch (type) {
      case MapType.zen:
        return ZenMapGenerator();
      case MapType.andes:
        return AndesMapGenerator();
      case MapType.nile:
        return NileMapGenerator();
      case MapType.arctic:
        return ArcticMapGenerator();
      case MapType.savanna:
        return SavannaMapGenerator();
      case MapType.delta:
        return DeltaMapGenerator();
    }
  }
}

