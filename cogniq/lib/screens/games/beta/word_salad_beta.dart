import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../widgets/challenge_cleared_overlay.dart';
import '../../../utils/audio_manager.dart';

class WordSaladLevel {
  final String category;
  final List<String> letters;
  final List<String> targetWords;
  const WordSaladLevel({required this.category, required this.letters, required this.targetWords});
}

const List<WordSaladLevel> kWordSaladLevels = [
  WordSaladLevel(
    category: 'FRUITS',
    letters: ['A', 'P', 'L', 'E', 'B', 'N', 'O', 'R', 'G', 'S'],
    targetWords: ['APPLE', 'PEAR', 'MELON'],
  ),
  WordSaladLevel(
    category: 'ANIMALS',
    letters: ['D', 'O', 'G', 'C', 'A', 'T', 'L', 'I', 'O', 'N'],
    targetWords: ['DOG', 'CAT', 'LION'],
  ),
  WordSaladLevel(
    category: 'COLORS',
    letters: ['R', 'E', 'D', 'B', 'L', 'U', 'E', 'G', 'R', 'N'],
    targetWords: ['RED', 'BLUE', 'GREEN'],
  ),
  WordSaladLevel(
    category: 'VEGETABLES',
    letters: ['P', 'E', 'A', 'C', 'O', 'R', 'N', 'T', 'O', 'M'],
    targetWords: ['PEA', 'CORN', 'TOMATO'],
  ),
  WordSaladLevel(
    category: 'COUNTRIES',
    letters: ['I', 'N', 'D', 'A', 'U', 'S', 'A', 'P', 'E', 'R'],
    targetWords: ['INDIA', 'USA', 'PERU'],
  ),
  WordSaladLevel(
    category: 'SHAPES',
    letters: ['O', 'V', 'A', 'L', 'L', 'I', 'N', 'E', 'C', 'R'],
    targetWords: ['OVAL', 'LINE', 'CONE'],
  ),
  WordSaladLevel(
    category: 'TECH',
    letters: ['C', 'O', 'D', 'E', 'B', 'Y', 'T', 'E', 'D', 'I'],
    targetWords: ['CODE', 'BYTE', 'EDIT'],
  ),
  WordSaladLevel(
    category: 'SPORTS',
    letters: ['G', 'O', 'L', 'F', 'R', 'U', 'N', 'P', 'L', 'A'],
    targetWords: ['GOLF', 'RUN', 'PLAY'],
  ),
  WordSaladLevel(
    category: 'SPACE',
    letters: ['S', 'T', 'A', 'R', 'M', 'O', 'O', 'N', 'S', 'U'],
    targetWords: ['STAR', 'MOON', 'SUN'],
  ),
  WordSaladLevel(
    category: 'BODY PARTS',
    letters: ['H', 'A', 'N', 'D', 'E', 'Y', 'E', 'E', 'A', 'R'],
    targetWords: ['HAND', 'EYE', 'EAR'],
  ),
];

class WordSaladBetaScreen extends StatefulWidget {
  const WordSaladBetaScreen({super.key});

  @override
  State<WordSaladBetaScreen> createState() => _WordSaladBetaScreenState();
}

class _WordSaladBetaScreenState extends State<WordSaladBetaScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  String _currentWord = '';
  final Set<String> _foundWords = {};
  List<int> _selectedIndices = [];

  @override
  void initState() {
    super.initState();
    _loadLevelIndex();
  }

  Future<void> _loadLevelIndex() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentLevel = (prefs.getInt('beta_level_word_salad') ?? 0).clamp(0, kWordSaladLevels.length - 1);
      _loadLevel();
    });
  }

  void _loadLevel() {
    setState(() {
      _isSuccess = false;
      _currentWord = '';
      _foundWords.clear();
      _selectedIndices.clear();
    });
  }

  void _selectLetter(int idx, String letter) {
    if (_isSuccess) return;
    setState(() {
      if (_selectedIndices.contains(idx)) {
        // Toggle off if it's the last selected one to allow undoing
        if (_selectedIndices.last == idx) {
          _selectedIndices.removeLast();
          _currentWord = _currentWord.substring(0, _currentWord.length - 1);
          AudioManager.playClick();
          settingsNotifier.hapticTap();
        }
      } else {
        _selectedIndices.add(idx);
        _currentWord += letter;
        AudioManager.playClick();
        settingsNotifier.hapticTap();
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _currentWord = '';
      _selectedIndices.clear();
      AudioManager.playClick();
      settingsNotifier.hapticTap();
    });
  }

  void _submitWord() {
    if (_currentWord.isEmpty || _isSuccess) return;
    
    final level = kWordSaladLevels[_currentLevel];
    if (level.targetWords.contains(_currentWord)) {
      if (_foundWords.contains(_currentWord)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Already found "$_currentWord"!', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            duration: const Duration(seconds: 1),
          ),
        );
        AudioManager.playFail();
        settingsNotifier.hapticSuccess();
      } else {
        setState(() {
          _foundWords.add(_currentWord);
          _currentWord = '';
          _selectedIndices.clear();
        });
        AudioManager.playSuccess();
        settingsNotifier.hapticSuccess();
        _checkWin();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Not a target word!', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          duration: const Duration(seconds: 1),
        ),
      );
      AudioManager.playFail();
      settingsNotifier.hapticSuccess();
      setState(() {
        _currentWord = '';
        _selectedIndices.clear();
      });
    }
  }

  void _checkWin() {
    final level = kWordSaladLevels[_currentLevel];
    if (_foundWords.length == level.targetWords.length) {
      setState(() {
        _isSuccess = true;
      });
      _saveProgress();
    }
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    int highest = prefs.getInt('beta_level_word_salad') ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt('beta_level_word_salad', _currentLevel + 1);
    }
  }

  void _nextLevel() {
    if (_currentLevel < kWordSaladLevels.length - 1) {
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
    final level = kWordSaladLevels[_currentLevel];
    final size = MediaQuery.of(context).size;
    final double bowlSize = min(size.width * 0.75, 280.0);

    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text('Word Salad (Beta)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: context.bgDark,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Category: ${level.category}',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.amber.shade400,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Display target words checklist
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: level.targetWords.map((word) {
                            final isFound = _foundWords.contains(word);
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isFound ? Colors.green.withOpacity(0.2) : context.bgCard,
                                border: Border.all(color: isFound ? Colors.green : context.textMuted.withOpacity(0.3), width: 1.5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isFound ? Icons.check_circle : Icons.help_outline_rounded,
                                    color: isFound ? Colors.green : context.textMuted,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isFound ? word : word.replaceAll(RegExp(r'.'), '_ '),
                                    style: GoogleFonts.outfit(
                                      color: isFound ? Colors.green.shade200 : context.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: isFound ? 0.0 : 2.0,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 32),
                        // Current word spelling
                        Container(
                          height: 48,
                          alignment: Alignment.center,
                          child: Text(
                            _currentWord.isEmpty ? 'Tap letters below' : _currentWord,
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: _currentWord.isEmpty ? context.textMuted : context.textPrimary,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Salad Bowl layout of letters in circle
                        Container(
                          width: bowlSize,
                          height: bowlSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: context.bgCard,
                            border: Border.all(color: context.textMuted.withOpacity(0.3), width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Stack(
                            children: List.generate(level.letters.length, (idx) {
                              final letter = level.letters[idx];
                              final angle = (idx * 2 * pi) / level.letters.length;
                              final radius = (bowlSize / 2) - 36.0;
                              final x = (bowlSize / 2) + radius * cos(angle) - 24.0;
                              final y = (bowlSize / 2) + radius * sin(angle) - 24.0;
                              
                              final isSelected = _selectedIndices.contains(idx);

                              return Positioned(
                                left: x,
                                top: y,
                                child: GestureDetector(
                                  onTap: () => _selectLetter(idx, letter),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected ? Colors.amber.shade700 : context.bgDark,
                                      border: Border.all(
                                        color: isSelected ? Colors.amber : context.textMuted.withOpacity(0.3),
                                        width: 2,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      letter,
                                      style: GoogleFonts.outfit(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? Colors.white : context.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Action buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton.icon(
                              onPressed: _clearSelection,
                              icon: const Icon(Icons.clear, color: Colors.redAccent),
                              label: Text('Clear', style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 32),
                            ElevatedButton.icon(
                              onPressed: _submitWord,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              icon: const Icon(Icons.send),
                              label: Text('Submit', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isSuccess)
            ChallengeClearedOverlay(
              accentColor: Colors.amber,
              onComplete: _nextLevel,
            ),
        ],
      ),
    );
  }
}
