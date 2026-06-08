import'package:flutter/material.dart';
import'package:google_fonts/google_fonts.dart';
import'package:shared_preferences/shared_preferences.dart';
import'../../../theme/app_theme.dart';
import'../../../utils/hint_manager.dart';
import'../../../utils/rules_helper.dart';

class SudokuLevel {
  final int size; // 4, 6, or 9
  final List<List<int>> startBoard;
  final List<List<int>> solution;
  const SudokuLevel({required this.size, required this.startBoard, required this.solution});
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
      [1, 0, 0, 4],
      [0, 2, 3, 0],
      [0, 4, 1, 0],
      [3, 0, 0, 2],
    ],
    solution: [
      [1, 3, 2, 4],
      [4, 2, 3, 1],
      [2, 4, 1, 3],
      [3, 1, 4, 2],
    ],
  ),
  SudokuLevel(
    size: 4,
    startBoard: [
      [0, 0, 1, 0],
      [4, 0, 0, 2],
      [1, 0, 0, 4],
      [0, 4, 0, 0],
    ],
    solution: [
      [2, 3, 1, 4],
      [4, 1, 3, 2],
      [1, 2, 3, 4],
      [3, 4, 2, 1],
    ],
  ),
  SudokuLevel(
    size: 4,
    startBoard: [
      [0, 1, 0, 0],
      [0, 0, 2, 0],
      [0, 4, 0, 0],
      [0, 0, 3, 0],
    ],
    solution: [
      [2, 1, 4, 3],
      [4, 3, 2, 1],
      [3, 4, 1, 2],
      [1, 2, 3, 4],
    ],
  ),
  SudokuLevel(
    size: 4,
    startBoard: [
      [4, 0, 0, 0],
      [0, 1, 0, 2],
      [1, 0, 2, 0],
      [0, 0, 0, 4],
    ],
    solution: [
      [4, 2, 3, 1],
      [3, 1, 4, 2],
      [1, 4, 2, 3],
      [2, 3, 1, 4],
    ],
  ),
  // Medium (6x6)
  SudokuLevel(
    size: 6,
    startBoard: [
      [1, 0, 3, 0, 5, 0],
      [0, 5, 0, 1, 0, 3],
      [2, 0, 4, 0, 6, 0],
      [0, 6, 0, 2, 0, 4],
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
      [0, 5, 0, 3, 0, 1],
      [3, 0, 0, 0, 5, 0],
      [0, 4, 3, 0, 0, 6],
      [2, 0, 0, 5, 4, 0],
      [0, 3, 0, 0, 0, 5],
      [1, 0, 5, 0, 3, 0],
    ],
    solution: [
      [6, 5, 4, 3, 2, 1],
      [3, 2, 1, 6, 5, 4],
      [5, 4, 3, 2, 1, 6],
      [2, 1, 6, 5, 4, 3],
      [4, 3, 2, 1, 6, 5],
      [1, 6, 5, 4, 3, 2],
    ],
  ),
  SudokuLevel(
    size: 6,
    startBoard: [
      [2, 0, 0, 4, 0, 5],
      [0, 4, 6, 0, 3, 0],
      [3, 0, 0, 5, 0, 0],
      [0, 0, 1, 0, 0, 3],
      [0, 3, 0, 6, 2, 0],
      [1, 0, 2, 0, 0, 4],
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
      [0, 5, 0, 0, 4, 0],
      [2, 0, 6, 0, 0, 1],
      [0, 3, 0, 4, 0, 0],
      [0, 0, 2, 0, 3, 0],
      [5, 0, 0, 6, 0, 4],
      [0, 2, 0, 0, 1, 0],
    ],
    solution: [
      [3, 5, 1, 2, 4, 6],
      [2, 4, 6, 3, 5, 1],
      [1, 3, 5, 4, 6, 2],
      [4, 6, 2, 1, 3, 5],
      [5, 1, 3, 6, 2, 4],
      [6, 2, 4, 5, 1, 3],
    ],
  ),
  SudokuLevel(
    size: 6,
    startBoard: [
      [5, 0, 0, 3, 0, 0],
      [0, 4, 0, 0, 6, 0],
      [0, 0, 5, 0, 0, 3],
      [4, 0, 0, 6, 0, 0],
      [0, 3, 0, 0, 5, 0],
      [0, 0, 6, 0, 0, 4],
    ],
    solution: [
      [5, 6, 2, 3, 4, 1],
      [3, 4, 1, 5, 6, 2],
      [6, 1, 5, 4, 2, 3],
      [4, 2, 3, 6, 1, 5],
      [2, 3, 4, 1, 5, 6],
      [1, 5, 6, 2, 3, 4],
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
      [1, 0, 0, 4, 0, 0, 7, 0, 0],
      [0, 5, 0, 0, 8, 0, 0, 2, 0],
      [0, 0, 9, 0, 0, 3, 0, 0, 6],
      [2, 0, 0, 5, 0, 0, 8, 0, 0],
      [0, 6, 0, 0, 9, 0, 0, 3, 0],
      [0, 0, 1, 0, 0, 4, 0, 0, 7],
      [3, 0, 0, 6, 0, 0, 9, 0, 0],
      [0, 7, 0, 0, 1, 0, 0, 4, 0],
      [0, 0, 2, 0, 0, 5, 0, 0, 8],
    ],
    solution: [
      [1, 2, 3, 4, 5, 6, 7, 8, 9],
      [4, 5, 6, 7, 8, 9, 1, 2, 3],
      [7, 8, 9, 1, 2, 3, 4, 5, 6],
      [2, 3, 4, 5, 6, 7, 8, 9, 1],
      [5, 6, 7, 8, 9, 1, 2, 3, 4],
      [8, 9, 1, 2, 3, 4, 5, 6, 7],
      [3, 4, 5, 6, 7, 8, 9, 1, 2],
      [6, 7, 8, 9, 1, 2, 3, 4, 5],
      [9, 1, 2, 3, 4, 5, 6, 7, 8],
    ],
  ),
  SudokuLevel(
    size: 9,
    startBoard: [
      [0, 8, 0, 0, 5, 0, 0, 2, 0],
      [3, 0, 0, 9, 0, 0, 6, 0, 0],
      [0, 0, 4, 0, 0, 1, 0, 0, 7],
      [0, 7, 0, 0, 4, 0, 0, 1, 0],
      [2, 0, 0, 8, 0, 0, 5, 0, 0],
      [0, 0, 3, 0, 0, 9, 0, 0, 6],
      [0, 6, 0, 0, 3, 0, 0, 9, 0],
      [1, 0, 0, 7, 0, 0, 4, 0, 0],
      [0, 0, 2, 0, 0, 8, 0, 0, 5],
    ],
    solution: [
      [9, 8, 7, 6, 5, 4, 3, 2, 1],
      [3, 2, 1, 9, 8, 7, 6, 5, 4],
      [6, 5, 4, 3, 2, 1, 9, 8, 7],
      [8, 7, 6, 5, 4, 3, 2, 1, 9],
      [2, 1, 9, 8, 7, 6, 5, 4, 3],
      [5, 4, 3, 2, 1, 9, 8, 7, 6],
      [7, 6, 5, 4, 3, 2, 1, 9, 8],
      [1, 9, 8, 7, 6, 5, 4, 3, 2],
      [4, 3, 2, 1, 9, 8, 7, 6, 5],
    ],
  ),
  SudokuLevel(
    size: 9,
    startBoard: [
      [0, 5, 6, 0, 8, 9, 0, 2, 3],
      [7, 0, 0, 1, 0, 0, 4, 0, 0],
      [1, 0, 0, 4, 0, 0, 7, 0, 0],
      [0, 6, 7, 0, 9, 1, 0, 3, 4],
      [8, 0, 0, 2, 0, 0, 5, 0, 0],
      [2, 0, 0, 5, 0, 0, 8, 0, 0],
      [0, 7, 8, 0, 1, 2, 0, 4, 5],
      [9, 0, 0, 3, 0, 0, 6, 0, 0],
      [3, 0, 0, 6, 0, 0, 9, 0, 0],
    ],
    solution: [
      [4, 5, 6, 7, 8, 9, 1, 2, 3],
      [7, 8, 9, 1, 2, 3, 4, 5, 6],
      [1, 2, 3, 4, 5, 6, 7, 8, 9],
      [5, 6, 7, 8, 9, 1, 2, 3, 4],
      [8, 9, 1, 2, 3, 4, 5, 6, 7],
      [2, 3, 4, 5, 6, 7, 8, 9, 1],
      [6, 7, 8, 9, 1, 2, 3, 4, 5],
      [9, 1, 2, 3, 4, 5, 6, 7, 8],
      [3, 4, 5, 6, 7, 8, 9, 1, 2],
    ],
  ),
  SudokuLevel(
    size: 9,
    startBoard: [
      [7, 0, 0, 0, 2, 0, 0, 0, 6],
      [0, 2, 0, 4, 0, 6, 0, 8, 0],
      [0, 0, 6, 0, 0, 0, 1, 0, 0],
      [8, 0, 0, 0, 3, 0, 0, 0, 7],
      [0, 3, 0, 5, 0, 7, 0, 9, 0],
      [0, 0, 7, 0, 0, 0, 2, 0, 0],
      [9, 0, 0, 0, 4, 0, 0, 0, 8],
      [0, 4, 0, 6, 0, 8, 0, 1, 0],
      [0, 0, 8, 0, 0, 0, 3, 0, 0],
    ],
    solution: [
      [7, 8, 9, 1, 2, 3, 4, 5, 6],
      [1, 2, 3, 4, 5, 6, 7, 8, 9],
      [4, 5, 6, 7, 8, 9, 1, 2, 3],
      [8, 9, 1, 2, 3, 4, 5, 6, 7],
      [2, 3, 4, 5, 6, 7, 8, 9, 1],
      [5, 6, 7, 8, 9, 1, 2, 3, 4],
      [9, 1, 2, 3, 4, 5, 6, 7, 8],
      [3, 4, 5, 6, 7, 8, 9, 1, 2],
      [6, 7, 8, 9, 1, 2, 3, 4, 5],
    ],
  ),
  SudokuLevel(
    size: 4,
    startBoard: [
      [1, 0, 0, 0],
      [0, 0, 2, 0],
      [0, 3, 0, 0],
      [0, 0, 0, 4],
    ],
    solution: [
      [1, 2, 3, 4],
      [3, 4, 2, 1],
      [4, 3, 1, 2],
      [2, 1, 4, 3],
    ],
  ),
  SudokuLevel(
    size: 4,
    startBoard: [
      [0, 2, 0, 0],
      [0, 0, 3, 0],
      [0, 4, 0, 0],
      [1, 0, 0, 0],
    ],
    solution: [
      [3, 2, 4, 1],
      [4, 1, 3, 2],
      [2, 4, 1, 3],
      [1, 3, 2, 4],
    ],
  ),
  SudokuLevel(
    size: 4,
    startBoard: [
      [0, 0, 0, 2],
      [3, 0, 0, 0],
      [0, 0, 0, 4],
      [0, 1, 0, 0],
    ],
    solution: [
      [4, 3, 1, 2],
      [3, 2, 4, 1],
      [1, 4, 2, 3],
      [2, 1, 3, 4],
    ],
  ),
  SudokuLevel(
    size: 4,
    startBoard: [
      [0, 0, 3, 0],
      [2, 0, 0, 0],
      [0, 0, 0, 1],
      [0, 4, 0, 0],
    ],
    solution: [
      [4, 1, 3, 2],
      [2, 3, 1, 4],
      [3, 2, 4, 1],
      [1, 4, 2, 3],
    ],
  ),
  SudokuLevel(
    size: 4,
    startBoard: [
      [2, 0, 0, 0],
      [0, 1, 0, 0],
      [0, 0, 4, 0],
      [0, 0, 0, 3],
    ],
    solution: [
      [2, 4, 3, 1],
      [3, 1, 2, 4],
      [1, 3, 4, 2],
      [4, 2, 1, 3],
    ],
  ),
  SudokuLevel(
    size: 6,
    startBoard: [
      [1, 0, 3, 0, 5, 0],
      [0, 5, 0, 1, 0, 3],
      [2, 0, 4, 0, 6, 0],
      [0, 6, 0, 2, 0, 4],
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
      [0, 2, 0, 4, 0, 6],
      [4, 0, 6, 0, 2, 0],
      [0, 3, 0, 5, 0, 1],
      [5, 0, 1, 0, 3, 0],
      [0, 4, 0, 6, 0, 2],
      [6, 0, 2, 0, 4, 0],
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
      [1, 2, 0, 0, 5, 6],
      [4, 5, 0, 0, 2, 3],
      [2, 3, 0, 0, 6, 1],
      [5, 6, 0, 0, 3, 4],
      [3, 4, 0, 0, 1, 2],
      [6, 1, 0, 0, 4, 5],
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
      [0, 0, 3, 4, 0, 0],
      [0, 0, 6, 1, 0, 0],
      [0, 0, 4, 5, 0, 0],
      [0, 0, 1, 2, 0, 0],
      [0, 0, 5, 6, 0, 0],
      [0, 0, 2, 3, 0, 0],
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
      [1, 0, 0, 0, 0, 6],
      [0, 5, 0, 0, 2, 0],
      [0, 0, 4, 5, 0, 0],
      [0, 0, 1, 2, 0, 0],
      [0, 4, 0, 0, 1, 0],
      [6, 0, 0, 0, 0, 5],
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
    size: 9,
    startBoard: [
      [1, 0, 3, 0, 5, 0, 7, 0, 9],
      [0, 5, 0, 7, 0, 9, 0, 2, 0],
      [7, 0, 9, 0, 2, 0, 4, 0, 6],
      [0, 3, 0, 5, 0, 4, 0, 9, 0],
      [5, 0, 4, 0, 9, 0, 2, 0, 1],
      [0, 9, 0, 2, 0, 1, 0, 6, 0],
      [3, 0, 2, 0, 4, 0, 9, 0, 8],
      [0, 4, 0, 9, 0, 8, 0, 1, 0],
      [9, 0, 8, 0, 1, 0, 6, 0, 5],
    ],
    solution: [
      [1, 2, 3, 4, 5, 6, 7, 8, 9],
      [4, 5, 6, 7, 8, 9, 1, 2, 3],
      [7, 8, 9, 1, 2, 3, 4, 5, 6],
      [2, 3, 1, 5, 6, 4, 8, 9, 7],
      [5, 6, 4, 8, 9, 7, 2, 3, 1],
      [8, 9, 7, 2, 3, 1, 5, 6, 4],
      [3, 1, 2, 6, 4, 5, 9, 7, 8],
      [6, 4, 5, 9, 7, 8, 3, 1, 2],
      [9, 7, 8, 3, 1, 2, 6, 4, 5],
    ],
  ),
  SudokuLevel(
    size: 9,
    startBoard: [
      [0, 2, 0, 4, 0, 6, 0, 8, 0],
      [4, 0, 6, 0, 8, 0, 1, 0, 3],
      [0, 8, 0, 1, 0, 3, 0, 5, 0],
      [2, 0, 1, 0, 6, 0, 8, 0, 7],
      [0, 6, 0, 8, 0, 7, 0, 3, 0],
      [8, 0, 7, 0, 3, 0, 5, 0, 4],
      [0, 1, 0, 6, 0, 5, 0, 7, 0],
      [6, 0, 5, 0, 7, 0, 3, 0, 2],
      [0, 7, 0, 3, 0, 2, 0, 4, 0],
    ],
    solution: [
      [1, 2, 3, 4, 5, 6, 7, 8, 9],
      [4, 5, 6, 7, 8, 9, 1, 2, 3],
      [7, 8, 9, 1, 2, 3, 4, 5, 6],
      [2, 3, 1, 5, 6, 4, 8, 9, 7],
      [5, 6, 4, 8, 9, 7, 2, 3, 1],
      [8, 9, 7, 2, 3, 1, 5, 6, 4],
      [3, 1, 2, 6, 4, 5, 9, 7, 8],
      [6, 4, 5, 9, 7, 8, 3, 1, 2],
      [9, 7, 8, 3, 1, 2, 6, 4, 5],
    ],
  ),
  SudokuLevel(
    size: 9,
    startBoard: [
      [1, 2, 3, 0, 0, 0, 7, 8, 9],
      [4, 5, 6, 0, 0, 0, 1, 2, 3],
      [7, 8, 9, 0, 0, 0, 4, 5, 6],
      [2, 3, 1, 0, 0, 0, 8, 9, 7],
      [5, 6, 4, 0, 0, 0, 2, 3, 1],
      [8, 9, 7, 0, 0, 0, 5, 6, 4],
      [3, 1, 2, 0, 0, 0, 9, 7, 8],
      [6, 4, 5, 0, 0, 0, 3, 1, 2],
      [9, 7, 8, 0, 0, 0, 6, 4, 5],
    ],
    solution: [
      [1, 2, 3, 4, 5, 6, 7, 8, 9],
      [4, 5, 6, 7, 8, 9, 1, 2, 3],
      [7, 8, 9, 1, 2, 3, 4, 5, 6],
      [2, 3, 1, 5, 6, 4, 8, 9, 7],
      [5, 6, 4, 8, 9, 7, 2, 3, 1],
      [8, 9, 7, 2, 3, 1, 5, 6, 4],
      [3, 1, 2, 6, 4, 5, 9, 7, 8],
      [6, 4, 5, 9, 7, 8, 3, 1, 2],
      [9, 7, 8, 3, 1, 2, 6, 4, 5],
    ],
  ),
  SudokuLevel(
    size: 9,
    startBoard: [
      [0, 0, 0, 4, 5, 6, 0, 0, 0],
      [0, 0, 0, 7, 8, 9, 0, 0, 0],
      [0, 0, 0, 1, 2, 3, 0, 0, 0],
      [0, 0, 0, 5, 6, 4, 0, 0, 0],
      [0, 0, 0, 8, 9, 7, 0, 0, 0],
      [0, 0, 0, 2, 3, 1, 0, 0, 0],
      [0, 0, 0, 6, 4, 5, 0, 0, 0],
      [0, 0, 0, 9, 7, 8, 0, 0, 0],
      [0, 0, 0, 3, 1, 2, 0, 0, 0],
    ],
    solution: [
      [1, 2, 3, 4, 5, 6, 7, 8, 9],
      [4, 5, 6, 7, 8, 9, 1, 2, 3],
      [7, 8, 9, 1, 2, 3, 4, 5, 6],
      [2, 3, 1, 5, 6, 4, 8, 9, 7],
      [5, 6, 4, 8, 9, 7, 2, 3, 1],
      [8, 9, 7, 2, 3, 1, 5, 6, 4],
      [3, 1, 2, 6, 4, 5, 9, 7, 8],
      [6, 4, 5, 9, 7, 8, 3, 1, 2],
      [9, 7, 8, 3, 1, 2, 6, 4, 5],
    ],
  ),
  SudokuLevel(
    size: 9,
    startBoard: [
      [1, 0, 0, 4, 0, 0, 7, 0, 0],
      [0, 5, 0, 0, 8, 0, 0, 2, 0],
      [0, 0, 9, 0, 0, 3, 0, 0, 6],
      [2, 0, 0, 5, 0, 0, 8, 0, 0],
      [0, 6, 0, 0, 9, 0, 0, 3, 0],
      [0, 0, 7, 0, 0, 1, 0, 0, 4],
      [3, 0, 0, 6, 0, 0, 9, 0, 0],
      [0, 4, 0, 0, 7, 0, 0, 1, 0],
      [0, 0, 8, 0, 0, 2, 0, 0, 5],
    ],
    solution: [
      [1, 2, 3, 4, 5, 6, 7, 8, 9],
      [4, 5, 6, 7, 8, 9, 1, 2, 3],
      [7, 8, 9, 1, 2, 3, 4, 5, 6],
      [2, 3, 1, 5, 6, 4, 8, 9, 7],
      [5, 6, 4, 8, 9, 7, 2, 3, 1],
      [8, 9, 7, 2, 3, 1, 5, 6, 4],
      [3, 1, 2, 6, 4, 5, 9, 7, 8],
      [6, 4, 5, 9, 7, 8, 3, 1, 2],
      [9, 7, 8, 3, 1, 2, 6, 4, 5],
    ],
  ),
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
      [0, 0, 4, 6, 0, 0, 9, 1, 0],
      [0, 7, 0, 0, 9, 0, 3, 0, 0],
      [1, 0, 0, 3, 0, 2, 0, 0, 7],
      [0, 5, 9, 0, 0, 1, 4, 2, 0],
      [0, 0, 0, 0, 5, 0, 0, 0, 0],
      [0, 1, 3, 9, 0, 0, 8, 5, 0],
      [9, 0, 0, 5, 0, 7, 0, 0, 4],
      [0, 0, 7, 0, 1, 0, 0, 3, 0],
      [0, 4, 5, 0, 0, 6, 1, 0, 0],
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
      [0, 3, 0, 6, 7, 8, 0, 1, 0],
      [6, 0, 2, 0, 0, 0, 3, 0, 8],
      [0, 9, 0, 3, 0, 2, 0, 6, 0],
      [8, 0, 9, 0, 6, 0, 4, 0, 3],
      [0, 2, 0, 8, 0, 3, 0, 9, 0],
      [7, 0, 3, 0, 2, 0, 8, 0, 6],
      [0, 6, 0, 5, 0, 7, 0, 8, 0],
      [2, 0, 7, 0, 0, 0, 6, 0, 5],
      [0, 4, 0, 2, 8, 6, 0, 7, 0],
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
      [5, 0, 4, 0, 0, 0, 9, 0, 2],
      [0, 7, 0, 1, 0, 5, 0, 4, 0],
      [1, 0, 0, 0, 4, 0, 0, 0, 7],
      [0, 5, 0, 7, 0, 1, 0, 2, 0],
      [0, 0, 6, 0, 5, 0, 7, 0, 0],
      [0, 1, 0, 9, 0, 4, 0, 5, 0],
      [9, 0, 0, 0, 3, 0, 0, 0, 4],
      [0, 8, 0, 4, 0, 9, 0, 3, 0],
      [3, 0, 5, 0, 0, 0, 1, 0, 9],
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
      [0, 0, 0, 0, 7, 8, 0, 0, 0],
      [0, 0, 2, 1, 0, 5, 3, 0, 0],
      [0, 9, 8, 3, 0, 0, 5, 6, 0],
      [8, 5, 0, 7, 0, 0, 0, 2, 3],
      [4, 0, 0, 0, 0, 0, 0, 0, 1],
      [7, 1, 0, 0, 0, 4, 0, 5, 6],
      [0, 6, 1, 0, 0, 7, 2, 8, 0],
      [0, 0, 7, 4, 0, 9, 6, 0, 0],
      [0, 0, 0, 2, 8, 0, 0, 0, 0],
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
      [0, 3, 4, 0, 0, 8, 9, 1, 0],
      [6, 0, 0, 0, 9, 0, 0, 0, 8],
      [1, 0, 0, 3, 0, 0, 0, 0, 7],
      [0, 0, 9, 7, 0, 1, 4, 0, 0],
      [0, 2, 0, 0, 0, 0, 0, 9, 0],
      [0, 0, 3, 9, 0, 4, 8, 0, 0],
      [9, 0, 0, 0, 0, 7, 0, 0, 4],
      [2, 0, 0, 0, 1, 0, 0, 0, 5],
      [0, 4, 5, 2, 0, 0, 1, 7, 0],
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
      [5, 0, 0, 6, 7, 8, 0, 0, 2],
      [0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 0, 3, 4, 2, 0, 0, 0],
      [8, 0, 9, 0, 0, 0, 4, 0, 3],
      [4, 0, 6, 0, 0, 0, 7, 0, 1],
      [7, 0, 3, 0, 0, 0, 8, 0, 6],
      [0, 0, 0, 5, 3, 7, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 0],
      [3, 0, 0, 2, 8, 6, 0, 0, 9],
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
      [0, 3, 4, 0, 0, 0, 9, 1, 0],
      [6, 7, 0, 0, 0, 0, 0, 4, 8],
      [0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 0, 7, 6, 1, 0, 0, 0],
      [4, 2, 0, 8, 5, 3, 0, 9, 1],
      [0, 0, 0, 9, 2, 4, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 0],
      [2, 8, 0, 0, 0, 0, 0, 3, 5],
      [0, 4, 5, 0, 0, 0, 1, 7, 0],
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
      [5, 3, 0, 0, 7, 0, 0, 1, 2],
      [6, 0, 0, 0, 9, 0, 0, 0, 8],
      [0, 0, 8, 3, 0, 2, 5, 0, 0],
      [0, 0, 9, 7, 0, 1, 4, 0, 0],
      [4, 0, 0, 0, 5, 0, 0, 0, 1],
      [0, 0, 3, 9, 0, 4, 8, 0, 0],
      [0, 0, 1, 5, 0, 7, 2, 0, 0],
      [2, 0, 0, 0, 1, 0, 0, 0, 5],
      [3, 4, 0, 0, 8, 0, 0, 7, 9],
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
  String _message ='';
  bool _won = false;

  @override
  void initState() {
    super.initState();
    // Default synchronous initialization to avoid LateInitializationError
    _level = _kLevels[0];
    _board = List.generate(_level.size, (r) => List.from(_level.startBoard[r]));
    _initLevel();
  }

  int _hintCount = 0;

  Future<void> _initLevel() async {
    _hintCount = await HintManager.getHints('sudoku');
    if (widget.dailyLevelIndex != null) {
      if (mounted) {
        setState(() {
          _levelIndex = widget.dailyLevelIndex!;
          _loadLevel();
        });
      }
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final savedLevel = prefs.getInt('level_sudoku') ?? 0;
    if (mounted) {
      setState(() {
        _levelIndex = savedLevel % _kLevels.length;
        _loadLevel();
      });
    }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hint earned! (Total: $newCount)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            backgroundColor: AppTheme.accentFor('sudoku'),
          ),
        );
      }
    }
  }

  void _loadLevel() {
    _level = _kLevels[_levelIndex % _kLevels.length];
    _board = List.generate(_level.size, (r) => List.from(_level.startBoard[r]));
    _selectedRow = -1;
    _selectedCol = -1;
    _message ='';
    _won = false;
  }

  void _reset() => setState(() => _loadLevel());

  bool _isOriginal(int r, int c) {
    return _level.startBoard[r][c] != 0;
  }

  void _selectCell(int r, int c) {
    if (_won || _isOriginal(r, c)) return;
    setState(() {
      _selectedRow = r;
      _selectedCol = c;
      _message ='';
    });
  }

  void _inputNumber(int num) {
    if (_won || _selectedRow == -1 || _selectedCol == -1) return;
    setState(() {
      _board[_selectedRow][_selectedCol] = num;
      _message ='';
    });
  }

  void _clearCell() {
    if (_won || _selectedRow == -1 || _selectedCol == -1) return;
    setState(() {
      _board[_selectedRow][_selectedCol] = 0;
      _message ='';
    });
  }

  void _checkBoard() {
    if (_won) return;
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
        _message ='Correct! Sudoku Solved!';
        _savePersistedLevel(_levelIndex);
      });
    } else {
      setState(() {
        _message ='❌ Some numbers are incorrect or missing!';
      });
    }
  }

  void _nextLevel() {
    if (widget.dailyLevelIndex != null) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _levelIndex = (_levelIndex + 1) % _kLevels.length;
      _savePersistedLevel(_levelIndex);
      _loadLevel();
    });
  }

  Future<void> _useSudokuHint() async {
    if (_hintCount <= 0 || _won) return;
    if (_selectedRow == -1 || _selectedCol == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Select an empty cell first to get a hint!', style: GoogleFonts.outfit())),
      );
      return;
    }
    if (_isOriginal(_selectedRow, _selectedCol)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('This cell is already part of the original board!', style: GoogleFonts.outfit())),
      );
      return;
    }
    if (_board[_selectedRow][_selectedCol] == _level.solution[_selectedRow][_selectedCol]) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('This cell is already correct!', style: GoogleFonts.outfit())),
      );
      return;
    }

    await HintManager.useHint('sudoku');
    final newCount = await HintManager.getHints('sudoku');
    setState(() {
      _hintCount = newCount;
      _board[_selectedRow][_selectedCol] = _level.solution[_selectedRow][_selectedCol];
      _message ='Revealed correct number!';
    });
    _checkBoard();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = AppTheme.accentFor('sudoku');
    final size = _level.size;
    final boardScale = size == 9 ? 300.0 : size == 6 ? 280.0 : 260.0;
    
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        backgroundColor: context.bgDark,
        foregroundColor: context.textPrimary,
        title: Text('Sudoku', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: context.textPrimary)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, size: 20),
            color: context.textMuted,
            onPressed: () => RulesHelper.showRulesBottomSheet(context,'sudoku','Sudoku'),
          ),
          IconButton(
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lightbulb_outline, size: 20, color: Colors.amber),
                  Text('$_hintCount', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber)),
                ],
              ),
              onPressed: _useSudokuHint,
            ),
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _reset, color: context.textMuted),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
'Level ${_levelIndex + 1}',
                style: GoogleFonts.outfit(color: accentColor, fontSize: context.scale(13)),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
              child: Column(
                children: [
                  Text(
'Fill the ${size}x${size} grid so every row, column and subgrid contains unique numbers from 1 to $size',
                    style: GoogleFonts.outfit(color: context.textSecondary, fontSize: context.scale(13)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
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
                            borderRight = (c == 1) ? BorderSide(color: context.textMuted, width: 2) : BorderSide(color: context.textMuted.withAlpha(40), width: 0.5);
                            borderBottom = (r == 1) ? BorderSide(color: context.textMuted, width: 2) : BorderSide(color: context.textMuted.withAlpha(40), width: 0.5);
                          } else if (size == 6) {
                            borderRight = (c == 2) ? BorderSide(color: context.textMuted, width: 2) : BorderSide(color: context.textMuted.withAlpha(40), width: 0.5);
                            borderBottom = (r == 1 || r == 3) ? BorderSide(color: context.textMuted, width: 2) : BorderSide(color: context.textMuted.withAlpha(40), width: 0.5);
                          } else {
                            // size == 9
                            borderRight = (c == 2 || c == 5) ? BorderSide(color: context.textMuted, width: 2) : BorderSide(color: context.textMuted.withAlpha(40), width: 0.5);
                            borderBottom = (r == 2 || r == 5) ? BorderSide(color: context.textMuted, width: 2) : BorderSide(color: context.textMuted.withAlpha(40), width: 0.5);
                          }

                          return GestureDetector(
                            onTap: () => _selectCell(r, c),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSel 
                                    ? accentColor.withAlpha(45) 
                                    : isOrig 
                                        ? context.bgSurface 
                                        : context.bgCard,
                                border: Border(
                                  right: borderRight,
                                  bottom: borderBottom,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  value != 0 ? '$value' : '',
                                  style: GoogleFonts.outfit(
                                    fontSize: context.scale(size == 9 ? 15 : 18),
                                    fontWeight: isOrig ? FontWeight.w900 : FontWeight.w600,
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
                                  color: (_selectedRow != -1) ? accentColor : context.textMuted.withAlpha(50),
                                  width: 1.5,
                                ),
                              ),
                              elevation: 0,
                            ),
                            onPressed: (_selectedRow != -1) ? () => _inputNumber(n) : null,
                            child: Text(
'$n',
                              style: GoogleFonts.outfit(fontSize: context.scale(16), fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: (_selectedRow != -1) ? _clearCell : null,
                          child: Text('CLEAR', style: GoogleFonts.outfit(color: context.textSecondary, fontWeight: FontWeight.bold, fontSize: context.scale(14))),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          onPressed: _checkBoard,
                          child: Text('CHECK', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: context.scale(14))),
                        ),
                      ],
                    ),
                  ] else
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: _nextLevel,
                      child: Text('Next Level →', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: context.scale(14))),
                    ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
