import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../utils/audio_manager.dart';
import '../utils/daily_challenge_manager.dart';
import '../utils/recently_played_manager.dart';

class DailyChallengeTestScreen extends StatelessWidget {
  const DailyChallengeTestScreen({super.key});

  Future<void> _playChallenge(BuildContext context, DailyChallenge challenge) async {
    final game = challenge.game;
    final gameId = game.id;
    final levelKey = 'level_$gameId';
    final levelIndex = challenge.levelIndex;

    final prefs = await SharedPreferences.getInstance();

    final stateKeyMap = {
      'minesweeper': 'daily_minesweeper_state',
      'flagle': 'daily_flagle_state',
      'wordle': 'daily_wordle_state',
      'queens': 'daily_queens_state',
      'memory': 'daily_memory_state',
      'numbermemory': 'daily_numbermemory_state',
      'wordbuilder': 'daily_wordbuilder_state',
      'sudoku': 'daily_sudoku_state',
      'spellingbee': 'daily_spellingbee_state',
    };
    final stateKey = stateKeyMap[gameId];
    if (stateKey != null) {
      await prefs.remove(stateKey);
    }

    // Backup current level
    final realLevel = prefs.getInt(levelKey) ?? 0;
    await prefs.setInt('daily_backup_$gameId', realLevel);
    await prefs.setString('daily_backup_active_game', gameId);

    // Set level index & modifier for daily mode
    await prefs.setInt(levelKey, levelIndex);
    await DailyChallengeManager.setupDailyModifier(challenge);
    await RecentlyPlayedManager.addGame(gameId);

    // Play tap sound/haptic if possible (silently ignored if settings are not loaded)
    AudioManager.fadeOutMusic();
    if (context.mounted) {
      await Navigator.pushNamed(context, game.routeName);
    }
    AudioManager.fadeInMusic();

    // Restore original level & clean up modifier
    final updatedPrefs = await SharedPreferences.getInstance();
    await updatedPrefs.setInt(levelKey, realLevel);
    await updatedPrefs.remove('daily_backup_$gameId');
    await updatedPrefs.remove('daily_backup_active_game');
    await DailyChallengeManager.clearDailyModifier();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        backgroundColor: context.bgDark,
        foregroundColor: context.textPrimary,
        elevation: 0,
        title: Text(
          '90 Challenges Debugger',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 30,
          itemBuilder: (context, index) {
            final dayNum = index + 1;
            final challenges = DailyChallengeManager.getChallengesForDay(dayNum);

            return Container(
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: context.bgCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.textMuted.withAlpha(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Day Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.dustyMauve.withAlpha(20),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Day $dayNum',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppTheme.dustyMauve,
                          ),
                        ),
                        Text(
                          'Active progression day',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Easy/Medium/Hard Challenges
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Column(
                      children: challenges.map((challenge) {
                        Color diffColor;
                        if (challenge.difficulty == 'Easy') {
                          diffColor = AppTheme.softSage;
                        } else if (challenge.difficulty == 'Medium') {
                          diffColor = AppTheme.warmAmber;
                        } else {
                          diffColor = AppTheme.dustyMauve;
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: context.bgDark.withAlpha(100),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: diffColor.withAlpha(30)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            onTap: () => _playChallenge(context, challenge),
                            title: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: diffColor.withAlpha(20),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    challenge.difficulty.toUpperCase(),
                                    style: GoogleFonts.outfit(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: diffColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  challenge.game.name,
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: context.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                '${challenge.modifierName}: ${challenge.modifierDescription}',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: context.textSecondary,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            trailing: Icon(
                              Icons.play_arrow_rounded,
                              color: diffColor,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
