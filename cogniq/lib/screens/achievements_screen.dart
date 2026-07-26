import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/achievement_manager.dart';
import '../theme/app_theme.dart';

class AchievementsScreen extends StatefulWidget {
  final String? highlightId;
  const AchievementsScreen({super.key, this.highlightId});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  String _selectedCategory = 'All';
  List<String> _unlockedIds = [];
  List<String> _claimedIds = [];
  Map<String, double> _progressMap = {};
  bool _loading = true;
  final ScrollController _scrollController = ScrollController();

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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    await AchievementManager.checkAndUnlock('');
    final unlocked = await AchievementManager.getUnlockedIds();
    final claimed = await AchievementManager.getClaimedIds();
    final Map<String, double> progress = {};
    for (final a in AchievementManager.allAchievements) {
      progress[a.id] = await AchievementManager.getProgress(a);
    }

    if (widget.highlightId != null) {
      Achievement? a;
      for (final ach in AchievementManager.allAchievements) {
        if (ach.id == widget.highlightId) {
          a = ach;
          break;
        }
      }
      if (a != null) {
        String matchingCategory = 'All';
        for (final c in _categories) {
          if (c.toLowerCase() == a.category.toLowerCase()) {
            matchingCategory = c;
            break;
          }
        }
        _selectedCategory = matchingCategory;
      }
    }

    if (mounted) {
      setState(() {
        _unlockedIds = unlocked;
        _claimedIds = claimed;
        _progressMap = progress;
        _loading = false;
      });

      if (widget.highlightId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final filtered = AchievementManager.allAchievements.where((a) {
            if (_selectedCategory == 'All') return true;
            return a.category.toLowerCase() == _selectedCategory.toLowerCase();
          }).toList();
          final index = filtered.indexWhere((x) => x.id == widget.highlightId);
          if (index != -1) {
            double offset = index * 105.0; // approximate card heights
            _scrollController.animateTo(
              offset,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOutCubic,
            );
          }
        });
      }
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
                    itemCount: _categories.length,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            cat,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.white : context.textPrimary,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: AppTheme.dustyMauve,
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          selectedShadowColor: Colors.transparent,
                          elevation: 0,
                          pressElevation: 0,
                          checkmarkColor: Colors.transparent,
                          showCheckmark: false,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: isSelected ? AppTheme.dustyMauve : context.textMuted.withAlpha(40),
                              width: 0.8,
                            ),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedCategory = cat;
                              });
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Grid/List of achievements
                Expanded(
                  child: _buildAchievementsList(),
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
      controller: _scrollController,
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
    final isHighlight = widget.highlightId == a.id;

    Widget cardContent = Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.zenCard(context).copyWith(
        border: Border.all(
          color: isHighlight
              ? Colors.amber
              : context.textMuted.withAlpha(30),
          width: isHighlight ? 2.0 : 0.5,
        ),
      ),
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
                  // Unlocked but unclaimed state
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
                          if (a.rewardTitle != null) {
                            AchievementManager.titleClaimedNotifier.value = a.rewardTitle;
                            Navigator.of(context).pop();
                          }
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
                // Locked State
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
                if (a.rewardTitle != null) ...[
                  if (a.rewardPoints > 0) const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.dustyMauve.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.dustyMauve.withAlpha(50), width: 0.5),
                    ),
                    child: Text(
                      a.rewardTitle!,
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
              if (a.rewardTitle != null) {
                AchievementManager.titleClaimedNotifier.value = a.rewardTitle;
                Navigator.of(context).pop();
              }
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
