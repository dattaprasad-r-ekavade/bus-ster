import 'dart:io';
import 'dart:math' as math;

import 'package:busster/game/depot_game.dart';
import 'package:busster/game/game_progress.dart';
import 'package:busster/game/game_settings.dart';
import 'package:busster/main.dart' as app;
import 'package:busster/game/progress_store.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState, Offset;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tapping the clear center bus dispatches one route', (
    tester,
  ) async {
    final supportDirectory = await getApplicationSupportDirectory();
    final store = ProgressFileStore(
      file: File(
        '${supportDirectory.path}${Platform.pathSeparator}'
        'busster-integration-progress.json',
      ),
    );
    final settingsStore = _MemoryGameSettingsStore();
    final testFiles = [
      store.file,
      File('${store.file.path}.bak'),
      File('${store.file.path}.tmp'),
      File('${store.file.path}.corrupt'),
    ];
    for (final file in testFiles) {
      if (await file.exists()) await file.delete();
    }
    addTearDown(() async {
      for (final file in testFiles) {
        if (await file.exists()) await file.delete();
      }
    });

    await app.main(
      progressStoreOverride: store,
      settingsStoreOverride: settingsStore,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.textContaining('DEPOT 01'), findsOneWidget);
    final board = find.byType(GameWidget<DepotGame>);
    expect(board, findsOneWidget);
    final game = tester.widget<GameWidget<DepotGame>>(board).game!;

    await tester.tap(find.byTooltip('Pause game'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('PAUSED'), findsOneWidget);
    expect(game.paused, isTrue);
    await tester.tap(find.text('RESUME'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('PAUSED'), findsNothing);
    expect(game.paused, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(game.paused, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(game.paused, isFalse);

    await tester.tap(find.byTooltip('Pause game'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Reduce motion'));
    await tester.pump();
    expect(game.reduceMotion, isTrue);
    expect(settingsStore.value.reduceMotion, isTrue);
    await tester.tap(find.text('RESUME'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final boardRect = tester.getRect(board);
    final component = game.firstChild<DepotBoard>()!;
    final level = game.session.level;
    final cellSize = math.min(
      (component.size.x - 28) / level.width,
      (component.size.y - 56) / level.height,
    );
    final bluePosition = level.busById('blue').position;
    final target = Offset(
      boardRect.left +
          (component.size.x - cellSize * level.width) / 2 +
          (bluePosition.x + 0.5) * cellSize,
      boardRect.top +
          (component.size.y - cellSize * level.height) / 2 +
          12 +
          (bluePosition.y + 0.5) * cellSize,
    );
    await tester.tapAt(target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(game.session.state.moveCount, 1);
    expect(game.firstChild<DepotBoard>()!.dispatchAnimationProgress, 1);
    expect(find.textContaining('Blue sent'), findsOneWidget);
    expect(find.textContaining('No riders matched'), findsOneWidget);
    expect(find.text('0/2'), findsOneWidget);

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    final savedProgress = await store.load();
    expect(savedProgress?.currentLevelId, 'depot-01');
    expect(savedProgress?.dispatches, ['blue']);
    expect(savedProgress?.earnedHints, GameProgress.initialHintCredits);
  });
}

class _MemoryGameSettingsStore implements GameSettingsStore {
  GameSettings value = GameSettings.defaults;

  @override
  Future<GameSettings> load() async => value;

  @override
  Future<void> save(GameSettings settings) async {
    value = settings;
  }
}
