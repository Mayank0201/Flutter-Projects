import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final logoColor = AppTheme.dustyMauve;
    
    return Scaffold(
      backgroundColor: context.bgDark,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            
            // Staggered letters for the title 'CogniQ'
            Row(
              mainAxisSize: MainAxisSize.min,
              children: 'CogniQ'.split('').asMap().entries.map((entry) {
                final idx = entry.key;
                final char = entry.value;
                return Text(
                  char,
                  style: GoogleFonts.outfit(
                    fontSize: context.scale(42),
                    fontWeight: FontWeight.w800,
                    color: char == 'Q' ? logoColor : context.textPrimary,
                    letterSpacing: -1,
                  ),
                )
                    .animate()
                    .fadeIn(
                      delay: (300 + idx * 80).ms,
                      duration: 400.ms,
                    )
                    .slideY(
                      begin: 0.4,
                      end: 0,
                      duration: 400.ms,
                      curve: Curves.easeOutBack,
                    );
              }).toList(),
            ),
            const SizedBox(height: 12),
            
            // Subtitle with a soft slide-up and fade-in
            Text(
              'Play. Think. Win.',
              style: GoogleFonts.outfit(
                fontSize: context.scale(15),
                fontWeight: FontWeight.w500,
                color: context.textMuted,
                letterSpacing: 2.0,
              ),
            )
                .animate()
                .fadeIn(delay: 900.ms, duration: 600.ms)
                .slideY(begin: 0.3, end: 0, duration: 600.ms, curve: Curves.easeOut),
          ],
        ),
      ),
    );
  }
}
