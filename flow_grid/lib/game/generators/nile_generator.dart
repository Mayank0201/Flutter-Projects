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
    startingRoads: 25,
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
      _drawWindingRiver(grid, i, minX: minX, maxX: maxX, minY: minY, maxY: maxY);
    }

    _cleanupIsolatedWater(grid);

    grid.detectRegionsEndless();
    grid.applyTerrainSpeeds();
  }

  void _drawWindingRiver(GridManager grid, int index, {int? minX, int? maxX, int? minY, int? maxY}) {
    final isVertical = _random.nextBool();
    
    // Clamp limits based on bounds or grid size
    final xMin = minX ?? 5;
    final xMax = maxX ?? grid.cols - 6;
    final yMin = minY ?? 5;
    final yMax = maxY ?? grid.rows - 6;

    final startOffset = _random.nextInt(15);
    final amplitude = 2.0 + _random.nextDouble() * 4.0; // Moderate amplitude to stay within bounds
    final frequency = 0.08 + _random.nextDouble() * 0.08;
    final phase = _random.nextDouble() * pi * 2;

    if (isVertical) {
      // Winding vertical river within bounds
      final baseCenterX = xMin + ((xMax - xMin) ~/ 2);
      final centerX = (baseCenterX + startOffset - 7).clamp(xMin, xMax);
      for (int y = (minY ?? 0); y <= (maxY ?? grid.rows - 1); y++) {
        final wx = centerX + (sin(y * frequency + phase) * amplitude).round();
        final width = 1 + _random.nextInt(2);
        for (int dx = -width; dx <= width; dx++) {
          final tx = wx + dx;
          if (grid.isValid(tx, y) && grid.grid[y][tx].isEmpty) {
            grid.grid[y][tx] = GridCell(type: CellType.water);
          }
        }
      }
    } else {
      // Winding horizontal river within bounds
      final baseCenterY = yMin + ((yMax - yMin) ~/ 2);
      final centerY = (baseCenterY + startOffset - 7).clamp(yMin, yMax);
      for (int x = (minX ?? 0); x <= (maxX ?? grid.cols - 1); x++) {
        final wy = centerY + (sin(x * frequency + phase) * amplitude).round();
        final width = 1 + _random.nextInt(2);
        for (int dy = -width; dy <= width; dy++) {
          final ty = wy + dy;
          if (grid.isValid(x, ty) && grid.grid[ty][x].isEmpty) {
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
    if (coverage < 0.04 || coverage > 0.30) return false;
    return true; 
  }

  @override
  void generateExpansion(GridManager grid, int week) {
    if (week % 5 == 0) {
      // Add a river on one side of expansion
      _drawWindingRiver(grid, week, minX: 0, maxX: grid.cols - 1, minY: 0, maxY: grid.rows - 1); 
      _cleanupIsolatedWater(grid);
      grid.detectRegionsEndless();
      grid.applyTerrainSpeeds();
    }
  }

  void _cleanupIsolatedWater(GridManager grid) {
    for (int y = 0; y < grid.rows; y++) {
      for (int x = 0; x < grid.cols; x++) {
        if (grid.grid[y][x].type == CellType.water) {
          int neighbors = 0;
          List<GridPosition> emptyNeighbors = [];
          for (final d in const [[0, -1], [1, 0], [0, 1], [-1, 0]]) {
            final nx = x + d[0];
            final ny = y + d[1];
            if (grid.isValid(nx, ny)) {
              if (grid.grid[ny][nx].type == CellType.water) {
                neighbors++;
              } else if (grid.grid[ny][nx].isEmpty) {
                emptyNeighbors.add(GridPosition(nx, ny));
              }
            }
          }
          if (neighbors == 0) {
            // Isolated single water tile!
            if (emptyNeighbors.isNotEmpty) {
              // Try to grow it by choosing a random empty neighbor
              final target = emptyNeighbors[_random.nextInt(emptyNeighbors.length)];
              grid.grid[target.y][target.x] = GridCell(type: CellType.water);
            } else {
              // If no empty neighbors, just remove the water tile
              grid.grid[y][x] = GridCell();
            }
          }
        }
      }
    }
  }
}
