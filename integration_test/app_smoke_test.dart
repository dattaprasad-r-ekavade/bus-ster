import 'package:busster/jam/ui/jam_game_screen.dart';
import 'package:busster/jam/ui/jam_home_screen.dart';
import 'package:busster/jam/ui/jam_settings_screen.dart';
import 'package:busster/main.dart' as app;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 80; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home -> settings -> play -> tap a bus -> back to levels', (
    tester,
  ) async {
    app.main();
    await pumpUntil(tester, find.byType(JamHomeScreen));
    expect(find.byType(JamHomeScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('home-level-0')), findsOneWidget);

    // Settings opens and closes.
    await tester.tap(find.byKey(const ValueKey('home-settings')));
    await pumpUntil(tester, find.byType(JamSettingsScreen));
    expect(find.byKey(const ValueKey('settings-sound')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings-back')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(JamSettingsScreen), findsNothing);

    // Play continues at the next level.
    await tester.tap(find.byKey(const ValueKey('home-play')));
    await pumpUntil(tester, find.byType(JamGameScreen));
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

    // Pause -> Levels returns home.
    await tester.tap(find.byKey(const ValueKey('jam-menu')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const ValueKey('jam-pause-levels')));
    await pumpUntil(tester, find.byType(JamHomeScreen).hitTestable());
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(JamGameScreen), findsNothing);
    expect(find.byType(JamHomeScreen), findsOneWidget);
  });
}
