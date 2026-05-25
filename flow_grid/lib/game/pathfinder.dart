import 'dart:math';
import '../models/grid_cell.dart';
import '../models/game_constants.dart';
import 'grid_manager.dart';

class Pathfinder {
  /// A* pathfinding with directed roundabout support and intersection penalties.
  static List<GridPosition>? findPath(
    GridManager grid,
    GridPosition start,
    GridPosition end, {
    double congestionMultiplier = 1.0,
    bool isEmergency = false,
    VehicleType vehicleType = VehicleType.car,
  }) {
    final openSet = _BinaryHeap<_Node>((a, b) => a.f.compareTo(b.f));
    final cameFrom = <String, GridPosition>{};
    final gScore = <String, double>{};
    final closedSet = <String>{};

    final startKey = start.key;

    gScore[startKey] = 0;
    openSet.add(_Node(start, startKey, _heuristic(start, end)));

    while (openSet.isNotEmpty) {
      final current = openSet.removeFirst();

      if (current.pos.x == end.x && current.pos.y == end.y && current.pos.side == null) {
        // print('[PATH] Reachability verified for ${end.x},${end.y}');
        return _reconstructPath(cameFrom, current.pos);
      }

      if (closedSet.contains(current.key)) continue;
      closedSet.add(current.key);

      // --- EXPAND NEIGHBORS ---
      final nextNodes = <GridPosition>[];
      final currentCell = grid.grid[current.pos.y][current.pos.x];

      if (current.pos.side == null) {
        // Normal Road/Building Node
        final neighbors = grid.getNeighbors(current.pos.x, current.pos.y, target: end);
        for (final nPos in neighbors) {
          final nCell = grid.grid[nPos.y][nPos.x];
          if (nCell.type == CellType.smartJunction) {
            // Entering a roundabout: target the specific side node
            if (nPos.y < current.pos.y) {
              nextNodes.add(GridPosition(nPos.x, nPos.y, Direction.south));
            } else if (nPos.y > current.pos.y) {
              nextNodes.add(GridPosition(nPos.x, nPos.y, Direction.north));
            } else if (nPos.x < current.pos.x) {
              nextNodes.add(GridPosition(nPos.x, nPos.y, Direction.east));
            } else if (nPos.x > current.pos.x) {
              nextNodes.add(GridPosition(nPos.x, nPos.y, Direction.west));
            }
          } else {
            // [NEW] One-Way Logic: Only allow moving INTO a one-way tile if the direction matches
            if (nCell.isOneWay) {
              Direction? moveDir;
              if (nPos.x > current.pos.x) {
                moveDir = Direction.east;
              } else if (nPos.x < current.pos.x) {
                moveDir = Direction.west;
              } else if (nPos.y > current.pos.y) {
                moveDir = Direction.south;
              } else if (nPos.y < current.pos.y) {
                moveDir = Direction.north;
              }

              if (moveDir != nCell.oneWayDirection) continue; // Forbidden direction
            }
            nextNodes.add(nPos);
          }
        }
      } else {
        // Roundabout Sub-Node
        // 1. Move to next internal node (Clockwise: N -> E -> S -> W -> N)
        switch (current.pos.side!) {
          case Direction.north: nextNodes.add(GridPosition(current.pos.x, current.pos.y, Direction.east)); break;
          case Direction.east:  nextNodes.add(GridPosition(current.pos.x, current.pos.y, Direction.south)); break;
          case Direction.south: nextNodes.add(GridPosition(current.pos.x, current.pos.y, Direction.west)); break;
          case Direction.west:  nextNodes.add(GridPosition(current.pos.x, current.pos.y, Direction.north)); break;
        }

        // 2. Option to exit to adjacent road/building
        final exitDir = current.pos.side!;
        final neighborPos = current.pos.getNeighbor(exitDir);
        if (grid.isValid(neighborPos.x, neighborPos.y)) {
          // Can exit if there's a connection
          bool hasExit = false;
          if (exitDir == Direction.north && currentCell.connUp) {
            hasExit = true;
          }
          if (exitDir == Direction.east && currentCell.connRight) {
            hasExit = true;
          }
          if (exitDir == Direction.south && currentCell.connDown) {
            hasExit = true;
          }
          if (exitDir == Direction.west && currentCell.connLeft) {
            hasExit = true;
          }

          if (hasExit) {
            nextNodes.add(neighborPos);
          }
        }
      }

      for (final neighbor in nextNodes) {
        final neighborKey = neighbor.key;
        if (closedSet.contains(neighborKey)) continue;
        if (grid.blockedTiles.contains(neighbor)) continue; // Event blockage

        double stepCost = 1.0;
        
        // Diagonal check (only for non-subnodes)
        if (current.pos.side == null && neighbor.side == null) {
          final dx = (neighbor.x - current.pos.x).abs();
          final dy = (neighbor.y - current.pos.y).abs();
          if (dx + dy == 2) stepCost = 1.414;
        }

        final neighborCell = grid.grid[neighbor.y][neighbor.x];
        
        // Smart Junction usage is encouraged
        if (neighbor.side != null) {
          stepCost = 0.25; // Internal junction move is cheap
        } else if (neighborCell.type == CellType.smartJunction) {
          stepCost = 0.5; // Entry cost
        } else if (neighborCell.isRoad) {
          // Terrain speed cost
          if (neighborCell.speedMultiplier < 1.0) {
            stepCost *= 1.0 / neighborCell.speedMultiplier; // Mountain penalty
          } else if (neighborCell.speedMultiplier > 1.0) {
            stepCost *= 1.0 / neighborCell.speedMultiplier; // Express lane bonus
          }
          
          // --- [NEW] Strategic Weighting (Road Hierarchy) ---
          double roadWeight = 1.0;
          if (neighborCell.isExpressLaneNode) {
            roadWeight = 0.4;
          } else if (neighborCell.isHighway || neighborCell.roadLevel == 2) {
             // Trucks LOVE highways
             roadWeight = (vehicleType == VehicleType.truck) ? 0.3 : 0.5;
          } else if (neighborCell.roadLevel == 1) {
            roadWeight = 0.75; // Avenue priority
          }
          else if (neighborCell.isBusLane) {
             // Buses LOVE bus lanes
             roadWeight = (vehicleType == VehicleType.bus) ? 0.4 : 0.9;
          }
          
          // Metro/Rail Filtering
          if (neighborCell.type == CellType.metroTrack || neighborCell.type == CellType.elevatedRail) {
             if (vehicleType != VehicleType.bus && vehicleType != VehicleType.emergency) {
                // Regular cars can't use tracks
                stepCost = 999;
             } else {
                roadWeight = 0.35; // Fast if allowed
             }
          }
          
          // --- [NEW] Dynamic Congestion Weight (Smart AI) ---
          double congestionWeight = 1.0;
          final count = grid.getRoadLoad(neighbor.x, neighbor.y);
          final load = count / (neighborCell.capacity * 1.5);
          
          // Emergency vehicles ignore 90% of congestion
          final impact = (vehicleType == VehicleType.emergency) ? 0.1 : 2.5; 
          congestionWeight = 1.0 + (load * impact * congestionMultiplier);

          stepCost *= roadWeight * congestionWeight;
          
          // Intersection penalty
          final connectionCount = grid.getNeighbors(neighbor.x, neighbor.y, target: end)
              .where((n) => grid.grid[n.y][n.x].isPassable).length;
          if (connectionCount > 2) stepCost += 0.3;
        }

        // Traffic signal cost
        if (neighborCell.hasTrafficLight) {
          // Determine movement direction
          Direction? moveDir;
          if (neighbor.x > current.pos.x) {
            moveDir = Direction.east;
          } else if (neighbor.x < current.pos.x) {
            moveDir = Direction.west;
          } else if (neighbor.y > current.pos.y) {
            moveDir = Direction.south;
          } else if (neighbor.y < current.pos.y) {
            moveDir = Direction.north;
          }
          
          if (moveDir != null && grid.isGreenForDirection(neighbor.x, neighbor.y, moveDir)) {
            stepCost -= 0.15; // Green signal bonus
          } else {
            stepCost += 0.5; // Red signal penalty
          }
        }

        final tentativeG = (gScore[current.key] ?? double.infinity) + stepCost;

        if (tentativeG < (gScore[neighborKey] ?? double.infinity)) {
          cameFrom[neighborKey] = current.pos;
          gScore[neighborKey] = tentativeG;
          final f = tentativeG + _heuristic(neighbor, end);
          openSet.add(_Node(neighbor, neighborKey, f));
        }
      }

      // EXPRESS LANE SHORTCUTS (connectivity, not teleport — cost based on distance)
      if (current.pos.side == null) {
        for (final mw in grid.placedExpressLanes) {
          GridPosition? otherEnd;
          if (mw[0].x == current.pos.x && mw[0].y == current.pos.y) {
            otherEnd = mw[1];
          } else if (mw[1].x == current.pos.x && mw[1].y == current.pos.y) {
            otherEnd = mw[0];
          }

          if (otherEnd != null) {
            final neighborKey = otherEnd.key;
            if (closedSet.contains(neighborKey)) continue;
            if (grid.blockedTiles.contains(otherEnd)) continue; // Event blockage

            final dist = current.pos.manhattanDistance(otherEnd);
            // Express lanes are fast (1.5x) so cost is distance / 1.5
            final stepCost = dist / GameConstants.expressLaneSpeed;

            final tentativeG = (gScore[current.key] ?? double.infinity) + stepCost;
            if (tentativeG < (gScore[neighborKey] ?? double.infinity)) {
              cameFrom[neighborKey] = current.pos;
              gScore[neighborKey] = tentativeG;
              final f = tentativeG + _heuristic(otherEnd, end);
              openSet.add(_Node(otherEnd, neighborKey, f));
            }
          }
        }
      }
    }

    return null;
  }

  static double _heuristic(GridPosition a, GridPosition b) {
    final dx = (a.x - b.x).abs();
    final dy = (a.y - b.y).abs();
    return max(dx, dy) + 0.414 * min(dx, dy);
  }

  static List<GridPosition> _reconstructPath(
    Map<String, GridPosition> cameFrom,
    GridPosition current,
  ) {
    final path = [current];
    while (cameFrom.containsKey(current.key)) {
      current = cameFrom[current.key]!;
      path.add(current);
    }
    return path.reversed.toList();
  }
}

class _BinaryHeap<T> {
  final List<T> _items = [];
  final int Function(T, T) _comparator;

  _BinaryHeap(this._comparator);

  bool get isNotEmpty => _items.isNotEmpty;

  void add(T item) {
    _items.add(item);
    _bubbleUp(_items.length - 1);
  }

  T removeFirst() {
    final first = _items[0];
    final last = _items.removeLast();
    if (_items.isNotEmpty) {
      _items[0] = last;
      _sinkDown(0);
    }
    return first;
  }

  void _bubbleUp(int index) {
    while (index > 0) {
      final parentIndex = (index - 1) >> 1;
      if (_comparator(_items[index], _items[parentIndex]) < 0) {
        _swap(index, parentIndex);
        index = parentIndex;
      } else {
        break;
      }
    }
  }

  void _sinkDown(int index) {
    final length = _items.length;
    while (true) {
      int smallest = index;
      final left = 2 * index + 1;
      final right = 2 * index + 2;

      if (left < length && _comparator(_items[left], _items[smallest]) < 0) smallest = left;
      if (right < length && _comparator(_items[right], _items[smallest]) < 0) smallest = right;

      if (smallest != index) {
        _swap(index, smallest);
        index = smallest;
      } else {
        break;
      }
    }
  }

  void _swap(int a, int b) {
    final temp = _items[a];
    _items[a] = _items[b];
    _items[b] = temp;
  }
}

class _Node {
  final GridPosition pos;
  final String key;
  final double f;
  _Node(this.pos, this.key, this.f);
}
