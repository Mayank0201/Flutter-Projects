import 'package:flutter/material.dart';

class AppTheme {
  // ── Zen palette ─────────────────────────────────────────────────────────────
  // Light (primary mode)
  static const Color bgDarkLight       = Color(0xFFF5F4F0); // warm linen
  static const Color bgCardLight       = Color(0xFFFFFFFF); // pure white cards
  static const Color bgSurfaceLight    = Color(0xFFEEECE8); // slightly warm surface
  static const Color textPrimaryLight   = Color(0xFF2B2926); // warm charcoal
  static const Color textSecondaryLight = Color(0xFF7A7672); // muted taupe
  static const Color textMutedLight     = Color(0xFFE2DFDA); // barely-there border

  // Dark
  static const Color bgDarkDark       = Color(0xFF1C1A18);
  static const Color bgCardDark       = Color(0xFF252320);
  static const Color bgSurfaceDark    = Color(0xFF252320);
  static const Color textPrimaryDark   = Color(0xFFF0EBE3);
  static const Color textSecondaryDark = Color(0xFF8A847C);
  static const Color textMutedDark     = Color(0xFF302E2A);

  // ── Warm-zen accent palette ─────────────────────────────────────────────────
  // Drawn from the reference image: mauve, warm gold, slate periwinkle, terracotta
  static const Color dustyMauve    = Color(0xFF8B6E8C); // spiritual calm
  static const Color warmAmber     = Color(0xFFD4953A); // warm active
  static const Color slateBlue     = Color(0xFF5E7A8C); // serene
  static const Color softSage      = Color(0xFF6B8C6E); // natural
  static const Color terracotta    = Color(0xFF9E6B5A); // grounded
  static const Color roseGold      = Color(0xFFC4786E); // gentle
  static const Color deepLavender  = Color(0xFF7068A0); // focus

  // ── Legacy game-colour aliases ───────────────────────────────────────────────
  static const Color forestGreen      = softSage;
  static const Color oliveGreen       = softSage;
  static const Color burntOrange      = warmAmber;
  static const Color wordleGreen      = softSage;
  static const Color wordleYellow     = warmAmber;
  static const Color spellingbeeGold  = warmAmber;
  static const Color weaverBlue       = slateBlue;
  static const Color zipPink          = roseGold;
  static const Color hangmanGold      = warmAmber;
  static const Color crossclimbPurple = dustyMauve;
  static const Color queensOrange     = deepLavender;
  static const Color patchesTeal      = slateBlue;
  static const Color connectionsRed   = dustyMauve;
  static const Color flagleSky        = slateBlue;

  // ── Themes ───────────────────────────────────────────────────────────────────
  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: bgDarkLight,
    cardColor: bgCardLight,
    dialogBackgroundColor: bgCardLight,
    colorScheme: const ColorScheme.light(
      surface: bgDarkLight,
      primary: dustyMauve,
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

  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bgDarkDark,
    cardColor: bgCardDark,
    dialogBackgroundColor: bgCardDark,
    colorScheme: const ColorScheme.dark(
      surface: bgDarkDark,
      primary: dustyMauve,
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

  static Color accentFor(String id) {
    switch (id) {
      case 'wordle':      return softSage;
      case 'hangman':     return warmAmber;
      case 'weaver':      return slateBlue;
      case 'zip':         return roseGold;
      case 'crossclimb':  return dustyMauve;
      case 'queens':      return deepLavender;
      case 'chimp':       return terracotta;
      case 'connections': return dustyMauve;
      case 'flagle':      return slateBlue;
      case 'wordbuilder': return softSage;
      case 'memory':      return roseGold;
      case 'spellingbee': return warmAmber;
      case 'sudoku':      return deepLavender;
      case 'wordsearch':  return softSage;
      case 'twentyfortyeight': return terracotta;
      case 'reaction':    return roseGold;
      case 'numbermemory': return slateBlue;
      case 'sequence':    return dustyMauve;
      default:            return textSecondaryLight;
    }
  }

  // Gradient for hero banner — warm purple-to-gold inspired by the image
  static const LinearGradient zenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7068A0), Color(0xFFB07A5A), Color(0xFFD4953A)],
    stops: [0.0, 0.6, 1.0],
  );

  // Soft card shadow
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF2B2926).withAlpha(12),
      blurRadius: 20,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: const Color(0xFF2B2926).withAlpha(6),
      blurRadius: 6,
      offset: const Offset(0, 1),
      spreadRadius: 0,
    ),
  ];
}

extension ResponsiveTheme on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get bgDark    => isDarkMode ? AppTheme.bgDarkDark    : AppTheme.bgDarkLight;
  Color get bgCard    => isDarkMode ? AppTheme.bgCardDark    : AppTheme.bgCardLight;
  Color get bgSurface => isDarkMode ? AppTheme.bgSurfaceDark : AppTheme.bgSurfaceLight;
  Color get textPrimary   => isDarkMode ? AppTheme.textPrimaryDark   : AppTheme.textPrimaryLight;
  Color get textSecondary => isDarkMode ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight;
  Color get textMuted     => isDarkMode ? AppTheme.textMutedDark     : AppTheme.textMutedLight;

  double get screenWidth  => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  bool get isTablet  => screenWidth >= 600;
  bool get isDesktop => screenWidth >= 1024;

  double scale(double size) {
    double factor = screenWidth / 375.0;
    if (factor > 1.4) factor = 1.4;
    if (factor < 0.85) factor = 0.85;
    return size * factor;
  }
}

class GameColors {
  final Color primary, dark;
  final String emoji, name, description;
  const GameColors({required this.primary, required this.dark, required this.emoji, required this.name, required this.description});
}

const Map<String, GameColors> kGameColors = {
  'wordle':      GameColors(primary: AppTheme.softSage,      dark: Color(0xFF4B6B4E), emoji: '', name: 'Word Guess',   description: ''),
  'hangman':     GameColors(primary: AppTheme.warmAmber,     dark: Color(0xFF8A6020), emoji: '', name: 'Hangman',      description: ''),
  'weaver':      GameColors(primary: AppTheme.slateBlue,     dark: Color(0xFF3E5A6C), emoji: '', name: 'Word Ladder',  description: ''),
  'zip':         GameColors(primary: AppTheme.roseGold,     dark: Color(0xFF9E5D54), emoji: '⚡', name: 'Zip',         description: ''),
  'crossclimb':  GameColors(primary: AppTheme.dustyMauve,   dark: Color(0xFF5E4860), emoji: '', name: 'Word Climb',   description: ''),
  'queens':      GameColors(primary: AppTheme.deepLavender, dark: Color(0xFF4A4278), emoji: '♛', name: 'Star Battle',  description: ''),
  'chimp':       GameColors(primary: AppTheme.terracotta,   dark: Color(0xFF6E4838), emoji: '', name: 'Chimp Test',   description: ''),
  'connections': GameColors(primary: AppTheme.dustyMauve,   dark: Color(0xFF5E4860), emoji: '', name: 'Categories',   description: ''),
};
