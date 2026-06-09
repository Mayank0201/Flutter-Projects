import 'package:flutter/material.dart';

class ZenSunsetWidget extends StatelessWidget {
  final double height;
  const ZenSunsetWidget({super.key, this.height = 180});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2B2926).withAlpha(16),
            blurRadius: 24,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: CustomPaint(
          painter: _ZenSunsetPainter(),
        ),
      ),
    );
  }
}

class _ZenSunsetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1. Sky Gradient (Dusty Purple to Soft Peach to Warm Sand)
    final skyGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF4C4673), // Deep Indigo/Mauve
        const Color(0xFF8B6E8C), // Dusty Mauve
        const Color(0xFFB57E6D), // Peach/Terracotta
        const Color(0xFFD4953A), // Sunset Gold
        const Color(0xFFEDE8E0), // Warm Linen
      ],
      stops: const [0.0, 0.35, 0.6, 0.85, 1.0],
    );

    final skyPaint = Paint()..shader = skyGradient.createShader(rect);
    canvas.drawRect(rect, skyPaint);

    // 2. Large Soft Sun in the center-bottom
    final sunCenter = Offset(size.width * 0.5, size.height * 0.72);
    final sunRadius = size.height * 0.42;
    final sunGradient = RadialGradient(
      colors: [
        const Color(0xFFFFF6DF), // Sun core
        const Color(0xFFFFDB9E).withAlpha(220),
        const Color(0xFFD4953A).withAlpha(80),
        Colors.transparent,
      ],
      stops: const [0.0, 0.4, 0.8, 1.0],
    );

    final sunPaint = Paint()
      ..shader = sunGradient.createShader(
        Rect.fromCircle(center: sunCenter, radius: sunRadius),
      );
    canvas.drawCircle(sunCenter, sunRadius, sunPaint);

    // 3. Layered mountains in the background (desaturated terracotta & purples)
    final pathFarMtn = Path();
    pathFarMtn.moveTo(0, size.height * 0.7);
    pathFarMtn.quadraticBezierTo(
      size.width * 0.2, size.height * 0.58,
      size.width * 0.45, size.height * 0.65,
    );
    pathFarMtn.quadraticBezierTo(
      size.width * 0.75, size.height * 0.52,
      size.width, size.height * 0.68,
    );
    pathFarMtn.lineTo(size.width, size.height);
    pathFarMtn.lineTo(0, size.height);
    pathFarMtn.close();

    final farMtnPaint = Paint()
      ..color = const Color(0xFF9E6B5A).withAlpha(120); // semi-transparent terracotta
    canvas.drawPath(pathFarMtn, farMtnPaint);

    final pathMidMtn = Path();
    pathMidMtn.moveTo(0, size.height * 0.78);
    pathMidMtn.quadraticBezierTo(
      size.width * 0.3, size.height * 0.68,
      size.width * 0.6, size.height * 0.74,
    );
    pathMidMtn.quadraticBezierTo(
      size.width * 0.8, size.height * 0.64,
      size.width, size.height * 0.76,
    );
    pathMidMtn.lineTo(size.width, size.height);
    pathMidMtn.lineTo(0, size.height);
    pathMidMtn.close();

    final midMtnPaint = Paint()
      ..color = const Color(0xFF705D6B).withAlpha(180); // midground mauve/purple
    canvas.drawPath(pathMidMtn, midMtnPaint);

    // 4. Floating birds in the sky
    final birdPaint = Paint()
      ..color = const Color(0xFF4C4673).withAlpha(90)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    _drawBird(canvas, Offset(size.width * 0.25, size.height * 0.32), 12, birdPaint);
    _drawBird(canvas, Offset(size.width * 0.33, size.height * 0.26), 9, birdPaint);
    _drawBird(canvas, Offset(size.width * 0.75, size.height * 0.22), 14, birdPaint);

    // 5. Ground platform (warm linen/sand color matching the bottom)
    final groundPath = Path();
    groundPath.moveTo(0, size.height * 0.85);
    groundPath.quadraticBezierTo(
      size.width * 0.5, size.height * 0.82,
      size.width, size.height * 0.86,
    );
    groundPath.lineTo(size.width, size.height);
    groundPath.lineTo(0, size.height);
    groundPath.close();

    final groundPaint = Paint()
      ..color = const Color(0xFFEDE8E0); // Warm sand/linen
    canvas.drawPath(groundPath, groundPaint);

    // 6. Silhouette of meditating person in lotus pose
    final pCenter = Offset(size.width * 0.5, size.height * 0.83);
    final scale = size.height * 0.0036; // scale factor based on heights
    
    final silhouettePaint = Paint()
      ..color = const Color(0xFF534C66) // calm dark purple silhouette
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Head
    canvas.drawCircle(Offset(pCenter.dx, pCenter.dy - 50 * scale), 9 * scale, silhouettePaint);

    // Hair / Ponytail / Bun detail
    final bunPath = Path();
    bunPath.addOval(Rect.fromCircle(center: Offset(pCenter.dx, pCenter.dy - 41 * scale), radius: 3.5 * scale));
    canvas.drawPath(bunPath, silhouettePaint);

    // Neck
    final neckPath = Path();
    neckPath.moveTo(pCenter.dx - 2.5 * scale, pCenter.dy - 42 * scale);
    neckPath.lineTo(pCenter.dx + 2.5 * scale, pCenter.dy - 42 * scale);
    neckPath.lineTo(pCenter.dx + 3 * scale, pCenter.dy - 35 * scale);
    neckPath.lineTo(pCenter.dx - 3 * scale, pCenter.dy - 35 * scale);
    neckPath.close();
    canvas.drawPath(neckPath, silhouettePaint);

    // Torso / Body
    final bodyPath = Path();
    bodyPath.moveTo(pCenter.dx - 12 * scale, pCenter.dy - 34 * scale); // left shoulder
    bodyPath.quadraticBezierTo(pCenter.dx, pCenter.dy - 36 * scale, pCenter.dx + 12 * scale, pCenter.dy - 34 * scale); // neck base
    bodyPath.lineTo(pCenter.dx + 9 * scale, pCenter.dy - 10 * scale); // right waist
    bodyPath.lineTo(pCenter.dx - 9 * scale, pCenter.dy - 10 * scale); // left waist
    bodyPath.close();
    canvas.drawPath(bodyPath, silhouettePaint);

    // Crossed Legs (Lotus Pose)
    final legsPath = Path();
    legsPath.moveTo(pCenter.dx - 9 * scale, pCenter.dy - 10 * scale);
    legsPath.quadraticBezierTo(pCenter.dx - 22 * scale, pCenter.dy - 12 * scale, pCenter.dx - 26 * scale, pCenter.dy + 4 * scale); // left knee outer
    legsPath.quadraticBezierTo(pCenter.dx - 18 * scale, pCenter.dy + 8 * scale, pCenter.dx, pCenter.dy + 6 * scale); // left leg bottom
    legsPath.quadraticBezierTo(pCenter.dx + 18 * scale, pCenter.dy + 8 * scale, pCenter.dx + 26 * scale, pCenter.dy + 4 * scale); // right knee outer
    legsPath.quadraticBezierTo(pCenter.dx + 22 * scale, pCenter.dy - 12 * scale, pCenter.dx + 9 * scale, pCenter.dy - 10 * scale); // right leg top
    legsPath.close();
    canvas.drawPath(legsPath, silhouettePaint);

    // Hands resting on knees in mudra pose
    // Left Arm
    final leftArm = Path();
    leftArm.moveTo(pCenter.dx - 12 * scale, pCenter.dy - 33 * scale); // shoulder
    leftArm.quadraticBezierTo(pCenter.dx - 20 * scale, pCenter.dy - 18 * scale, pCenter.dx - 22 * scale, pCenter.dy + 1 * scale); // elbow & arm resting
    leftArm.lineTo(pCenter.dx - 18 * scale, pCenter.dy + 2 * scale);
    leftArm.close();
    canvas.drawPath(leftArm, silhouettePaint);

    // Right Arm
    final rightArm = Path();
    rightArm.moveTo(pCenter.dx + 12 * scale, pCenter.dy - 33 * scale); // shoulder
    rightArm.quadraticBezierTo(pCenter.dx + 20 * scale, pCenter.dy - 18 * scale, pCenter.dx + 22 * scale, pCenter.dy + 1 * scale); // elbow & arm resting
    rightArm.lineTo(pCenter.dx + 18 * scale, pCenter.dy + 2 * scale);
    rightArm.close();
    canvas.drawPath(rightArm, silhouettePaint);
  }

  void _drawBird(Canvas canvas, Offset pos, double size, Paint paint) {
    final path = Path();
    path.moveTo(pos.dx - size * 0.5, pos.dy + size * 0.1);
    path.quadraticBezierTo(pos.dx - size * 0.25, pos.dy - size * 0.35, pos.dx, pos.dy);
    path.quadraticBezierTo(pos.dx + size * 0.25, pos.dy - size * 0.35, pos.dx + size * 0.5, pos.dy + size * 0.1);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
