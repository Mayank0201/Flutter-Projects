import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/achievement_manager.dart';
import '../theme/app_theme.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  String _selectedCategory = 'All';
  List<String> _unlockedIds = [];
  List<String> _claimedIds = [];
  Map<String, double> _progressMap = {};
  bool _loading = true;

  final List<String> _categories = [
    'All',
    'Milestone',
    'Exploration',
    'Mastery',
    'Streak',
    'Special',
  ];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    await AchievementManager.checkAndUnlock('');
    final unlocked = await AchievementManager.getUnlockedIds();
    final claimed = await AchievementManager.getClaimedIds();
    final Map<String, double> progress = {};
    for (final a in AchievementManager.allAchievements) {
      progress[a.id] = await AchievementManager.getProgress(a);
    }

    if (mounted) {
      setState(() {
        _unlockedIds = unlocked;
        _claimedIds = claimed;
        _progressMap = progress;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalCount = AchievementManager.allAchievements.length;
    final unlockedCount = _unlockedIds.length;
    final overallPct = totalCount == 0 ? 0.0 : unlockedCount / totalCount;

    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        backgroundColor: context.bgDark,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Achievements',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: context.scale(18),
            color: context.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: context.textPrimary,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Completion stats header card
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: AppTheme.zenCard(context),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Grand Completion',
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: context.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$unlockedCount of $totalCount Unlocked',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: context.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${(overallPct * 100).toInt()}%',
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.dustyMauve,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Premium thin progress line
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: overallPct,
                            minHeight: 3,
                            backgroundColor: isDark ? Colors.white10 : Colors.black12,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppTheme.dustyMauve,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Category Chips scrolling list
                SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(
                            cat,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : context.textSecondary,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedCategory = cat;
                              });
                            }
                          },
                          selectedColor: AppTheme.dustyMauve,
                          backgroundColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(
                              color: isSelected
                                  ? Colors.transparent
                                  : (isDark ? Colors.white12 : Colors.black12),
                              width: 0.5,
                            ),
                          ),
                          showCheckmark: false,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Grid/List of achievements
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildAchievementsList(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAchievementsList() {
    final filtered = AchievementManager.allAchievements.where((a) {
      if (_selectedCategory == 'All') return true;
      return a.category.toLowerCase() == _selectedCategory.toLowerCase();
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.hourglass_empty_rounded,
              size: 40,
              color: context.textSecondary.withAlpha(80),
            ),
            const SizedBox(height: 12),
            Text(
              'No achievements found',
              style: GoogleFonts.outfit(
                color: context.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      key: ValueKey<String>(_selectedCategory),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final a = filtered[index];
        final isUnlocked = _unlockedIds.contains(a.id);
        final progress = _progressMap[a.id] ?? 0.0;
        return _buildAchievementCard(a, isUnlocked, progress);
      },
    );
  }

  Widget _buildAchievementCard(Achievement a, bool isUnlocked, double progress) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isClaimed = _claimedIds.contains(a.id);
    final canClaim = isUnlocked && !isClaimed;

    Widget cardContent = Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.zenCard(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Achievement Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isUnlocked
                  ? AppTheme.dustyMauve.withAlpha(20)
                  : (isDark ? Colors.white10 : Colors.black12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isUnlocked
                  ? Text(
                      a.icon,
                      style: const TextStyle(fontSize: 24),
                    )
                  : Icon(
                      Icons.lock_outline_rounded,
                      size: 20,
                      color: context.textSecondary.withAlpha(150),
                    ),
            ),
          ),
          const SizedBox(width: 16),

          // Middle: Name, description & progress bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  a.name,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  a.description,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: context.textSecondary,
                  ),
                ),
                if (!isUnlocked && progress > 0.0 && progress < 1.0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(1),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 2,
                            backgroundColor: isDark ? Colors.white10 : Colors.black12,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppTheme.dustyMauve,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Right: Claim button or Rewards badge
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isUnlocked) ...[
                if (isClaimed) ...[
                  // Claimed State
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline, color: AppTheme.softSage, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Claimed',
                        style: GoogleFonts.outfit(
                          color: AppTheme.softSage,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Unlocked but unclaimed state: show Claim button + reward hint
                  if (a.rewardPoints > 0) ...[
                    Text(
                      '+${a.rewardPoints} IQ',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.dustyMauve,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  ElevatedButton(
                    onPressed: () async {
                      final success = await AchievementManager.claim(a.id);
                      if (success) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Claimed reward: ${a.name}!',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                              ),
                              backgroundColor: AppTheme.softSage,
                            ),
                          );
                          _loadStats();
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.dustyMauve,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Claim',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ] else ...[
                // Locked State: show prospective rewards
                if (a.rewardPoints > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.dustyMauve.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.dustyMauve.withAlpha(50), width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.monetization_on_rounded,
                          size: 10,
                          color: AppTheme.dustyMauve,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '+${a.rewardPoints}',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.dustyMauve,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (a.rewardTitle != null || a.rewardTrailStyle != null) ...[
                  if (a.rewardPoints > 0) const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.dustyMauve.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.dustyMauve.withAlpha(50), width: 0.5),
                    ),
                    child: Text(
                      a.rewardTitle ?? 'Cosmetic',
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.dustyMauve,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ],
      ),
    );

    if (canClaim) {
      cardContent = InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          final success = await AchievementManager.claim(a.id);
          if (success) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Claimed reward: ${a.name}!',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: AppTheme.softSage,
                ),
              );
              _loadStats();
            }
          }
        },
        child: cardContent,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: isUnlocked ? 1.0 : 0.65,
        child: cardContent,
      ),
    );
  }
}
