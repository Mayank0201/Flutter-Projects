import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── dark palette (cinematic charcoal + amber gold) ──────────────────────
  static const Color _darkBg        = Color(0xFF111110); // near-black, warm
  static const Color _darkSurface   = Color(0xFF1C1B19); // elevated surface
  static const Color _darkCard      = Color(0xFF242320); // card / input bg
  static const Color _darkAccent    = Color(0xFFE8A020); // amber gold
  static const Color _darkAccentDim = Color(0xFFB87D18); // dimmer gold
  static const Color _darkOnBg      = Color(0xFFEDEAE3); // warm off-white
  static const Color _darkOnBgMuted = Color(0xFF8C8880); // warm mid-gray
  static const Color _darkDivider   = Color(0xFF2E2D2A); // subtle separator

  // ── light palette (warm cream + terracotta) ──────────────────────────────
  static const Color _lightBg        = Color(0xFFF7F4F0); // warm cream
  static const Color _lightSurface   = Color(0xFFFFFEFC); // almost white warm
  static const Color _lightCard      = Color(0xFFFFFEFC);
  static const Color _lightAccent    = Color(0xFFC2622D); // terracotta
  static const Color _lightAccentDim = Color(0xFFD97B45); // lighter terracotta
  static const Color _lightOnBg      = Color(0xFF1E1C1A); // warm near-black
  static const Color _lightOnBgMuted = Color(0xFF6B6560); // warm gray
  static const Color _lightDivider   = Color(0xFFE0DAD3); // warm separator

  static TextTheme _buildTextTheme(Color onBg, Color onBgMuted) {
    return TextTheme(
      displayLarge: GoogleFonts.dmSans(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: onBg,
        letterSpacing: -0.8,
      ),
      displayMedium: GoogleFonts.dmSans(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: onBg,
        letterSpacing: -0.6,
      ),
      headlineLarge: GoogleFonts.dmSans(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: onBg,
        letterSpacing: -0.4,
      ),
      headlineMedium: GoogleFonts.dmSans(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: onBg,
        letterSpacing: -0.2,
      ),
      titleLarge: GoogleFonts.dmSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: onBg,
      ),
      titleMedium: GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: onBg,
      ),
      titleSmall: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: onBgMuted,
      ),
      bodyLarge: GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: onBg,
        height: 1.55,
      ),
      bodyMedium: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: onBg,
        height: 1.5,
      ),
      bodySmall: GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: onBgMuted,
        height: 1.4,
      ),
      labelLarge: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: onBg,
      ),
      labelMedium: GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: onBgMuted,
      ),
      labelSmall: GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: onBgMuted,
      ),
    );
  }

  // ── DARK THEME ────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    final textTheme = _buildTextTheme(_darkOnBg, _darkOnBgMuted);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _darkBg,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      colorScheme: const ColorScheme.dark(
        primary: _darkAccent,
        primaryContainer: _darkAccentDim,
        secondary: _darkAccentDim,
        surface: _darkSurface,
        onPrimary: Color(0xFF111110),
        onSurface: _darkOnBg,
        onSurfaceVariant: _darkOnBgMuted,
        outline: _darkDivider,
        error: Color(0xFFE05C5C),
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: _darkBg,
        foregroundColor: _darkOnBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: _darkOnBg,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: _darkOnBg, size: 22),
      ),
      cardTheme: CardThemeData(
        color: _darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkCard,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _darkDivider, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _darkAccent, width: 1.5),
        ),
        hintStyle: GoogleFonts.dmSans(color: _darkOnBgMuted, fontSize: 14),
        labelStyle: GoogleFonts.dmSans(color: _darkOnBgMuted, fontSize: 14),
        floatingLabelStyle: GoogleFonts.dmSans(
          color: _darkAccent,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _darkAccent,
          foregroundColor: const Color(0xFF111110),
          elevation: 0,
          padding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.dmSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _darkAccent,
          textStyle: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _darkSurface,
        selectedItemColor: _darkAccent,
        unselectedItemColor: _darkOnBgMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
        selectedLabelStyle: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: _darkDivider,
        thickness: 0.5,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: _darkOnBg,
        ),
        subtitleTextStyle: GoogleFonts.dmSans(
          fontSize: 13,
          color: _darkOnBgMuted,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _darkCard,
        labelStyle: GoogleFonts.dmSans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: _darkOnBg,
        ),
        side: const BorderSide(color: _darkDivider, width: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _darkCard,
        contentTextStyle: GoogleFonts.dmSans(
          fontSize: 14,
          color: _darkOnBg,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _darkAccent,
      ),
      iconTheme: const IconThemeData(color: _darkOnBg, size: 22),
    );
  }

  // ── LIGHT THEME ───────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    final textTheme = _buildTextTheme(_lightOnBg, _lightOnBgMuted);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: _lightBg,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      colorScheme: const ColorScheme.light(
        primary: _lightAccent,
        primaryContainer: _lightAccentDim,
        secondary: _lightAccentDim,
        surface: _lightSurface,
        onPrimary: Colors.white,
        onSurface: _lightOnBg,
        onSurfaceVariant: _lightOnBgMuted,
        outline: _lightDivider,
        error: Color(0xFFB93E3E),
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: _lightBg,
        foregroundColor: _lightOnBg,
        elevation: 0,
        scrolledUnderElevation: 0.3,
        surfaceTintColor: Colors.transparent,
        shadowColor: _lightDivider,
        centerTitle: false,
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: _lightOnBg,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: _lightOnBg, size: 22),
      ),
      cardTheme: CardThemeData(
        color: _lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _lightDivider, width: 0.8),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightSurface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _lightDivider, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _lightAccent, width: 1.5),
        ),
        hintStyle: GoogleFonts.dmSans(color: _lightOnBgMuted, fontSize: 14),
        labelStyle:
            GoogleFonts.dmSans(color: _lightOnBgMuted, fontSize: 14),
        floatingLabelStyle: GoogleFonts.dmSans(
          color: _lightAccent,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _lightAccent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.dmSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _lightAccent,
          textStyle: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _lightSurface,
        selectedItemColor: _lightAccent,
        unselectedItemColor: _lightOnBgMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
        selectedLabelStyle: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: _lightDivider,
        thickness: 0.5,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: _lightOnBg,
        ),
        subtitleTextStyle: GoogleFonts.dmSans(
          fontSize: 13,
          color: _lightOnBgMuted,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _lightBg,
        labelStyle: GoogleFonts.dmSans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: _lightOnBg,
        ),
        side: const BorderSide(color: _lightDivider, width: 0.8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _lightOnBg,
        contentTextStyle: GoogleFonts.dmSans(
          fontSize: 14,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _lightAccent,
      ),
      iconTheme: const IconThemeData(color: _lightOnBg, size: 22),
    );
  }
}
