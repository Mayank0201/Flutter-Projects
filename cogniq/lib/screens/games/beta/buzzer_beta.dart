import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../../../theme/app_theme.dart';
import '../../../widgets/auto_next_countdown.dart';

class BuzzerBetaScreen extends StatefulWidget {
  const BuzzerBetaScreen({super.key});
  @override
  State<BuzzerBetaScreen> createState() => _BuzzerBetaScreenState();
}
class _BuzzerBetaScreenState extends State<BuzzerBetaScreen> with SingleTickerProviderStateMixin {
  int _currentLevel = 0;
  bool _isSuccess = false;
  DateTime? _pressStart;
  int _targetSeconds = 3;
  late AnimationController _pulseController;
  bool _hintActive = false;
  Timer? _liveTimer;
  double _elapsed = 0.0;
  double _actualTime = 0.0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      lowerBound: 1.0,
      upperBound: 1.15,
    );
    _loadLevel();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _liveTimer?.cancel();
    super.dispose();
  }

  void _loadLevel() {
    setState(() {
      _isSuccess = false;
      _hintActive = false;
      _elapsed = 0.0;
      _actualTime = 0.0;
      _targetSeconds = 2 + _currentLevel;
    });
  }

  Future<void> _onLevelCleared() async {
    final prefs = await SharedPreferences.getInstance();
    int highest = prefs.getInt('beta_level_buzzer') ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt('beta_level_buzzer', _currentLevel + 1);
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

  bool _isRunning = false;

  void _handleTap() {
    if (_isSuccess) return;
    setState(() {
      if (!_isRunning) {
        _isRunning = true;
        _pressStart = DateTime.now();
        _pulseController.repeat(reverse: true);
        _elapsed = 0.0;
        if (_hintActive) {
          _liveTimer?.cancel();
          _liveTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
            if (_pressStart != null) {
              setState(() {
                _elapsed = DateTime.now().difference(_pressStart!).inMilliseconds / 1000.0;
              });
            }
          });
        }
      } else {
        _isRunning = false;
        _pulseController.stop();
        _pulseController.animateTo(1.0, duration: const Duration(milliseconds: 100));
        _liveTimer?.cancel();
        
        if (_pressStart != null) {
          final diff = DateTime.now().difference(_pressStart!).inMilliseconds / 1000.0;
          _actualTime = diff;
          _pressStart = null;
          final err = (diff - _targetSeconds).abs();
          if (err < 0.35) {
            _onLevelCleared();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Stopped at ${diff.toStringAsFixed(2)}s. Error of ${err.toStringAsFixed(2)}s is too high!'),
            ));
            setState(() {
              _elapsed = 0.0;
              // Reset the hint aid on a loss so retrying the same level
              // starts with the hint OFF until pressed again.
              _hintActive = false;
            });
          }
        }
      }
    });
  }

  void _showHint() {
    setState(() {
      _hintActive = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Hint active: A live timer will be shown!'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text('Buzzer', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.lightbulb_outline, color: AppTheme.dustyMauve),
            tooltip: 'Show timer helper',
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
                          _isRunning ? 'Keep counting in your head!' : 'Tap the button to start, and tap again to stop after exactly:',
                          style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isRunning ? '??.?? Seconds' : '$_targetSeconds.00 Seconds',
                          style: GoogleFonts.spaceGrotesk(fontSize: 36, fontWeight: FontWeight.bold, color: AppTheme.dustyMauve),
                        ),
                        if (_hintActive && _elapsed > 0.0) ...[
                          const SizedBox(height: 16),
                          Text('${_elapsed.toStringAsFixed(2)}s', style: GoogleFonts.spaceGrotesk(fontSize: 24, color: Colors.amber, fontWeight: FontWeight.bold)),
                        ],
                        const SizedBox(height: 48),
                        ScaleTransition(
                          scale: _pulseController,
                          child: GestureDetector(
                            onTap: _handleTap,
                            child: Container(
                              width: 120, height: 120,
                              decoration: BoxDecoration(
                                color: _isRunning ? Colors.green : Colors.red,
                                shape: BoxShape.circle,
                                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 6))],
                              ),
                              child: Center(
                                child: Icon(
                                  _isRunning ? Icons.stop : Icons.play_arrow,
                                  size: 48,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(top: 16),
                          decoration: BoxDecoration(
                            color: context.bgCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.textMuted.withAlpha(20)),
                          ),
                          child: Text(
                            '💡 Tap to start the buzzer, then tap again to stop it after exactly the target seconds. Land within 0.35s of the target to clear the level — no visible timer, so count in your head. The Hint shows a live timer, but it turns OFF again after a loss.',
                            style: GoogleFonts.outfit(fontSize: 12, color: context.textSecondary),
                            textAlign: TextAlign.center,
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
                      Text('Target: ${_targetSeconds}.00s', style: GoogleFonts.outfit(fontSize: 16, color: context.textSecondary)),
                      Text('Your Time: ${_actualTime.toStringAsFixed(2)}s', style: GoogleFonts.outfit(fontSize: 16, color: context.textSecondary)),
                      Text(
                        'Error: ${(_actualTime - _targetSeconds).abs().toStringAsFixed(2)}s',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: (_actualTime - _targetSeconds).abs() < 0.15 ? Colors.green : Colors.amber,
                        ),
                      ),
                      const SizedBox(height: 24),
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
