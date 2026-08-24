import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/daily_screen.dart';
import 'screens/games/grid_path/grid_path_screen.dart';
import 'screens/games/star_battle/star_battle_screen.dart';
import 'screens/games/chimp_test/chimp_test_screen.dart';
import 'screens/games/word_hive/word_hive_screen.dart';
import 'screens/games/sudoku/sudoku_screen.dart';
import 'screens/games/mine_finder/mine_finder_screen.dart';
import 'screens/games/practice/practice_screen.dart';
import 'screens/games/odd_color_out/odd_color_out_screen.dart';
import 'screens/games/spectrum/spectrum_screen.dart';
import 'screens/games/pattern_lock/pattern_lock_screen.dart';
import 'screens/games/colour_link/colour_link_screen.dart';
import 'screens/games/color_flood/color_flood_screen.dart';
import 'screens/games/circuit_guide/circuit_guide_screen.dart';
import 'screens/games/kakuro/kakuro_screen.dart';
import 'screens/games/sandsort/sandsort_screen.dart';
import 'screens/games/lightbeam/lightbeam_screen.dart';
import 'screens/games/zenslide/zenslide_screen.dart';
import 'screens/games/untangle/untangle_screen.dart';
import 'screens/games/cipher_decoder/cipher_decoder_screen.dart';
import 'screens/games/hitori/hitori_screen.dart';
import 'screens/games/slitherlink/slitherlink_screen.dart';
import 'screens/games/masyu/masyu_screen.dart';
import 'screens/games/bridges/bridges_screen.dart';
import 'screens/games/sum_strike/sum_strike_screen.dart';
import 'screens/games/killer_sudoku/killer_sudoku_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_manager.dart';
import 'utils/audio_manager.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'theme/settings_manager.dart';
import 'utils/ad_manager.dart';
import 'utils/purchase_manager.dart';
import 'utils/update_manager.dart';
import 'utils/restore_manager.dart';
import 'utils/notification_manager.dart';
import 'widgets/swipe_trail_overlay.dart';
import 'utils/prefs_keys.dart';
import 'utils/zen_mode.dart';
import 'utils/analytics/analytics.dart';
import 'utils/streak_manager.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (_) {}
  }
  // Must run before any screen resolves a level key, since Zen Mode changes
  // which key a game reads its progress from.
  try {
    await ZenMode.initialize();
  } catch (e) {
    debugPrint('ZenMode init failed: $e');
  }

  // Analytics state only. Nothing is recorded until the user opts in, and the
  // default sink is a no-op, so this makes no network call — the app's
  // zero-network property is unchanged. The consent dialog is deliberately NOT
  // shown yet: no backend has been chosen, so prompting for permission to
  // collect data that goes nowhere would train people to dismiss the prompt
  // that eventually matters.
  try {
    await Analytics.initialize();
    Analytics.startSession();
  } catch (e) {
    debugPrint('Analytics init failed: $e');
  }

  // Settles any missed days before the UI reads the streak, so a lapse shows up
  // immediately rather than on the next play.
  try {
    await StreakManager.reconcile();
  } catch (e) {
    debugPrint('StreakManager reconcile failed: $e');
  }

  try {
    await AdManager.initialize();
  } catch (e) {
    debugPrint('AdManager init failed: $e');
  }

  try {
    await PurchaseManager.initialize();
  } catch (e) {
    debugPrint('PurchaseManager init failed: $e');
  }

  try {
    await NotificationManager.initialize();
  } catch (e) {
    debugPrint('NotificationManager init failed: $e');
  }

  try {
    AudioManager.init();
  } catch (e) {
    debugPrint('AudioManager init failed: $e');
  }

  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } catch (_) {}

  try {
    final prefs = await SharedPreferences.getInstance();

    final activeGame = prefs.getString(PrefsKeys.dailyBackupActiveGame);
    if (activeGame != null && activeGame.isNotEmpty) {
      final backupLevel = prefs.getInt(PrefsKeys.dailyBackupGame(activeGame));
      if (backupLevel != null) {
        // Always restore into the Challenge-mode key: the daily challenge
        // borrows and restores that slot regardless of which mode is active.
        await prefs.setInt(PrefsKeys.normalGameLevel(activeGame), backupLevel);
      }
      await prefs.remove(PrefsKeys.dailyBackupActiveGame);
      await prefs.remove(PrefsKeys.dailyBackupGame(activeGame));
      await prefs.setBool(PrefsKeys.playDailyMode, false);
    }
  } catch (_) {}

  try {
    await RestoreManager.checkAndHandleRestore();
  } catch (e) {
    debugPrint('RestoreManager check failed: $e');
  }

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
      Analytics.endSession();
    } else if (state == AppLifecycleState.resumed) {
      Analytics.startSession();
      if (settingsNotifier.musicEnabled && !AudioManager.isGameActive) {
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
          navigatorKey: navigatorKey,
          title: 'CogniQ',
          navigatorObservers: [routeObserver],
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
              child: SwipeTrailOverlay(
                accentColor: AppTheme.dustyMauve,
                child: child!,
              ),
            );
          },
          initialRoute: '/',
          routes: {
            '/': (ctx) => const SplashScreen(),
            '/home': (ctx) => const HomeScreen(),
            '/daily': (ctx) => const DailyScreen(),
            '/zip': (ctx) => const GridPathScreen(),
            '/queens': (ctx) => const StarBattleScreen(),
            '/chimp': (ctx) => const ChimpTestScreen(),
            '/spellingbee': (ctx) => const WordHiveScreen(),
            '/sudoku': (ctx) => const SudokuScreen(),
            '/minesweeper': (ctx) => const MineFinderScreen(),
            '/oddcolor': (ctx) => const OddColorOutScreen(),
            '/hue': (ctx) => const SpectrumScreen(),
            '/pattern_lock': (ctx) => const PatternLockScreen(),
            '/colour_link': (ctx) => const ColourLinkScreen(),
            '/color_flood': (ctx) => const ColorFloodScreen(),
            '/circuit_guide': (ctx) => const CircuitGuideScreen(),
            '/kakuro': (ctx) => const KakuroScreen(),
            '/sandsort': (ctx) => const SandSortScreen(),
            '/lightbeam': (ctx) => const LightBeamScreen(),
        '/zenslide': (ctx) => const ZenSlideScreen(),
        '/untangle': (ctx) => const UntangleScreen(),
            '/cipher_decoder': (ctx) => const CipherDecoderScreen(),
            '/hitori': (ctx) => const HitoriScreen(),
            '/slitherlink': (ctx) => const SlitherlinkScreen(),
            '/masyu': (ctx) => const MasyuScreen(),
            '/bridges': (ctx) => const BridgesScreen(),
            '/sumstrike': (ctx) => const SumStrikeScreen(),
            '/killersudoku': (ctx) => const KillerSudokuScreen(),
            '/practice': (ctx) => const PracticeScreen(),
          },
        );
      },
    );
  }
}
