import 'package:busster/jam/jam_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ids = ['a', 'b', 'c', 'd'];

  test('fresh progress unlocks only the first level', () {
    final p = JamProgress.empty;
    expect(
      [for (var i = 0; i < ids.length; i++) p.isUnlocked(i, ids)],
      [true, false, false, false],
    );
    expect(p.nextLevelIndex(ids), 0);
    expect(p.completedCount(ids), 0);
  });

  test('a win completes the level and unlocks the next one', () {
    final p = JamProgress.empty.recordWin(0, ids);
    expect(p.isCompleted('a'), isTrue);
    expect(p.highestUnlockedIndex, 1);
    expect(p.isUnlocked(1, ids), isTrue);
    expect(p.isUnlocked(2, ids), isFalse);
    expect(p.nextLevelIndex(ids), 1);
  });

  test('replaying an earlier level never lowers the unlock frontier', () {
    final p = JamProgress.empty
        .recordWin(0, ids)
        .recordWin(1, ids)
        .recordWin(0, ids);
    expect(p.highestUnlockedIndex, 2);
    expect(p.nextLevelIndex(ids), 2);
  });

  test('play continues at the first unlocked gap', () {
    // Level c completed out of order (e.g. pack reordered) but b is not.
    final p = JamProgress(highestUnlockedIndex: 3, completed: {'a', 'c'});
    expect(p.nextLevelIndex(ids), 1);
  });

  test('all cleared continues at the last level', () {
    final p = JamProgress(highestUnlockedIndex: 3, completed: ids);
    expect(p.nextLevelIndex(ids), 3);
    expect(p.recordWin(3, ids).highestUnlockedIndex, 3);
  });

  test('ids survive a reorder: the level after a completed one opens', () {
    final p = JamProgress(completed: {'c'});
    const reordered = ['a', 'c', 'b', 'd'];
    expect(p.isUnlocked(1, reordered), isTrue); // completed itself
    expect(p.isUnlocked(2, reordered), isTrue); // after a completed id
    expect(p.isUnlocked(3, reordered), isFalse);
  });

  test('json round-trips with a schema version', () {
    final p = JamProgress.empty.recordWin(0, ids).recordWin(1, ids);
    final json = p.toJson();
    expect(json['schemaVersion'], JamProgress.schemaVersion);
    expect(JamProgress.fromJson(json), p);
  });

  test('malformed json is rejected', () {
    for (final bad in <Object?>[
      null,
      'x',
      <String, Object>{},
      {'schemaVersion': 1, 'highestUnlockedIndex': -1, 'completed': []},
      {
        'schemaVersion': 1,
        'highestUnlockedIndex': 0,
        'completed': [1],
      },
      {'schemaVersion': 99, 'highestUnlockedIndex': 0, 'completed': []},
    ]) {
      expect(() => JamProgress.fromJson(bad), throwsFormatException);
    }
  });
}
