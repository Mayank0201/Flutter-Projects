class Weather {
  final String city;
  final double temperature;
  final String description;
  final String searchedAt;
  final double windSpeed;
  final String? time;

  Weather({
    required this.city,
    required this.temperature,
    required this.description,
    required this.searchedAt,
    this.windSpeed = 0.0,
    this.time,
  });

  factory Weather.fromJson(Map<String, dynamic> json) {
    return Weather(
      city: json['city'] ?? '',
      temperature: (json['temperature'] as num).toDouble(),
      description: json['description'] ?? '',
      searchedAt: json['searchedAt'] ?? '',
      windSpeed: (json['windSpeed'] as num?)?.toDouble() ?? 0.0,
      time: json['dateTime'],
    );
  }

  factory Weather.fromForecastJson(Map<String, dynamic> json) {
    return Weather(
      city: '',
      temperature: (json['main']['temp'] as num).toDouble(),
      description: json['weather'][0]['description'] ?? '',
      searchedAt: '',
      windSpeed: (json['wind']['speed'] as num?)?.toDouble() ?? 0.0,
      time: json['dt_txt'],
    );
  }
}
