import 'package:cinetracker/core/storage/token_storage.dart';
import 'package:cinetracker/features/home/pages/main_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../service/auth_service.dart';
import '../../../core/network/api_service.dart';
import '../../../provider/wishlist_provider.dart';
import '../../../service/tmdb_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  final storage = TokenStorage();

  final apiService = ApiService();
  final tmdbService = TMDBService();
  late final AuthService authService;

  @override
  void initState() {
    super.initState();
    authService = AuthService(apiService);
  }

  void login() async {
    try {
      final token = await authService.login(
        usernameController.text,
        passwordController.text,
      );
      apiService.setToken(token);
      tmdbService.setToken(token);
      await storage.saveToken(token);
      await context.read<WishlistProvider>().loadWatchlist();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainPage()),
      );
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Login failed")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(labelText: "Username"),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: login, child: const Text("Login")),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RegisterScreen(),
                  ),
                );
              },
              child: const Text("Don't have an account? Register"),
            ),
          ],
        ),
      ),
    );
  }
}
