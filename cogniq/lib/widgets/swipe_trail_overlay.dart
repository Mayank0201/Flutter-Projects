import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TrailPoint {
  Offset position;
  final int timestamp;
  double opacity;
  Offset velocity;
  double size;
  final bool isParticle;

  _TrailPoint({
    required this.position,
    required this.timestamp,
    this.opacity = 1.0,
    this.velocity = Offset.zero,
    this.size = 8.0,
    this.isParticle = false,
  });
}

class _TapRipple {
  final Offset position;
  final int startTime;
  final Color color;

  _TapRipple({
    required this.position,
    required this.startTime,
    required this.color,
  });
}

class SwipeTrailOverlay extends StatefulWidget {
  final Widget child;
  final Color accentColor;

  static final ValueNotifier<String> styleNotifier = ValueNotifier<String>('none');
  static final ValueNotifier<bool> unlockedNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<String?> customColorNotifier = ValueNotifier<String?>(null);

  const SwipeTrailOverlay({
    super.key,
    required this.child,
    required this.accentColor,
  });

  @override
  State<SwipeTrailOverlay> createState() => _SwipeTrailOverlayState();
}

class _SwipeTrailOverlayState extends State<SwipeTrailOverlay>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  final List<_TrailPoint> _points = [];
  final List<_TapRipple> _ripples = [];
  bool _unlocked = false;
  String _style = 'none'; // 'none', 'accent', 'pastel', etc.
  Color? _customColor;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _ticker = createTicker((_) {
      _updateTrail();
    });
    _ticker.start();

    SwipeTrailOverlay.styleNotifier.addListener(_onStyleChanged);
    SwipeTrailOverlay.unlockedNotifier.addListener(_onUnlockedChanged);
    SwipeTrailOverlay.customColorNotifier.addListener(_onCustomColorChanged);
  }

  void _onStyleChanged() {
    if (mounted) {
      setState(() {
        _style = SwipeTrailOverlay.styleNotifier.value;
      });
    }
  }

  void _onUnlockedChanged() {
    if (mounted) {
      setState(() {
        _unlocked = SwipeTrailOverlay.unlockedNotifier.value;
      });
    }
  }

  void _onCustomColorChanged() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final style = prefs.getString('swipe_trail_style') ?? 'none';
    final customColorHex = prefs.getString('swipe_trail_custom_color');

    int requiredClears = 0;
    switch (style) {
      case 'none':
        requiredClears = 0;
        break;
      case 'accent':
        requiredClears = 30;
        break;
      case 'pastel':
        requiredClears = 60;
        break;
      case 'sparkle':
        requiredClears = 120;
        break;
      case 'neon_glow':
        requiredClears = 200;
        break;
      case 'rainbow':
        requiredClears = 250;
        break;
      case 'fire':
        requiredClears = 300;
        break;
    }
    final clears = prefs.getInt('global_level_cleared_count') ?? 0;
    final isUnlocked = clears >= requiredClears;

    SwipeTrailOverlay.styleNotifier.value = style;
    SwipeTrailOverlay.unlockedNotifier.value = isUnlocked;
    SwipeTrailOverlay.customColorNotifier.value = customColorHex;

    Color? parsedColor;
    if (customColorHex != null && customColorHex.isNotEmpty) {
      try {
        parsedColor = Color(int.parse(customColorHex));
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _unlocked = isUnlocked;
        _style = style;
        _customColor = parsedColor;
      });
    }
  }

  @override
  void dispose() {
    SwipeTrailOverlay.styleNotifier.removeListener(_onStyleChanged);
    SwipeTrailOverlay.unlockedNotifier.removeListener(_onUnlockedChanged);
    SwipeTrailOverlay.customColorNotifier.removeListener(_onCustomColorChanged);
    _ticker.dispose();
    super.dispose();
  }

  void _updateTrail() {
    final now = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      // Decay ripples older than 400ms
      _ripples.removeWhere((r) => now - r.startTime > 400);

      for (var i = _points.length - 1; i >= 0; i--) {
        final pt = _points[i];
        if (pt.isParticle) {
          // Particle physics update
          pt.position += pt.velocity;
          if (_style == 'sparkle') {
            pt.velocity = Offset(pt.velocity.dx * 0.94, pt.velocity.dy * 0.94 + 0.12);
            pt.opacity -= 0.035;
          } else if (_style == 'fire') {
            pt.velocity = Offset(
              pt.velocity.dx * 0.9 + (_random.nextDouble() - 0.5) * 0.25,
              pt.velocity.dy * 0.95,
            );
            pt.opacity -= 0.05;
          }
          if (pt.opacity <= 0) {
            _points.removeAt(i);
          }
        } else {
          // Regular swipe line trail
          if (now - pt.timestamp > 300) {
            _points.removeAt(i);
          }
        }
      }
    });
  }

  void _addPoint(Offset position) {
    if (!_unlocked || _style == 'none') return;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (_style == 'sparkle') {
      // Reduced stars density: Spawns 1 particle per touch point for elegance
      final angle = _random.nextDouble() * 2 * pi;
      final speed = _random.nextDouble() * 2.5 + 1.0;
      _points.add(_TrailPoint(
        position: position,
        timestamp: now,
        opacity: 1.0,
        size: _random.nextDouble() * 7 + 4,
        velocity: Offset(cos(angle) * speed, sin(angle) * speed),
        isParticle: true,
      ));
    } else if (_style == 'fire') {
      // Add the main path line point
      _points.add(_TrailPoint(
        position: position,
        timestamp: now,
        isParticle: false,
      ));
      // Spawn 1 rising ember particle
      final angle = _random.nextDouble() * pi - pi;
      final speed = _random.nextDouble() * 1.5 + 0.5;
      _points.add(_TrailPoint(
        position: position,
        timestamp: now,
        opacity: 1.0,
        size: _random.nextDouble() * 4 + 2,
        velocity: Offset(cos(angle) * speed, -speed - 1.0),
        isParticle: true,
      ));
    } else {
      // Regular line trail
      _points.add(_TrailPoint(
        position: position,
        timestamp: now,
        isParticle: false,
      ));
    }
  }

  void _addRipple(Offset position) {
    if (!_unlocked || _style == 'none') return;
    final now = DateTime.now().millisecondsSinceEpoch;

    Color rippleColor;
    if (_style == 'pastel') {
      rippleColor = const Color(0xFFC6DEF1);
    } else if (_style == 'rainbow') {
      rippleColor = const Color(0xFFB5EAD7);
    } else {
      rippleColor = widget.accentColor;
    }

    setState(() {
      _ripples.add(_TapRipple(
        position: position,
        startTime: now,
        color: rippleColor,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_unlocked || _style == 'none') {
      return widget.child;
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _addPoint(event.localPosition);
        _addRipple(event.localPosition);
      },
      onPointerMove: (event) {
        _addPoint(event.localPosition);
      },
      child: Stack(
        children: [
          widget.child,
          IgnorePointer(
            child: CustomPaint(
              size: Size.infinite,
              painter: _TrailPainter(
                points: _points,
                ripples: _ripples,
                style: _style,
                accentColor: _style == 'accent' && _customColor != null
                    ? _customColor!
                    : widget.accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrailPainter extends CustomPainter {
  final List<_TrailPoint> points;
  final List<_TapRipple> ripples;
  final String style;
  final Color accentColor;

  _TrailPainter({
    required this.points,
    required this.ripples,
    required this.style,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (style == 'none') return;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Paint ripples first (under the trail)
    _paintRipples(canvas, now);

    if (points.isEmpty) return;

    if (style == 'sparkle') {
      _paintSparkles(canvas);
    } else {
      _paintLineTrail(canvas);
      if (style == 'fire') {
        _paintEmberParticles(canvas);
      }
    }
  }

  void _paintRipples(Canvas canvas, int now) {
    for (final ripple in ripples) {
      final elapsed = now - ripple.startTime;
      final progress = (elapsed / 400.0).clamp(0.0, 1.0);

      final double radius = 35.0 * progress;
      final double opacity = 1.0 - progress;

      Color finalRippleColor = ripple.color;
      if (style == 'neon_glow') {
        finalRippleColor = const Color(0xFF00FFFF);
      } else if (style == 'fire') {
        finalRippleColor = const Color(0xFFFF5F00);
      }

      // Outer ring
      final ringPaint = Paint()
        ..color = finalRippleColor.withOpacity(opacity * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0 * (1.0 - progress)
        ..isAntiAlias = true;
      canvas.drawCircle(ripple.position, radius, ringPaint);

      // Inner soft fill
      final fillPaint = Paint()
        ..color = finalRippleColor.withOpacity(opacity * 0.15)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      canvas.drawCircle(ripple.position, radius * 0.6, fillPaint);
    }
  }

  void _paintSparkles(Canvas canvas) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (final pt in points) {
      if (pt.isParticle) {
        paint.color = Colors.amber.withOpacity(pt.opacity.clamp(0.0, 1.0));
        _drawStar(canvas, pt.position, pt.size, paint);
      }
    }
  }

  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    final double innerRadius = size / 2.5;
    final double outerRadius = size;
    const int pointsCount = 4;

    for (int i = 0; i < pointsCount * 2; i++) {
      final double r = i % 2 == 0 ? outerRadius : innerRadius;
      final double angle = i * pi / pointsCount;
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _paintEmberParticles(Canvas canvas) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (final pt in points) {
      if (pt.isParticle) {
        // Drifting warm embers
        paint.color = const Color(0xFFFF5F00).withOpacity(pt.opacity.clamp(0.0, 1.0));
        canvas.drawCircle(pt.position, pt.size, paint);
        // Yellow core
        paint.color = const Color(0xFFFFD000).withOpacity((pt.opacity * 0.8).clamp(0.0, 1.0));
        canvas.drawCircle(pt.position, pt.size * 0.5, paint);
      }
    }
  }

  void _paintLineTrail(Canvas canvas) {
    final linePoints = points.where((pt) => !pt.isParticle).toList();
    if (linePoints.length < 2) return;

    final path = Path();
    path.moveTo(linePoints.first.position.dx, linePoints.first.position.dy);

    for (int i = 1; i < linePoints.length - 1; i++) {
      final p1 = linePoints[i].position;
      final p2 = linePoints[i + 1].position;
      final xc = (p1.dx + p2.dx) / 2.0;
      final yc = (p1.dy + p2.dy) / 2.0;
      path.quadraticBezierTo(p1.dx, p1.dy, xc, yc);
    }
    path.lineTo(linePoints.last.position.dx, linePoints.last.position.dy);

    List<Color> gradientColors;
    double innerWidth = 7.0;
    double outerWidth = 0.0;
    double outerOpacityMultiplier = 0.25;

    if (style == 'pastel') {
      gradientColors = [
        const Color(0xFFF3C6D3), // Pastel pink
        const Color(0xFFC6DEF1), // Pastel blue
        const Color(0xFFD6E2E9), // Light sky
      ];
    } else if (style == 'rainbow') {
      // Vivid Neon Rainbow
      gradientColors = [
        const Color(0xFFFF003C), // Hot Red
        const Color(0xFFFF8A00), // Bright Orange
        const Color(0xFFFABE00), // Gold Yellow
        const Color(0xFF05FF00), // Electric Green
        const Color(0xFF00FFFF), // Electric Cyan
        const Color(0xFF0066FF), // Neon Blue
        const Color(0xFFBD00FF), // Neon Violet
      ];
      innerWidth = 6.0;
      outerWidth = 14.0;
      outerOpacityMultiplier = 0.3;
    } else if (style == 'neon_glow') {
      // Neon Glow (Electric Cyan to Neon Magenta)
      gradientColors = [
        const Color(0xFF00FFFF), // Electric Cyan
        const Color(0xFFFF00FF), // Neon Magenta
      ];
      innerWidth = 4.5;
      outerWidth = 16.0;
      outerOpacityMultiplier = 0.25;
    } else if (style == 'fire') {
      // Fire Trail (Red to Orange to Yellow)
      gradientColors = [
        const Color(0xFFFF0000), // Fire Red
        const Color(0xFFFF6600), // Flame Orange
        const Color(0xFFFFCC00), // Ember Yellow
      ];
      innerWidth = 6.0;
      outerWidth = 14.0;
      outerOpacityMultiplier = 0.25;
    } else {
      gradientColors = [
        accentColor.withOpacity(0.05),
        accentColor.withOpacity(0.4),
        accentColor,
      ];
    }

    final bounds = path.getBounds();
    final startPt = linePoints.first.position;
    final endPt = linePoints.last.position;

    final w = bounds.width > 0 ? bounds.width : 1.0;
    final h = bounds.height > 0 ? bounds.height : 1.0;

    final shader = LinearGradient(
      colors: gradientColors,
      begin: Alignment(
        ((startPt.dx - bounds.left) / w * 2 - 1).clamp(-1.0, 1.0),
        ((startPt.dy - bounds.top) / h * 2 - 1).clamp(-1.0, 1.0),
      ),
      end: Alignment(
        ((endPt.dx - bounds.left) / w * 2 - 1).clamp(-1.0, 1.0),
        ((endPt.dy - bounds.top) / h * 2 - 1).clamp(-1.0, 1.0),
      ),
    ).createShader(bounds);

    // Draw outer glow pass if specified
    if (outerWidth > 0) {
      final outerShader = LinearGradient(
        colors: gradientColors.map((c) => c.withOpacity(c.opacity * outerOpacityMultiplier)).toList(),
        begin: Alignment(
          ((startPt.dx - bounds.left) / w * 2 - 1).clamp(-1.0, 1.0),
          ((startPt.dy - bounds.top) / h * 2 - 1).clamp(-1.0, 1.0),
        ),
        end: Alignment(
          ((endPt.dx - bounds.left) / w * 2 - 1).clamp(-1.0, 1.0),
          ((endPt.dy - bounds.top) / h * 2 - 1).clamp(-1.0, 1.0),
        ),
      ).createShader(bounds);

      final outerPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = outerWidth
        ..shader = outerShader
        ..isAntiAlias = true;

      canvas.drawPath(path, outerPaint);
    }

    // Draw inner sharp pass
    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = innerWidth
      ..shader = shader
      ..isAntiAlias = true;

    canvas.drawPath(path, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _TrailPainter oldDelegate) {
    return true;
  }
}
