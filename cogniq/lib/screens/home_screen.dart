import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/game_info.dart';
import '../theme/app_theme.dart';
import '../theme/settings_manager.dart';
import '../theme/theme_manager.dart';
import '../utils/ad_manager.dart';
import '../utils/purchase_manager.dart';
import '../utils/hint_manager.dart';
import '../utils/audio_manager.dart';
import '../utils/recently_played_manager.dart';
import 'package:home_widget/home_widget.dart';
import '../utils/daily_challenge_manager.dart';
import 'daily_screen.dart';
import 'beta/beta_games_screen.dart';
import '../utils/challenge_reminder_helper.dart';
// import 'daily_challenge_test_screen.dart';
import '../utils/activity_tracker.dart';
import '../utils/notification_manager.dart';

const Map<String, IconData> _gameIcons = {
  'wordle': Icons.grid_4x4_outlined,
  'hangman': Icons.person_outline,
  'weaver': Icons.swap_horiz_outlined,
  'zip': Icons.bolt_outlined,
  'crossclimb': Icons.trending_up_outlined,
  'queens': Icons.star_outline_rounded,
  'chimp': Icons.psychology_outlined,
  'connections': Icons.hub_outlined,
  'flagle': Icons.flag_outlined,
  'wordbuilder': Icons.spellcheck_outlined,
  'memory': Icons.style_outlined,
  'spellingbee': Icons.hive_outlined,
  'sudoku': Icons.grid_on_outlined,
  'wordsearch': Icons.search_outlined,
  'minesweeper': Icons.dangerous_outlined,
  'nonogram': Icons.apps_rounded,
  'numbermemory': Icons.pin_outlined,
  'sequence': Icons.pattern_outlined,
  'oddcolor': Icons.palette_outlined,
  'hue': Icons.color_lens_outlined,
  'pattern_lock': Icons.lock_outline,
  'colour_link': Icons.link_outlined,
  'color_flood': Icons.water_drop_outlined,
  'circuit_guide': Icons.electrical_services_outlined,
};

const Map<String, List<String>> _categories = {
  'All': [],
  'Word': [
    'spellingbee',
    'wordsearch',
  ],
  'Logic': [
    'sudoku',
    'queens',
    'zip',
    'connections',
    'minesweeper',
    'oddcolor',
    'hue',
    'nonogram',
    'colour_link',
    'color_flood',
    'block_escape',
    'circuit_guide',
  ],
  'Memory': [
    'chimp',
    'pattern_lock',
  ],
};

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _ctrl;
  String _activeCategory = 'All';
  int _dailyStreak = 0;
  bool _dailyCompleted = false;
  GameInfo? _todaysGame;
  int _currentTab = 0;
  int _completedCount = 0;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<GameInfo> _recentlyPlayedGames = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();

    final now = DateTime.now().toUtc();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    _todaysGame = kAllGames[seed % kAllGames.length];

    _loadDailyChallengeInfo();
    settingsNotifier.addListener(_onSettingsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ChallengeReminderHelper.checkAndShowReminder(context);
      NotificationManager.requestPermissions();
      NotificationManager.updateDailyChallengeReminder();
      NotificationManager.updateInactivityReminders();
      // NotificationManager.scheduleInstallTestNotification();
      _checkAndShowDailyChallengePopup();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      NotificationManager.updateInactivityReminders();
    }
  }

  Future<void> _checkAndShowDailyChallengePopup() async {
    final prefs = await SharedPreferences.getInstance();
    final bool hasSeen = prefs.getBool('shown_daily_challenge_popup_v1') ?? false;
    if (!hasSeen) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          final activeColor = AppTheme.dustyMauve;
          return AlertDialog(
            backgroundColor: context.bgCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: activeColor.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.bolt_rounded,
                    color: activeColor,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Today's Daily Challenge",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Check out today's daily challenges! Train your brain to keep your streak going.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.spaceEvenly,
            actionsPadding: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  "Not Now",
                  style: GoogleFonts.outfit(
                    color: context.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _currentTab = 1;
                    _loadDailyChallengeInfo();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: activeColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(
                  "Take Me There",
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      );
      await prefs.setBool('shown_daily_challenge_popup_v1', true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    settingsNotifier.removeListener(_onSettingsChanged);
    _ctrl.dispose();
    super.dispose();
  }

  void _onSettingsChanged() {
    _loadDailyChallengeInfo();
  }

  Future<void> _loadDailyChallengeInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toUtc();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    final dateStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    _dailyStreak = await DailyChallengeManager.getOrUpdateStreak(dateStr);
    final completedCount = await DailyChallengeManager.getCompletedCountForDate(
      dateStr,
    );
    _dailyCompleted = completedCount == 3;

    final challenges = DailyChallengeManager.getChallengesForDate(now);
    if (challenges.isNotEmpty) {
      _todaysGame = challenges[0].game;
    } else {
      final dailyGames = kAllGames
          .where((g) => ['zip', 'oddcolor', 'nonogram', 'hue'].contains(g.id))
          .toList();
      _todaysGame = dailyGames[seed % dailyGames.length];
    }

    // Compute total exercises completed and favorite game
    int completed = 0;
    String favGame = 'Categories';
    int maxLvl = 0;

    for (final g in kAllGames) {
      final lvl = prefs.getInt('level_${g.id}') ?? 0;
      if (lvl > 0) completed += lvl;
      if (lvl > maxLvl) {
        maxLvl = lvl;
        favGame = g.name;
      }
    }
    _completedCount = completed;

    // Update native home screen widget
    try {
      await HomeWidget.saveWidgetData('daily_streak', _dailyStreak);
      await HomeWidget.saveWidgetData('total_solved', completed);
      await HomeWidget.saveWidgetData('favorite_game', favGame);
      await HomeWidget.saveWidgetData(
        'todays_puzzle_name',
        _todaysGame?.name ?? 'Puzzle',
      );
      await HomeWidget.saveWidgetData(
        'todays_puzzle_desc',
        _todaysGame?.description ?? 'Train your mind',
      );
      await HomeWidget.updateWidget(
        name: 'StreakWidgetProvider',
        androidName: 'com.mayank.cogniq.StreakWidgetProvider',
        qualifiedAndroidName: 'com.mayank.cogniq.StreakWidgetProvider',
      );
    } catch (_) {}

    // Load recently played games
    final recentlyPlayedIds = await RecentlyPlayedManager.getRecentlyPlayed();
    _recentlyPlayedGames = recentlyPlayedIds
        .map((id) {
          try {
            return kAllGames.firstWhere((g) => g.id == id);
          } catch (_) {
            return null;
          }
        })
        .whereType<GameInfo>()
        .toList();

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDark,
      body: SafeArea(child: _buildCurrentTabContent()),
      bottomNavigationBar: _buildCustomBottomNavBar(),
    );
  }

  Widget _buildCustomBottomNavBar() {
    final activeColor = AppTheme.dustyMauve;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: context.bgCard,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2B2926).withAlpha(10),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final tabWidth = totalWidth / 4;

          return SizedBox(
            height: 48,
            child: Stack(
              children: [
                // Sliding Capsule Background
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOutCubic,
                  left:
                      _currentTab * tabWidth + (tabWidth - tabWidth * 0.85) / 2,
                  width: tabWidth * 0.85,
                  top: 4,
                  bottom: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: activeColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),

                // Row of Tabs
                Row(
                  children: [
                    _buildNavItem(0, Icons.home_outlined, Icons.home, 'Home'),
                    _buildNavItem(
                      1,
                      Icons.calendar_today_outlined,
                      Icons.calendar_today,
                      'Daily',
                    ),
                    _buildNavItem(
                      2,
                      Icons.bar_chart_outlined,
                      Icons.bar_chart,
                      'Stats',
                    ),
                    _buildNavItem(
                      3,
                      Icons.person_outlined,
                      Icons.person,
                      'Profile',
                    ),
                    // _buildNavItem(
                    //   4,
                    //   Icons.bug_report_outlined,
                    //   Icons.bug_report,
                    //   'Beta',
                    // ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData outlineIcon,
    IconData solidIcon,
    String label,
  ) {
    final isSelected = _currentTab == index;
    final activeColor = AppTheme.dustyMauve;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentTab = index;
            _loadDailyChallengeInfo();
          });
        },
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? solidIcon : outlineIcon,
                color: isSelected ? activeColor : context.textSecondary,
                size: 20,
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: SizedBox(
                  width: isSelected ? null : 0,
                  child: isSelected
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 6),
                            Text(
                              label,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: activeColor,
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTabContent() {
    switch (_currentTab) {
      case 0:
        return _buildHomeTab();
      case 1:
        return const _DailyTab();
      case 2:
        return const _StatsTab();
      case 3:
        return const _ProfileTab();
      case 4:
        return const BetaGamesScreen();
      default:
        return _buildHomeTab();
    }
  }

  Widget _buildHomeTab() {
    final filteredGames = kAllGames.where((g) {
      final matchesCategory =
          _activeCategory == 'All' ||
          (_categories[_activeCategory]?.contains(g.id) ?? false);
      final matchesSearch =
          _searchQuery.isEmpty ||
          g.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch && !g.isStashed;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Premium Spacious Header (Zen style)
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How are you feeling today?',
                    style: GoogleFonts.outfit(
                      fontSize: context.scale(22),
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Cultivate your daily mindfulness & focus',
                    style: GoogleFonts.outfit(
                      fontSize: context.scale(12),
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.dustyMauve.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.spa_outlined,
                  color: AppTheme.dustyMauve,
                  size: 20,
                ),
              ),
            ],
          ),
        ),

        // Expanded Scrollable Content
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              // 1. Mindful Report Dashboard
              _buildProgressReportCard()
                  .animate()
                  .fadeIn(duration: 350.ms)
                  .slideY(begin: 0.08, end: 0.0, curve: Curves.easeOutQuad),
              const SizedBox(height: 20),

              // Search Bar
              _buildSearchBar()
                  .animate()
                  .fadeIn(delay: 80.ms, duration: 350.ms)
                  .slideY(begin: 0.08, end: 0.0, curve: Curves.easeOutQuad),
              const SizedBox(height: 20),

              // 2. Recently Played Horizontal Strip
              _buildRecentlyPlayedSection()
                  .animate()
                  .fadeIn(delay: 150.ms, duration: 350.ms)
                  .slideY(begin: 0.08, end: 0.0, curve: Curves.easeOutQuad),
              const SizedBox(height: 20),

              // "Todays Exercises" section title
              Text(
                'Today\'s Exercises',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 12),

              // 3. Custom category pill tabs
              _buildCategoryChips().animate().fadeIn(delay: 240.ms),
              const SizedBox(height: 16),

              // 4. Grid of Clean Zen Game Cards or empty state
              if (filteredGames.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 40,
                          color: context.textSecondary.withAlpha(100),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No exercises match your search',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: context.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn()
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: filteredGames.length,
                  itemBuilder: (ctx, idx) {
                    return _GameCard(game: filteredGames[idx])
                        .animate()
                        .fadeIn(delay: (idx * 30).ms, duration: 300.ms)
                        .slideY(
                          begin: 0.1,
                          end: 0.0,
                          curve: Curves.easeOutQuad,
                        );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          setState(() {
            _searchQuery = val;
          });
        },
        style: GoogleFonts.outfit(color: context.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search exercises...',
          hintStyle: GoogleFonts.outfit(
            color: context.textSecondary.withAlpha(150),
            fontSize: 13,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: context.textSecondary,
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  child: Icon(
                    Icons.close_rounded,
                    color: context.textSecondary,
                    size: 18,
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildRecentlyPlayedSection() {
    if (_recentlyPlayedGames.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Continue Playing',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 65,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _recentlyPlayedGames.length,
            itemBuilder: (context, index) {
              final game = _recentlyPlayedGames[index];
              final accent = AppTheme.accentFor(game.id);
              final icon = _gameIcons[game.id] ?? Icons.games_outlined;

              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _RecentGameCard(
                  game: game,
                  accent: accent,
                  icon: icon,
                  onRefresh: _loadDailyChallengeInfo,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProgressReportCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR PROGRESS REPORT',
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppTheme.dustyMauve,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildReportStat(
                _dailyStreak > 0 ? '$_dailyStreak Days' : '0 Days',
                'Active Streak',
                Icons.wb_sunny_outlined,
                AppTheme.warmAmber,
              ),
              Container(
                width: 1,
                height: 36,
                color: context.textMuted.withAlpha(40),
              ),
              _buildReportStat(
                '$_completedCount Cleared',
                'Total Puzzles',
                Icons.check_circle_outline,
                AppTheme.softSage,
              ),
              Container(
                width: 1,
                height: 36,
                color: context.textMuted.withAlpha(40),
              ),
              _buildReportStat(
                _dailyCompleted ? 'Complete' : 'Pending',
                'Daily Challenge',
                Icons.star_outline_rounded,
                AppTheme.dustyMauve,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportStat(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 10,
              color: context.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.keys.map((cat) {
          final isActive = _activeCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _activeCategory = cat;
                  _ctrl.reset();
                  _ctrl.forward();
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: EdgeInsets.symmetric(
                  horizontal: isActive ? 18 : 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isActive ? AppTheme.dustyMauve : context.bgCard,
                  borderRadius: BorderRadius.circular(isActive ? 24 : 16),
                  border: Border.all(
                    color: isActive
                        ? AppTheme.dustyMauve
                        : context.textMuted.withAlpha(20),
                    width: 1,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: AppTheme.dustyMauve.withAlpha(50),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : AppTheme.cardShadow,
                ),
                child: Text(
                  cat,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.white : context.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RecentGameCard extends StatefulWidget {
  final GameInfo game;
  final Color accent;
  final IconData icon;
  final VoidCallback onRefresh;

  const _RecentGameCard({
    required this.game,
    required this.accent,
    required this.icon,
    required this.onRefresh,
  });

  @override
  State<_RecentGameCard> createState() => _RecentGameCardState();
}

class _RecentGameCardState extends State<_RecentGameCard> {
  bool _pressed = false;
  int _level = 1;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final lvl = prefs.getInt('level_${widget.game.id}') ?? 0;
    if (mounted) {
      setState(() {
        _level = lvl + 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        AudioManager.fadeOutMusic();
        RecentlyPlayedManager.addGame(widget.game.id);
        ActivityTracker.trackGamePlay(widget.game.id);
        Navigator.pushNamed(context, widget.game.routeName).then((_) {
          AudioManager.fadeInMusic();
          widget.onRefresh();
        });
      },
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 160,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: context.bgCard,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: widget.accent.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, color: widget.accent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.game.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Level $_level',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        color: context.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircularProgressBadge extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final Color color;

  const _CircularProgressBadge({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    // If progress is 0, show a faint complete track instead of an empty line
    final displayValue = value == 0.0 ? 0.05 : value;
    return SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(
        value: displayValue,
        backgroundColor: color.withAlpha(25),
        valueColor: AlwaysStoppedAnimation<Color>(color),
        strokeWidth: 2.5,
      ),
    );
  }
}

class _GameCard extends StatefulWidget {
  final GameInfo game;
  const _GameCard({required this.game});
  @override
  State<_GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<_GameCard> {
  bool _pressed = false;
  int _level = 1;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final lvl = prefs.getInt('level_${widget.game.id}') ?? 0;
    if (mounted) {
      setState(() {
        _level = lvl + 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentFor(widget.game.id);
    final icon = _gameIcons[widget.game.id] ?? Icons.games_outlined;

    // Sector progress fraction: level 1 = 0% progress in this block of 5 levels, level 5 = 80% progress
    final progressFraction = ((_level - 1) % 5) / 5.0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        AudioManager.fadeOutMusic();
        RecentlyPlayedManager.addGame(widget.game.id);
        ActivityTracker.trackGamePlay(widget.game.id);
        Navigator.pushNamed(context, widget.game.routeName).then((_) {
          AudioManager.fadeInMusic();
          _loadProgress();
        });
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: context.bgCard,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: accent.withAlpha(25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, color: accent, size: 16),
                        ),
                        _CircularProgressBadge(
                          value: progressFraction,
                          color: accent,
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      widget.game.name,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Level $_level',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        color: context.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: 4,
                  child: LinearProgressIndicator(
                    value: progressFraction == 0.0 ? 0.05 : progressFraction,
                    backgroundColor: accent.withAlpha(20),
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Stats Tab content
class _StatsTab extends StatefulWidget {
  const _StatsTab();
  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> {
  Map<String, int> _levels = {};
  Map<String, int> _streaks = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, int> lvls = {};
    final Map<String, int> strks = {};
    for (final g in kAllGames) {
      lvls[g.id] = (prefs.getInt('level_${g.id}') ?? 0) + 1;
      strks[g.id] = prefs.getInt('streak_${g.id}') ?? 0;
    }
    if (mounted) {
      setState(() {
        _levels = lvls;
        _streaks = strks;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      children: [
        Text(
          'Progress Log',
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
        Text(
          'A record of your daily focus and exercises.',
          style: GoogleFonts.outfit(fontSize: 13, color: context.textSecondary),
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: context.bgCard,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: kAllGames.where((g) => !g.isStashed).map((g) {
              final lvl = _levels[g.id] ?? 1;
              final strk = _streaks[g.id] ?? 0;
              final accent = AppTheme.accentFor(g.id);
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: accent.withAlpha(25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _gameIcons[g.id] ?? Icons.gamepad_outlined,
                                size: 16,
                                color: accent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              g.name,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: context.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Level $lvl${strk > 0 ? ' • Streak $strk' : ''}',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: context.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (g != kAllGames.last)
                    Divider(
                      color: context.textMuted.withAlpha(40),
                      height: 1,
                      thickness: 0.8,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}

// Profile Tab content (integrated Settings)
class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settingsNotifier,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            Text(
              'Settings',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            Text(
              'Configure your quiet mindfulness space.',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: context.bgCard,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                children: [
                  ListenableBuilder(
                    listenable: themeNotifier,
                    builder: (ctx, _) {
                      return _ProfileTile(
                        icon: themeNotifier.isDarkMode
                            ? Icons.dark_mode_outlined
                            : Icons.light_mode_outlined,
                        title: 'Dark Mode',
                        trailing: Switch.adaptive(
                          value: themeNotifier.isDarkMode,
                          onChanged: (_) => themeNotifier.toggleTheme(),
                          activeColor: AppTheme.dustyMauve,
                        ),
                      );
                    },
                  ),
                  Divider(
                    color: context.textMuted.withAlpha(40),
                    height: 1,
                    thickness: 0.8,
                  ),
                  _ProfileTile(
                    icon: Icons.text_fields,
                    title: 'Font Size',
                    subtitle: settingsNotifier.fontScale == 0.85
                        ? 'Small'
                        : settingsNotifier.fontScale == 1.0
                        ? 'Normal'
                        : 'Large',
                    trailing: SizedBox(
                      width: 120,
                      child: Slider(
                        value: settingsNotifier.fontScale,
                        min: 0.85,
                        max: 1.15,
                        divisions: 2,
                        activeColor: AppTheme.dustyMauve,
                        onChanged: (val) {
                          settingsNotifier.setFontScale(val);
                        },
                      ),
                    ),
                  ),
                  Divider(
                    color: context.textMuted.withAlpha(40),
                    height: 1,
                    thickness: 0.8,
                  ),
                  _ProfileTile(
                    icon: Icons.volume_up_outlined,
                    title: 'SFX (loss, win, and tile tapping)',
                    trailing: Switch.adaptive(
                      value: settingsNotifier.soundEnabled,
                      onChanged: (val) => settingsNotifier.setSound(val),
                      activeColor: AppTheme.dustyMauve,
                    ),
                  ),
                  Divider(
                    color: context.textMuted.withAlpha(40),
                    height: 1,
                    thickness: 0.8,
                  ),
                  _ProfileTile(
                    icon: Icons.music_note_outlined,
                    title: 'Bg music',
                    trailing: Switch.adaptive(
                      value: settingsNotifier.musicEnabled,
                      onChanged: (val) => settingsNotifier.setMusic(val),
                      activeColor: AppTheme.dustyMauve,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _SectionHeader(title: 'Premium & Ads'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: context.bgCard,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                children: [
                  _ProfileTile(
                    icon: Icons.star_border_outlined,
                    title: 'Go Premium',
                    subtitle: settingsNotifier.adsRemoved
                        ? 'Premium ad-free is active!'
                        : 'Unlock lifetime ad-free experience',
                    onTap: settingsNotifier.adsRemoved
                        ? null
                        : () {
                            final messenger = ScaffoldMessenger.of(context);
                            PurchaseManager.buyAdFree(
                              onStoreUnavailable: () {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'App Store/Play Store is currently unavailable.',
                                      style: GoogleFonts.outfit(),
                                    ),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              },
                              onProductNotFound: () {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Premium product ID not found. Verify console configuration.',
                                      style: GoogleFonts.outfit(),
                                    ),
                                    backgroundColor: Colors.amber[800],
                                  ),
                                );
                              },
                            );
                          },
                  ),
                  Divider(
                    color: context.textMuted.withAlpha(40),
                    height: 1,
                    thickness: 0.8,
                  ),
                  _ProfileTile(
                    icon: Icons.restore_outlined,
                    title: 'Restore Purchase',
                    subtitle: 'Restore premium status from App/Play store',
                    onTap: () {
                      final messenger = ScaffoldMessenger.of(context);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'Restoring purchases...',
                            style: GoogleFonts.outfit(),
                          ),
                          backgroundColor: Colors.grey[800],
                          duration: const Duration(seconds: 1),
                        ),
                      );
                      PurchaseManager.restorePurchases(
                        onRestoreFinished: (success) {
                          if (success) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Restore process finished.',
                                  style: GoogleFonts.outfit(),
                                ),
                                backgroundColor: AppTheme.wordleGreen,
                              ),
                            );
                          } else {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Restore failed or store unavailable.',
                                  style: GoogleFonts.outfit(),
                                ),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                  Divider(
                    color: context.textMuted.withAlpha(40),
                    height: 1,
                    thickness: 0.8,
                  ),
                  _ProfileTile(
                    icon: Icons.play_circle_outline,
                    title: 'Earn Free Hints',
                    subtitle: AdManager.isRewardedAdReady()
                        ? 'Rewarded video ready'
                        : 'Watch video to get +2 hints',
                    onTap: () => _showEarnHintsDialog(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _SectionHeader(title: 'Data Management'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: context.bgCard,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                children: [
                  // _ProfileTile(
                  //   icon: Icons.bug_report_outlined,
                  //   title: 'Daily Challenges Debug Tester',
                  //   subtitle: 'Test and debug all 90 daily challenges directly',
                  //   onTap: () {
                  //     Navigator.pushNamed(context, '/daily_test');
                  //   },
                  // ),
                  // Divider(
                  //   color: context.textMuted.withAlpha(40),
                  //   height: 1,
                  //   thickness: 0.8,
                  // ),
                  _ProfileTile(
                    icon: Icons.delete_outline,
                    title: 'Clear All Saved Progress',
                    titleColor: Colors.redAccent,
                    onTap: () => _showResetDialog(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _SectionHeader(title: 'Info'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: context.bgCard,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppTheme.cardShadow,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Text(
                'CogniQ is designed to help cultivate mindful daily puzzles. Clear, distraction-free study.',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: context.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        );
      },
    );
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Reset Progress?',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
          ),
        ),
        content: Text(
          'This will clear all your level data and streaks. This action cannot be undone.',
          style: GoogleFonts.outfit(color: context.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(
                color: context.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              await settingsNotifier.resetAllProgress();
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All progress has been reset'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: Text(
              'Reset',
              style: GoogleFonts.outfit(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEarnHintsDialog(BuildContext context) {
    String selectedGameId = kAllGames.first.id;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: context.bgCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Earn Free Hints',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select the game you want to add 2 hints to:',
                    style: GoogleFonts.outfit(
                      color: context.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: context.bgDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: context.textMuted.withAlpha(50),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedGameId,
                        isExpanded: true,
                        dropdownColor: context.bgCard,
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: context.textSecondary,
                        ),
                        items: kAllGames.map((game) {
                          return DropdownMenuItem<String>(
                            value: game.id,
                            child: Text(
                              game.name,
                              style: GoogleFonts.outfit(
                                color: context.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedGameId = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.outfit(
                      color: context.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.wordleGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    final messenger = ScaffoldMessenger.of(context);
                    AdManager.showRewardedAd(
                      onRewardGranted: (amount) async {
                        await HintManager.addHints(selectedGameId, amount);
                        final gameName = kAllGames
                            .firstWhere((g) => g.id == selectedGameId)
                            .name;
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Earned $amount hints for $gameName!',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            backgroundColor: AppTheme.wordleGreen,
                          ),
                        );
                      },
                      onAdNotReady: () {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Rewarded ad is loading. Please try again in a moment.',
                              style: GoogleFonts.outfit(),
                            ),
                            backgroundColor: Colors.amber[800],
                          ),
                        );
                      },
                    );
                  },
                  child: Text(
                    'Watch Video',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(
          color: context.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color? titleColor;
  final VoidCallback? onTap;
  const _ProfileTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.titleColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final trailingWidget = trailing;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: titleColor ?? context.textSecondary, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      color: titleColor ?? context.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: GoogleFonts.outfit(
                        color: context.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailingWidget != null) trailingWidget,
          ],
        ),
      ),
    );
  }
}

// Daily Tab Widget implementation
class _DailyTab extends StatelessWidget {
  const _DailyTab();

  @override
  Widget build(BuildContext context) {
    return const DailyScreen(isEmbedded: true);
  }
}
