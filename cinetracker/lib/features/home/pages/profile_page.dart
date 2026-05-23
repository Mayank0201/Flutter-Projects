import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cinetracker/core/storage/token_storage.dart';
import 'package:cinetracker/core/network/api_service.dart';
import 'package:cinetracker/service/tmdb_service.dart';
import 'package:cinetracker/service/social_service.dart';
import '../../../provider/wishlist_provider.dart';
import '../../../model/user_profile_model.dart';
import 'credits_page.dart';
import 'package:cinetracker/core/utils/content_moderator.dart';
import 'wishlist_page.dart';
import 'challenges_page.dart';
import 'my_reviews_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final SocialService _socialService = SocialService();

  String _username = 'User';
  String _nickname = 'Movie Enthusiast';

  UserProfile? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
    });

    final storage = TokenStorage();
    final token = await storage.getAccessToken();

    String decodedUsername = 'User';
    int? decodedUserId;

    if (token != null && token.isNotEmpty) {
      try {
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload = parts[1];
          final normalized = base64Url.normalize(payload);
          final resp = utf8.decode(base64Url.decode(normalized));
          final decoded = json.decode(resp) as Map<String, dynamic>;
          decodedUsername = decoded['sub']?.toString() ?? 'User';
          // JWT sub is username; userId may be in 'userId' claim
          decodedUserId = (decoded['userId'] as num?)?.toInt();
        }
      } catch (e) {
        debugPrint('Error decoding token: $e');
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final savedNickname = prefs.getString('user_nickname');

    // Try to load the backend profile for XP/level/badges
    UserProfile? profile;
    if (decodedUserId != null) {
      try {
        profile = await _socialService.getUserProfile(decodedUserId);
      } catch (_) {
        // Silently ignore — profile section will show loading fallback
      }
    }

    if (mounted) {
      setState(() {
        _username = decodedUsername;
        _profile = profile;
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
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            String? errorText;
            return AlertDialog(
              title: const Text('Edit Nickname'),
              content: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Enter new nickname',
                  errorText: errorText,
                ),
                autofocus: true,
                onChanged: (val) {
                  setDialogState(
                    () => errorText = ContentModerator.validateUsername(val),
                  );
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final validationError = ContentModerator.validateUsername(
                      controller.text.trim(),
                    );
                    if (validationError != null) {
                      setDialogState(() => errorText = validationError);
                      // Use the page's context to show the snackbar
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(validationError)),
                      );
                    } else {
                      Navigator.pop(dialogContext, controller.text.trim());
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (newNickname != null &&
        newNickname.isNotEmpty &&
        newNickname != _nickname) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_nickname', newNickname);
      if (mounted) setState(() => _nickname = newNickname);
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
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Refresh',
            onPressed: _loadProfile,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfile,
              color: colorScheme.primary,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 20),
                children: [
                  // ── Avatar + username + nickname ───────────────────
                  Center(
                    child: Column(
                      children: [
                        // Avatar with level ring
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: colorScheme.primaryContainer,
                              child: Text(
                                _username.isNotEmpty
                                    ? _username[0].toUpperCase()
                                    : 'U',
                                style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            if (_profile != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Lv ${_profile!.level}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _username,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
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
                                color: colorScheme.primary.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── XP & Stats ─────────────────────────────────────
                  if (_profile != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _XpProgressCard(profile: _profile!),
                    ),
                    const SizedBox(height: 16),

                    // Follower stats
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          _StatChip(
                            label: 'Followers',
                            value: '${_profile!.followerCount}',
                            icon: Icons.people_rounded,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          _StatChip(
                            label: 'Following',
                            value: '${_profile!.followingCount}',
                            icon: Icons.person_add_rounded,
                            color: colorScheme.secondary,
                          ),
                          const SizedBox(width: 12),
                          _StatChip(
                            label: 'Badges',
                            value: '${_profile!.badges.length}',
                            icon: Icons.military_tech_rounded,
                            color: const Color(0xFFFFB800),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (_profile!.badges.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                        child: Text(
                          'MY BADGES',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 100,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _profile!.badges.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 14),
                          itemBuilder: (context, index) {
                            final badge = _profile!.badges[index];
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        colorScheme.surfaceContainerHighest
                                            .withValues(alpha: 0.8),
                                        colorScheme.surfaceContainerHighest
                                            .withValues(alpha: 0.4),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: const Color(
                                        0xFFFFB800,
                                      ).withValues(alpha: 0.4),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFFFFB800,
                                        ).withValues(alpha: 0.1),
                                        blurRadius: 10,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: badge.iconUrl.isNotEmpty
                                        ? Image.network(
                                            badge.iconUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                _buildBadgeIcon(badge.name),
                                          )
                                        : _buildBadgeIcon(badge.name),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  badge.name,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.8,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],

                  // ── Account section ────────────────────────────────
                  _buildSectionHeader(context, 'Account'),
                  _buildListTile(
                    context,
                    icon: Icons.bookmark_rounded,
                    title: 'Watchlist',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const WishlistPage()),
                    ),
                  ),
                  _buildListTile(
                    context,
                    icon: Icons.rate_review_rounded,
                    title: 'My Reviews',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MyReviewsPage()),
                    ),
                  ),
                  _buildListTile(
                    context,
                    icon: Icons.emoji_events_rounded,
                    title: 'Challenges & Quests',
                    trailing: _profile != null
                        ? _buildXpBadge('${_profile!.xp} XP', colorScheme)
                        : null,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChallengesPage()),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── App section ────────────────────────────────────
                  _buildSectionHeader(context, 'App'),
                  _buildListTile(
                    context,
                    icon: Icons.info_outline_rounded,
                    title: 'Credits',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CreditsPage()),
                    ),
                  ),
                  _buildListTile(
                    context,
                    icon: Icons.logout_rounded,
                    title: 'Logout',
                    textColor: colorScheme.error,
                    onTap: () => _showLogoutDialog(context),
                  ),
                ],
              ),
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
    Widget? trailing,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: Icon(
        icon,
        color: textColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(
        title,
        style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: onTap,
    );
  }

  Widget _buildXpBadge(String text, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB800).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFFD4A000),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleLogout(context);
            },
            child: Text(
              'Logout',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

// ── XP Progress card ───────────────────────────────────────────────────────

class _XpProgressCard extends StatelessWidget {
  final UserProfile profile;

  const _XpProgressCard({required this.profile});

  int _xpForLevel(int l) => 50 * l * (l - 1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final currentLevelXp = _xpForLevel(profile.level);
    final nextLevelXp = _xpForLevel(profile.level + 1);
    final xpInLevel = profile.xp - currentLevelXp;
    final xpNeeded = nextLevelXp - currentLevelXp;
    final progress = xpNeeded > 0
        ? (xpInLevel / xpNeeded).clamp(0.0, 1.0)
        : 1.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withValues(alpha: 0.12),
            colorScheme.primary.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.military_tech_rounded,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Level ${profile.level}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
              Text(
                '${profile.xp} XP total',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$xpInLevel / $xpNeeded XP to Level ${profile.level + 1}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Stat chip ──────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildBadgeIcon(String badgeName) {
  IconData icon;
  Color color = const Color(0xFFFFB800);

  switch (badgeName) {
    case 'Time Bender':
      icon = Iconsax.timer_1;
      break;
    case 'Heart-Throb':
      icon = Iconsax.heart5;
      color = Colors.pinkAccent;
      break;
    case 'Fearless':
      icon = Iconsax.shield_security;
      color = Colors.deepOrange;
      break;
    default:
      icon = Iconsax.award;
  }

  return Icon(icon, color: color.withValues(alpha: 0.9), size: 30);
}
