import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';

class GameCompletedScreen extends StatelessWidget {
  final String gameName;
  final String? prefKey;
  final String? routeName;

  const GameCompletedScreen({
    super.key,
    required this.gameName,
    this.prefKey,
    this.routeName,
  });

  /// Helper function to route to the Game Completed Screen
  static void show(
    BuildContext context, {
    required String gameName,
    String? prefKey,
    String? routeName,
  }) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => GameCompletedScreen(
          gameName: gameName,
          prefKey: prefKey,
          routeName: routeName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              // Trophy / Achievement Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppTheme.warmAmber.withAlpha(25),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.warmAmber.withAlpha(80),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.emoji_events_rounded,
                  size: 64,
                  color: AppTheme.warmAmber,
                ),
              )
                  .animate()
                  .scale(
                    begin: const Offset(0.3, 0.3),
                    end: const Offset(1.0, 1.0),
                    duration: 600.ms,
                    curve: Curves.elasticOut,
                  )
                  .shimmer(delay: 500.ms, duration: 1000.ms),
              const SizedBox(height: 36),

              // Title
              Text(
                'Congratulations!',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 200.ms)
                  .slideY(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOutQuad),
              const SizedBox(height: 12),

              // Subtext with Game Name
              Text(
                'You have mastered $gameName!',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.queensOrange,
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 350.ms)
                  .slideY(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOutQuad),
              const SizedBox(height: 20),

              // Description
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Good job! You have successfully completed all available levels of this training category. More levels will be added soon to keep stretching your limits!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    color: isDark ? Colors.white70 : Colors.black54,
                    height: 1.5,
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 500.ms)
                  .slideY(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOutQuad),
              const Spacer(),

              // Action Buttons
              if (prefKey != null && routeName != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.queensOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setInt(prefKey!, 0);
                      final gameId = prefKey!.startsWith('level_') ? prefKey!.substring(6) : prefKey!;
                      await prefs.remove('daily_backup_$gameId');
                      await prefs.remove('daily_backup_active_game');
                      if (context.mounted) {
                        Navigator.pushReplacementNamed(context, routeName!);
                      }
                    },
                    child: Text(
                      'Replay Game',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 650.ms)
                    .slideY(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOutQuad),
                const SizedBox(height: 12),
              ],

              // Return to Home button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : Colors.black87,
                    side: BorderSide(color: isDark ? Colors.white30 : Colors.black26),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
                  },
                  child: Text(
                    'Back to Home',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 750.ms)
                  .slideY(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOutQuad),
            ],
          ),
        ),
      ),
    );
  }
}
