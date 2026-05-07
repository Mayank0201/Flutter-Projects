import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'game/flow_grid_game.dart';
import 'ui/main_menu_overlay.dart';
import 'ui/game_hud_overlay.dart';
import 'ui/game_over_overlay.dart';
import 'ui/weekly_upgrade_overlay.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Force landscape and hide system UI for immersive gameplay
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  runApp(const FlowGridApp());
}

class FlowGridApp extends StatelessWidget {
  const FlowGridApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flow Grid',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE74C3C),
          brightness: Brightness.dark,
        ),
      ),
      home: const GamePage(),
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final FlowGridGame _game;

  @override
  void initState() {
    super.initState();
    _game = FlowGridGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget<FlowGridGame>(
        game: _game,
        overlayBuilderMap: {
          'mainMenu': (context, game) => MainMenuOverlay(game: game),
          'hud': (context, game) => GameHudOverlay(game: game),
          'gameOver': (context, game) => GameOverOverlay(game: game),
          'weeklyUpgrade': (context, game) =>
              WeeklyUpgradeOverlay(game: game),
        },
      ),
    );
  }
}
