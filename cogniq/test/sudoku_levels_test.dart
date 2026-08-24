import 'package:flutter_test/flutter_test.dart';
import 'package:cogniq/screens/games/sudoku/sudoku_levels.dart';

/// Sudoku's win check compares the player's board against the stored solution,
/// so a level whose solution breaks the rules, disagrees with its own givens, or
/// is not the only solution is simply unwinnable. Sixteen of the fifty-six
/// shipped boards failed one of these checks; this pins them.

({int rows, int cols}) boxShape(int size) => switch (size) {
      4 => (rows: 2, cols: 2),
      6 => (rows: 2, cols: 3),
      9 => (rows: 3, cols: 3),
      _ => throw ArgumentError('unsupported size $size'),
    };

bool _canPlace(List<List<int>> g, int n, int r, int c, int v) {
  for (var i = 0; i < n; i++) {
    if (g[r][i] == v || g[i][c] == v) return false;
  }
  final box = boxShape(n);
  final r0 = (r ~/ box.rows) * box.rows;
  final c0 = (c ~/ box.cols) * box.cols;
  for (var i = 0; i < box.rows; i++) {
    for (var j = 0; j < box.cols; j++) {
      if (g[r0 + i][c0 + j] == v) return false;
    }
  }
  return true;
}

/// Counts solutions, stopping at [cap] so a pathological board cannot hang.
int countSolutions(List<List<int>> start, int n, {int cap = 2}) {
  final g = [for (final row in start) List<int>.from(row)];
  var found = 0;

  bool step() {
    var br = -1, bc = -1;
    List<int>? best;
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if (g[r][c] != 0) continue;
        final cand = [
          for (var v = 1; v <= n; v++)
            if (_canPlace(g, n, r, c, v)) v
        ];
        if (cand.isEmpty) return false;
        if (best == null || cand.length < best.length) {
          best = cand;
          br = r;
          bc = c;
        }
      }
    }
    if (best == null) {
      found++;
      return found >= cap;
    }
    for (final v in best) {
      g[br][bc] = v;
      final stop = step();
      g[br][bc] = 0;
      if (stop) return true;
    }
    return false;
  }

  step();
  return found;
}

void main() {
  test('every shipped level is well formed, solvable and unique', () {
    expect(kSudokuLevels, isNotEmpty);

    final failures = <String>[];

    for (var i = 0; i < kSudokuLevels.length; i++) {
      final lvl = kSudokuLevels[i];
      final n = lvl.size;
      final box = boxShape(n);
      final full = {for (var v = 1; v <= n; v++) v};

      void fail(String why) => failures.add('level $i (${n}x$n): $why');

      if (lvl.solution.length != n ||
          lvl.solution.any((r) => r.length != n) ||
          lvl.startBoard.length != n ||
          lvl.startBoard.any((r) => r.length != n)) {
        fail('wrong shape');
        continue;
      }

      for (var r = 0; r < n; r++) {
        if (lvl.solution[r].toSet().difference(full).isNotEmpty ||
            lvl.solution[r].toSet().length != n) {
          fail('row $r is not a permutation of 1..$n');
        }
      }
      for (var c = 0; c < n; c++) {
        final col = {for (var r = 0; r < n; r++) lvl.solution[r][c]};
        if (col.length != n || col.difference(full).isNotEmpty) {
          fail('column $c is not a permutation of 1..$n');
        }
      }
      for (var r0 = 0; r0 < n; r0 += box.rows) {
        for (var c0 = 0; c0 < n; c0 += box.cols) {
          final b = {
            for (var i2 = 0; i2 < box.rows; i2++)
              for (var j = 0; j < box.cols; j++) lvl.solution[r0 + i2][c0 + j]
          };
          if (b.length != n || b.difference(full).isNotEmpty) {
            fail('box at $r0,$c0 is not a permutation of 1..$n');
          }
        }
      }

      for (var r = 0; r < n; r++) {
        for (var c = 0; c < n; c++) {
          final given = lvl.startBoard[r][c];
          if (given != 0 && given != lvl.solution[r][c]) {
            fail('given $given at $r,$c contradicts solution '
                '${lvl.solution[r][c]}');
          }
        }
      }

      final count = countSolutions(lvl.startBoard, n);
      if (count != 1) {
        fail(count == 0
            ? 'givens admit no solution'
            : 'givens admit more than one solution');
      }
    }

    expect(failures, isEmpty,
        reason: 'unwinnable levels:\n${failures.join('\n')}');
  });

  test('only square box shapes may be transposed', () {
    // A 6x6 uses 2x3 boxes, so transposing it yields a board that is valid for
    // 3x2 boxes while the game still validates 2x3. sudoku_screen only
    // transposes when the box is square; this documents why.
    expect(boxShape(4).rows == boxShape(4).cols, isTrue);
    expect(boxShape(9).rows == boxShape(9).cols, isTrue);
    expect(boxShape(6).rows == boxShape(6).cols, isFalse);
  });
}
