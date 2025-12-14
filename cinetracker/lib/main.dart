import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'pages/movie_search_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // load .env before runApp
  await dotenv.load(fileName: ".env");

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const MovieSearchPage(),
    );
  }
}
