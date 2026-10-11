/// A privacy-minimal event emitted by the local game session.
class GameEvent {
  GameEvent({required this.name, required Map<String, Object> parameters})
    : parameters = Map.unmodifiable(parameters);

  final String name;
  final Map<String, Object> parameters;
}

/// Adapter boundary for analytics providers. Implementations must be
/// best-effort and must never throw into gameplay.
abstract interface class GameTelemetry {
  void record(GameEvent event);
}

/// Keeps all gameplay offline until a reviewed analytics adapter is provided.
class NoopGameTelemetry implements GameTelemetry {
  const NoopGameTelemetry();

  @override
  void record(GameEvent event) {}
}

/// Event names fired by the bus-jam screen. Every event carries `level_id`
/// and `level_index`; outcome events also carry `moves`.
abstract final class GameEventNames {
  static const levelStart = 'level_start';
  static const levelWin = 'level_win';
  static const levelLose = 'level_lose';
  static const undo = 'undo';
  static const retry = 'retry';
  static const hintUsed = 'hint_used';
}
