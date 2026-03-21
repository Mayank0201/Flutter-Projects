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
  String errorMessage = '';

  final service = WeatherService();

  @override
  void initState() {
    super.initState();
    fetchWeatherData(widget.city);
  }

  Future<void> fetchWeatherData(String city) async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      weather = await service.getWeather(city).timeout(const Duration(seconds: 10));
      forecast = await service.getForecast(city).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint("Weather error: $e");
      if (e.toString().contains('TimeoutException')) {
        errorMessage = 'Request timed out';
      } else {
        errorMessage = 'City not found';
      }
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  IconData getWeatherIcon(Weather w) {
    final desc = w.description.toLowerCase();
    if (desc.contains("clear")) return Icons.wb_sunny_rounded;
    if (desc.contains("rain") || desc.contains("drizzle")) return Icons.water_drop_rounded;
    if (desc.contains("thunderstorm")) return Icons.thunderstorm_rounded;
    if (desc.contains("snow")) return Icons.ac_unit;
    if (desc.contains("cloud")) return Icons.cloud_rounded;
    return Icons.cloud_queue_rounded;
  }

  Color getWeatherIconColor(Weather w, ColorScheme cs) {
    final desc = w.description.toLowerCase();
    if (desc.contains("clear")) return Colors.amber;
    if (desc.contains("rain") || desc.contains("drizzle")) return Colors.blue;
    if (desc.contains("thunderstorm")) return Colors.deepPurple;
    if (desc.contains("snow")) return Colors.lightBlue;
    if (desc.contains("cloud")) return cs.primary;
    return cs.secondary;
  }

  String formatTime(String timestamp) {
    if (timestamp.isEmpty) return "--:--";
    try {
      String parseStr = timestamp;
      if (!parseStr.contains('T')) parseStr = parseStr.replaceFirst(' ', 'T');
      if (!parseStr.endsWith('Z') && !parseStr.contains('+')) {
        parseStr += 'Z'; // Force UTC parsing
      }
      final dt = DateTime.parse(parseStr).toLocal();
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return "$hour:$minute";
    } catch (e) {
      if (timestamp.length >= 16) return timestamp.substring(11, 16);
      return timestamp;
    }
  }

  Widget buildErrorUI(ColorScheme cs, TextTheme tt) {
    final isTimeout = errorMessage.contains('timed out');
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isTimeout ? Icons.timer_off_rounded : Icons.location_off_rounded, color: Colors.red.shade300, size: 84), // soft red
            const SizedBox(height: 20),
            Text(
              errorMessage.isNotEmpty ? errorMessage : "City not found",
              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface),
            ),
            const SizedBox(height: 10),
            Text(
              isTimeout 
                ? "Server is taking too long to respond."
                : "Please check the city name and try again.",
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isTimeout) ...[
                  FilledButton.icon(
                    onPressed: () => fetchWeatherData(widget.city),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text("Refresh"),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(width: 20), // added spacing
                ],
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text("Back"),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(cs.surface, cs.primaryContainer, isDark ? 0.8 : 0.3)!,
            cs.surface,
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            widget.city[0].toUpperCase() + widget.city.substring(1),
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          foregroundColor: cs.onSurface,
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: cs.primary),
              onPressed: () => fetchWeatherData(widget.city),
            ),
          ],
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: isLoading
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: cs.primary),
                      const SizedBox(height: 16),
                      Text("Fetching weather...", style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                )
              : weather == null
                  ? buildErrorUI(cs, tt)
                  : buildWeatherUI(cs, tt, isDark),
        ),
      ),
    );
  }

  Widget buildWeatherUI(ColorScheme cs, TextTheme tt, bool isDark) {
    final iconColor = getWeatherIconColor(weather!, cs);
    final glassColor = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03);
    final glassBorder = isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            decoration: BoxDecoration(
              color: glassColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: glassBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.1 : 0.05),
                  blurRadius: 10,
                  spreadRadius: isDark ? 2 : 0,
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  widget.city[0].toUpperCase() + widget.city.substring(1),
                  style: tt.titleMedium?.copyWith(
                    color: cs.onSurface.withOpacity(0.6),
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: Icon(
                    getWeatherIcon(weather!),
                    key: ValueKey(weather!.description),
                    size: 80,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "${weather!.temperature.toStringAsFixed(1)}°C",
                  style: tt.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 40,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  weather!.description.toUpperCase(),
                  style: tt.titleMedium?.copyWith(
                    color: cs.onSurface.withOpacity(0.5),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          Text(
            "Next Hours",
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface),
          ),

          const SizedBox(height: 12),

          SizedBox(
            height: 128,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: forecast.length,
              itemBuilder: (context, index) {
                final item = forecast[index];
                final timeStr = item.time ?? item.searchedAt;
                final time = formatTime(timeStr);
                return ForecastCard(
                  time: time,
                  temp: item.temperature.toStringAsFixed(1),
                  icon: getWeatherIcon(item),
                  iconColor: getWeatherIconColor(item, cs),
                  cs: cs,
                  tt: tt,
                  isDark: isDark,
                );
              },
            ),
          ),

          const SizedBox(height: 28),

          Text(
            "Details",
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface),
          ),

          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                InfoItem(
                  icon: Icons.location_city_rounded,
                  label: "City",
                  value: () {
                    final raw = weather!.city.isEmpty ? widget.city : weather!.city;
                    return raw.isNotEmpty ? raw[0].toUpperCase() + raw.substring(1) : raw;
                  }(),
                  cs: cs,
                  tt: tt,
                ),
                InfoItem(
                  icon: Icons.access_time_filled_rounded,
                  label: "Last Updated",
                  value: formatTime(weather!.searchedAt),
                  cs: cs,
                  tt: tt,
                ),
                InfoItem(
                  icon: Icons.thermostat_rounded,
                  label: "Temp",
                  value: "${weather!.temperature.toStringAsFixed(1)}°C",
                  cs: cs,
                  tt: tt,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          Center(
            child: Text(
              "Weather data provided by OpenWeather",
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant.withOpacity(0.5),
                letterSpacing: 0.5,
              ),
            ),
          ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class ForecastCard extends StatelessWidget {
  final String time;
  final String temp;
  final IconData icon;
  final Color iconColor;
  final ColorScheme cs;
  final TextTheme tt;
  final bool isDark;

  const ForecastCard({
    super.key,
    required this.time,
    required this.temp,
    required this.icon,
    required this.iconColor,
    required this.cs,
    required this.tt,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.05 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            time,
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant.withOpacity(0.7), fontWeight: FontWeight.w600),
          ),
          Icon(icon, size: 30, color: iconColor),
          Text(
            "$temp°C",
            style: tt.labelMedium?.copyWith(
              color: cs.onSurface.withOpacity(0.9),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ColorScheme cs;
  final TextTheme tt;

  const InfoItem({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: cs.primary, size: 26),
        const SizedBox(height: 6),
        Text(
          value,
          style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface.withOpacity(0.9)),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant.withOpacity(0.6)),
        ),
      ],
    );
  }
}
