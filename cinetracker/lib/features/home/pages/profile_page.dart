import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cinetracker/core/storage/token_storage.dart';
import 'package:cinetracker/core/network/api_service.dart';
import 'package:cinetracker/service/tmdb_service.dart';
import '../../../provider/wishlist_provider.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'credits_page.dart';
import 'wishlist_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _username = "User";
  String _nickname = "Movie Enthusiast";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final storage = TokenStorage();
    final token = await storage.getAccessToken();
    
    String decodedUsername = "User";
    if (token != null && token.isNotEmpty) {
      try {
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload = parts[1];
          final normalized = base64Url.normalize(payload);
          final resp = utf8.decode(base64Url.decode(normalized));
          final decoded = json.decode(resp);
          decodedUsername = decoded['sub']?.toString() ?? "User";
        }
      } catch (e) {
        debugPrint("Error decoding token: $e");
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final savedNickname = prefs.getString('user_nickname');

    if (mounted) {
      setState(() {
        _username = decodedUsername;
        if (savedNickname != null && savedNickname.isNotEmpty) {
          _nickname = savedNickname;
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _editNickname() async {
    final controller = TextEditingController(text: _nickname);
    final newNickname = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Nickname"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "Enter new nickname",
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text("Save"),
          ),
        ],
      ),
    );

    if (newNickname != null && newNickname.isNotEmpty && newNickname != _nickname) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_nickname', newNickname);
      if (mounted) {
        setState(() {
          _nickname = newNickname;
        });
      }
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final apiService = ApiService();
    final tmdbService = TMDBService();
    final storage = TokenStorage();

    context.read<WishlistProvider>().resetForLogout();
    apiService.clearToken();
    tmdbService.clearToken();
    await storage.clearTokens();

    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          // user avatar placeholder
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                  child: _isLoading 
                    ? const CircularProgressIndicator()
                    : Text(
                        _username.isNotEmpty ? _username[0].toUpperCase() : "U",
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                ),
                const SizedBox(height: 16),
                _isLoading 
                  ? const SizedBox(height: 28, width: 28, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(
                      _username,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                const SizedBox(height: 4),
                _isLoading
                  ? const SizedBox.shrink()
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _nickname,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: _editNickname,
                          child: Icon(
                            Icons.edit_rounded,
                            size: 16,
                            color: colorScheme.primary.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          _buildSectionHeader(context, "Account"),
          _buildListTile(
            context,
            icon: Icons.favorite_rounded,
            title: "Watchlist",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WishlistPage()),
              );
            },
          ),

          const SizedBox(height: 20),

          _buildSectionHeader(context, "App"),
          _buildListTile(
            context,
            icon: Icons.info_outline_rounded,
            title: "Credits",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreditsPage()),
              );
            },
          ),
          _buildListTile(
            context,
            icon: Icons.logout_rounded,
            title: "Logout",
            textColor: colorScheme.error,
            onTap: () => _showLogoutDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: Icon(icon, color: textColor ?? Theme.of(context).colorScheme.onSurfaceVariant),
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: onTap,
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleLogout(context);
            },
            child: Text(
              "Logout",
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
