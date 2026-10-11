import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'game_progress.dart';

/// Stores the small progress record as a validated JSON file with a last-good
/// backup. Writes go through a temporary file in the same directory.
class ProgressFileStore {
  ProgressFileStore({required this.file});

  static Future<ProgressFileStore> inApplicationSupport() async {
    final directory = await getApplicationSupportDirectory();
    return ProgressFileStore(
      file: File(
        '${directory.path}${Platform.pathSeparator}busster-progress.json',
      ),
    );
  }

  final File file;
  Future<void> _writeQueue = Future<void>.value();
  bool _canWrite = true;
  String? _loadWarning;

  bool get canWrite => _canWrite;
  String? get loadWarning => _loadWarning;

  File get _backupFile => File('${file.path}.bak');
  File get _temporaryFile => File('${file.path}.tmp');

  Future<GameProgress?> load() async {
    final primaryExists = await file.exists();
    final backupExists = await _backupFile.exists();
    if (!primaryExists && !backupExists) return null;

    if (primaryExists) {
      try {
        final decoded = await _read(file);
        if (decoded.wasLegacy) await _write(decoded.progress);
        return decoded.progress;
      } on UnsupportedProgressVersion {
        _canWrite = false;
        rethrow;
      } on Object {
        if (!backupExists) {
          _loadWarning = 'Saved progress was damaged. Starting a fresh depot.';
          return null;
        }
        try {
          _loadWarning = 'Recovered saved progress from its last-good backup.';
          return (await _read(_backupFile)).progress;
        } on UnsupportedProgressVersion {
          _canWrite = false;
          rethrow;
        } on Object {
          _loadWarning =
              'Saved progress and its backup were damaged. Starting a fresh depot.';
          return null;
        }
      }
    }

    try {
      return (await _read(_backupFile)).progress;
    } on Object {
      _canWrite = false;
      rethrow;
    }
  }

  Future<void> save(GameProgress progress) {
    if (!_canWrite) {
      return Future<void>.error(
        StateError('Progress storage is read-only after a load error.'),
      );
    }
    final write = _writeQueue.then((_) => _write(progress));
    _writeQueue = write.catchError((Object _) {});
    return write;
  }

  Future<_DecodedProgress> _read(File candidate) async {
    final decoded = jsonDecode(await candidate.readAsString());
    if (decoded is! Map) {
      throw const FormatException('Progress file must contain a JSON object.');
    }
    final json = decoded.cast<String, Object?>();
    return _DecodedProgress(
      progress: GameProgress.fromJson(json),
      wasLegacy: json['schemaVersion'] == 0,
    );
  }

  Future<void> _write(GameProgress progress) async {
    await file.parent.create(recursive: true);
    try {
      final encoded = jsonEncode(progress.toJson());
      await _temporaryFile.writeAsString(encoded, flush: true);
      await _read(_temporaryFile);

      if (await file.exists()) {
        try {
          await _read(file);
          await file.copy(_backupFile.path);
        } on UnsupportedProgressVersion {
          _canWrite = false;
          rethrow;
        } on Object {
          // Preserve the damaged primary without replacing a good backup.
          final corruptFile = File('${file.path}.corrupt');
          if (!await corruptFile.exists()) {
            await file.copy(corruptFile.path);
          }
        }
      }
      await _temporaryFile.rename(file.path);
    } finally {
      if (await _temporaryFile.exists()) await _temporaryFile.delete();
    }
  }
}

class _DecodedProgress {
  const _DecodedProgress({required this.progress, required this.wasLegacy});

  final GameProgress progress;
  final bool wasLegacy;
}
