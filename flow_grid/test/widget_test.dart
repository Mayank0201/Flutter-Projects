import 'package:flutter_test/flutter_test.dart';
import 'package:flow_grid/main.dart';

void main() {
  testWidgets('App starts successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const FlowGridApp());
    // Verify the game widget is rendered
    expect(find.byType(FlowGridApp), findsOneWidget);
  });
}
