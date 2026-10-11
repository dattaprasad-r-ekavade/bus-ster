import 'package:busster/game/parking_jam_screen.dart';
import 'package:busster/main.dart' as app;
import 'package:flutter/foundation.dart' show ValueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('parking-jam launch clears a lane and boards its passengers', (
    tester,
  ) async {
    app.main();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ParkingJamScreen), findsOneWidget);
    expect(find.text('2 LEFT'), findsOneWidget);

    // This bus is blocked by the coral blocker. The move should explain why.
    await tester.tap(find.byKey(const ValueKey('coral-bus')));
    await tester.pump();
    expect(find.textContaining('coral-blocker'), findsOneWidget);

    // The blue bus has a clear lane and matches the first passenger.
    await tester.tap(find.byKey(const ValueKey('blue-bus')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.byKey(const ValueKey('blue-bus')), findsNothing);
    expect(find.text('1 LEFT'), findsOneWidget);
    expect(find.textContaining('1 passenger boarded.'), findsOneWidget);

    await tester.tap(find.text('UNDO'));
    await tester.pump();
    expect(find.byKey(const ValueKey('blue-bus')), findsOneWidget);
    expect(find.text('2 LEFT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
