import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class InteractiveTutorialOverlay extends StatelessWidget {
  final String instruction;
  final bool isCompleted;
  final VoidCallback onStartGame;
  final VoidCallback onSkip;

  const InteractiveTutorialOverlay({
    super.key,
    required this.instruction,
    required this.isCompleted,
    required this.onStartGame,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Positioned(
      top: 12,
      left: 16,
      right: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: (isDark ? const Color(0xFF1E1E2C) : Colors.white).withOpacity(0.75),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (isDark ? Colors.white10 : Colors.black12),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.dustyMauve.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'TUTORIAL',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.dustyMauve,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      if (!isCompleted)
                        GestureDetector(
                          onTap: onSkip,
                          child: Text(
                            'Skip',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    instruction,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                      color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (isCompleted) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.dustyMauve,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        onPressed: onStartGame,
                        child: Text(
                          'Start Game',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
