import 'dart:math';
import '../map_generator.dart';
import '../grid_manager.dart';
import '../../models/grid_cell.dart';

class ZenMapGenerator extends MapGenerator {
  final Random _random = Random();

  @override
  String get name => "ZEN";

  @override
  String get description => "Balanced layout with a central mountain divide.";

  @override
  MapConfig get config => const MapConfig(
    startingRoads: 20,
    startingTunnels: 1,
    startingBridges: 0,
  );

  @override
  void generateInitialTerrain(GridManager grid, {int? minX, int? maxX, int? minY, int? maxY}) {
    // Generate a central mountain spine with gaps
    final centerX = grid.cols ~/ 2;
    
    // Determine bounds for initial spine
    final yMin = minY ?? 0;
    final yMax = maxY ?? grid.rows - 1;

    // Create a spine with gaps every few tiles
    for (int y = yMin; y <= yMax; y++) {
      // 30% chance of a gap (passable)
      if (_random.nextDouble() < 0.3) continue;

      _growBlob(grid, centerX, y, 1 + _random.nextInt(2));
    }

    grid.detectRegionsEndless();
    grid.applyTerrainSpeeds();
  }

  int _growBlob(GridManager grid, int startX, int startY, int targetSize) {
    if (!grid.isValid(startX, startY) || !grid.grid[startY][startX].isEmpty) return 0;

    final cluster = MountainCluster(GridPosition(startX, startY));
    grid.mountainClusters.add(cluster);
    
    List<GridPosition> queue = [GridPosition(startX, startY)];
    _addMountainTile(grid, cluster, startX, startY);
    
    int added = 1;
    while (queue.isNotEmpty && added < targetSize) {
      GridPosition pos = queue.removeAt(_random.nextInt(queue.length));
      final dirs = [Direction.north, Direction.south, Direction.west, Direction.east]..shuffle(_random);
      
      for (var dir in dirs) {
        int nx = pos.x + (dir == Direction.west ? -1 : (dir == Direction.east ? 1 : 0));
        int ny = pos.y + (dir == Direction.north ? -1 : (dir == Direction.south ? 1 : 0));
        
        if (grid.isValid(nx, ny) && grid.grid[ny][nx].isEmpty) {
          _addMountainTile(grid, cluster, nx, ny);
          queue.add(GridPosition(nx, ny));
          added++;
          if (added >= targetSize) break;
        }
      }
    }
    return added;
  }

  void _addMountainTile(GridManager grid, MountainCluster cluster, int x, int y) {
    if (grid.isValid(x, y) && grid.grid[y][x].isEmpty) {
      cluster.cells.add(GridPosition(x, y));
      grid.grid[y][x] = GridCell(type: CellType.mountain);
    }
  }

  @override
  void generateExpansion(GridManager grid, int week) {
    // Occasionally add mountain fragments near the divide
    if (week % 3 == 0) {
      final centerX = grid.cols ~/ 2;
      final rx = centerX + (_random.nextInt(5) - 2);
      final ry = _random.nextInt(grid.rows);
      _growBlob(grid, rx, ry, 2 + _random.nextInt(3));
      grid.detectRegionsEndless();
      grid.applyTerrainSpeeds();
    }
  }
}
