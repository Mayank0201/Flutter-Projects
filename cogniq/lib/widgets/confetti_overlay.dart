import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../theme/app_theme.dart';

class ConfettiOverlayWidget extends StatefulWidget {
  final Color accentColor;
  const ConfettiOverlayWidget({super.key, required this.accentColor});

  @override
  State<ConfettiOverlayWidget> createState() => _ConfettiOverlayWidgetState();
}

class _ConfettiOverlayWidgetState extends State<ConfettiOverlayWidget>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  final List<_Particle> _particles = [];
  final Random _random = Random();
  late Size _screenSize;
  bool _initialized = false;

  // Physics constants
  static const double gravity = 450.0; // pixels / s^2
  static const double drag = 0.985;    // air resistance factor
  static const double fadeDelay = 1.2;  // seconds before fading starts
  static const double fadeDuration = 0.8; // seconds to fade completely

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _screenSize = MediaQuery.of(context).size;
      _generateParticles();
      _ticker.start();
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _generateParticles() {
    final colors = [
      widget.accentColor,
      AppTheme.dustyMauve,
      AppTheme.warmAmber,
      AppTheme.slateBlue,
      AppTheme.softSage,
      AppTheme.terracotta,
      AppTheme.roseGold,
      AppTheme.deepLavender,
      Colors.white,
    ];

    // Left corner fountain
    for (int i = 0; i < 40; i++) {
      _particles.add(_createFountainParticle(
        startX: 0.0,
        startY: _screenSize.height,
        angleRangeMin: -75 * pi / 180,
        angleRangeMax: -25 * pi / 180,
        colors: colors,
      ));
    }

    // Right corner fountain
    for (int i = 0; i < 40; i++) {
      _particles.add(_createFountainParticle(
        startX: _screenSize.width,
        startY: _screenSize.height,
        angleRangeMin: -155 * pi / 180,
        angleRangeMax: -105 * pi / 180,
        colors: colors,
      ));
    }
  }

  _Particle _createFountainParticle({
    required double startX,
    required double startY,
    required double angleRangeMin,
    required double angleRangeMax,
    required List<Color> colors,
  }) {
    final angle = angleRangeMin + _random.nextDouble() * (angleRangeMax - angleRangeMin);
    final speed = 550.0 + _random.nextDouble() * 450.0;
    
    return _Particle(
      x: startX,
      y: startY,
      vx: cos(angle) * speed,
      vy: sin(angle) * speed,
      color: colors[_random.nextInt(colors.length)],
      size: 6.0 + _random.nextDouble() * 8.0,
      rotation: _random.nextDouble() * 2 * pi,
      rotationSpeed: (-4.0 + _random.nextDouble() * 8.0) * pi,
      shape: _random.nextBool() ? _ParticleShape.rect : _ParticleShape.circle,
      aspectRatio: 0.5 + _random.nextDouble() * 1.0,
    );
  }

  double _lastTime = 0.0;

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    final currentTime = elapsed.inMilliseconds / 1000.0;
    if (_lastTime == 0.0) {
      _lastTime = currentTime;
      return;
    }
    final dt = currentTime - _lastTime;
    _lastTime = currentTime;

    setState(() {
      for (final p in _particles) {
        p.x += p.vx * dt;
        p.y += p.vy * dt;
        p.vy += gravity * dt;
        p.vx *= drag;
        p.vy *= drag;
        p.rotation += p.rotationSpeed * dt;
        p.age += dt;

        if (p.age > fadeDelay) {
          p.opacity = (1.0 - (p.age - fadeDelay) / fadeDuration).clamp(0.0, 1.0);
        }
      }
      _particles.removeWhere((p) => p.opacity <= 0.0 || p.y > _screenSize.height + 20);
    });
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ConfettiPainter(particles: _particles),
      ),
    );
  }
}

enum _ParticleShape { rect, circle }

class _Particle {
  double x;
  double y;
  double vx;
  double vy;
  final Color color;
  final double size;
  double rotation;
  final double rotationSpeed;
  final _ParticleShape shape;
  final double aspectRatio;
  double age = 0.0;
  double opacity = 1.0;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
    required this.shape,
    required this.aspectRatio,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  _ConfettiPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paintObj = Paint();

    for (final p in particles) {
      paintObj.color = p.color.withOpacity(p.opacity);
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);

      if (p.shape == _ParticleShape.rect) {
        final w = p.size;
        final h = p.size * p.aspectRatio;
        canvas.drawRect(
          Rect.fromLTWH(-w / 2, -h / 2, w, h),
          paintObj,
        );
      } else {
        canvas.drawOval(
          Rect.fromLTWH(-p.size / 2, -p.size / 2, p.size, p.size * p.aspectRatio),
          paintObj,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
