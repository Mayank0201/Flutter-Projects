import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_info.dart';
import '../theme/app_theme.dart';
import '../theme/settings_manager.dart';
import '../theme/theme_manager.dart';
import 'widgets/zen_sunset_widget.dart';

// Map game id → Material icon
const Map<String, IconData> _gameIcons = {
  'wordle':      Icons.grid_4x4_outlined,
  'hangman':     Icons.person_outline,
  'weaver':      Icons.swap_horiz_outlined,
  'zip':         Icons.bolt_outlined,
  'crossclimb':  Icons.trending_up_outlined,
  'queens':      Icons.star_outline_rounded,
  'chimp':       Icons.psychology_outlined,
  'connections': Icons.hub_outlined,
  'flagle':      Icons.flag_outlined,
  'wordbuilder': Icons.spellcheck_outlined,
  'memory':      Icons.style_outlined,
  'spellingbee': Icons.hive_outlined,
  'sudoku':      Icons.grid_on_outlined,
  'wordsearch':  Icons.search_outlined,
  'twentyfortyeight': Icons.filter_2_outlined,
  'reaction':    Icons.flash_on_outlined,
  'numbermemory': Icons.pin_outlined,
  'sequence':    Icons.pattern_outlined,
};

const Map<String, List<String>> _categories = {
  'All': [],
  'Word': ['wordle', 'hangman', 'weaver', 'crossclimb', 'wordbuilder', 'spellingbee', 'wordsearch'],
  'Logic': ['sudoku', 'queens', 'zip', 'connections', 'twentyfortyeight'],
  'Memory': ['chimp', 'memory', 'sequence'],
  'Speed': ['reaction'],
};

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  String _activeCategory = 'All';
  int _dailyStreak = 0;
  bool _dailyCompleted = false;
  GameInfo? _todaysGame;
  int _currentTab = 0;
  int _completedCount = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300))..forward();
    
    final now = DateTime.now().toUtc();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    _todaysGame = kAllGames[seed % kAllGames.length];
    
    _loadDailyChallengeInfo();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadDailyChallengeInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toUtc();
    final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final seed = now.year * 10000 + now.month * 100 + now.day;
    
    _dailyStreak = prefs.getInt('daily_streak') ?? 0;
    _dailyCompleted = prefs.getBool('daily_completed_$dateStr') ?? false;
    _todaysGame = kAllGames[seed % kAllGames.length];

    // Compute total exercises completed
    int completed = 0;
    for (final g in kAllGames) {
      final lvl = prefs.getInt('level_${g.id}') ?? 0;
      if (lvl > 0) completed += lvl;
    }
    _completedCount = completed;

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDark,
      body: SafeArea(
        child: _buildCurrentTabContent(),
      ),
      bottomNavigationBar: _buildCustomBottomNavBar(),
    );
  }

  Widget _buildCustomBottomNavBar() {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.bgCard,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2B2926).withAlpha(10),
            blurRadius: 16,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.home_outlined, Icons.home, 'Home'),
          _buildNavItem(1, Icons.calendar_today_outlined, Icons.calendar_today, 'Daily'),
          _buildNavItem(2, Icons.bar_chart_outlined, Icons.bar_chart, 'Stats'),
          _buildNavItem(3, Icons.person_outlined, Icons.person, 'Profile'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData outlineIcon, IconData solidIcon, String label) {
    final isSelected = _currentTab == index;
    final activeColor = AppTheme.dustyMauve;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentTab = index;
          _loadDailyChallengeInfo();
        });
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withAlpha(25) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? solidIcon : outlineIcon,
              color: isSelected ? activeColor : context.textSecondary,
              size: 22,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: activeColor,
                ),
              ),
            ],
          ],
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
      default:
        return _buildHomeTab();
    }
  }

  Widget _buildHomeTab() {
    final filteredGames = kAllGames.where((g) {
      if (_activeCategory == 'All') return true;
      return _categories[_activeCategory]?.contains(g.id) ?? false;
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
                    style: GoogleFonts.inter(
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
              // 1. Mindful Report Dashboard (replaces the raw daily streak block)
              _buildProgressReportCard(),
              const SizedBox(height: 24),

              // "Todays Exercises" section title
              Text(
                'Today\'s Exercises',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              // 2. Custom category pill tabs
              _buildCategoryChips(),
              const SizedBox(height: 16),

              // 3. Grid of Clean Zen Game Cards
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
                  return _GameCard(game: filteredGames[idx]);
                },
              ),
            ],
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
            style: GoogleFonts.inter(
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

  Widget _buildReportStat(String value, String label, IconData icon, Color color) {
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
            style: GoogleFonts.inter(
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
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? AppTheme.dustyMauve : context.bgCard,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isActive ? null : AppTheme.cardShadow,
                ),
                child: Text(
                  cat,
                  style: GoogleFonts.inter(
                    fontSize: 12,
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

class _CircularProgressBadge extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final Color color;

  const _CircularProgressBadge({
    required this.value,
    required this.color,
  });

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
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final lvl = prefs.getInt('level_${widget.game.id}') ?? 0;
    final strk = prefs.getInt('streak_${widget.game.id}') ?? 0;
    if (mounted) {
      setState(() {
        _level = lvl + 1;
        _streak = strk;
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
        Navigator.pushNamed(context, widget.game.routeName).then((_) => _loadProgress());
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          decoration: BoxDecoration(
            color: context.bgCard,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppTheme.cardShadow,
          ),
          padding: const EdgeInsets.all(14),
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
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: context.textSecondary,
                  fontWeight: FontWeight.w500,
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
          style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: context.textPrimary),
        ),
        Text(
          'A record of your daily focus and exercises.',
          style: GoogleFonts.inter(fontSize: 13, color: context.textSecondary),
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: context.bgCard,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: kAllGames.map((g) {
              final lvl = _levels[g.id] ?? 1;
              final strk = _streaks[g.id] ?? 0;
              final accent = AppTheme.accentFor(g.id);
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                              child: Icon(_gameIcons[g.id] ?? Icons.gamepad_outlined, size: 16, color: accent),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              g.name,
                              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary),
                            ),
                          ],
                        ),
                        Text(
                          'Level $lvl${strk > 0 ? ' • Streak $strk' : ''}',
                          style: GoogleFonts.inter(fontSize: 12, color: context.textSecondary, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  if (g != kAllGames.last)
                    Divider(color: context.textMuted.withAlpha(40), height: 1, thickness: 0.8),
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
              style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: context.textPrimary),
            ),
            Text(
              'Configure your quiet mindfulness space.',
              style: GoogleFonts.inter(fontSize: 13, color: context.textSecondary),
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
                        icon: themeNotifier.isDarkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                        title: 'Dark Mode',
                        trailing: Switch.adaptive(
                          value: themeNotifier.isDarkMode,
                          onChanged: (_) => themeNotifier.toggleTheme(),
                          activeColor: AppTheme.dustyMauve,
                        ),
                      );
                    },
                  ),
                  Divider(color: context.textMuted.withAlpha(40), height: 1, thickness: 0.8),
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
                  Divider(color: context.textMuted.withAlpha(40), height: 1, thickness: 0.8),
                  _ProfileTile(
                    icon: Icons.vibration,
                    title: 'Haptic Feedback',
                    trailing: Switch.adaptive(
                      value: settingsNotifier.hapticEnabled,
                      onChanged: (val) => settingsNotifier.setHaptic(val),
                      activeColor: AppTheme.dustyMauve,
                        ),
                      ),
                  Divider(color: context.textMuted.withAlpha(40), height: 1, thickness: 0.8),
                  _ProfileTile(
                    icon: Icons.volume_up_outlined,
                    title: 'Sound Effects',
                    trailing: Switch.adaptive(
                      value: settingsNotifier.soundEnabled,
                      onChanged: (val) => settingsNotifier.setSound(val),
                      activeColor: AppTheme.dustyMauve,
                    ),
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
              child: _ProfileTile(
                icon: Icons.delete_outline,
                title: 'Clear All Saved Progress',
                titleColor: Colors.redAccent,
                onTap: () => _showResetDialog(context),
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
                style: GoogleFonts.inter(fontSize: 12, color: context.textSecondary, height: 1.4),
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
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: context.textPrimary),
        ),
        content: Text(
          'This will clear all your level data and streaks. This action cannot be undone.',
          style: GoogleFonts.inter(color: context.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: context.textSecondary, fontWeight: FontWeight.w600)),
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
            child: Text('Reset', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
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
  const _ProfileTile({required this.icon, required this.title, this.subtitle, this.trailing, this.titleColor, this.onTap});

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
                  Text(title, style: GoogleFonts.outfit(
                    color: titleColor ?? context.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  )),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: GoogleFonts.inter(
                      color: context.textSecondary,
                      fontSize: 11,
                    )),
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
class _DailyTab extends StatefulWidget {
  const _DailyTab();
  @override
  State<_DailyTab> createState() => _DailyTabState();
}

class _DailyTabState extends State<_DailyTab> {
  int _streak = 0;
  bool _completedToday = false;
  String _dateStr = '';
  late GameInfo _todaysGame;
  int _todaysLevelIndex = 0;
  bool _loading = true;
  Timer? _countdownTimer;
  String _timeLeft = '';

  @override
  void initState() {
    super.initState();
    _todaysGame = kAllGames[0];
    _loadDailyState();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _timeLeft = _calculateTimeLeft();
        });
      }
    });
  }

  String _calculateTimeLeft() {
    final now = DateTime.now().toUtc();
    final tomorrow = DateTime.utc(now.year, now.month, now.day + 1);
    final diff = tomorrow.difference(now);
    final h = diff.inHours.toString().padLeft(2, '0');
    final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _loadDailyState() async {
    final now = DateTime.now().toUtc();
    _dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final seed = now.year * 10000 + now.month * 100 + now.day;

    _todaysGame = kAllGames[seed % kAllGames.length];
    _todaysLevelIndex = (seed * 7) % 30;

    final prefs = await SharedPreferences.getInstance();
    final lastCompleted = prefs.getString('daily_last_completed_date') ?? '';
    _streak = prefs.getInt('daily_streak') ?? 0;

    if (lastCompleted.isNotEmpty && lastCompleted != _dateStr) {
      final lastDate = DateTime.parse(lastCompleted);
      final todayDate = DateTime.utc(now.year, now.month, now.day);
      final diff = todayDate.difference(lastDate).inDays;
      if (diff > 1) {
        _streak = 0;
        await prefs.setInt('daily_streak', 0);
      }
    }

    _completedToday = prefs.getBool('daily_completed_$_dateStr') ?? false;

    if (mounted) {
      setState(() {
        _loading = false;
        _timeLeft = _calculateTimeLeft();
      });
    }
  }

  Future<void> _playChallenge() async {
    if (_completedToday) return;

    final prefs = await SharedPreferences.getInstance();
    final gameId = _todaysGame.id;
    final levelKey = 'level_$gameId';

    final realLevel = prefs.getInt(levelKey) ?? 0;
    await prefs.setInt('daily_backup_$gameId', realLevel);
    await prefs.setString('daily_backup_active_game', gameId);

    await prefs.setInt(levelKey, _todaysLevelIndex);
    await prefs.setBool('play_daily_mode', true);

    if (!mounted) return;
    settingsNotifier.hapticTap();

    final result = await Navigator.pushNamed(context, _todaysGame.routeName);

    final updatedPrefs = await SharedPreferences.getInstance();
    final postLevel = updatedPrefs.getInt(levelKey) ?? 0;

    if (postLevel > _todaysLevelIndex || result == true) {
      settingsNotifier.hapticSuccess();
      
      int newStreak = _streak;
      final lastCompleted = updatedPrefs.getString('daily_last_completed_date') ?? '';
      if (lastCompleted != _dateStr) {
        if (lastCompleted.isEmpty) {
          newStreak = 1;
        } else {
          final lastDate = DateTime.parse(lastCompleted);
          final todayDate = DateTime.now().toUtc();
          final diff = DateTime.utc(todayDate.year, todayDate.month, todayDate.day).difference(lastDate).inDays;
          if (diff == 1) {
            newStreak += 1;
          } else {
            newStreak = 1;
          }
        }
        await updatedPrefs.setInt('daily_streak', newStreak);
        await updatedPrefs.setString('daily_last_completed_date', _dateStr);
        await updatedPrefs.setBool('daily_completed_$_dateStr', true);
      }

      if (mounted) {
        setState(() {
          _streak = newStreak;
          _completedToday = true;
        });
        _showSuccessDialog();
      }
    }

    await updatedPrefs.setInt(levelKey, realLevel);
    await updatedPrefs.remove('daily_backup_$gameId');
    await updatedPrefs.remove('daily_backup_active_game');
    await updatedPrefs.setBool('play_daily_mode', false);
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Center(
          child: Text(
            'Challenge Completed!',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: AppTheme.softSage, fontSize: 20),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Text(
              '$_streak',
              style: GoogleFonts.outfit(fontSize: 44, fontWeight: FontWeight.w900, color: AppTheme.softSage),
            ),
            Text(
              'Day Streak',
              style: GoogleFonts.inter(fontSize: 13, color: context.textSecondary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Text(
              'You cleared today\'s challenge in ${_todaysGame.name}!',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: context.textPrimary, fontSize: 14),
            ),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Continue', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.softSage)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final accent = AppTheme.accentFor(_todaysGame.id);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      children: [
        // Title & subtitle
        Text(
          'Daily Dose of Zen',
          style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: context.textPrimary),
        ),
        Text(
          'A new exercise is selected every day to center your mind.',
          style: GoogleFonts.inter(fontSize: 13, color: context.textSecondary),
        ),
        const SizedBox(height: 20),

        // Custom Sunset illustration
        const ZenSunsetWidget(height: 180),
        const SizedBox(height: 24),

        // Main Featured Game block
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: context.bgCard,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: [
              Text(
                _completedToday ? 'COMPLETED' : 'TODAY\'S FEATURED EXERCISE',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: _completedToday ? AppTheme.softSage : accent,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: accent.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(_gameIcons[_todaysGame.id] ?? Icons.gamepad_outlined, size: 28, color: accent),
              ),
              const SizedBox(height: 16),
              Text(
                _todaysGame.name,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Level ${_todaysLevelIndex + 1}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: context.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _todaysGame.description,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: context.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              if (_completedToday)
                const Icon(Icons.check_circle_outline, color: AppTheme.softSage, size: 36)
              else
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.dustyMauve,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                  ),
                  onPressed: _playChallenge,
                  child: Text(
                    'Start Exercise',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Stats summary row
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.bgCard,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DAILY STREAK',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: context.textSecondary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_streak consecutive days',
                    style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: context.textPrimary),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'NEXT PUZZLE IN',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: context.textSecondary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _timeLeft,
                    style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: context.textPrimary),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}
