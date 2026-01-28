import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/adapters.dart';
import 'pages/main_page.dart';
import 'package:provider/provider.dart';
import 'provider/wishlist_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox("wishlistBox");

  // load .env before runApp
  await dotenv.load(fileName: ".env");

  runApp(
    ChangeNotifierProvider(
      create: (_) => WishlistProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.deepPurple);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,

        // global font for the entire app
        textTheme: GoogleFonts.interTextTheme(),

        appBarTheme: AppBarTheme(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          centerTitle: true,
          elevation: 2,
        ),
      ),
      home: const MainPage(),
    );
  }
}
