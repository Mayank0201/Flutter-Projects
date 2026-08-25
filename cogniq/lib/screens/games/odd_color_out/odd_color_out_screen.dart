import 'package:flutter/foundation.dart';
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../widgets/game_level_chip.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/prefs_keys.dart';
import '../../../utils/hint_manager.dart';
import '../../../utils/audio_manager.dart';
import '../../../widgets/fog_overlay.dart';
import '../../../widgets/challenge_cleared_overlay.dart';
import '../../../widgets/loss_overlay.dart';
import '../../../widgets/buy_hints_dialog.dart';
import '../../../widgets/game_tutorial_dialog.dart';
import '../../../utils/rotation_engine.dart';
import '../../../utils/point_manager.dart';
import '../../../utils/shuffle_manager.dart';
import '../../../widgets/auto_next_countdown.dart';

class OddColorOutScreen extends StatefulWidget {
  const OddColorOutScreen({super.key});

  @override
  State<OddColorOutScreen> createState() => _OddColorOutScreenState();
}

class _OddColorOutScreenState extends State<OddColorOutScreen> with SingleTickerProviderStateMixin {
  String? _forcedModifier;
  Set<String> _activeModifiers = {};

  // COGNIQ-FIX:mod-active-helper
  bool _isModActive(String name) {
    if (_forcedModifier == name) return true;
    if (_isDailyMode) return _dailyModifierType == name;
    return _levelIndex >= RotationEngine.modifierStartLevel('oddcolor') &&
        _activeModifiers.contains(name);
  }

  // COGNIQ-FIX:mod-getters
  bool get _isEndgame => _isModActive('timer');

  // COGNIQ-FIX:mod-desc-copy
  String _getModifierDescription(String mod) {
    switch (mod) {
      case 'hueChannel':
        return 'The odd tile differs in tint rather than brightness.';
      case 'noise':
        return 'Tile shades jitter subtly across the grid.';
      case 'gradient':
        return 'A color gradient flows across background tiles.';
      case 'timer':
        return 'Find the odd tile before the countdown expires.';
      case 'monochrome':
        return 'The entire grid is rendered in shades of grey.';
      case 'whisper':
        return 'The color difference is exceptionally faint.';
      case 'prism':
        return 'The grid is split across two alternating color palettes.';
      case 'eclipse':
        return 'Brief periodic blackouts darken the screen.';
      case 'fog':
        return 'A dense fog obscures portions of the grid.';
      case 'retro':
        return 'Retro CRT scanline styling is active.';
      default:
        return '';
    }
  }

  String get _modifierBannerText {
    if (_isTutorialMode) return '';
    if (_isDailyMode) {
      if (_dailyModifierDesc.isNotEmpty) return _dailyModifierDesc;
      if (_dailyModifierName.isNotEmpty) return _dailyModifierName;
      return '';
    }
    return _activeModifiers
        .map(_getModifierDescription)
        .where((d) => d.isNotEmpty)
        .join(' · ');
  }
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
  String _dailyModifierDesc = '';
  bool _isShadowed = false;
  Timer? _eclipseTimer;
  Timer? _chaosTimer;
  Timer? _gameTimer;
  int _timeLeft = -1;
  bool _timeBonusEarned = false;

  bool _chaosHasOdd = false;
  bool _chaosIsFirstCall = true;
  int _chaosTimeLeft = 4;
  int _chaosTickId = 0;
  bool _gameOver = false;
  int _attempts = 0;

  late int _oddRow;
  late int _oddCol;
  late Color _baseColor;
  late Color _oddColor;
  List<Color> _gridColors = [];

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  /// Modifiers now begin at a per-game level chosen in RotationEngine
  /// rather than a flat level 30 for every game.
  // COGNIQ-FIX:mod-getters
  // 'oddcolor' throughout, matching lib/models/game_info.dart and the id this
  // file already uses for prefs, hints and theming. It previously said
  // 'oddcolorout' here and in getActiveModifiers but 'oddcolor' in
  // modifierStartLevel; both are aliased in RotationEngine's map, so this
  // removes an inconsistency rather than a live bug.
  //
  // The `getDeterminism` seeds below stay 'oddcolorout'/'oddcolorout_retry<n>':
  // those strings are RNG seeds, not identifiers, and renaming one regenerates
  // every board the player has ever seen.
  bool get _modsOn => !_isDailyMode && RotationEngine.hasModifiers('oddcolor', _levelIndex);

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
    _gameTimer?.cancel();
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
    // COGNIQ-FIX:curve-plateau
    // The board used to stop at 9x9 for levels 30-89 and then RUN BACKWARDS:
    // `5 + ((_levelIndex - 90) % 5)` dropped a level-90 player from a 9x9 to a
    // 5x5 and cycled 5->9 forever, so level 90 was easier than level 89 and the
    // game had no net progression at all past 30. The ladder keeps climbing
    // instead, and stops at 11 rather than continuing: the board is laid out at
    // `min(screenWidth - 32, 420)` px with 6px gutters, so an 11x11 tile is
    // about 26px on a 375pt phone and a 12x12 about 23px. Below ~25px picking
    // out a single tile stops being a perception test and starts being a
    // fat-finger test, which is not the difficulty this game is measuring.
    if (_levelIndex < 45) return 9; // 9x9
    if (_levelIndex < 65) return 10; // 10x10
    return 11; // 11x11 -- the cap, set by tap-target size // not-a-modifier-gate
  }

  void _generateLevelColors({bool keepPosition = false, bool keepTimer = false}) {
    if (!keepTimer) {
      _gameTimer?.cancel();
      _timeLeft = -1;
      _timeBonusEarned = false;
    }

    // Seeded, not random: the same (gameId, level) must produce the same board
    // on every device and every replay, or hints, bug reports and shared levels
    // stop being reproducible. (remember.md — the seeded-RNG law.)
    //
    // Free play used to fall back to `Random()` below level 90, which is the
    // whole realistic play range, so every one of those boards was different on
    // every device. The retry variation is a *separate salted stream* rather
    // than `_levelIndex + _attempts`: adding the attempt count to the level made
    // level N+1 attempt 0 draw exactly the board of level N attempt 1, and it
    // meant replaying a level never gave the same puzzle back.
    // The daily branch stays unseeded, as it is on every other screen.
    final rand = _isDailyMode
        ? Random()
        : RotationEngine.getDeterminism(
            _attempts == 0 ? 'oddcolorout' : 'oddcolorout_retry$_attempts',
            _levelIndex,
          );
    
    if (_isDailyMode && (_dailyModifierType == 'chaos' || _dailyModifierType == 'time_warp')) {
      if (_chaosIsFirstCall) {
        _chaosHasOdd = false;
        _chaosIsFirstCall = false;
      } else {
        _chaosHasOdd = rand.nextBool();
      }
    }

    final double saturation = _isModActive('monochrome') ? 0.0 : (0.55 + rand.nextDouble() * 0.35); 
    final double lightness = 0.40 + rand.nextDouble() * 0.35;

    double baseHue = rand.nextDouble() * 360.0;
    if (_isDailyMode && _dailyModifierType == 'hidden_rule') {
      baseHue = 195.0 + rand.nextDouble() * 35.0;
    }

    _baseColor = HSLColor.fromAHSL(1.0, baseHue, saturation, lightness).toColor();

    bool isHueChannel = false;
    bool hasNoise = false;
    bool hasGradient = false;

    if (!_isDailyMode) {
      if (_modsOn) {
        var activeMods = RotationEngine.getActiveModifiers(
          gameId: 'oddcolor', // COGNIQ-FIX:mod-getters
          levelIndex: _levelIndex,
          pool: ['hueChannel', 'noise', 'gradient', 'timer', 'monochrome', 'whisper', 'prism', 'eclipse', 'fog'],
          minActive: 2,
          maxActive: 4,
          smallGrid: _gridSide <= 5,
        );
        if (_forcedModifier != null) {
          activeMods = {_forcedModifier!};
        }
        _activeModifiers = activeMods;
        isHueChannel = activeMods.contains('hueChannel');
        hasNoise = activeMods.contains('noise');
        hasGradient = activeMods.contains('gradient');
      } else {
        _activeModifiers = {};
      }
    } else {
      _activeModifiers = {};
    }

    double delta = 0.0;
    if (_isDailyMode && _dailyModifierType == 'hidden_rule') {
      final double shift = 70.0 + rand.nextDouble() * 110.0;
      final double oddHue = (baseHue + shift) % 360.0;
      _oddColor = HSLColor.fromAHSL(1.0, oddHue, saturation, lightness).toColor();
    } else {
      if (!_isDailyMode && _levelIndex >= 30) { // not-a-modifier-gate
        // COGNIQ-FIX:curve-plateau
        // Was `0.04 * (30 / (30 + (level - 30)))` -- i.e. 1.2/level -- clamped
        // at 0.035. That clamp bit at level 35 (raw 0.034286), so every level
        // from 35 on shipped an IDENTICAL colour delta: 55 flat levels.
        //
        // A straight ramp instead, because it is obviously monotonic and its
        // endpoint is readable: 0.040 at level 30 (continuous with the pre-30
        // curve, which ends on exactly 0.040 at level 29), falling 0.00025 per
        // level, reaching the floor at level 118.
        //
        // Floor 0.018 rather than the JND itself. An HSL lightness step of
        // ~0.010 is roughly the just-noticeable difference for a mid-lightness
        // patch, but that is a lab number -- on a phone at half brightness, on
        // OLED, or in daylight it is a coin flip rather than a puzzle. 0.018
        // also sits deliberately ABOVE the `whisper` modifier's 0.015 so that
        // whisper stays the hardest thing on screen; see the clamp below.
        delta = 0.040 - (_levelIndex - 30) * 0.00025;
        if (delta < 0.018) delta = 0.018;
      } else {
        delta = 0.10 - (_levelIndex / 29.0) * 0.06;
        if (delta < 0.035) delta = 0.035;
      }
      if (_isModActive('whisper')) {
        // COGNIQ-FIX:curve-plateau
        // `min`, not assignment. Once the base curve is allowed past 0.035 a
        // flat `delta = 0.015` would eventually be LARGER than the level's own
        // delta, so the "exceptionally faint" modifier would hand the player an
        // easier tile than not having it. Whisper may only ever tighten.
        delta = min(delta, 0.015);
      }
      double oddLightness = lightness;
      double oddSaturation = saturation;
      double oddHue = baseHue;

      if (isHueChannel) {
        final double shiftDirection = rand.nextBool() ? 1.0 : -1.0;
        double hueShift = delta * 250.0;
        oddHue = (baseHue + shiftDirection * hueShift) % 360.0;
      } else {
        final double shiftDirection = rand.nextBool() ? 1.0 : -1.0;
        oddLightness = lightness + (shiftDirection * delta);
        
        if (oddLightness < 0.15 || oddLightness > 0.85) {
          oddLightness = lightness - (shiftDirection * delta);
        }

        final double progress = min(49, _levelIndex) / 49.0;
        final double satShift = progress * 0.06;
        final double satDirection = rand.nextBool() ? 1.0 : -1.0;
        oddSaturation = saturation + (satDirection * satShift);
        if (oddSaturation < 0.1 || oddSaturation > 0.95) {
          oddSaturation = saturation - (satDirection * satShift);
        }
      }

      _oddColor = HSLColor.fromAHSL(
        1.0, 
        oddHue, 
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
          final double oddHue = rand.nextBool()
              ? (45.0 + rand.nextDouble() * 100.0) 
              : (300.0 + rand.nextDouble() * 60.0); 
          return HSLColor.fromAHSL(1.0, oddHue, saturation, lightness).toColor();
        } else {
          final double bHue = 190.0 + rand.nextDouble() * 55.0;
          final double bSat = 0.50 + rand.nextDouble() * 0.40;
          final double bLight = 0.35 + rand.nextDouble() * 0.30;
          return HSLColor.fromAHSL(1.0, bHue, bSat, bLight).toColor();
        }
      } else if (_isModActive('prism')) {
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
        double cellHue = baseHue;
        double cellSaturation = saturation;
        double cellLightness = lightness;

        if (!_isDailyMode && (hasGradient || hasNoise)) {
          if (hasGradient) {
            double gradientFactor = (r + c) / (2 * (side - 1));
            if (isHueChannel) {
              double gradHueMag = 35.0;
              cellHue += (gradientFactor - 0.5) * gradHueMag;
            } else {
              double gradMag = 0.05;
              cellLightness += (gradientFactor - 0.5) * gradMag;
            }
          }
          if (hasNoise) {
            // Noise must stay well under the odd tile's own deviation,
            // otherwise ordinary tiles drift further from the base colour than
            // the target does and the puzzle becomes a coin flip. This bit
            // hardest with 'whisper' (delta 0.015) whose signal was exactly the
            // old noise range on lightness, and half it on hue.
            if (isHueChannel) {
              final double hueSignal = delta * 250.0;
              final double noiseHueMag = min(15.0, hueSignal * 1.2);
              cellHue += (rand.nextDouble() - 0.5) * noiseHueMag;
            } else {
              final double noiseMag = min(0.03, delta * 1.2);
              cellLightness += (rand.nextDouble() - 0.5) * noiseMag;
            }
          }
        }

        if (isOdd) {
          if (isHueChannel) {
            final double shiftDirection = rand.nextBool() ? 1.0 : -1.0;
            double hueShift = delta * 250.0;
            cellHue = (cellHue + shiftDirection * hueShift);
          } else {
            final double shiftDirection = rand.nextBool() ? 1.0 : -1.0;
            cellLightness = cellLightness + (shiftDirection * delta);
            
            if (cellLightness < 0.15 || cellLightness > 0.85) {
              cellLightness = cellLightness - (shiftDirection * delta);
            }

            final double progress = min(49, _levelIndex) / 49.0;
            final double satShift = progress * 0.06;
            final double satDirection = rand.nextBool() ? 1.0 : -1.0;
            cellSaturation = cellSaturation + (satDirection * satShift);
          }
        }

        return HSLColor.fromAHSL(
          1.0,
          cellHue % 360.0,
          cellSaturation.clamp(0.0, 1.0),
          cellLightness.clamp(0.15, 0.85),
        ).toColor();
      }
    });

    if (!keepTimer && _isEndgame) {
      _timeLeft = 25;
      _timeBonusEarned = true;
      _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          if (_timeLeft > 0) {
            setState(() {
              _timeLeft--;
            });
          } else {
            _gameTimer?.cancel();
            AudioManager.playFail();
            setState(() {
              _gameOver = true;
            });
          }
        }
      });
    }

    if (!keepPosition) {
      _startDailyTimers();
    }
  }

  void _startDailyTimers() {
    _eclipseTimer?.cancel();
    _chaosTimer?.cancel();
    if (_isModActive('eclipse')) {
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
    }
    if (_isDailyMode && (_dailyModifierType == 'chaos' || _dailyModifierType == 'time_warp')) {
        final int interval = (_dailyModifierType == 'time_warp') ? 2 : 4;
        _chaosTimeLeft = interval;
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
              _chaosTimeLeft = interval;
              _chaosTickId++;
              _generateLevelColors(keepPosition: true);
            });
          }
        });
      }
  }

  Future<void> _loadPersistedLevel() async {
    await HintManager.startLevel('oddcolor');
    _hintCount = await HintManager.getHints('oddcolor');
    final prefs = await SharedPreferences.getInstance();
    _isDailyMode = prefs.getBool(PrefsKeys.playDailyMode) ?? false;
    if (_isDailyMode) {
      _dailyModifierType = prefs.getString(PrefsKeys.dailyModifierType) ?? '';
      _dailyModifierName = prefs.getString(PrefsKeys.dailyModifierName) ?? '';
      _dailyModifierDesc = prefs.getString(PrefsKeys.dailyModifierDesc) ?? '';
    } else {
      _dailyModifierType = '';
      _dailyModifierName = '';
      _dailyModifierDesc = '';
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

  void _showJumpToLevelDialog() {
    showDialog(
      context: context,
      builder: (context) {
        int target = _levelIndex + 1;
        String? selectedMod = _forcedModifier;
        final pool = ['hueChannel', 'noise', 'gradient', 'timer', 'monochrome', 'whisper', 'prism', 'eclipse', 'fog', 'retro'];
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: context.bgCard,
              title: Text('Jump to Level', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.outfit(color: context.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Level Number (1+)',
                        labelStyle: GoogleFonts.outfit(color: context.textSecondary),
                      ),
                      onChanged: (val) {
                        target = int.tryParse(val) ?? target;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedMod,
                      dropdownColor: context.bgCard,
                      style: GoogleFonts.outfit(color: context.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Force Modifier',
                        labelStyle: GoogleFonts.outfit(color: context.textSecondary),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('None (Default)')),
                        ...pool.map((m) => DropdownMenuItem(value: m, child: Text(m))),
                      ],
                      onChanged: (val) {
                        setDialogState(() {
                          selectedMod = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: GoogleFonts.outfit(color: context.textSecondary)),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (target > 0) {
                      setState(() {
                        _levelIndex = target - 1;
                        _forcedModifier = selectedMod;
                        _generateLevelColors();
                      });
                    }
                  },
                  child: Text('Jump', style: GoogleFonts.outfit(color: AppTheme.accentFor('oddcolor'))),
                ),
              ],
            );
          }
        );
      },
    );
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

    if (_isDailyMode && (_dailyModifierType == 'chaos' || _dailyModifierType == 'time_warp')) {
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
      _gameTimer?.cancel();
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

      if (_timeLeft > 0 && _timeBonusEarned) {
        PointManager.addPoints(5);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Speed Bonus! Earned +5 Points!', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black)),
            backgroundColor: Colors.amber,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (_isTutorialMode) return;
      AudioManager.playFail();
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft = max(0, _timeLeft - 3);
        }
        _attempts++;
        _generateLevelColors(keepTimer: true);
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
      _attempts = 0;
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
      _attempts++;
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
        title: const GameTitle('Odd Color Out'),
        actions: [
          if (_shuffleActive && !_isTutorialMode)
            IconButton(
              icon: const Icon(Icons.skip_next_rounded),
              tooltip: 'Skip Game',
              onPressed: () => ShuffleManager.tryShuffleNavigate(context, 'oddcolor'),
            ),
          IconButton(
            tooltip: 'Hint',
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
          if (_timeLeft >= 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Row(
                  children: [
                    Icon(
                      Icons.timer,
                      color: _timeLeft <= 4 ? Colors.red : Colors.amber,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_timeLeft s',
                      style: GoogleFonts.spaceGrotesk(
                        color: _timeLeft <= 4 ? Colors.red : Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          IconButton(
            tooltip: 'Rules',
            icon: const Icon(Icons.help_outline),
            onPressed: () => GameTutorialDialog.show(context, 'oddcolor', 'Odd Color Out'),
          ),
          GameLevelChip(
            level: _levelIndex + 1,
            modeLabel: _isTutorialMode
                ? 'Tutorial'
                : (_isDailyMode ? 'Daily' : null),
            accent: AppTheme.accentFor('oddcolor'),
            onTap: kDebugMode ? _showJumpToLevelDialog : null,
          ),
        ],
      ),
      body: Stack(
        children: [
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
                          // The level lives in the app bar like every other
                          // game; the body only carries board information.
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
                if (_modifierBannerText.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      _modifierBannerText,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accentFor('oddcolor').withOpacity(0.9),
                      ),
                    ),
                  ),
                ],
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
                        enabled: _isModActive('fog'),
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
                                        if (_isModActive('retro'))
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
                            if (_isModActive('eclipse'))
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
          if (_gameOver)
            Positioned.fill(
              child: LossOverlay(
                onTryAgain: _resetGame,
                subtitle: 'Out of time or tapped identical cells!',
                accentColor: accentColor,
              ),
            ),
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
