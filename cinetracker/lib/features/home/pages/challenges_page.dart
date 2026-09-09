import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../service/social_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/poster_image.dart';

// two lists off the same dto: weekly challenges just show where you are, quests
// hand out a badge once you claim them
class ChallengesPage extends StatefulWidget {
  const ChallengesPage({super.key});

  @override
  State<ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<ChallengesPage>
    with SingleTickerProviderStateMixin {
  final SocialService _service = SocialService();

  late final TabController _tabController =
      TabController(length: 2, vsync: this);

  List<Challenge> _challenges = [];
  List<Challenge> _quests = [];
  bool _loadingChallenges = true;
  bool _loadingQuests = true;
  bool _challengesFailed = false;
  bool _questsFailed = false;
  final Set<String> _claiming = {};

  @override
  void initState() {
    super.initState();
    _loadChallenges();
    _loadQuests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadChallenges() async {
    setState(() {
      _loadingChallenges = true;
      _challengesFailed = false;
    });
    try {
      final list = await _service.getDailyChallenges();
      if (!mounted) return;
      setState(() {
        _challenges = list;
        _loadingChallenges = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _challengesFailed = true;
        _loadingChallenges = false;
      });
    }
  }

  Future<void> _loadQuests() async {
    setState(() {
      _loadingQuests = true;
      _questsFailed = false;
    });
    try {
      final list = await _service.getQuests();
      if (!mounted) return;
      setState(() {
        _quests = list;
        _loadingQuests = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _questsFailed = true;
        _loadingQuests = false;
      });
    }
  }

  Future<void> _claimQuest(Challenge quest) => _claim(
        key: 'quest-${quest.id}',
        send: () => _service.claimQuest(quest.id),
        reload: _loadQuests,
      );

  Future<void> _claimChallenge(Challenge challenge) => _claim(
        key: 'challenge-${challenge.id}',
        send: () => _service.claimChallenge(challenge.id),
        reload: _loadChallenges,
      );

  // ids only have to be unique inside their own tab, so the key is prefixed
  Future<void> _claim({
    required String key,
    required Future<String> Function() send,
    required Future<void> Function() reload,
  }) async {
    if (_claiming.contains(key)) return;
    setState(() => _claiming.add(key));
    try {
      final message = await send();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      await reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not claim that one')),
      );
    } finally {
      if (mounted) setState(() => _claiming.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Challenges'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'This week'),
            Tab(text: 'Quests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChallenges(),
          _buildQuests(),
        ],
      ),
    );
  }

  Widget _buildChallenges() {
    if (_loadingChallenges) return const _LoadingList();
    if (_challengesFailed) {
      return EmptyState(
        icon: Iconsax.flash_1,
        title: 'Could not load challenges',
        actionLabel: 'Retry',
        onAction: _loadChallenges,
      );
    }
    if (_challenges.isEmpty) {
      return const EmptyState(
        icon: Iconsax.flash_1,
        title: 'Nothing to do this week',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadChallenges,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: _challenges.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == 0) {
            return const _SectionNote('Counted over your last seven days');
          }
          final challenge = _challenges[index - 1];
          return _ChallengeTile(
            challenge: challenge,
            isClaiming: _claiming.contains('challenge-${challenge.id}'),
            onClaim: () => _claimChallenge(challenge),
          );
        },
      ),
    );
  }

  Widget _buildQuests() {
    if (_loadingQuests) return const _LoadingList();
    if (_questsFailed) {
      return EmptyState(
        icon: Iconsax.medal,
        title: 'Could not load quests',
        actionLabel: 'Retry',
        onAction: _loadQuests,
      );
    }
    if (_quests.isEmpty) {
      return const EmptyState(icon: Iconsax.medal, title: 'Nothing yet');
    }

    return RefreshIndicator(
      onRefresh: _loadQuests,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: _quests.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == 0) {
            return const _SectionNote('Lifetime milestones, each claimed once');
          }
          final quest = _quests[index - 1];
          return _QuestTile(
            quest: quest,
            isClaiming: _claiming.contains('quest-${quest.id}'),
            onClaim: () => _claimQuest(quest),
          );
        },
      ),
    );
  }
}

// one line of context above each list, quieter than a banner
class _SectionNote extends StatelessWidget {
  final String text;

  const _SectionNote(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) =>
          const SkeletonBox(width: double.infinity, height: 96, radius: 12),
    );
  }
}

// shared frame so a challenge and a quest sit at the same weight in the list
class _Card extends StatelessWidget {
  final Widget child;
  final bool highlight;

  const _Card({required this.child, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight ? cs.primary.withValues(alpha: 0.5) : cs.outline,
          width: highlight ? 1.2 : 0.8,
        ),
      ),
      child: child,
    );
  }
}

class _XpLabel extends StatelessWidget {
  final int xp;
  final bool muted;

  const _XpLabel({required this.xp, this.muted = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Text(
      '$xp XP',
      style: theme.textTheme.labelMedium?.copyWith(
        color: muted ? cs.onSurfaceVariant : cs.primary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// bar plus the raw numbers, so a row reads at a glance and on a second look
class _ProgressRow extends StatelessWidget {
  final Challenge item;

  const _ProgressRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: item.fraction,
            minHeight: 5,
            backgroundColor: cs.onSurfaceVariant.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${item.progress} of ${item.target}',
          style: theme.textTheme.labelSmall,
        ),
      ],
    );
  }
}

class _ChallengeTile extends StatelessWidget {
  final Challenge challenge;
  final bool isClaiming;
  final VoidCallback onClaim;

  const _ChallengeTile({
    required this.challenge,
    required this.isClaiming,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // completed now means claimed, so the xp is only owed while canClaim holds
    final done = challenge.isCompleted;
    final ready = challenge.canClaim && !done;

    return _Card(
      highlight: ready,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                done ? Iconsax.tick_circle : Iconsax.record,
                size: 18,
                color: done ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  challenge.title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              _XpLabel(xp: challenge.rewardXp, muted: done),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            challenge.description,
            style:
                theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          _ProgressRow(item: challenge),
          if (ready) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isClaiming ? null : onClaim,
                child: isClaiming
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.onPrimary,
                        ),
                      )
                    : const Text('Claim'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuestTile extends StatelessWidget {
  final Challenge quest;
  final bool isClaiming;
  final VoidCallback onClaim;

  const _QuestTile({
    required this.quest,
    required this.isClaiming,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final claimed = quest.isCompleted;
    final ready = quest.canClaim && !claimed;
    final badge = quest.badgeName;

    return _Card(
      highlight: ready,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                claimed ? Iconsax.medal_star5 : Iconsax.medal,
                size: 18,
                color: claimed ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  quest.title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              _XpLabel(xp: quest.rewardXp, muted: claimed),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            quest.description,
            style:
                theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          if (!claimed) ...[
            const SizedBox(height: 12),
            _ProgressRow(item: quest),
          ],
          if (badge != null && badge.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              claimed ? '$badge is on your profile' : 'Badge: $badge',
              style: theme.textTheme.labelSmall,
            ),
          ],
          if (ready) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isClaiming ? null : onClaim,
                child: isClaiming
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.onPrimary,
                        ),
                      )
                    : const Text('Claim'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
