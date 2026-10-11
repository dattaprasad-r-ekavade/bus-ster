import 'dart:convert';
import 'dart:io';

import 'package:busster/jam/jam_progress.dart';
import 'package:busster/jam/jam_progress_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late FileJamProgressStore store;
  const ids = ['a', 'b', 'c'];

  File file(String name) => File('${dir.path}${Platform.pathSeparator}$name');
  File mainFile() => file(FileJamProgressStore.fileName);
  File backupFile() => file(FileJamProgressStore.backupName);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('busster-progress-');
    store = FileJamProgressStore(directory: () async => dir);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('file names match the Android backup rules', () {
    for (final rules in [
      'android/app/src/main/res/xml/backup_rules.xml',
      'android/app/src/main/res/xml/data_extraction_rules.xml',
    ]) {
      final xml = File(rules).readAsStringSync();
      expect(xml, contains('path="${FileJamProgressStore.fileName}"'));
      expect(xml, contains('path="${FileJamProgressStore.backupName}"'));
    }
  });

  test('missing file loads empty progress', () async {
    expect(await store.load(), JamProgress.empty);
    expect(store.lastLoadSource, JamProgressSource.empty);
  });

  test('save then load round-trips and leaves no temp file', () async {
    final p = JamProgress.empty.recordWin(0, ids);
    await store.save(p);
    expect(mainFile().existsSync(), isTrue);
    expect(file(FileJamProgressStore.tempName).existsSync(), isFalse);
    expect(await FileJamProgressStore(directory: () async => dir).load(), p);
  });

  test('a second save keeps the previous good copy as .bak', () async {
    final first = JamProgress.empty.recordWin(0, ids);
    final second = first.recordWin(1, ids);
    await store.save(first);
    expect(backupFile().existsSync(), isFalse);
    await store.save(second);
    expect(
      JamProgress.fromJson(jsonDecode(backupFile().readAsStringSync())),
      first,
    );
    expect(
      JamProgress.fromJson(jsonDecode(mainFile().readAsStringSync())),
      second,
    );
  });

  test('concurrent saves are serialised; the last one wins', () async {
    final a = JamProgress.empty.recordWin(0, ids);
    final b = a.recordWin(1, ids);
    await Future.wait([store.save(a), store.save(b)]);
    expect(await store.load(), b);
  });

  test(
    'a corrupt main file recovers from the backup and is repaired',
    () async {
      final first = JamProgress.empty.recordWin(0, ids);
      await store.save(first);
      await store.save(first.recordWin(1, ids));
      mainFile().writeAsStringSync(
        '{"schemaVersion": 1, "highestUnl',
      ); // truncated

      final loaded = await store.load();
      expect(loaded, first);
      expect(store.lastLoadSource, JamProgressSource.backup);
      // Main file was rewritten from the backup.
      expect(
        JamProgress.fromJson(jsonDecode(mainFile().readAsStringSync())),
        first,
      );
    },
  );

  test('corrupt main and backup fall back to empty progress', () async {
    mainFile().writeAsStringSync('not json');
    backupFile().writeAsStringSync('{}');
    expect(await store.load(), JamProgress.empty);
    expect(store.lastLoadSource, JamProgressSource.empty);
  });

  test('saving over a corrupt main file does not clobber the backup', () async {
    final good = JamProgress.empty.recordWin(0, ids);
    backupFile().writeAsStringSync(jsonEncode(good.toJson()));
    mainFile().writeAsStringSync('garbage');
    final next = good.recordWin(1, ids);
    await store.save(next);
    expect(
      JamProgress.fromJson(jsonDecode(backupFile().readAsStringSync())),
      good,
    );
    expect(await store.load(), next);
  });
}
