/// Player-facing preferences that do not affect puzzle progress.
class GameSettings {
  const GameSettings({this.hapticsEnabled = true, this.reduceMotion = false});

  static const defaults = GameSettings();

  final bool hapticsEnabled;
  final bool reduceMotion;

  GameSettings copyWith({bool? hapticsEnabled, bool? reduceMotion}) =>
      GameSettings(
        hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
        reduceMotion: reduceMotion ?? this.reduceMotion,
      );
}

abstract interface class GameSettingsStore {
  Future<GameSettings> load();
  Future<void> save(GameSettings settings);
}
