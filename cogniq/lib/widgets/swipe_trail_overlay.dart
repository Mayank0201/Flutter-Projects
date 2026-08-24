import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/prefs_keys.dart';
import '../utils/trail_catalog.dart';
import '../utils/zen_mode.dart';

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

  /// How long a line point survives, in milliseconds.
  ///
  /// 300ms everywhere except the two trails whose whole idea is persistence:
  /// Starfall's after-image and Constellation's star map both need the tail to
  /// outlive the finger. A longer life means more points on screen every
  /// frame, so it is deliberately not raised for anything else.
  static int lineLifetimeMs(String style) {
    switch (style) {
      case 'starfall':
        return 700;
      case 'constellation':
        return 900;
      default:
        return 300;
    }
  }

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
    final style = prefs.getString(PrefsKeys.swipeTrailStyle) ?? 'none';
    final customColorHex = prefs.getString(PrefsKeys.swipeTrailCustomColor);

    final clears = prefs.getInt(PrefsKeys.globalLevelClearedCount) ?? 0;
    final claimed =
        prefs.getStringList(PrefsKeys.claimedTrailStyles) ?? const ['none'];
    // Must consider claimed/bought trails, not just the level count: a
    // points-only trail has no reachable clear requirement, so checking clears
    // alone silently stops rendering a trail the player paid for. Star trails
    // are the same trap in a new coat, so the star totals go through the same
    // shared catalog check rather than being re-derived here.
    final isUnlocked = TrailCatalog.isAvailable(
      styleId: style,
      clears: clears,
      claimed: claimed,
      zenClears: prefs.getInt(ZenMode.zenClearedCountKey) ?? 0,
      stars: StarCounts.fromPrefs(prefs),
    );

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
    final lifetime = SwipeTrailOverlay.lineLifetimeMs(_style);
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
          } else if (_style == 'petal_fall') {
            // Petals keep their sideways drift and sink slowly: the sideways
            // component barely decays while gravity builds, which is what
            // makes them leave the swipe instead of following it.
            pt.velocity = Offset(
              pt.velocity.dx * 0.995,
              pt.velocity.dy * 0.98 + 0.05,
            );
            pt.opacity -= 0.018;
          }
          if (pt.opacity <= 0) {
            _points.removeAt(i);
          }
        } else {
          // Regular swipe line trail
          if (now - pt.timestamp > lifetime) {
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
    } else if (_style == 'petal_fall') {
      // The soft line the petals detach from.
      _points.add(_TrailPoint(
        position: position,
        timestamp: now,
        isParticle: false,
      ));
      // One blossom, thrown sideways rather than along the swipe.
      final drift = (_random.nextBool() ? 1.0 : -1.0) *
          (_random.nextDouble() * 0.9 + 0.5);
      _points.add(_TrailPoint(
        position: position,
        timestamp: now,
        opacity: 1.0,
        size: _random.nextDouble() * 3.5 + 3.0,
        velocity: Offset(drift, -_random.nextDouble() * 0.4),
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
    } else if (_style == TrailCatalog.zenTrailId) {
      rippleColor = const Color(0xFF7FB77E);
    } else if (_style == 'morning_mist') {
      rippleColor = const Color(0xFFCFD8DC);
    } else if (_style == 'tide_line') {
      rippleColor = const Color(0xFF81D4FA);
    } else if (_style == 'aurora_veil') {
      rippleColor = const Color(0xFF00B0FF);
    } else if (_style == 'starfall') {
      rippleColor = const Color(0xFF80D8FF);
    } else if (_style == 'petal_fall') {
      rippleColor = const Color(0xFFF8BBD0);
    } else if (_style == 'constellation') {
      rippleColor = const Color(0xFFFFF9C4);
    } else if (_style == 'eclipse') {
      rippleColor = const Color(0xFFFFB300);
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
    } else if (style == 'constellation') {
      _paintConstellation(canvas, now);
    } else if (style == 'eclipse') {
      _paintEclipse(canvas);
    } else {
      _paintLineTrail(canvas);
      if (style == 'fire') {
        _paintEmberParticles(canvas);
      } else if (style == 'tide_line') {
        _paintFoamRim(canvas);
      } else if (style == 'aurora_veil') {
        _paintAuroraCurtains(canvas, now);
      } else if (style == 'starfall') {
        _paintCometHead(canvas);
      } else if (style == 'petal_fall') {
        _paintPetals(canvas);
      }
    }
  }

  /// The non-particle points, oldest first. Every star-trail painter walks the
  /// same list, so it is built once per painter rather than per pass.
  List<_TrailPoint> get _linePoints =>
      points.where((pt) => !pt.isParticle).toList();

  /// Tide Line's foam: a thin bright edge sitting just off the wave, brightest
  /// at the leading edge and dissolving toward the tail.
  ///
  /// One short line per segment (a few dozen at most) with the true segment
  /// normal, which is cheaper than offsetting a path and reads the same.
  void _paintFoamRim(Canvas canvas) {
    final pts = _linePoints;
    if (pts.length < 3) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.0
      ..isAntiAlias = true;

    final last = pts.length - 1;
    for (var i = 0; i < last; i++) {
      final a = pts[i].position;
      final b = pts[i + 1].position;
      final dx = b.dx - a.dx;
      final dy = b.dy - a.dy;
      final len = sqrt(dx * dx + dy * dy);
      if (len < 0.5) continue;
      final nx = -dy / len * 4.0;
      final ny = dx / len * 4.0;
      final t = i / last;
      paint.color =
          const Color(0xFFE1F5FE).withValues(alpha: 0.12 + 0.65 * t);
      canvas.drawLine(
        Offset(a.dx + nx, a.dy + ny),
        Offset(b.dx + nx, b.dy + ny),
        paint,
      );
    }
  }

  /// Aurora Veil's curtains: short strokes hanging perpendicular to the swipe,
  /// their length rippling with time so the veil moves even when the finger
  /// does not. Sampled every fourth point, so about eight strokes a frame.
  void _paintAuroraCurtains(Canvas canvas, int now) {
    final pts = _linePoints;
    if (pts.length < 4) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5
      ..isAntiAlias = true;

    final phase = now / 260.0;
    final last = pts.length - 1;
    for (var i = 1; i < last; i += 4) {
      final a = pts[i - 1].position;
      final b = pts[i + 1].position;
      final dx = b.dx - a.dx;
      final dy = b.dy - a.dy;
      final len = sqrt(dx * dx + dy * dy);
      if (len < 0.5) continue;
      final nx = -dy / len;
      final ny = dx / len;
      final t = i / last;
      final h = 11.0 + 7.0 * sin(phase + i * 0.7);
      final mid = pts[i].position;
      final colour = Color.lerp(
        const Color(0xFF00E5A0),
        const Color(0xFF7C4DFF),
        t,
      )!;
      paint.color = colour.withValues(alpha: 0.10 + 0.35 * t);
      canvas.drawLine(
        Offset(mid.dx - nx * h, mid.dy - ny * h),
        Offset(mid.dx + nx * h * 0.45, mid.dy + ny * h * 0.45),
        paint,
      );
    }
  }

  /// Starfall's head: two circles at the newest point. The long tail and the
  /// after-image come from the gradient and the extended point lifetime, not
  /// from extra draw passes.
  void _paintCometHead(Canvas canvas) {
    final pts = _linePoints;
    if (pts.isEmpty) return;
    final head = pts.last.position;

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..color = const Color(0xFF80D8FF).withValues(alpha: 0.28);
    canvas.drawCircle(head, 9.0, paint);
    paint.color = const Color(0xFFFFFFFF).withValues(alpha: 0.92);
    canvas.drawCircle(head, 3.2, paint);
  }

  /// Petal Fall's blossoms. Drawn as squashed ovals rather than rotated petal
  /// paths: a per-particle canvas transform would cost a save/restore for every
  /// petal on screen, and the sideways drift already reads as falling.
  void _paintPetals(Canvas canvas) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (final pt in points) {
      if (!pt.isParticle) continue;
      final a = pt.opacity.clamp(0.0, 1.0);
      paint.color = const Color(0xFFF48FB1).withValues(alpha: a * 0.85);
      canvas.drawOval(
        Rect.fromCenter(
          center: pt.position,
          width: pt.size * 1.6,
          height: pt.size,
        ),
        paint,
      );
      paint.color = const Color(0xFFFCE4EC).withValues(alpha: a * 0.7);
      canvas.drawOval(
        Rect.fromCenter(
          center: pt.position,
          width: pt.size * 0.7,
          height: pt.size * 0.45,
        ),
        paint,
      );
    }
  }

  /// Constellation: a light every few points, joined to its neighbour once the
  /// newer star has had a beat to appear, fading from the oldest star first.
  void _paintConstellation(Canvas canvas, int now) {
    final pts = _linePoints;
    if (pts.isEmpty) return;

    // Sample rather than draw every point: the effect is a star map, and this
    // keeps the work at roughly a dozen ops however long the swipe is.
    final nodes = <_TrailPoint>[];
    for (var i = 0; i < pts.length; i += 5) {
      nodes.add(pts[i]);
    }

    const life = 900.0;
    double alphaOf(_TrailPoint pt) =>
        (1.0 - (now - pt.timestamp) / life).clamp(0.0, 1.0);

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true;

    for (var i = 0; i < nodes.length - 1; i++) {
      // "A beat later": the join only appears once the newer star has settled.
      if (now - nodes[i + 1].timestamp < 120) continue;
      final a = alphaOf(nodes[i]);
      if (a <= 0) continue;
      linePaint.color = const Color(0xFF9FA8DA).withValues(alpha: a * 0.55);
      canvas.drawLine(nodes[i].position, nodes[i + 1].position, linePaint);
    }

    final dot = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    for (final node in nodes) {
      final a = alphaOf(node);
      if (a <= 0) continue;
      dot.color = const Color(0xFFFFF9C4).withValues(alpha: a * 0.35);
      canvas.drawCircle(node.position, 4.5, dot);
      dot.color = const Color(0xFFFFFFFF).withValues(alpha: a);
      canvas.drawCircle(node.position, 1.8, dot);
    }
  }

  /// Eclipse: a dark band with a thin amber corona.
  ///
  /// Deliberately **not** a subtractive blend. A [BlendMode.multiply] stroke
  /// would force the compositor to re-read the pixels underneath on every
  /// frame of every drag, in every game -- the exact cost `remember.md` warns
  /// about. A near-opaque black stroke reads as darkening for a fraction of
  /// the work, and the corona is what sells the effect anyway.
  void _paintEclipse(Canvas canvas) {
    final pts = _linePoints;
    if (pts.length < 2) return;
    final path = _buildTrailPath(pts);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    // Outer glow, then the corona ring, then the dark body over both.
    paint
      ..strokeWidth = 26.0
      ..color = const Color(0xFFFFB300).withValues(alpha: 0.08);
    canvas.drawPath(path, paint);

    paint
      ..strokeWidth = 19.0
      ..color = const Color(0xFFFFB300).withValues(alpha: 0.30);
    canvas.drawPath(path, paint);

    paint
      ..strokeWidth = 15.0
      ..color = const Color(0xFF000000).withValues(alpha: 0.80);
    canvas.drawPath(path, paint);
  }

  /// The smoothed path through a run of line points.
  Path _buildTrailPath(List<_TrailPoint> linePoints) {
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
    return path;
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
    final linePoints = _linePoints;
    if (linePoints.length < 2) return;

    final path = _buildTrailPath(linePoints);

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
    } else if (style == TrailCatalog.zenTrailId) {
      // Zen Ripple: soft jade, wide and quiet rather than bright.
      gradientColors = [
        const Color(0xFF7FB77E), // Jade
        const Color(0xFFB7D3B0), // Soft sage
        const Color(0xFFE3EFE0), // Pale mist
      ];
      innerWidth = 6.5;
      outerWidth = 15.0;
      outerOpacityMultiplier = 0.18;
    } else if (style == 'morning_mist') {
      // Vapour: the alpha ramp is what makes it "widen and thin as it fades",
      // rather than per-segment widths, which would cost a draw call each.
      gradientColors = [
        const Color(0x00CFD8DC),
        const Color(0x99ECEFF1),
        const Color(0xCCB0BEC5),
      ];
      innerWidth = 9.0;
      outerWidth = 22.0;
      outerOpacityMultiplier = 0.14;
    } else if (style == 'tide_line') {
      gradientColors = [
        const Color(0x004FC3F7),
        const Color(0xCC4FC3F7),
        const Color(0xFF81D4FA),
      ];
      innerWidth = 8.0;
      outerWidth = 18.0;
      outerOpacityMultiplier = 0.22;
    } else if (style == 'aurora_veil') {
      gradientColors = [
        const Color(0x8000E5A0),
        const Color(0xCC00B0FF),
        const Color(0xF27C4DFF),
      ];
      innerWidth = 7.0;
      outerWidth = 20.0;
      outerOpacityMultiplier = 0.28;
    } else if (style == 'starfall') {
      // Thin and long: the tail fades through the gradient's own alpha, and
      // the extended point lifetime is what makes it linger.
      gradientColors = [
        const Color(0x001A237E),
        const Color(0x6680D8FF),
        const Color(0xFFFFFFFF),
      ];
      innerWidth = 3.0;
      outerWidth = 10.0;
      outerOpacityMultiplier = 0.18;
    } else if (style == 'petal_fall') {
      gradientColors = [
        const Color(0x00FCE4EC),
        const Color(0x99F8BBD0),
        const Color(0xE6F48FB1),
      ];
      innerWidth = 4.0;
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
