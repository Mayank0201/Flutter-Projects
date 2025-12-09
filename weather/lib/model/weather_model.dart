class Weather {
  final String city;
  final double temperature;
  final String description;
  final int humidity;
  final double windSpeed;
  final int pressure;
  final String? time;

  Weather({
    required this.city,
    required this.temperature,
    required this.description,
    required this.humidity,
    required this.windSpeed,
    required this.pressure,
    this.time,
  });

  // CURRENT WEATHER
  factory Weather.fromJson(Map<String, dynamic> json) {
    return Weather(
      city: json["name"],
      temperature: (json["main"]["temp"]).toDouble(),
      description: json["weather"][0]["description"],
      humidity: json["main"]["humidity"],
      windSpeed: (json["wind"]["speed"]).toDouble(),
      pressure: json["main"]["pressure"],
    );
  }

  // FORECAST WEATHER
  factory Weather.fromForecastJson(Map<String, dynamic> json) {
    return Weather(
      city: "",
      temperature: (json["main"]["temp"]).toDouble(),
      description: json["weather"][0]["description"],
      humidity: json["main"]["humidity"],
      windSpeed: (json["wind"]["speed"]).toDouble(),
      pressure: json["main"]["pressure"],
      time: json["dt_txt"],
    );
  }
}
