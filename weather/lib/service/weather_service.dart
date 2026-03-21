import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/weather_model.dart';

class WeatherService {
  final String currentUrl = "https://springboot-projects-8jns.onrender.com";

  // current weather
  Future<Weather> getWeather(String city) async {
    final url = Uri.parse("$currentUrl/api/weather?city=$city");

    final response = await http
        .post(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"city": city}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return Weather.fromJson(jsonDecode(response.body));
    } else {
      throw Exception("Failed to load weather data");
    }
  }

  // forecast (next 3-hour intervals)
  Future<List<Weather>> getForecast(String city) async {
    final url = Uri.parse("$currentUrl/api/forecast?city=$city");

    final response = await http.get(url).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      List<dynamic> list;
      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('forecasts')) {
          list = decoded['forecasts'] as List;
        } else if (decoded.containsKey('list')) {
          list = decoded['list'] as List;
        } else {
          list = [decoded];
        }
      } else if (decoded is List) {
        list = decoded;
      } else {
        list = [decoded];
      }

      int count = list.length > 4 ? 4 : list.length;
      return List.generate(count, (i) {
        try {
          if (list[i] is Map<String, dynamic> &&
              list[i].containsKey('weather') &&
              list[i].containsKey('main')) {
            return Weather.fromForecastJson(list[i]);
          } else {
            return Weather.fromJson(list[i]);
          }
        } catch (e) {
          return Weather(
            city: city,
            temperature: 0,
            description: 'Unknown',
            searchedAt: '',
          );
        }
      });
    } else {
      throw Exception("Failed to load forecast data");
    }
  }

}
