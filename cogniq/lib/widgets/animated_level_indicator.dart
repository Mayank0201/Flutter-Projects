import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AnimatedLevelIndicator extends StatelessWidget {
  final int level;
  final Color accentColor;
  final String label;
  final double? fontSize;
  final FontWeight? fontWeight;

  const AnimatedLevelIndicator({
    super.key,
    required this.level,
    required this.accentColor,
    this.label = 'Level',
    this.fontSize,
    this.fontWeight,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (Widget child, Animation<double> animation) {
        // Slide down from top when entering, and slide down to bottom when exiting
        final inAnimation = Tween<Offset>(
          begin: const Offset(0.0, -0.6),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack));

        final outAnimation = Tween<Offset>(
          begin: const Offset(0.0, 0.6),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeIn));

        return SlideTransition(
          position: child.key == ValueKey(level) ? inAnimation : outAnimation,
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      child: Text(
        '$label $level',
        key: ValueKey<int>(level),
        style: AppTheme.numberStyle(
          color: accentColor,
          fontSize: fontSize ?? context.scale(13),
          fontWeight: fontWeight ?? FontWeight.bold,
        ),
      ),
    );
  }
}
