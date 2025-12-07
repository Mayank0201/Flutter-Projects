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
      MaterialPageRoute(
        builder: (_) => WeatherPage(city: city),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),

      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Enter City Name",
                style: TextStyle(fontSize: 22),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: controller,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => submitCity(),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Type city name",
                  hintStyle: TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: submitCity,
                child: const Text("Search Weather"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
