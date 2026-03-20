import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/weather_model.dart';

class WeatherService {
  final String baseUrl = "https://springboot-projects-8jns.onrender.com";

  // CURRENT WEATHER (FROM YOUR BACKEND)
  Future<Weather> getWeather(String city) async {
    final url = Uri.parse("$baseUrl/api/weather?city=$city");

    final response = await http
        .post(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"city": city}),
        )
        .timeout(const Duration(seconds: 30));

    print("STATUS: ${response.statusCode}");
    print("BODY: ${response.body}");

    if (response.statusCode == 200) {
      return Weather.fromJson(jsonDecode(response.body));
    } else {
      throw Exception("Failed to load weather data");
    }
  }
}
