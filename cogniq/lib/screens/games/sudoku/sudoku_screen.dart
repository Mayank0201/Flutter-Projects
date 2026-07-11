import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cogniq/widgets/buy_hints_dialog.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/audio_manager.dart';
import '../../../utils/hint_manager.dart';
import '../../../utils/rules_helper.dart';
import '../../../widgets/auto_next_countdown.dart';
import '../../../widgets/fog_overlay.dart';
import '../../../widgets/challenge_cleared_overlay.dart';
import '../../../widgets/loss_overlay.dart';
import '../../../utils/shuffle_manager.dart';
class SudokuLevel {
  final int size; // 4, 6, or 9
  final List<List<int>> startBoard;
  final List<List<int>> solution;
  const SudokuLevel({
    required this.size,
    required this.startBoard,
    required this.solution,
  });
}

const List<SudokuLevel> _kLevels = [
  // Easy (4x4)
  SudokuLevel(
    size: 4,
    startBoard: [
      [0, 2, 4, 0],
      [1, 0, 0, 3],
      [4, 0, 0, 2],
      [0, 1, 3, 0],
    ],
    solution: [
      [3, 2, 4, 1],
      [1, 4, 2, 3],
      [4, 3, 1, 2],
      [2, 1, 3, 4],
    ],
  ),
  SudokuLevel(
    size: 4,
    startBoard: [
      [4, 0, 0, 2],
      [0, 1, 3, 0],
      [0, 4, 2, 0],
      [3, 0, 0, 1],
    ],
    solution: [
      [4, 3, 1, 2],
      [2, 1, 3, 4],
      [1, 4, 2, 3],
      [3, 2, 4, 1],
    ],
  ),
  SudokuLevel(
    size: 4,
    startBoard: [
      [0, 1, 3, 0],
      [4, 0, 0, 2],
      [3, 0, 0, 1],
      [0, 4, 2, 0],
    ],
    solution: [
      [2, 1, 3, 4],
      [4, 3, 1, 2],
      [3, 2, 4, 1],
      [1, 4, 2, 3],
    ],
  ),
  SudokuLevel(
    size: 4,
    startBoard: [
      [1, 0, 0, 3],
      [0, 2, 4, 0],
      [0, 1, 3, 0],
      [4, 0, 0, 2],
    ],
    solution: [
      [1, 4, 2, 3],
      [3, 2, 4, 1],
      [2, 1, 3, 4],
      [4, 3, 1, 2],
    ],
  ),
  SudokuLevel(
    size: 4,
    startBoard: [
      [4, 0, 2, 0],
      [0, 2, 0, 4],
      [2, 0, 1, 0],
      [0, 1, 0, 2],
    ],
    solution: [
      [4, 3, 2, 1],
      [1, 2, 3, 4],
      [2, 4, 1, 3],
      [3, 1, 4, 2],
    ],
  ),
  SudokuLevel(
    size: 4,
    startBoard: [
      [0, 2, 3, 0],
      [4, 0, 0, 1],
      [3, 0, 0, 2],
      [0, 4, 1, 0],
    ],
    solution: [
      [1, 2, 3, 4],
      [4, 3, 2, 1],
      [3, 1, 4, 2],
      [2, 4, 1, 3],
    ],
  ),

  // Medium (6x6)
  SudokuLevel(
    size: 6,
    startBoard: [
      [2, 1, 3, 4, 6, 5],
      [5, 4, 6, 1, 3, 2],
      [3, 2, 4, 5, 1, 6],
      [6, 5, 1, 2, 4, 3],
      [4, 3, 5, 6, 2, 1],
      [1, 6, 2, 3, 5, 4],
    ],
    solution: [
      [2, 1, 3, 4, 6, 5],
      [5, 4, 6, 1, 3, 2],
      [3, 2, 4, 5, 1, 6],
      [6, 5, 1, 2, 4, 3],
      [4, 3, 5, 6, 2, 1],
      [1, 6, 2, 3, 5, 4],
    ],
  ),
  SudokuLevel(
    size: 6,
    startBoard: [
      [3, 0, 4, 0, 1, 0],
      [0, 5, 0, 2, 0, 3],
      [4, 0, 5, 0, 2, 0],
      [0, 6, 0, 3, 0, 4],
      [5, 0, 6, 0, 3, 0],
      [0, 1, 0, 4, 0, 5],
    ],
    solution: [
      [3, 2, 4, 5, 1, 6],
      [6, 5, 1, 2, 4, 3],
      [4, 3, 5, 6, 2, 1],
      [1, 6, 2, 3, 5, 4],
      [5, 4, 6, 1, 3, 2],
      [2, 1, 3, 4, 6, 5],
    ],
  ),
  SudokuLevel(
    size: 6,
    startBoard: [
      [0, 3, 0, 6, 2, 0],
      [1, 0, 2, 0, 0, 4],
      [0, 4, 6, 0, 3, 0],
      [2, 0, 0, 4, 0, 5],
      [6, 0, 1, 0, 4, 0],
      [0, 2, 0, 5, 0, 6],
    ],
    solution: [
      [4, 3, 5, 6, 2, 1],
      [1, 6, 2, 3, 5, 4],
      [5, 4, 6, 1, 3, 2],
      [2, 1, 3, 4, 6, 5],
      [6, 5, 1, 2, 4, 3],
      [3, 2, 4, 5, 1, 6],
    ],
  ),
  SudokuLevel(
    size: 6,
    startBoard: [
      [5, 0, 6, 0, 3, 0],
      [0, 1, 0, 4, 0, 5],
      [6, 0, 1, 0, 4, 0],
      [0, 2, 0, 5, 0, 6],
      [1, 0, 2, 0, 5, 0],
      [0, 3, 0, 6, 0, 1],
    ],
    solution: [
      [5, 4, 6, 1, 3, 2],
      [2, 1, 3, 4, 6, 5],
      [6, 5, 1, 2, 4, 3],
      [3, 2, 4, 5, 1, 6],
      [1, 6, 2, 3, 5, 4],
      [4, 3, 5, 6, 2, 1],
    ],
  ),
  SudokuLevel(
    size: 6,
    startBoard: [
      [0, 5, 0, 2, 0, 3],
      [3, 0, 4, 0, 1, 0],
      [0, 6, 0, 3, 0, 4],
      [4, 0, 5, 0, 2, 0],
      [0, 1, 0, 4, 0, 5],
      [5, 0, 6, 0, 3, 0],
    ],
    solution: [
      [6, 5, 1, 2, 4, 3],
      [3, 2, 4, 5, 1, 6],
      [1, 6, 2, 3, 5, 4],
      [4, 3, 5, 6, 2, 1],
      [2, 1, 3, 4, 6, 5],
      [5, 4, 6, 1, 3, 2],
    ],
  ),
  SudokuLevel(
    size: 6,
    startBoard: [
      [1, 0, 2, 0, 5, 0],
      [0, 3, 0, 6, 0, 1],
      [2, 0, 3, 0, 6, 0],
      [0, 4, 0, 1, 0, 2],
      [3, 0, 4, 0, 1, 0],
      [0, 5, 0, 2, 0, 3],
    ],
    solution: [
      [1, 6, 2, 3, 5, 4],
      [4, 3, 5, 6, 2, 1],
      [2, 1, 3, 4, 6, 5],
      [5, 4, 6, 1, 3, 2],
      [3, 2, 4, 5, 1, 6],
      [6, 5, 1, 2, 4, 3],
    ],
  ),
  SudokuLevel(
    size: 6,
    startBoard: [
      [0, 1, 0, 6, 0, 3],
      [3, 0, 4, 0, 2, 0],
      [0, 5, 0, 3, 0, 4],
      [4, 0, 1, 0, 6, 0],
      [0, 2, 0, 4, 0, 1],
      [1, 0, 5, 0, 3, 0],
    ],
    solution: [
      [5, 1, 2, 6, 4, 3],
      [3, 6, 4, 1, 2, 5],
      [2, 5, 6, 3, 1, 4],
      [4, 3, 1, 5, 6, 2],
      [6, 2, 3, 4, 5, 1],
      [1, 4, 5, 2, 3, 6],
    ],
  ),
  SudokuLevel(
    size: 6,
    startBoard: [
      [6, 0, 3, 0, 5, 0],
      [0, 1, 0, 2, 0, 6],
      [3, 0, 1, 0, 2, 0],
      [0, 4, 0, 6, 0, 3],
      [1, 0, 4, 0, 6, 0],
      [0, 5, 0, 3, 0, 1],
    ],
    solution: [
      [6, 2, 3, 1, 5, 4],
      [4, 1, 5, 2, 3, 6],
      [3, 6, 1, 4, 2, 5],
      [5, 4, 2, 6, 1, 3],
      [1, 3, 4, 5, 6, 2],
      [2, 5, 6, 3, 4, 1],
    ],
  ),

  // Hard (9x9)
  SudokuLevel(
    size: 9,
    startBoard: [
      [5, 3, 0, 0, 7, 0, 0, 0, 0],
      [6, 0, 0, 1, 9, 5, 0, 0, 0],
      [0, 9, 8, 0, 0, 0, 0, 6, 0],
      [8, 0, 0, 0, 6, 0, 0, 0, 3],
      [4, 0, 0, 8, 0, 3, 0, 0, 1],
      [7, 0, 0, 0, 2, 0, 0, 0, 6],
      [0, 6, 0, 0, 0, 0, 2, 8, 0],
      [0, 0, 0, 4, 1, 9, 0, 0, 5],
      [0, 0, 0, 0, 8, 0, 0, 7, 9],
    ],
    solution: [
      [5, 3, 4, 6, 7, 8, 9, 1, 2],
      [6, 7, 2, 1, 9, 5, 3, 4, 8],
      [1, 9, 8, 3, 4, 2, 5, 6, 7],
      [8, 5, 9, 7, 6, 1, 4, 2, 3],
      [4, 2, 6, 8, 5, 3, 7, 9, 1],
      [7, 1, 3, 9, 2, 4, 8, 5, 6],
      [9, 6, 1, 5, 3, 7, 2, 8, 4],
      [2, 8, 7, 4, 1, 9, 6, 3, 5],
      [3, 4, 5, 2, 8, 6, 1, 7, 9],
    ],
  ),
  SudokuLevel(
    size: 9,
    startBoard: [
      [6, 0, 0, 7, 8, 0, 1, 0, 0],
      [0, 8, 3, 0, 0, 6, 4, 0, 9],
      [2, 0, 0, 4, 5, 0, 0, 7, 0],
      [0, 6, 1, 0, 0, 2, 5, 0, 4],
      [5, 0, 0, 9, 0, 4, 0, 1, 2],
      [8, 0, 4, 1, 0, 0, 9, 6, 0],
      [0, 7, 0, 0, 4, 8, 0, 0, 5],
      [3, 0, 8, 5, 0, 0, 7, 4, 0],
      [0, 0, 6, 0, 9, 7, 0, 0, 1],
    ],
    solution: [
      [6, 4, 5, 7, 8, 9, 1, 2, 3],
      [7, 8, 3, 2, 1, 6, 4, 5, 9],
      [2, 1, 9, 4, 5, 3, 6, 7, 8],
      [9, 6, 1, 8, 7, 2, 5, 3, 4],
      [5, 3, 7, 9, 6, 4, 8, 1, 2],
      [8, 2, 4, 1, 3, 5, 9, 6, 7],
      [1, 7, 2, 6, 4, 8, 3, 9, 5],
      [3, 9, 8, 5, 2, 1, 7, 4, 6],
      [4, 5, 6, 3, 9, 7, 2, 8, 1],
    ],
  ),
  SudokuLevel(
    size: 9,
    startBoard: [
      [7, 0, 6, 8, 0, 0, 2, 0, 4],
      [8, 9, 0, 0, 2, 7, 0, 6, 0],
      [0, 2, 0, 5, 0, 0, 7, 0, 9],
      [1, 0, 2, 0, 8, 3, 0, 4, 0],
      [6, 0, 0, 1, 0, 5, 0, 2, 3],
      [0, 3, 5, 2, 4, 0, 1, 0, 0],
      [2, 0, 3, 0, 5, 9, 0, 1, 0],
      [0, 1, 0, 6, 0, 0, 8, 5, 7],
      [5, 0, 7, 0, 0, 8, 3, 0, 2],
    ],
    solution: [
      [7, 5, 6, 8, 9, 1, 2, 3, 4],
      [8, 9, 4, 3, 2, 7, 5, 6, 1],
      [3, 2, 1, 5, 6, 4, 7, 8, 9],
      [1, 7, 2, 9, 8, 3, 6, 4, 5],
      [6, 4, 8, 1, 7, 5, 9, 2, 3],
      [9, 3, 5, 2, 4, 6, 1, 7, 8],
      [2, 8, 3, 7, 5, 9, 4, 1, 6],
      [4, 1, 9, 6, 3, 2, 8, 5, 7],
      [5, 6, 7, 4, 1, 8, 3, 9, 2],
    ],
  ),
  SudokuLevel(
    size: 9,
    startBoard: [
      [0, 6, 7, 0, 1, 2, 0, 4, 5],
      [9, 0, 5, 4, 0, 0, 6, 0, 2],
      [4, 0, 0, 6, 7, 0, 8, 9, 0],
      [2, 8, 0, 1, 0, 4, 0, 5, 0],
      [0, 5, 9, 0, 8, 6, 1, 0, 4],
      [1, 0, 6, 3, 0, 0, 2, 8, 0],
      [3, 9, 0, 8, 0, 1, 0, 2, 7],
      [0, 2, 1, 0, 4, 3, 9, 0, 0],
      [6, 0, 8, 5, 0, 9, 0, 1, 3],
    ],
    solution: [
      [8, 6, 7, 9, 1, 2, 3, 4, 5],
      [9, 1, 5, 4, 3, 8, 6, 7, 2],
      [4, 3, 2, 6, 7, 5, 8, 9, 1],
      [2, 8, 3, 1, 9, 4, 7, 5, 6],
      [7, 5, 9, 2, 8, 6, 1, 3, 4],
      [1, 4, 6, 3, 5, 7, 2, 8, 9],
      [3, 9, 4, 8, 6, 1, 5, 2, 7],
      [5, 2, 1, 7, 4, 3, 9, 6, 8],
      [6, 7, 8, 5, 2, 9, 4, 1, 3],
    ],
  ),
  SudokuLevel(
    size: 9,
    startBoard: [
      [9, 0, 8, 1, 0, 3, 4, 0, 6],
      [0, 2, 6, 0, 4, 9, 0, 8, 0],
      [5, 4, 0, 7, 0, 0, 9, 0, 2],
      [3, 0, 4, 0, 1, 5, 0, 6, 0],
      [8, 6, 0, 3, 9, 0, 2, 4, 5],
      [0, 5, 7, 4, 0, 8, 3, 0, 0],
      [4, 0, 5, 9, 0, 2, 0, 3, 8],
      [6, 3, 0, 0, 5, 0, 1, 0, 9],
      [7, 0, 9, 6, 3, 1, 0, 2, 4],
    ],
    solution: [
      [9, 7, 8, 1, 2, 3, 4, 5, 6],
      [1, 2, 6, 5, 4, 9, 7, 8, 3],
      [5, 4, 3, 7, 8, 6, 9, 1, 2],
      [3, 9, 4, 2, 1, 5, 8, 6, 7],
      [8, 6, 1, 3, 9, 7, 2, 4, 5],
      [2, 5, 7, 4, 6, 8, 3, 9, 1],
      [4, 1, 5, 9, 7, 2, 6, 3, 8],
      [6, 3, 2, 8, 5, 4, 1, 7, 9],
      [7, 8, 9, 6, 3, 1, 5, 2, 4],
    ],
  ),
  SudokuLevel(
    size: 9,
    startBoard: [
      [1, 0, 9, 2, 3, 0, 5, 0, 7],
      [0, 3, 7, 0, 5, 1, 0, 9, 0],
      [6, 5, 0, 8, 0, 7, 1, 0, 3],
      [4, 0, 5, 0, 2, 6, 0, 7, 8],
      [9, 7, 0, 4, 0, 8, 3, 5, 6],
      [3, 5, 8, 7, 6, 0, 4, 1, 0],
      [5, 2, 0, 1, 0, 3, 7, 0, 9],
      [0, 4, 3, 9, 6, 5, 0, 8, 1],
      [8, 9, 1, 0, 4, 2, 6, 3, 0],
    ],
    solution: [
      [1, 8, 9, 2, 3, 4, 5, 6, 7],
      [2, 3, 7, 6, 5, 1, 8, 9, 4],
      [6, 5, 4, 8, 9, 7, 1, 2, 3],
      [4, 1, 5, 3, 2, 6, 9, 7, 8],
      [9, 7, 2, 4, 1, 8, 3, 5, 6],
      [3, 5, 8, 7, 6, 9, 4, 1, 2],
      [5, 2, 6, 1, 8, 3, 7, 4, 9],
      [7, 4, 3, 9, 6, 5, 2, 8, 1],
      [8, 9, 1, 7, 4, 2, 6, 3, 5],
    ],
  ),
  SudokuLevel(
    size: 9,
    startBoard: [
      [2, 0, 1, 3, 0, 5, 6, 0, 8],
      [3, 4, 0, 7, 6, 0, 9, 1, 0],
      [7, 6, 5, 0, 1, 8, 0, 3, 4],
      [0, 2, 6, 4, 0, 7, 1, 0, 9],
      [1, 0, 3, 5, 2, 9, 0, 6, 7],
      [4, 7, 0, 8, 6, 1, 5, 2, 0],
      [6, 3, 7, 2, 0, 4, 8, 5, 0],
      [8, 5, 4, 0, 7, 6, 0, 9, 2],
      [0, 1, 2, 8, 5, 0, 7, 4, 6],
    ],
    solution: [
      [2, 9, 1, 3, 4, 5, 6, 7, 8],
      [3, 4, 8, 7, 6, 2, 9, 1, 5],
      [7, 6, 5, 9, 1, 8, 2, 3, 4],
      [5, 2, 6, 4, 3, 7, 1, 8, 9],
      [1, 8, 3, 5, 2, 9, 4, 6, 7],
      [4, 7, 9, 8, 6, 1, 5, 2, 3],
      [6, 3, 7, 2, 9, 4, 8, 5, 1],
      [8, 5, 4, 1, 7, 6, 3, 9, 2],
      [9, 1, 2, 8, 5, 3, 7, 4, 6],
    ],
  ),
  SudokuLevel(
    size: 9,
    startBoard: [
      [3, 0, 2, 4, 5, 0, 7, 0, 9],
      [0, 5, 9, 0, 7, 3, 1, 2, 0],
      [8, 7, 0, 1, 0, 9, 0, 4, 5],
      [6, 3, 7, 5, 4, 0, 2, 9, 1],
      [2, 0, 4, 6, 3, 1, 5, 0, 8],
      [5, 8, 1, 9, 0, 2, 6, 3, 4],
      [7, 0, 8, 3, 1, 5, 0, 6, 2],
      [9, 6, 5, 0, 8, 7, 4, 1, 0],
      [1, 0, 3, 7, 6, 4, 8, 0, 9],
    ],
    solution: [
      [3, 1, 2, 4, 5, 6, 7, 8, 9],
      [4, 5, 9, 8, 7, 3, 1, 2, 6],
      [8, 7, 6, 1, 2, 9, 3, 4, 5],
      [6, 3, 7, 5, 4, 8, 2, 9, 1],
      [2, 9, 4, 6, 3, 1, 5, 7, 8],
      [5, 8, 1, 9, 7, 2, 6, 3, 4],
      [7, 4, 8, 3, 1, 5, 9, 6, 2],
      [9, 6, 5, 2, 8, 7, 4, 1, 3],
      [1, 2, 3, 7, 6, 4, 8, 5, 9],
    ],
  ),
  SudokuLevel(
    size: 9,
    startBoard: [
      [0, 2, 3, 5, 6, 0, 8, 0, 1],
      [5, 6, 0, 9, 0, 4, 2, 3, 0],
      [9, 8, 7, 0, 3, 1, 0, 5, 6],
      [7, 0, 8, 6, 5, 0, 3, 1, 0],
      [3, 1, 5, 7, 0, 2, 6, 8, 9],
      [0, 9, 2, 8, 1, 3, 7, 0, 5],
      [8, 5, 9, 0, 2, 6, 0, 7, 3],
      [1, 7, 6, 3, 9, 0, 5, 2, 4],
      [2, 0, 4, 1, 7, 5, 9, 0, 8],
    ],
    solution: [
      [4, 2, 3, 5, 6, 7, 8, 9, 1],
      [5, 6, 1, 9, 8, 4, 2, 3, 7],
      [9, 8, 7, 2, 3, 1, 4, 5, 6],
      [7, 4, 8, 6, 5, 9, 3, 1, 2],
      [3, 1, 5, 7, 4, 2, 6, 8, 9],
      [6, 9, 2, 8, 1, 3, 7, 4, 5],
      [8, 5, 9, 4, 2, 6, 1, 7, 3],
      [1, 7, 6, 3, 9, 8, 5, 2, 4],
      [2, 3, 4, 1, 7, 5, 9, 6, 8],
    ],
  ),
  SudokuLevel(
    size: 9,
    startBoard: [
      [1, 6, 0, 3, 5, 0, 9, 0, 4],
      [3, 5, 4, 2, 0, 1, 6, 8, 0],
      [2, 9, 0, 6, 8, 4, 1, 3, 5],
      [7, 1, 9, 0, 3, 2, 8, 0, 6],
      [8, 4, 3, 7, 1, 0, 5, 9, 2],
      [5, 2, 0, 9, 4, 8, 7, 1, 3],
      [0, 3, 2, 1, 6, 5, 4, 0, 8],
      [4, 7, 5, 0, 2, 9, 3, 6, 1],
      [6, 8, 1, 4, 7, 0, 2, 5, 9],
    ],
    solution: [
      [1, 6, 8, 3, 5, 7, 9, 2, 4],
      [3, 5, 4, 2, 9, 1, 6, 8, 7],
      [2, 9, 7, 6, 8, 4, 1, 3, 5],
      [7, 1, 9, 5, 3, 2, 8, 4, 6],
      [8, 4, 3, 7, 1, 6, 5, 9, 2],
      [5, 2, 6, 9, 4, 8, 7, 1, 3],
      [9, 3, 2, 1, 6, 5, 4, 7, 8],
      [4, 7, 5, 8, 2, 9, 3, 6, 1],
      [6, 8, 1, 4, 7, 3, 2, 5, 9],
    ],
  ),
  SudokuLevel(
    size: 9,
    startBoard: [
      [1, 0, 3, 8, 6, 4, 2, 0, 7],
      [8, 6, 7, 0, 2, 1, 5, 3, 0],
      [9, 2, 0, 5, 3, 7, 0, 8, 6],
      [0, 1, 2, 6, 8, 9, 3, 7, 5],
      [3, 7, 8, 4, 0, 5, 6, 2, 9],
      [6, 9, 5, 2, 7, 3, 8, 1, 0],
      [2, 0, 9, 1, 5, 6, 7, 4, 3],
      [7, 4, 6, 3, 0, 8, 5, 2, 1],
      [5, 3, 1, 7, 4, 2, 9, 0, 8],
    ],
    solution: [
      [1, 5, 3, 8, 6, 4, 2, 9, 7],
      [8, 6, 7, 9, 2, 1, 5, 3, 4],
      [9, 2, 4, 5, 3, 7, 1, 8, 6],
      [4, 1, 2, 6, 8, 9, 3, 7, 5],
      [3, 7, 8, 4, 1, 5, 6, 2, 9],
      [6, 9, 5, 2, 7, 3, 8, 1, 4],
      [2, 8, 9, 1, 5, 6, 7, 4, 3],
      [7, 4, 6, 3, 9, 8, 5, 2, 1],
      [5, 3, 1, 7, 4, 2, 9, 6, 8],
    ],
  ),
  SudokuLevel(
    size: 9,
    startBoard: [
      [9, 0, 2, 7, 5, 3, 0, 8, 6],
      [7, 5, 6, 0, 1, 9, 4, 2, 0],
      [8, 1, 0, 4, 2, 6, 9, 7, 5],
      [3, 0, 1, 5, 7, 8, 2, 6, 4],
      [2, 6, 7, 3, 0, 4, 5, 1, 8],
      [5, 8, 4, 1, 6, 2, 3, 9, 0],
      [1, 7, 8, 9, 0, 5, 6, 3, 2],
      [6, 3, 5, 2, 8, 1, 7, 4, 9],
      [4, 2, 9, 0, 3, 7, 8, 5, 1],
    ],
    solution: [
      [9, 4, 2, 7, 5, 3, 1, 8, 6],
      [7, 5, 6, 8, 1, 9, 4, 2, 3],
      [8, 1, 3, 4, 2, 6, 9, 7, 5],
      [3, 9, 1, 5, 7, 8, 2, 6, 4],
      [2, 6, 7, 3, 9, 4, 5, 1, 8],
      [5, 8, 4, 1, 6, 2, 3, 9, 7],
      [1, 7, 8, 9, 4, 5, 6, 3, 2],
      [6, 3, 5, 2, 8, 1, 7, 4, 9],
      [4, 2, 9, 6, 3, 7, 8, 5, 1],
    ],
  ),
  // 10 new levels
  SudokuLevel(
    size: 4,
    startBoard: [
      [1, 0, 3, 0],
      [0, 4, 0, 2],
      [2, 0, 4, 0],
      [0, 1, 0, 3],
    ],
    solution: [
      [1, 2, 3, 4],
      [3, 4, 1, 2],
      [2, 3, 4, 1],
      [4, 1, 2, 3],
    ],
  ),
  SudokuLevel(
    size: 4,
    startBoard: [
      [0, 1, 0, 3],
      [2, 0, 4, 0],
      [0, 4, 0, 2],
      [1, 0, 3, 0],
    ],
    solution: [
      [4, 1, 2, 3],
      [2, 3, 4, 1],
      [3, 4, 1, 2],
      [1, 2, 3, 4],
    ],
  ),
  SudokuLevel(
    size: 4,
    startBoard: [
      [2, 0, 0, 3],
      [0, 3, 2, 0],
      [0, 2, 3, 0],
      [3, 0, 0, 2],
    ],
    solution: [
      [2, 4, 1, 3],
      [1, 3, 2, 4],
      [4, 2, 3, 1],
      [3, 1, 4, 2],
    ],
  ),
  SudokuLevel(
    size: 6,
    startBoard: [
      [1, 0, 3, 0, 5, 0],
      [0, 5, 0, 1, 0, 3],
      [0, 3, 0, 5, 0, 1],
      [5, 0, 1, 0, 3, 0],
      [3, 0, 5, 0, 1, 0],
      [0, 1, 0, 3, 0, 5],
    ],
    solution: [
      [1, 2, 3, 4, 5, 6],
      [4, 5, 6, 1, 2, 3],
      [2, 3, 4, 5, 6, 1],
      [5, 6, 1, 2, 3, 4],
      [3, 4, 5, 6, 1, 2],
      [6, 1, 2, 3, 4, 5],
    ],
  ),
  SudokuLevel(
    size: 6,
    startBoard: [
      [2, 0, 0, 0, 6, 1],
      [0, 6, 1, 2, 0, 0],
      [1, 0, 3, 4, 0, 0],
      [0, 5, 6, 0, 2, 0],
      [0, 0, 5, 6, 0, 2],
      [6, 1, 0, 0, 4, 0],
    ],
    solution: [
      [2, 3, 4, 5, 6, 1],
      [5, 6, 1, 2, 3, 4],
      [1, 2, 3, 4, 5, 6],
      [4, 5, 6, 1, 2, 3],
      [3, 4, 5, 6, 1, 2],
      [6, 1, 2, 3, 4, 5],
    ],
  ),
  SudokuLevel(
    size: 6,
    startBoard: [
      [0, 4, 5, 6, 0, 0],
      [6, 0, 2, 0, 4, 5],
      [2, 3, 0, 0, 6, 0],
      [0, 6, 1, 2, 0, 4],
      [0, 0, 3, 4, 5, 0],
      [4, 5, 0, 0, 2, 3],
    ],
    solution: [
      [3, 4, 5, 6, 1, 2],
      [6, 1, 2, 3, 4, 5],
      [2, 3, 4, 5, 6, 1],
      [5, 6, 1, 2, 3, 4],
      [1, 2, 3, 4, 5, 6],
      [4, 5, 6, 1, 2, 3],
    ],
  ),
  SudokuLevel(
    size: 9,
    startBoard: [
      [5, 3, 0, 0, 7, 0, 0, 0, 2],
      [6, 0, 0, 1, 0, 0, 0, 4, 8],
      [1, 0, 8, 0, 4, 0, 5, 0, 0],
      [0, 5, 0, 7, 0, 1, 0, 0, 3],
      [0, 0, 6, 0, 5, 0, 7, 0, 0],
      [7, 0, 0, 9, 0, 4, 0, 5, 0],
      [0, 0, 1, 0, 3, 0, 2, 0, 4],
      [2, 8, 0, 0, 0, 9, 0, 0, 5],
      [3, 0, 0, 0, 8, 0, 0, 7, 9],
    ],
    solution: [
      [5, 3, 4, 6, 7, 8, 9, 1, 2],
      [6, 7, 2, 1, 9, 5, 3, 4, 8],
      [1, 9, 8, 3, 4, 2, 5, 6, 7],
      [8, 5, 9, 7, 6, 1, 4, 2, 3],
      [4, 2, 6, 8, 5, 3, 7, 9, 1],
      [7, 1, 3, 9, 2, 4, 8, 5, 6],
      [9, 6, 1, 5, 3, 7, 2, 8, 4],
      [2, 8, 7, 4, 1, 9, 6, 3, 5],
      [3, 4, 5, 2, 8, 6, 1, 7, 9],
    ],
  ),
  SudokuLevel(
    size: 9,
    startBoard: [
      [5, 0, 0, 0, 7, 8, 9, 0, 0],
      [0, 7, 2, 0, 9, 0, 0, 4, 0],
      [1, 0, 0, 3, 0, 0, 0, 6, 7],
      [0, 5, 9, 0, 6, 0, 0, 2, 0],
      [4, 0, 0, 8, 0, 3, 0, 0, 1],
      [0, 1, 0, 0, 2, 0, 8, 5, 0],
      [9, 6, 0, 0, 0, 7, 0, 0, 4],
      [0, 8, 0, 0, 1, 0, 6, 3, 0],
      [0, 0, 5, 2, 8, 0, 0, 0, 9],
    ],
    solution: [
      [5, 3, 4, 6, 7, 8, 9, 1, 2],
      [6, 7, 2, 1, 9, 5, 3, 4, 8],
      [1, 9, 8, 3, 4, 2, 5, 6, 7],
      [8, 5, 9, 7, 6, 1, 4, 2, 3],
      [4, 2, 6, 8, 5, 3, 7, 9, 1],
      [7, 1, 3, 9, 2, 4, 8, 5, 6],
      [9, 6, 1, 5, 3, 7, 2, 8, 4],
      [2, 8, 7, 4, 1, 9, 6, 3, 5],
      [3, 4, 5, 2, 8, 6, 1, 7, 9],
    ],
  ),
  SudokuLevel(
    size: 9,
    startBoard: [
      [0, 3, 4, 6, 0, 0, 0, 1, 2],
      [6, 0, 0, 0, 9, 5, 3, 0, 0],
      [1, 9, 0, 3, 0, 0, 0, 6, 0],
      [8, 0, 9, 0, 6, 0, 4, 0, 3],
      [0, 2, 0, 8, 0, 3, 0, 9, 0],
      [7, 0, 3, 0, 2, 0, 8, 0, 6],
      [0, 6, 0, 0, 0, 7, 0, 8, 4],
      [2, 0, 7, 4, 0, 0, 6, 0, 5],
      [3, 4, 0, 0, 8, 6, 0, 7, 0],
    ],
    solution: [
      [5, 3, 4, 6, 7, 8, 9, 1, 2],
      [6, 7, 2, 1, 9, 5, 3, 4, 8],
      [1, 9, 8, 3, 4, 2, 5, 6, 7],
      [8, 5, 9, 7, 6, 1, 4, 2, 3],
      [4, 2, 6, 8, 5, 3, 7, 9, 1],
      [7, 1, 3, 9, 2, 4, 8, 5, 6],
      [9, 6, 1, 5, 3, 7, 2, 8, 4],
      [2, 8, 7, 4, 1, 9, 6, 3, 5],
      [3, 4, 5, 2, 8, 6, 1, 7, 9],
    ],
  ),
  SudokuLevel(
    size: 9,
    startBoard: [
      [5, 0, 0, 6, 7, 0, 0, 1, 2],
      [6, 7, 0, 1, 0, 5, 0, 4, 8],
      [1, 0, 8, 0, 4, 0, 5, 0, 7],
      [0, 5, 0, 7, 0, 1, 0, 2, 0],
      [4, 0, 6, 0, 0, 0, 7, 0, 1],
      [0, 1, 0, 9, 0, 4, 0, 5, 0],
      [9, 0, 1, 0, 3, 0, 2, 0, 4],
      [2, 8, 0, 4, 0, 9, 0, 3, 5],
      [3, 4, 0, 0, 8, 6, 0, 0, 9],
    ],
    solution: [
      [5, 3, 4, 6, 7, 8, 9, 1, 2],
      [6, 7, 2, 1, 9, 5, 3, 4, 8],
      [1, 9, 8, 3, 4, 2, 5, 6, 7],
      [8, 5, 9, 7, 6, 1, 4, 2, 3],
      [4, 2, 6, 8, 5, 3, 7, 9, 1],
      [7, 1, 3, 9, 2, 4, 8, 5, 6],
      [9, 6, 1, 5, 3, 7, 2, 8, 4],
      [2, 8, 7, 4, 1, 9, 6, 3, 5],
      [3, 4, 5, 2, 8, 6, 1, 7, 9],
    ],
  ),
  SudokuLevel(
    size: 4,
    startBoard: [
      [0, 2, 4, 0],
      [3, 0, 0, 1],
      [4, 0, 0, 2],
      [0, 3, 1, 0],
    ],
    solution: [
      [1, 2, 4, 3],
      [3, 4, 2, 1],
      [4, 1, 3, 2],
      [2, 3, 1, 4],
    ],
  ),
  SudokuLevel(
    size: 4,
    startBoard: [
      [2, 0, 0, 4],
      [0, 1, 3, 0],
      [0, 2, 4, 0],
      [3, 0, 0, 1],
    ],
    solution: [
      [2, 3, 1, 4],
      [4, 1, 3, 2],
      [1, 2, 4, 3],
      [3, 4, 2, 1],
    ],
  ),
  SudokuLevel(
    size: 4,
    startBoard: [
      [0, 4, 3, 0],
      [1, 0, 0, 2],
      [3, 0, 0, 4],
      [0, 1, 2, 0],
    ],
    solution: [
      [2, 4, 3, 1],
      [1, 3, 4, 2],
      [3, 2, 1, 4],
      [4, 1, 2, 3],
    ],
  ),
  SudokuLevel(
    size: 4,
    startBoard: [
      [1, 0, 0, 2],
      [0, 3, 4, 0],
      [0, 1, 2, 0],
      [4, 0, 0, 3],
    ],
    solution: [
      [1, 4, 3, 2],
      [2, 3, 4, 1],
      [3, 1, 2, 4],
      [4, 2, 1, 3],
    ],
  ),
  SudokuLevel(
    size: 4,
    startBoard: [
      [4, 0, 1, 0],
      [0, 1, 0, 4],
      [1, 0, 2, 0],
      [0, 2, 0, 1],
    ],
    solution: [
      [4, 3, 1, 2],
      [2, 1, 3, 4],
      [1, 4, 2, 3],
      [3, 2, 4, 1],
    ],
  ),
  SudokuLevel(
    size: 4,
    startBoard: [
      [4, 0, 2, 0],
      [0, 1, 0, 3],
      [0, 2, 0, 4],
      [1, 0, 3, 0],
    ],
    solution: [
      [4, 3, 2, 1],
      [2, 1, 4, 3],
      [3, 2, 1, 4],
      [1, 4, 3, 2],
    ],
  ),
  SudokuLevel(
    size: 4,
    startBoard: [
      [0, 2, 0, 4],
      [4, 0, 1, 0],
      [0, 1, 0, 3],
      [3, 0, 2, 0],
    ],
    solution: [
      [1, 2, 3, 4],
      [4, 3, 1, 2],
      [2, 1, 4, 3],
      [3, 4, 2, 1],
    ],
  ),
  SudokuLevel(
    size: 4,
    startBoard: [
      [2, 0, 0, 1],
      [0, 4, 2, 0],
      [0, 2, 4, 0],
      [1, 0, 0, 3],
    ],
    solution: [
      [2, 3, 1, 4],
      [1, 4, 2, 3],
      [3, 2, 4, 1],
      [4, 1, 3, 2],
    ],
  ),
  SudokuLevel(
    size: 4,
    startBoard: [
      [0, 0, 2, 1],
      [1, 2, 0, 0],
      [0, 0, 1, 2],
      [2, 1, 0, 0],
    ],
    solution: [
      [4, 3, 2, 1],
      [1, 2, 3, 4],
      [3, 4, 1, 2],
      [2, 1, 4, 3],
    ],
  ),
  SudokuLevel(
    size: 4,
    startBoard: [
      [0, 2, 3, 0],
      [4, 0, 0, 1],
      [1, 0, 0, 4],
      [0, 3, 2, 0],
    ],
    solution: [
      [4, 2, 3, 1],
      [3, 1, 2, 4],
      [1, 4, 3, 2],
      [2, 3, 1, 4],
    ],
  ),
  SudokuLevel(
    size: 6,
    startBoard: [
      [0, 3, 0, 6, 1, 0],
      [2, 0, 1, 0, 0, 4],
      [0, 4, 6, 0, 3, 0],
      [1, 0, 0, 4, 0, 5],
      [6, 0, 2, 0, 4, 0],
      [0, 1, 0, 5, 0, 6],
    ],
    solution: [
      [4, 3, 5, 6, 1, 2],
      [2, 6, 1, 3, 5, 4],
      [5, 4, 6, 2, 3, 1],
      [1, 2, 3, 4, 6, 5],
      [6, 5, 2, 1, 4, 3],
      [3, 1, 4, 5, 2, 6],
    ],
  ),
  SudokuLevel(
    size: 6,
    startBoard: [
      [5, 0, 6, 0, 4, 0],
      [0, 1, 0, 3, 0, 5],
      [6, 0, 1, 0, 3, 0],
      [0, 2, 0, 5, 0, 6],
      [1, 0, 2, 0, 5, 0],
      [0, 4, 0, 6, 0, 1],
    ],
    solution: [
      [5, 3, 6, 1, 4, 2],
      [2, 1, 4, 3, 6, 5],
      [6, 5, 1, 2, 3, 4],
      [4, 2, 3, 5, 1, 6],
      [1, 6, 2, 4, 5, 3],
      [3, 4, 5, 6, 2, 1],
    ],
  ),
  SudokuLevel(
    size: 6,
    startBoard: [
      [0, 5, 0, 2, 0, 6],
      [6, 0, 4, 0, 1, 0],
      [0, 1, 0, 6, 0, 4],
      [4, 0, 5, 0, 2, 0],
      [0, 1, 0, 4, 0, 5],
      [5, 0, 6, 0, 3, 0],
    ],
    solution: [
      [1, 5, 3, 2, 4, 6],
      [6, 2, 4, 5, 1, 3],
      [3, 1, 2, 6, 5, 4],
      [4, 6, 5, 1, 2, 3],
      [2, 3, 1, 4, 6, 5],
      [5, 4, 6, 3, 3, 2],
    ],
  ),
  SudokuLevel(
    size: 6,
    startBoard: [
      [1, 0, 5, 0, 2, 0],
      [0, 3, 0, 6, 0, 1],
      [5, 0, 3, 0, 6, 0],
      [0, 4, 0, 1, 0, 5],
      [3, 0, 4, 0, 1, 0],
      [0, 2, 0, 5, 0, 3],
    ],
    solution: [
      [1, 6, 5, 3, 2, 4],
      [4, 3, 2, 6, 5, 1],
      [5, 1, 3, 4, 6, 2],
      [2, 4, 6, 1, 3, 5],
      [3, 5, 4, 2, 1, 6],
      [6, 2, 1, 5, 4, 3],
    ],
  ),
  SudokuLevel(
    size: 6,
    startBoard: [
      [0, 1, 0, 3, 0, 6],
      [6, 0, 4, 0, 2, 0],
      [0, 5, 0, 6, 0, 4],
      [4, 0, 1, 0, 3, 0],
      [0, 2, 0, 4, 0, 1],
      [1, 0, 5, 0, 6, 0],
    ],
    solution: [
      [2, 1, 5, 3, 4, 6],
      [6, 3, 4, 1, 2, 5],
      [3, 5, 2, 6, 1, 4],
      [4, 6, 1, 5, 3, 2],
      [5, 2, 6, 4, 3, 1],
      [1, 4, 5, 2, 6, 3],
    ],
  ),
  SudokuLevel(
    size: 6,
    startBoard: [
      [1, 0, 2, 0, 5, 0],
      [0, 3, 0, 5, 0, 1],
      [2, 0, 3, 0, 5, 0],
      [0, 4, 0, 1, 0, 2],
      [3, 0, 4, 0, 1, 0],
      [0, 5, 0, 2, 0, 3],
    ],
    solution: [
      [1, 5, 2, 3, 6, 4],
      [4, 3, 6, 5, 2, 1],
      [2, 1, 3, 4, 6, 5],
      [5, 6, 6, 1, 3, 2],
      [3, 2, 4, 6, 1, 5],
      [6, 4, 1, 2, 5, 3],
    ],
  ),
  SudokuLevel(
    size: 6,
    startBoard: [
      [0, 3, 0, 5, 0, 6],
      [1, 0, 5, 0, 4, 0],
      [0, 4, 1, 0, 6, 0],
      [6, 0, 2, 0, 5, 0],
      [0, 5, 0, 6, 0, 4],
      [4, 0, 6, 0, 2, 0],
    ],
    solution: [
      [2, 3, 4, 5, 1, 6],
      [1, 6, 5, 2, 4, 3],
      [5, 4, 1, 3, 6, 2],
      [6, 1, 2, 4, 5, 3],
      [3, 5, 2, 6, 1, 4],
      [4, 2, 6, 1, 3, 5],
    ],
  ),
  SudokuLevel(
    size: 6,
    startBoard: [
      [5, 0, 3, 0, 6, 0],
      [0, 1, 0, 4, 0, 5],
      [3, 0, 1, 0, 4, 0],
      [0, 2, 0, 5, 0, 3],
      [1, 0, 2, 0, 5, 0],
      [0, 6, 0, 3, 0, 1],
    ],
    solution: [
      [5, 4, 3, 1, 6, 2],
      [2, 1, 6, 4, 3, 5],
      [3, 5, 1, 2, 4, 6],
      [6, 2, 4, 5, 1, 3],
      [1, 3, 2, 6, 5, 4],
      [4, 6, 5, 3, 2, 1],
    ],
  ),
  SudokuLevel(
    size: 6,
    startBoard: [
      [0, 5, 0, 2, 0, 3],
      [3, 0, 6, 0, 1, 0],
      [0, 4, 0, 3, 0, 6],
      [6, 0, 5, 0, 2, 0],
      [0, 1, 0, 6, 0, 5],
      [5, 0, 3, 0, 4, 0],
    ],
    solution: [
      [1, 5, 4, 2, 6, 3],
      [3, 2, 6, 5, 1, 4],
      [2, 4, 1, 3, 5, 6],
      [6, 3, 5, 4, 2, 1],
      [4, 1, 2, 6, 3, 5],
      [5, 6, 3, 1, 4, 2],
    ],
  ),
  SudokuLevel(
    size: 6,
    startBoard: [
      [3, 0, 1, 0, 4, 0],
      [0, 5, 0, 2, 0, 3],
      [1, 0, 5, 0, 2, 0],
      [0, 6, 0, 3, 0, 1],
      [5, 0, 6, 0, 3, 0],
      [0, 4, 0, 1, 0, 5],
    ],
    solution: [
      [3, 2, 1, 5, 4, 6],
      [6, 5, 4, 2, 1, 3],
      [1, 3, 5, 6, 2, 4],
      [4, 6, 2, 3, 5, 1],
      [5, 1, 6, 4, 3, 2],
      [2, 4, 3, 1, 6, 5],
    ],
  ),
];

class SudokuScreen extends StatefulWidget {
  final int? dailyLevelIndex;
  const SudokuScreen({super.key, this.dailyLevelIndex});
  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends State<SudokuScreen> {
  int _levelIndex = 0;
  late SudokuLevel _level;
  late List<List<int>> _board;
  int _selectedRow = -1;
  int _selectedCol = -1;
  String _message = '';
  bool _won = false;
  bool _playDailyMode = false;
  String _dailyModifierType = '';
  int _dailyGridSize = 9;
  double _dailyRadius = 1.5;
  Timer? _blackoutTimer;
  bool _isBlackout = false;
  int _blackoutCountdown = 30;
  int _correctPlacementsCount = 0;
  bool _gameOver = false;
  int _warpTimeLeft = 90;
  Timer? _warpTimer;

  bool _inRecallTest = false;
  bool _shuffleActive = false;
  bool _isScanPhase = true;
  int _recallTargetCount = 2;
  int _recallPlacedCount = 0;
  final Set<(int, int)> _recallCorrectSelections = {};
  final Set<(int, int)> _lockedRecallCells = {};



  @override
  void initState() {
    super.initState();
    // Default synchronous initialization to avoid LateInitializationError
    _level = _getSudokuLevel(0);
    _board = List.generate(_level.size, (r) => List.from(_level.startBoard[r]));
    _initLevel();
  }

  @override
  void dispose() {
    _blackoutTimer?.cancel();
    _warpTimer?.cancel();
    super.dispose();
  }

  void _startBlackoutTimer() {
    _blackoutTimer?.cancel();
    if (_playDailyMode && _dailyModifierType == 'eclipse') {
      _isScanPhase = true;
      _inRecallTest = false;
      _blackoutCountdown = 30;
      
      _blackoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_gameOver || _won) {
          timer.cancel();
          return;
        }
        setState(() {
          if (_isScanPhase) {
            if (_blackoutCountdown > 1) {
              _blackoutCountdown--;
            } else {
              _isScanPhase = false;
              _inRecallTest = true;
              _recallPlacedCount = 0;
              _recallCorrectSelections.clear();
              _selectedRow = -1;
              _selectedCol = -1;
              _message = 'Recall Phase! Place $_recallTargetCount numbers correctly.';
              
              // Hide all user-placed numbers that are not locked
              for (int r = 0; r < _level.size; r++) {
                for (int c = 0; c < _level.size; c++) {
                  if (_level.startBoard[r][c] == 0 && !_lockedRecallCells.contains((r, c))) {
                    _board[r][c] = 0;
                  }
                }
              }
              AudioManager.playClick();
            }
          }
        });
      });
    }
  }

  int _hintCount = 0;

  Future<void> _initLevel() async {
    _hintCount = await HintManager.getHints('sudoku');
    final prefs = await SharedPreferences.getInstance();
    _playDailyMode = prefs.getBool('play_daily_mode') ?? false;
    if (_playDailyMode) {
      _dailyModifierType = prefs.getString('daily_modifier_type') ?? '';
      final difficulty = prefs.getString('daily_modifier_difficulty') ?? 'Medium';
      if (difficulty.toLowerCase() == 'hard') {
        _dailyGridSize = 9;
      } else {
        _dailyGridSize = 6;
      }
      final extraParamsStr = prefs.getString('daily_modifier_extra_params') ?? '';
      if (extraParamsStr.isNotEmpty) {
        try {
          final extraParams = jsonDecode(extraParamsStr) as Map<String, dynamic>;
          if (extraParams.containsKey('radius')) {
            _dailyRadius = (extraParams['radius'] as num).toDouble();
          } else {
            _dailyRadius = 1.5;
          }
        } catch (_) {
          _dailyRadius = 1.5;
        }
      } else {
        _dailyRadius = 1.5;
      }
    } else {
      _dailyModifierType = '';
      _dailyGridSize = 9;
      _dailyRadius = 1.5;
    }

    if (!_playDailyMode) {
      Future.delayed(Duration.zero, () async {
        if (!mounted) return;
        final savedStateStr = prefs.getString('normal_sudoku_state');
        if (savedStateStr != null) {
          try {
            final data = jsonDecode(savedStateStr);
            if (data['levelIndex'] == _levelIndex) {
              final continueGame = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => AlertDialog(
                  backgroundColor: context.bgCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: context.textMuted.withAlpha(40)),
                  ),
                  title: Text(
                    'Continue Game?',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary),
                  ),
                  content: Text(
                    'We found a saved state for this level. Would you like to continue playing or start a new game?',
                    style: GoogleFonts.outfit(color: context.textSecondary),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx, false); // New Game
                      },
                      child: Text(
                        'New Game',
                        style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx, true); // Continue
                      },
                      child: Text(
                        'Continue',
                        style: GoogleFonts.outfit(color: AppTheme.dustyMauve, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ) ?? false;

              if (continueGame) {
                final List<dynamic> boardData = data['board'];
                final List<List<int>> loadedBoard = boardData.map((row) => List<int>.from(row)).toList();
                final List<dynamic>? startBoardData = data['startBoard'];
                final List<dynamic>? solutionData = data['solution'];
                setState(() {
                  _board = loadedBoard;
                  if (startBoardData != null && solutionData != null) {
                    final loadedStartBoard = startBoardData.map((row) => List<int>.from(row)).toList();
                    final loadedSolution = solutionData.map((row) => List<int>.from(row)).toList();
                    _level = SudokuLevel(
                      size: _level.size,
                      startBoard: loadedStartBoard,
                      solution: loadedSolution,
                    );
                  }
                  _correctPlacementsCount = data['correctPlacementsCount'] ?? 0;
                });
              } else {
                await _clearNormalState();
              }
            } else {
              await _clearNormalState();
            }
          } catch (_) {
            await _clearNormalState();
          }
        }
      });
    }

    if (widget.dailyLevelIndex != null) {
      if (mounted) {
        setState(() {
          _levelIndex = widget.dailyLevelIndex!;
          _loadLevel();
        });
      }
      return;
    }
    final savedLevel = prefs.getInt('level_sudoku') ?? 0;
    final active = await ShuffleManager.isActive();
 
    if (mounted) {
      setState(() {
        _shuffleActive = active;
        _levelIndex = savedLevel;
        _loadLevel();
      });
    }
  }

  Future<void> _saveNormalState() async {
    if (_playDailyMode || _won) return;
    final prefs = await SharedPreferences.getInstance();
    final state = {
      'board': _board,
      'levelIndex': _levelIndex,
      'startBoard': _level.startBoard,
      'solution': _level.solution,
      'correctPlacementsCount': _correctPlacementsCount,
    };
    await prefs.setString('normal_sudoku_state', jsonEncode(state));
  }

  Future<void> _clearNormalState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('normal_sudoku_state');
  }

  Future<void> _savePersistedLevel(int lvl) async {
    if (widget.dailyLevelIndex != null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('level_sudoku', lvl);
    final earned = await HintManager.onLevelCleared('sudoku');
    if (earned) {
      final newCount = await HintManager.getHints('sudoku');
      setState(() {
        _hintCount = newCount;
      });
      
    }
  }

  bool _isValidSudokuPlace(List<List<int>> board, int size, int r, int c, int val) {
    for (int col = 0; col < size; col++) {
      if (board[r][col] == val) return false;
    }
    for (int row = 0; row < size; row++) {
      if (board[row][c] == val) return false;
    }
    int boxRows, boxCols;
    if (size == 4) {
      boxRows = 2; boxCols = 2;
    } else if (size == 6) {
      boxRows = 2; boxCols = 3;
    } else {
      boxRows = 3; boxCols = 3;
    }
    int boxStartRow = (r ~/ boxRows) * boxRows;
    int boxStartCol = (c ~/ boxCols) * boxCols;
    for (int i = 0; i < boxRows; i++) {
      for (int j = 0; j < boxCols; j++) {
        if (board[boxStartRow + i][boxStartCol + j] == val) return false;
      }
    }
    return true;
  }

  bool _hasUniqueSolution(List<List<int>> board, int size) {
    int solutionCount = 0;
    bool solve(int row, int col) {
      if (row == size) {
        solutionCount++;
        return solutionCount > 1;
      }
      int nextRow = col == size - 1 ? row + 1 : row;
      int nextCol = col == size - 1 ? 0 : col + 1;
      if (board[row][col] != 0) {
        return solve(nextRow, nextCol);
      }
      for (int val = 1; val <= size; val++) {
        if (_isValidSudokuPlace(board, size, row, col, val)) {
          board[row][col] = val;
          if (solve(nextRow, nextCol)) {
            board[row][col] = 0;
            return true;
          }
          board[row][col] = 0;
        }
      }
      return false;
    }
    solve(0, 0);
    return solutionCount == 1;
  }

  SudokuLevel _getSudokuLevel(int index) {
    final List<SudokuLevel> levels4 = _kLevels.where((l) => l.size == 4).toList();
    final List<SudokuLevel> levels6 = _kLevels.where((l) => l.size == 6).toList();
    final List<SudokuLevel> levels9 = _kLevels.where((l) => l.size == 9).toList();

    SudokuLevel baseLevel;
    if (_playDailyMode) {
      if (_dailyGridSize == 6) {
        baseLevel = levels6[index % levels6.length];
      } else if (_dailyGridSize == 4) {
        baseLevel = levels4[index % levels4.length];
      } else {
        baseLevel = levels9[index % levels9.length];
      }
    } else {
      if (index < 10) {
        baseLevel = levels4[index % levels4.length];
      } else if (index < 25) {
        baseLevel = levels6[(index - 10) % levels6.length];
      } else {
        baseLevel = levels9[(index - 25) % levels9.length];
      }
    }

    final size = baseLevel.size;
    final rng = Random(index * 997);
    final digits = List.generate(size, (i) => i + 1)..shuffle(rng);
    final mapping = <int, int>{};
    for (int i = 0; i < size; i++) {
      mapping[i + 1] = digits[i];
    }
    mapping[0] = 0;
    final transpose = rng.nextBool();
    final startBoard = List.generate(size, (r) => List.filled(size, 0));
    final solutionList = List.generate(size, (r) => List.filled(size, 0));
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        final baseStart = baseLevel.startBoard[r][c];
        final baseSol = baseLevel.solution[r][c];
        final mappedStart = mapping[baseStart]!;
        final mappedSol = mapping[baseSol]!;
        if (transpose) {
          startBoard[c][r] = mappedStart;
          solutionList[c][r] = mappedSol;
        } else {
          startBoard[r][c] = mappedStart;
          solutionList[r][c] = mappedSol;
        }
      }
    }

    // Now dynamically reduce pre-filled cells based on the level index to increase difficulty
    final List<int> filledCells = [];
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (startBoard[r][c] != 0) {
          filledCells.add(r * size + c);
        }
      }
    }

    int targetFilled;
    if (_playDailyMode && _dailyModifierType == 'minimal') {
      targetFilled = 12;
    } else if (size == 9) {
      if (index < 40) {
        targetFilled = 25; // levels 26-40
      } else {
        targetFilled = 21; // levels 41-50
      }
    } else if (size == 6) {
      // levels 11-25, scale from 18 down to 14
      targetFilled = 18 - ((index - 10) * 4 ~/ 15);
    } else {
      // levels 1-10, scale from 8 down to 5
      targetFilled = 8 - (index * 3 ~/ 10);
    }

    if (filledCells.length > targetFilled) {
      filledCells.shuffle(rng);
      int removedCount = 0;
      final int targetToRemove = filledCells.length - targetFilled;
      for (int i = 0; i < filledCells.length; i++) {
        if (removedCount >= targetToRemove) break;
        final idxVal = filledCells[i];
        final r = idxVal ~/ size;
        final c = idxVal % size;
        final temp = startBoard[r][c];
        startBoard[r][c] = 0;
        final copy = List.generate(size, (row) => List<int>.from(startBoard[row]));
        if (_hasUniqueSolution(copy, size)) {
          removedCount++;
        } else {
          startBoard[r][c] = temp;
        }
      }
    }

    return SudokuLevel(
      size: size,
      startBoard: startBoard,
      solution: solutionList,
    );
  }

  void _loadLevel() {
    _level = _getSudokuLevel(_levelIndex);
    _board = List.generate(_level.size, (r) => List.from(_level.startBoard[r]));
    _selectedRow = -1;
    _selectedCol = -1;
    _message = '';
    _won = false;
    _correctPlacementsCount = 0;

    _warpTimer?.cancel();
    _blackoutTimer?.cancel();
    _gameOver = false;
    _isBlackout = false;
    _inRecallTest = false;
    _isScanPhase = true;
    _recallTargetCount = 2;
    _recallPlacedCount = 0;
    _recallCorrectSelections.clear();
    _lockedRecallCells.clear();
    if (_playDailyMode) {
      if (_dailyModifierType == 'time_warp') {
        _warpTimeLeft = 90;
        _warpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted || _won || _gameOver) {
            timer.cancel();
            return;
          }
          setState(() {
            if (_warpTimeLeft > 0) {
              _warpTimeLeft--;
            } else {
              _gameOver = true;
              _message = 'Time is up!';
              AudioManager.playFail();
            }
          });
        });
      } else if (_dailyModifierType == 'eclipse') {
        _startBlackoutTimer();
      }
    }
  }

  void _reset() => setState(() => _loadLevel());

  bool _isOriginal(int r, int c) {
    return _level.startBoard[r][c] != 0 || _lockedRecallCells.contains((r, c));
  }

  void _selectCell(int r, int c) {
    if (_won || _gameOver) return;
    if (_playDailyMode && _dailyModifierType == 'eclipse' && _isScanPhase) return;
    if (_isOriginal(r, c)) return;
    if (_inRecallTest && _recallCorrectSelections.contains((r, c))) return;
    setState(() {
      _selectedRow = r;
      _selectedCol = c;
      _message = '';
      AudioManager.playClick();
    });
  }

  void _inputNumber(int num) {
    if (_won || _gameOver || _selectedRow == -1 || _selectedCol == -1) return;
    if (_playDailyMode && _dailyModifierType == 'eclipse' && _isScanPhase) return;
    final prevVal = _board[_selectedRow][_selectedCol];
    final targetVal = _level.solution[_selectedRow][_selectedCol];

    if (_playDailyMode && _dailyModifierType == 'eclipse' && _inRecallTest) {
      if (num == targetVal) {
        setState(() {
          _board[_selectedRow][_selectedCol] = num;
          _recallCorrectSelections.add((_selectedRow, _selectedCol));
          _recallPlacedCount++;
          _selectedRow = -1;
          _selectedCol = -1;
          _message = 'Correct placement! ($_recallPlacedCount/$_recallTargetCount)';
          AudioManager.playClick();

          if (_recallPlacedCount >= _recallTargetCount) {
            for (final cell in _recallCorrectSelections) {
              _lockedRecallCells.add(cell);
            }
            
            bool fullySolved = true;
            for (int r = 0; r < _level.size; r++) {
              for (int c = 0; c < _level.size; c++) {
                if (_board[r][c] != _level.solution[r][c]) {
                  fullySolved = false;
                  break;
                }
              }
            }

            if (fullySolved) {
              _won = true;
              _selectedRow = -1;
              _selectedCol = -1;
              _message = 'Correct! Sudoku Solved!';
              AudioManager.playSuccess();
              _savePersistedLevel(_levelIndex + 1);
              _clearNormalState();
            } else {
              _isScanPhase = true;
              _inRecallTest = false;
              _recallTargetCount++;
              _blackoutCountdown = 30;
              _message = 'Recall success! Placed cells locked. Scan again!';
              AudioManager.playSuccess();
            }
          }
        });
      } else {
        setState(() {
          _board[_selectedRow][_selectedCol] = num;
          _gameOver = true;
          _message = 'Incorrect placement! Recall failed.';
          AudioManager.playFail();
        });
      }
      return;
    }

    setState(() {
      _board[_selectedRow][_selectedCol] = num;
      _message = '';
      AudioManager.playClick();
    });
    
    if (_playDailyMode && _dailyModifierType == 'time_warp') {
      if (num == targetVal) {
        _warpTimeLeft = (_warpTimeLeft + 5).clamp(0, 300);
        _message = '+5 Seconds!';
      } else {
        _warpTimeLeft = (_warpTimeLeft - 10).clamp(0, 300);
        _message = '-10 Seconds!';
        if (_warpTimeLeft <= 0) {
          _gameOver = true;
          _message = 'Time is up!';
          AudioManager.playFail();
        }
      }
    }
    
    if (_playDailyMode && _dailyModifierType == 'glitch') {
      if (prevVal != num && num == targetVal) {
        _correctPlacementsCount++;
        if (_correctPlacementsCount >= 3) {
          _correctPlacementsCount = 0;
          _glitchRowSwap();
        }
      }
    }
    _saveNormalState();
  }

  void _clearCell() {
    if (_won || _gameOver || _selectedRow == -1 || _selectedCol == -1) return;
    if (_inRecallTest) return;
    setState(() {
      _board[_selectedRow][_selectedCol] = 0;
      _message = '';
      AudioManager.playClick();
    });
    _saveNormalState();
  }

  void _checkBoard() {
    if (_won || _gameOver) return;
    bool correct = true;
    final size = _level.size;
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (_board[r][c] != _level.solution[r][c]) {
          correct = false;
          break;
        }
      }
    }
    if (correct) {
      setState(() {
        _won = true;
        _selectedRow = -1;
        _selectedCol = -1;
        _message = 'Correct! Sudoku Solved!';
        AudioManager.playSuccess();
        _savePersistedLevel(_levelIndex + 1);
      });
      _clearNormalState();
    } else {
      setState(() {
        _message = 'Some numbers are incorrect or missing!';
        AudioManager.playFail();
      });
    }
  }

  void _nextLevel() async {
    if (!_won) return;
    if (widget.dailyLevelIndex != null) {
      Navigator.pop(context, true);
      return;
    }
    if (await ShuffleManager.tryShuffleNavigate(context, 'sudoku')) return;
 
    setState(() {
      _levelIndex = _levelIndex + 1;
      _loadLevel();
    });
  }

  Future<void> _useSudokuHint() async {
    if (_hintCount <= 0 || _won) return;
    if (_selectedRow == -1 || _selectedCol == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Select an empty cell first to get a hint!',
            style: GoogleFonts.outfit(),
          ),
        ),
      );
      return;
    }
    if (_isOriginal(_selectedRow, _selectedCol)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This cell is already part of the original board!',
            style: GoogleFonts.outfit(),
          ),
        ),
      );
      return;
    }
    if (_board[_selectedRow][_selectedCol] ==
        _level.solution[_selectedRow][_selectedCol]) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This cell is already correct!',
            style: GoogleFonts.outfit(),
          ),
        ),
      );
      return;
    }

    await HintManager.useHint('sudoku');
    final newCount = await HintManager.getHints('sudoku');
    setState(() {
      _hintCount = newCount;
      _board[_selectedRow][_selectedCol] =
          _level.solution[_selectedRow][_selectedCol];
      _message = 'Revealed correct number!';
    });
    _checkBoard();
    if (!_won) {
      _saveNormalState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = AppTheme.accentFor('sudoku');
    final size = _level.size;
    final boardScale = size == 9
        ? 300.0
        : size == 6
        ? 280.0
        : 260.0;

    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        backgroundColor: context.bgDark,
        foregroundColor: context.textPrimary,
        title: Text(
          'Sudoku',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_shuffleActive)
            IconButton(
              icon: const Icon(Icons.skip_next_rounded),
              tooltip: 'Skip Game',
              onPressed: () => ShuffleManager.tryShuffleNavigate(context, 'sudoku'),
            ),
          IconButton(
            icon: const Icon(Icons.help_outline, size: 20),
            color: context.textMuted,
            onPressed: () =>
                RulesHelper.showRulesBottomSheet(context, 'sudoku', 'Sudoku'),
          ),
          IconButton(
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  size: 20,
                  color: Colors.amber,
                ),
                Text(
                  _hintCount == 0 ? '+' : '$_hintCount',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
            onPressed: !_won
                ? () async {
                    if (_hintCount > 0) {
                      _useSudokuHint();
                    } else {
                      await BuyHintsDialog.show(
                        context,
                        initialGameId: 'sudoku',
                        onPurchaseComplete: () async {
                          final newCount = await HintManager.getHints('sudoku');
                          if (mounted) setState(() => _hintCount = newCount);
                        },
                      );
                    }
                  }
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _reset,
            color: context.textMuted,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                _playDailyMode ? 'Daily' : 'Level ${_levelIndex + 1}',
                style: AppTheme.numberStyle(
                  color: accentColor,
                  fontSize: context.scale(13),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 10,
              ),
              child: Column(
                children: [
                  Text(
                    'Fill the ${size}x${size} grid so every row, column and subgrid contains unique numbers from 1 to $size',
                    style: GoogleFonts.outfit(
                      color: context.textSecondary,
                      fontSize: context.scale(13),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (_playDailyMode && _dailyModifierType == 'time_warp') ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.hourglass_bottom, color: Colors.orange, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Time Left: $_warpTimeLeft s',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: context.scale(18),
                            fontWeight: FontWeight.bold,
                            color: _warpTimeLeft <= 15 ? Colors.redAccent : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_playDailyMode && _dailyModifierType == 'eclipse') ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isScanPhase ? Icons.timer : Icons.memory,
                          color: _isScanPhase ? Colors.amber : Colors.redAccent,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isScanPhase
                              ? 'SCAN PHASE: Study the board! $_blackoutCountdown s'
                              : 'RECALL PHASE: Place $_recallTargetCount numbers! ($_recallPlacedCount/$_recallTargetCount)',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: context.scale(16),
                            fontWeight: FontWeight.bold,
                            color: _isScanPhase ? Colors.amber : Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Sudoku Board Display
                  Center(
                    child: Container(
                      width: context.scale(boardScale),
                      height: context.scale(boardScale),
                      decoration: BoxDecoration(
                        color: context.bgCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.textMuted, width: 2),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: FogOverlay(
                              enabled: _playDailyMode && _dailyModifierType == 'fog',
                              radius: (context.scale(boardScale) / size) * _dailyRadius,
                              focalPoint: (_selectedRow != -1 && _selectedCol != -1)
                                  ? Offset(
                                      (_selectedCol + 0.5) * (context.scale(boardScale) / size),
                                      (_selectedRow + 0.5) * (context.scale(boardScale) / size),
                                    )
                                  : null,
                              child: GridView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: size * size,
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: size,
                                ),
                                itemBuilder: (ctx, idx) {
                                  final r = idx ~/ size;
                                  final c = idx % size;
                                  final value = _board[r][c];
                                  final isOrig = _isOriginal(r, c);
                                  final isSel = r == _selectedRow && c == _selectedCol;

                                  BorderSide borderRight;
                                  BorderSide borderBottom;

                                  if (size == 4) {
                                    borderRight = (c == 1)
                                        ? BorderSide(color: context.textMuted, width: 2)
                                        : BorderSide(
                                            color: context.textMuted.withAlpha(40),
                                            width: 0.5,
                                          );
                                    borderBottom = (r == 1)
                                        ? BorderSide(color: context.textMuted, width: 2)
                                        : BorderSide(
                                            color: context.textMuted.withAlpha(40),
                                            width: 0.5,
                                          );
                                  } else if (size == 6) {
                                    borderRight = (c == 2)
                                        ? BorderSide(color: context.textMuted, width: 2)
                                        : BorderSide(
                                            color: context.textMuted.withAlpha(40),
                                            width: 0.5,
                                          );
                                    borderBottom = (r == 1 || r == 3)
                                        ? BorderSide(color: context.textMuted, width: 2)
                                        : BorderSide(
                                            color: context.textMuted.withAlpha(40),
                                            width: 0.5,
                                          );
                                  } else {
                                    // size == 9
                                    borderRight = (c == 2 || c == 5)
                                        ? BorderSide(color: context.textMuted, width: 2)
                                        : BorderSide(
                                            color: context.textMuted.withAlpha(40),
                                            width: 0.5,
                                          );
                                    borderBottom = (r == 2 || r == 5)
                                        ? BorderSide(color: context.textMuted, width: 2)
                                        : BorderSide(
                                            color: context.textMuted.withAlpha(40),
                                            width: 0.5,
                                          );
                                  }

                                  return GestureDetector(
                                    onTap: () => _selectCell(r, c),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: isSel
                                            ? accentColor.withAlpha(45)
                                            : (_inRecallTest
                                                ? context.bgCard
                                                : (isOrig
                                                    ? context.bgSurface
                                                    : context.bgCard)),
                                        border: Border(
                                          right: borderRight,
                                          bottom: borderBottom,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          _inRecallTest
                                              ? (_recallCorrectSelections.contains((r, c)) ? '$value' : '')
                                              : (value != 0 ? '$value' : ''),
                                          style: AppTheme.numberStyle(
                                            fontSize: context.scale(
                                              size == 9 ? 15 : 18,
                                            ),
                                            fontWeight: isOrig
                                                ? FontWeight.w900
                                                : FontWeight.w600,
                                            color: isOrig
                                                ? context.textPrimary
                                                : accentColor,
                                          ),
                                        ),
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
                  const SizedBox(height: 24),
                  if (_message.isNotEmpty)
                    Text(
                      _message,
                      style: GoogleFonts.outfit(
                        color: _won ? accentColor : Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: context.scale(14),
                      ),
                    ),
                  const SizedBox(height: 16),
                  // Number Pad (1 to size)
                  if (!_won) ...[
                    if (!(_playDailyMode && _dailyModifierType == 'eclipse' && _isScanPhase)) ...[
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: List.generate(size, (i) => i + 1).map((n) {
                          return SizedBox(
                            width: context.scale(size == 9 ? 42 : 50),
                            height: context.scale(size == 9 ? 42 : 50),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: context.bgSurface,
                                foregroundColor: context.textPrimary,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: (_selectedRow != -1)
                                        ? accentColor
                                        : context.textMuted.withAlpha(50),
                                    width: 1.5,
                                  ),
                                ),
                                elevation: 0,
                              ),
                              onPressed: (_selectedRow != -1)
                                  ? () => _inputNumber(n)
                                  : null,
                              child: Text(
                                '$n',
                                style: AppTheme.numberStyle(
                                  fontSize: context.scale(16),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (!(_playDailyMode && _dailyModifierType == 'eclipse'))
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton(
                            onPressed: (_selectedRow != -1) ? _clearCell : null,
                            child: Text(
                              'CLEAR',
                              style: GoogleFonts.outfit(
                                color: context.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: context.scale(14),
                              ),
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            onPressed: _checkBoard,
                            child: Text(
                              'CHECK',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: context.scale(14),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ] else ...[
                    const SizedBox(height: 16),
                    if (!_playDailyMode)
                      AutoNextCountdown(
                        onNext: _nextLevel,
                        accentColor: accentColor,
                      ),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
      if (_gameOver && !_won)
        LossOverlay(
          onTryAgain: _reset,
          subtitle: _playDailyMode ? 'Daily Challenge failed.' : 'Failed on level ${_levelIndex + 1}.',
          accentColor: accentColor,
        ),
      if (_won && _playDailyMode)
        ChallengeClearedOverlay(
          accentColor: accentColor,
          onComplete: () {
            Navigator.pop(context, true);
          },
        ),
    ],
  ),
);
  }

  void _glitchRowSwap() {
    final size = _level.size;
    final rng = Random();
    
    int bandSize = 3; 
    if (size == 4) bandSize = 2;
    if (size == 6) bandSize = 2; 
    
    final numBands = size ~/ bandSize;
    final bandIdx = rng.nextInt(numBands);
    
    final startRow = bandIdx * bandSize;
    final r1 = startRow + rng.nextInt(bandSize);
    int r2 = startRow + rng.nextInt(bandSize);
    while (r2 == r1) {
      r2 = startRow + rng.nextInt(bandSize);
    }
    
    final tempBoardRow = List<int>.from(_board[r1]);
    _board[r1] = List<int>.from(_board[r2]);
    _board[r2] = tempBoardRow;

    final tempStartRow = List<int>.from(_level.startBoard[r1]);
    _level.startBoard[r1] = List<int>.from(_level.startBoard[r2]);
    _level.startBoard[r2] = tempStartRow;

    final tempSolRow = List<int>.from(_level.solution[r1]);
    _level.solution[r1] = List<int>.from(_level.solution[r2]);
    _level.solution[r2] = tempSolRow;
    
    setState(() {
      _message = 'Glitch! Rows $r1 and $r2 swapped!';
    });
    
    AudioManager.playFail(); 
  }
}
