import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flow_grid/game/flow_grid_game.dart';
import 'package:flow_grid/game/map_generator.dart';
import 'package:flow_grid/ui/game_hud_overlay.dart';

void main() {
  test('FlowGridGame initializes correctly', () {
    final game = FlowGridGame();
    expect(game.score, 0);
    expect(game.selectedMapType, MapType.zen);
  });

  testWidgets('GameHudOverlay renders correctly without paint assertions', (tester) async {
    final game = FlowGridGame();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameHudOverlay(game: game),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GameHudOverlay), findsOneWidget);
  });
}
