import '../map_generator.dart';
import '../grid_manager.dart';

class ZenMapGenerator extends MapGenerator {
  @override
  String get name => "ZEN";

  @override
  String get description => "Fully open layout — no central mountain divide.";

  @override
  MapConfig get config => const MapConfig(
    startingRoads: 25,
    startingTunnels: 1,
    startingBridges: 0,
  );

  @override
  void generateInitialTerrain(GridManager grid, {int? minX, int? maxX, int? minY, int? maxY}) {
    // Zen: open canvas — no central mountain divide.
    grid.detectRegionsEndless();
    grid.applyTerrainSpeeds();
  }

  @override
  void generateExpansion(GridManager grid, int week) {
    // Zen: no mountain fragments injected on weekly expansion.
  }
}
