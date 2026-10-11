import 'package:busster/jam/jam_model.dart';
import 'package:busster/jam/jam_solver.dart';
import 'package:flutter_test/flutter_test.dart';

import 'jam_test_helpers.dart';

JamState replay(JamLevel level, List<String> path, {JamState? from}) {
  final rules = JamRules(level);
  var state = from ?? rules.initialState();
  for (final id in path) {
    final result = rules.tap(state, id);
    expect(result.moved, isTrue, reason: 'tap $id should move');
    state = result.state;
  }
  return state;
}

void main() {
  // Two bays; tapping g1 and b1 before r1 fills the bays and loses.
  JamLevel pressure() =>
      rowLevel(bays: 2, passengers: crowd([(red, 4), (blue, 4), (green, 4)]));

  // One bay; tapping b1 first loses outright.
  JamLevel oneBay() => rowLevel(
    bays: 1,
    passengers: crowd([(red, 4), (blue, 4)]),
    buses: const [('r1', red, 4), ('b1', blue, 4)],
  );

  group('solveJam', () {
    test('solvable returns a path that replays to a win', () {
      final level = oneBay();
      final result = solveJam(level);
      expect(result, isA<Solvable>());
      final path = (result as Solvable).path;
      expect(path, ['r1', 'b1']);
      expect(replay(level, path).status, JamStatus.won);
    });

    test('solves from a mid-game state', () {
      final level = pressure();
      final rules = JamRules(level);
      final mid = rules.tap(rules.initialState(), 'g1').state;
      final result = solveJam(level, from: mid) as Solvable;
      expect(result.path.first, 'r1');
      expect(replay(level, result.path, from: mid).status, JamStatus.won);
    });

    test('unsolvable when the space is exhausted without a win', () {
      final level = JamLevel(
        id: 'deadlock',
        width: 5,
        height: 3,
        bayCount: 3,
        vehicles: [
          bus('o1', orange, right, 1, 0),
          bus('p1', purple, left, 2, 0),
          bus('r1', red, up, 4, 1),
        ],
        passengers: crowd([(red, 4), (orange, 4), (purple, 4)]),
      );
      expect(solveJam(level), isA<Unsolvable>());
    });

    test('unsolvable when every order overflows the bays', () {
      final level = rowLevel(
        bays: 1,
        passengers: crowd([(red, 2), (blue, 2), (red, 2), (blue, 2)]),
        buses: const [('r1', red, 4), ('b1', blue, 4)],
      );
      expect(solveJam(level), isA<Unsolvable>());
    });

    test('unknown when the node limit is hit', () {
      final result = solveJam(pressure(), nodeLimit: 1);
      expect(result, isA<Unknown>());
      expect((result as Unknown).nodeLimit, 1);
    });

    test('compute-style request entry point', () {
      final result = solveJamRequest(JamSolveRequest(oneBay()));
      expect(result, isA<Solvable>());
    });
  });

  group('state key', () {
    test('ignores remaining-set order and parked bus identity', () {
      final level = rowLevel(
        bays: 3,
        passengers: crowd([(blue, 1), (red, 4)]),
        buses: const [('r1', red, 2), ('r2', red, 2), ('b1', blue, 1)],
      );
      JamState s(List<String> remaining, List<JamBay?> bays) => JamState(
        remaining: remaining,
        bays: bays,
        passengerIndex: 0,
        moveCount: 2,
        status: JamStatus.playing,
      );
      expect(
        jamStateKey(
          level,
          s(['b1', 'r2'], const [JamBay('r1', 0), null, null]),
        ),
        jamStateKey(
          level,
          s(['r2', 'b1'], const [JamBay('r1', 0), null, null]),
        ),
      );
      // r1 and r2 are both red with 2 seats: interchangeable once parked.
      expect(
        jamStateKey(
          level,
          s(['b1'], const [JamBay('r1', 0), JamBay('r2', 0), null]),
        ),
        jamStateKey(
          level,
          s(['b1'], const [JamBay('r2', 0), JamBay('r1', 0), null]),
        ),
      );
    });

    test('slot order matters: swapping same-colour buses changes outcome', () {
      // Two red buses with 1 and 3 free seats. One red rider is next after
      // green. With the 1-seat bus in the lower slot it fills and frees a
      // bay; swapped, it does not and the bays overflow.
      final level = JamLevel(
        id: 'slots',
        width: 5,
        height: 2,
        bayCount: 3,
        vehicles: [
          bus('r1', red, up, 0, 0),
          bus('r2', red, up, 1, 0),
          bus('g1', green, up, 2, 0, capacity: 1),
          bus('y1', yellow, up, 3, 0, capacity: 1),
          bus('p1', purple, up, 4, 0, capacity: 1),
        ],
        passengers: crowd([
          (red, 4),
          (green, 1),
          (red, 1),
          (yellow, 1),
          (purple, 1),
          (red, 3),
        ]),
      );
      JamState s(List<JamBay?> bays) => JamState(
        remaining: const ['g1', 'y1', 'p1'],
        bays: bays,
        passengerIndex: 4,
        moveCount: 2,
        status: JamStatus.playing,
      );
      final a = s(const [JamBay('r1', 3), JamBay('r2', 1), null]);
      final b = s(const [JamBay('r2', 1), JamBay('r1', 3), null]);
      expect(jamStateKey(level, a), isNot(jamStateKey(level, b)));
      expect(replay(level, ['g1', 'p1', 'y1'], from: a).status, JamStatus.won);
      final rules = JamRules(level);
      var state = rules.tap(b, 'g1').state;
      state = rules.tap(state, 'p1').state;
      expect(state.status, JamStatus.lost);
      expect(solveJam(level, from: a), isA<Solvable>());
      expect(solveJam(level, from: b), isA<Solvable>());
    });
  });

  group('analyzeJam', () {
    test('metrics on a one-bay level', () {
      final analysis = analyzeJam(oneBay(), playouts: 2000, seed: 7);
      expect(analysis.solvable, isTrue);
      expect(analysis.minMoves, 2);
      expect(analysis.firstMoves, 2);
      expect(analysis.winningFirstMoves, 1);
      expect(analysis.losingFirstMoves, 1);
      expect(analysis.unknownFirstMoves, 0);
      expect(analysis.playouts, 2000);
      expect(analysis.failRate, closeTo(0.5, 0.05));
    });

    test('metrics on a two-bay pressure level', () {
      final analysis = analyzeJam(pressure(), playouts: 3000, seed: 3);
      expect(analysis.solvable, isTrue);
      expect(analysis.minMoves, 3);
      expect(analysis.firstMoves, 3);
      expect(analysis.winningFirstMoves, 3);
      expect(analysis.losingFirstMoves, 0);
      // Loses iff the first two taps are b1 and g1: 2/3 * 1/2.
      expect(analysis.failRate, closeTo(1 / 3, 0.04));
    });

    test('is deterministic for a seed and usable via a request', () {
      final a = analyzeJam(pressure(), playouts: 200, seed: 42);
      final b = analyzeJamRequest(
        JamAnalyzeRequest(pressure(), playouts: 200, seed: 42),
      );
      expect(b.playoutLosses, a.playoutLosses);
    });

    test('unsolvable level reports no min moves', () {
      final level = rowLevel(
        bays: 1,
        passengers: crowd([(red, 2), (blue, 2), (red, 2), (blue, 2)]),
        buses: const [('r1', red, 4), ('b1', blue, 4)],
      );
      final analysis = analyzeJam(level, playouts: 50);
      expect(analysis.solvable, isFalse);
      expect(analysis.minMoves, isNull);
      expect(analysis.losingFirstMoves, 2);
      expect(analysis.failRate, 1.0);
    });
  });
}
