import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../theme/settings_manager.dart';
import '../utils/audio_manager.dart';
import '../utils/daily_challenge_manager.dart';
import '../utils/recently_played_manager.dart';
import '../utils/challenge_reminder_helper.dart';
import '../utils/activity_tracker.dart';
import '../utils/prefs_keys.dart';
import '../widgets/confetti_overlay.dart';
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
  'minesweeper': Icons.dangerous_outlined,
  'numbermemory': Icons.pin_outlined,
  'sequence':    Icons.pattern_outlined,
  'oddcolor':    Icons.palette_outlined,
  'hue':         Icons.color_lens_outlined,
  'kakuro':      Icons.border_all_outlined,
  'cipherdecoder': Icons.vpn_key_outlined,
  'hitori':      Icons.grid_on_outlined,
  'slitherlink': Icons.loop_outlined,
};

class DailyScreen extends StatefulWidget {
  final bool isEmbedded;
  const DailyScreen({super.key, this.isEmbedded = false});

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> {
  int _streak = 0;
  int _perfectDays = 0;
  int _completedTodayCount = 0;
  bool _completedEasy = false;
  bool _completedMedium = false;
  bool _completedHard = false;
  String _dateStr = '';
  List<DailyChallenge> _challenges = [];
  bool _loading = true;
  Timer? _countdownTimer;
  String _timeLeft = '';
  int _activeDay = 1;
  DateTime? _challengeStartTime;
  DateTime _currentDate = DateTime.now().toUtc();

  int _bronzeCount = 0;
  int _silverCount = 0;
  int _goldCount = 0;

  int _weeklyPerfectStreak = 0;
  int _diamondStars = 0;
  List<String> _perfectWeekHistory = [];

  @override
  void initState() {
    super.initState();
    _loadDailyState();
    _startCountdown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ChallengeReminderHelper.checkAndShowReminder(context);
    });
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
    if (_challengeStartTime == null) return '24:00:00';
    final now = DateTime.now().toUtc();
    final target = _challengeStartTime!.add(const Duration(hours: 24));
    if (now.isAfter(target)) return '00:00:00';
    final diff = target.difference(now);
    final h = diff.inHours.toString().padLeft(2, '0');
    final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _loadDailyState() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toUtc();
    _currentDate = now;
    _dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    _activeDay = await DailyChallengeManager.getActiveDay();
    _challenges = DailyChallengeManager.getChallengesForDay(_activeDay);
    _streak = await DailyChallengeManager.getOrUpdateStreak(_dateStr);
    _perfectDays = await DailyChallengeManager.getPerfectDays();

    _completedEasy = await DailyChallengeManager.isChallengeCompleted('Easy', _dateStr);
    _completedMedium = await DailyChallengeManager.isChallengeCompleted('Medium', _dateStr);
    _completedHard = await DailyChallengeManager.isChallengeCompleted('Hard', _dateStr);

    _completedTodayCount = 0;
    if (_completedEasy) _completedTodayCount++;
    if (_completedMedium) _completedTodayCount++;
    if (_completedHard) _completedTodayCount++;

    _bronzeCount = prefs.getInt('daily_bronze_stars') ?? 0;
    _silverCount = prefs.getInt('daily_silver_stars') ?? 0;
    _goldCount = prefs.getInt('daily_gold_stars') ?? 0;
    _weeklyPerfectStreak = await DailyChallengeManager.getOrUpdatePerfectStreak(_dateStr);
    _diamondStars = prefs.getInt(PrefsKeys.diamondStars) ?? 0;
    _perfectWeekHistory = prefs.getStringList(PrefsKeys.perfectWeekHistory) ?? [];

    final startTimeStr = prefs.getString('daily_challenge_start_time') ?? '';
    if (startTimeStr.isNotEmpty) {
      _challengeStartTime = DateTime.parse(startTimeStr);
    } else {
      _challengeStartTime = now;
    }

    if (mounted) {
      setState(() {
        _loading = false;
        _timeLeft = _calculateTimeLeft();
      });
    }
  }

  Future<void> _playChallenge(DailyChallenge challenge) async {
    final difficulty = challenge.difficulty;
    final isCompleted = await DailyChallengeManager.isChallengeCompleted(difficulty, _dateStr);
    if (isCompleted) return;

    final game = challenge.game;
    final gameId = game.id;
    final levelKey = 'level_$gameId';
    final levelIndex = challenge.levelIndex;

    final prefs = await SharedPreferences.getInstance();

    final realLevel = prefs.getInt(levelKey) ?? 0;
    await prefs.setInt('daily_backup_$gameId', realLevel);
    await prefs.setString('daily_backup_active_game', gameId);

    await prefs.setInt(levelKey, levelIndex);
    await DailyChallengeManager.setupDailyModifier(challenge);
    await RecentlyPlayedManager.addGame(gameId);

    if (!mounted) return;
    settingsNotifier.hapticTap();

    String variantMsg = "";
    if (challenge.modifierName.isNotEmpty) {
      variantMsg = "Daily Variant: ${challenge.modifierName.toUpperCase()}!\n\n${challenge.modifierDescription}";
    }

    if (variantMsg.isNotEmpty) {
      bool proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: context.bgCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: context.textMuted.withAlpha(40)),
          ),
          title: Row(
            children: [
              const Icon(Icons.star, color: Colors.amber),
              const SizedBox(width: 8),
              Text('Special Daily Rule!', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary)),
            ],
          ),
          content: Text(variantMsg, style: GoogleFonts.outfit(color: context.textSecondary, fontSize: 16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textMuted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Play!', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.dustyMauve)),
            ),
          ],
        ),
      ) ?? false;
      if (!proceed) {
        await prefs.setInt(levelKey, realLevel);
        await DailyChallengeManager.clearDailyModifier();
        await prefs.remove('daily_backup_$gameId');
        await prefs.remove('daily_backup_active_game');
        return;
      }
    }
    
    if (!mounted) return;
    AudioManager.fadeOutMusic();
    ActivityTracker.trackGamePlay(game.id);
    final result = await Navigator.pushNamed(context, game.routeName);
    AudioManager.fadeInMusic();

    final updatedPrefs = await SharedPreferences.getInstance();
    final postLevel = updatedPrefs.getInt(levelKey) ?? 0;

    if (result == true) {
      settingsNotifier.hapticSuccess();
      final oldDiamonds = _diamondStars;
      await DailyChallengeManager.completeChallenge(difficulty, _dateStr, gameId);
      
      await _loadDailyState();
      
      if (_diamondStars > oldDiamonds) {
        _showPerfectWeekDialog();
      } else if (_completedTodayCount == 3) {
        _showPerfectDayDialog();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Challenge cleared! +25 points earned.',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              backgroundColor: AppTheme.wordleGreen,
            ),
          );
        }
      }
    }

    await updatedPrefs.setInt(levelKey, realLevel);
    await updatedPrefs.remove('daily_backup_$gameId');
    await updatedPrefs.remove('daily_backup_active_game');
    await DailyChallengeManager.clearDailyModifier();
  }

  void _showPerfectWeekDialog() {
    AudioManager.playSuccess();
    settingsNotifier.hapticSuccess();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Stack(
          children: [
            const ConfettiOverlayWidget(accentColor: Colors.cyan),
            AlertDialog(
              backgroundColor: context.bgCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.elasticOut,
                    builder: (context, val, child) {
                      return Transform.scale(
                        scale: val,
                        child: Transform.rotate(
                          angle: val * 2 * pi,
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      width: 100,
                      height: 100,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.cyan.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.cyan, width: 2),
                      ),
                      child: const Text('💎', style: TextStyle(fontSize: 48)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'PERFECT WEEK ACCOMPLISHED!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You have cleared 7 perfect days in a row and earned a Diamond Star!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: context.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      settingsNotifier.hapticTap();
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyan,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: Text('AWESOME!', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }


  List<Color> _themeGradient(String themeName) {
    final lower = themeName.toLowerCase();
    if (lower.contains('fog') || lower.contains('whisper') || lower.contains('chaos')) {
      return const [Color(0xFF232526), Color(0xFF414345)]; // Charcoal slate
    }
    if (lower.contains('mirror') || lower.contains('hidden') || lower.contains('nightmare')) {
      return const [Color(0xFF2C3E50), Color(0xFFFD746C)]; // Dark orange/red
    }
    if (lower.contains('monochrome') || lower.contains('zoom') || lower.contains('prism')) {
      return const [Color(0xFF0F2027), Color(0xFF2C5364)]; // Midnight ocean
    }
    if (lower.contains('retro') || lower.contains('eclipse') || lower.contains('time')) {
      return const [Color(0xFF114357), Color(0xFFF29492)]; // Retro sunrise
    }
    return const [Color(0xFF3A1C71), Color(0xFFD76D77)]; // Royal violet sunset
  }

  void _showPerfectDayDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Center(
          child: Column(
            children: [
              const Icon(Icons.star, size: 48, color: Colors.amber),
              const SizedBox(height: 8),
              Text(
                'Perfect Day!',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: AppTheme.warmAmber, fontSize: 22),
              ),
            ],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You completed all 3 challenges today!',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: context.textPrimary, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              'Streak is active and a Gold Star has been added to your calendar.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: context.textSecondary, fontSize: 13),
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warmAmber,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(ctx),
              child: Text('Awesome', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final progressVal = _completedTodayCount / 3.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: CircularProgressIndicator(
                      value: progressVal,
                      strokeWidth: 6,
                      backgroundColor: context.textMuted.withAlpha(30),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.dustyMauve),
                    ),
                  ),
                  Text(
                    '$_completedTodayCount/3',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 18),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '$_streak Day Streak',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: context.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '$_perfectDays Perfect Days',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: context.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: context.textMuted.withOpacity(0.15), height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStarStat('★', const Color(0xFFCD7F32), 'Bronze', _bronzeCount),
              _buildStarStat('★', const Color(0xFFC0C0C0), 'Silver', _silverCount),
              _buildStarStat('★', const Color(0xFFFFD700), 'Gold', _goldCount),
              _buildStarStat('💎', Colors.cyanAccent, 'Diamond', _diamondStars),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStarStat(String symbol, Color color, String label, int count) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(symbol, style: TextStyle(color: color, fontSize: 16)),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10,
            color: context.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyDayItem(DateTime day) {
    final dateStr = "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
    final isToday = dateStr == _dateStr;
    final dayName = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day.weekday - 1];

    return Expanded(
      child: FutureBuilder<int>(
        future: DailyChallengeManager.getCompletedCountForDate(dateStr),
        builder: (context, snapshot) {
          final count = snapshot.data ?? 0;
          Widget statusIndicator;
          if (count == 3) {
            statusIndicator = const Text('★', style: TextStyle(color: Color(0xFFFFD700), fontSize: 13, fontWeight: FontWeight.bold));
          } else if (count == 2) {
            statusIndicator = const Text('★', style: TextStyle(color: Color(0xFFC0C0C0), fontSize: 13, fontWeight: FontWeight.bold));
          } else if (count == 1) {
            statusIndicator = const Text('★', style: TextStyle(color: Color(0xFFCD7F32), fontSize: 13, fontWeight: FontWeight.bold));
          } else {
            statusIndicator = Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: context.textMuted.withAlpha(55),
                shape: BoxShape.circle,
              ),
            );
          }

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isToday ? AppTheme.dustyMauve.withAlpha(30) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isToday ? Border.all(color: AppTheme.dustyMauve.withAlpha(80), width: 1.5) : null,
            ),
            child: Column(
              children: [
                Text(
                  dayName,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    color: isToday ? AppTheme.dustyMauve : context.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${day.day}',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 18,
                  child: Center(child: statusIndicator),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChallengeCard(DailyChallenge challenge, bool isCompleted) {
    final game = challenge.game;
    final accent = AppTheme.accentFor(game.id);
    final icon = _gameIcons[game.id] ?? Icons.gamepad_outlined;

    Color diffColor;
    if (challenge.difficulty == 'Easy') {
      diffColor = AppTheme.softSage;
    } else if (challenge.difficulty == 'Medium') {
      diffColor = AppTheme.warmAmber;
    } else {
      diffColor = AppTheme.dustyMauve;
    }

    return Card(
      color: context.bgCard,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isCompleted ? AppTheme.softSage.withAlpha(80) : context.textMuted.withAlpha(20),
          width: isCompleted ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: isCompleted ? null : () => _playChallenge(challenge),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isCompleted ? AppTheme.softSage.withAlpha(25) : accent.withAlpha(25),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isCompleted ? Icons.check_circle_rounded : icon,
                  color: isCompleted ? AppTheme.softSage : accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${challenge.difficulty} Challenge',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: context.textSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: diffColor.withAlpha(30),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            challenge.difficulty,
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: diffColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      game.name,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${challenge.modifierName}: ${challenge.modifierDescription}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: context.textMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isCompleted)
                Text(
                  'DONE',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.softSage,
                  ),
                )
              else
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: context.textMuted.withAlpha(120),
                  size: 14,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStarsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('★', style: const TextStyle(color: Color(0xFFCD7F32), fontSize: 18)),
        const SizedBox(width: 2),
        Text('$_bronzeCount', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: context.textPrimary)),
        const SizedBox(width: 14),
        Text('★', style: const TextStyle(color: Color(0xFFC0C0C0), fontSize: 18)),
        const SizedBox(width: 2),
        Text('$_silverCount', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: context.textPrimary)),
        const SizedBox(width: 14),
        Text('★', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 18)),
        const SizedBox(width: 2),
        Text('$_goldCount', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: context.textPrimary)),
        const SizedBox(width: 14),
        const Text('💎', style: TextStyle(fontSize: 16)),
        const SizedBox(width: 2),
        Text('$_diamondStars', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: context.textPrimary)),
      ],
    );
  }

  Widget _buildPerfectWeekTracker() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PERFECT WEEK STREAK',
                  style: GoogleFonts.outfit(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: context.textSecondary,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  '$_weeklyPerfectStreak / 7 Days',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.cyan,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final isCompleted = index < _weeklyPerfectStreak;
              final isCurrent = index == _weeklyPerfectStreak;
              
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isCompleted ? Colors.cyan.withOpacity(0.15) : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCompleted
                            ? Colors.cyan
                            : isCurrent
                                ? Colors.cyan.withOpacity(0.8)
                                : context.textMuted.withAlpha(50),
                        width: isCurrent ? 2.0 : 1.2,
                      ),
                    ),
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.cyan, size: 16)
                        : Text(
                            '${index + 1}',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isCurrent ? Colors.cyan : context.textMuted,
                            ),
                          ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final week = DailyChallengeManager.weekOf(_activeDay);
    final dayInWeek = DailyChallengeManager.dayInWeekOf(_activeDay);
    final theme = DailyChallengeManager.themeOf(_activeDay);
    
    // Find active weekly modifier description
    final activeDesc = DailyChallengeManager.themeDescriptionOf(_activeDay);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      children: [
        if (widget.isEmbedded) ...[
          const SizedBox(height: 10),
          Text(
            'Weekly Gauntlet',
            style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: context.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Complete 3 daily mind exercises to keep your streak alive.',
            style: GoogleFonts.outfit(fontSize: 13, color: context.textSecondary),
          ),
          const SizedBox(height: 16),
          _buildStarsRow(),
          const SizedBox(height: 16),
        ],

        // 1. Weekly Theme Banner Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _themeGradient(theme),
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${theme.toUpperCase()} WEEK',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                activeDesc,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.85),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Text(
          'Week $week of 14 • Day $dayInWeek of 7 • progress day $_activeDay',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(fontSize: 13, color: context.textSecondary, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),

        _buildSummaryCard(),
        const SizedBox(height: 20),

        // 2. Perfect Week Streak checklist nodes
        _buildPerfectWeekTracker(),
        const SizedBox(height: 20),

        // 3. Weekly Calendar Stars Tracker Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.bgCard,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'WEEKLY STARS (CALENDAR)',
                  style: GoogleFonts.outfit(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: context.textSecondary,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (i) => _currentDate.subtract(Duration(days: 6 - i)))
                    .map((day) => _buildWeeklyDayItem(day))
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 4. Three Challenge Cards
        if (_challenges.length >= 3) ...[
          _buildChallengeCard(_challenges[0], _completedEasy),
          _buildChallengeCard(_challenges[1], _completedMedium),
          _buildChallengeCard(_challenges[2], _completedHard),
        ],
        const SizedBox(height: 10),

        // 5. Countdown timer card
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: context.bgCard,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: [
              Text(
                'NEXT CHALLENGE IN',
                style: GoogleFonts.outfit(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: context.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _timeLeft,
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SizedBox(height: 40),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: context.bgDark,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (widget.isEmbedded) {
      return _buildBody(context);
    }

    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        backgroundColor: context.bgDark,
        foregroundColor: context.textPrimary,
        elevation: 0,
        title: Text(
          'Weekly Gauntlet',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: context.textPrimary),
        ),
        actions: [
          // IconButton(
          //   icon: const Icon(Icons.bug_report_outlined, color: Colors.amber, size: 20),
          //   onPressed: () {
          //     Navigator.pushNamed(context, '/daily_test');
          //   },
          //   tooltip: 'Debug 90 Challenges',
          // ),
          // Star Counter Badge Row
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                Text('★', style: const TextStyle(color: Color(0xFFCD7F32), fontSize: 16)),
                const SizedBox(width: 2),
                Text('$_bronzeCount', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: context.textPrimary)),
                const SizedBox(width: 8),
                Text('★', style: const TextStyle(color: Color(0xFFC0C0C0), fontSize: 16)),
                const SizedBox(width: 2),
                Text('$_silverCount', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: context.textPrimary)),
                const SizedBox(width: 8),
                Text('★', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 16)),
                const SizedBox(width: 2),
                Text('$_goldCount', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: context.textPrimary)),
                const SizedBox(width: 8),
                const Text('💎', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 2),
                Text('$_diamondStars', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: context.textPrimary)),
              ],
            ),
          ),
        ],
        centerTitle: false,
      ),
      body: SafeArea(
        child: _buildBody(context),
      ),
    );
  }
}
