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
  late final ValueNotifier<Offset?> _pointerPosNotifier;
  late final ValueNotifier<bool> _isPointerDownNotifier;

  @override
  void initState() {
    super.initState();
    _pointerPosNotifier = ValueNotifier<Offset?>(widget.focalPoint);
    _isPointerDownNotifier = ValueNotifier<bool>(false);
  }

  @override
  void dispose() {
    _pointerPosNotifier.dispose();
    _isPointerDownNotifier.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FogOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focalPoint != oldWidget.focalPoint) {
      if (widget.focalPoint != null) {
        _pointerPosNotifier.value = widget.focalPoint;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return Listener(
      onPointerDown: (event) {
        _isPointerDownNotifier.value = true;
        _pointerPosNotifier.value = event.localPosition;
      },
      onPointerMove: (event) {
        _pointerPosNotifier.value = event.localPosition;
      },
      onPointerUp: (event) {
        _isPointerDownNotifier.value = false;
      },
      onPointerCancel: (event) {
        _isPointerDownNotifier.value = false;
      },
      child: MouseRegion(
        onHover: (event) {
          if (!_isPointerDownNotifier.value && widget.focalPoint == null) {
            _pointerPosNotifier.value = event.localPosition;
          }
        },
        child: Stack(
          children: [
            widget.child,
            Positioned.fill(
              child: IgnorePointer(
                child: ValueListenableBuilder<Offset?>(
                  valueListenable: _pointerPosNotifier,
                  builder: (context, pointerPos, _) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: _isPointerDownNotifier,
                      builder: (context, isPointerDown, _) {
                        final Offset? activeCenter = (isPointerDown && pointerPos != null)
                            ? pointerPos
                            : (widget.focalPoint ?? pointerPos);
                        final double activeRadius = isPointerDown ? (widget.radius * 1.25) : widget.radius;

                        return CustomPaint(
                          painter: FogPainter(
                            pointerPos: activeCenter,
                            radius: activeRadius,
                          ),
                        );
                      },
                    );
                  },
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
