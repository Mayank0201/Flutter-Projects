import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/auto_next_countdown.dart';

class ChessPuzzlesBetaScreen extends StatefulWidget {
  const ChessPuzzlesBetaScreen({super.key});
  @override
  State<ChessPuzzlesBetaScreen> createState() => _ChessPuzzlesBetaScreenState();
}
class _ChessPuzzlesBetaScreenState extends State<ChessPuzzlesBetaScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  List<String> _board = List.filled(16, ""); // 4x4 Chess board
  int _selectedIdx = -1;
  int _targetMoveStart = -1;
  int _targetMoveEnd = -1;

  @override
  void initState() {
    super.initState();
    _loadLevel();
  }
  void _loadLevel() {
    setState(() {
      _isSuccess = false;
      _selectedIdx = -1;
      _board = List.filled(16, "");
      if (_currentLevel == 0) {
        // Rook captures King
        _board[12] = "WR"; _board[0] = "BK";
        _targetMoveStart = 12; _targetMoveEnd = 0;
      } else if (_currentLevel == 1) {
        // Queen captures King
        _board[15] = "WQ"; _board[3] = "BK";
        _targetMoveStart = 15; _targetMoveEnd = 3;
      } else if (_currentLevel == 2) {
        // Knight checks King
        _board[14] = "WN"; _board[1] = "BK";
        _targetMoveStart = 14; _targetMoveEnd = 8;
      } else if (_currentLevel == 3) {
        // Bishop captures King
        _board[13] = "WB"; _board[7] = "BK";
        _targetMoveStart = 13; _targetMoveEnd = 7;
      } else if (_currentLevel == 4) {
        // Pawn captures King
        _board[13] = "WP"; _board[8] = "BK";
        _targetMoveStart = 13; _targetMoveEnd = 8;
      } else if (_currentLevel == 5) {
        // Rook captures King (level 5)
        _board[12] = "WR"; _board[0] = "BK";
        _targetMoveStart = 12; _targetMoveEnd = 0;
      } else if (_currentLevel == 6) {
        // Queen captures King (level 6)
        _board[15] = "WQ"; _board[3] = "BK";
        _targetMoveStart = 15; _targetMoveEnd = 3;
      } else if (_currentLevel == 7) {
        // Knight checks King (level 7)
        _board[14] = "WN"; _board[1] = "BK";
        _targetMoveStart = 14; _targetMoveEnd = 8;
      } else if (_currentLevel == 8) {
        // Bishop captures King (level 8)
        _board[13] = "WB"; _board[7] = "BK";
        _targetMoveStart = 13; _targetMoveEnd = 7;
      } else {
        // Pawn captures King (level 9)
        _board[13] = "WP"; _board[8] = "BK";
        _targetMoveStart = 13; _targetMoveEnd = 8;
      }
    });
  }
  Future<void> _onLevelCleared() async {
    final prefs = await SharedPreferences.getInstance();
    int highest = prefs.getInt('beta_level_chesspuzzles') ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt('beta_level_chesspuzzles', _currentLevel + 1);
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

  String _getChessPieceSymbol(String code) {
    switch (code) {
      case "WK": return "♔";
      case "WQ": return "♕";
      case "WR": return "♖";
      case "WB": return "♗";
      case "WN": return "♘";
      case "WP": return "♙";
      case "BK": return "♚";
      case "BQ": return "♛";
      case "BR": return "♜";
      case "BB": return "♝";
      case "BN": return "♞";
      case "BP": return "♟";
      default: return "";
    }
  }

  void _showHint() {
    setState(() {
      _selectedIdx = _targetMoveStart;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Hint: Move the white piece at row ${(_targetMoveStart ~/ 4) + 1}, col ${(_targetMoveStart % 4) + 1}!'),
      ));
    });
  }

  String _getLevelGoal() {
    switch (_currentLevel) {
      case 0: return "Move the White Rook to capture the Black King.";
      case 1: return "Move the White Queen to capture the Black King.";
      case 2: return "Move the White Knight to check the Black King.";
      case 3: return "Move the White Bishop to capture the Black King.";
      case 4: return "Move the White Pawn to capture the Black King.";
      case 5: return "Move the White Rook to capture the Black King.";
      case 6: return "Move the White Queen to capture the Black King.";
      case 7: return "Move the White Knight to check the Black King.";
      case 8: return "Move the White Bishop to capture the Black King.";
      case 9: return "Move the White Pawn to capture the Black King.";
      default: return "Find the winning chess move.";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text('Chess Puzzles', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
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
                        Text(_getLevelGoal(), style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: context.textSecondary), textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        RepaintBoundary(
                          child: Container(
                            width: 280, height: 280,
                            decoration: BoxDecoration(color: context.bgCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.textMuted.withAlpha(40))),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4),
                            itemCount: 16,
                            itemBuilder: (context, idx) {
                              int r = idx ~/ 4; int c = idx % 4;
                              Color tileColor = (r + c) % 2 == 0 ? Colors.grey.shade300 : Colors.grey.shade600;
                              if (_selectedIdx == idx) tileColor = Colors.teal.shade300;
                              String piece = _board[idx];
                              return GestureDetector(
                                onTap: () {
                                  if (_selectedIdx == -1) {
                                    if (piece.startsWith("W")) {
                                      setState(() => _selectedIdx = idx);
                                    }
                                  } else {
                                    if (_selectedIdx == idx) {
                                      setState(() => _selectedIdx = -1);
                                    } else {
                                      if (_selectedIdx == _targetMoveStart && idx == _targetMoveEnd) {
                                        setState(() {
                                          _board[idx] = _board[_selectedIdx];
                                          _board[_selectedIdx] = "";
                                          _selectedIdx = -1;
                                        });
                                        _onLevelCleared();
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect move! Try again.')));
                                        setState(() => _selectedIdx = -1);
                                      }
                                    }
                                  }
                                },
                                child: Container(
                                  color: tileColor,
                                  child: Center(
                                    child: piece.isNotEmpty
                                        ? Text(
                                            _getChessPieceSymbol(piece),
                                            style: GoogleFonts.spaceGrotesk(
                                              fontSize: 36,
                                              fontWeight: FontWeight.bold,
                                              color: piece.startsWith("W") ? Colors.white : Colors.black,
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                              );
                            },
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
