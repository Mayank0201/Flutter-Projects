import 'package:flutter/material.dart' hide Badge;
import '../../../model/user_profile_model.dart';
import '../../../model/review_model.dart';
import '../../../model/badge_model.dart';
import '../../../service/social_service.dart';
import '../../../service/tmdb_service.dart';
import 'movie_details_page.dart';
import 'movie_reviews_page.dart';

class UserProfilePage extends StatefulWidget {
  final int userId;
  final String? preloadedUsername;

  const UserProfilePage({
    super.key,
    required this.userId,
    this.preloadedUsername,
  });

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final SocialService _socialService = SocialService();

  UserProfile? _profile;
  bool _isLoading = true;
  String? _error;
  bool _isFollowLoading = false;

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
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load profile.';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (_profile == null || _isFollowLoading) return;
    setState(() => _isFollowLoading = true);
    try {
      if (_profile!.isFollowing) {
        await _socialService.unfollowUser(widget.userId);
      } else {
        await _socialService.followUser(widget.userId);
      }
      // Reload to get fresh counts + isFollowing flag
      await _loadProfile();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Action failed. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _isFollowLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.preloadedUsername ?? _profile?.username ?? 'Profile'),
      ),
      body: _buildBody(theme, colorScheme),
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme colorScheme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _profile == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off_outlined,
                size: 56, color: colorScheme.error.withValues(alpha: 0.5)),
            const SizedBox(height: 14),
            Text(_error ?? 'Profile not found',
                style: theme.textTheme.bodyLarge),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadProfile,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final p = _profile!;

    return RefreshIndicator(
      onRefresh: _loadProfile,
      color: colorScheme.primary,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          // ── Avatar + username ──────────────────────────────────────
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    p.username.isNotEmpty ? p.username[0].toUpperCase() : 'U',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  p.username,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),

                // Level badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary,
                        colorScheme.primary.withValues(alpha: 0.75),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.military_tech_rounded,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Level ${p.level}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Follow button
                ElevatedButton.icon(
                  onPressed: _isFollowLoading ? null : _toggleFollow,
                  icon: _isFollowLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Icon(p.isFollowing
                          ? Icons.person_remove_rounded
                          : Icons.person_add_rounded,
                          size: 18),
                  label: Text(p.isFollowing ? 'Unfollow' : 'Follow'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: p.isFollowing
                        ? colorScheme.surfaceContainerHighest
                        : colorScheme.primary,
                    foregroundColor: p.isFollowing
                        ? colorScheme.onSurface
                        : colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Stats row ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _StatBox(label: 'XP', value: '${p.xp}'),
                _divider(),
                _StatBox(
                    label: 'Followers', value: '${p.followerCount}'),
                _divider(),
                _StatBox(
                    label: 'Following', value: '${p.followingCount}'),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── XP progress bar ────────────────────────────────────────
          if (p.level > 0) _XpProgressSection(xp: p.xp, level: p.level),

          const SizedBox(height: 24),

          // ── Badges ─────────────────────────────────────────────────
          if (p.badges.isNotEmpty) ...[
            _SectionHeader(title: 'Badges (${p.badges.length})'),
            _BadgesRow(badges: p.badges),
            const SizedBox(height: 20),
          ],

          // ── Recent reviews ─────────────────────────────────────────
          if (p.reviews.isNotEmpty) ...[
            _SectionHeader(title: 'Recent Reviews'),
            ...p.reviews.take(5).map((r) => _ReviewItem(review: r)),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'No reviews yet.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
      );
}

// ── Stat box ───────────────────────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  final String label;
  final String value;

  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── XP Progress section ────────────────────────────────────────────────────

class _XpProgressSection extends StatelessWidget {
  final int xp;
  final int level;

  const _XpProgressSection({required this.xp, required this.level});

  /// Dynamic leveling formula: 50 * L * (L-1)  (matches backend)
  int _xpForLevel(int l) => 50 * l * (l - 1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final currentLevelXp = _xpForLevel(level);
    final nextLevelXp = _xpForLevel(level + 1);
    final xpInLevel = xp - currentLevelXp;
    final xpNeeded = nextLevelXp - currentLevelXp;
    final progress = xpNeeded > 0 ? (xpInLevel / xpNeeded).clamp(0.0, 1.0) : 1.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Level $level → ${level + 1}',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '$xp XP',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
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
            const SizedBox(height: 6),
            Text(
              '$xpInLevel / $xpNeeded XP to next level',
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

// ── Badges row ─────────────────────────────────────────────────────────────

class _BadgesRow extends StatelessWidget {
  final List<Badge> badges;

  const _BadgesRow({required this.badges});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: badges.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final badge = badges[i];
          return Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primaryContainer,
                ),
                child: badge.iconUrl.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          badge.iconUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.star_rounded, size: 26),
                        ),
                      )
                    : Icon(
                        Icons.star_rounded,
                        color: colorScheme.onPrimaryContainer,
                        size: 26,
                      ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 60,
                child: Text(
                  badge.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          );
        },
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
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MovieReviewsPage(
                    movieId: review.movieId,
                    movieTitle: review.movieTitle ?? 'Movie',
                  ),
                ),
              );
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
