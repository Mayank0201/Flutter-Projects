import 'package:flutter/material.dart';

// one poster widget for the whole app. every list drew its own fallback box
// before, so radius and placeholder drifted apart between screens.
class PosterImage extends StatelessWidget {
  final String? url;
  final double width;
  final double height;
  final double radius;

  const PosterImage({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    this.radius = 10,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: url == null
            ? _placeholder(context)
            : Image.network(
                url!,
                width: width,
                height: height,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder(context),
                // fade in rather than popping, otherwise a grid flickers as it fills
                frameBuilder: (_, child, frame, wasSync) {
                  if (wasSync || frame != null) {
                    return AnimatedOpacity(
                      opacity: 1,
                      duration: const Duration(milliseconds: 180),
                      child: child,
                    );
                  }
                  return _placeholder(context);
                },
              ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      color: cs.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.tv_rounded,
        size: width * 0.3,
        color: cs.onSurfaceVariant.withValues(alpha: 0.35),
      ),
    );
  }
}

// grey block used while a list is still loading. beats a spinner in the middle
// of an empty screen because the page keeps its shape.
class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 10,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest
              .withValues(alpha: 0.35 + (_controller.value * 0.25)),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}
