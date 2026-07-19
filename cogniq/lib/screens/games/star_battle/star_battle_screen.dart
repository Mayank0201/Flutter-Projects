import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cogniq/widgets/buy_hints_dialog.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../widgets/auto_next_countdown.dart';
import '../../../utils/rules_helper.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/prefs_keys.dart';
import '../../../utils/hint_manager.dart';
import '../../../utils/audio_manager.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../widgets/animated_level_indicator.dart';
import '../../../utils/shuffle_manager.dart';
class QueensLevel {
  final int n;
  final List<List<int>> regions;
  const QueensLevel({required this.n, required this.regions});
}

const List<QueensLevel> _kLevels = [];
/* const List<QueensLevel> _kLevels_disabled = [
  // Easy (Size 4-5)
  QueensLevel(n: 4, regions: [[0,0,1,1],[0,0,1,1],[2,2,3,3],[2,2,3,3]]),
  QueensLevel(n: 4, regions: [[0,1,1,2],[0,1,2,2],[3,3,2,2],[3,3,3,3]]),
  QueensLevel(n: 4, regions: [[0,0,1,1],[0,2,2,1],[0,2,3,3],[0,2,3,3]]),
  QueensLevel(n: 5, regions: [[0,0,1,1,1],[0,0,1,2,2],[3,3,3,2,2],[3,4,4,4,2],[3,4,4,4,4]]),
  // Medium (Size 5-6)
  QueensLevel(n: 5, regions: [[0,0,0,1,1],[0,2,2,1,1],[3,2,2,1,4],[3,3,2,4,4],[3,3,3,4,4]]),
  QueensLevel(n: 5, regions: [[0,1,1,1,1],[0,0,2,2,2],[0,3,3,2,4],[0,3,3,4,4],[0,3,4,4,4]]),
  QueensLevel(n: 6, regions: [[0,0,1,1,2,2],[0,0,1,1,2,2],[3,3,1,1,4,4],[3,3,5,5,4,4],[3,3,5,5,4,4],[3,3,5,5,4,4]]),
  // Hard (Size 6-8)
  QueensLevel(n: 6, regions: [[0,0,0,1,1,1],[2,0,0,1,3,3],[2,2,1,1,3,4],[5,2,1,4,4,4],[5,5,4,4,4,4],[5,5,5,5,4,4]]),
  QueensLevel(n: 7, regions: [[0,0,1,1,2,2,2],[0,0,1,1,2,3,3],[4,4,1,1,2,3,3],[4,4,5,5,2,3,3],[4,4,5,5,6,6,3],[4,4,5,5,6,6,6],[4,4,5,5,6,6,6]]),
  QueensLevel(n: 8, regions: [[0,0,0,1,1,1,2,2],[0,3,3,1,4,4,2,2],[0,3,5,5,4,6,6,2],[3,3,5,7,7,6,2,2],[3,5,5,7,7,6,6,2],[3,5,7,7,7,7,6,2],[3,5,5,7,7,6,6,2],[3,3,3,7,7,7,2,2]]),
  // Expansions
  QueensLevel(n: 4, regions: [[0,0,0,0],[1,1,1,1],[2,2,2,2],[3,3,3,3]]),
  QueensLevel(n: 4, regions: [[0,1,2,3],[0,1,2,3],[0,1,2,3],[0,1,2,3]]),
  QueensLevel(n: 5, regions: [[0,0,0,0,0],[1,1,1,1,2],[3,3,3,2,2],[4,4,3,2,2],[4,4,4,4,2]]),
  QueensLevel(n: 6, regions: [[0, 0, 0, 0, 0, 1], [2, 2, 0, 0, 1, 1], [2, 2, 2, 3, 3, 1], [4, 2, 3, 3, 3, 3], [4, 4, 4, 5, 3, 3], [4, 4, 5, 5, 5, 5]]),
  QueensLevel(n: 7, regions: [[0,0,0,1,1,1,1],[2,0,0,3,1,4,4],[2,2,3,3,1,4,5],[2,6,6,3,1,5,5],[6,6,6,3,1,5,5],[6,6,6,3,1,5,5],[6,6,6,6,1,5,5]]),
  QueensLevel(n: 4, regions: [[0,0,0,1],[2,0,1,1],[2,2,3,1],[2,3,3,3]]),
  QueensLevel(n: 4, regions: [[0,1,1,1],[0,0,2,2],[3,0,0,2],[3,3,3,2]]),
  QueensLevel(n: 5, regions: [[0,0,0,1,1],[2,2,0,1,1],[2,2,3,3,1],[4,4,4,3,3],[4,4,4,4,3]]),
  QueensLevel(n: 5, regions: [[0,0,1,1,1],[0,2,2,2,1],[0,3,3,2,1],[4,4,3,2,1],[4,4,4,4,1]]),
  QueensLevel(n: 5, regions: [[0,1,2,3,4],[0,1,2,3,4],[0,1,2,3,4],[0,1,2,3,4],[0,1,2,3,4]]),
  QueensLevel(n: 6, regions: [[0,0,0,0,1,1],[2,2,2,0,1,1],[2,2,3,3,3,1],[4,4,4,3,3,1],[4,5,5,5,3,1],[4,5,5,5,5,1]]),
  QueensLevel(n: 6, regions: [[0,0,0,1,1,1],[2,2,0,1,3,3],[2,4,4,4,3,5],[2,4,4,4,3,5],[2,4,4,4,3,5],[2,2,2,2,3,5]]),
  QueensLevel(n: 6, regions: [[0,0,1,1,2,2],[0,0,1,1,2,2],[3,3,4,4,2,2],[3,3,4,4,5,5],[3,3,4,4,5,5],[3,3,5,5,5,5]]),
  QueensLevel(n: 7, regions: [[0,0,0,1,1,1,2],[3,3,0,1,4,2,2],[3,5,5,1,4,4,2],[3,5,6,6,6,4,2],[3,5,6,6,6,4,2],[3,5,5,6,4,4,2],[3,3,3,6,6,2,2]]),
  QueensLevel(n: 7, regions: [[0,0,1,1,2,2,3],[0,0,1,1,2,2,3],[4,4,4,1,2,2,3],[4,5,5,5,2,2,3],[4,5,6,6,6,2,3],[4,5,6,6,6,2,3],[4,5,6,6,6,2,3]]),
  QueensLevel(n: 7, regions: [[0,1,2,3,4,5,6],[0,1,2,3,4,5,6],[0,1,2,3,4,5,6],[0,1,2,3,4,5,6],[0,1,2,3,4,5,6],[0,1,2,3,4,5,6],[0,1,2,3,4,5,6]]),
  QueensLevel(n: 8, regions: [[0,0,0,0,1,1,1,1],[2,2,2,2,3,3,3,3],[4,4,4,4,5,5,5,5],[6,6,6,6,7,7,7,7],[0,0,0,0,1,1,1,1],[2,2,2,2,3,3,3,3],[4,4,4,4,5,5,5,5],[6,6,6,6,7,7,7,7]]),
  QueensLevel(n: 8, regions: [[0,0,0,1,1,1,2,2],[0,3,3,1,4,4,2,2],[0,3,5,5,4,6,6,2],[3,3,5,7,7,6,2,2],[3,5,5,7,7,6,6,2],[3,5,7,7,7,7,6,2],[3,5,5,7,7,6,6,2],[3,3,3,7,7,7,2,2]]),
  QueensLevel(n: 8, regions: [[0,0,0,0,0,0,0,0],[1,1,1,1,1,1,1,1],[2,2,2,2,2,2,2,2],[3,3,3,3,3,3,3,3],[4,4,4,4,4,4,4,4],[5,5,5,5,5,5,5,5],[6,6,6,6,6,6,6,6],[7,7,7,7,7,7,7,7]]),
  QueensLevel(n: 8, regions: [[0,1,2,3,4,5,6,7],[0,1,2,3,4,5,6,7],[0,1,2,3,4,5,6,7],[0,1,2,3,4,5,6,7],[0,1,2,3,4,5,6,7],[0,1,2,3,4,5,6,7],[0,1,2,3,4,5,6,7],[0,1,2,3,4,5,6,7]]),
  QueensLevel(n: 8, regions: [[0,0,1,1,2,2,3,3],[0,0,1,1,2,2,3,3],[4,4,5,5,6,6,7,7],[4,4,5,5,6,6,7,7],[0,0,1,1,2,2,3,3],[0,0,1,1,2,2,3,3],[4,4,5,5,6,6,7,7],[4,4,5,5,6,6,7,7]]),
  // Expanded Larger Levels (9x9 and 10x10)
  QueensLevel(n: 9, regions: [
    [0,0,0,1,1,1,2,2,2],
    [0,3,3,1,4,4,2,5,5],
    [0,3,6,6,4,7,7,2,5],
    [3,3,6,8,8,7,2,2,5],
    [3,6,6,8,8,7,7,2,5],
    [3,6,8,8,8,8,7,2,5],
    [3,6,6,8,8,7,7,2,5],
    [3,3,3,8,8,8,2,2,5],
    [3,3,3,3,8,8,2,2,2]
  ]),
  QueensLevel(n: 9, regions: [
    [0,0,0,0,1,1,1,1,1],
    [2,2,2,2,1,3,3,3,3],
    [4,4,4,4,1,5,5,5,5],
    [6,6,6,6,1,7,7,7,7],
    [8,8,8,8,1,8,8,8,8],
    [0,0,0,0,1,1,1,1,1],
    [2,2,2,2,1,3,3,3,3],
    [4,4,4,4,1,5,5,5,5],
    [6,6,6,6,1,7,7,7,7]
  ]),
  QueensLevel(n: 10, regions: [
    [1, 1, 1, 1, 2, 2, 0, 0, 0, 0],
    [1, 1, 1, 1, 2, 2, 2, 0, 0, 0],
    [1, 1, 3, 2, 2, 2, 2, 2, 0, 0],
    [4, 3, 3, 3, 2, 2, 2, 6, 0, 5],
    [4, 4, 3, 3, 2, 7, 6, 6, 5, 5],
    [4, 4, 3, 8, 7, 7, 6, 6, 5, 5],
    [4, 4, 8, 8, 7, 7, 6, 6, 6, 5],
    [4, 8, 8, 8, 7, 7, 7, 6, 6, 5],
    [8, 8, 8, 8, 8, 7, 9, 9, 9, 5],
    [8, 8, 8, 8, 9, 9, 9, 9, 9, 9]
  ]),
  QueensLevel(n: 9, regions: [
    [0,0,1,1,1,2,2,2,2],
    [0,3,1,4,4,4,2,5,5],
    [3,3,1,4,6,6,2,5,7],
    [3,8,8,6,6,6,7,7,7],
    [8,8,8,6,6,6,7,7,7],
    [3,8,8,6,6,6,7,7,7],
    [3,3,1,4,6,6,2,5,7],
    [0,3,1,4,4,4,2,5,5],
    [0,0,1,1,1,2,2,2,2]
  ]),
  QueensLevel(n: 9, regions: [
    [0,0,0,0,0,0,0,0,0],
    [1,1,1,1,1,1,1,1,1],
    [2,2,2,2,2,2,2,2,2],
    [3,3,3,3,3,3,3,3,3],
    [4,4,4,4,4,4,4,4,4],
    [5,5,5,5,5,5,5,5,5],
    [6,6,6,6,6,6,6,6,6],
    [7,7,7,7,7,7,7,7,7],
    [8,8,8,8,8,8,8,8,8]
  ]),
  QueensLevel(n: 9, regions: [
    [0,1,2,3,4,5,6,7,8],
    [0,1,2,3,4,5,6,7,8],
    [0,1,2,3,4,5,6,7,8],
    [0,1,2,3,4,5,6,7,8],
    [0,1,2,3,4,5,6,7,8],
    [0,1,2,3,4,5,6,7,8],
    [0,1,2,3,4,5,6,7,8],
    [0,1,2,3,4,5,6,7,8],
    [0,1,2,3,4,5,6,7,8]
  ]),
  QueensLevel(n: 9, regions: [
    [0,0,0,1,1,1,2,2,2],
    [3,0,0,1,4,4,2,5,5],
    [3,3,6,6,4,4,2,5,7],
    [3,3,6,8,8,8,7,7,7],
    [3,6,6,8,8,8,7,7,7],
    [3,6,8,8,8,8,7,7,7],
    [3,6,6,8,8,8,7,7,7],
    [3,3,3,8,8,8,2,2,5],
    [3,3,3,3,8,8,2,2,2]
  ]),
  QueensLevel(n: 9, regions: [
    [0,0,0,0,1,1,1,1,2],
    [3,3,0,0,1,4,4,2,2],
    [3,5,5,0,1,4,6,2,7],
    [3,5,8,8,8,6,6,7,7],
    [3,5,8,8,8,6,7,7,7],
    [3,5,8,8,8,6,6,7,7],
    [3,5,5,0,1,4,6,2,7],
    [3,3,0,0,1,4,4,2,2],
    [0,0,0,0,1,1,1,1,2]
  ]),
  QueensLevel(n: 10, regions: [
    [0,0,0,0,0,1,1,1,1,1],
    [2,2,2,2,2,3,3,3,3,3],
    [4,4,4,4,4,5,5,5,5,5],
    [6,6,6,6,6,7,7,7,7,7],
    [8,8,8,8,8,9,9,9,9,9],
    [0,0,0,0,0,1,1,1,1,1],
    [2,2,2,2,2,3,3,3,3,3],
    [4,4,4,4,4,5,5,5,5,5],
    [6,6,6,6,6,7,7,7,7,7],
    [8,8,8,8,8,9,9,9,9,9]
  ]),
  QueensLevel(n: 10, regions: [
    [0,1,2,3,4,5,6,7,8,9],
    [0,1,2,3,4,5,6,7,8,9],
    [0,1,2,3,4,5,6,7,8,9],
    [0,1,2,3,4,5,6,7,8,9],
    [0,1,2,3,4,5,6,7,8,9],
    [0,1,2,3,4,5,6,7,8,9],
    [0,1,2,3,4,5,6,7,8,9],
    [0,1,2,3,4,5,6,7,8,9],
    [0,1,2,3,4,5,6,7,8,9],
    [0,1,2,3,4,5,6,7,8,9]
  ]),
  QueensLevel(n: 10, regions: [
    [0,0,0,1,1,1,2,2,2,3],
    [4,0,0,1,5,5,2,6,6,3],
    [4,4,7,7,5,5,2,6,8,3],
    [4,4,7,9,9,9,8,8,8,3],
    [4,7,7,9,9,9,8,8,8,3],
    [4,7,9,9,9,9,8,8,8,3],
    [4,7,7,9,9,9,8,8,8,3],
    [4,4,4,9,9,9,2,2,6,3],
    [4,4,4,4,9,9,2,2,2,3],
    [0,0,0,0,9,9,2,2,2,3]
  ]),
  QueensLevel(n: 10, regions: [
    [1, 1, 1, 1, 1, 2, 0, 0, 0, 0],
    [1, 1, 1, 1, 1, 2, 2, 3, 0, 0],
    [4, 4, 1, 1, 2, 2, 2, 3, 3, 3],
    [4, 4, 4, 1, 2, 2, 3, 3, 3, 3],
    [4, 4, 4, 4, 4, 5, 5, 3, 3, 3],
    [6, 4, 7, 7, 5, 5, 5, 5, 5, 5],
    [6, 6, 7, 7, 8, 5, 5, 5, 5, 9],
    [6, 7, 7, 7, 8, 8, 5, 5, 9, 9],
    [6, 7, 7, 8, 8, 8, 8, 9, 9, 9],
    [6, 7, 7, 8, 8, 8, 9, 9, 9, 9]
  ]),
  QueensLevel(n: 10, regions: [
    [1, 1, 1, 1, 2, 2, 0, 0, 0, 0],
    [1, 1, 1, 1, 2, 2, 2, 3, 0, 0],
    [4, 4, 1, 2, 2, 2, 2, 3, 3, 0],
    [4, 4, 4, 2, 2, 2, 3, 3, 3, 3],
    [4, 4, 4, 4, 2, 6, 3, 3, 5, 5],
    [4, 4, 4, 6, 6, 6, 6, 5, 5, 5],
    [7, 4, 6, 6, 6, 6, 6, 6, 5, 5],
    [7, 7, 7, 9, 6, 6, 8, 8, 5, 5],
    [7, 7, 9, 9, 8, 8, 8, 8, 8, 8],
    [7, 9, 9, 9, 9, 8, 8, 8, 8, 8]
  ]),
  QueensLevel(n: 8, regions: [
    [0,0,0,0,0,0,0,0],
    [1,1,1,1,1,1,1,1],
    [2,2,2,2,2,2,2,2],
    [3,3,3,3,3,3,3,3],
    [4,4,4,4,4,4,4,4],
    [5,5,5,5,5,5,5,5],
    [6,6,6,6,6,6,6,6],
    [7,7,7,7,7,7,7,7]
  ]),
  QueensLevel(n: 8, regions: [
    [0,1,2,3,4,5,6,7],
    [0,1,2,3,4,5,6,7],
    [0,1,2,3,4,5,6,7],
    [0,1,2,3,4,5,6,7],
    [0,1,2,3,4,5,6,7],
    [0,1,2,3,4,5,6,7],
    [0,1,2,3,4,5,6,7],
    [0,1,2,3,4,5,6,7]
  ]),
  QueensLevel(n: 8, regions: [
    [0,0,0,0,1,1,1,1],
    [0,0,0,0,1,1,1,1],
    [2,2,3,3,4,4,5,5],
    [2,2,3,3,4,4,5,5],
    [6,6,3,3,4,4,7,7],
    [6,6,3,3,4,4,7,7],
    [0,0,0,0,1,1,1,1],
    [0,0,0,0,1,1,1,1]
  ]),
  QueensLevel(n: 9, regions: [
    [0,0,0,0,0,0,0,0,0],
    [0,1,1,1,1,1,1,1,0],
    [0,1,2,2,2,2,2,1,0],
    [0,1,2,3,3,3,2,1,0],
    [0,1,2,3,4,3,2,1,0],
    [0,1,2,3,3,3,2,1,0],
    [0,1,2,2,2,2,2,1,0],
    [0,1,1,1,1,1,1,1,0],
    [0,0,0,0,0,0,0,0,0]
  ]),
  QueensLevel(n: 9, regions: [
    [0,0,0,1,1,1,2,2,2],
    [0,0,0,1,1,1,2,2,2],
    [0,0,0,1,1,1,2,2,2],
    [3,3,3,4,4,4,5,5,5],
    [3,3,3,4,4,4,5,5,5],
    [3,3,3,4,4,4,5,5,5],
    [6,6,6,7,7,7,8,8,8],
    [6,6,6,7,7,7,8,8,8],
    [6,6,6,7,7,7,8,8,8]
  ]),
  QueensLevel(n: 10, regions: [
    [0,0,0,0,0,0,0,0,0,0],
    [1,1,1,1,1,1,1,1,1,1],
    [2,2,2,2,2,2,2,2,2,2],
    [3,3,3,3,3,3,3,3,3,3],
    [4,4,4,4,4,4,4,4,4,4],
    [5,5,5,5,5,5,5,5,5,5],
    [6,6,6,6,6,6,6,6,6,6],
    [7,7,7,7,7,7,7,7,7,7],
    [8,8,8,8,8,8,8,8,8,8],
    [9,9,9,9,9,9,9,9,9,9]
  ]),
  QueensLevel(n: 10, regions: [
    [0,1,2,3,4,5,6,7,8,9],
    [0,1,2,3,4,5,6,7,8,9],
    [0,1,2,3,4,5,6,7,8,9],
    [0,1,2,3,4,5,6,7,8,9],
    [0,1,2,3,4,5,6,7,8,9],
    [0,1,2,3,4,5,6,7,8,9],
    [0,1,2,3,4,5,6,7,8,9],
    [0,1,2,3,4,5,6,7,8,9],
    [0,1,2,3,4,5,6,7,8,9],
    [0,1,2,3,4,5,6,7,8,9]
  ]),
  QueensLevel(n: 9, regions: [
    [0,1,2,3,4,5,6,7,8],
    [1,2,3,4,5,6,7,8,0],
    [2,3,4,5,6,7,8,0,1],
    [3,4,5,6,7,8,0,1,2],
    [4,5,6,7,8,0,1,2,3],
    [5,6,7,8,0,1,2,3,4],
    [6,7,8,0,1,2,3,4,5],
    [7,8,0,1,2,3,4,5,6],
    [8,0,1,2,3,4,5,6,7]
  ]),
  QueensLevel(n: 9, regions: [
    [0,0,0,0,0,0,0,0,0],
    [1,1,1,1,1,1,1,1,0],
    [1,2,2,2,2,2,2,2,0],
    [1,2,3,3,3,3,3,3,0],
    [1,2,3,4,4,4,4,4,0],
    [1,2,3,5,5,5,5,5,0],
    [1,2,6,6,6,6,6,6,0],
    [1,7,7,7,7,7,7,7,0],
    [8,8,8,8,8,8,8,8,0]
  ]),
  QueensLevel(n: 10, regions: [
    [2, 2, 1, 1, 0, 0, 0, 0, 0, 0],
    [2, 2, 1, 1, 1, 0, 3, 3, 4, 4],
    [2, 2, 2, 1, 1, 3, 3, 3, 4, 4],
    [2, 2, 2, 1, 3, 3, 3, 3, 4, 4],
    [6, 2, 5, 5, 3, 3, 3, 4, 4, 4],
    [6, 5, 5, 5, 5, 3, 3, 7, 4, 4],
    [6, 6, 5, 5, 9, 7, 7, 7, 7, 8],
    [6, 6, 5, 9, 9, 7, 7, 7, 7, 8],
    [6, 6, 9, 9, 9, 9, 7, 7, 8, 8],
    [6, 9, 9, 9, 9, 9, 9, 7, 8, 8]
  ]),
  // 10 new levels
  QueensLevel(n: 5, regions: [[0,0,0,0,0],[1,1,1,1,1],[2,2,2,2,2],[3,3,3,3,3],[4,4,4,4,4]]),
  QueensLevel(n: 5, regions: [[0,1,2,3,4],[0,1,2,3,4],[0,1,2,3,4],[0,1,2,3,4],[0,1,2,3,4]]),
  QueensLevel(n: 5, regions: [[0,0,1,1,2],[0,0,1,1,2],[3,3,4,4,2],[3,3,4,4,2],[3,3,4,4,2]]),
  QueensLevel(n: 6, regions: [[0,0,0,1,1,1],[2,0,0,1,3,3],[2,2,4,4,3,3],[5,2,4,4,3,3],[5,5,4,4,3,3],[5,5,5,5,3,3]]),
  QueensLevel(n: 6, regions: [[0,0,1,1,2,2],[0,0,1,1,2,2],[3,3,4,4,2,2],[3,3,4,4,5,5],[3,3,4,4,5,5],[3,3,4,4,5,5]]),
  QueensLevel(n: 6, regions: [[0,1,2,3,4,5],[0,1,2,3,4,5],[0,1,2,3,4,5],[0,1,2,3,4,5],[0,1,2,3,4,5],[0,1,2,3,4,5]]),
  QueensLevel(n: 7, regions: [[0,0,0,0,0,0,0],[1,1,1,1,1,1,1],[2,2,2,2,2,2,2],[3,3,3,3,3,3,3],[4,4,4,4,4,4,4],[5,5,5,5,5,5,5],[6,6,6,6,6,6,6]]),
  QueensLevel(n: 7, regions: [[0, 0, 0, 0, 2, 1, 1], [0, 0, 3, 2, 2, 1, 1], [4, 3, 3, 2, 2, 2, 1], [4, 3, 3, 3, 2, 5, 1], [4, 4, 3, 3, 5, 5, 5], [4, 4, 3, 6, 5, 5, 5], [4, 6, 6, 6, 6, 5, 5]]),
  QueensLevel(n: 8, regions: [[0,0,1,1,2,2,3,3],[0,0,1,1,2,2,3,3],[4,4,5,5,6,6,7,7],[4,4,5,5,6,6,7,7],[0,0,1,1,2,2,3,3],[0,0,1,1,2,2,3,3],[4,4,5,5,6,6,7,7],[4,4,5,5,6,6,7,7]]),
  QueensLevel(n: 8, regions: [[0,0,0,0,1,1,1,1],[2,2,2,2,3,3,3,3],[4,4,4,4,5,5,5,5],[6,6,6,6,7,7,7,7],[0,0,0,0,1,1,1,1],[2,2,2,2,3,3,3,3],[4,4,4,4,5,5,5,5],[6,6,6,6,7,7,7,7]]),
  QueensLevel(n: 5, regions: [[0,0,0,1,1],[2,0,0,1,1],[2,2,3,3,3],[4,2,3,3,3],[4,4,4,3,3]]),
  QueensLevel(n: 6, regions: [[0,0,0,1,1,1],[0,2,2,1,1,3],[4,2,2,5,5,3],[4,4,2,5,5,3],[4,4,2,2,5,3],[4,4,4,2,5,5]]),
  QueensLevel(n: 7, regions: [[0,0,0,1,1,1,2],[3,0,0,1,4,2,2],[3,3,0,1,4,4,2],[3,3,5,5,4,4,2],[3,5,5,5,5,4,2],[3,6,6,6,6,4,2],[3,6,6,6,6,6,2]]),
  QueensLevel(n: 8, regions: [[0,0,0,0,1,1,1,1],[0,2,2,2,1,3,3,3],[0,2,4,4,1,3,5,5],[0,2,4,6,6,3,5,7],[0,2,4,6,6,3,5,7],[0,2,4,4,1,3,5,5],[0,2,2,2,1,3,3,3],[0,0,0,0,1,1,1,1]]),
]; */

class StarBattleScreen extends StatefulWidget {
  final int? dailyLevelIndex;
  const StarBattleScreen({super.key, this.dailyLevelIndex});
  @override
  State<StarBattleScreen> createState() => _StarBattleScreenState();
}

class _StarBattleScreenState extends State<StarBattleScreen> {
  int _levelIndex = 0;
  late QueensLevel _level;
  late List<List<int>> _cells; // 0=empty, 1=X, 2=queen
  String _error = '';
  bool _won = false;
  bool _isTutorialMode = false;
  bool _tutorialCompleted = false;
  int _actualGameLevel = 0;
  bool _playDailyMode = false;
  String _dailyModifierType = '';
  String _dailyModifierName = '';
  String _dailyModifierDesc = '';

  // Drag-to-place-X state
  int _dragTargetState = -1; // -1=not dragging, 0=erasing, 1=placing X
  (int,int)? _lastDragCell;

  int _hintCount = 0;
  final GlobalKey _gridKey = GlobalKey();
  final List<List<List<int>>> _history = [];
  bool _shuffleActive = false;

  @override
  void initState() {
    super.initState();
    // Default synchronous initialization to avoid LateInitializationError
    _level = generateProceduralLevel(5, Random(8734));
    _cells = List.generate(_level.n, (_) => List.filled(_level.n, 0));
    _initLevel();
  }

  QueensLevel generateProceduralLevel(int n, Random rand) {
    // 1. Place stars first to guarantee a solution exists
    List<(int, int)>? starCoords = placeStars(n, rand);
    int retries = 0;
    while (starCoords == null && retries < 100) {
      starCoords = placeStars(n, Random(rand.nextInt(100000) + retries));
      retries++;
    }
    
    // Fail-safe diagonal placement if retries fail
    if (starCoords == null) {
      starCoords = [];
      for (int i = 0; i < n; i++) {
        starCoords.add((i, i));
      }
    }

    final grid = List.generate(n, (_) => List.generate(n, (_) => -1));
    final seeds = <(int, int)>[];
    for (int i = 0; i < n; i++) {
      final (r, c) = starCoords[i];
      grid[r][c] = i;
      seeds.add((r, c));
    }

    // 2. Grow regions around seeds using cellular growth
    final borderCells = <int, List<(int, int)>>{};
    for (int i = 0; i < n; i++) {
      borderCells[i] = [seeds[i]];
    }

    bool hasUnassigned = true;
    while (hasUnassigned) {
      hasUnassigned = false;
      for (int i = 0; i < n; i++) {
        final borders = borderCells[i]!;
        if (borders.isEmpty) continue;
        final neighbors = <(int, int)>[];
        for (final cell in borders) {
          final (r, c) = cell;
          final dirs = [(0, 1), (0, -1), (1, 0), (-1, 0)];
          for (final (dr, dc) in dirs) {
            final nr = r + dr;
            final nc = c + dc;
            if (nr >= 0 && nr < n && nc >= 0 && nc < n && grid[nr][nc] == -1) {
              if (!neighbors.contains((nr, nc))) {
                neighbors.add((nr, nc));
              }
            }
          }
        }
        if (neighbors.isNotEmpty) {
          hasUnassigned = true;
          final nextCell = neighbors[rand.nextInt(neighbors.length)];
          final (nr, nc) = nextCell;
          grid[nr][nc] = i;
          borders.add(nextCell);
        } else {
          borders.clear();
        }
      }

      if (!hasUnassigned) {
        for (int r = 0; r < n; r++) {
          for (int c = 0; c < n; c++) {
            if (grid[r][c] == -1) {
              int minDist = 9999;
              int bestRegion = 0;
              for (int sr = 0; sr < n; sr++) {
                for (int sc = 0; sc < n; sc++) {
                  if (grid[sr][sc] != -1) {
                    final dist = (sr - r).abs() + (sc - c).abs();
                    if (dist < minDist) {
                      minDist = dist;
                      bestRegion = grid[sr][sc];
                    }
                  }
                }
              }
              grid[r][c] = bestRegion;
              hasUnassigned = true;
            }
          }
        }
      }
    }
    return QueensLevel(n: n, regions: grid);
  }

  List<(int, int)>? placeStars(int n, Random rand) {
    for (int attempt = 0; attempt < 200; attempt++) {
      final stars = <(int, int)>[];
      final cols = List.generate(n, (i) => i)..shuffle(rand);
      bool backtrack(int row) {
        if (row == n) return true;
        final shuffledCols = List<int>.from(cols);
        for (final col in shuffledCols) {
          bool ok = true;
          for (final (sr, sc) in stars) {
            if (sc == col) { ok = false; break; }
            if ((sr - row).abs() == 1 && (sc - col).abs() == 1) { ok = false; break; }
            if (_playDailyMode && _dailyModifierType == 'hidden_rule') {
              if ((sr - row).abs() == (sc - col).abs()) { ok = false; break; }
            }
          }
          if (ok) {
            stars.add((row, col));
            if (backtrack(row + 1)) return true;
            stars.removeLast();
          }
        }
        return false;
      }
      if (backtrack(0)) return stars;
    }
    return null;
  }

  void _saveToHistory() {
    _history.add(_cells.map((row) => List<int>.from(row)).toList());
    if (_history.length > 50) {
      _history.removeAt(0);
    }
  }

  void _undo() {
    if (_history.isEmpty || _won) return;
    setState(() {
      _cells = _history.removeLast();
      _error = '';
    });
    _saveNormalState();
  }

  Future<void> _initLevel() async {
    _hintCount = await HintManager.getHints('queens');
    final prefs = await SharedPreferences.getInstance();
    _playDailyMode = prefs.getBool(PrefsKeys.playDailyMode) ?? false;
    if (_playDailyMode) {
      _dailyModifierType = prefs.getString(PrefsKeys.dailyModifierType) ?? '';
      _dailyModifierName = prefs.getString(PrefsKeys.dailyModifierName) ?? '';
      _dailyModifierDesc = prefs.getString(PrefsKeys.dailyModifierDesc) ?? '';
    } else {
      _dailyModifierType = '';
      _dailyModifierName = '';
      _dailyModifierDesc = '';
    }
    
    int targetLevel = 0;
    if (widget.dailyLevelIndex != null) {
      targetLevel = widget.dailyLevelIndex!;
    } else {
      targetLevel = prefs.getInt(PrefsKeys.gameLevel('queens')) ?? 0;
    }



    final active = await ShuffleManager.isActive();

    _isTutorialMode = false;
    _levelIndex = targetLevel;

    if (mounted) {
      setState(() {
        _shuffleActive = active;
        _loadLevel();
      });
    }

    if (!_playDailyMode && !_isTutorialMode) {
      Future.delayed(Duration.zero, () async {
        if (!mounted) return;
        final savedStateStr = prefs.getString(PrefsKeys.normalGameState('queens'));
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
                final List<dynamic> cellsData = data['cells'];
                final List<List<int>> loadedCells = cellsData.map((row) => List<int>.from(row)).toList();
                setState(() {
                  _cells = loadedCells;
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
  }



  Future<void> _saveNormalState() async {
    if (_playDailyMode || _won) return;
    final prefs = await SharedPreferences.getInstance();
    final state = {
      'levelIndex': _levelIndex,
      'cells': _cells,
    };
    await prefs.setString(PrefsKeys.normalGameState('queens'), jsonEncode(state));
  }

  Future<void> _clearNormalState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(PrefsKeys.normalGameState('queens'));
  }

  Future<void> _savePersistedLevel(int lvl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(PrefsKeys.gameLevel('queens'), lvl);
    final earned = await HintManager.onLevelCleared('queens');
    final newCount = await HintManager.getHints('queens');
    setState(() {
      _hintCount = newCount;
    });
    
    await _clearNormalState();
  }

  List<(int, int)>? _solveQueens(QueensLevel level) {
    final n = level.n;
    final List<(int, int)> queens = [];

    bool isSafe(int row, int col) {
      for (final q in queens) {
        if (q.$1 == row || q.$2 == col) return false;
        if (level.regions[q.$1][q.$2] == level.regions[row][col]) return false;
        if ((q.$1 - row).abs() == 1 && (q.$2 - col).abs() == 1) return false;
        if (_playDailyMode && _dailyModifierType == 'hidden_rule') {
          if ((q.$1 - row).abs() == (q.$2 - col).abs()) return false;
        }
      }
      return true;
    }

    bool backtrack(int row) {
      if (row == n) return true;
      for (int col = 0; col < n; col++) {
        if (isSafe(row, col)) {
          queens.add((row, col));
          if (backtrack(row + 1)) return true;
          queens.removeLast();
        }
      }
      return false;
    }

    if (backtrack(0)) return queens;
    return null;
  }

  Future<void> _useHint() async {
    if (_won) return;

    if (_hintCount <= 0) {
      BuyHintsDialog.show(
        context,
        initialGameId: 'queens',
        isFromGameScreen: true,
        onPurchaseComplete: () {
          HintManager.getHints('queens').then((val) {
            if (mounted) setState(() => _hintCount = val);
          });
        },
      );
      return;
    }

    final solution = _solveQueens(_level);
    if (solution == null) return;

    // Find the first star from solution not placed yet
    (int, int)? targetCell;
    for (final cell in solution) {
      if (_cells[cell.$1][cell.$2] != 2) {
        targetCell = cell;
        break;
      }
    }

    if (targetCell == null) return;

    await HintManager.useHint('queens');
    final newCount = await HintManager.getHints('queens');
    AudioManager.playClick();

    setState(() {
      _hintCount = newCount;
    });

    final int targetRow = targetCell.$1;
    final int targetCol = targetCell.$2;
    final int half = (_level.n / 2).ceil();
    final String colRange = targetCol < half ? "1 to $half" : "${half + 1} to ${_level.n}";
    final String message = "Hint: A star belongs in Row ${targetRow + 1}, columns $colRange.";

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        duration: const Duration(seconds: 4),
        backgroundColor: AppTheme.accentFor('queens'),
      ),
    );
  }

  void _loadLevel() {
    int n = 5;
    if (_levelIndex < 5) {
      n = 5;
    } else if (_levelIndex < 15) {
      n = 6;
    } else if (_levelIndex < 30) {
      n = 7;
    } else if (_levelIndex < 50) {
      n = 8;
    } else if (_levelIndex < 75) {
      n = 9;
    } else {
      n = 10;
    }
    _level = generateProceduralLevel(n, Random(_levelIndex + 8734));
    _cells = List.generate(_level.n, (_) => List.filled(_level.n, 0));
    _history.clear();
    _error = ''; _won = false;
  }

  void _reset() => setState(() => _loadLevel());

  void _tap(int r, int c) {
    if (_won) return;
    AudioManager.playClick();
    _saveToHistory();
    setState(() { _cells[r][c] = (_cells[r][c] + 1) % 3; _error = ''; });
    _saveNormalState();
  }

  void _onDragStart(int r, int c) {
    if (_won) return;
    if (_cells[r][c] == 2) return;
    AudioManager.playClick();
    _saveToHistory();
    setState(() {
      _dragTargetState = _cells[r][c] == 0 ? 1 : 0;
      _lastDragCell = (r, c);
      _cells[r][c] = _dragTargetState;
      _error = '';
    });
  }

  void _onDragUpdate(int r, int c) {
    if (_won || _dragTargetState == -1) return;
    if (_lastDragCell == (r, c)) return;
    if (_cells[r][c] == 2) return; // Skip queen cells
    AudioManager.playClick();
    setState(() {
      _lastDragCell = (r, c);
      _cells[r][c] = _dragTargetState;
      _error = '';
    });
  }

  void _onDragEnd() {
    setState(() {
      _dragTargetState = -1;
      _lastDragCell = null;
    });
    _saveNormalState();
  }

  void _check() {
    final n = _level.n;
    final queens = <(int,int)>[];
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        if (_cells[r][c] == 2) { queens.add((r,c)); }
      }
    }
    final targetQueensCount = (_playDailyMode && _dailyModifierType == 'spy') ? (n - 1) : n;
    if (queens.length != targetQueensCount) {
      AudioManager.playFail();
      setState(() => _error = 'Place exactly $targetQueensCount stars.');
      return;
    }
    final rows = <int>{}, cols = <int>{};
    final regCounts = <int, int>{};
    for (final (r,c) in queens) {
      if (rows.contains(r)) {
        AudioManager.playFail();
        setState(() => _error = 'Two stars in same row!');
        return;
      }
      if (cols.contains(c)) {
        AudioManager.playFail();
        setState(() => _error = 'Two stars in same column!');
        return;
      }
      final reg = _level.regions[r][c];
      regCounts[reg] = (regCounts[reg] ?? 0) + 1;
      rows.add(r); cols.add(c);
      for (final (qr,qc) in queens) {
        if ((qr-r).abs() == 1 && (qc-c).abs() == 1) {
          AudioManager.playFail();
          setState(() => _error = 'Stars cannot touch diagonally!');
          return;
        }
        if (_playDailyMode && _dailyModifierType == 'hidden_rule') {
          if ((qr-r).abs() == (qc-c).abs() && qr != r) {
            AudioManager.playFail();
            setState(() => _error = 'Diagonal Shield: Stars cannot share a diagonal!');
            return;
          }
        }
      }
    }
    if (_playDailyMode && _dailyModifierType == 'spy') {
      for (final count in regCounts.values) {
        if (count > 1) {
          AudioManager.playFail();
          setState(() => _error = 'Decoy Region: No region can have more than 1 star!');
          return;
        }
      }
    } else {
      for (final count in regCounts.values) {
        if (count > 1) {
          AudioManager.playFail();
          setState(() => _error = 'Two stars in same region!');
          return;
        }
      }
    }
    AudioManager.playSuccess();
    if (_isTutorialMode) {
      setState(() {
        _tutorialCompleted = true;
        _error = '';
      });
      return;
    }
    setState(() {
      _won = true;
      _error = '';
      _savePersistedLevel(_levelIndex + 1);
    });
  }

  void _nextLevel() async {
    if (!_won) return;
    if (await ShuffleManager.tryShuffleNavigate(context, 'queens')) return;

    setState(() {
      _levelIndex = _levelIndex + 1;
      _loadLevel();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        backgroundColor: context.bgDark, foregroundColor: context.textPrimary,
        title: Text(_isTutorialMode ? 'Tutorial' : 'Star Battle', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: context.textPrimary)),
        centerTitle: true,
        actions: [
          if (_shuffleActive && !_isTutorialMode)
            IconButton(
              icon: const Icon(Icons.skip_next_rounded),
              tooltip: 'Skip Game',
              onPressed: () => ShuffleManager.tryShuffleNavigate(context, 'queens'),
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
            onPressed: !_won && !_isTutorialMode
                ? () async {
                    if (_hintCount > 0) {
                      _useHint();
                    } else {
                      await BuyHintsDialog.show(
                        context,
                        initialGameId: 'queens',
                        onPurchaseComplete: () async {
                          final newCount = await HintManager.getHints('queens');
                          if (mounted) setState(() => _hintCount = newCount);
                        },
                      );
                    }
                  }
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.undo, size: 20),
            color: context.textMuted,
            onPressed: _history.isNotEmpty && !_won && !_isTutorialMode ? _undo : null,
          ),
          if (MediaQuery.of(context).size.width < 360)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: context.textMuted),
              onSelected: (val) {
                if (val == 'help') {
                  RulesHelper.showRulesBottomSheet(context, 'queens', 'Star Battle');
                } else if (val == 'reset') {
                  _reset();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'help',
                  child: Row(
                    children: [
                      Icon(Icons.help_outline, size: 20),
                      SizedBox(width: 8),
                      Text('Rules'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'reset',
                  child: Row(
                    children: [
                      Icon(Icons.refresh, size: 20),
                      SizedBox(width: 8),
                      Text('Reset'),
                    ],
                  ),
                ),
              ],
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.help_outline, size: 20),
              color: context.textMuted,
              onPressed: () => RulesHelper.showRulesBottomSheet(context, 'queens', 'Star Battle'),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: _reset,
              color: context.textMuted,
            ),
          ],
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _isTutorialMode
                ? Text(
                    'Tutorial',
                    style: GoogleFonts.outfit(
                      color: AppTheme.queensOrange,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : AnimatedLevelIndicator(
                    level: _levelIndex + 1,
                    accentColor: AppTheme.queensOrange,
                    label: MediaQuery.of(context).size.width < 360 ? 'L.' : 'Level',
                  ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: LayoutBuilder(builder: (ctx, constraints) {
              // Use minimum of available width and height for grid
              final maxDim = min(constraints.maxWidth - 40, constraints.maxHeight - 160);
              final cellSize = maxDim / _level.n;

              return Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (_playDailyMode && _dailyModifierName.isNotEmpty)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          color: Colors.amber.withOpacity(0.12),
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
                                        letterSpacing: 1.1,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _dailyModifierDesc,
                                style: GoogleFonts.outfit(
                                  color: context.textSecondary,
                                  fontSize: context.scale(11),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text('Tap: empty → X → Star → empty. Drag to place/erase X marks.\nOne Star per row, column & color.',
                        style: GoogleFonts.outfit(color: context.textMuted, fontSize: context.scale(12)), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: RepaintBoundary(
                            child: GestureDetector(
                            onTapUp: (details) {
                              final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
                              if (box == null) return;
                              final localPos = box.globalToLocal(details.globalPosition);
                              final row = (localPos.dy / cellSize).floor();
                              final col = (localPos.dx / cellSize).floor();
                              if (row >= 0 && row < _level.n && col >= 0 && col < _level.n) {
                                _tap(row, col);
                              }
                            },
                            onPanStart: (details) {
                              final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
                              if (box == null) return;
                              final localPos = box.globalToLocal(details.globalPosition);
                              final row = (localPos.dy / cellSize).floor();
                              final col = (localPos.dx / cellSize).floor();
                              if (row >= 0 && row < _level.n && col >= 0 && col < _level.n) {
                                _onDragStart(row, col);
                              }
                            },
                            onPanUpdate: (details) {
                              final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
                              if (box == null) return;
                              final localPos = box.globalToLocal(details.globalPosition);
                              final row = (localPos.dy / cellSize).floor();
                              final col = (localPos.dx / cellSize).floor();
                              if (row >= 0 && row < _level.n && col >= 0 && col < _level.n) {
                                _onDragUpdate(row, col);
                              }
                            },
                            onPanEnd: (_) => _onDragEnd(),
                            onPanCancel: () => _onDragEnd(),
                            child: Column(
                              key: _gridKey,
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(_level.n, (r) =>
                                Row(mainAxisSize: MainAxisSize.min,
                                  children: List.generate(_level.n, (c) {
                                    final regionId = _level.regions[r][c];
                                    final state = _cells[r][c];

                                    final borderColor = context.textPrimary;
                                    final dividerColor = context.textSecondary.withAlpha(60);

                                    BorderSide getTopBorder() {
                                      if (r == 0 || _level.regions[r - 1][c] != regionId) {
                                        return BorderSide(color: borderColor, width: 2.5);
                                      }
                                      return BorderSide(color: dividerColor, width: 0.8);
                                    }

                                    BorderSide getLeftBorder() {
                                      if (c == 0 || _level.regions[r][c - 1] != regionId) {
                                        return BorderSide(color: borderColor, width: 2.5);
                                      }
                                      return BorderSide(color: dividerColor, width: 0.8);
                                    }

                                    BorderSide getRightBorder() {
                                      if (c == _level.n - 1) {
                                        return BorderSide(color: borderColor, width: 2.5);
                                      }
                                      return BorderSide(color: dividerColor, width: 0.8);
                                    }

                                    BorderSide getBottomBorder() {
                                      if (r == _level.n - 1) {
                                        return BorderSide(color: borderColor, width: 2.5);
                                      }
                                      return BorderSide(color: dividerColor, width: 0.8);
                                    }

                                    return Builder(
                                      builder: (context) {
                                        final regionColorsLight = const [
                                          Color(0xFFFBCFE8), // Pink
                                          Color(0xFFBFDBFE), // Blue
                                          Color(0xFFA7F3D0), // Green
                                          Color(0xFFFDE68A), // Yellow
                                          Color(0xFFDDD6FE), // Purple
                                          Color(0xFFFED7AA), // Orange
                                          Color(0xFF99F6E4), // Teal
                                          Color(0xFFC7D2FE), // Indigo
                                          Color(0xFFFECDD3), // Rose
                                          Color(0xFFE2E8F0), // Slate/Gray
                                        ];
                                        final regionColorsDark = const [
                                          Color(0xFF6E284E), // Dark Muted Pink
                                          Color(0xFF1E3A5F), // Dark Muted Blue
                                          Color(0xFF154C34), // Dark Muted Green
                                          Color(0xFF614E18), // Dark Muted Yellow
                                          Color(0xFF3F3066), // Dark Muted Purple
                                          Color(0xFF613B17), // Dark Muted Orange
                                          Color(0xFF184A45), // Dark Muted Teal
                                          Color(0xFF223161), // Dark Muted Indigo
                                          Color(0xFF63242F), // Dark Muted Rose
                                          Color(0xFF1E293B), // Dark Muted Slate
                                        ];
                                        final regionColor = context.isDarkMode 
                                            ? regionColorsDark[regionId % regionColorsDark.length]
                                            : regionColorsLight[regionId % regionColorsLight.length];

                                        String cellLabel = 'Cell Row ${r + 1}, Column ${c + 1}, Region ${regionId + 1}';
                                        if (state == 1) {
                                          cellLabel += ', X mark';
                                        } else if (state == 2) {
                                          cellLabel += ', Star';
                                        } else {
                                          cellLabel += ', empty';
                                        }

                                        return Semantics(
                                          label: cellLabel,
                                          child: Container(
                                            width: cellSize, height: cellSize,
                                            decoration: BoxDecoration(
                                              color: regionColor,
                                              border: Border(
                                                top: getTopBorder(),
                                                left: getLeftBorder(),
                                                right: getRightBorder(),
                                                bottom: getBottomBorder(),
                                              ),
                                            ),
                                            child: Center(
                                              child: AnimatedSwitcher(
                                                duration: const Duration(milliseconds: 180),
                                                transitionBuilder: (child, animation) {
                                                  return ScaleTransition(
                                                    scale: animation,
                                                    child: child,
                                                  );
                                                },
                                                child: state == 1
                                                    ? Text(
                                                        'X',
                                                        key: const ValueKey('x_marker'),
                                                        style: TextStyle(
                                                          fontSize: cellSize * 0.38,
                                                          color: context.isDarkMode ? Colors.white70 : Colors.black87,
                                                          fontWeight: FontWeight.w900,
                                                        ),
                                                      )
                                                    : state == 2
                                                        ? Text(
                                                            '★',
                                                            key: const ValueKey('star_marker'),
                                                            style: TextStyle(
                                                              fontSize: cellSize * 0.52,
                                                              color: AppTheme.warmAmber,
                                                              shadows: const [
                                                                Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(1, 1))
                                                              ],
                                                            ),
                                                          )
                                                              .animate()
                                                              .scale(
                                                                begin: const Offset(0.3, 0.3),
                                                                end: const Offset(1.0, 1.0),
                                                                duration: 350.ms,
                                                                curve: Curves.easeOutBack,
                                                              )
                                                              .shimmer(
                                                                duration: 400.ms,
                                                                color: Colors.white.withOpacity(0.4),
                                                              )
                                                        : const SizedBox(key: ValueKey('empty_marker')),
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                    );
                                  }))),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_error.isNotEmpty) Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(_error, style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: context.scale(13)), textAlign: TextAlign.center),
                      ),
                      const SizedBox(height: 8),
                      if (_won && !_isTutorialMode) ...[
                        Text('All stars placed!', style: GoogleFonts.outfit(fontSize: context.scale(17), color: AppTheme.queensOrange, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),
                        AutoNextCountdown(
                          onNext: _nextLevel,
                          accentColor: AppTheme.queensOrange,
                        ),
                      ] else if (!_tutorialCompleted && !_won)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.queensOrange, foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
                          onPressed: _check,
                          child: Text('Check', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: context.scale(14))),
                        ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              );
            }),
          ),
          // if (_isTutorialMode)
          //   InteractiveTutorialOverlay(
          //     instruction: _tutorialCompleted
          //         ? "Nice! You successfully solved the Star Battle puzzle."
          //         : "Place exactly 1 star in every row, column, and colored region. Stars cannot touch each other, not even diagonally!",
          //     isCompleted: _tutorialCompleted,
          //     onSkip: _finishTutorial,
          //     onStartGame: _finishTutorial,
          //   ),
        ],
      ),
    );
  }
}
