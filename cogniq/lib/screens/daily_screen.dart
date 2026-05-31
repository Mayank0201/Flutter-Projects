import'dart:async';
import'package:flutter/material.dart';
import'package:google_fonts/google_fonts.dart';
import'package:shared_preferences/shared_preferences.dart';
import'../models/game_info.dart';
import'../theme/app_theme.dart';
import'../theme/settings_manager.dart';

class DailyScreen extends StatefulWidget {
  const DailyScreen({super.key});
  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> {
  int _streak = 0;
  bool _completedToday = false;
  String _dateStr ='';
  late GameInfo _todaysGame;
  int _todaysLevelIndex = 0;
  bool _loading = true;
  Timer? _countdownTimer;
  String _timeLeft ='';

  @override
  void initState() {
    super.initState();
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
    final h = diff.inHours.toString().padLeft(2,'0');
    final m = (diff.inMinutes % 60).toString().padLeft(2,'0');
    final s = (diff.inSeconds % 60).toString().padLeft(2,'0');
    return'$h:$m:$s';
  }

  Future<void> _loadDailyState() async {
    final now = DateTime.now().toUtc();
    _dateStr ="${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}";
    final seed = now.year * 10000 + now.month * 100 + now.day;

    // Pick game deterministically
    _todaysGame = kAllGames[seed % kAllGames.length];
    _todaysLevelIndex = (seed * 7) % 30; // levels 0-29

    final prefs = await SharedPreferences.getInstance();
    
    // Check streak validity
    final lastCompleted = prefs.getString('daily_last_completed_date') ??'';
    _streak = prefs.getInt('daily_streak') ?? 0;

    if (lastCompleted.isNotEmpty && lastCompleted != _dateStr) {
      final lastDate = DateTime.parse(lastCompleted);
      final todayDate = DateTime.utc(now.year, now.month, now.day);
      final diff = todayDate.difference(lastDate).inDays;
      if (diff > 1) {
        // Streak broken
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
    final levelKey ='level_$gameId';

    // 1. Back up current real level progress
    final realLevel = prefs.getInt(levelKey) ?? 0;
    await prefs.setInt('daily_backup_$gameId', realLevel);
    await prefs.setString('daily_backup_active_game', gameId);

    // 2. Set level to today's challenge level
    await prefs.setInt(levelKey, _todaysLevelIndex);
    await prefs.setBool('play_daily_mode', true);

    if (!mounted) return;
    settingsNotifier.hapticTap();

    // 3. Navigate to game screen
    final result = await Navigator.pushNamed(context, _todaysGame.routeName);

    // 4. Return from game screen -> Restore backup and process results
    final updatedPrefs = await SharedPreferences.getInstance();
    final postLevel = updatedPrefs.getInt(levelKey) ?? 0;

    // Did they clear the target level? (The game increments levelKey on success)
    if (postLevel > _todaysLevelIndex || result == true) {
      // Completed!
      settingsNotifier.hapticSuccess();
      
      // Update streak
      int newStreak = _streak;
      final lastCompleted = updatedPrefs.getString('daily_last_completed_date') ??'';
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

    // 5. Always restore the real level index
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
            style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: AppTheme.wordleGreen, fontSize: 22),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Text(
'$_streak',
              style: GoogleFonts.outfit(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.orangeAccent),
            ),
            Text(
'Day Streak',
              style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Text(
'You cleared today\'s challenge in ${_todaysGame.name}!',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: context.textPrimary, fontSize: 15),
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.wordleGreen,
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: context.bgDark,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final accentColor = AppTheme.accentFor(_todaysGame.id);

    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        backgroundColor: context.bgDark,
        foregroundColor: context.textPrimary,
        title: Text('Daily Challenge', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Streak Display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: context.bgCard,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('', style: TextStyle(fontSize: context.scale(28))),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
'$_streak Day Streak',
                          style: GoogleFonts.outfit(
                            fontSize: context.scale(18),
                            fontWeight: FontWeight.w800,
                            color: context.textPrimary,
                          ),
                        ),
                        Text(
                          _completedToday ?'Completed today':'Play today to keep it active',
                          style: GoogleFonts.outfit(
                            fontSize: context.scale(11),
                            color: context.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Today's Game Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: context.bgCard,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _completedToday ? AppTheme.wordleGreen.withAlpha(80) : accentColor.withAlpha(50),
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _completedToday ?'CHALLENGE COMPLETED':'TODAY\'S PUZLE',
                      style: GoogleFonts.outfit(
                        fontSize: context.scale(11),
                        fontWeight: FontWeight.w800,
                        color: _completedToday ? AppTheme.wordleGreen : accentColor,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _todaysGame.emoji,
                      style: TextStyle(fontSize: context.scale(56)),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _todaysGame.name,
                      style: GoogleFonts.outfit(
                        fontSize: context.scale(24),
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
'Level ${_todaysLevelIndex + 1}',
                      style: GoogleFonts.outfit(
                        fontSize: context.scale(14),
                        fontWeight: FontWeight.w600,
                        color: context.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _todaysGame.description,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: context.scale(13),
                        color: context.textMuted,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_completedToday) ...[
                      Icon(Icons.check_circle_rounded, color: AppTheme.wordleGreen, size: context.scale(40)),
                      const SizedBox(height: 12),
                      Text(
'Nice job! Come back tomorrow.',
                        style: GoogleFonts.outfit(color: context.textSecondary, fontSize: context.scale(13), fontWeight: FontWeight.w600),
                      ),
                    ] else ...[
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: _playChallenge,
                        child: Text(
'START CHALLENGE',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: context.scale(14), letterSpacing: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              // Countdown timer
              Column(
                children: [
                  Text(
'NEXT CHALLENGE IN',
                    style: GoogleFonts.outfit(
                      fontSize: context.scale(10),
                      fontWeight: FontWeight.w700,
                      color: context.textMuted,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _timeLeft,
                    style: GoogleFonts.outfit(
                      fontSize: context.scale(22),
                      fontWeight: FontWeight.w800,
                      color: context.textSecondary,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
