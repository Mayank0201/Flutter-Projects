import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../utils/achievement_manager.dart';

class LossOverlay extends StatefulWidget {
  final VoidCallback onTryAgain;
  final String title;
  final String subtitle;
  final Color accentColor;
  final List<Widget>? extraContent;

  const LossOverlay({
    super.key,
    required this.onTryAgain,
    this.title = 'Game Over',
    required this.subtitle,
    required this.accentColor,
    this.extraContent,
  });

  @override
  State<LossOverlay> createState() => _LossOverlayState();
}

class _LossOverlayState extends State<LossOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _flashController;
  late Animation<double> _flashAnimation;

  @override
  void initState() {
    super.initState();
    AchievementManager.resetClearStreak();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _flashAnimation = Tween<double>(begin: 0.45, end: 0.0).animate(
      CurvedAnimation(parent: _flashController, curve: Curves.easeOut),
    );
    _flashController.forward();
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // 1. Black backing overlay
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.72),
          ),
        ),

        // 2. Center card containing stats & try again details
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2926) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Game Over Icon in red/accent
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.redAccent,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.title,
                    style: GoogleFonts.outfit(
                      fontSize: context.scale(28),
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.subtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: context.scale(14),
                      color: isDark ? Colors.white70 : Colors.black54,
                      height: 1.4,
                    ),
                  ),
                  
                  if (widget.extraContent != null && widget.extraContent!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    ...widget.extraContent!,
                  ],
                  
                  const SizedBox(height: 24),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: widget.onTryAgain,
                      icon: const Icon(Icons.replay_rounded, size: 20),
                      label: Text(
                        'Try Again',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: context.scale(15),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.accentColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 250.ms)
                .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.0, 1.0), duration: 250.ms, curve: Curves.easeOutBack)
                .shake(hz: 8, duration: 400.ms, curve: Curves.easeInOut),
          ),
        ),

        // 3. Quick Red Flash Overlay on top
        AnimatedBuilder(
          animation: _flashAnimation,
          builder: (context, child) {
            if (_flashAnimation.value == 0.0) return const SizedBox.shrink();
            return Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.redAccent.withOpacity(_flashAnimation.value),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
