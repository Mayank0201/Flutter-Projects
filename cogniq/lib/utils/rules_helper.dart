import 'package:flutter/material.dart';
import '../widgets/game_tutorial_dialog.dart';

class RulesHelper {
  static void showRulesBottomSheet(BuildContext context, String gameId, String gameName) {
    GameTutorialDialog.show(context, gameId, gameName);
  }
}
