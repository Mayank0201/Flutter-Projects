import 'dart:math';
import '../map_generator.dart';
import '../grid_manager.dart';
import '../../models/grid_cell.dart';

class SavannaMapGenerator extends MapGenerator {
  final Random _random = Random();

  @override
  String get name => "SAVANNA";

  @override
  String get description => "Open grasslands divided by wide horizontal mountain ridges.";

  @override
  MapConfig get config => const MapConfig(
    startingRoads: 25,
    startingTunnels: 2,
    startingBridges: 0,
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
    // Clear all mountains
    for (int y = 0; y < grid.rows; y++) {
      for (int x = 0; x < grid.cols; x++) {
        if (grid.grid[y][x].isMountain) {
          grid.grid[y][x] = GridCell();
        }
      }
    }

    final xMin = minX ?? 0;
    final xMax = maxX ?? grid.cols - 1;
    final yMin = minY ?? 3;
    final yMax = maxY ?? grid.rows - 4;
    final height = yMax - yMin;

    // 2–3 horizontal bands evenly spaced vertically
    final bandCount = 2 + _random.nextInt(2);
    final spacing = height ~/ (bandCount + 1);

    for (int b = 1; b <= bandCount; b++) {
      final bandY = yMin + b * spacing + (_random.nextInt(3) - 1);
      final bandH = 2 + _random.nextInt(3); // 2–4 tiles tall
      _drawHorizontalBand(grid, xMin, xMax, bandY, bandH);
    }

    grid.detectRegionsEndless();
    grid.applyTerrainSpeeds();
  }

  /// Draw a near-full-width horizontal mountain band from xMin to xMax.
  /// Leaves 1–2 natural gaps (1 tile wide) in the band so the map isn't
  /// completely impassable without tunnels — but these gaps are intentionally
  /// narrow enough to be hard to use.
  void _drawHorizontalBand(GridManager grid, int xMin, int xMax, int bandY, int bandH) {
    // Decide gap positions (1–2 gaps of width 1)
    final gapCount = 1 + _random.nextInt(2);
    final gapPositions = <int>{};
    final bandWidth = xMax - xMin + 1;
    for (int g = 0; g < gapCount; g++) {
      gapPositions.add(xMin + 1 + _random.nextInt(max(1, bandWidth - 2)));
    }

    for (int x = xMin; x <= xMax; x++) {
      if (gapPositions.contains(x)) continue; // leave a gap
      for (int dy = 0; dy < bandH; dy++) {
        final ty = bandY + dy;
        if (grid.isValid(x, ty) && grid.grid[ty][x].isEmpty) {
          grid.grid[ty][x] = GridCell(type: CellType.mountain);
        }
      }
    }
  }

  bool _validate(GridManager grid) {
    int mountainCount = 0;
    for (var row in grid.grid) {
      for (var cell in row) {
        if (cell.isMountain) mountainCount++;
      }
    }
    final coverage = mountainCount / (grid.cols * grid.rows);
    // Ensure coverage is between 4% and 22%
    if (coverage < 0.04 || coverage > 0.22) return false;
    // No column completely blocked
    for (int x = 0; x < grid.cols; x++) {
      bool blocked = true;
      for (int y = 0; y < grid.rows; y++) {
        if (!grid.grid[y][x].isMountain) { blocked = false; break; }
      }
      if (blocked) return false;
    }
    return true;
  }

  @override
  void generateExpansion(GridManager grid, int week) {
    if (week % 4 == 0) {
      // Add a new band near the edges on expansion
      final y = _random.nextBool()
          ? _random.nextInt(5)
          : grid.rows - 5 + _random.nextInt(5);
      _drawHorizontalBand(grid, 0, grid.cols - 1, y, 2 + _random.nextInt(2));
      grid.detectRegionsEndless();
      grid.applyTerrainSpeeds();
    }
  }
}
