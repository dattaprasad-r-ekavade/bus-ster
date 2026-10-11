// Durable storage for [JamProgress].
//
// Progress lives in a small JSON file in the app's support directory (the
// Android `files/` dir, which `res/xml/backup_rules.xml` and
// `data_extraction_rules.xml` include by name). Writes are atomic: the new
// document goes to a temp file which is then renamed over the main file, and
// the previous good main file is kept as `.bak` so a corrupt or truncated
// main file can be recovered on the next load.
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'jam_progress.dart';

/// Loads and saves [JamProgress]. Implementations never throw from [load];
/// unreadable data degrades to the best available copy or empty progress.
abstract interface class JamProgressStore {
  Future<JamProgress> load();
  Future<void> save(JamProgress progress);
}

/// Where the most recent [FileJamProgressStore.load] got its data from.
enum JamProgressSource { none, main, backup, empty }

class FileJamProgressStore implements JamProgressStore {
  FileJamProgressStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  /// Must match the names in android/app/src/main/res/xml/*_rules.xml.
  static const fileName = 'busster-progress.json';
  static const backupName = '$fileName.bak';
  static const tempName = '$fileName.tmp';

  final Future<Directory> Function() _directory;
  Future<void> _queue = Future.value();

  JamProgressSource lastLoadSource = JamProgressSource.none;

  Future<File> _file(String name) async {
    final dir = await _directory();
    return File('${dir.path}${Platform.pathSeparator}$name');
  }

  @override
  Future<JamProgress> load() async {
    // Let any in-flight save finish so we never read a half-renamed state.
    await _queue;
    try {
      final main = await _file(fileName);
      final fromMain = await _tryRead(main);
      if (fromMain != null) {
        lastLoadSource = JamProgressSource.main;
        return fromMain;
      }
      final backup = await _file(backupName);
      final fromBackup = await _tryRead(backup);
      if (fromBackup != null) {
        lastLoadSource = JamProgressSource.backup;
        // Repair the main file from the last good copy (best effort).
        try {
          await _writeAtomically(main, await backup.readAsString());
        } on Object {
          // The backup still loads next time.
        }
        return fromBackup;
      }
    } on Object {
      // Fall through to empty progress; the game must still start.
    }
    lastLoadSource = JamProgressSource.empty;
    return JamProgress.empty;
  }

  @override
  Future<void> save(JamProgress progress) {
    final next = _queue.then((_) => _save(progress));
    // Keep the queue alive after a failed write; the caller still sees it.
    _queue = next.catchError((Object _) {});
    return next;
  }

  Future<void> _save(JamProgress progress) async {
    final main = await _file(fileName);
    final backup = await _file(backupName);
    // Preserve the current file as the last-good backup before replacing it.
    if (await _tryRead(main) != null) {
      final backupTemp = await _file('$backupName.tmp');
      await main.copy(backupTemp.path);
      await backupTemp.rename(backup.path);
    }
    await _writeAtomically(main, jsonEncode(progress.toJson()));
  }

  Future<void> _writeAtomically(File target, String contents) async {
    final temp = await _file(tempName);
    await temp.parent.create(recursive: true);
    await temp.writeAsString(contents, flush: true);
    await temp.rename(target.path);
  }

  Future<JamProgress?> _tryRead(File file) async {
    try {
      if (!await file.exists()) return null;
      return JamProgress.fromJson(jsonDecode(await file.readAsString()));
    } on Object {
      return null;
    }
  }
}

/// Non-persistent store for tests and previews.
class MemoryJamProgressStore implements JamProgressStore {
  MemoryJamProgressStore([JamProgress? initial])
    : progress = initial ?? JamProgress.empty;

  JamProgress progress;
  int saveCount = 0;

  @override
  Future<JamProgress> load() async => progress;

  @override
  Future<void> save(JamProgress progress) async {
    this.progress = progress;
    saveCount++;
  }
}
