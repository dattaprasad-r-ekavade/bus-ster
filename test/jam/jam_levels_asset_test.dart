import 'dart:io';

import 'package:busster/jam/jam_generator.dart';
import 'package:busster/jam/jam_level_codec.dart';
import 'package:busster/jam/jam_model.dart';
import 'package:busster/jam/jam_solver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final levels = JamLevelCodec.decodeBundle(
    File('assets/levels/jam_levels.json').readAsStringSync(),
  );

  test('bundle holds the three tutorials first, then 27 generated levels', () {
    expect(levels, hasLength(30));
    expect(levels.take(3).map((l) => l.id), [
      'tutorial-1',
      'tutorial-2',
      'tutorial-3',
    ]);
    for (final level in levels.take(3)) {
      expect(level.hint, isNotNull, reason: level.id);
    }
    expect(levels.skip(3).map((l) => l.id), [
      for (var n = 4; n <= 30; n++) 'level-${n.toString().padLeft(3, '0')}',
    ]);
    expect(levels.map((l) => l.id).toSet(), hasLength(levels.length));
  });

  test('lots fit 8x10 and bays stay within 3..7', () {
    for (final level in levels) {
      expect(level.width, inInclusiveRange(1, 8), reason: level.id);
      expect(level.height, inInclusiveRange(1, 10), reason: level.id);
      expect(level.bayCount, inInclusiveRange(3, 7), reason: level.id);
    }
  });

  test('generated levels can be lost and offer a choice', () {
    // Sampled with fewer playouts than the validator to keep tests fast.
    for (final level in levels.skip(3)) {
      final rules = JamRules(level);
      expect(
        rules.legalTaps(rules.initialState()).length,
        greaterThanOrEqualTo(2),
        reason: level.id,
      );
      expect(
        jamPlayoutFailRate(level, playouts: 200),
        greaterThan(0),
        reason: level.id,
      );
    }
  });

  test('every level is solvable and its solution replays to a win', () {
    for (final level in levels) {
      final result = solveJam(level);
      expect(result, isA<Solvable>(), reason: level.id);
      final rules = JamRules(level);
      var state = rules.initialState();
      for (final id in (result as Solvable).path) {
        state = rules.tap(state, id).state;
      }
      expect(state.status, JamStatus.won, reason: level.id);
    }
  });

  test('tutorial difficulty ramps as designed', () {
    final byId = {
      for (final l in levels.take(3))
        l.id: analyzeJam(l, playouts: 1000, seed: 1),
    };
    final t1 = byId['tutorial-1']!;
    final t2 = byId['tutorial-2']!;
    final t3 = byId['tutorial-3']!;

    expect(t1.level(levels).bayCount, 3);
    expect(t1.failRate, 0);

    // L2: the first red bus is blocked and must be cleared first.
    final l2 = t2.level(levels);
    expect(l2.bayCount, 4);
    final rules2 = JamRules(l2);
    expect(
      rules2.check(rules2.initialState(), 'r1'),
      const JamBlock(JamBlockReason.vehicle, blockerId: 'y1'),
    );
    expect(t2.failRate, 0);

    // L3: bay pressure — some tap orders lose.
    final l3 = t3.level(levels);
    expect(l3.bayCount, inInclusiveRange(3, 4));
    expect(t3.playoutLosses, greaterThan(0));
    expect(t3.failRate, lessThan(0.75));
  });
}

extension on JamAnalysis {
  JamLevel level(List<JamLevel> levels) =>
      levels.firstWhere((l) => l.id == levelId);
}
