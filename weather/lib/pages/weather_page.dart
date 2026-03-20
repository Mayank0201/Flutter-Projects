import 'package:flutter/material.dart';
import '../service/weather_service.dart';
import '../model/weather_model.dart';

class WeatherPage extends StatefulWidget {
  final String city;

  const WeatherPage({super.key, required this.city});

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  Weather? weather;
  bool isLoading = true;

  final service = WeatherService();

  @override
  void initState() {
    super.initState();
    fetchWeatherData(widget.city);
  }

  Future<void> fetchWeatherData(String city) async {
    setState(() => isLoading = true);

    try {
      weather = await service.getWeather(city);
    } catch (e) {
      debugPrint("Weather error: $e");
      weather = null;
    }

    setState(() => isLoading = false);
  }

  Widget buildErrorUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 60),
            const SizedBox(height: 16),
            const Text(
              "City not found!",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Please enter a valid city name.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Try Another City"),
            ),
          ],
        ),
      ),
    );
  }

  IconData getWeatherIcon(Weather w) {
    if (w.description.toLowerCase().contains("rain")) {
      return Icons.cloudy_snowing;
    }

    if (w.temperature > 30) {
      return Icons.wb_sunny;
    }

    if (w.temperature < 15) {
      return Icons.ac_unit;
    }

    return Icons.cloud;
  }

  String formatTime(String timestamp) {
    return timestamp.substring(11, 16); // HH:mm
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),

      appBar: AppBar(
        title: Text("Weather - ${widget.city}"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : weather == null
          ? buildErrorUI()
          : buildWeatherUI(),
    );
  }

  Widget buildWeatherUI() {
    return Padding(
      padding: const EdgeInsets.all(16),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // MAIN WEATHER CARD
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2833),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  "${weather!.temperature}°C",
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Icon(getWeatherIcon(weather!), size: 64),
                const SizedBox(height: 8),
                Text(
                  weather!.description,
                  style: const TextStyle(fontSize: 18),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            "Forecast",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          const Text(
            "Forecast coming soon...",
            style: TextStyle(color: Colors.grey),
          ),

          const SizedBox(height: 24),

          const Text(
            "Additional Information",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              InfoItem(
                icon: Icons.location_city,
                label: "City",
                value: weather!.city,
              ),
              InfoItem(
                icon: Icons.access_time,
                label: "Time",
                value: formatTime(weather!.searchedAt),
              ),
              InfoItem(
                icon: Icons.thermostat,
                label: "Temp",
                value: "${weather!.temperature}°C",
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// INFO CARD
class InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const InfoItem({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
