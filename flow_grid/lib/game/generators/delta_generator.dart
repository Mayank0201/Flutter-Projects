import 'dart:math';
import '../map_generator.dart';
import '../grid_manager.dart';
import '../../models/grid_cell.dart';

class DeltaMapGenerator extends MapGenerator {
  final Random _random = Random();

  @override
  String get name => "DELTA";

  @override
  String get description => "River delta with forking waterways radiating from the centre.";

  @override
  MapConfig get config => const MapConfig(
    startingRoads: 25,
    startingTunnels: 0,
    startingBridges: 2,
  );

  @override
  void generateInitialTerrain(GridManager grid, {int? minX, int? maxX, int? minY, int? maxY}) {
    int attempts = 0;
    bool valid = false;
    while (!valid && attempts < 3) {
      _generate(grid, minX: minX, maxX: maxX, minY: minY, maxY: maxY);
      valid = _validate(grid);
      attempts++;
    }
  }

  void _generate(GridManager grid, {int? minX, int? maxX, int? minY, int? maxY}) {
    // Clear water
    for (int y = 0; y < grid.rows; y++) {
      for (int x = 0; x < grid.cols; x++) {
        if (grid.grid[y][x].isWater) {
          grid.grid[y][x] = GridCell();
        }
      }
    }

    final cx = grid.cols ~/ 2;
    final cy = grid.rows ~/ 2;

    // 3–4 river branches radiating outward from centre
    final branchCount = 3 + _random.nextInt(2);

    // Use evenly spaced angles for a spoke-like layout
    for (int b = 0; b < branchCount; b++) {
      final angle = (2 * pi * b) / branchCount + (_random.nextDouble() * 0.4 - 0.2);
      _drawRiverBranch(grid, cx, cy, angle);
    }

    _cleanupIsolatedWater(grid);
    grid.detectRegionsEndless();
    grid.applyTerrainSpeeds();
  }

  void _drawRiverBranch(GridManager grid, int startX, int startY, double angle) {
    final maxLen = min(grid.cols, grid.rows) ~/ 2 - 2;
    final length = maxLen - 2 + _random.nextInt(4);
    final width = 1 + _random.nextInt(2); // 1–2 tiles wide

    // Walk outward from centre in the given angle direction with slight wobble
    double x = startX.toDouble();
    double y = startY.toDouble();
    double curAngle = angle;

    for (int step = 0; step < length; step++) {
      // slight random wobble each step
      curAngle += (_random.nextDouble() - 0.5) * 0.2;
      final dx = cos(curAngle);
      final dy = sin(curAngle);
      x += dx;
      y += dy;

      final ix = x.round();
      final iy = y.round();

      for (int w = -width; w <= width; w++) {
        // Perpendicular offset for width
        final px = (ix + (-sin(curAngle) * w).round()).clamp(0, grid.cols - 1);
        final py = (iy + (cos(curAngle) * w).round()).clamp(0, grid.rows - 1);
        if (grid.isValid(px, py) && grid.grid[py][px].isEmpty) {
          grid.grid[py][px] = GridCell(type: CellType.water);
        }
      }
    }
  }

  bool _validate(GridManager grid) {
    int waterCount = 0;
    for (var row in grid.grid) {
      for (var cell in row) {
        if (cell.isWater) waterCount++;
      }
    }
    final coverage = waterCount / (grid.cols * grid.rows);
    return coverage >= 0.05 && coverage <= 0.30;
  }

  void _cleanupIsolatedWater(GridManager grid) {
    for (int y = 0; y < grid.rows; y++) {
      for (int x = 0; x < grid.cols; x++) {
        if (!grid.grid[y][x].isWater) continue;
        int neighbors = 0;
        final empties = <GridPosition>[];
        for (final d in const [[0, -1], [1, 0], [0, 1], [-1, 0]]) {
          final nx = x + d[0]; final ny = y + d[1];
          if (!grid.isValid(nx, ny)) continue;
          if (grid.grid[ny][nx].isWater) {
            neighbors++;
          } else if (grid.grid[ny][nx].isEmpty) {
            empties.add(GridPosition(nx, ny));
          }
        }
        if (neighbors == 0) {
          if (empties.isNotEmpty) {
            final t = empties[_random.nextInt(empties.length)];
            grid.grid[t.y][t.x] = GridCell(type: CellType.water);
          } else {
            grid.grid[y][x] = GridCell();
          }
        }
      }
    }
  }

  @override
  void generateExpansion(GridManager grid, int week) {
    if (week % 5 == 0) {
      final cx = grid.cols ~/ 2;
      final cy = grid.rows ~/ 2;
      final angle = _random.nextDouble() * 2 * pi;
      _drawRiverBranch(grid, cx, cy, angle);
      _cleanupIsolatedWater(grid);
      grid.detectRegionsEndless();
      grid.applyTerrainSpeeds();
    }
  }
}
