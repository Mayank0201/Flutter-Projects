import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../model/weather_model.dart';

class RecentSearchesProvider extends ChangeNotifier {
  final _box = Hive.box('recent_searches');

  List<Weather> get history {
    final list = _box.values.toList();
    return list.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return Weather(
        city: map['city'] ?? '',
        temperature: (map['temperature'] as num).toDouble(),
        description: map['description'] ?? '',
        searchedAt: map['searchedAt'] ?? '',
        windSpeed: (map['windSpeed'] as num?)?.toDouble() ?? 0.0,
        time: map['dateTime'],
      );
    }).toList().reversed.toList();
  }

  void addSearch(Weather weather) {
    final currentHistory = _box.values.toList();
    if (currentHistory.isNotEmpty) {
      final last = Map<String, dynamic>.from(currentHistory.last as Map);
      // Avoid duplicate consecutive entries for the same city
      if (last['city'].toString().toLowerCase() == weather.city.toLowerCase() && 
          last['searchedAt'] == weather.searchedAt) {
        return;
      }
    }
    
    _box.add(weather.toJson());
    
    // Keep max 30 items
    if (_box.length > 30) {
      _box.deleteAt(0);
    }
    
    notifyListeners();
  }
}
