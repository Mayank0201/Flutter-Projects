import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game/flow_grid_game.dart';
import 'ui/main_menu_overlay.dart';
import 'ui/game_hud_overlay.dart';
import 'ui/game_over_overlay.dart';
import 'ui/weekly_upgrade_overlay.dart';
import 'ui/map_selection_overlay.dart';
import 'ui/save_slot_overlay.dart';
import 'ui/tutorial_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force landscape and hide system UI for immersive gameplay
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flow Grid',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late FlowGridGame _game;

  @override
  void initState() {
    super.initState();
    _game = FlowGridGame();
  }

  @override
  Widget build(BuildContext context) {
    return GameWidget(
      game: _game,
      overlayBuilderMap: {
        'mainMenu': (context, FlowGridGame game) => MainMenuOverlay(game: game),
        'mapSelection': (context, FlowGridGame game) => MapSelectionOverlay(game: game),
        'gameOver': (context, FlowGridGame game) => GameOverOverlay(game: game),
        'weeklyUpgrade': (context, FlowGridGame game) => WeeklyUpgradeOverlay(game: game),
        'hud': (context, FlowGridGame game) => GameHudOverlay(game: game),
        'saveSlot': (context, FlowGridGame game) => SaveSlotOverlay(game: game),
        'tutorial': (context, FlowGridGame game) => TutorialOverlay(game: game),
      },
    );
  }
}
