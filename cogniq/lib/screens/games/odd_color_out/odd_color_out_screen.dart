import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/prefs_keys.dart';
import '../../../utils/hint_manager.dart';
import '../../../utils/audio_manager.dart';
import '../../../widgets/animated_level_indicator.dart';
import '../../../widgets/fog_overlay.dart';
import '../../../widgets/challenge_cleared_overlay.dart';
import '../../../widgets/loss_overlay.dart';
import '../../../widgets/buy_hints_dialog.dart';
import '../../../widgets/game_tutorial_dialog.dart';
import '../../../utils/shuffle_manager.dart';
import '../../../widgets/auto_next_countdown.dart';

class OddColorOutScreen extends StatefulWidget {
  const OddColorOutScreen({super.key});

  @override
  State<OddColorOutScreen> createState() => _OddColorOutScreenState();
}

class _OddColorOutScreenState extends State<OddColorOutScreen> with SingleTickerProviderStateMixin {
  int _levelIndex = 0;
  bool _shuffleActive = false;
  int _hintCount = 0;
  bool _isHintShowing = false;
  bool _isTutorialMode = false;
  bool _tutorialCompleted = false;
  bool _levelCleared = false;
  bool _isDailyMode = false;
  String _dailyModifierType = '';
  String _dailyModifierName = '';
  bool _isShadowed = false;
  Timer? _eclipseTimer;
  Timer? _chaosTimer;

  bool _chaosHasOdd = false;
  bool _chaosIsFirstCall = true;
  int _chaosTimeLeft = 4;
  int _chaosTickId = 0;
  bool _gameOver = false;

  late int _oddRow;
  late int _oddCol;
  late Color _baseColor;
  late Color _oddColor;
  List<Color> _gridColors = [];

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 12.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);

    _generateLevelColors();
    _loadPersistedLevel();
  }

  @override
  void dispose() {
    _eclipseTimer?.cancel();
    _chaosTimer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  int get _gridSide {
    if (_isDailyMode && _dailyModifierType == 'chaos') return 2;
    if (_isDailyMode && _dailyModifierType == 'hidden_rule') return 3;
    if (_levelIndex < 2) return 2; // 2x2
    if (_levelIndex < 5) return 3; // 3x3
    if (_levelIndex < 10) return 4; // 4x4
    if (_levelIndex < 16) return 5; // 5x5
    if (_levelIndex < 23) return 6; // 6x6
    if (_levelIndex < 30) return 7; // 7x7
    if (_levelIndex < 40) return 8; // 8x8
    return 9; // 9x9 max
  }

  void _generateLevelColors({bool keepPosition = false}) {
    final rand = Random();
    
    if (_isDailyMode && _dailyModifierType == 'chaos') {
      if (_chaosIsFirstCall) {
        _chaosHasOdd = false;
        _chaosIsFirstCall = false;
      } else {
        _chaosHasOdd = rand.nextBool();
      }
    }

    // Saturation and Lightness kept in zen-friendly pastel/moderate ranges
    final double saturation = (_isDailyMode && _dailyModifierType == 'monochrome') ? 0.0 : (0.55 + rand.nextDouble() * 0.35); 
    final double lightness = 0.40 + rand.nextDouble() * 0.35;

    double baseHue = rand.nextDouble() * 360.0;
    if (_isDailyMode && _dailyModifierType == 'hidden_rule') {
      // 195.0 to 230.0 hue represents shades of blue
      baseHue = 195.0 + rand.nextDouble() * 35.0;
    }

    _baseColor = HSLColor.fromAHSL(1.0, baseHue, saturation, lightness).toColor();

    if (_isDailyMode && _dailyModifierType == 'hidden_rule') {
      // Shift hue to a completely different non-blue color family (e.g. shift by 70 to 180 degrees)
      final double shift = 70.0 + rand.nextDouble() * 110.0;
      final double oddHue = (baseHue + shift) % 360.0;
      _oddColor = HSLColor.fromAHSL(1.0, oddHue, saturation, lightness).toColor();
    } else {
      // Delta difference decreases linearly as level increases (gets harder)
      final double minDelta = 0.04;
      final double maxDelta = 0.10;
      final double delta = maxDelta - (min(49, _levelIndex) / 49.0) * (maxDelta - minDelta);

      final double shiftDirection = rand.nextBool() ? 1.0 : -1.0;
      double oddLightness = lightness + (shiftDirection * delta);
      
      // Clamp to ensure it remains a valid visual color
      if (oddLightness < 0.15 || oddLightness > 0.85) {
        oddLightness = lightness - (shiftDirection * delta);
      }

      // Dual-channel shift: also shift saturation slightly at harder levels
      final double progress = min(49, _levelIndex) / 49.0;
      final double satShift = progress * 0.06;
      final double satDirection = rand.nextBool() ? 1.0 : -1.0;
      double oddSaturation = saturation + (satDirection * satShift);
      if (oddSaturation < 0.1 || oddSaturation > 0.95) {
        oddSaturation = saturation - (satDirection * satShift);
      }

      _oddColor = HSLColor.fromAHSL(
        1.0, 
        baseHue, 
        oddSaturation.clamp(0.0, 1.0), 
        oddLightness.clamp(0.15, 0.85)
      ).toColor();
    }

    final int side = _gridSide;
    if (!keepPosition) {
      _oddRow = rand.nextInt(side);
      _oddCol = rand.nextInt(side);
    }
    _levelCleared = false;

    _gridColors = List.generate(side * side, (index) {
      final r = index ~/ side;
      final c = index % side;
      final isOdd = r == _oddRow && c == _oddCol;

      if (_isDailyMode && _dailyModifierType == 'hidden_rule') {
        if (isOdd) {
          // Odd color is a non-blue color family (e.g. green/yellow/red/orange/purple)
          // Pick a random hue outside the blue range [190, 245]
          final double oddHue = rand.nextBool()
              ? (45.0 + rand.nextDouble() * 100.0) // 45 to 145 (green/yellow/orange)
              : (300.0 + rand.nextDouble() * 60.0); // 300 to 360 (purple/pink/red)
          return HSLColor.fromAHSL(1.0, oddHue, saturation, lightness).toColor();
        } else {
          // Base color is a random type of blue (hue in [190, 245])
          // We also vary the lightness and saturation slightly so they are different types/shades of blue
          final double bHue = 190.0 + rand.nextDouble() * 55.0;
          final double bSat = 0.50 + rand.nextDouble() * 0.40;
          final double bLight = 0.35 + rand.nextDouble() * 0.30;
          return HSLColor.fromAHSL(1.0, bHue, bSat, bLight).toColor();
        }
      } else if (_isDailyMode && _dailyModifierType == 'prism') {
        final double baseHue2 = (baseHue + 120.0) % 360.0;
        final Color baseColor2 = HSLColor.fromAHSL(1.0, baseHue2, saturation, lightness).toColor();
        final bool isTopLeft = (r + c < side);
        if (isOdd) {
          final double secHue = isTopLeft ? baseHue : baseHue2;
          final double progress = min(49, _levelIndex) / 49.0;
          final double delta = 0.10 - progress * 0.06;
          final double oddLightness = (lightness + delta > 0.85) ? (lightness - delta) : (lightness + delta);
          return HSLColor.fromAHSL(1.0, secHue, saturation, oddLightness).toColor();
        } else {
          return isTopLeft ? _baseColor : baseColor2;
        }
      } else if (_isDailyMode && _dailyModifierType == 'chaos') {
        if (_chaosHasOdd) {
          return isOdd ? _oddColor : _baseColor;
        } else {
          return _baseColor;
        }
      } else {
        return isOdd ? _oddColor : _baseColor;
      }
    });

    if (!keepPosition) {
      _startDailyTimers();
    }
  }

  void _startDailyTimers() {
    _eclipseTimer?.cancel();
    _chaosTimer?.cancel();
    if (_isDailyMode) {
      if (_dailyModifierType == 'eclipse') {
        _isShadowed = true;
        _eclipseTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          if (_gameOver || _levelCleared) {
            timer.cancel();
            return;
          }
          setState(() {
            _isShadowed = !_isShadowed;
          });
        });
      } else if (_dailyModifierType == 'chaos') {
        _chaosTimeLeft = 4;
        _chaosTickId = 0;
        _chaosTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          if (_gameOver || _levelCleared) {
            timer.cancel();
            return;
          }
          
          if (_chaosTimeLeft > 1) {
            setState(() {
              _chaosTimeLeft--;
            });
          } else {
            // Check if there was an odd cell in the previous cycle that was missed
            if (_chaosHasOdd && !_levelCleared) {
              setState(() {
                _gameOver = true;
              });
              timer.cancel();
              AudioManager.playFail();
              return;
            }
            
            setState(() {
              _chaosTimeLeft = 4;
              _chaosTickId++;
              _generateLevelColors(keepPosition: true);
            });
          }
        });
      }
    }
  }

  Future<void> _loadPersistedLevel() async {
    _hintCount = await HintManager.getHints('oddcolor');
    final prefs = await SharedPreferences.getInstance();
    _isDailyMode = prefs.getBool(PrefsKeys.playDailyMode) ?? false;
    if (_isDailyMode) {
      _dailyModifierType = prefs.getString(PrefsKeys.dailyModifierType) ?? '';
      _dailyModifierName = prefs.getString(PrefsKeys.dailyModifierName) ?? '';
    } else {
      _dailyModifierType = '';
      _dailyModifierName = '';
    }
    final savedLevel = prefs.getInt(PrefsKeys.gameLevel('oddcolor')) ?? 0;
    final active = await ShuffleManager.isActive();

    _isTutorialMode = false;
    _levelIndex = savedLevel;

    if (mounted) {
      setState(() {
        _shuffleActive = active;
        _generateLevelColors();
      });
    }
  }

  Future<void> _savePersistedLevel(int lvl) async {
    if (_isDailyMode) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(PrefsKeys.gameLevel('oddcolor'), lvl);
    final earned = await HintManager.onLevelCleared('oddcolor');
    final newCount = await HintManager.getHints('oddcolor');
    if (mounted) {
      setState(() {
        _hintCount = newCount;
      });
    }
    
  }

  void _onCellTap(int r, int c) {
    if (_levelCleared || _gameOver) return;

    if (_isDailyMode && _dailyModifierType == 'chaos') {
      if (_chaosHasOdd && r == _oddRow && c == _oddCol) {
        // Correct!
        AudioManager.playSuccess();
        setState(() {
          _levelCleared = true;
        });
      } else {
        // Incorrect tap
        AudioManager.playFail();
        setState(() {
          _gameOver = true;
        });
        _shakeController.forward(from: 0.0);
      }
      return;
    }

    if (r == _oddRow && c == _oddCol) {
      // Correct!
      AudioManager.playSuccess();
      if (_isTutorialMode) {
        setState(() {
          _levelCleared = true;
          _tutorialCompleted = true;
        });
        return;
      }
      setState(() {
        _levelCleared = true;
      });
      if (_isDailyMode) {
        // Handled by ChallengeClearedOverlay
        return;
      }
    } else {
      if (_isTutorialMode) return;
      // Wrong cell - form a new color grid with same difficulty
      AudioManager.playFail();
      setState(() {
        _generateLevelColors();
      });
      _shakeController.forward(from: 0.0);
    }
  }

  Future<void> _useHint() async {
    if (_levelCleared) return;

    if (_hintCount <= 0) {
      BuyHintsDialog.show(
        context,
        initialGameId: 'oddcolor',
        isFromGameScreen: true,
        onPurchaseComplete: () {
          HintManager.getHints('oddcolor').then((val) {
            if (mounted) setState(() => _hintCount = val);
          });
        },
      );
      return;
    }

    await HintManager.useHint('oddcolor');
    final newCount = await HintManager.getHints('oddcolor');

    setState(() {
      _hintCount = newCount;
    });

    final side = _gridSide;
    String message = "";
    if (side <= 3) {
      message = "Hint: The odd tile is in row ${_oddRow + 1} or column ${_oddCol + 1}.";
    } else {
      final verticalHalf = _oddRow < side / 2 ? "top" : "bottom";
      final horizontalHalf = _oddCol < side / 2 ? "left" : "right";
      message = "Hint: The odd tile is in the $verticalHalf-half, $horizontalHalf-half section.";
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        duration: const Duration(seconds: 4),
        backgroundColor: AppTheme.accentFor('oddcolor'),
      ),
    );
  }

  void _nextLevel() async {
    if (await ShuffleManager.tryShuffleNavigate(context, 'oddcolor')) return;
    setState(() {
      _levelCleared = false;
      _levelIndex++;
      _savePersistedLevel(_levelIndex);
      _generateLevelColors();
    });
  }

  void _resetGame() {
    setState(() {
      _gameOver = false;
      _levelCleared = false;
      _chaosTimeLeft = 4;
      _chaosTickId = 0;
      _chaosHasOdd = false;
      _chaosIsFirstCall = true;
      _generateLevelColors();
    });
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = AppTheme.accentFor('oddcolor');
    final int side = _gridSide;
    
    // Dynamic grid size calculations
    final double screenW = context.screenWidth;
    final double gridW = min(screenW - 32, 420.0);
    final double cellW = (gridW - (side - 1) * 6) / side;

    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text(
          _isTutorialMode ? 'Tutorial' : 'Odd Color Out',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: context.scale(18)),
        ),
        actions: [
          if (_shuffleActive && !_isTutorialMode)
            IconButton(
              icon: const Icon(Icons.skip_next_rounded),
              tooltip: 'Skip Game',
              onPressed: () => ShuffleManager.tryShuffleNavigate(context, 'oddcolor'),
            ),
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
            onPressed: !_levelCleared && !_gameOver && !_isHintShowing && !_isTutorialMode
                ? () async {
                    if (_hintCount > 0) {
                      _useHint();
                    } else {
                      await BuyHintsDialog.show(
                        context,
                        initialGameId: 'oddcolor',
                        onPurchaseComplete: () async {
                          final newCount = await HintManager.getHints('oddcolor');
                          if (mounted) setState(() => _hintCount = newCount);
                        },
                      );
                    }
                  }
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => GameTutorialDialog.show(context, 'oddcolor', 'Odd Color Out'),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_gameOver)
            LossOverlay(
              onTryAgain: _resetGame,
              subtitle: 'Out of time or tapped identical cells!',
              accentColor: accentColor,
            ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height -
                        kToolbarHeight -
                        MediaQuery.of(context).padding.top -
                        MediaQuery.of(context).padding.bottom -
                        40,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                if (_isDailyMode)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 18),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'DAILY CHALLENGE: ${_dailyModifierName.toUpperCase()}',
                                style: GoogleFonts.outfit(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: context.scale(12),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                        if (_dailyModifierType == 'chaos') ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.timer, color: Colors.amber, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Palette Shifting in: $_chaosTimeLeft s',
                                style: GoogleFonts.spaceGrotesk(
                                  color: Colors.amber[200],
                                  fontWeight: FontWeight.bold,
                                  fontSize: context.scale(13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              height: 4,
                              child: TweenAnimationBuilder<double>(
                                key: ValueKey(_chaosTickId),
                                duration: const Duration(seconds: 4),
                                tween: Tween<double>(begin: 1.0, end: 0.0),
                                builder: (context, val, child) {
                                  return LinearProgressIndicator(
                                    value: val,
                                    color: Colors.amber,
                                    backgroundColor: Colors.amber.withOpacity(0.2),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                // Header stats
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isTutorialMode)
                            Text(
                              'Tutorial',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: context.scale(20),
                                color: context.textPrimary,
                              ),
                            )
                          else if (!_isDailyMode)
                            AnimatedLevelIndicator(
                              level: _levelIndex + 1,
                              accentColor: context.textPrimary,
                              fontSize: context.scale(20),
                              fontWeight: FontWeight.bold,
                            )
                          else
                            Text(
                              'Daily Challenge',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: context.scale(18),
                                color: context.textPrimary,
                              ),
                            ),
                          Text(
                            'Grid: ${side}x${side}',
                            style: AppTheme.numberStyle(
                              fontSize: context.scale(12),
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      // Render empty SizedBox to balance layout
                      const SizedBox(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Grid container
                AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    final double offset = sin(_shakeController.value * pi * 4) * _shakeAnimation.value;
                    return Transform.translate(
                      offset: Offset(offset, 0),
                      child: child,
                    );
                  },
                  child: Center(
                    child: SizedBox(
                      width: gridW,
                      height: gridW,
                      child: FogOverlay(
                        enabled: _isDailyMode && _dailyModifierType == 'fog',
                        radius: cellW * 1.5,
                        child: Stack(
                          children: [
                            GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: side,
                                crossAxisSpacing: 6,
                                mainAxisSpacing: 6,
                              ),
                              itemCount: side * side,
                              itemBuilder: (context, index) {
                                final r = index ~/ side;
                                final c = index % side;
                                final isOdd = r == _oddRow && c == _oddCol;
                                final color = _gridColors.length > index ? _gridColors[index] : (isOdd ? _oddColor : _baseColor);

                                final showHintBorder = _isHintShowing && isOdd;

                                return GestureDetector(
                                  onTap: () => _onCellTap(r, c),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(min(12.0, 48.0 / side)),
                                      border: Border.all(
                                        color: showHintBorder ? Colors.amber : Colors.transparent,
                                        width: showHintBorder ? 3.0 : 0,
                                      ),
                                      boxShadow: showHintBorder
                                          ? [BoxShadow(color: Colors.amber.withOpacity(0.6), blurRadius: 8, spreadRadius: 2)]
                                          : null,
                                    ),
                                    child: Stack(
                                      children: [
                                        if (_isDailyMode && _dailyModifierType == 'retro')
                                          Positioned.fill(
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(min(12.0, 48.0 / side)),
                                              child: CustomPaint(
                                                painter: _RetroTilePainter(),
                                              ),
                                            ),
                                          ),
                                        Center(
                                          child: AnimatedSwitcher(
                                            duration: const Duration(milliseconds: 150),
                                            child: _levelCleared && isOdd
                                                ? const Icon(Icons.check, key: ValueKey('correct'), color: Colors.white)
                                                : const SizedBox(key: ValueKey('empty')),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            if (_isDailyMode && _dailyModifierType == 'eclipse')
                              IgnorePointer(
                                child: AnimatedOpacity(
                                  opacity: _isShadowed ? 0.94 : 0.0,
                                  duration: const Duration(milliseconds: 400),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_levelCleared && !_isDailyMode && !_isTutorialMode)
                  AutoNextCountdown(
                    onNext: _nextLevel,
                    accentColor: accentColor,
                  ),
                const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_levelCleared && _isDailyMode)
            ChallengeClearedOverlay(
              accentColor: accentColor,
              onComplete: () {
                Navigator.pop(context, true);
              },
            ),
          // if (_isTutorialMode)
          //   InteractiveTutorialOverlay(
          //     instruction: _tutorialCompleted
          //         ? "Nice! You successfully spotted the odd color tile."
          //         : "A grid of colored tiles will appear. Identify and tap the one tile that has a slightly different shade or color compared to the rest!",
          //     isCompleted: _tutorialCompleted,
          //     onSkip: _finishTutorial,
          //     onStartGame: _finishTutorial,
          //   ),
        ],
      ),
    );
  }
}

class _RetroTilePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.15)
      ..strokeWidth = 1.0;
    
    for (double y = 0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (double x = 0; x < size.width; x += 4) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(Rect.fromLTWH(0.75, 0.75, size.width - 1.5, size.height - 1.5), borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
