import 'package:cinetracker/core/network/api_service.dart';
import 'package:cinetracker/core/navigation/app_navigator.dart';
import 'package:cinetracker/core/storage/token_storage.dart';
import 'package:cinetracker/core/theme/app_theme.dart';
import 'package:cinetracker/features/auth/pages/login_screen.dart';
import 'package:cinetracker/provider/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/adapters.dart';
import 'service/tmdb_service.dart';
import 'features/home/pages/main_page.dart';
import 'package:provider/provider.dart';
import 'provider/wishlist_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Hive.initFlutter();
  await Hive.openBox("wishlistBox");

  // load .env before runapp
  await dotenv.load(fileName: ".env");

  final storage = TokenStorage();
  final token = await storage.getAccessToken();
  final isLoggedIn = token != null && token.isNotEmpty;
  final accessToken = token ?? '';

  final apiService = ApiService();
  final tmdbService = TMDBService();

  if (isLoggedIn) {
    apiService.setToken(accessToken);
    tmdbService.setToken(accessToken);
  } else {
    apiService.clearToken();
    tmdbService.clearToken();
  }

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
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
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            navigatorKey: appNavigatorKey,
            debugShowCheckedModeBanner: false,
            title: 'CineTracker',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            themeAnimationDuration: const Duration(milliseconds: 450),
            themeAnimationCurve: Curves.easeInOutCubic,
            routes: {
              '/login': (_) => const LoginScreen(),
              '/main': (_) => const MainPage(),
            },
            home: isLoggedIn ? const MainPage() : const LoginScreen(),
          );
        },
      ),
    );
  }
}
