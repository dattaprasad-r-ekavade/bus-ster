import 'dart:io';

import 'package:busster/game/depot_game.dart';
import 'package:busster/main.dart' as app;
import 'package:busster/game/progress_store.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
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

    await app.main(progressStoreOverride: store);
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

    await tester.tapAt(tester.getRect(board).center);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('1 MOVES'), findsOneWidget);
    expect(find.textContaining('Blue sent'), findsOneWidget);
    expect(find.textContaining('No riders matched'), findsOneWidget);
    expect(find.text('0/2'), findsOneWidget);

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    final savedProgress = await store.load();
    expect(savedProgress?.currentLevelId, 'depot-01');
    expect(savedProgress?.dispatches, ['blue']);
  });
}
