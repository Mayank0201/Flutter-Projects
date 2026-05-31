import'package:flutter/material.dart';
import'package:google_fonts/google_fonts.dart';
import'screens/splash_screen.dart';
import'screens/home_screen.dart';
import'screens/settings_screen.dart';
import'screens/daily_screen.dart';
import'screens/games/wordle/wordle_screen.dart';
import'screens/games/hangman/hangman_screen.dart';
import'screens/games/weaver/weaver_screen.dart';
import'screens/games/zip/zip_screen.dart';
import'screens/games/crossclimb/crossclimb_screen.dart';
import'screens/games/queens/queens_screen.dart';
import'screens/games/patches/patches_screen.dart';
import'screens/games/connections/connections_screen.dart';
import'screens/games/flagle/flagle_screen.dart';
import'screens/games/wordbuilder/wordbuilder_screen.dart';
import'screens/games/memory/memory_screen.dart';
import'screens/games/spellingbee/spellingbee_screen.dart';
import'screens/games/sudoku/sudoku_screen.dart';
import'screens/games/wordsearch/wordsearch_screen.dart';
import'screens/games/twentyfortyeight/twentyfortyeight_screen.dart';
import'screens/games/reaction/reaction_screen.dart';
import'screens/games/numbermemory/numbermemory_screen.dart';
import'screens/games/sequence/sequence_screen.dart';
import'theme/app_theme.dart';
import'theme/theme_manager.dart';

import'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final prefs = await SharedPreferences.getInstance();
    final activeGame = prefs.getString('daily_backup_active_game');
    if (activeGame != null && activeGame.isNotEmpty) {
      final backupLevel = prefs.getInt('daily_backup_$activeGame');
      if (backupLevel != null) {
        await prefs.setInt('level_$activeGame', backupLevel);
      }
      await prefs.remove('daily_backup_active_game');
      await prefs.remove('daily_backup_$activeGame');
      await prefs.setBool('play_daily_mode', false);
    }
  } catch (_) {}
  runApp(const CogniQApp());
}

class CogniQApp extends StatelessWidget {
  const CogniQApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeNotifier,
      builder: (context, _) {
        return MaterialApp(
          title:'CogniQ',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme.copyWith(
            textTheme: GoogleFonts.interTextTheme(AppTheme.lightTheme.textTheme),
          ),
          darkTheme: AppTheme.darkTheme.copyWith(
            textTheme: GoogleFonts.interTextTheme(AppTheme.darkTheme.textTheme),
          ),
          themeMode: themeNotifier.themeMode,
          initialRoute:'/',
          routes: {
'/': (ctx) => const SplashScreen(),
'/home': (ctx) => const HomeScreen(),
'/settings': (ctx) => const SettingsScreen(),
'/daily': (ctx) => const DailyScreen(),
'/wordle': (ctx) => const WordleScreen(),
'/hangman': (ctx) => const HangmanScreen(),
'/weaver': (ctx) => const WeaverScreen(),
'/zip': (ctx) => const ZipScreen(),
'/crossclimb': (ctx) => const CrossClimbScreen(),
'/queens': (ctx) => const QueensScreen(),
'/chimp': (ctx) => const ChimpScreen(),
'/connections': (ctx) => const ConnectionsScreen(),
'/flagle': (ctx) => const FlagleScreen(),
'/wordbuilder': (ctx) => const WordBuilderScreen(),
'/memory': (ctx) => const MemoryScreen(),
'/spellingbee': (ctx) => const SpellingBeeScreen(),
'/sudoku': (ctx) => const SudokuScreen(),
'/wordsearch': (ctx) => const WordSearchScreen(),
'/2048': (ctx) => const TwentyFortyEightScreen(),
'/reaction': (ctx) => const ReactionScreen(),
'/numbermemory': (ctx) => const NumberMemoryScreen(),
'/sequence': (ctx) => const SequenceScreen(),
          },
        );
      },
    );
  }
}
