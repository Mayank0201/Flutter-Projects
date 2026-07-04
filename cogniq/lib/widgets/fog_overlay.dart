import 'package:flutter/material.dart';

class FogOverlay extends StatefulWidget {
  final Widget child;
  final double radius;
  final bool enabled;
  final Offset? focalPoint; // Optional focal point (e.g. selected cell center)

  const FogOverlay({
    super.key,
    required this.child,
    required this.radius,
    required this.enabled,
    this.focalPoint,
  });

  @override
  State<FogOverlay> createState() => _FogOverlayState();
}

class _FogOverlayState extends State<FogOverlay> {
  Offset? _pointerPos;
  bool _isPointerDown = false;

  @override
  void didUpdateWidget(covariant FogOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focalPoint != oldWidget.focalPoint) {
      if (widget.focalPoint != null) {
        _pointerPos = widget.focalPoint;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    // Use dragging pointer position when pointer is active to allow viewing board during drag
    final Offset? activeCenter = (_isPointerDown && _pointerPos != null)
        ? _pointerPos
        : (widget.focalPoint ?? _pointerPos);

    // Make the spotlight 25% larger during active press/drag
    final double activeRadius = _isPointerDown ? (widget.radius * 1.25) : widget.radius;

    return Listener(
      onPointerDown: (event) {
        setState(() {
          _isPointerDown = true;
          _pointerPos = event.localPosition;
        });
      },
      onPointerMove: (event) {
        setState(() {
          _pointerPos = event.localPosition;
        });
      },
      onPointerUp: (event) {
        setState(() {
          _isPointerDown = false;
        });
      },
      onPointerCancel: (event) {
        setState(() {
          _isPointerDown = false;
        });
      },
      child: MouseRegion(
        onHover: (event) {
          if (!_isPointerDown && widget.focalPoint == null) {
            setState(() {
              _pointerPos = event.localPosition;
            });
          }
        },
        child: Stack(
          children: [
            widget.child,
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: FogPainter(
                    pointerPos: activeCenter,
                    radius: activeRadius,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FogPainter extends CustomPainter {
  final Offset? pointerPos;
  final double radius;

  FogPainter({required this.pointerPos, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.saveLayer(rect, Paint());

    // Dark foggy background
    canvas.drawRect(
      rect,
      Paint()..color = const Color(0xFF0D0D14), // Opaque dark fog
    );

    if (pointerPos != null) {
      // Clear a soft circular spotlight at the pointer position
      final Paint clearPaint = Paint()
        ..blendMode = BlendMode.dstOut
        ..shader = RadialGradient(
          colors: [
            Colors.black,
            Colors.black.withOpacity(0.7),
            Colors.black.withOpacity(0.0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: pointerPos!, radius: radius));

      canvas.drawCircle(pointerPos!, radius, clearPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FogPainter oldDelegate) {
    return oldDelegate.pointerPos != pointerPos || oldDelegate.radius != radius;
  }
}
