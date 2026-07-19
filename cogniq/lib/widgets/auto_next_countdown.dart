import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'confetti_overlay.dart';

class AutoNextCountdown extends StatefulWidget {
  final VoidCallback onNext;
  final Duration duration;
  final Color accentColor;

  const AutoNextCountdown({
    super.key,
    required this.onNext,
    this.duration = const Duration(milliseconds: 1000),
    required this.accentColor,
  });

  @override
  State<AutoNextCountdown> createState() => _AutoNextCountdownState();
}

class _AutoNextCountdownState extends State<AutoNextCountdown>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  OverlayEntry? _confettiEntry;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _controller.addListener(() {
      setState(() {});
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onNext();
      }
    });

    _controller.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showConfetti();
      }
    });
  }

  void _showConfetti() {
    _confettiEntry = OverlayEntry(
      builder: (context) => ConfettiOverlayWidget(
        accentColor: widget.accentColor,
      ),
    );
    Overlay.of(context).insert(_confettiEntry!);
  }

  @override
  void dispose() {
    _controller.dispose();
    _confettiEntry?.remove();
    _confettiEntry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _controller.value;
    final remainingSeconds =
        ((1.0 - progress) * widget.duration.inMilliseconds / 1000)
            .toStringAsFixed(1);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isSmall = MediaQuery.of(context).size.width < 360;

    return InkWell(
      onTap: widget.onNext,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isSmall ? 16 : 24, vertical: 16),
        decoration: BoxDecoration(
          color: widget.accentColor.withAlpha((255 * 0.05).round()),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.accentColor.withAlpha((255 * 0.15).round()),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    value: 1.0 - progress,
                    strokeWidth: 2.0,
                    backgroundColor: widget.accentColor.withAlpha((255 * 0.1).round()),
                    valueColor: AlwaysStoppedAnimation<Color>(widget.accentColor),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: widget.accentColor,
                  size: 16,
                ).animate(
                  onPlay: (controller) => controller.repeat(reverse: true),
                ).move(
                  begin: const Offset(-2, 0),
                  end: const Offset(2, 0),
                  duration: 600.ms,
                  curve: Curves.easeInOut,
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Level Cleared!',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Next level in ${remainingSeconds}s... Tap to skip',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.0, 1.0), curve: Curves.easeOutCubic)
        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
  }
}
