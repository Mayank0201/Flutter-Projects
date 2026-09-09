import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flow_grid/game/flow_grid_game.dart';
import 'package:flow_grid/game/components/car_component.dart';
import 'package:flow_grid/models/grid_cell.dart';
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

  test('CarComponent isOncomingCar correctly classifies follower vs oncoming vs crossing', () {
    // Car A going East: (5, 10) -> (6, 10) -> (7, 10)
    final carA = CarComponent(
      colorIndex: 0,
      path: [
        const GridPosition(5, 10),
        const GridPosition(6, 10),
        const GridPosition(7, 10),
      ],
      cellSize: 40.0,
      spawnHousePos: const GridPosition(5, 10),
      targetDest: const GridPosition(7, 10),
    );

    // Car B following behind Car A in the same direction: (4, 10) -> (5, 10) -> (6, 10)
    final carB = CarComponent(
      colorIndex: 0,
      path: [
        const GridPosition(4, 10),
        const GridPosition(5, 10),
        const GridPosition(6, 10),
      ],
      cellSize: 40.0,
      spawnHousePos: const GridPosition(4, 10),
      targetDest: const GridPosition(6, 10),
    );

    // Car C crossing perpendicularly from North to South: (6, 9) -> (6, 10) -> (6, 11)
    final carC = CarComponent(
      colorIndex: 1,
      path: [
        const GridPosition(6, 9),
        const GridPosition(6, 10),
        const GridPosition(6, 11),
      ],
      cellSize: 40.0,
      spawnHousePos: const GridPosition(6, 9),
      targetDest: const GridPosition(6, 11),
    );

    // Car D truly oncoming: going West from (7, 10) -> (6, 10) -> (5, 10)
    final carD = CarComponent(
      colorIndex: 2,
      path: [
        const GridPosition(7, 10),
        const GridPosition(6, 10),
        const GridPosition(5, 10),
      ],
      cellSize: 40.0,
      spawnHousePos: const GridPosition(7, 10),
      targetDest: const GridPosition(5, 10),
    );

    // Follower must NEVER be classified as oncoming
    expect(carA.isOncomingCar(carB), isFalse);
    expect(carB.isOncomingCar(carA), isFalse);

    // Perpendicular crossing at intersection must NEVER be classified as oncoming
    expect(carA.isOncomingCar(carC), isFalse);
    expect(carC.isOncomingCar(carA), isFalse);

    // Truly opposing traffic traversing the reverse segment MUST be classified as oncoming
    expect(carA.isOncomingCar(carD), isTrue);
    expect(carD.isOncomingCar(carA), isTrue);
  });
}

