// Scripted demo tour for screen recordings (not run in CI).
// Plays the next three levels with solver paths, shows a blocked tap and a
// hint, then skips ahead (debug builds only) to play a dense level.
import 'package:busster/jam/jam_level_codec.dart';
import 'package:busster/jam/jam_model.dart';
import 'package:busster/jam/jam_solver.dart';
import 'package:busster/jam/ui/jam_game_screen.dart';
import 'package:busster/jam/ui/jam_home_screen.dart';
import 'package:busster/main.dart' as app;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

Future<void> wait(WidgetTester tester, int ms) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 16));
    await Future<void>.delayed(const Duration(milliseconds: 16));
  }
}

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 300 && finder.evaluate().isEmpty; i++) {
    await wait(tester, 50);
  }
}

int currentLevelIndex(WidgetTester tester) {
  final text = tester.widget<Text>(
    find.descendant(
      of: find.byKey(const ValueKey('jam-level-pill')),
      matching: find.byType(Text),
    ),
  );
  return int.parse(RegExp(r'\d+').firstMatch(text.data!)!.group(0)!) - 1;
}

Future<void> tapBus(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(ValueKey('jam-bus-$id')), warnIfMissed: false);
}

Future<void> playLevel(
  WidgetTester tester,
  List<JamLevel> levels, {
  bool showBlocked = false,
  bool showHint = false,
  int stepMs = 900,
}) async {
  final level = levels[currentLevelIndex(tester)];
  final path = (solveJam(level) as Solvable).path;
  final rules = JamRules(level);
  var state = rules.initialState();

  if (showBlocked) {
    final blocked = level.vehicles.where(
      (v) => rules.check(state, v.id)?.reason == JamBlockReason.vehicle,
    );
    if (blocked.isNotEmpty) {
      await tapBus(tester, blocked.first.id);
      await wait(tester, 1400);
    }
  }
  if (showHint) {
    await tester.tap(find.byKey(const ValueKey('jam-hint')));
    await wait(tester, 1800);
  }
  for (final id in path) {
    await tapBus(tester, id);
    state = rules.tap(state, id).state;
    await wait(tester, stepMs);
  }
  await waitFor(tester, find.byKey(const ValueKey('jam-win-overlay')));
  await wait(tester, 2200);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('demo tour', (tester) async {
    final levels = JamLevelCodec.decodeBundle(
      await rootBundle.loadString('assets/levels/jam_levels.json'),
    );
    app.main();
    await waitFor(tester, find.byType(JamHomeScreen));
    await wait(tester, 2500);

    await tester.tap(find.byKey(const ValueKey('home-play')));
    await waitFor(tester, find.byType(JamGameScreen));
    await wait(tester, 2000);

    await playLevel(tester, levels, showBlocked: true);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(const ValueKey('jam-next')));
      await wait(tester, 1500);
      await playLevel(tester, levels, showHint: i == 1);
    }

    // Jump ahead to a dense level via the debug-only Skip.
    await tester.tap(find.byKey(const ValueKey('jam-next')));
    await wait(tester, 800);
    while (currentLevelIndex(tester) < 11) {
      await tester.tap(find.byKey(const ValueKey('jam-menu')));
      await wait(tester, 300);
      await tester.tap(find.byKey(const ValueKey('jam-skip')));
      await wait(tester, 300);
    }
    await wait(tester, 2000);
    await playLevel(tester, levels, stepMs: 700);
  });
}
