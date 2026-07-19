import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';
import '../utils/audio_manager.dart';
import '../utils/prefs_keys.dart';

class SettingsNotifier extends ChangeNotifier {
  static const String _hapticKey = PrefsKeys.hapticEnabled;
  static const String _soundKey = PrefsKeys.soundEnabled;
  static const String _musicKey = PrefsKeys.musicEnabled;
  static const String _fontScaleKey = PrefsKeys.fontScale;
  static const String _adsRemovedKey = PrefsKeys.adsRemoved;

  bool _hapticEnabled = true;
  bool _soundEnabled = true;
  bool _musicEnabled = true;
  double _fontScale = 1.0; // 0.85, 1.0, 1.15
  bool _adsRemoved = false;

  SettingsNotifier() {
    _load();
  }

  bool get hapticEnabled => _hapticEnabled;
  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;
  double get fontScale => _fontScale;
  bool get adsRemoved => _adsRemoved;
  // Auto-next-level is now always on — no longer a user setting.
  bool get autoNextLevel => true;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _hapticEnabled = prefs.getBool(_hapticKey) ?? true;
    _soundEnabled = prefs.getBool(_soundKey) ?? true;
    _musicEnabled = prefs.getBool(_musicKey) ?? true;
    _fontScale = prefs.getDouble(_fontScaleKey) ?? 1.0;
    _adsRemoved = prefs.getBool(_adsRemovedKey) ?? false;
    notifyListeners();
    AudioManager.updateMusicSetting(_musicEnabled);
    AudioManager.updateVolume();
  }

  Future<void> setAdsRemoved(bool val) async {
    _adsRemoved = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_adsRemovedKey, val);
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
    if (!val) {
      AudioManager.stopSfx();
    }
  }

  Future<void> setMusic(bool val) async {
    _musicEnabled = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_musicKey, val);
    AudioManager.updateMusicSetting(val);
  }

  Future<void> setFontScale(double val) async {
    _fontScale = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontScaleKey, val);
  }

  // Helper methods for haptics
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
    final keys = prefs.getKeys().where((k) =>
        k.startsWith('level_') ||
        k.startsWith('daily_') ||
        k.startsWith('cleared_count_') ||
        k.startsWith('hints_') ||
        k.startsWith('streak_') ||
        k == 'global_level_cleared_count' ||
        k == 'daily_streak' ||
        k == 'daily_last_completed_date'
    ).toList();

    for (final key in keys) {
      await prefs.remove(key);
    }

    try {
      await HomeWidget.saveWidgetData('daily_streak', 0);
      await HomeWidget.saveWidgetData('total_solved', 0);
      await HomeWidget.saveWidgetData('favorite_game', 'Grid Path');
      await HomeWidget.saveWidgetData('todays_puzzle_name', 'Puzzle');
      await HomeWidget.saveWidgetData('todays_puzzle_desc', 'Train your mind');
      await HomeWidget.updateWidget(
        name: 'StreakWidgetProvider',
        androidName: 'StreakWidgetProvider',
        qualifiedAndroidName: 'com.mayank.cogniq.StreakWidgetProvider',
      );
    } catch (_) {}

    notifyListeners();
  }
}

final settingsNotifier = SettingsNotifier();
