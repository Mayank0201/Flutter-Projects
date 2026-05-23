import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../service/social_service.dart';
import '../../../model/user_profile_model.dart';
import '../../../model/badge_model.dart' as app_badge;
import '../../../model/review_model.dart';
import '../../../service/tmdb_service.dart';
import 'movie_details_page.dart';

class PublicProfilePage extends StatefulWidget {
  final int userId;
  final String username;

  const PublicProfilePage({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  final SocialService _socialService = SocialService();
  UserProfile? _profile;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final profile = await _socialService.getUserProfile(widget.userId);
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load profile.';
          _isLoading = false;
        });
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.username),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: colorScheme.error)))
              : _profile == null
                  ? const Center(child: Text('Profile not found'))
                  : RefreshIndicator(
                      onRefresh: _loadProfile,
                      color: colorScheme.primary,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        children: [
                          // ── Avatar + username ───────────────────
                          Center(
                            child: Column(
                              children: [
                                Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    CircleAvatar(
                                      radius: 50,
                                      backgroundColor: colorScheme.primaryContainer,
                                      child: Text(
                                        widget.username.isNotEmpty
                                            ? widget.username[0].toUpperCase()
                                            : 'U',
                                        style: TextStyle(
                                          fontSize: 40,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
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
                                  widget.username,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // ── XP & Stats ─────────────────────────────────────
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: _XpProgressCard(profile: _profile!),
                          ),
                          const SizedBox(height: 16),
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
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () async {
                                  final isFollowing = _profile!.isFollowing;
                                  try {
                                    if (isFollowing) {
                                      await _socialService.unfollowUser(widget.userId);
                                    } else {
                                      await _socialService.followUser(widget.userId);
                                    }
                                    await _loadProfile();
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Failed to update follow status')),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _profile!.isFollowing 
                                    ? colorScheme.surfaceContainerHighest
                                    : colorScheme.primary,
                                  foregroundColor: _profile!.isFollowing
                                    ? colorScheme.onSurfaceVariant
                                    : colorScheme.onPrimary,
                                ),
                                child: Text(_profile!.isFollowing ? 'Unfollow' : 'Follow'),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_profile!.badges.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                              child: Text(
                                'BADGES',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
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
                                separatorBuilder: (_, _) => const SizedBox(width: 12),
                                itemBuilder: (_, i) {
                                  final app_badge.Badge badge = _profile!.badges[i];
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
                                              colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
                                              colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                            ],
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFFFB800).withValues(alpha: 0.4),
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFFFFB800).withValues(alpha: 0.1),
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
                                                  errorBuilder: (_, __, ___) => _buildBadgeIcon(badge.name),
                                                )
                                              : _buildBadgeIcon(badge.name),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        badge.name,
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.onSurface.withValues(alpha: 0.8),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          // ── Recent reviews ─────────────────────────────────
                          const _SectionHeader(title: 'Recent Reviews'),
                          if (_profile!.reviews.isNotEmpty) ...[
                            ..._profile!.reviews.take(5).map((r) => _ReviewItem(review: r)),
                          ] else
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                              child: Text(
                                'No reviews yet.',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: colorScheme.onSurfaceVariant),
                              ),
                            ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
    );
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
    final progress =
        xpNeeded > 0 ? (xpInLevel / xpNeeded).clamp(0.0, 1.0) : 1.0;

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
        border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.military_tech_rounded,
                      color: colorScheme.primary, size: 20),
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
                    color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor:
                  colorScheme.primary.withValues(alpha: 0.12),
              valueColor:
                  AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$xpInLevel / $xpNeeded XP to Level ${profile.level + 1}',
                style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant),
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
              color: colorScheme.outline.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
      ),
    );
  }
}

// ── Review item ────────────────────────────────────────────────────────────

class _ReviewItem extends StatelessWidget {
  final Review review;

  const _ReviewItem({required this.review});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hasMovieInfo = review.movieTitle != null && review.movieTitle!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              try {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator()),
                );
                final movie = await TMDBService().getMovieDetails(review.movieId);
                if (!context.mounted) return;
                Navigator.pop(context); // pop loading dialog
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MovieDetailsPage(movie: movie)),
                );
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context); // pop loading dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not load movie details')),
                  );
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasMovieInfo) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: review.moviePosterUrl != null && review.moviePosterUrl!.isNotEmpty
                          ? Image.network(
                              review.moviePosterUrl!,
                              width: 60,
                              height: 90,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildPosterPlaceholder(colorScheme),
                            )
                          : _buildPosterPlaceholder(colorScheme),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasMovieInfo) ...[
                          Text(
                            review.movieTitle!,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (review.movieReleaseYear != null) ...[
                                Text(
                                  '${review.movieReleaseYear}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              if (review.movieGenre != null && review.movieGenre!.isNotEmpty)
                                Expanded(
                                  child: Text(
                                    review.movieGenre!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                        Row(
                          children: [
                            ...List.generate(5, (i) {
                              final filled = review.rating >= i + 1;
                              return Icon(
                                filled ? Icons.star_rounded : Icons.star_outline_rounded,
                                size: 14,
                                color: filled
                                    ? const Color(0xFFFFB800)
                                    : colorScheme.onSurface.withValues(alpha: 0.2),
                              );
                            }),
                            const SizedBox(width: 6),
                            Text(
                              review.rating.toStringAsFixed(1),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (review.comment != null && review.comment!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            review.comment!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPosterPlaceholder(ColorScheme cs) {
    return Container(
      width: 60,
      height: 90,
      color: cs.surfaceContainerHighest,
      child: const Icon(Icons.movie_rounded, size: 24),
    );
  }
}

