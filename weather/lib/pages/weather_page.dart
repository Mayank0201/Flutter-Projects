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
  List<Weather> forecast = [];
  bool isLoading = true;

  final service = WeatherService();

  @override
  void initState() {
    super.initState();
    fetchWeatherData(widget.city);
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
                Navigator.pop(context);     // ⬅️ GO BACK TO CITY INPUT
              },
              child: const Text("Try Another City"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> fetchWeatherData(String city) async {
    setState(() => isLoading = true);

    try {
      weather = await service.getWeather(city);
      forecast = await service.getForecast(city);
    } catch (e) {
      debugPrint("Weather error: $e");
    }

    setState(() => isLoading = false);
  }

  IconData getWeatherIcon(Weather w) {
    // Rule 3: rain or high wind
    if (w.description.toLowerCase().contains("rain") || w.windSpeed > 10) {
      return Icons.cloudy_snowing; // rain / storm style
    }

    // Rule 1: hot weather
    if (w.temperature > 30) {
      return Icons.wb_sunny;
    }

    // Rule 2: cold weather
    if (w.temperature < 15) {
      return Icons.ac_unit;
    }

    // Default
    return Icons.cloud;
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
              Navigator.pop(context);   // go back to city input screen
            },
          )
        ],
      ),


      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : weather == null
          ? buildErrorUI()   // NEW ERROR UI
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
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
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
            "Next Hours Forecast",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          // REAL FORECAST DISPLAY
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: forecast.length,
              itemBuilder: (context, index) {
                final item = forecast[index];
                final time = item.time!.substring(11, 16); // "HH:MM"

                return ForecastCard(
                  time: time,
                  temp: item.temperature.toString(),
                  icon: getWeatherIcon(item),
                );
              },
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

// FORECAST CARD
class ForecastCard extends StatelessWidget {
  final String time;
  final String temp;
  final IconData icon;

  const ForecastCard({
    super.key,
    required this.time,
    required this.temp,
    required this.icon,
  });

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
          Icon(icon, size: 28),
          Text("$temp°C"),
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

  const InfoItem({super.key, required this.icon, required this.label, required this.value});

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
