import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../utils/rules_helper.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/hint_manager.dart';

class QueensLevel {
  final int n;
  final List<List<int>> regions;
  const QueensLevel({required this.n, required this.regions});
}

const List<QueensLevel> _kLevels = [
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
  QueensLevel(n: 6, regions: [[0,0,0,1,1,1],[0,2,2,1,3,3],[2,2,4,4,3,3],[5,5,4,4,3,3],[5,5,5,5,3,3],[5,5,5,5,5,3]]),
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
    [0,0,0,0,1,1,1,1,2,2],
    [3,3,3,3,1,4,4,4,2,2],
    [5,5,5,5,1,6,6,6,2,2],
    [7,7,7,7,1,8,8,8,2,2],
    [9,9,9,9,1,9,9,9,2,2],
    [0,0,0,0,1,1,1,1,2,2],
    [3,3,3,3,1,4,4,4,2,2],
    [5,5,5,5,1,6,6,6,2,2],
    [7,7,7,7,1,8,8,8,2,2],
    [9,9,9,9,1,9,9,9,2,2]
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
    [0,0,1,1,2,2,3,3,4,4],
    [0,0,1,1,2,2,3,3,4,4],
    [5,5,6,6,7,7,8,8,9,9],
    [5,5,6,6,7,7,8,8,9,9],
    [0,0,1,1,2,2,3,3,4,4],
    [0,0,1,1,2,2,3,3,4,4],
    [5,5,6,6,7,7,8,8,9,9],
    [5,5,6,6,7,7,8,8,9,9],
    [0,0,1,1,2,2,3,3,4,4],
    [0,0,1,1,2,2,3,3,4,4]
  ]),
  QueensLevel(n: 10, regions: [
    [0,0,0,0,1,1,1,1,2,2],
    [3,0,0,0,1,4,4,4,2,2],
    [3,3,5,5,1,4,6,6,2,2],
    [3,3,5,7,7,7,6,8,2,2],
    [3,3,5,7,9,9,6,8,2,2],
    [3,3,5,7,9,9,6,8,2,2],
    [3,3,5,7,7,7,6,8,2,2],
    [3,3,5,5,1,4,6,6,2,2],
    [3,0,0,0,1,4,4,4,2,2],
    [0,0,0,0,1,1,1,1,2,2]
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
    [0,0,0,0,0,1,1,1,1,1],
    [0,2,2,2,2,3,3,3,3,1],
    [0,2,4,4,4,5,5,5,3,1],
    [0,2,4,6,6,7,7,5,3,1],
    [0,2,4,6,8,9,7,5,3,1],
    [0,2,4,6,9,8,7,5,3,1],
    [0,2,4,6,6,7,7,5,3,1],
    [0,2,4,4,4,5,5,5,3,1],
    [0,2,2,2,2,3,3,3,3,1],
    [0,0,0,0,0,1,1,1,1,1]
  ]),
  // 10 new levels
  QueensLevel(n: 5, regions: [[0,0,0,0,0],[1,1,1,1,1],[2,2,2,2,2],[3,3,3,3,3],[4,4,4,4,4]]),
  QueensLevel(n: 5, regions: [[0,1,2,3,4],[0,1,2,3,4],[0,1,2,3,4],[0,1,2,3,4],[0,1,2,3,4]]),
  QueensLevel(n: 5, regions: [[0,0,1,1,2],[0,0,1,1,2],[3,3,4,4,2],[3,3,4,4,2],[3,3,4,4,2]]),
  QueensLevel(n: 6, regions: [[0,0,0,1,1,1],[2,0,0,1,3,3],[2,2,4,4,3,3],[5,2,4,4,3,3],[5,5,4,4,3,3],[5,5,5,5,3,3]]),
  QueensLevel(n: 6, regions: [[0,0,1,1,2,2],[0,0,1,1,2,2],[3,3,4,4,2,2],[3,3,4,4,5,5],[3,3,4,4,5,5],[3,3,4,4,5,5]]),
  QueensLevel(n: 6, regions: [[0,1,2,3,4,5],[0,1,2,3,4,5],[0,1,2,3,4,5],[0,1,2,3,4,5],[0,1,2,3,4,5],[0,1,2,3,4,5]]),
  QueensLevel(n: 7, regions: [[0,0,0,0,0,0,0],[1,1,1,1,1,1,1],[2,2,2,2,2,2,2],[3,3,3,3,3,3,3],[4,4,4,4,4,4,4],[5,5,5,5,5,5,5],[6,6,6,6,6,6,6]]),
  QueensLevel(n: 7, regions: [[0,0,1,1,2,2,3],[0,0,1,1,2,2,3],[4,4,5,5,6,6,3],[4,4,5,5,6,6,3],[4,4,5,5,6,6,3],[4,4,5,5,6,6,3],[4,4,5,5,6,6,3]]),
  QueensLevel(n: 8, regions: [[0,0,1,1,2,2,3,3],[0,0,1,1,2,2,3,3],[4,4,5,5,6,6,7,7],[4,4,5,5,6,6,7,7],[0,0,1,1,2,2,3,3],[0,0,1,1,2,2,3,3],[4,4,5,5,6,6,7,7],[4,4,5,5,6,6,7,7]]),
  QueensLevel(n: 8, regions: [[0,0,0,0,1,1,1,1],[2,2,2,2,3,3,3,3],[4,4,4,4,5,5,5,5],[6,6,6,6,7,7,7,7],[0,0,0,0,1,1,1,1],[2,2,2,2,3,3,3,3],[4,4,4,4,5,5,5,5],[6,6,6,6,7,7,7,7]]),
];

const List<Color> _kColors = [
  Color(0xFF6AAA64), Color(0xFF4F9EE8), Color(0xFFE67E22),
  Color(0xFFE84F9E), Color(0xFF9B59B6), Color(0xFF1ABC9C), Color(0xFFC9B458),
  Color(0xFF8E7C93), Color(0xFF7A909C), Color(0xFFC5B48D),
];

class QueensScreen extends StatefulWidget {
  const QueensScreen({super.key});
  @override
  State<QueensScreen> createState() => _QueensScreenState();
}

class _QueensScreenState extends State<QueensScreen> {
  int _levelIndex = 0;
  late QueensLevel _level;
  late List<List<int>> _cells; // 0=empty, 1=X, 2=queen
  String _error = '';
  bool _won = false;

  // Drag-to-place-X state
  int _dragTargetState = -1; // -1=not dragging, 0=erasing, 1=placing X
  (int,int)? _lastDragCell;

  int _hintCount = 0;
  final GlobalKey _gridKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Default synchronous initialization to avoid LateInitializationError
    _level = _kLevels[0];
    _cells = List.generate(_level.n, (_) => List.filled(_level.n, 0));
    _initLevel();
  }

  Future<void> _initLevel() async {
    _hintCount = await HintManager.getHints('queens');
    final prefs = await SharedPreferences.getInstance();
    final savedLevel = prefs.getInt('level_queens') ?? 0;
    if (mounted) {
      setState(() {
        _levelIndex = savedLevel % _kLevels.length;
        _loadLevel();
      });
    }
  }

  Future<void> _savePersistedLevel(int lvl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('level_queens', lvl);
    final earned = await HintManager.onLevelCleared('queens');
    final newCount = await HintManager.getHints('queens');
    setState(() {
      _hintCount = newCount;
    });
    if (earned && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hint earned! (Total: $newCount)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: AppTheme.accentFor('queens'),
        ),
      );
    }
  }

  List<(int, int)>? _solveQueens(QueensLevel level) {
    final n = level.n;
    final List<(int, int)> queens = [];

    bool isSafe(int row, int col) {
      for (final q in queens) {
        if (q.$1 == row || q.$2 == col) return false;
        if (level.regions[q.$1][q.$2] == level.regions[row][col]) return false;
        if ((q.$1 - row).abs() == 1 && (q.$2 - col).abs() == 1) return false;
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
    if (_won || _hintCount <= 0) return;
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

    setState(() {
      _hintCount = newCount;
      final tr = targetCell!.$1;
      final tc = targetCell.$2;

      // Clear any other queens in the same row, col, or region
      for (int r = 0; r < _level.n; r++) {
        for (int c = 0; c < _level.n; c++) {
          if (_cells[r][c] == 2) {
            if (r == tr || c == tc || _level.regions[r][c] == _level.regions[tr][tc]) {
              _cells[r][c] = 0;
            }
          }
        }
      }

      // Place the correct queen
      _cells[tr][tc] = 2;
      _error = '';

      // Re-check if this solves the level
      final queensCount = _cells.expand((row) => row).where((cell) => cell == 2).length;
      if (queensCount == _level.n) {
        // Run full validation to check if won
        _check();
      }
    });
  }

  void _loadLevel() {
    _level = _kLevels[_levelIndex % _kLevels.length];
    _cells = List.generate(_level.n, (_) => List.filled(_level.n, 0));
    _error = ''; _won = false;
  }

  void _reset() => setState(() => _loadLevel());

  void _tap(int r, int c) {
    if (_won) return;
    setState(() { _cells[r][c] = (_cells[r][c] + 1) % 3; _error = ''; });
  }

  void _onDragStart(int r, int c) {
    if (_won) return;
    // If starting on empty or X cell, toggle X mode
    // If starting on a queen cell, do nothing special
    if (_cells[r][c] == 2) return;
    setState(() {
      _dragTargetState = _cells[r][c] == 0 ? 1 : 0; // 0=empty → place X; X=1 → erase
      _lastDragCell = (r, c);
      _cells[r][c] = _dragTargetState;
      _error = '';
    });
  }

  void _onDragUpdate(int r, int c) {
    if (_won || _dragTargetState == -1) return;
    if (_lastDragCell == (r, c)) return;
    if (_cells[r][c] == 2) return; // Skip queen cells
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
  }

  void _check() {
    final n = _level.n;
    final queens = <(int,int)>[];
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        if (_cells[r][c] == 2) { queens.add((r,c)); }
      }
    }
    if (queens.length != n) { setState(() => _error = 'Place exactly $n stars.'); return; }
    final rows = <int>{}, cols = <int>{}, regs = <int>{};
    for (final (r,c) in queens) {
      if (rows.contains(r)) { setState(() => _error = 'Two stars in same row!'); return; }
      if (cols.contains(c)) { setState(() => _error = 'Two stars in same column!'); return; }
      final reg = _level.regions[r][c];
      if (regs.contains(reg)) { setState(() => _error = 'Two stars in same color region!'); return; }
      rows.add(r); cols.add(c); regs.add(reg);
      for (final (qr,qc) in queens) {
        if ((qr-r).abs() == 1 && (qc-c).abs() == 1) { setState(() => _error = 'Stars cannot touch diagonally!'); return; }
      }
    }
    setState(() {
      _won = true;
      _error = '';
      _savePersistedLevel(_levelIndex);
    });
  }

  void _nextLevel() {
    setState(() {
      _levelIndex = (_levelIndex + 1) % _kLevels.length;
      _savePersistedLevel(_levelIndex);
      _loadLevel();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        backgroundColor: context.bgDark, foregroundColor: context.textPrimary,
        title: Text('Star Battle', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: context.textPrimary)),
        centerTitle: true,
        actions: [
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
                      '$_hintCount',
                      style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
            onPressed: _hintCount > 0 && !_won ? _useHint : null,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, size: 20),
            color: context.textMuted,
            onPressed: () => RulesHelper.showRulesBottomSheet(context, 'queens', 'Star Battle'),
          ),
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _reset, color: context.textMuted),
          Padding(padding: const EdgeInsets.only(right: 12),
            child: Center(child: Text('Level ${_levelIndex + 1}', style: GoogleFonts.outfit(color: AppTheme.queensOrange, fontSize: context.scale(13))))),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(builder: (ctx, constraints) {
          // Use minimum of available width and height for grid
          final maxDim = min(constraints.maxWidth - 40, constraints.maxHeight - 160);
          final cellSize = maxDim / _level.n;

          return SingleChildScrollView(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const SizedBox(height: 8),
              Text('Tap: empty → X → Star → empty. Drag to place/erase X marks.\nOne Star per row, column & color.',
                style: GoogleFonts.outfit(color: context.textMuted, fontSize: context.scale(12)), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Center(
                child: Column(
                  key: _gridKey,
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(_level.n, (r) =>
                    Row(mainAxisSize: MainAxisSize.min,
                      children: List.generate(_level.n, (c) {
                        final regionId = _level.regions[r][c];
                        final color = _kColors[regionId % _kColors.length];
                        final state = _cells[r][c];
                        return GestureDetector(
                          onTap: () => _tap(r, c),
                          onPanStart: (_) => _onDragStart(r, c),
                          onPanUpdate: (d) {
                            final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
                            if (box == null) return;
                            final localPos = box.globalToLocal(d.globalPosition);
                            final cellDim = cellSize + 3.0; // cellSize + 2 * 1.5 margin
                            final row = (localPos.dy / cellDim).floor();
                            final col = (localPos.dx / cellDim).floor();
                            if (row >= 0 && row < _level.n && col >= 0 && col < _level.n) {
                              _onDragUpdate(row, col);
                            }
                          },
                          onPanEnd: (_) => _onDragEnd(),
                          child: Container(
                            width: cellSize, height: cellSize, margin: const EdgeInsets.all(1.5),
                            decoration: BoxDecoration(
                              color: color.withAlpha(state == 2 ? 200 : 65),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: color.withAlpha(110), width: 1),
                            ),
                            child: Center(child: state == 1
                              ? Text('X', style: TextStyle(fontSize: cellSize * 0.38, color: color, fontWeight: FontWeight.w900))
                              : state == 2
                                ? Text('★', style: TextStyle(fontSize: cellSize * 0.48, color: Colors.white))
                                : null),
                          ),
                        );
                      }))),
                ),
              ),
              const SizedBox(height: 12),
              if (_error.isNotEmpty) Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(_error, style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: context.scale(13)), textAlign: TextAlign.center),
              ),
              const SizedBox(height: 8),
              if (_won) ...[
                Text('All stars placed!', style: GoogleFonts.outfit(fontSize: context.scale(17), color: AppTheme.queensOrange, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                TextButton(onPressed: _nextLevel,
                  child: Text('Next Level →', style: GoogleFonts.outfit(color: AppTheme.queensOrange, fontWeight: FontWeight.w700, fontSize: context.scale(16)))),
              ] else
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.queensOrange, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
                  onPressed: _check,
                  child: Text('Check', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: context.scale(14))),
                ),
              const SizedBox(height: 12),
            ]),
          );
        }),
      ),
    );
  }
}
