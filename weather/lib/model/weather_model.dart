class Weather {
  final String city;
  final double temperature;
  final String description;
  final String searchedAt;

  Weather({
    required this.city,
    required this.temperature,
    required this.description,
    required this.searchedAt,
  });

  factory Weather.fromJson(Map<String, dynamic> json) {
    return Weather(
      city: json['city'] ?? '',
      temperature: (json['temperature'] as num).toDouble(),
      description: json['description'] ?? '',
      searchedAt: json['searchedAt'] ?? '',
    );
  }
}
