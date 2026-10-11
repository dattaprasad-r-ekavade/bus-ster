import 'dart:io';

import 'package:busster/game/game_model.dart';
import 'package:busster/main.dart';
import 'package:busster/game/level_bundle.dart';
import 'package:busster/game/game_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<LevelSpec> levels;

  setUpAll(() async {
    levels = LevelBundleCodec.decode(
      await File('assets/levels/levels.json').readAsString(),
    );
  });

  testWidgets('restores the saved depot and move history', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      BussterApp(
        levelList: levels,
        initialProgress: GameProgress(
          currentLevelId: 'depot-02',
          dispatches: ['coral'],
          completedLevelIds: ['depot-01'],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('DEPOT 02'), findsOneWidget);
    expect(find.textContaining('1 MOVES'), findsOneWidget);
    expect(find.textContaining('Progress restored'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pause overlay resumes the depot', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(BussterApp(levelList: levels));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byTooltip('Pause game'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('PAUSED'), findsOneWidget);

    await tester.tap(find.text('RESUME'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('PAUSED'), findsNothing);
    expect(find.byTooltip('Pause game'), findsOneWidget);
  });

  testWidgets(
    'depot picker exposes unlocked depots and keeps locked ones shut',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        BussterApp(
          levelList: levels,
          initialProgress: GameProgress(
            currentLevelId: 'depot-02',
            dispatches: ['coral'],
            completedLevelIds: ['depot-01'],
            earnedHints: 4,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('ROUTE TIP · 4'), findsOneWidget);
      await tester.tap(find.byTooltip('Select depot'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('SELECT DEPOT'), findsOneWidget);
      expect(find.textContaining('DEPOT 03 · Queue order'), findsOneWidget);

      await tester.tap(find.textContaining('DEPOT 03 · Queue order'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('SELECT DEPOT'), findsOneWidget);

      await tester.tap(find.textContaining('DEPOT 01 · One clear route'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Leave this depot?'), findsOneWidget);
      await tester.tap(find.text('CANCEL'));
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.textContaining('DEPOT 02'), findsOneWidget);

      await tester.tap(find.byTooltip('Select depot'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.tap(find.textContaining('DEPOT 01 · One clear route'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.tap(find.text('SWITCH DEPOT'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.textContaining('DEPOT 01'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('keeps gameplay controls visible on a compact phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(BussterApp(levelList: levels));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('BUS-STER'), findsOneWidget);
    expect(find.byTooltip('Pause game'), findsOneWidget);
    expect(find.text('UNDO'), findsOneWidget);
    expect(find.text('HINT 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the first depot and rider queue', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(BussterApp(levelList: levels));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('BUS-STER'), findsOneWidget);
    expect(find.textContaining('DEPOT 01'), findsOneWidget);
    expect(find.text('NEXT RIDERS'), findsOneWidget);
    expect(find.text('FIFO QUEUE'), findsOneWidget);
    expect(find.textContaining('ROUTE TIP · 3'), findsOneWidget);
    expect(find.textContaining('Tap a bus with a clear road'), findsOneWidget);

    await tester.tap(find.byTooltip('How to play'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('How to play'), findsOneWidget);
    expect(find.textContaining('Riders board from the front'), findsOneWidget);

    await tester.tap(find.text('GOT IT'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('Debug overlay'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('DEBUG · depot-01'), findsOneWidget);
    expect(find.textContaining('blue: 2 tiles'), findsOneWidget);
    expect(find.textContaining('Solver: blue → coral → mint'), findsOneWidget);
  });
}
