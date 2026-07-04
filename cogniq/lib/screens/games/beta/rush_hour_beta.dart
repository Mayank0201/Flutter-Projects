import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../widgets/auto_next_countdown.dart';

class RushHourBetaScreen extends StatefulWidget {
  const RushHourBetaScreen({super.key});
  @override
  State<RushHourBetaScreen> createState() => _RushHourBetaScreenState();
}

class Vehicle {
  final String id;
  int row;
  int col;
  final int len;
  final bool isVertical;
  final Color color;

  Vehicle({
    required this.id,
    required this.row,
    required this.col,
    required this.len,
    required this.isVertical,
    required this.color,
  });

  List<int> getOccupiedCells() {
    List<int> cells = [];
    for (int i = 0; i < len; i++) {
      if (isVertical) {
        cells.add((row + i) * 4 + col);
      } else {
        cells.add(row * 4 + (col + i));
      }
    }
    return cells;
  }
}

class _RushHourBetaScreenState extends State<RushHourBetaScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  List<Vehicle> _vehicles = [];

  // Drag states
  double _dragStartX = 0.0;
  double _dragStartY = 0.0;
  int _vehicleStartRow = 0;
  int _vehicleStartCol = 0;

  @override
  void initState() {
    super.initState();
    _loadLevel();
  }

  void _loadLevel() {
    setState(() {
      _isSuccess = false;
      if (_currentLevel == 0) {
        _vehicles = [
          Vehicle(id: 'red', row: 1, col: 0, len: 2, isVertical: false, color: Colors.red),
          Vehicle(id: 'v1', row: 0, col: 2, len: 2, isVertical: true, color: Colors.blue),
          Vehicle(id: 'h1', row: 3, col: 1, len: 2, isVertical: false, color: Colors.green),
        ];
      } else if (_currentLevel == 1) {
        _vehicles = [
          Vehicle(id: 'red', row: 1, col: 0, len: 2, isVertical: false, color: Colors.red),
          Vehicle(id: 'v1', row: 0, col: 2, len: 2, isVertical: true, color: Colors.blue),
          Vehicle(id: 'v2', row: 1, col: 3, len: 2, isVertical: true, color: Colors.orange),
          Vehicle(id: 'h1', row: 3, col: 0, len: 2, isVertical: false, color: Colors.green),
        ];
      } else if (_currentLevel == 2) {
        _vehicles = [
          Vehicle(id: 'red', row: 1, col: 0, len: 2, isVertical: false, color: Colors.red),
          Vehicle(id: 'v1', row: 0, col: 2, len: 2, isVertical: true, color: Colors.blue),
          Vehicle(id: 'v2', row: 2, col: 0, len: 2, isVertical: true, color: Colors.orange),
          Vehicle(id: 'h1', row: 3, col: 1, len: 2, isVertical: false, color: Colors.green),
        ];
      } else if (_currentLevel == 3) {
        _vehicles = [
          Vehicle(id: 'red', row: 1, col: 0, len: 2, isVertical: false, color: Colors.red),
          Vehicle(id: 'v1', row: 0, col: 2, len: 2, isVertical: true, color: Colors.purple),
          Vehicle(id: 'h1', row: 3, col: 1, len: 2, isVertical: false, color: Colors.green),
        ];
      } else if (_currentLevel == 4) {
        _vehicles = [
          Vehicle(id: 'red', row: 1, col: 0, len: 2, isVertical: false, color: Colors.red),
          Vehicle(id: 'v1', row: 0, col: 2, len: 2, isVertical: true, color: Colors.blue),
          Vehicle(id: 'v2', row: 2, col: 3, len: 2, isVertical: true, color: Colors.teal),
          Vehicle(id: 'h1', row: 0, col: 0, len: 2, isVertical: false, color: Colors.orange),
          Vehicle(id: 'h2', row: 3, col: 0, len: 2, isVertical: false, color: Colors.green),
        ];
      } else if (_currentLevel == 5) {
        _vehicles = [
          Vehicle(id: 'red', row: 1, col: 0, len: 2, isVertical: false, color: Colors.red),
          Vehicle(id: 'v1', row: 0, col: 2, len: 2, isVertical: true, color: Colors.blue),
          Vehicle(id: 'h1', row: 3, col: 1, len: 2, isVertical: false, color: Colors.green),
        ];
      } else if (_currentLevel == 6) {
        _vehicles = [
          Vehicle(id: 'red', row: 1, col: 0, len: 2, isVertical: false, color: Colors.red),
          Vehicle(id: 'v1', row: 0, col: 2, len: 2, isVertical: true, color: Colors.blue),
          Vehicle(id: 'v2', row: 1, col: 3, len: 2, isVertical: true, color: Colors.orange),
          Vehicle(id: 'h1', row: 3, col: 0, len: 2, isVertical: false, color: Colors.green),
        ];
      } else if (_currentLevel == 7) {
        _vehicles = [
          Vehicle(id: 'red', row: 1, col: 0, len: 2, isVertical: false, color: Colors.red),
          Vehicle(id: 'v1', row: 0, col: 2, len: 2, isVertical: true, color: Colors.blue),
          Vehicle(id: 'v2', row: 2, col: 0, len: 2, isVertical: true, color: Colors.orange),
          Vehicle(id: 'h1', row: 3, col: 1, len: 2, isVertical: false, color: Colors.green),
        ];
      } else if (_currentLevel == 8) {
        _vehicles = [
          Vehicle(id: 'red', row: 1, col: 0, len: 2, isVertical: false, color: Colors.red),
          Vehicle(id: 'v1', row: 0, col: 2, len: 2, isVertical: true, color: Colors.purple),
          Vehicle(id: 'h1', row: 3, col: 1, len: 2, isVertical: false, color: Colors.green),
        ];
      } else {
        _vehicles = [
          Vehicle(id: 'red', row: 1, col: 0, len: 2, isVertical: false, color: Colors.red),
          Vehicle(id: 'v1', row: 0, col: 2, len: 2, isVertical: true, color: Colors.blue),
          Vehicle(id: 'v2', row: 2, col: 3, len: 2, isVertical: true, color: Colors.teal),
          Vehicle(id: 'h1', row: 0, col: 0, len: 2, isVertical: false, color: Colors.orange),
          Vehicle(id: 'h2', row: 3, col: 0, len: 2, isVertical: false, color: Colors.green),
        ];
      }
    });
  }

  bool _isCellEmpty(int r, int c, String currentVehicleId) {
    if (r < 0 || r >= 4 || c < 0 || c >= 4) return false;
    for (var v in _vehicles) {
      if (v.id == currentVehicleId) continue;
      for (int cell in v.getOccupiedCells()) {
        if (cell == r * 4 + c) return false;
      }
    }
    return true;
  }

  // Check if path is empty between original column and target column
  bool _canSlideToCol(Vehicle v, int targetCol) {
    if (targetCol < 0 || targetCol + v.len > 4) return false;
    int step = targetCol > v.col ? 1 : -1;
    int curr = v.col;
    while (curr != targetCol) {
      curr += step;
      // If moving right, check front of vehicle. If left, check back of vehicle
      int checkCol = step == 1 ? curr + v.len - 1 : curr;
      if (!_isCellEmpty(v.row, checkCol, v.id)) {
        return false;
      }
    }
    return true;
  }

  // Check if path is empty between original row and target row
  bool _canSlideToRow(Vehicle v, int targetRow) {
    if (targetRow < 0 || targetRow + v.len > 4) return false;
    int step = targetRow > v.row ? 1 : -1;
    int curr = v.row;
    while (curr != targetRow) {
      curr += step;
      int checkRow = step == 1 ? curr + v.len - 1 : curr;
      if (!_isCellEmpty(checkRow, v.col, v.id)) {
        return false;
      }
    }
    return true;
  }

  void _onDragStart(DragStartDetails details, Vehicle v) {
    if (_isSuccess) return;
    _dragStartX = details.globalPosition.dx;
    _dragStartY = details.globalPosition.dy;
    _vehicleStartRow = v.row;
    _vehicleStartCol = v.col;
  }

  void _onDragUpdate(DragUpdateDetails details, Vehicle v, double cellSize) {
    if (_isSuccess) return;
    double dx = details.globalPosition.dx - _dragStartX;
    double dy = details.globalPosition.dy - _dragStartY;

    if (v.isVertical) {
      int deltaRow = (dy / cellSize).round();
      int targetRow = _vehicleStartRow + deltaRow;
      targetRow = targetRow.clamp(0, 4 - v.len);
      if (_canSlideToRow(v, targetRow)) {
        if (v.row != targetRow) {
          settingsNotifier.hapticTap();
          setState(() {
            v.row = targetRow;
          });
        }
      }
    } else {
      int deltaCol = (dx / cellSize).round();
      int targetCol = _vehicleStartCol + deltaCol;
      targetCol = targetCol.clamp(0, 4 - v.len);
      if (_canSlideToCol(v, targetCol)) {
        if (v.col != targetCol) {
          settingsNotifier.hapticTap();
          setState(() {
            v.col = targetCol;
          });
        }
      }
    }
  }

  void _onDragEnd(Vehicle v) {
    if (_isSuccess) return;
    // Check win condition
    final redCar = _vehicles.firstWhere((veh) => veh.id == 'red');
    if (redCar.row == 1 && redCar.col == 2) {
      _onLevelCleared();
    }
  }

  void _showHint() {
    setState(() {
      if (_currentLevel == 0 || _currentLevel == 5) {
        _vehicles.firstWhere((v) => v.id == 'red').col = 2;
        _vehicles.firstWhere((v) => v.id == 'v1').row = 2;
        _vehicles.firstWhere((v) => v.id == 'h1').col = 0;
      } else if (_currentLevel == 1 || _currentLevel == 6) {
        _vehicles.firstWhere((v) => v.id == 'red').col = 2;
        _vehicles.firstWhere((v) => v.id == 'v1').row = 2;
        _vehicles.firstWhere((v) => v.id == 'v2').row = 2;
        _vehicles.firstWhere((v) => v.id == 'h1').col = 0;
      } else if (_currentLevel == 2 || _currentLevel == 7) {
        _vehicles.firstWhere((v) => v.id == 'red').col = 2;
        _vehicles.firstWhere((v) => v.id == 'v1').row = 2;
        _vehicles.firstWhere((v) => v.id == 'v2').row = 0;
        _vehicles.firstWhere((v) => v.id == 'h1').col = 0;
      } else if (_currentLevel == 3 || _currentLevel == 8) {
        _vehicles.firstWhere((v) => v.id == 'red').col = 2;
        _vehicles.firstWhere((v) => v.id == 'v1').row = 2;
        _vehicles.firstWhere((v) => v.id == 'h1').col = 0;
      } else {
        _vehicles.firstWhere((v) => v.id == 'red').col = 2;
        _vehicles.firstWhere((v) => v.id == 'v1').row = 2;
        _vehicles.firstWhere((v) => v.id == 'v2').row = 2;
        _vehicles.firstWhere((v) => v.id == 'h1').col = 0;
        _vehicles.firstWhere((v) => v.id == 'h2').col = 0;
      }
      _onLevelCleared();
    });
  }

  Future<void> _onLevelCleared() async {
    final prefs = await SharedPreferences.getInstance();
    int highest = prefs.getInt('beta_level_rushhour') ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt('beta_level_rushhour', _currentLevel + 1);
    }
    setState(() => _isSuccess = true);
  }

  void _nextLevel() {
    if (_currentLevel < 9) {
      setState(() {
        _currentLevel++;
        _loadLevel();
      });
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text('Block Escape', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.lightbulb_outline, color: AppTheme.dustyMauve),
            tooltip: 'Hint',
            onPressed: _showHint,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text('Level ${_currentLevel + 1}/10', style: AppTheme.numberStyle(color: AppTheme.dustyMauve, fontSize: 14, fontWeight: FontWeight.bold))),
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Slide blocking vehicles out of the way. Slide the RED car to the right exit.', style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary), textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        // Layout container with exit indicator
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RepaintBoundary(
                              child: Container(
                                width: 240, height: 240,
                                decoration: BoxDecoration(color: context.bgCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.textMuted.withAlpha(40))),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    double cs = constraints.maxWidth / 4;
                                    return Stack(
                                      children: [
                                        // Grid lines background
                                        for (int i = 1; i < 4; i++) ...[
                                          Positioned(left: i * cs, top: 0, bottom: 0, child: Container(width: 1, color: Colors.grey.shade900)),
                                          Positioned(top: i * cs, left: 0, right: 0, child: Container(height: 1, color: Colors.grey.shade900)),
                                        ],
                                        // Vehicles
                                        for (var v in _vehicles)
                                          Positioned(
                                            left: v.col * cs,
                                            top: v.row * cs,
                                            width: v.isVertical ? cs : cs * v.len,
                                            height: v.isVertical ? cs * v.len : cs,
                                            child: GestureDetector(
                                              onPanStart: (d) => _onDragStart(d, v),
                                              onPanUpdate: (d) => _onDragUpdate(d, v, cs),
                                              onPanEnd: (_) => _onDragEnd(v),
                                              child: Container(
                                                margin: const EdgeInsets.all(3),
                                                decoration: BoxDecoration(
                                                  color: v.color,
                                                  borderRadius: BorderRadius.circular(12),
                                                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                                                ),
                                                child: Center(
                                                  child: Icon(
                                                    v.id == 'red' ? Icons.star : Icons.directions_car,
                                                    color: Colors.white,
                                                    size: 24,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  }
                                ),
                              ),
                            ),
                            // Exit gate arrow
                            Container(
                              width: 30, height: 240,
                              alignment: Alignment.center,
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(height: 60), // Skip row 0
                                  Icon(Icons.arrow_forward, color: Colors.green, size: 24),
                                  SizedBox(height: 120), // Skip rows 2 and 3
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: context.bgCard, foregroundColor: context.textPrimary),
                      onPressed: _loadLevel, icon: const Icon(Icons.refresh), label: const Text('Reset'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isSuccess)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: context.bgCard, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.emoji_events, color: Colors.amber, size: 64),
                      const SizedBox(height: 16),
                      Text('Level ${_currentLevel + 1} Cleared!', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      AutoNextCountdown(
                        onNext: _nextLevel,
                        accentColor: AppTheme.dustyMauve,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
