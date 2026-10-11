/// A privacy-minimal event emitted by the local game session.
class GameEvent {
  GameEvent({required this.name, required Map<String, Object> parameters})
    : parameters = Map.unmodifiable(parameters);

  final String name;
  final Map<String, Object> parameters;
}

/// Adapter boundary for analytics providers. Implementations must be best-effort.
abstract interface class GameTelemetry {
  void record(GameEvent event);
}

/// Keeps all gameplay offline until a reviewed analytics adapter is provided.
class NoopGameTelemetry implements GameTelemetry {
  const NoopGameTelemetry();

  @override
  void record(GameEvent event) {}
}

abstract final class GameEventNames {
  static const levelStarted = 'level_started';
  static const dispatchRejected = 'dispatch_rejected';
  static const busDispatched = 'bus_dispatched';
  static const routeTipUsed = 'route_tip_used';
  static const routeTipUnavailable = 'route_tip_unavailable';
  static const adOffer = 'ad_offer';
  static const adReward = 'ad_reward';
  static const moveUndone = 'move_undone';
  static const levelRestarted = 'level_restarted';
  static const levelResumed = 'level_resumed';
  static const levelCompleted = 'level_completed';
  static const levelStuck = 'level_stuck';
}
