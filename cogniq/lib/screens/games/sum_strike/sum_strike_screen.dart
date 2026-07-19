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
  final Set<int> _wrongTaps = {};

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
    if (!_playDailyMode && _currentLevel >= 50) {
      return;
    }
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
    _rowTargets = List.filled(_gridSize, 0);
    _colTargets = List.filled(_gridSize, 0);

    bool generated = false;

    // Try up to 50 attempts to find a uniquely solvable puzzle
    for (int attempt = 0; attempt < 50; attempt++) {
      _grid = List.generate(total, (_) => rand.nextInt(9) + 1);
      
      List<bool> solution = [];
      int retries = 0;
      do {
        solution = List.generate(total, (_) => rand.nextDouble() > 0.4);
        retries++;
      } while (solution.where((k) => k).length < total * 0.3 && retries < 20);

      // Compute targets for this candidate solution
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

      // Check uniqueness of solution using backtracking
      final tempKeep = List.filled(total, false);
      final solutions = _countSumStrikeSolutions(0, tempKeep, 2);
      if (solutions == 1) {
        _solutionMask = solution;
        generated = true;
        break;
      }
    }

    // Fallback if no unique board found after 50 attempts
    if (!generated) {
      _grid = List.generate(total, (_) => rand.nextInt(9) + 1);
      List<bool> solution = [];
      int retries = 0;
      do {
        solution = List.generate(total, (_) => rand.nextDouble() > 0.4);
        retries++;
      } while (solution.where((k) => k).length < total * 0.3 && retries < 20);

      for (int r = 0; r < _gridSize; r++) {
        int rSum = 0;
        for (int c = 0; c < _gridSize; c++) {
          if (solution[r * _gridSize + c]) rSum += _grid[r * _gridSize + c];
        }
        _rowTargets[r] = rSum;
      }
      for (int c = 0; c < _gridSize; c++) {
        int cSum = 0;
        for (int r = 0; r < _gridSize; r++) {
          if (solution[r * _gridSize + c]) cSum += _grid[r * _gridSize + c];
        }
        _colTargets[c] = cSum;
      }
      _solutionMask = solution;
    }

    _keep = List.filled(total, true);
    _isSuccess = false;
    _hintIdx = -1;
    _isHintShowing = false;
    _wrongTaps.clear();
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

  bool _isSumStrikePartialValid(int cellIdx, List<bool> tempKeep) {
    for (int r = 0; r < _gridSize; r++) {
      int determinedKeptSum = 0;
      int undeterminedMaxSum = 0;
      for (int c = 0; c < _gridSize; c++) {
        int idx = r * _gridSize + c;
        if (idx <= cellIdx) {
          if (tempKeep[idx]) determinedKeptSum += _grid[idx];
        } else {
          undeterminedMaxSum += _grid[idx];
        }
      }
      if (determinedKeptSum > _rowTargets[r]) return false;
      if (determinedKeptSum + undeterminedMaxSum < _rowTargets[r]) return false;
    }

    for (int c = 0; c < _gridSize; c++) {
      int determinedKeptSum = 0;
      int undeterminedMaxSum = 0;
      for (int r = 0; r < _gridSize; r++) {
        int idx = r * _gridSize + c;
        if (idx <= cellIdx) {
          if (tempKeep[idx]) determinedKeptSum += _grid[idx];
        } else {
          undeterminedMaxSum += _grid[idx];
        }
      }
      if (determinedKeptSum > _colTargets[c]) return false;
      if (determinedKeptSum + undeterminedMaxSum < _colTargets[c]) return false;
    }

    return true;
  }

  int _countSumStrikeSolutions(int cellIdx, List<bool> tempKeep, int maxSolutions) {
    if (cellIdx >= _grid.length) return 1;

    int solutionsCount = 0;

    tempKeep[cellIdx] = false;
    if (_isSumStrikePartialValid(cellIdx, tempKeep)) {
      solutionsCount += _countSumStrikeSolutions(cellIdx + 1, tempKeep, maxSolutions);
      if (solutionsCount >= maxSolutions) return solutionsCount;
    }

    tempKeep[cellIdx] = true;
    if (_isSumStrikePartialValid(cellIdx, tempKeep)) {
      solutionsCount += _countSumStrikeSolutions(cellIdx + 1, tempKeep, maxSolutions);
      if (solutionsCount >= maxSolutions) return solutionsCount;
    }

    return solutionsCount;
  }

  void _toggleCell(int idx) {
    if (_isSuccess || !_keep[idx] || _wrongTaps.contains(idx)) return;

    if (_solutionMask[idx] == false) {
      // Correct: the number should be struck out/deleted!
      settingsNotifier.hapticTap();
      setState(() {
        _keep[idx] = false;
      });
      _tryAutoCheck();
    } else {
      // Incorrect: the number should be kept!
      AudioManager.playFail();
      settingsNotifier.hapticError();
      setState(() {
        _wrongTaps.add(idx);
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _wrongTaps.remove(idx);
          });
        }
      });
    }
  }

  void _tryAutoCheck() {
    bool allMatched = true;
    for (int r = 0; r < _gridSize; r++) {
      if (_rowSum(r) != _rowTargets[r]) {
        allMatched = false;
        break;
      }
    }
    if (allMatched) {
      for (int c = 0; c < _gridSize; c++) {
        if (_colSum(c) != _colTargets[c]) {
          allMatched = false;
          break;
        }
      }
    }

    if (allMatched) {
      AudioManager.playSuccess();
      settingsNotifier.hapticSuccess();
      _onLevelCleared();
    }
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

    final bool allLevelsCompleted = !_playDailyMode && _currentLevel >= 50;

    if (allLevelsCompleted) {
      return Scaffold(
        backgroundColor: context.bgDark,
        appBar: AppBar(
          title: Text('Sum Strike', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        body: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: context.bgCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: context.textMuted.withAlpha(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.emoji_events,
                  color: Colors.amber,
                  size: 80,
                ),
                const SizedBox(height: 24),
                Text(
                  'All Levels Completed!',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Congratulations! You have solved all 50 levels of Sum Strike. More levels will be added in future updates!',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: context.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.dustyMauve,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.home),
                  label: const Text('Back to Home'),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: context.textMuted,
                  ),
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt(PrefsKeys.gameLevel('sumstrike'), 0);
                    setState(() {
                      _currentLevel = 0;
                      _generatePuzzle();
                    });
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reset Progress & Replay'),
                ),
              ],
            ),
          ),
        ),
      );
    }

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

                                    return Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E2127),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isMatch
                                              ? AppTheme.dustyMauve.withAlpha(120)
                                              : Colors.transparent,
                                          width: 1,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$target',
                                          style: GoogleFonts.spaceGrotesk(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: isMatch ? Colors.white38 : Colors.white,
                                            decoration: isMatch ? TextDecoration.lineThrough : null,
                                            decorationColor: AppTheme.dustyMauve,
                                            decorationThickness: 2,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    );
                                  }

                                  // Row Target chip (right column)
                                  if (c == _gridSize) {
                                    int target = _rowTargets[r];
                                    int sum = _rowSum(r);
                                    bool isMatch = sum == target;

                                    return Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E2127),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isMatch
                                              ? AppTheme.dustyMauve.withAlpha(120)
                                              : Colors.transparent,
                                          width: 1,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$target',
                                          style: GoogleFonts.spaceGrotesk(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: isMatch ? Colors.white38 : Colors.white,
                                            decoration: isMatch ? TextDecoration.lineThrough : null,
                                            decorationColor: AppTheme.dustyMauve,
                                            decorationThickness: 2,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    );
                                  }

                                  // Game grid number cells
                                  int gridIdx = r * _gridSize + c;
                                  int val = _grid[gridIdx];
                                  bool keep = _keep[gridIdx];
                                  bool isHintGlow = _hintIdx == gridIdx;
                                  bool isWrong = _wrongTaps.contains(gridIdx);

                                  return GestureDetector(
                                    onTap: () => _toggleCell(gridIdx),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      decoration: BoxDecoration(
                                        color: isWrong
                                            ? const Color(0xFFC62828)
                                            : keep
                                                ? const Color(0xFF23272F)
                                                : const Color(0xFF14161B),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isWrong
                                              ? Colors.redAccent
                                              : isHintGlow
                                                  ? Colors.amber
                                                  : keep
                                                      ? AppTheme.dustyMauve.withAlpha(90)
                                                      : Colors.transparent,
                                          width: (isHintGlow || isWrong) ? 2.5 : 1,
                                        ),
                                        boxShadow: isHintGlow
                                            ? [
                                                BoxShadow(
                                                  color: Colors.amber.withOpacity(0.5),
                                                  blurRadius: 8,
                                                  spreadRadius: 1,
                                                )
                                              ]
                                            : (keep && !isWrong)
                                                ? [
                                                    BoxShadow(
                                                      color: Colors.black.withAlpha(60),
                                                      blurRadius: 3,
                                                      offset: const Offset(0, 2),
                                                    )
                                                  ]
                                                : null,
                                      ),
                                      child: Center(
                                        child: Text(
                                          keep ? '$val' : '',
                                          style: GoogleFonts.spaceGrotesk(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
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
                Center(
                  child: _isSuccess
                      ? AutoNextCountdown(
                          onNext: _nextLevel,
                          accentColor: AppTheme.dustyMauve,
                        )
                      : ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.bgCard,
                            foregroundColor: context.textPrimary,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            settingsNotifier.hapticTap();
                            setState(() {
                              _keep = List.filled(_keep.length, true);
                              _wrongTaps.clear();
                            });
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reset'),
                        ),
                ),
              ],
            ),
          ),
          if (_isSuccess && _playDailyMode)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.6),
                child: Center(
                  child: ChallengeClearedOverlay(
                    accentColor: AppTheme.dustyMauve,
                    onComplete: () {
                      Navigator.pop(context, true);
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
