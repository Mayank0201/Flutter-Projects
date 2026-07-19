import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../utils/prefs_keys.dart';
import '../../../utils/audio_manager.dart';
import '../../../widgets/auto_next_countdown.dart';
import '../../../widgets/challenge_cleared_overlay.dart';
import '../../../widgets/fog_overlay.dart';
import '../../../widgets/buy_hints_dialog.dart';
import '../../../utils/hint_manager.dart';
import '../../../widgets/game_tutorial_dialog.dart';

class SumStrikeScreen extends StatefulWidget {
  const SumStrikeScreen({super.key});

  @override
  State<SumStrikeScreen> createState() => _SumStrikeScreenState();
}

class _SumStrikeScreenState extends State<SumStrikeScreen> {
  int _currentLevel = 0;
  bool _isLoading = true;
  bool _isSuccess = false;
  bool _playDailyMode = false;
  String _dailyModifierType = '';
  double _dailyRadius = 1.5;

  late int _gridSize;
  late List<int> _grid;
  late List<bool> _keep; // true: kept, false: struck-out
  late List<int> _rowTargets;
  late List<int> _colTargets;
  late List<bool> _solutionMask; // Pre-calculated solution for hint usage

  int _hintCount = 1;
  bool _isHintShowing = false;
  int _hintIdx = -1;

  @override
  void initState() {
    super.initState();
    _loadProgressAndLevel();
  }

  Future<void> _loadProgressAndLevel() async {
    final prefs = await SharedPreferences.getInstance();
    _hintCount = await HintManager.getHints('sumstrike');
    _playDailyMode = prefs.getBool(PrefsKeys.playDailyMode) ?? false;
    if (_playDailyMode) {
      _dailyModifierType = prefs.getString(PrefsKeys.dailyModifierType) ?? '';
      final extraParamsStr = prefs.getString(PrefsKeys.dailyModifierExtraParams) ?? '';
      if (extraParamsStr.isNotEmpty) {
        try {
          final extraParams = jsonDecode(extraParamsStr) as Map<String, dynamic>;
          if (extraParams.containsKey('radius')) {
            _dailyRadius = (extraParams['radius'] as num).toDouble();
          }
        } catch (_) {}
      }
    } else {
      _dailyModifierType = '';
    }

    int level = prefs.getInt(PrefsKeys.gameLevel('sumstrike')) ?? 0;
    if (mounted) {
      setState(() {
        _currentLevel = level;
        _isLoading = false;
        _generatePuzzle();
      });
    }
  }

  void _generatePuzzle() {
    final rand = Random();
    
    // Easy: 3x3, Medium: 4x4, Hard: 5x5
    if (_currentLevel < 5) {
      _gridSize = 3;
    } else if (_currentLevel < 10) {
      _gridSize = 4;
    } else {
      _gridSize = 5;
    }

    final total = _gridSize * _gridSize;
    _grid = List.generate(total, (_) => rand.nextInt(9) + 1);
    
    List<bool> solution = [];
    do {
      solution = List.generate(total, (_) => rand.nextDouble() > 0.4);
    } while (solution.where((k) => k).length < total * 0.3); // Must keep at least 30% of numbers

    _rowTargets = List.filled(_gridSize, 0);
    _colTargets = List.filled(_gridSize, 0);

    for (int r = 0; r < _gridSize; r++) {
      int rSum = 0;
      for (int c = 0; c < _gridSize; c++) {
        if (solution[r * _gridSize + c]) {
          rSum += _grid[r * _gridSize + c];
        }
      }
      _rowTargets[r] = rSum;
    }

    for (int c = 0; c < _gridSize; c++) {
      int cSum = 0;
      for (int r = 0; r < _gridSize; r++) {
        if (solution[r * _gridSize + c]) {
          cSum += _grid[r * _gridSize + c];
        }
      }
      _colTargets[c] = cSum;
    }

    _keep = List.filled(total, true);
    _solutionMask = solution;
    _isSuccess = false;
    _hintIdx = -1;
    _isHintShowing = false;
  }

  int _rowSum(int r) {
    int s = 0;
    for (int c = 0; c < _gridSize; c++) {
      if (_keep[r * _gridSize + c]) s += _grid[r * _gridSize + c];
    }
    return s;
  }

  int _colSum(int c) {
    int s = 0;
    for (int r = 0; r < _gridSize; r++) {
      if (_keep[r * _gridSize + c]) s += _grid[r * _gridSize + c];
    }
    return s;
  }

  void _toggleCell(int idx) {
    if (_isSuccess) return;
    settingsNotifier.hapticTap();
    setState(() {
      _keep[idx] = !_keep[idx];
    });
  }

  void _checkSolution() {
    bool isValid = true;
    for (int r = 0; r < _gridSize; r++) {
      if (_rowSum(r) != _rowTargets[r]) {
        isValid = false;
        break;
      }
    }
    for (int c = 0; c < _gridSize; c++) {
      if (_colSum(c) != _colTargets[c]) {
        isValid = false;
        break;
      }
    }

    if (isValid) {
      AudioManager.playSuccess();
      settingsNotifier.hapticSuccess();
      _onLevelCleared();
    } else {
      AudioManager.playFail();
      settingsNotifier.hapticError();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sums do not match targets! Check row and column targets.',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _onLevelCleared() async {
    final prefs = await SharedPreferences.getInstance();
    if (!_playDailyMode) {
      int highest = prefs.getInt('beta_level_sumplete') ?? 0;
      if (_currentLevel + 1 > highest) {
        await prefs.setInt('beta_level_sumplete', _currentLevel + 1);
      }
    }
    setState(() => _isSuccess = true);
  }

  void _nextLevel() {
    setState(() {
      _currentLevel++;
      _generatePuzzle();
    });
    final prefs = SharedPreferences.getInstance().then((p) {
      p.setInt(PrefsKeys.gameLevel('sumstrike'), _currentLevel);
    });
  }

  void _showHint() {
    for (int i = 0; i < _keep.length; i++) {
      if (_keep[i] != _solutionMask[i]) {
        setState(() {
          _hintIdx = i;
          _isHintShowing = true;
          _keep[i] = _solutionMask[i]; // Fix it!
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _isHintShowing = false;
              _hintIdx = -1;
            });
          }
        });
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.bgDark,
        body: const Center(child: CircularProgressIndicator(color: AppTheme.dustyMauve)),
      );
    }

    final double screenW = MediaQuery.of(context).size.width;
    final double boardSize = min(screenW - 32, 420.0);
    // Grid size includes targets column/row at the end
    final int viewGridSize = _gridSize + 1;
    final double cellW = boardSize / viewGridSize;

    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text('Sum Strike', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.lightbulb_outline, size: 20, color: context.textMuted),
                Positioned(
                  right: -4,
                  top: -4,
                  child: CircleAvatar(
                    radius: 6,
                    backgroundColor: Colors.amber,
                    child: Text(
                      _hintCount == 0 ? '+' : '$_hintCount',
                      style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
            onPressed: !_isSuccess && !_isHintShowing
                ? () async {
                    if (_hintCount > 0) {
                      _showHint();
                      setState(() => _hintCount--);
                      HintManager.useHint('sumstrike');
                    } else {
                      await BuyHintsDialog.show(
                        context,
                        initialGameId: 'sumstrike',
                        onPurchaseComplete: () async {
                          final newCount = await HintManager.getHints('sumstrike');
                          if (mounted) setState(() => _hintCount = newCount);
                        },
                      );
                    }
                  }
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => GameTutorialDialog.show(context, 'sumstrike', 'Sum Strike'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 8),
            child: Center(
              child: Text(
                _playDailyMode ? 'Challenge' : 'Level ${_currentLevel + 1}',
                style: GoogleFonts.outfit(color: AppTheme.dustyMauve, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.dustyMauve.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Tap cells to strike out numbers. Make rows and columns match targets.',
                            style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.dustyMauve, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 24),
                        RepaintBoundary(
                          child: Container(
                            width: boardSize,
                            height: boardSize,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: context.bgCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: context.textMuted.withAlpha(30)),
                            ),
                            child: FogOverlay(
                              enabled: _playDailyMode && _dailyModifierType == 'fog',
                              radius: cellW * _dailyRadius,
                              child: GridView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: viewGridSize,
                                  crossAxisSpacing: 4,
                                  mainAxisSpacing: 4,
                                ),
                                itemCount: viewGridSize * viewGridSize,
                                itemBuilder: (context, idx) {
                                  int r = idx ~/ viewGridSize;
                                  int c = idx % viewGridSize;

                                  // Bottom-right corner is empty
                                  if (r == _gridSize && c == _gridSize) {
                                    return const SizedBox();
                                  }

                                  // Column Target chip (bottom row)
                                  if (r == _gridSize) {
                                    int target = _colTargets[c];
                                    int sum = _colSum(c);
                                    bool isMatch = sum == target;
                                    bool isOver = sum > target;

                                    return Container(
                                      decoration: BoxDecoration(
                                        color: isMatch
                                            ? const Color(0xFF2E7D32)
                                            : isOver
                                                ? Colors.red.shade900
                                                : Colors.blueGrey.shade900,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$target',
                                          style: GoogleFonts.spaceGrotesk(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  // Row Target chip (right column)
                                  if (c == _gridSize) {
                                    int target = _rowTargets[r];
                                    int sum = _rowSum(r);
                                    bool isMatch = sum == target;
                                    bool isOver = sum > target;

                                    return Container(
                                      decoration: BoxDecoration(
                                        color: isMatch
                                            ? const Color(0xFF2E7D32)
                                            : isOver
                                                ? Colors.red.shade900
                                                : Colors.blueGrey.shade900,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$target',
                                          style: GoogleFonts.spaceGrotesk(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  // Game grid number cells
                                  int gridIdx = r * _gridSize + c;
                                  int val = _grid[gridIdx];
                                  bool keep = _keep[gridIdx];
                                  bool isHintGlow = _hintIdx == gridIdx;

                                  return GestureDetector(
                                    onTap: () => _toggleCell(gridIdx),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      decoration: BoxDecoration(
                                        color: keep ? const Color(0xFF1E2126) : Colors.black38,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isHintGlow
                                              ? Colors.amber
                                              : keep
                                                  ? AppTheme.dustyMauve.withAlpha(80)
                                                  : Colors.transparent,
                                          width: isHintGlow ? 2.5 : 1,
                                        ),
                                        boxShadow: isHintGlow
                                            ? [
                                                BoxShadow(
                                                  color: Colors.amber.withOpacity(0.5),
                                                  blurRadius: 8,
                                                  spreadRadius: 1,
                                                )
                                              ]
                                            : null,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$val',
                                          style: GoogleFonts.spaceGrotesk(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: keep ? Colors.white : Colors.white24,
                                            decoration: keep ? null : TextDecoration.lineThrough,
                                            decorationColor: Colors.red.shade600,
                                            decorationThickness: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.bgCard,
                        foregroundColor: context.textPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: () {
                        setState(() {
                          _keep = List.filled(_keep.length, true);
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset'),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.dustyMauve,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: _checkSolution,
                      icon: const Icon(Icons.check),
                      label: const Text('Check'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isSuccess)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.6),
                child: Center(
                  child: _playDailyMode
                      ? ChallengeClearedOverlay(
                          accentColor: AppTheme.dustyMauve,
                          onComplete: () {
                            Navigator.pop(context, true);
                          },
                        )
                      : Container(
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: context.bgCard,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.emoji_events, color: Colors.amber, size: 64),
                              const SizedBox(height: 16),
                              Text(
                                'Level ${_currentLevel + 1} Cleared!',
                                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
                              ),
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
            ),
        ],
      ),
    );
  }
}
