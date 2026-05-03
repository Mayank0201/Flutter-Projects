import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../service/social_service.dart';

class ChallengesPage extends StatefulWidget {
  const ChallengesPage({super.key});

  @override
  State<ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<ChallengesPage>
    with SingleTickerProviderStateMixin {
  final SocialService _service = SocialService();

  late TabController _tabController;

  List<Challenge> _dailyChallenges = [];
  List<Challenge> _quests = [];
  bool _isDailyLoading = true;
  bool _isQuestsLoading = true;
  String? _dailyError;
  String? _questsError;
  final Set<String> _claimingIds = {};

  String _getTimeUntilNextWeek() {
    final now = DateTime.now();
    final daysUntilSunday = 7 - now.weekday;
    if (daysUntilSunday == 0) return "Resets today";
    return "Resets in $daysUntilSunday days";
  }

  String _getTimeUntilNextMonth() {
    final now = DateTime.now();
    // Targeted June 1st as requested for the current monthly quests
    final targetDate = DateTime(2026, 6, 1);
    final daysLeft = targetDate.difference(now).inDays;
    
    if (daysLeft < 0) return "Quest period ended";
    if (daysLeft == 0) return "Resets today";
    return "Resets in $daysLeft days";
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    _loadDaily();
    _loadQuests();
  }

  Future<void> _loadDaily() async {
    setState(() {
      _isDailyLoading = true;
      _dailyError = null;
    });
    try {
      final list = await _service.getDailyChallenges();
      if (!mounted) return;
      setState(() {
        _dailyChallenges = list;
        _isDailyLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _dailyError = 'Could not load challenges.';
        _isDailyLoading = false;
      });
    }
  }

  Future<void> _loadQuests() async {
    setState(() {
      _isQuestsLoading = true;
      _questsError = null;
    });
    try {
      final list = await _service.getQuests();
      if (!mounted) return;
      setState(() {
        _quests = list;
        _isQuestsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _questsError = 'Could not load quests.';
        _isQuestsLoading = false;
      });
    }
  }

  Future<void> _claimQuest(Challenge quest) async {
    if (_claimingIds.contains(quest.id)) return;
    setState(() => _claimingIds.add(quest.id));

    try {
      final msg = await _service.claimQuest(quest.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadQuests();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to claim quest.')));
    } finally {
      if (mounted) setState(() => _claimingIds.remove(quest.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.emoji_events_rounded,
              color: colorScheme.primary,
              size: 22,
            ),
            const SizedBox(width: 8),
            const Text('Challenges'),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Weekly'),
            Tab(text: 'Monthly Quests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Daily Challenges ────────────────────────────────────────
          _buildDailyTab(theme, colorScheme),
          // ── Quests ──────────────────────────────────────────────────
          _buildQuestsTab(theme, colorScheme),
        ],
      ),
    );
  }

  Widget _buildDailyTab(ThemeData theme, ColorScheme colorScheme) {
    if (_isDailyLoading)
      return const Center(child: CircularProgressIndicator());
    if (_dailyError != null) {
      return _errorView(_dailyError!, _loadDaily, colorScheme);
    }

    return RefreshIndicator(
      onRefresh: _loadDaily,
      color: colorScheme.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary.withValues(alpha: 0.15),
                  colorScheme.primary.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(Iconsax.flash_15, size: 28, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weekly Challenges',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Complete tasks to earn XP. ${_getTimeUntilNextWeek()}!',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ..._dailyChallenges.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DailyChallengeCard(
                challenge: c,
                colorScheme: colorScheme,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestsTab(ThemeData theme, ColorScheme colorScheme) {
    if (_isQuestsLoading)
      return const Center(child: CircularProgressIndicator());
    if (_questsError != null) {
      return _errorView(_questsError!, _loadQuests, colorScheme);
    }

    return RefreshIndicator(
      onRefresh: _loadQuests,
      color: colorScheme.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFFB800).withValues(alpha: 0.15),
                  const Color(0xFFFFB800).withValues(alpha: 0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFFB800).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Iconsax.medal_star5,
                  size: 28,
                  color: Color(0xFFFFB800),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monthly Quests',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Long-term goals with badge rewards. ${_getTimeUntilNextMonth()}!',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ..._quests.map(
            (q) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _QuestCard(
                quest: q,
                isClaiming: _claimingIds.contains(q.id),
                onClaim: () => _claimQuest(q),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorView(String msg, VoidCallback retry, ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: cs.error.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 14),
          Text(msg),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ── Daily challenge card ───────────────────────────────────────────────────

class _DailyChallengeCard extends StatelessWidget {
  final Challenge challenge;
  final ColorScheme colorScheme;

  const _DailyChallengeCard({
    required this.challenge,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = challenge.isCompleted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: done
              ? Colors.green.withValues(alpha: 0.3)
              : colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          // Completion circle
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done
                  ? Colors.green.withValues(alpha: 0.12)
                  : colorScheme.primary.withValues(alpha: 0.08),
            ),
            child: Icon(
              done ? Iconsax.tick_circle : Iconsax.record,
              color: done ? Colors.green : colorScheme.onSurfaceVariant,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  challenge.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    decoration: done ? TextDecoration.lineThrough : null,
                    color: done ? colorScheme.onSurfaceVariant : null,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  challenge.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // XP pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB800).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFFB800).withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              '+${challenge.rewardXp} XP',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFD4A000),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quest card ─────────────────────────────────────────────────────────────

class _QuestCard extends StatelessWidget {
  final Challenge quest;
  final bool isClaiming;
  final VoidCallback onClaim;

  const _QuestCard({
    required this.quest,
    required this.isClaiming,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final totalRequired = quest.requiredMovieIds.length;
    final totalCompleted = quest.completedMovieIds.length;
    final progress = totalRequired > 0
        ? (totalCompleted / totalRequired).clamp(0.0, 1.0)
        : 0.0;

    final canClaim = quest.canClaim && !quest.isCompleted;
    final isDone = quest.isCompleted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDone
              ? Colors.green.withValues(alpha: 0.3)
              : canClaim
              ? const Color(0xFFFFB800).withValues(alpha: 0.4)
              : colorScheme.outline.withValues(alpha: 0.15),
        ),
        boxShadow: canClaim
            ? [
                BoxShadow(
                  color: const Color(0xFFFFB800).withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Icon(
                isDone
                    ? Iconsax.award5
                    : (canClaim ? Iconsax.star1 : Iconsax.gps),
                size: 24,
                color: isDone
                    ? Colors.green
                    : (canClaim
                          ? const Color(0xFFFFB800)
                          : colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  quest.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    color: isDone ? colorScheme.onSurfaceVariant : null,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB800).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '+${quest.rewardXp} XP',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFD4A000),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Text(
            quest.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),

          Builder(
            builder: (context) {
              final questMovies = {
                'Q_NOLAN':
                    'Interstellar, Inception, The Dark Knight, Memento, The Prestige',
                'Q_ROMCOM':
                    'When Harry Met Sally, Crazy Stupid Love, 10 Things I Hate About You, Love Actually, Notting Hill',
                'Q_HORROR':
                    'The Exorcist, The Shining, Halloween, The Texas Chain Saw Massacre, A Nightmare on Elm Street',
              };
              final moviesText = questMovies[quest.id];
              if (moviesText != null) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Required: $moviesText',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary.withValues(alpha: 0.8),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          if (quest.badgeName != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.star_rounded, size: 14, color: colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  'Reward: ${quest.badgeName} badge',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],

          // Progress bar (only for quests with movie requirements)
          if (totalRequired > 0) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progress',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '$totalCompleted / $totalRequired movies',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDone ? Colors.green : colorScheme.primary,
                ),
              ),
            ),
          ],

          // Claim button
          if (!isDone) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canClaim && !isClaiming ? onClaim : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canClaim
                      ? const Color(0xFFFFB800)
                      : colorScheme.surfaceContainerHighest,
                  foregroundColor: canClaim
                      ? Colors.black87
                      : colorScheme.onSurfaceVariant,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: isClaiming
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black54,
                        ),
                      )
                    : Text(
                        canClaim ? '🎉  Claim Reward' : 'Keep Watching…',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  'Completed!',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
