import 'package:cinetracker/core/network/api_service.dart';
import 'package:cinetracker/core/storage/token_storage.dart';
import 'package:cinetracker/features/auth/pages/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/adapters.dart';
import 'service/tmdb_service.dart';
import 'features/home/pages/main_page.dart';
import 'package:provider/provider.dart';
import 'provider/wishlist_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox("wishlistBox");

  // load .env before runapp
  await dotenv.load(fileName: ".env");

  final storage = TokenStorage();
  await storage.clearToken();
  final token = await storage.getToken();

  final ApiService apiService = ApiService();
  final TMDBService tmdbService = TMDBService();

  if (token != null && token.isNotEmpty) {
    apiService.setToken(token);
    tmdbService.setToken(token);
  } else {
    tmdbService.clearToken();
  }

  runApp(const MyApp(isLoggedIn: false));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.deepPurple);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<WishlistProvider>(
          create: (_) {
            final provider = WishlistProvider();
            if (isLoggedIn) {
              provider.loadWatchlist();
            }
            return provider;
          },
        ),
      ],
      child: MaterialApp(
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
        home: isLoggedIn ? const MainPage() : const LoginScreen(),
      ),
    );
  }
}
