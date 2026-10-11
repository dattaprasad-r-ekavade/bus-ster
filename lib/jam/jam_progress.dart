// Player progress through the level pack.
//
// Level ids are the durable key: the pack may be reordered or extended in a
// later build, so "completed" is a set of ids and unlocking is recomputed
// against whatever order the current pack uses. [highestUnlockedIndex] is a
// monotonic convenience so a reordered pack never re-locks a level the
// player could already reach.

/// Immutable snapshot of saved progress.
class JamProgress {
  JamProgress({
    this.highestUnlockedIndex = 0,
    Iterable<String> completed = const [],
  }) : assert(highestUnlockedIndex >= 0),
       completed = Set.unmodifiable(completed);

  static const int schemaVersion = 1;

  static final JamProgress empty = JamProgress();

  /// Highest level index (in pack order at the time of saving) the player
  /// has unlocked.
  final int highestUnlockedIndex;

  /// Ids of levels the player has won at least once.
  final Set<String> completed;

  bool isCompleted(String levelId) => completed.contains(levelId);

  /// Whether the level at [index] of [levelIds] can be played. The first
  /// level, any completed level and the level after a completed one are
  /// always open, as is everything up to [highestUnlockedIndex].
  bool isUnlocked(int index, List<String> levelIds) {
    if (index < 0 || index >= levelIds.length) return false;
    if (index == 0 || index <= highestUnlockedIndex) return true;
    if (completed.contains(levelIds[index])) return true;
    return completed.contains(levelIds[index - 1]);
  }

  /// Number of levels in [levelIds] that are completed.
  int completedCount(List<String> levelIds) =>
      levelIds.where(completed.contains).length;

  /// Where "Play" should continue: the first unlocked, uncompleted level, or
  /// the last level when everything is cleared.
  int nextLevelIndex(List<String> levelIds) {
    if (levelIds.isEmpty) return 0;
    for (var i = 0; i < levelIds.length; i++) {
      if (!completed.contains(levelIds[i]) && isUnlocked(i, levelIds)) {
        return i;
      }
    }
    return levelIds.length - 1;
  }

  /// Progress after winning the level at [index] of [levelIds].
  JamProgress recordWin(int index, List<String> levelIds) {
    RangeError.checkValidIndex(index, levelIds, 'index');
    final unlock = index + 1 < levelIds.length ? index + 1 : index;
    return JamProgress(
      highestUnlockedIndex: unlock > highestUnlockedIndex
          ? unlock
          : highestUnlockedIndex,
      completed: {...completed, levelIds[index]},
    );
  }

  Map<String, Object> toJson() => {
    'schemaVersion': schemaVersion,
    'highestUnlockedIndex': highestUnlockedIndex,
    'completed': completed.toList()..sort(),
  };

  /// Parses saved JSON. Throws [FormatException] for anything that is not a
  /// well-formed progress document so callers can fall back to a backup.
  factory JamProgress.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('progress is not an object');
    final version = json['schemaVersion'];
    if (version is! int || version < 1) {
      throw const FormatException('missing schemaVersion');
    }
    if (version > schemaVersion) {
      throw FormatException('unsupported schemaVersion $version');
    }
    final highest = json['highestUnlockedIndex'];
    final completed = json['completed'];
    if (highest is! int || highest < 0) {
      throw const FormatException('bad highestUnlockedIndex');
    }
    if (completed is! List || completed.any((e) => e is! String)) {
      throw const FormatException('bad completed list');
    }
    return JamProgress(
      highestUnlockedIndex: highest,
      completed: completed.cast<String>(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is JamProgress &&
      other.highestUnlockedIndex == highestUnlockedIndex &&
      other.completed.length == completed.length &&
      other.completed.containsAll(completed);

  @override
  int get hashCode =>
      Object.hash(highestUnlockedIndex, Object.hashAllUnordered(completed));

  @override
  String toString() =>
      'JamProgress(highest $highestUnlockedIndex, completed $completed)';
}
