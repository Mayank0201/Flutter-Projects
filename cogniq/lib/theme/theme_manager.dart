import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ChangeNotifier {
  static const String _themeKey = "theme_mode";
  ThemeMode _themeMode = ThemeMode.system;

  ThemeNotifier() {
    _loadTheme();
  }

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
      return brightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_themeKey);
    if (index != null) {
      _themeMode = ThemeMode.values[index];
      notifyListeners();
    }
  }

  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.dark) {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.dark;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, _themeMode.index);
  }
}

// Global notifier instance
final themeNotifier = ThemeNotifier();
