import'package:flutter/material.dart';
import'package:google_fonts/google_fonts.dart';
import'../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) { Navigator.pushReplacementNamed(context,'/home'); }
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDark,
      body: FadeTransition(
        opacity: _fade,
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('', style: TextStyle(fontSize: context.scale(56))),
            const SizedBox(height: 20),
            Text('CogniQ',
              style: GoogleFonts.outfit(fontSize: context.scale(40), fontWeight: FontWeight.w800, color: context.textPrimary, letterSpacing: -1)),
            const SizedBox(height: 8),
            Text('Play. Think. Win.',
              style: GoogleFonts.outfit(fontSize: context.scale(15), color: context.textMuted, letterSpacing: 1.5)),
          ]),
        ),
      ),
    );
  }
}
