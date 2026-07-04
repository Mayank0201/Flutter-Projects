import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'confetti_overlay.dart';
import '../theme/app_theme.dart';

class ChallengeClearedOverlay extends StatefulWidget {
  final VoidCallback onComplete;
  final Color accentColor;

  const ChallengeClearedOverlay({
    super.key,
    required this.onComplete,
    required this.accentColor,
  });

  @override
  State<ChallengeClearedOverlay> createState() => _ChallengeClearedOverlayState();
}

class _ChallengeClearedOverlayState extends State<ChallengeClearedOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  OverlayEntry? _confettiEntry;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _controller.addListener(() {
      setState(() {});
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
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
    final remainingSeconds = (5.0 * (1.0 - progress)).ceil();

    return Material(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: context.bgCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: widget.accentColor.withOpacity(0.3), width: 2),
            boxShadow: [
              BoxShadow(
                color: widget.accentColor.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: widget.accentColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: CircularProgressIndicator(
                          value: 1.0 - progress,
                          strokeWidth: 4,
                          valueColor: AlwaysStoppedAnimation<Color>(widget.accentColor),
                          backgroundColor: widget.accentColor.withOpacity(0.1),
                        ),
                      ),
                      Text(
                        '$remainingSeconds',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Challenge Cleared!',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Returning to challenge screen...',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: widget.onComplete,
                child: Text(
                  'Return Now',
                  style: GoogleFonts.outfit(
                    color: widget.accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
