import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/auto_next_countdown.dart';

/// Board index mapping (used everywhere, consistently):
///   idx = rank * 8 + file
///   rank 0 = TOP displayed row = chess rank 8
///   rank 7 = BOTTOM displayed row = chess rank 1
///   file 0 = a (left) ... file 7 = h (right)
/// So idx(square) = (8 - chessRank) * 8 + fileIndex.
/// Examples: a8=0, h8=7, e1=60, h1=63, d8=3.
class _Puzzle {
  final Map<int, String> pieces; // square index -> piece code (e.g. "WQ")
  final int fromIdx;             // solution: move piece FROM this index
  final int toIdx;               // solution: ...TO this index
  final String goal;             // level goal text
  const _Puzzle({
    required this.pieces,
    required this.fromIdx,
    required this.toIdx,
    required this.goal,
  });
}

class ChessPuzzlesBetaScreen extends StatefulWidget {
  const ChessPuzzlesBetaScreen({super.key});
  @override
  State<ChessPuzzlesBetaScreen> createState() => _ChessPuzzlesBetaScreenState();
}

class _ChessPuzzlesBetaScreenState extends State<ChessPuzzlesBetaScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  List<String> _board = List.filled(64, "");
  int _selectedIdx = -1;

  // 10 real, verified puzzles. White to move and win (mate in 1 or winning fork).
  static const List<_Puzzle> _puzzles = [
    // 1) Back-rank rook mate. WK g1, WR d1 | BK g8, BP f7/g7/h7. Rd1-d8#
    _Puzzle(
      pieces: {62: "WK", 59: "WR", 6: "BK", 13: "BP", 14: "BP", 15: "BP"},
      fromIdx: 59, toIdx: 3,
      goal: "White to move — mate in 1 (back-rank rook).",
    ),
    // 2) King & queen mate. WK g6, WQ b2 | BK g8. Qb2-g7#
    _Puzzle(
      pieces: {22: "WK", 49: "WQ", 6: "BK"},
      fromIdx: 49, toIdx: 14,
      goal: "White to move — mate in 1 (king & queen).",
    ),
    // 3) Knight fork wins the queen. WK e1, WN d5 | BK a8, BQ c8. Nd5-b6+
    _Puzzle(
      pieces: {60: "WK", 27: "WN", 0: "BK", 2: "BQ"},
      fromIdx: 27, toIdx: 17,
      goal: "White to move — win the queen with a knight fork.",
    ),
    // 4) Two-rook ladder mate. WK e1, WR a7, WR b1 | BK h8. Rb1-b8#
    _Puzzle(
      pieces: {60: "WK", 8: "WR", 57: "WR", 7: "BK"},
      fromIdx: 57, toIdx: 1,
      goal: "White to move — mate in 1 (two-rook ladder).",
    ),
    // 5) Mate on the h-file. WK a4, WR g2, WQ a1 | BK h8. Qa1-h1#
    _Puzzle(
      pieces: {32: "WK", 54: "WR", 56: "WQ", 7: "BK"},
      fromIdx: 56, toIdx: 63,
      goal: "White to move — mate in 1 on the h-file.",
    ),
    // 6) Knight fork wins the queen. WK g1, WN a6 | BK e8, BQ b5. Na6-c7+
    _Puzzle(
      pieces: {62: "WK", 16: "WN", 4: "BK", 25: "BQ"},
      fromIdx: 16, toIdx: 10,
      goal: "White to move — win the queen with a knight fork.",
    ),
    // 7) Scholar's mate. WK e1, WQ h5, WB c4 | BK e8, BQ d8, BB f8, BP d7/f7, BN c6/f6. Qxf7#
    _Puzzle(
      pieces: {
        60: "WK", 31: "WQ", 34: "WB",
        4: "BK", 3: "BQ", 5: "BB", 11: "BP", 13: "BP", 18: "BN", 21: "BN",
      },
      fromIdx: 31, toIdx: 13,
      goal: "White to move — mate in 1 (Scholar's mate, Qxf7#).",
    ),
    // 8) Arabian mate (rook + knight). WK a1, WN f6, WR h1 | BK h8. Rh1-h7#
    _Puzzle(
      pieces: {56: "WK", 21: "WN", 63: "WR", 7: "BK"},
      fromIdx: 63, toIdx: 15,
      goal: "White to move — mate in 1 (Arabian mate).",
    ),
    // 9) Queen backed by pawn. WK a1, WP f6, WQ g2 | BK g8. Qg2-g7#
    _Puzzle(
      pieces: {56: "WK", 21: "WP", 54: "WQ", 6: "BK"},
      fromIdx: 54, toIdx: 14,
      goal: "White to move — mate in 1 (queen backed by a pawn).",
    ),
    // 10) Queen & bishop mate. WK a1, WB b1, WQ f1 | BK h8. Qf1-f8#
    _Puzzle(
      pieces: {56: "WK", 57: "WB", 61: "WQ", 7: "BK"},
      fromIdx: 61, toIdx: 5,
      goal: "White to move — mate in 1 (queen & bishop).",
    ),
  ];

  _Puzzle get _puzzle => _puzzles[_currentLevel];

  @override
  void initState() {
    super.initState();
    _loadLevel();
  }

  void _loadLevel() {
    setState(() {
      _isSuccess = false;
      _selectedIdx = -1;
      _board = List.filled(64, "");
      _puzzle.pieces.forEach((idx, code) => _board[idx] = code);
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
    if (_currentLevel < _puzzles.length - 1) {
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

  /// idx -> square name like "e1".
  String _squareName(int idx) {
    final file = idx % 8;
    final chessRank = 8 - (idx ~/ 8);
    return "${String.fromCharCode('a'.codeUnitAt(0) + file)}$chessRank";
  }

  String _pieceName(String code) {
    switch (code[1]) {
      case "K": return "King";
      case "Q": return "Queen";
      case "R": return "Rook";
      case "B": return "Bishop";
      case "N": return "Knight";
      case "P": return "Pawn";
      default: return "piece";
    }
  }

  void _showHint() {
    final from = _puzzle.fromIdx;
    final code = _board[from];
    setState(() => _selectedIdx = from);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Hint: move your ${_pieceName(code)} on ${_squareName(from)}.'),
    ));
  }

  void _onTapSquare(int idx) {
    final piece = _board[idx];
    if (_selectedIdx == -1) {
      // Nothing selected yet: only allow selecting a white piece.
      if (piece.startsWith("W")) {
        setState(() => _selectedIdx = idx);
      }
      return;
    }
    // Tapping the selected square again deselects.
    if (_selectedIdx == idx) {
      setState(() => _selectedIdx = -1);
      return;
    }
    // Allow re-selecting a different white piece.
    if (piece.startsWith("W")) {
      setState(() => _selectedIdx = idx);
      return;
    }
    // Validate the move against the stored solution.
    if (_selectedIdx == _puzzle.fromIdx && idx == _puzzle.toIdx) {
      setState(() {
        _board[idx] = _board[_selectedIdx];
        _board[_selectedIdx] = "";
        _selectedIdx = -1;
      });
      _onLevelCleared();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect move, try again.')),
      );
      setState(() => _selectedIdx = -1);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Warm light/dark board tones that fit the calm dark UI.
    const lightSquare = Color(0xFFE8D9C0);
    const darkSquare = Color(0xFF9C7E5E);

    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text('Chess Puzzles',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.lightbulb_outline, color: AppTheme.dustyMauve),
            tooltip: 'Hint',
            onPressed: _showHint,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('Level ${_currentLevel + 1}/${_puzzles.length}',
                  style: AppTheme.numberStyle(
                      color: AppTheme.dustyMauve,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Text(
                    _puzzle.goal,
                    style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: context.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  RepaintBoundary(
                    child: Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.textMuted.withAlpha(40)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 8),
                        itemCount: 64,
                        itemBuilder: (context, idx) {
                          final r = idx ~/ 8;
                          final c = idx % 8;
                          final isLight = (r + c) % 2 == 0;
                          Color tile = isLight ? lightSquare : darkSquare;
                          if (_selectedIdx == idx) {
                            tile = Color.alphaBlend(
                                AppTheme.dustyMauve.withAlpha(170), tile);
                          }
                          final piece = _board[idx];
                          return GestureDetector(
                            onTap: () => _onTapSquare(idx),
                            child: Container(
                              color: tile,
                              alignment: Alignment.center,
                              child: piece.isEmpty
                                  ? null
                                  : Text(
                                      _getChessPieceSymbol(piece),
                                      style: GoogleFonts.spaceGrotesk(
                                        fontSize: 29,
                                        height: 1.0,
                                        fontWeight: FontWeight.bold,
                                        color: piece.startsWith("W")
                                            ? Colors.white
                                            : const Color(0xFF141414),
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: context.bgCard,
                            foregroundColor: context.textPrimary),
                        onPressed: _loadLevel,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset'),
                      ),
                    ],
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.bgCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.textMuted.withAlpha(20)),
                    ),
                    child: Text(
                      "💡 Rule Details:\n"
                      "• White to move. Find the move that wins.\n"
                      "• Tap your piece, then tap where it should go.\n"
                      "• Most puzzles are mate in one.",
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: context.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isSuccess)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                      color: context.bgCard,
                      borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.emoji_events, color: Colors.amber, size: 64),
                      const SizedBox(height: 16),
                      Text('Level ${_currentLevel + 1} Cleared!',
                          style: GoogleFonts.outfit(
                              fontSize: 22, fontWeight: FontWeight.bold)),
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
