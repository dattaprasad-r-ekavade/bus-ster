import 'package:busster/game/depot_game.dart';
import 'package:busster/main.dart' as app;
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tapping the clear center bus dispatches one route', (
    tester,
  ) async {
    app.main();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.textContaining('DEPOT 01'), findsOneWidget);
    final board = find.byType(GameWidget<DepotGame>);
    expect(board, findsOneWidget);
    await tester.tapAt(tester.getRect(board).center);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('1 MOVES'), findsOneWidget);
    expect(find.textContaining('Blue route dispatched'), findsOneWidget);
    expect(find.text('0/2'), findsOneWidget);
  });
}
