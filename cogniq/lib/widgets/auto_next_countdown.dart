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
    this.duration = const Duration(milliseconds: 2000),
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

    return InkWell(
      onTap: widget.onNext,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: widget.accentColor.withAlpha((255 * 0.08).round()),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.accentColor.withAlpha((255 * 0.3).round()),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.accentColor.withAlpha((255 * 0.1).round()),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    value: 1.0 - progress,
                    strokeWidth: 3.5,
                    backgroundColor: widget.accentColor.withAlpha((255 * 0.15).round()),
                    valueColor: AlwaysStoppedAnimation<Color>(widget.accentColor),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: widget.accentColor,
                  size: 18,
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Level Cleared!',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Next level in ${remainingSeconds}s... Tap to skip',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.2, end: 0, curve: Curves.easeOutBack);
  }
}
