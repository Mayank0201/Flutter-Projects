import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF6200EE); // Purple
  static const Color secondary = Color(0xFF03DAC6); // Teal
  static const Color background = Color(0xFFF5F5F5); // Light Gray
  static const Color error = Color(0xFFB00020); // Red
}

final ThemeData appTheme = ThemeData(
  primaryColor: AppColors.primary,
  colorScheme: ColorScheme.fromSwatch().copyWith(
    secondary: AppColors.secondary,
    background: AppColors.background,
    error: AppColors.error,
  ),
  scaffoldBackgroundColor: AppColors.background,
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: AppColors.primary,
    ),
  ),
);
