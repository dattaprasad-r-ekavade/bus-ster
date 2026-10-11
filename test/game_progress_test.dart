import 'dart:convert';
import 'dart:io';

import 'package:busster/game/game_progress.dart';
import 'package:busster/game/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late ProgressFileStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('busster-progress-test-');
    store = ProgressFileStore(
      file: File('${directory.path}${Platform.pathSeparator}progress.json'),
    );
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('writes and reads a versioned progress snapshot', () async {
    final saved = GameProgress(
      currentLevelId: 'depot-03',
      dispatches: ['coral', 'blue'],
      completedLevelIds: ['depot-01', 'depot-02'],
      earnedHints: 2,
    );

    await store.save(saved);
    final loaded = await store.load();

    expect(loaded?.toJson(), saved.toJson());
  });

  test('migrates version zero fields and writes the current schema', () async {
    await store.file.parent.create(recursive: true);
    await store.file.writeAsString(
      jsonEncode({
        'schemaVersion': 0,
        'levelId': 'depot-02',
        'moves': ['coral'],
        'completed': ['depot-01'],
      }),
    );

    final loaded = await store.load();
    final onDisk = jsonDecode(await store.file.readAsString()) as Map;

    expect(loaded?.currentLevelId, 'depot-02');
    expect(loaded?.dispatches, ['coral']);
    expect(loaded?.completedLevelIds, ['depot-01']);
    expect(loaded?.earnedHints, GameProgress.initialHintCredits);
    expect(onDisk['schemaVersion'], GameProgress.schemaVersion);
    expect(onDisk['currentLevelId'], 'depot-02');
  });

  test('uses the last-good backup when the current file is damaged', () async {
    final lastGood = GameProgress(
      currentLevelId: 'depot-02',
      dispatches: ['coral'],
      completedLevelIds: ['depot-01'],
    );
    await store.save(lastGood);
    await store.save(
      GameProgress(
        currentLevelId: 'depot-03',
        dispatches: ['blue'],
        completedLevelIds: ['depot-01', 'depot-02'],
      ),
    );
    await store.file.writeAsString('{broken');

    final loaded = await store.load();

    expect(loaded?.toJson(), lastGood.toJson());
    expect(store.loadWarning, contains('last-good backup'));
  });

  test(
    'migrates version one progress and adds the starter hint allowance',
    () async {
      await store.file.parent.create(recursive: true);
      await store.file.writeAsString(
        jsonEncode({
          'schemaVersion': 1,
          'currentLevelId': 'depot-03',
          'dispatches': ['blue'],
          'completedLevelIds': ['depot-01', 'depot-02'],
        }),
      );

      final loaded = await store.load();
      final onDisk = jsonDecode(await store.file.readAsString()) as Map;

      expect(loaded?.currentLevelId, 'depot-03');
      expect(loaded?.dispatches, ['blue']);
      expect(loaded?.earnedHints, GameProgress.initialHintCredits);
      expect(onDisk['schemaVersion'], GameProgress.schemaVersion);
      expect(onDisk['earnedHints'], GameProgress.initialHintCredits);
    },
  );

  test('preserves a damaged file before saving a fresh snapshot', () async {
    await store.file.parent.create(recursive: true);
    await store.file.writeAsString('{broken');

    expect(await store.load(), isNull);
    expect(store.canWrite, isTrue);
    expect(store.loadWarning, contains('damaged'));

    final fresh = GameProgress(currentLevelId: 'depot-01', dispatches: []);
    await store.save(fresh);

    expect((await store.load())?.toJson(), fresh.toJson());
    expect(await File('${store.file.path}.corrupt').readAsString(), '{broken');
  });

  test('does not overwrite progress written by a newer app version', () async {
    const futureVersion = '{"schemaVersion":99,"currentLevelId":"depot-01"}';
    await store.file.parent.create(recursive: true);
    await store.file.writeAsString(futureVersion);

    await expectLater(store.load(), throwsA(isA<UnsupportedProgressVersion>()));
    expect(store.canWrite, isFalse);
    await expectLater(
      store.save(GameProgress(currentLevelId: 'depot-01', dispatches: [])),
      throwsA(isA<StateError>()),
    );
    expect(await store.file.readAsString(), futureVersion);
  });
}
