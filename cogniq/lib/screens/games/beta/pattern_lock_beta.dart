import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../widgets/auto_next_countdown.dart';
import '../../../widgets/challenge_cleared_overlay.dart';
import '../../../utils/ad_manager.dart';
import '../../../utils/audio_manager.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

class PatternLockBetaScreen extends StatefulWidget {
  const PatternLockBetaScreen({super.key});
  @override
  State<PatternLockBetaScreen> createState() => _PatternLockBetaScreenState();
}

class _PatternLockBetaScreenState extends State<PatternLockBetaScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  bool _playDailyMode = false;
  List<int> _targetPattern = [];
  List<int> _userPattern = [];
  bool _isMemorizing = true;
  Timer? _memorizeTimer;

  final ValueNotifier<Offset?> _dragPositionNotifier = ValueNotifier<Offset?>(null);
  static const double _boardSize = 260;

  int get _gridN {
    if (_currentLevel < 5) return 3;
    if (_currentLevel < 10) return 4;
    return 5;
  }
  double get _spacing => _boardSize / _gridN;

  Offset _dotCenter(int idx) => Offset(
        _spacing * (idx % _gridN) + _spacing / 2,
        _spacing * (idx ~/ _gridN) + _spacing / 2,
      );

  @override
  void initState() {
    super.initState();
    _initLevelState();
  }

  Future<void> _initLevelState() async {
    final prefs = await SharedPreferences.getInstance();
    _playDailyMode = prefs.getBool('play_daily_mode') ?? false;
    final savedLvl = prefs.getInt('level_pattern_lock') ?? 0;
    if (mounted) {
      setState(() {
        _currentLevel = _playDailyMode ? (savedLvl % 10) : savedLvl;
        _loadLevel();
      });
    }
  }

  @override
  void dispose() {
    _memorizeTimer?.cancel();
    super.dispose();
  }

  void _loadLevel() {
    _memorizeTimer?.cancel();
    _dragPositionNotifier.value = null;
    setState(() {
      _isSuccess = false;
      _userPattern = [];
      _isMemorizing = true;
      
      final n = _gridN;
      final rng = Random(_currentLevel * 137 + 42);
      
      int targetLength = 3 + (_currentLevel ~/ 2);
      targetLength = targetLength.clamp(3, n * n);

      List<int> pattern = [];
      int curr = rng.nextInt(n * n);
      pattern.add(curr);

      int attempts = 0;
      while (pattern.length < targetLength && attempts < 1000) {
        attempts++;
        int r = curr ~/ n;
        int c = curr % n;

        List<int> neighbors = [];
        if (r > 0) neighbors.add((r - 1) * n + c);
        if (r < n - 1) neighbors.add((r + 1) * n + c);
        if (c > 0) neighbors.add(r * n + c - 1);
        if (c < n - 1) neighbors.add(r * n + c + 1);

        // Filter already visited
        neighbors.removeWhere((idx) => pattern.contains(idx));

        if (neighbors.isEmpty) {
          // Backtrack or restart random walk
          pattern = [rng.nextInt(n * n)];
          curr = pattern.first;
          continue;
        }

        int next = neighbors[rng.nextInt(neighbors.length)];
        pattern.add(next);
        curr = next;
      }

      _targetPattern = pattern;
      
      // Proportional memorization duration based on pattern length (0.6s per dot)
      double durationSeconds = max(1.5, targetLength * 0.6);
      
      _memorizeTimer = Timer(Duration(milliseconds: (durationSeconds * 1000).toInt()), () {
        if (mounted) {
          setState(() {
            _isMemorizing = false;
          });
        }
      });
    });
  }

  int _getHitDot(Offset localPos) {
    final total = _gridN * _gridN;
    final hitRadius = _spacing * 0.35;
    for (int idx = 0; idx < total; idx++) {
      double dist = (localPos - _dotCenter(idx)).distance;
      if (dist < hitRadius) {
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
    if (idx != -1) {
      if (!_userPattern.contains(idx)) {
        settingsNotifier.hapticTap();
        setState(() {
          _userPattern.add(idx);
        });
      } else if (_userPattern.length >= 2 && idx == _userPattern[_userPattern.length - 2]) {
        settingsNotifier.hapticTap();
        setState(() {
          _userPattern.removeLast();
        });
      }
    }
  }

  void _onPanEnd(DragEndDetails d) {
    if (_isMemorizing || _isSuccess) return;
    _dragPositionNotifier.value = null;

    if (_userPattern.isEmpty) return;

    // Order independent pattern matching (forward or backward draw sequence)
    bool win = listEquals(_userPattern, _targetPattern) || 
               listEquals(_userPattern, _targetPattern.reversed.toList());

    if (win) {
      _onLevelCleared();
    } else {
      AudioManager.playFail();
      settingsNotifier.hapticError();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Incorrect pattern sequence! Try again.'),
        backgroundColor: Colors.redAccent,
      ));
      setState(() {
        _userPattern = [];
      });
    }
  }

  Future<void> _onLevelCleared() async {
    AudioManager.playSuccess();
    settingsNotifier.hapticSuccess();

    final prefs = await SharedPreferences.getInstance();
    final key = 'level_pattern_lock';
    int highest = prefs.getInt(key) ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt(key, _currentLevel + 1);
    }

    int newLevel = _currentLevel + 1;
    if (newLevel == 15 || newLevel == 30 || newLevel == 40 || newLevel == 50) {
      AdManager.showInterstitialAd();
    }

    setState(() {
      _isSuccess = true;
    });
  }

  void _nextLevel() {
    setState(() {
      _currentLevel++;
      _loadLevel();
    });
  }

  void _showHint() {
    settingsNotifier.hapticTap();
    // Reset memorization to show target pattern again
    _memorizeTimer?.cancel();
    setState(() {
      _isMemorizing = true;
      _userPattern = [];
    });
    
    double durationSeconds = max(1.5, _targetPattern.length * 0.6);
    _memorizeTimer = Timer(Duration(milliseconds: (durationSeconds * 1000).toInt()), () {
      if (mounted) {
        setState(() {
          _isMemorizing = false;
        });
      }
    });
  }

  void _showRules() {
    settingsNotifier.hapticTap();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: context.textMuted.withAlpha(40)),
        ),
        title: Text(
          'How to Play',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary),
        ),
        content: Text(
          '• Memorize the highlighted path connecting the dots.\n• Trace the pattern from either end.\n• Swipe from dot to dot without lifting your finger.',
          style: GoogleFonts.outfit(color: context.textSecondary, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Got it',
              style: GoogleFonts.outfit(color: AppTheme.dustyMauve, fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
    );
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
            icon: const Icon(Icons.help_outline, color: AppTheme.dustyMauve),
            tooltip: 'Rules',
            onPressed: _showRules,
          ),
          IconButton(
            icon: const Icon(Icons.lightbulb_outline, color: AppTheme.dustyMauve),
            tooltip: 'Show Pattern Again',
            onPressed: _showHint,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Level ${_currentLevel + 1}', 
                style: AppTheme.numberStyle(
                  color: AppTheme.dustyMauve, 
                  fontSize: 14, 
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 36),
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
                              width: _boardSize, height: _boardSize,
                              decoration: BoxDecoration(
                                color: context.bgCard, 
                                borderRadius: BorderRadius.circular(16), 
                                border: Border.all(color: context.textMuted.withAlpha(40)),
                              ),
                              child: Stack(
                                children: [
                                  CustomPaint(
                                    size: const Size(_boardSize, _boardSize),
                                    painter: PatternPainter(
                                      pattern: _isMemorizing ? _targetPattern : _userPattern,
                                      lineColor: _isMemorizing ? Colors.amber.withOpacity(0.6) : AppTheme.dustyMauve,
                                      dragPositionNotifier: _dragPositionNotifier,
                                      gridN: _gridN,
                                      spacing: _spacing,
                                    ),
                                  ),
                                  for (int idx = 0; idx < _gridN * _gridN; idx++)
                                    Positioned(
                                      left: _dotCenter(idx).dx - 20.0,
                                      top: _dotCenter(idx).dy - 20.0,
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
                        const SizedBox(height: 36),
                        if (_isSuccess && !_playDailyMode)
                          AutoNextCountdown(
                            onNext: _nextLevel,
                            accentColor: AppTheme.dustyMauve,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isSuccess && _playDailyMode)
            Positioned.fill(
              child: ChallengeClearedOverlay(
                accentColor: AppTheme.dustyMauve,
                onComplete: () {
                  Navigator.pop(context, true);
                },
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
  final int gridN;
  final double spacing;

  PatternPainter({
    required this.pattern,
    required this.lineColor,
    required this.dragPositionNotifier,
    required this.gridN,
    required this.spacing,
  }) : super(repaint: dragPositionNotifier);

  Offset _center(int idx) => Offset(
        spacing * (idx % gridN) + spacing / 2,
        spacing * (idx ~/ gridN) + spacing / 2,
      );

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (pattern.length >= 2) {
      for (int i = 0; i < pattern.length - 1; i++) {
        canvas.drawLine(_center(pattern[i]), _center(pattern[i + 1]), paint);
      }
    }

    final dragOffset = dragPositionNotifier.value;
    if (dragOffset != null && pattern.isNotEmpty) {
      canvas.drawLine(_center(pattern.last), dragOffset, paint);
    }
  }

  @override
  bool shouldRepaint(covariant PatternPainter oldDelegate) {
    return !listEquals(oldDelegate.pattern, pattern) ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridN != gridN ||
        oldDelegate.spacing != spacing ||
        oldDelegate.dragPositionNotifier != dragPositionNotifier;
  }
}
