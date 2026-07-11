import 'package:flutter/material.dart';

class SpotifyCurvedLinesIcon extends StatelessWidget {
  final Color color;
  final double size;

  const SpotifyCurvedLinesIcon({
    super.key,
    required this.color,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _SpotifyCurvedLinesPainter(color: color),
    );
  }
}

class _SpotifyCurvedLinesPainter extends CustomPainter {
  final Color color;

  _SpotifyCurvedLinesPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.save();
    // Center of canvas
    canvas.translate(w * 0.5, h * 0.5);
    // Rotate to match the Spotify angle
    canvas.rotate(-0.2);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w * 0.1;

    // Center of the concentric arcs placed bottom-left
    final center = Offset(-w * 0.35, h * 0.35);

    // Draw three concentric arcs
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: w * 0.6),
      -0.8,
      0.8,
      false,
      paint,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: w * 0.9),
      -0.8,
      0.8,
      false,
      paint,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: w * 1.2),
      -0.8,
      0.8,
      false,
      paint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SpotifyCurvedLinesPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
