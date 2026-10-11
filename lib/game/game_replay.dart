import 'game_model.dart';

/// A deterministic, shareable record of the player's dispatch choices.
class GameReplayRecord {
  static const schemaVersion = 1;

  GameReplayRecord({
    required this.levelId,
    required Iterable<String> dispatches,
  }) : dispatches = List.unmodifiable(dispatches);

  final String levelId;
  final List<String> dispatches;

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'levelId': levelId,
    'dispatches': dispatches,
  };

  factory GameReplayRecord.fromJson(Map<String, Object?> json) {
    final version = json['schemaVersion'];
    final levelId = json['levelId'];
    final dispatches = json['dispatches'];
    if (version != schemaVersion ||
        levelId is! String ||
        dispatches is! List ||
        dispatches.any((id) => id is! String)) {
      throw const FormatException('Invalid Bus-ster replay record.');
    }
    return GameReplayRecord(
      levelId: levelId,
      dispatches: dispatches.cast<String>(),
    );
  }

  BoardState replay(LevelSpec level) => replayStates(level).last;

  List<BoardState> replayStates(LevelSpec level) {
    if (level.id != levelId) {
      throw FormatException(
        'Replay level "$levelId" does not match "${level.id}".',
      );
    }

    var state = BoardState.initial(level);
    final states = <BoardState>[state];
    for (var index = 0; index < dispatches.length; index++) {
      final busId = dispatches[index];
      final result = GameRules.dispatch(level, state, busId);
      if (!result.changed) {
        throw FormatException(
          'Replay dispatch ${index + 1} ($busId) is invalid: '
          '${result.failure?.name ?? 'unknown failure'}.',
        );
      }
      state = result.state;
      if (state.status != GameStatus.won &&
          LevelSolver.findSolution(level, start: state) == null) {
        state = state.copyWith(status: GameStatus.stuck);
      }
      states.add(state);
    }
    return List.unmodifiable(states);
  }
}
