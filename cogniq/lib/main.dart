import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/daily_screen.dart';
// import 'screens/daily_challenge_test_screen.dart';
import 'screens/games/word_guess/word_guess_screen.dart';
import 'screens/games/hangman/hangman_screen.dart';
import 'screens/games/word_ladder/word_ladder_screen.dart';
import 'screens/games/grid_path/grid_path_screen.dart';
import 'screens/games/word_climb/word_climb_screen.dart';
import 'screens/games/star_battle/star_battle_screen.dart';
import 'screens/games/patches/patches_screen.dart';
import 'screens/games/categories/categories_screen.dart';
import 'screens/games/flag_finder/flag_finder_screen.dart';
import 'screens/games/word_builder/word_builder_screen.dart';
import 'screens/games/mahjong/mahjong_screen.dart';
import 'screens/games/word_hive/word_hive_screen.dart';
import 'screens/games/sudoku/sudoku_screen.dart';
import 'screens/games/word_search/word_search_screen.dart';
import 'screens/games/mine_finder/mine_finder_screen.dart';

import 'screens/games/nonogram/nonogram_screen.dart';
import 'screens/games/number_memory/number_memory_screen.dart';
import 'screens/games/sequence_memory/sequence_memory_screen.dart';
import 'screens/games/odd_color_out/odd_color_out_screen.dart';
import 'screens/games/spectrum/spectrum_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_manager.dart';
import 'utils/audio_manager.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'theme/settings_manager.dart';
import 'utils/ad_manager.dart';
import 'utils/purchase_manager.dart';
import 'utils/update_manager.dart';
import 'utils/restore_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (_) {}
  }
  await AdManager.initialize();
  await PurchaseManager.initialize();
  AudioManager.init();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
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
  await RestoreManager.checkAndHandleRestore();
  runApp(const CogniQApp());
}

class CogniQApp extends StatefulWidget {
  const CogniQApp({super.key});

  @override
  State<CogniQApp> createState() => _CogniQAppState();
}

class _CogniQAppState extends State<CogniQApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateManager.checkForUpdate();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      AudioManager.stopMusic();
    } else if (state == AppLifecycleState.resumed) {
      if (settingsNotifier.musicEnabled) {
        AudioManager.fadeInMusic();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([themeNotifier, settingsNotifier]),
      builder: (context, _) {
        return MaterialApp(
          title: 'CogniQ',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme.copyWith(
            textTheme: GoogleFonts.outfitTextTheme(
              AppTheme.lightTheme.textTheme,
            ),
          ),
          darkTheme: AppTheme.darkTheme.copyWith(
            textTheme: GoogleFonts.outfitTextTheme(
              AppTheme.darkTheme.textTheme,
            ),
          ),
          themeMode: themeNotifier.themeMode,
          builder: (context, child) {
            final mediaQueryData = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQueryData.copyWith(
                textScaleFactor:
                    mediaQueryData.textScaleFactor * settingsNotifier.fontScale,
              ),
              child: child!,
            );
          },
          initialRoute: '/',
          routes: {
            '/': (ctx) => const SplashScreen(),
            '/home': (ctx) => const HomeScreen(),
            '/settings': (ctx) => const SettingsScreen(),
            '/daily': (ctx) => const DailyScreen(),
            // '/daily_test': (ctx) => const DailyChallengeTestScreen(),
            '/wordle': (ctx) => const WordGuessScreen(),
            '/hangman': (ctx) => const HangmanScreen(),
            '/weaver': (ctx) => const WordLadderScreen(),
            '/zip': (ctx) => const GridPathScreen(),
            '/crossclimb': (ctx) => const WordClimbScreen(),
            '/queens': (ctx) => const StarBattleScreen(),
            '/chimp': (ctx) => const ChimpTestScreen(),
            '/connections': (ctx) => const CategoriesScreen(),
            '/flagle': (ctx) => const FlagFinderScreen(),
            '/wordbuilder': (ctx) => const WordBuilderScreen(),
            '/memory': (ctx) => const MahjongScreen(),
            '/spellingbee': (ctx) => const WordHiveScreen(),
            '/sudoku': (ctx) => const SudokuScreen(),
            '/wordsearch': (ctx) => const WordSearchScreen(),
            '/minesweeper': (ctx) => const MineFinderScreen(),
            // '/reaction': (ctx) => const ReactionScreen(),
            '/nonogram': (ctx) => const NonogramScreen(),
            '/numbermemory': (ctx) => const NumberMemoryScreen(),
            '/sequence': (ctx) => const SequenceMemoryScreen(),
            '/oddcolor': (ctx) => const OddColorOutScreen(),
            '/hue': (ctx) => const SpectrumScreen(),
          },
        );
      },
    );
  }
}
