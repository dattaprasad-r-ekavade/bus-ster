import 'package:busster/jam/ui/jam_game_screen.dart';
import 'package:busster/main.dart' as app;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app loads levels into the bus-jam screen and accepts a tap', (
    tester,
  ) async {
    app.main();
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(JamGameScreen).evaluate().isNotEmpty) break;
    }
    expect(find.byType(JamGameScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('jam-level-pill')), findsOneWidget);

    final buses = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('jam-bus-'),
    );
    expect(buses, findsWidgets);
    await tester.tap(buses.first, warnIfMissed: false);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });
}
