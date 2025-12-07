import 'package:flutter/material.dart';
import 'package:weather/pages/city_input.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // material app with dark theme
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const CityInputScreen(),  // start with city input page
    );
  }
}
