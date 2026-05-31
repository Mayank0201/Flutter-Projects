import'package:flutter/material.dart';
import'package:flutter/services.dart';
import'package:shared_preferences/shared_preferences.dart';

class SettingsNotifier extends ChangeNotifier {
  static const String _hapticKey ='settings_haptic';
  static const String _soundKey ='settings_sound';
  static const String _fontScaleKey ='settings_font_scale';

  bool _hapticEnabled = true;
  bool _soundEnabled = true;
  double _fontScale = 1.0; // 0.85, 1.0, 1.15

  SettingsNotifier() {
    _load();
  }

  bool get hapticEnabled => _hapticEnabled;
  bool get soundEnabled => _soundEnabled;
  double get fontScale => _fontScale;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _hapticEnabled = prefs.getBool(_hapticKey) ?? true;
    _soundEnabled = prefs.getBool(_soundKey) ?? true;
    _fontScale = prefs.getDouble(_fontScaleKey) ?? 1.0;
    notifyListeners();
  }

  Future<void> setHaptic(bool val) async {
    _hapticEnabled = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hapticKey, val);
  }

  Future<void> setSound(bool val) async {
    _soundEnabled = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundKey, val);
  }

  Future<void> setFontScale(double val) async {
    _fontScale = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontScaleKey, val);
  }

  /// Call this on correct answers, button taps, etc.
  void hapticTap() {
    if (_hapticEnabled) HapticFeedback.lightImpact();
  }

  void hapticSuccess() {
    if (_hapticEnabled) HapticFeedback.mediumImpact();
  }

  void hapticError() {
    if (_hapticEnabled) HapticFeedback.heavyImpact();
  }

  Future<void> resetAllProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('level_') || k.startsWith('daily_'));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}

final settingsNotifier = SettingsNotifier();
