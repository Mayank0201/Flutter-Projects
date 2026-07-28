import 'package:shared_preferences/shared_preferences.dart';
import 'prefs_keys.dart';

class PointManager {
  static const String _key = PrefsKeys.points;

  static Future<int> getPoints() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key) ?? 0;
  }

  static Future<void> addPoints(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_key) ?? 0;
    await prefs.setInt(_key, current + amount);
  }

  static Future<bool> consumePoints(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_key) ?? 0;
    if (current < amount) return false;
    await prefs.setInt(_key, current - amount);
    return true;
  }

  static Future<void> setBalance(int balance) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, balance);
  }
}
