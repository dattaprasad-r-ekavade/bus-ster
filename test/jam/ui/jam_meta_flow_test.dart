import 'dart:io';

import 'package:busster/game/game_settings.dart';
import 'package:busster/jam/jam_app_controller.dart';
import 'package:busster/jam/jam_level_codec.dart';
import 'package:busster/jam/jam_model.dart';
import 'package:busster/jam/jam_progress.dart';
import 'package:busster/jam/jam_progress_store.dart';
import 'package:busster/jam/jam_solver.dart';
import 'package:busster/jam/ui/jam_game_screen.dart';
import 'package:busster/jam/ui/jam_home_screen.dart';
import 'package:busster/jam/ui/jam_level_loader.dart';
import 'package:busster/jam/ui/jam_settings_screen.dart';
import 'package:busster/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final List<JamLevel> levels = JamLevelCodec.decodeBundle(
  File('assets/levels/jam_levels.json').readAsStringSync(),
);
final List<String> ids = [for (final l in levels) l.id];

Future<SolveResult> syncSolver(JamSolveRequest request) async =>
    solveJamRequest(request);

const phone = Size(412, 915);

Finder tile(int i) => find.byKey(ValueKey('home-level-$i'));

class Harness {
  Harness({JamProgress? progress, GameSettings? settings})
    : progressStore = MemoryJamProgressStore(progress),
      settingsStore = MemoryGameSettingsStore(
        settings ?? GameSettings.defaults,
      );

  final MemoryJamProgressStore progressStore;
  final MemoryGameSettingsStore settingsStore;

  Future<void> pump(WidgetTester tester, {Size size = phone}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: JamLevelLoader(
          levelsLoader: () async => levels,
          progressStore: progressStore,
          settingsStore: settingsStore,
          solver: syncSolver,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(JamHomeScreen), findsOneWidget);
  }
}

String? tileLabel(WidgetTester tester, int i) =>
    tester.getSemantics(tile(i)).label;

JamGameScreenState game(WidgetTester tester) =>
    tester.state<JamGameScreenState>(find.byType(JamGameScreen));

Future<void> winCurrentLevel(WidgetTester tester) async {
  final s = game(tester);
  final path = (solveJam(s.level) as Solvable).path;
  for (final id in path) {
    await tester.tap(find.byKey(ValueKey('jam-bus-$id')), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 150));
  }
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('jam-win-overlay')), findsOneWidget);
}

Future<void> backToLevels(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('jam-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('jam-pause-levels')));
  await tester.pumpAndSettle();
  expect(find.byType(JamGameScreen), findsNothing);
  expect(find.byType(JamHomeScreen), findsOneWidget);
}

void main() {
  group('home screen', () {
    testWidgets('fresh install: only level 1 is open and Play starts it', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await Harness().pump(tester);
      expect(find.text('Bus-ster'), findsOneWidget);
      expect(find.text('0 of ${levels.length} cleared'), findsOneWidget);
      expect(tileLabel(tester, 0), 'Level 1, up next');
      expect(tileLabel(tester, 1), 'Level 2, locked');
      expect(find.text('Play level 1'), findsOneWidget);

      // Locked tiles do nothing.
      await tester.tap(tile(1));
      await tester.pumpAndSettle();
      expect(find.byType(JamGameScreen), findsNothing);

      await tester.tap(find.byKey(const ValueKey('home-play')));
      await tester.pumpAndSettle();
      expect(game(tester).levelIndex, 0);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('saved progress unlocks by id and Play continues', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final progress = JamProgress.empty
          .recordWin(0, ids)
          .recordWin(1, ids)
          .recordWin(2, ids);
      await Harness(progress: progress).pump(tester);
      expect(tileLabel(tester, 0), 'Level 1, completed');
      expect(tileLabel(tester, 2), 'Level 3, completed');
      expect(tileLabel(tester, 3), 'Level 4, up next');
      expect(tileLabel(tester, 4), 'Level 5, locked');
      expect(find.text('3 of ${levels.length} cleared'), findsOneWidget);
      expect(find.text('Play level 4'), findsOneWidget);

      // Replaying a completed level is allowed.
      await tester.tap(tile(1));
      await tester.pumpAndSettle();
      expect(game(tester).levelIndex, 1);
      semantics.dispose();
    });

    testWidgets('renders without overflow on a compact phone', (tester) async {
      await Harness().pump(tester, size: const Size(320, 568));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('home-settings')));
      await tester.pumpAndSettle();
      expect(find.byType(JamSettingsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('winning unlocks the next level, persists, and Next continues', (
    tester,
  ) async {
    final h = Harness();
    await h.pump(tester);
    await tester.tap(find.byKey(const ValueKey('home-play')));
    await tester.pumpAndSettle();
    await winCurrentLevel(tester);

    expect(h.progressStore.progress.isCompleted(ids[0]), isTrue);
    expect(h.progressStore.progress.highestUnlockedIndex, 1);
    expect(h.progressStore.saveCount, 1);

    await tester.tap(find.byKey(const ValueKey('jam-next')));
    await tester.pumpAndSettle();
    expect(game(tester).levelIndex, 1);

    await backToLevels(tester);
    expect(find.text('1 of ${levels.length} cleared'), findsOneWidget);
    expect(find.text('Play level 2'), findsOneWidget);

    // A fresh app session reads the saved file back.
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const SizedBox());
    await Harness(progress: h.progressStore.progress).pump(tester);
    expect(tileLabel(tester, 1), 'Level 2, up next');
    semantics.dispose();
  });

  group('settings', () {
    testWidgets('toggles persist through the store', (tester) async {
      final h = Harness();
      await h.pump(tester);
      await tester.tap(find.byKey(const ValueKey('home-settings')));
      await tester.pumpAndSettle();
      expect(find.text('Sound effects'), findsOneWidget);
      expect(find.text('Vibration'), findsOneWidget);
      expect(find.text('Reduce motion'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('settings-sound')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-haptics')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-reduce-motion')));
      await tester.pumpAndSettle();

      final saved = h.settingsStore.settings;
      expect(saved.soundEnabled, isFalse);
      expect(saved.hapticsEnabled, isFalse);
      expect(saved.reduceMotion, isTrue);
      expect(h.settingsStore.saveCount, 3);

      await tester.tap(find.byKey(const ValueKey('settings-back')));
      await tester.pumpAndSettle();
      expect(find.byType(JamHomeScreen), findsOneWidget);
    });

    testWidgets('reduced motion applies to the game subtree', (tester) async {
      await Harness(
        settings: const GameSettings(reduceMotion: true),
      ).pump(tester);
      await tester.tap(find.byKey(const ValueKey('home-play')));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(JamGameScreen));
      expect(MediaQuery.disableAnimationsOf(context), isTrue);

      final s = game(tester);
      final id = JamRules(s.level).legalTaps(s.session.state).first;
      await tester.tap(
        find.byKey(ValueKey('jam-bus-$id')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(s.isAnimating, isFalse);
      expect(s.session.state.remaining, isNot(contains(id)));
    });

    testWidgets('settings opened from the pause menu apply live', (
      tester,
    ) async {
      final h = Harness();
      await h.pump(tester);
      await tester.tap(find.byKey(const ValueKey('home-play')));
      await tester.pumpAndSettle();
      final gameElement = find.byType(JamGameScreen);
      expect(
        MediaQuery.disableAnimationsOf(tester.element(gameElement)),
        isFalse,
      );
      expect(tester.widget<JamGameScreen>(gameElement).hapticsEnabled, isTrue);

      await tester.tap(find.byKey(const ValueKey('jam-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('jam-pause-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-reduce-motion')));
      await tester.tap(find.byKey(const ValueKey('settings-haptics')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-back')));
      await tester.pumpAndSettle();

      expect(
        MediaQuery.disableAnimationsOf(tester.element(gameElement)),
        isTrue,
      );
      expect(tester.widget<JamGameScreen>(gameElement).hapticsEnabled, isFalse);
      // Still paused where the player left it.
      expect(find.byKey(const ValueKey('jam-pause-overlay')), findsOneWidget);
    });
  });

  test(
    'controller records wins once and ignores out-of-range indices',
    () async {
      final store = MemoryJamProgressStore();
      final c = JamAppController(
        levels: levels,
        progressStore: store,
        settingsStore: MemoryGameSettingsStore(),
      );
      await c.recordWin(0);
      await c.recordWin(0);
      await c.recordWin(-1);
      await c.recordWin(levels.length);
      expect(store.saveCount, 1);
      expect(c.nextLevelIndex, 1);
      expect(c.isUnlocked(1), isTrue);
      expect(c.isUnlocked(2), isFalse);
    },
  );

  testWidgets('every ARB string resolves and plurals read naturally', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(l10n.passengersLeft(0), 'Nobody waiting');
    expect(l10n.passengersLeft(1), '1 passenger waiting');
    expect(l10n.passengersLeft(12), '12 passengers waiting');
    expect(
      l10n.busSemantics('red', 'left', 3),
      'Red bus, facing left, length 3',
    );
    expect(l10n.levelTileSemantics(4, 'locked'), 'Level 4, locked');
    expect(l10n.homeProgress(2, 30), '2 of 30 cleared');
    // Sanity: semantics tree is buildable with labels on the home screen.
    final handle = tester.ensureSemantics();
    await Harness().pump(tester);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('home-play'))),
      matchesSemantics(
        label: 'Play level 1',
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });
}
