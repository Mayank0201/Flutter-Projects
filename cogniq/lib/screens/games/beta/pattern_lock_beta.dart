import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../widgets/auto_next_countdown.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

class PatternLockBetaScreen extends StatefulWidget {
  const PatternLockBetaScreen({super.key});
  @override
  State<PatternLockBetaScreen> createState() => _PatternLockBetaScreenState();
}

class _PatternLockBetaScreenState extends State<PatternLockBetaScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  List<int> _targetPattern = [0, 4, 8];
  List<int> _userPattern = [];
  bool _isMemorizing = true;
  Timer? _memorizeTimer;

  // For live drag line tracking
  final ValueNotifier<Offset?> _dragPositionNotifier = ValueNotifier<Offset?>(null);

  @override
  void initState() {
    super.initState();
    _loadLevel();
  }

  void _loadLevel() {
    _memorizeTimer?.cancel();
    _dragPositionNotifier.value = null;
    setState(() {
      _isSuccess = false;
      _userPattern = [];
      _isMemorizing = true;
      if (_currentLevel == 0) {
        _targetPattern = [0, 4, 8];
      } else if (_currentLevel == 1) {
        _targetPattern = [1, 4, 7];
      } else if (_currentLevel == 2) {
        _targetPattern = [2, 4, 6];
      } else if (_currentLevel == 3) {
        _targetPattern = [0, 1, 2, 5];
      } else if (_currentLevel == 4) {
        _targetPattern = [3, 4, 5, 8];
      } else if (_currentLevel == 5) {
        _targetPattern = [0, 3, 6, 7, 8];
      } else if (_currentLevel == 6) {
        _targetPattern = [2, 5, 8, 7, 6];
      } else if (_currentLevel == 7) {
        _targetPattern = [0, 1, 2, 4, 6];
      } else if (_currentLevel == 8) {
        _targetPattern = [2, 4, 6, 3, 0];
      } else {
        _targetPattern = [0, 1, 2, 5, 8, 7, 6, 3, 4];
      }
    });

    _memorizeTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isMemorizing = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _memorizeTimer?.cancel();
    _dragPositionNotifier.dispose();
    super.dispose();
  }

  Future<void> _onLevelCleared() async {
    final prefs = await SharedPreferences.getInstance();
    int highest = prefs.getInt('beta_level_patternlock') ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt('beta_level_patternlock', _currentLevel + 1);
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

  void _showHint() {
    if (_isSuccess) return;
    _dragPositionNotifier.value = null;
    setState(() {
      _userPattern = [];
      _isMemorizing = true;
    });
    _memorizeTimer?.cancel();
    _memorizeTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isMemorizing = false;
        });
      }
    });
  }

  // Get dot index based on local coordinate
  int _getHitDot(Offset localPos) {
    for (int idx = 0; idx < 9; idx++) {
      double cx = 40.0 + (idx % 3) * 80.0;
      double cy = 40.0 + (idx ~/ 3) * 80.0;
      double dist = (localPos - Offset(cx, cy)).distance;
      if (dist < 24.0) {
        return idx;
      }
    }
    return -1;
  }

  void _onPanStart(DragStartDetails d) {
    if (_isMemorizing || _isSuccess) return;
    final idx = _getHitDot(d.localPosition);
    if (idx != -1) {
      settingsNotifier.hapticTap();
      setState(() {
        _userPattern = [idx];
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_isMemorizing || _isSuccess) return;
    _dragPositionNotifier.value = d.localPosition;

    final idx = _getHitDot(d.localPosition);
    if (idx != -1 && !_userPattern.contains(idx)) {
      settingsNotifier.hapticTap();
      setState(() {
        _userPattern.add(idx);
      });
    }
  }

  void _onPanEnd(DragEndDetails d) {
    if (_isMemorizing || _isSuccess) return;
    _dragPositionNotifier.value = null;

    if (_userPattern.isEmpty) return;

    // Accept any drawing order — set equality
    final userSet = _userPattern.toSet();
    final targetSet = _targetPattern.toSet();
    bool win = userSet.length == targetSet.length && userSet.containsAll(targetSet);

    if (win) {
      _onLevelCleared();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect pattern! Try again.')));
      setState(() {
        _userPattern = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text('Pattern Lock', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.lightbulb_outline, color: AppTheme.dustyMauve),
            tooltip: 'Show Pattern Again',
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
                        Text(
                          _isMemorizing ? 'Memorize the highlighted pattern...' : 'Trace the pattern from memory!',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _isMemorizing ? Colors.amber : context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        RepaintBoundary(
                          child: GestureDetector(
                            onPanStart: _onPanStart,
                            onPanUpdate: _onPanUpdate,
                            onPanEnd: _onPanEnd,
                            child: Container(
                              width: 240, height: 240,
                              decoration: BoxDecoration(color: context.bgCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.textMuted.withAlpha(40))),
                              child: Stack(
                                children: [
                                  CustomPaint(
                                    size: const Size(240, 240),
                                    painter: PatternPainter(
                                      pattern: _isMemorizing ? _targetPattern : _userPattern,
                                      lineColor: _isMemorizing ? Colors.amber.withOpacity(0.6) : AppTheme.dustyMauve,
                                      dragPositionNotifier: _dragPositionNotifier,
                                    ),
                                  ),
                                  for (int idx = 0; idx < 9; idx++)
                                    Positioned(
                                      left: 40.0 + (idx % 3) * 80.0 - 20.0,
                                      top: 40.0 + (idx ~/ 3) * 80.0 - 20.0,
                                      child: IgnorePointer(
                                        child: Container(
                                          width: 40, height: 40,
                                          color: Colors.transparent,
                                          child: Center(
                                            child: Builder(
                                              builder: (context) {
                                                bool isHighlighted = _isMemorizing
                                                    ? _targetPattern.contains(idx)
                                                    : _userPattern.contains(idx);
                                                Color dotColor = isHighlighted
                                                    ? (_isMemorizing ? Colors.amber : AppTheme.dustyMauve)
                                                    : context.textMuted.withOpacity(0.3);
                                                return AnimatedContainer(
                                                  duration: const Duration(milliseconds: 200),
                                                  width: isHighlighted ? 20 : 12,
                                                  height: isHighlighted ? 20 : 12,
                                                  decoration: BoxDecoration(
                                                    color: dotColor,
                                                    shape: BoxShape.circle,
                                                    boxShadow: isHighlighted
                                                        ? [BoxShadow(color: dotColor.withOpacity(0.5), blurRadius: 8, spreadRadius: 2)]
                                                        : [],
                                                  ),
                                                );
                                              }
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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

class PatternPainter extends CustomPainter {
  final List<int> pattern;
  final Color lineColor;
  final ValueNotifier<Offset?> dragPositionNotifier;

  PatternPainter({
    required this.pattern,
    required this.lineColor,
    required this.dragPositionNotifier,
  }) : super(repaint: dragPositionNotifier);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // 1. Draw connections between completed dots
    if (pattern.length >= 2) {
      for (int i = 0; i < pattern.length - 1; i++) {
        int a = pattern[i];
        int b = pattern[i + 1];
        
        double x1 = 40.0 + (a % 3) * 80.0;
        double y1 = 40.0 + (a ~/ 3) * 80.0;
        double x2 = 40.0 + (b % 3) * 80.0;
        double y2 = 40.0 + (b ~/ 3) * 80.0;
        
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
      }
    }

    // 2. Draw live line from last dot to current drag position
    final dragOffset = dragPositionNotifier.value;
    if (dragOffset != null && pattern.isNotEmpty) {
      int lastIdx = pattern.last;
      double x1 = 40.0 + (lastIdx % 3) * 80.0;
      double y1 = 40.0 + (lastIdx ~/ 3) * 80.0;
      canvas.drawLine(Offset(x1, y1), dragOffset, paint);
    }
  }

  @override
  bool shouldRepaint(covariant PatternPainter oldDelegate) {
    return !listEquals(oldDelegate.pattern, pattern) ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.dragPositionNotifier != dragPositionNotifier;
  }
}
