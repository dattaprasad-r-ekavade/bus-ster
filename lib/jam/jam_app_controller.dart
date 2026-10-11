// Meta-layer state shared by the home, settings and game screens: the level
// pack, saved progress and player settings.
import 'package:flutter/foundation.dart';

import '../game/game_settings.dart';
import 'jam_model.dart';
import 'jam_progress.dart';
import 'jam_progress_store.dart';

class JamAppController extends ChangeNotifier {
  JamAppController({
    required this.levels,
    required this.progressStore,
    required this.settingsStore,
    JamProgress? progress,
    GameSettings settings = GameSettings.defaults,
  }) : _progress = progress ?? JamProgress.empty,
       _settings = settings,
       levelIds = List.unmodifiable([for (final l in levels) l.id]);

  /// Loads progress and settings; storage failures fall back to defaults.
  static Future<JamAppController> load({
    required List<JamLevel> levels,
    required JamProgressStore progressStore,
    required GameSettingsStore settingsStore,
  }) async {
    JamProgress progress;
    GameSettings settings;
    try {
      progress = await progressStore.load();
    } on Object {
      progress = JamProgress.empty;
    }
    try {
      settings = await settingsStore.load();
    } on Object {
      settings = GameSettings.defaults;
    }
    return JamAppController(
      levels: levels,
      progressStore: progressStore,
      settingsStore: settingsStore,
      progress: progress,
      settings: settings,
    );
  }

  final List<JamLevel> levels;
  final List<String> levelIds;
  final JamProgressStore progressStore;
  final GameSettingsStore settingsStore;

  JamProgress _progress;
  GameSettings _settings;

  JamProgress get progress => _progress;
  GameSettings get settings => _settings;

  bool isUnlocked(int index) => _progress.isUnlocked(index, levelIds);
  bool isCompleted(int index) =>
      index >= 0 &&
      index < levelIds.length &&
      _progress.isCompleted(levelIds[index]);
  int get nextLevelIndex => _progress.nextLevelIndex(levelIds);
  int get completedCount => _progress.completedCount(levelIds);
  bool get allCompleted => completedCount == levels.length;

  /// Records a win for the level at [index] and persists it.
  Future<void> recordWin(int index) async {
    if (index < 0 || index >= levels.length) return;
    final next = _progress.recordWin(index, levelIds);
    if (next == _progress) return;
    _progress = next;
    notifyListeners();
    try {
      await progressStore.save(next);
    } on Object catch (e) {
      debugPrint('Progress save failed: $e');
    }
  }

  Future<void> updateSettings(GameSettings settings) async {
    _settings = settings;
    notifyListeners();
    try {
      await settingsStore.save(settings);
    } on Object catch (e) {
      debugPrint('Settings save failed: $e');
    }
  }
}
