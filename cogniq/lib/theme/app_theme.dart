import'package:flutter/material.dart';

class AppTheme {
  // Muji-inspired design tokens (Dark theme - Sumi-e warm charcoal)
  static const Color bgDarkDark       = Color(0xFF181715); // Warm Dark Charcoal
  static const Color bgCardDark       = Color(0xFF22201C); // Slightly Lighter Warm Charcoal
  static const Color bgSurfaceDark    = Color(0xFF22201C);
  static const Color textPrimaryDark   = Color(0xFFEFEAE2); // Warm Soft Cream/Off-white
  static const Color textSecondaryDark = Color(0xFF8E8A82); // Muted Warm Gray
  static const Color textMutedDark     = Color(0xFF3C3934); // Thin Dark Gray / Borders

  // Muji-inspired design tokens (Light theme)
  static const Color bgDarkLight       = Color(0xFFF7F4EE); // Warm Off White
  static const Color bgCardLight       = Color(0xFFEFEAE2); // Slightly Darker Beige
  static const Color bgSurfaceLight    = Color(0xFFEFEAE2);
  static const Color textPrimaryLight   = Color(0xFF2C2C2C); // Charcoal
  static const Color textSecondaryLight = Color(0xFF6B6B6B); // Soft Gray
  static const Color textMutedLight     = Color(0xFFD9D4CC); // Thin Light Gray / Borders

  // Muji-inspired game accents (muted, desaturated earth tones)
  static const Color forestGreen      = Color(0xFF4A5D4E); // Word Guess
  static const Color slateBlue        = Color(0xFF5E6E77); // Word Ladder
  static const Color burntOrange      = Color(0xFFA95C42); // Zip
  static const Color oliveGreen       = Color(0xFF627052); // Logic / Queens
  static const Color terracotta       = Color(0xFF9B5C4A); // Memory

  // Legacy aliases for backwards compatibility in game screens
  static const Color wordleGreen      = forestGreen;
  static const Color wordleYellow     = Color(0xFFC9B458);
  static const Color spellingbeeGold  = Color(0xFFC9B458);
  static const Color weaverBlue       = slateBlue;
  static const Color zipPink          = burntOrange;
  static const Color hangmanGold      = Color(0xFFC9B458);
  static const Color crossclimbPurple = slateBlue;
  static const Color queensOrange     = oliveGreen;
  static const Color patchesTeal      = terracotta;
  static const Color connectionsRed   = oliveGreen;
  static const Color flagleSky        = Color(0xFF4F9EE8);

  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bgDarkDark,
    cardColor: bgCardDark,
    dialogBackgroundColor: bgSurfaceDark,
    colorScheme: const ColorScheme.dark(
      surface: bgDarkDark,
      primary: forestGreen,
      onSurface: textPrimaryDark,
      onSurfaceVariant: textSecondaryDark,
      outline: textMutedDark,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: bgDarkDark,
      foregroundColor: textPrimaryDark,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    useMaterial3: true,
  );

  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: bgDarkLight,
    cardColor: bgCardLight,
    dialogBackgroundColor: bgSurfaceLight,
    colorScheme: const ColorScheme.light(
      surface: bgDarkLight,
      primary: forestGreen,
      onSurface: textPrimaryLight,
      onSurfaceVariant: textSecondaryLight,
      outline: textMutedLight,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: bgDarkLight,
      foregroundColor: textPrimaryLight,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    useMaterial3: true,
  );

  static Color accentFor(String id) {
    switch (id) {
      case'wordle':      return forestGreen;
      case'hangman':     return forestGreen;
      case'weaver':      return slateBlue;
      case'zip':         return burntOrange;
      case'crossclimb':  return slateBlue;
      case'queens':      return oliveGreen;
      case'chimp':       return terracotta;
      case'connections': return oliveGreen;
      case'flagle':      return oliveGreen;
      case'wordbuilder': return forestGreen;
      case'memory':      return terracotta;
      case'spellingbee': return forestGreen;
      case'sudoku':      return oliveGreen;
      case'wordsearch':  return forestGreen;
      case'twentyfortyeight': return oliveGreen;
      case'reaction':    return terracotta;
      case'numbermemory': return terracotta;
      case'sequence':    return terracotta;
      default:            return textSecondaryLight;
    }
  }
}

extension ResponsiveTheme on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  // Colors mapping reactively to theme mode
  Color get bgDark => isDarkMode ? AppTheme.bgDarkDark : AppTheme.bgDarkLight;
  Color get bgCard => isDarkMode ? AppTheme.bgCardDark : AppTheme.bgCardLight;
  Color get bgSurface => isDarkMode ? AppTheme.bgSurfaceDark : AppTheme.bgSurfaceLight;
  Color get textPrimary => isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
  Color get textSecondary => isDarkMode ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight;
  Color get textMuted => isDarkMode ? AppTheme.textMutedDark : AppTheme.textMutedLight;

  // Dynamic layout / dimensions
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  bool get isTablet => screenWidth >= 600;
  bool get isDesktop => screenWidth >= 1024;

  // Responsive font scaling
  double scale(double size) {
    double factor = screenWidth / 375.0;
    if (factor > 1.4) factor = 1.4;
    if (factor < 0.85) factor = 0.85;
    return size * factor;
  }
}

// Legacy stub class mapping for backward compatibility
class GameColors {
  final Color primary, dark;
  final String emoji, name, description;
  const GameColors({required this.primary, required this.dark, required this.emoji, required this.name, required this.description});
}

const Map<String, GameColors> kGameColors = {
'wordle':      GameColors(primary: AppTheme.forestGreen,      dark: Color(0xFF38473C), emoji:'', name:'Word Guess',   description:''),
'hangman':     GameColors(primary: AppTheme.forestGreen,      dark: Color(0xFF38473C), emoji:'', name:'Hangman',     description:''),
'weaver':      GameColors(primary: AppTheme.slateBlue,        dark: Color(0xFF434E54), emoji:'️', name:'Word Ladder',  description:''),
'zip':         GameColors(primary: AppTheme.burntOrange,      dark: Color(0xFF7A4330), emoji:'⚡', name:'Zip',         description:''),
'crossclimb':  GameColors(primary: AppTheme.slateBlue,        dark: Color(0xFF434E54), emoji:'', name:'Word Climb',   description:''),
'queens':      GameColors(primary: AppTheme.oliveGreen,       dark: Color(0xFF454F3B), emoji:'♛', name:'Star Battle',  description:''),
'chimp':       GameColors(primary: AppTheme.terracotta,       dark: Color(0xFF704335), emoji:'', name:'Chimp Test',   description:''),
'connections': GameColors(primary: AppTheme.oliveGreen,       dark: Color(0xFF454F3B), emoji:'', name:'Categories',   description:''),
};
