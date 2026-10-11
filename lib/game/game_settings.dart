/// Player-facing preferences that do not affect puzzle progress.
class GameSettings {
  const GameSettings({
    this.hapticsEnabled = true,
    this.soundEnabled = true,
    this.reduceMotion = false,
  });

  static const defaults = GameSettings();

  final bool hapticsEnabled;
  final bool soundEnabled;
  final bool reduceMotion;

  GameSettings copyWith({
    bool? hapticsEnabled,
    bool? soundEnabled,
    bool? reduceMotion,
  }) => GameSettings(
    hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    soundEnabled: soundEnabled ?? this.soundEnabled,
    reduceMotion: reduceMotion ?? this.reduceMotion,
  );
}

abstract interface class GameSettingsStore {
  Future<GameSettings> load();
  Future<void> save(GameSettings settings);
}

/// Non-persistent store for tests and previews.
class MemoryGameSettingsStore implements GameSettingsStore {
  MemoryGameSettingsStore([this.settings = GameSettings.defaults]);

  GameSettings settings;
  int saveCount = 0;

  @override
  Future<GameSettings> load() async => settings;

  @override
  Future<void> save(GameSettings settings) async {
    this.settings = settings;
    saveCount++;
  }
}
