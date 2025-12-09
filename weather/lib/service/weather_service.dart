import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/weather_model.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class WeatherService {
  final String apiKey = dotenv.env['API_KEY'] ?? '';

  final String currentUrl = "https://api.openweathermap.org/data/2.5/weather";
  final String forecastUrl = "https://api.openweathermap.org/data/2.5/forecast";

  // CURRENT WEATHER
  Future<Weather> getWeather(String city) async {
    final url = Uri.parse("$currentUrl?q=$city&appid=$apiKey&units=metric");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return Weather.fromJson(jsonDecode(response.body));
    } else {
      throw Exception("Failed to load weather data");
    }
  }

  // FORECAST (next 3-hour intervals)
  Future<List<Weather>> getForecast(String city) async {
    final url = Uri.parse("$forecastUrl?q=$city&appid=$apiKey&units=metric");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final list = jsonDecode(response.body)["list"];

      // Take first 4 forecast entries: 09:00, 12:00, 15:00, 18:00
      return List.generate(4, (i) {
        return Weather.fromForecastJson(list[i]);
      });
    } else {
      throw Exception("Failed to load forecast data");
    }
  }
}
