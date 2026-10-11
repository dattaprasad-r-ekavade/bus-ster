import 'game_replay.dart';

/// Saved player progress, separate from the live board and Flame rendering.
class GameProgress {
  GameProgress({
    required this.currentLevelId,
    required Iterable<String> dispatches,
    Iterable<String> completedLevelIds = const [],
  }) : dispatches = List.unmodifiable(dispatches),
       completedLevelIds = List.unmodifiable(
         completedLevelIds.toSet().toList()..sort(),
       );

  static const schemaVersion = 1;

  final String currentLevelId;
  final List<String> dispatches;
  final List<String> completedLevelIds;

  GameReplayRecord get replay =>
      GameReplayRecord(levelId: currentLevelId, dispatches: dispatches);

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'currentLevelId': currentLevelId,
    'dispatches': dispatches,
    'completedLevelIds': completedLevelIds,
  };

  factory GameProgress.fromJson(Map<String, Object?> json) {
    final version = json['schemaVersion'];
    if (version == 0) {
      final levelId = json['levelId'];
      final moves = json['moves'];
      final completed = json['completed'];
      if (levelId is! String ||
          levelId.isEmpty ||
          moves is! List ||
          moves.any((id) => id is! String) ||
          (completed != null &&
              (completed is! List || completed.any((id) => id is! String)))) {
        throw const FormatException('Invalid legacy Bus-ster progress.');
      }
      return GameProgress(
        currentLevelId: levelId,
        dispatches: moves.cast<String>(),
        completedLevelIds: completed == null
            ? const []
            : (completed as List).cast<String>(),
      );
    }
    if (version != schemaVersion) {
      if (version is int && version > schemaVersion) {
        throw UnsupportedProgressVersion(version);
      }
      throw const FormatException('Unsupported Bus-ster progress schema.');
    }

    final levelId = json['currentLevelId'];
    final dispatches = json['dispatches'];
    final completed = json['completedLevelIds'];
    if (levelId is! String ||
        levelId.isEmpty ||
        dispatches is! List ||
        dispatches.any((id) => id is! String) ||
        completed is! List ||
        completed.any((id) => id is! String)) {
      throw const FormatException('Invalid Bus-ster progress.');
    }
    return GameProgress(
      currentLevelId: levelId,
      dispatches: dispatches.cast<String>(),
      completedLevelIds: completed.cast<String>(),
    );
  }
}

class UnsupportedProgressVersion implements Exception {
  const UnsupportedProgressVersion(this.version);

  final int version;

  @override
  String toString() => 'Progress schema $version is newer than this app.';
}
