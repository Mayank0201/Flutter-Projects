import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../utils/prefs_keys.dart';
import '../../../utils/hint_manager.dart';
import '../../../utils/rotation_engine.dart';
import '../../../widgets/loss_overlay.dart';
import '../../../widgets/auto_next_countdown.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  final gameId = "practice";
  int level = 1;
  int hints = 1;
  bool hintUsed = false;
  Set<String> _activeModifiers = {};
  bool isGameOver = false;
  bool isSuccess = false;

  SharedPreferences? _prefs;
  @override
  void initState() {
    super.initState();
    _initState();
  }

  Future<void> useHint() async {
    if (hints > 0 && !hintUsed) {
      setState(() {
        hints--;
        hintUsed = true;
      });
      await HintManager.useHint(gameId);
    }
  }

  // COGNIQ-FIX:mod-active-helper
  bool _isModActive(String name) {
    return level >= RotationEngine.modifierStartLevel(gameId) &&
        _activeModifiers.contains(name);
  }

  Future<void> _initState() async {
    _prefs = await SharedPreferences.getInstance();

    final pool = ['fog', 'time_limit', 'no_hints'];

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (args != null && args.containsKey('level')) {
      level = args['level'] as int;
    } else {
      level = _prefs!.getInt(PrefsKeys.gameLevel(gameId)) ?? 1;
    }
    _activeModifiers = RotationEngine.getActiveModifiers(
      gameId: gameId,
      levelIndex: level,
      pool: pool,
    );
    int h = await HintManager.startLevel(gameId);
    if (mounted) {
      setState(() {
        hints = h;
      });
    }
  }

  Future<void> _onClick() async {
    await _prefs!.setInt(PrefsKeys.gameLevel(gameId), level);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Stack(
          children: [
            Column(
              children: [
                Text("$level"),
                ElevatedButton(
                  onPressed: () async {
                    setState(() {
                      level++;
                    });
                    await _onClick();
                  },
                  child: Text("Increment and Save"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await useHint();
                  },
                  child: Text("Use Hint ($hints left)"),
                ),
                Text(_activeModifiers.toString()),
                ElevatedButton(
                  onPressed: () async {
                    await _onClick();
                    await HintManager.onLevelCleared(gameId);
                    setState(() {
                      level++;
                      hintUsed = false;
                      isSuccess = true;
                    });
                  },
                  child: Text("Sim win"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    setState(() {
                      isGameOver = true;
                    });
                  },
                  child: Text("Sim lose"),
                ),
              ],
            ),

            if (isGameOver)
              LossOverlay(
                subtitle: "Practice Mode",
                accentColor: Colors.blue,
                onTryAgain: () {
                  setState(() {
                    isGameOver = false;
                  });
                },
              ),
            if (isSuccess)
              Center(
                child: AutoNextCountdown(
                  duration: Duration(seconds: 3),
                  accentColor: Colors.green,
                  onNext: () async {
                    setState(() {
                      isSuccess = false;
                      level++;
                      hintUsed = false;
                    });

                    await _onClick();
                    await _initState();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    //cancel any active timers all that
    super.dispose();
  }
}
