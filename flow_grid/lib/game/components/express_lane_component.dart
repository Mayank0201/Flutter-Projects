import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../models/game_constants.dart';
import '../../models/grid_cell.dart';

class ExpressLaneComponent extends PositionComponent with HasGameReference {
  final GridPosition start;
  final GridPosition end;
  final double cellSize;
  final double offsetX;
  final double offsetY;
  bool isPendingDeletion = false;
  double _animationTime = 0;

  ExpressLaneComponent({
    required this.start,
    required this.end,
    required this.cellSize,
    required this.offsetX,
    required this.offsetY,
  }) {
    priority = 15;
  }

  Offset get startOffset => Offset(
    offsetX + start.x * cellSize + cellSize / 2,
    offsetY + start.y * cellSize + cellSize / 2,
  );

  Offset get endOffset => Offset(
    offsetX + end.x * cellSize + cellSize / 2,
    offsetY + end.y * cellSize + cellSize / 2,
  );

  @override
  void update(double dt) {
    super.update(dt);
    _animationTime += dt * 2.0;
  }

  @override
  void render(Canvas canvas) {
    final s = startOffset;
    final e = endOffset;
    final opacity = isPendingDeletion ? 0.3 : 1.0;

    final delta = e - s;
    final dist = delta.distance;
    if (dist <= 0) return;

    // Calculate control point for a subtle arc
    final mid = (s + e) / 2;
    final unitDir = delta / dist;
    final perp = Offset(-unitDir.dy, unitDir.dx);
    // Arc strength depends on distance
    final arcHeight = dist * 0.15;
    final cp = mid + perp * arcHeight;

    final path = Path()
      ..moveTo(s.dx, s.dy)
      ..quadraticBezierTo(cp.dx, cp.dy, e.dx, e.dy);

    // Shadow
    canvas.drawPath(
      path.shift(const Offset(1, 3)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.2 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cellSize * 0.45
        ..strokeCap = StrokeCap.round,
    );

    // Outer Border
    final borderPaint = Paint()
      ..color = GameConstants.expressLaneBorderColor.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = cellSize * 0.48
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, borderPaint);

    // Inner Main Road (Green)
    final mainPaint = Paint()
      ..color = GameConstants.expressLaneColor.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = cellSize * 0.38
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, mainPaint);

    // Speed arrows (animated along curve)
    final metrics = path.computeMetrics().toList();
    if (metrics.isNotEmpty) {
      final metric = metrics.first;
      final arrowPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.5 * opacity)
        ..strokeWidth = cellSize * 0.06
        ..strokeCap = StrokeCap.round;

      double offset = -(_animationTime % 20);
      while (offset < metric.length) {
        if (offset > 0) {
          final tangent = metric.getTangentForOffset(offset);
          if (tangent != null) {
            final tip = tangent.position;
            final tDir = Offset(tangent.vector.dx, tangent.vector.dy);
            final tPerp = Offset(-tDir.dy, tDir.dx);
            canvas.drawLine(tip - tDir * 5 + tPerp * 4, tip, arrowPaint);
            canvas.drawLine(tip - tDir * 5 - tPerp * 4, tip, arrowPaint);
          }
        }
        offset += 25;
      }
    }
  }
}
