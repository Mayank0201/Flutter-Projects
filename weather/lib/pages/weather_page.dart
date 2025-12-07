import 'package:flutter/material.dart';
import '../service/weather_service.dart';
import '../model/weather_model.dart';

class WeatherPage extends StatefulWidget {
  final String city; // store the passed city

  const WeatherPage({super.key, required this.city});

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  Weather? weather; // holds weather data
  bool isLoading = true; // loading indicator
  final service = WeatherService();

  @override
  void initState() {
    super.initState();
    fetchWeatherData(widget.city); // fetch using user city
  }

  Future<void> fetchWeatherData(String city) async {
    setState(() => isLoading = true);

    try {
      weather = await service.getWeather(city);
    } catch (e) {
      debugPrint("Weather error: $e");
    }

    setState(() => isLoading = false);
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
            onPressed: () => fetchWeatherData(widget.city),
          )
        ],
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : weather == null
          ? const Center(child: Text("Failed to load data"))
          : buildWeatherUI(),
    );
  }

  Widget buildWeatherUI() {
    return Padding(
      padding: const EdgeInsets.all(16),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // main weather card
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
                const Icon(Icons.cloud, size: 64),
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
            "Weather Forecast",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          // static forecast for now
          SizedBox(
            height: 120,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ForecastCard(time: "09:00", temp: weather!.temperature.toString()),
                ForecastCard(time: "12:00", temp: weather!.temperature.toString()),
                ForecastCard(time: "15:00", temp: weather!.temperature.toString()),
              ],
            ),
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
                icon: Icons.water_drop,
                label: "Humidity",
                value: "${weather!.humidity}%",
              ),
              InfoItem(
                icon: Icons.air,
                label: "Wind",
                value: "${weather!.windSpeed} m/s",
              ),
              InfoItem(
                icon: Icons.speed,
                label: "Pressure",
                value: "${weather!.pressure} hPa",
              ),
            ],
          )
        ],
      ),
    );
  }
}

// forecast card widget
class ForecastCard extends StatelessWidget {
  final String time;
  final String temp;

  const ForecastCard({super.key, required this.time, required this.temp});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2833),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(time),
          const Icon(Icons.cloud, size: 28),
          Text("$temp°C"),
        ],
      ),
    );
  }
}

// reusable info widget
class InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const InfoItem({super.key, 
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
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
