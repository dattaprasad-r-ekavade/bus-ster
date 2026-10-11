import 'dart:io';

import 'package:busster/game/game_telemetry.dart';

import 'package:busster/jam/jam_level_codec.dart';
import 'package:busster/jam/jam_model.dart';
import 'package:busster/jam/jam_solver.dart';
import 'package:busster/jam/ui/jam_game_screen.dart';
import 'package:busster/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final List<JamLevel> levels = JamLevelCodec.decodeBundle(
  File('assets/levels/jam_levels.json').readAsStringSync(),
);

class RecordingTelemetry implements GameTelemetry {
  final events = <GameEvent>[];

  List<String> get names => [for (final e in events) e.name];

  @override
  void record(GameEvent event) => events.add(event);
}

int indexOf(String id) => levels.indexWhere((l) => l.id == id);

Future<SolveResult> syncSolver(JamSolveRequest request) async =>
    solveJamRequest(request);

const phone = Size(412, 915);
const compact = Size(320, 568);

Future<void> pumpScreen(
  WidgetTester tester, {
  Size size = phone,
  int index = 0,
  bool disableAnimations = false,
  JamLevelCompleteCallback? onLevelComplete,
  GameTelemetry telemetry = const NoopGameTelemetry(),
  VoidCallback? onExitToLevels,
  VoidCallback? onOpenSettings,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(size: size, disableAnimations: disableAnimations),
        child: JamGameScreen(
          key: ValueKey('screen-$index-$size'),
          levels: levels,
          initialLevelIndex: index,
          solver: syncSolver,
          onLevelComplete: onLevelComplete,
          telemetry: telemetry,
          onExitToLevels: onExitToLevels,
          onOpenSettings: onOpenSettings,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

JamGameScreenState screen(WidgetTester tester) =>
    tester.state<JamGameScreenState>(find.byType(JamGameScreen));

Finder bus(String id) => find.byKey(ValueKey('jam-bus-$id'));

Future<void> tapBus(WidgetTester tester, String id) =>
    tester.tap(bus(id), warnIfMissed: false);

/// A legal tap sequence from the initial state that ends in a loss.
List<String>? losingLine(JamLevel level) {
  final rules = JamRules(level);
  List<String>? dfs(JamState s, List<String> path) {
    if (s.status == JamStatus.lost) return path;
    if (s.status == JamStatus.won) return null;
    for (final id in rules.legalTaps(s)) {
      final found = dfs(rules.tap(s, id).state, [...path, id]);
      if (found != null) return found;
    }
    return null;
  }

  return dfs(rules.initialState(), []);
}

void main() {
  group('layout', () {
    for (final size in [phone, compact]) {
      testWidgets('every level renders without overflow at $size', (
        tester,
      ) async {
        for (var i = 0; i < levels.length; i++) {
          await pumpScreen(tester, size: size, index: i);
          expect(tester.takeException(), isNull, reason: levels[i].id);
          expect(find.byKey(const ValueKey('jam-level-pill')), findsOneWidget);
          // Every lot bus has an on-screen tap target.
          for (final v in levels[i].vehicles) {
            final rect = tester.getRect(bus(v.id));
            expect(
              Offset.zero & size,
              predicate<Rect>((r) => r.contains(rect.center)),
              reason: '${levels[i].id}/${v.id}',
            );
            expect(rect.width, greaterThan(20));
          }
        }
      });
    }

    testWidgets('lot fills most of the screen height', (tester) async {
      await pumpScreen(tester);
      final top = levels.first.vehicles
          .map((v) => tester.getRect(bus(v.id)).top)
          .reduce((a, b) => a < b ? a : b);
      // Buses start well below the crowd/bay band and the HUD.
      expect(top, greaterThan(915 * 0.3));
    });
  });

  testWidgets('buses expose readable semantics labels', (tester) async {
    await pumpScreen(tester);
    final v = levels.first.vehicles.first;
    final colour = v.color.name[0].toUpperCase() + v.color.name.substring(1);
    expect(
      find.bySemanticsLabel(
        '$colour bus, facing ${v.facing.name}, length ${v.length}',
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping a free bus parks it once animations settle', (
    tester,
  ) async {
    await pumpScreen(tester, index: indexOf('tutorial-1'));
    final s = screen(tester);
    final level = s.level;
    final rules = JamRules(level);
    // Pick a free bus whose colour is not at the front so it stays parked.
    final id = rules
        .legalTaps(s.session.state)
        .firstWhere((id) => level.vehicle(id).color != level.passengers.first);

    await tapBus(tester, id);
    await tester.pump();
    // Rules applied immediately; the lot target is gone at once.
    expect(s.session.state.remaining, isNot(contains(id)));
    expect(s.isAnimating, isTrue);
    expect(bus(id), findsNothing);

    await tester.pumpAndSettle();
    expect(s.isAnimating, isFalse);
    expect(s.session.state.bays.map((b) => b?.vehicleId), contains(id));
    expect(tester.takeException(), isNull);
  });

  testWidgets('blocked tap leaves the state unchanged', (tester) async {
    for (var i = 0; i < levels.length; i++) {
      final rules = JamRules(levels[i]);
      final start = rules.initialState();
      final blocked = levels[i].vehicles.where(
        (v) => rules.check(start, v.id)?.reason == JamBlockReason.vehicle,
      );
      if (blocked.isEmpty) continue;
      await pumpScreen(tester, index: i);
      final s = screen(tester);
      final before = s.session.state;
      await tapBus(tester, blocked.first.id);
      await tester.pump(const Duration(milliseconds: 100));
      expect(s.session.state, same(before));
      expect(s.session.canUndo, isFalse);
      await tester.pumpAndSettle();
      expect(s.session.state, same(before));
      expect(tester.takeException(), isNull);
      return;
    }
    fail('no level has an initially blocked bus');
  });

  testWidgets('undo and retry mid-animation snap to the true state', (
    tester,
  ) async {
    await pumpScreen(tester, index: indexOf('tutorial-1'));
    final s = screen(tester);
    final initial = s.session.state;
    final first = JamRules(s.level).legalTaps(initial).first;

    await tapBus(tester, first);
    await tester.pump(const Duration(milliseconds: 250));
    expect(s.isAnimating, isTrue);
    await tester.tap(find.byKey(const ValueKey('jam-undo')));
    await tester.pump();
    expect(s.session.state, initial);
    expect(s.isAnimating, isFalse);
    expect(bus(first), findsOneWidget);
    await tester.pumpAndSettle();

    // Two quick taps, then retry while both are still moving.
    final taps = JamRules(s.level).legalTaps(initial).take(2).toList();
    for (final id in taps) {
      await tapBus(tester, id);
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(s.isAnimating, isTrue);
    await tester.tap(find.byKey(const ValueKey('jam-retry')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(s.session.state, initial);
    await tester.pumpAndSettle();
    expect(s.session.state, initial);
    for (final v in s.level.vehicles) {
      expect(bus(v.id), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('replaying the solver path on tutorial-1 shows the win '
      'overlay', (tester) async {
    final completed = <int>[];
    final index = indexOf('tutorial-1');
    await pumpScreen(
      tester,
      index: index,
      onLevelComplete: (i, _) => completed.add(i),
    );
    final path = (solveJam(levels[index]) as Solvable).path;
    for (final id in path) {
      await tapBus(tester, id);
      // Tap the next bus while the previous one is still driving.
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(screen(tester).session.state.status, JamStatus.won);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('jam-win-overlay')), findsOneWidget);
    expect(find.text('All aboard!'), findsOneWidget);
    expect(completed, [index]);

    await tester.tap(find.byKey(const ValueKey('jam-next')));
    await tester.pumpAndSettle();
    expect(screen(tester).levelIndex, (index + 1) % levels.length);
    expect(find.byKey(const ValueKey('jam-win-overlay')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a losing line on tutorial-3 shows the lose overlay', (
    tester,
  ) async {
    final index = indexOf('tutorial-3');
    final line = losingLine(levels[index]);
    expect(line, isNotNull);
    await pumpScreen(tester, index: index);
    for (final id in line!) {
      await tapBus(tester, id);
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(screen(tester).session.state.status, JamStatus.lost);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('jam-lose-overlay')), findsOneWidget);
    expect(find.text('No room left'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('jam-lose-undo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('jam-lose-overlay')), findsNothing);
    expect(screen(tester).session.state.status, JamStatus.playing);

    // Lose again, then Retry from the overlay.
    await tapBus(tester, line.last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('jam-lose-overlay')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('jam-lose-retry')));
    await tester.pumpAndSettle();
    expect(screen(tester).session.canUndo, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hint runs without throwing and pulses a bus', (tester) async {
    await pumpScreen(tester, index: indexOf('tutorial-2'));
    await tester.tap(find.byKey(const ValueKey('jam-hint')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('tutorial levels point at a solver-suggested bus', (
    tester,
  ) async {
    await pumpScreen(tester, index: indexOf('tutorial-1'));
    expect(find.byKey(const ValueKey('jam-tutorial-bubble')), findsOneWidget);
  });

  testWidgets('reduced motion applies moves without animating', (tester) async {
    await pumpScreen(
      tester,
      index: indexOf('tutorial-1'),
      disableAnimations: true,
    );
    final s = screen(tester);
    final id = JamRules(s.level).legalTaps(s.session.state).first;
    await tapBus(tester, id);
    await tester.pump();
    expect(s.isAnimating, isFalse);
    expect(s.session.state.remaining, isNot(contains(id)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('pause menu skips to the next level', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const ValueKey('jam-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('jam-pause-overlay')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('jam-skip')));
    await tester.pumpAndSettle();
    expect(screen(tester).levelIndex, 1 % levels.length);
    expect(find.byKey(const ValueKey('jam-pause-overlay')), findsNothing);
  });

  testWidgets('pause menu offers Levels and Settings when wired', (
    tester,
  ) async {
    var levelsTapped = 0;
    var settingsTapped = 0;
    await pumpScreen(
      tester,
      onExitToLevels: () => levelsTapped++,
      onOpenSettings: () => settingsTapped++,
    );
    await tester.tap(find.byKey(const ValueKey('jam-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Levels'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('jam-pause-settings')));
    await tester.tap(find.byKey(const ValueKey('jam-pause-levels')));
    expect(settingsTapped, 1);
    expect(levelsTapped, 1);
  });

  testWidgets('pause menu hides Levels and Settings when not wired', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const ValueKey('jam-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('jam-pause-levels')), findsNothing);
    expect(find.byKey(const ValueKey('jam-pause-settings')), findsNothing);
  });

  testWidgets('screen fires the v2 telemetry events', (tester) async {
    final telemetry = RecordingTelemetry();
    final index = indexOf('tutorial-1');
    await pumpScreen(tester, index: index, telemetry: telemetry);
    expect(telemetry.names, [GameEventNames.levelStart]);
    expect(telemetry.events.first.parameters['level_id'], 'tutorial-1');

    final path = (solveJam(levels[index]) as Solvable).path;
    await tapBus(tester, path.first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('jam-undo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('jam-hint')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('jam-retry')));
    await tester.pumpAndSettle();
    for (final id in path) {
      await tapBus(tester, id);
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.pumpAndSettle();
    expect(telemetry.names, [
      GameEventNames.levelStart,
      GameEventNames.undo,
      GameEventNames.hintUsed,
      GameEventNames.retry,
      GameEventNames.levelWin,
    ]);
    expect(telemetry.events.last.parameters['moves'], path.length);

    await tester.tap(find.byKey(const ValueKey('jam-next')));
    await tester.pumpAndSettle();
    expect(telemetry.names.last, GameEventNames.levelStart);
  });

  testWidgets('losing fires levelLose', (tester) async {
    final telemetry = RecordingTelemetry();
    final index = indexOf('tutorial-3');
    await pumpScreen(tester, index: index, telemetry: telemetry);
    for (final id in losingLine(levels[index])!) {
      await tapBus(tester, id);
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pumpAndSettle();
    expect(telemetry.names.last, GameEventNames.levelLose);
  });

  testWidgets('HUD semantics use the localized plural', (tester) async {
    await pumpScreen(tester, index: indexOf('tutorial-1'));
    final n = levels[indexOf('tutorial-1')].passengers.length;
    expect(find.bySemanticsLabel('$n passengers waiting'), findsOneWidget);
    expect(find.text('Level ${indexOf('tutorial-1') + 1}'), findsOneWidget);
  });
}
