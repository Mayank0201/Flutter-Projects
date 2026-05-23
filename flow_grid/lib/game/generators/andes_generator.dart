import 'dart:math';
import '../map_generator.dart';
import '../grid_manager.dart';
import '../../models/grid_cell.dart';

class AndesMapGenerator extends MapGenerator {
  final Random _random = Random();

  @override
  String get name => "ANDES";

  @override
  String get description => "Unpredictable terrain with scattered mountain ranges.";

  @override
  MapConfig get config => const MapConfig(
    startingRoads: 20,
    startingTunnels: 1,
    startingBridges: 0,
  );

  @override
  void generateInitialTerrain(GridManager grid, {int? minX, int? maxX, int? minY, int? maxY}) {
    int attempts = 0;
    bool valid = false;

    // Cap retries at 2: each retry rebuilds 800+ cells, runs detectRegions,
    // and re-scans for terrain speeds. On mobile this is the difference
    // between a 200ms hitch and a multi-second freeze that the OS sometimes
    // kills as an ANR.
    while (!valid && attempts < 2) {
      _generate(grid, minX: minX, maxX: maxX, minY: minY, maxY: maxY);
      valid = _validate(grid);
      attempts++;
    }
  }

  void _generate(GridManager grid, {int? minX, int? maxX, int? minY, int? maxY}) {
    grid.mountainClusters.clear();
    
    // Clear grid
    for (int y = 0; y < grid.rows; y++) {
      for (int x = 0; x < grid.cols; x++) {
        if (grid.grid[y][x].type == CellType.mountain) {
          grid.grid[y][x] = GridCell();
        }
      }
    }

    // Determine bounds for initial clusters
    final xMin = minX ?? 5;
    final xMax = maxX ?? grid.cols - 6;
    final yMin = minY ?? 3;
    final yMax = maxY ?? grid.rows - 4;

    // Target coverage: ~12% of total grid or at least within visible area
    final totalCells = grid.cols * grid.rows;
    final targetCoverage = (totalCells * 0.12).round();
    int currentCoverage = 0;

    // Andes Terrain: Rugged, fragmented, and naturally chaotic.
    // Instead of one big blob, we want multiple systems and chains.
    // Cluster count scales with grid area so the new 32x24 default doesn't
    // get the same density as the old 64x40 (which choked mobile chunk
    // rasterization once every mountain hit the GPU through MaskFilter.blur).
    final cellsScale = (grid.cols * grid.rows) / (64 * 40);
    final clusterCount = max(4, ((12 + _random.nextInt(8)) * cellsScale).round());
    
    for (int i = 0; i < clusterCount; i++) {
      int cx, cy;
      
      // Chaining Logic: 40% chance to spawn near an existing cluster to form a range
      if (i > 0 && _random.nextDouble() < 0.4 && grid.mountainClusters.isNotEmpty) {
        final parent = grid.mountainClusters[_random.nextInt(grid.mountainClusters.length)];
        final pivot = parent.cells.first;
        cx = (pivot.x + _random.nextInt(11) - 5).clamp(xMin, xMax);
        cy = (pivot.y + _random.nextInt(11) - 5).clamp(yMin, yMax);
      } else {
        cx = xMin + _random.nextInt(max(1, xMax - xMin));
        cy = yMin + _random.nextInt(max(1, yMax - yMin));
      }
      
      final clusterSize = 8 + _random.nextInt(12); // 8-20 cells per cluster
      currentCoverage += _growBlob(grid, cx, cy, clusterSize);
      
      if (currentCoverage >= targetCoverage) break;
    }

    // Fill in extra texture with small isolated clusters
    final extraCount = max(4, ((15 + _random.nextInt(15)) * cellsScale).round());
    for (int i = 0; i < extraCount; i++) {
       final rx = xMin + _random.nextInt(max(1, xMax - xMin));
       final ry = yMin + _random.nextInt(max(1, yMax - yMin));
       if (grid.isValid(rx, ry) && grid.grid[ry][rx].isEmpty) {
          _growBlob(grid, rx, ry, 2 + _random.nextInt(2));
       }
    }

    _cleanupIsolatedMountains(grid);

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
      
      // Shuffle directions for organic growth
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

  bool _validate(GridManager grid) {
    int mountainCount = 0;
    for (var row in grid.grid) {
      for (var cell in row) {
        if (cell.type == CellType.mountain) mountainCount++;
      }
    }
    
    final totalCells = grid.cols * grid.rows;
    final coverage = mountainCount / totalCells;
    
    // Ensure coverage is between 4% and 25% (highly permissive for random generation)
    if (coverage < 0.04 || coverage > 0.25) return false;
    
    // Ensure no complete partition
    for (int x = 0; x < grid.cols; x++) {
      bool columnBlocked = true;
      for (int y = 0; y < grid.rows; y++) {
        if (grid.grid[y][x].type != CellType.mountain) {
          columnBlocked = false;
          break;
        }
      }
      if (columnBlocked) return false;
    }

    return true;
  }

  @override
  void generateExpansion(GridManager grid, int week) {
    // Occasionally add a new cluster during expansion, but far from center
    if (week % 4 == 0) {
      final side = _random.nextBool(); // Left or right
      final x = side ? _random.nextInt(10) : grid.cols - 10;
      final y = _random.nextInt(grid.rows);
      
      _growBlob(grid, x, y, 5 + _random.nextInt(8));
      _cleanupIsolatedMountains(grid);
      grid.detectRegionsEndless();
      grid.applyTerrainSpeeds();
    }
  }

  void _cleanupIsolatedMountains(GridManager grid) {
    for (int y = 0; y < grid.rows; y++) {
      for (int x = 0; x < grid.cols; x++) {
        if (grid.grid[y][x].type == CellType.mountain) {
          int neighbors = 0;
          List<GridPosition> emptyNeighbors = [];
          for (final d in const [[0, -1], [1, 0], [0, 1], [-1, 0]]) {
            final nx = x + d[0];
            final ny = y + d[1];
            if (grid.isValid(nx, ny)) {
              if (grid.grid[ny][nx].type == CellType.mountain) {
                neighbors++;
              } else if (grid.grid[ny][nx].isEmpty) {
                emptyNeighbors.add(GridPosition(nx, ny));
              }
            }
          }
          if (neighbors == 0) {
            // Isolated single mountain tile!
            if (emptyNeighbors.isNotEmpty) {
              // Try to grow it by choosing a random empty neighbor
              final target = emptyNeighbors[_random.nextInt(emptyNeighbors.length)];
              grid.grid[target.y][target.x] = GridCell(type: CellType.mountain);
            } else {
              // If no empty neighbors, just remove the mountain tile
              grid.grid[y][x] = GridCell();
            }
          }
        }
      }
    }
  }
}
