import 'dart:math';
import '../map_generator.dart';
import '../grid_manager.dart';
import '../../models/grid_cell.dart';

class ArcticMapGenerator extends MapGenerator {
  final Random _random = Random();

  @override
  String get name => "ARCTIC";

  @override
  String get description => "Frozen tundra with ice lakes and rocky ridges.";

  @override
  MapConfig get config => const MapConfig(
    startingRoads: 25,
    startingTunnels: 1,
    startingBridges: 1,
  );

  @override
  void generateInitialTerrain(GridManager grid, {int? minX, int? maxX, int? minY, int? maxY}) {
    _generate(grid, minX: minX, maxX: maxX, minY: minY, maxY: maxY);
  }

  void _generate(GridManager grid, {int? minX, int? maxX, int? minY, int? maxY}) {
    // Clear all terrain
    for (int y = 0; y < grid.rows; y++) {
      for (int x = 0; x < grid.cols; x++) {
        if (grid.grid[y][x].isMountain || grid.grid[y][x].isWater) {
          grid.grid[y][x] = GridCell();
        }
      }
    }

    final xMin = minX ?? 4;
    final xMax = maxX ?? grid.cols - 5;
    final yMin = minY ?? 3;
    final yMax = maxY ?? grid.rows - 4;

    // 1–2 diagonal mountain ridges
    final ridgeCount = 1 + _random.nextInt(2);
    for (int i = 0; i < ridgeCount; i++) {
      _drawDiagonalRidge(grid, xMin, xMax, yMin, yMax);
    }

    // 3–5 ice lakes (water blobs) - larger size for better visibility
    final lakeCount = 3 + _random.nextInt(3);
    for (int i = 0; i < lakeCount; i++) {
      final lx = xMin + _random.nextInt(max(1, xMax - xMin));
      final ly = yMin + _random.nextInt(max(1, yMax - yMin));
      _growBlob(grid, lx, ly, 8 + _random.nextInt(8), CellType.water);
    }

    _cleanupIsolated(grid, CellType.mountain);
    _cleanupIsolated(grid, CellType.water);

    grid.detectRegionsEndless();
    grid.applyTerrainSpeeds();
  }

  void _drawDiagonalRidge(GridManager grid, int xMin, int xMax, int yMin, int yMax) {
    // Pick a start corner and draw a NW→SE or NE→SW ridge
    int sx = xMin + _random.nextInt(max(1, (xMax - xMin) ~/ 2));
    int sy = yMin + _random.nextInt(max(1, (yMax - yMin) ~/ 2));
    final goSE = _random.nextBool();
    final dx = goSE ? 1 : -1;
    final length = 6 + _random.nextInt(10);
    final thickness = 2 + _random.nextInt(2);

    int cx = sx;
    int cy = sy;
    for (int step = 0; step < length; step++) {
      for (int t = -thickness ~/ 2; t <= thickness ~/ 2; t++) {
        final tx = cx + t;
        final ty = cy;
        if (grid.isValid(tx, ty) && grid.grid[ty][tx].isEmpty) {
          grid.grid[ty][tx] = GridCell(type: CellType.mountain);
        }
      }
      // Diagonal: move right (or left) AND down every step
      cx += dx;
      if (step % 2 == 1) cy++;
      if (cy > (grid.rows - 4)) break;
    }
  }

  int _growBlob(GridManager grid, int startX, int startY, int targetSize, CellType type) {
    if (!grid.isValid(startX, startY) || !grid.grid[startY][startX].isEmpty) return 0;
    final queue = <GridPosition>[GridPosition(startX, startY)];
    grid.grid[startY][startX] = GridCell(type: type);
    int added = 1;
    while (queue.isNotEmpty && added < targetSize) {
      final pos = queue.removeAt(_random.nextInt(queue.length));
      final dirs = [[0, -1], [1, 0], [0, 1], [-1, 0]]..shuffle(_random);
      for (final d in dirs) {
        final nx = pos.x + d[0];
        final ny = pos.y + d[1];
        if (grid.isValid(nx, ny) && grid.grid[ny][nx].isEmpty) {
          grid.grid[ny][nx] = GridCell(type: type);
          queue.add(GridPosition(nx, ny));
          added++;
          if (added >= targetSize) break;
        }
      }
    }
    return added;
  }

  void _cleanupIsolated(GridManager grid, CellType type) {
    for (int y = 0; y < grid.rows; y++) {
      for (int x = 0; x < grid.cols; x++) {
        if (grid.grid[y][x].type != type) continue;
        int neighbors = 0;
        final empties = <GridPosition>[];
        for (final d in const [[0, -1], [1, 0], [0, 1], [-1, 0]]) {
          final nx = x + d[0];
          final ny = y + d[1];
          if (!grid.isValid(nx, ny)) continue;
          if (grid.grid[ny][nx].type == type) {
            neighbors++;
          } else if (grid.grid[ny][nx].isEmpty) {
            empties.add(GridPosition(nx, ny));
          }
        }
        if (neighbors == 0) {
          if (empties.isNotEmpty) {
            final t = empties[_random.nextInt(empties.length)];
            grid.grid[t.y][t.x] = GridCell(type: type);
          } else {
            grid.grid[y][x] = GridCell();
          }
        }
      }
    }
  }

  @override
  void generateExpansion(GridManager grid, int week) {
    if (week % 3 == 0) {
      final xMin = 0; final xMax = grid.cols - 1;
      final yMin = 0; final yMax = grid.rows - 1;
      if (_random.nextBool()) {
        _drawDiagonalRidge(grid, xMin, xMax, yMin, yMax);
      } else {
        final lx = _random.nextInt(grid.cols);
        final ly = _random.nextInt(grid.rows);
        _growBlob(grid, lx, ly, 3 + _random.nextInt(5), CellType.water);
      }
      _cleanupIsolated(grid, CellType.mountain);
      _cleanupIsolated(grid, CellType.water);
      grid.detectRegionsEndless();
      grid.applyTerrainSpeeds();
    }
  }
}
