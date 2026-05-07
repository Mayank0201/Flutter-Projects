import 'dart:math';
import '../map_generator.dart';
import '../grid_manager.dart';
import '../../models/grid_cell.dart';

class NileMapGenerator extends MapGenerator {
  final Random _random = Random();

  @override
  String get name => "NILE";

  @override
  String get description => "A sprawling river city shaped by water crossings.";

  @override
  MapConfig get config => const MapConfig(
    startingRoads: 20,
    startingTunnels: 0,
    startingBridges: 1,
  );

  @override
  void generateInitialTerrain(GridManager grid, {int? minX, int? maxX, int? minY, int? maxY}) {
    int attempts = 0;
    bool valid = false;

    while (!valid && attempts < 5) {
      _generate(grid, minX: minX, maxX: maxX, minY: minY, maxY: maxY);
      valid = _validate(grid);
      attempts++;
    }
  }

  void _generate(GridManager grid, {int? minX, int? maxX, int? minY, int? maxY}) {
    // Clear grid of terrain
    for (int y = 0; y < grid.rows; y++) {
      for (int x = 0; x < grid.cols; x++) {
        if (grid.grid[y][x].isMountain || grid.grid[y][x].isWater) {
          grid.grid[y][x] = GridCell();
        }
      }
    }

    // Generate 1-2 major rivers
    final riverCount = 1 + _random.nextInt(2);
    for (int i = 0; i < riverCount; i++) {
      _drawWindingRiver(grid, i);
    }

    grid.detectRegionsEndless();
    grid.applyTerrainSpeeds();
  }

  void _drawWindingRiver(GridManager grid, int index) {
    final isVertical = _random.nextBool();
    final startOffset = (index * 20) + _random.nextInt(15);
    final amplitude = 4.0 + _random.nextDouble() * 8.0;
    final frequency = 0.05 + _random.nextDouble() * 0.1;
    final phase = _random.nextDouble() * pi * 2;

    if (isVertical) {
      final centerX = (grid.cols ~/ (index + 2)) + startOffset;
      for (int y = 0; y < grid.rows; y++) {
        final wx = centerX + (sin(y * frequency + phase) * amplitude).round();
        final width = 2 + _random.nextInt(2);
        for (int dx = -width; dx <= width; dx++) {
          final tx = wx + dx;
          if (grid.isValid(tx, y)) {
            grid.grid[y][tx] = GridCell(type: CellType.water);
          }
        }
      }
    } else {
      final centerY = (grid.rows ~/ (index + 2)) + startOffset;
      for (int x = 0; x < grid.cols; x++) {
        final wy = centerY + (sin(x * frequency + phase) * amplitude).round();
        final width = 2 + _random.nextInt(2);
        for (int dy = -width; dy <= width; dy++) {
          final ty = wy + dy;
          if (grid.isValid(x, ty)) {
            grid.grid[ty][x] = GridCell(type: CellType.water);
          }
        }
      }
    }
  }

  bool _validate(GridManager grid) {
    int waterCount = 0;
    for (var row in grid.grid) {
      for (var cell in row) {
        if (cell.type == CellType.water) waterCount++;
      }
    }
    final coverage = waterCount / (grid.cols * grid.rows);
    if (coverage < 0.08 || coverage > 0.30) return false;
    return true; 
  }

  @override
  void generateExpansion(GridManager grid, int week) {
    if (week % 5 == 0) {
      _drawWindingRiver(grid, 0); 
      grid.detectRegionsEndless();
      grid.applyTerrainSpeeds();
    }
  }
}
