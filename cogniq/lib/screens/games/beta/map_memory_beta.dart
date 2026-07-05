import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../widgets/auto_next_countdown.dart';

class MapMemoryBetaScreen extends StatefulWidget {
  const MapMemoryBetaScreen({super.key});
  @override
  State<MapMemoryBetaScreen> createState() => _MapMemoryBetaScreenState();
}
class _MapMemoryBetaScreenState extends State<MapMemoryBetaScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  bool _showLabels = true;
  String _targetLabel = "";
  int _targetIdx = 0;
  final List<String> _labels = ["A", "B", "C", "D"];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadLevel();
  }
  void _loadLevel() {
    setState(() {
      _isSuccess = false;
      _showLabels = true;
      _targetIdx = _currentLevel % 4;
      _targetLabel = _labels[_targetIdx];
    });
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showLabels = false);
      }
    });
  }
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
  Future<void> _onLevelCleared() async {
    final prefs = await SharedPreferences.getInstance();
    int highest = prefs.getInt('beta_level_mapmemory') ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt('beta_level_mapmemory', _currentLevel + 1);
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
  void _select(int idx) {
    if (_showLabels || _isSuccess) return;
    if (idx == _targetIdx) {
      settingsNotifier.hapticTap();
      _onLevelCleared();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Wrong location! Let's try again.")));
      _loadLevel();
    }
  }
  void _showHint() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Hint: The target is location $_targetLabel.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text('Map Memory', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
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
                        Text(_showLabels ? 'Memorize label locations...' : 'Where was label $_targetLabel?', style: GoogleFonts.outfit(fontSize: 16, color: context.textPrimary)),
                        const SizedBox(height: 24),
                        Container(
                          width: 240, height: 240,
                          decoration: BoxDecoration(border: Border.all(color: context.textMuted, width: 2)),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
                            itemCount: 4,
                            itemBuilder: (context, idx) {
                              return GestureDetector(
                                onTap: () => _select(idx),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: context.bgCard,
                                    border: Border.all(color: Colors.grey.shade900),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _showLabels ? _labels[idx] : "?",
                                      style: GoogleFonts.spaceGrotesk(fontSize: 36, fontWeight: FontWeight.bold, color: AppTheme.dustyMauve),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
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
                    '💡 Rule Details:\n• Study the map and its labels briefly.\n• Then recall the correct location from memory.\n• Look for landmarks to anchor your memory.',
                    style: GoogleFonts.outfit(fontSize: 12, color: context.textSecondary),
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
