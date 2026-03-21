import 'package:flutter/material.dart';
import 'weather_page.dart';

class CityInputScreen extends StatefulWidget {
  const CityInputScreen({super.key});

  @override
  State<CityInputScreen> createState() => _CityInputScreenState();
}

class _CityInputScreenState extends State<CityInputScreen> {
  final TextEditingController controller = TextEditingController();

  void submitCity() {
    final city = controller.text.trim();
    if (city.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WeatherPage(city: city)),
    ).then((_) => controller.clear());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.wb_sunny_rounded, size: 56, color: cs.onPrimaryContainer),
              ),
              const SizedBox(height: 28),
              Text(
                "Weather",
                style: tt.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                "Check live weather for any city",
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 36),
              TextField(
                controller: controller,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => submitCity(),
                style: tt.bodyLarge?.copyWith(color: cs.onSurface),
                decoration: InputDecoration(
                  hintText: "Enter city name...",
                  hintStyle: TextStyle(color: cs.onSurfaceVariant),
                  prefixIcon: Icon(Icons.search, color: cs.primary),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: cs.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: submitCity,
                  icon: const Icon(Icons.cloud_outlined),
                  label: const Text("Get Weather"),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
