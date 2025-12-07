import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/weather_model.dart';

class WeatherService {
  final String baseUrl = "https://api.openweathermap.org/data/2.5/weather";
  final String apiKey = "5b14fb9e94d9a17718b41c5a0aa18a83";

  Future<Weather> getWeather(String city) async {
    final url = Uri.parse("$baseUrl?q=$city&appid=$apiKey&units=metric");

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Weather.fromJson(data);
    } else {
      throw Exception("Failed to load weather data");
    }
  }
}