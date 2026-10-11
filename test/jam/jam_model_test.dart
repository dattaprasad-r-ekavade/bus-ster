import 'package:busster/jam/jam_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'jam_test_helpers.dart';

void main() {
  group('geometry', () {
    test('cells extend backwards from the nose for every facing', () {
      expect(bus('a', red, up, 2, 1, length: 3).cells, const [
        JamCell(2, 1),
        JamCell(2, 2),
        JamCell(2, 3),
      ]);
      expect(bus('a', red, down, 2, 3, length: 3).cells, const [
        JamCell(2, 3),
        JamCell(2, 2),
        JamCell(2, 1),
      ]);
      expect(bus('a', red, right, 3, 0).cells, const [
        JamCell(3, 0),
        JamCell(2, 0),
      ]);
      expect(bus('a', red, left, 0, 4, length: 4).cells, const [
        JamCell(0, 4),
        JamCell(1, 4),
        JamCell(2, 4),
        JamCell(3, 4),
      ]);
    });

    test('lane runs from in front of the nose to the lot edge', () {
      expect(bus('a', red, up, 1, 2).laneToEdge(4, 5), const [
        JamCell(1, 1),
        JamCell(1, 0),
      ]);
      expect(bus('a', red, down, 1, 2).laneToEdge(4, 5), const [
        JamCell(1, 3),
        JamCell(1, 4),
      ]);
      expect(bus('a', red, right, 1, 2).laneToEdge(4, 5), const [
        JamCell(2, 2),
        JamCell(3, 2),
      ]);
      expect(bus('a', red, left, 1, 2).laneToEdge(4, 5), const [JamCell(0, 2)]);
      expect(bus('a', red, left, 0, 2).laneToEdge(4, 5), isEmpty);
    });

    test('capacity defaults by length', () {
      expect(bus('a', red, up, 0, 1).capacity, 4);
      expect(bus('a', red, up, 0, 2, length: 3).capacity, 6);
      expect(bus('a', red, up, 0, 3, length: 4).capacity, 8);
      expect(bus('a', red, up, 0, 1, capacity: 3).capacity, 3);
    });
  });

  group('blocking', () {
    // r1 faces up from (1,4); h1 crosses its lane at (1,2), h2 at (1,0).
    JamLevel lane() => JamLevel(
      id: 'lane',
      width: 5,
      height: 6,
      bayCount: 3,
      vehicles: [
        bus('r1', red, up, 1, 4),
        bus('h1', blue, left, 0, 2),
        bus('h2', green, right, 2, 0),
      ],
      passengers: crowd([(red, 4), (blue, 4), (green, 4)]),
    );

    test('reports the nearest blocker and leaves state unchanged', () {
      final rules = JamRules(lane());
      final start = rules.initialState();
      final result = rules.tap(start, 'r1');
      expect(result.moved, isFalse);
      expect(
        result.block,
        const JamBlock(JamBlockReason.vehicle, blockerId: 'h1'),
      );
      expect(result.events, isEmpty);
      expect(result.state, same(start));
      expect(rules.legalTaps(start), ['h1', 'h2']);
    });

    test('clearing blockers opens the lane', () {
      final rules = JamRules(lane());
      var state = rules.initialState();
      state = rules.tap(state, 'h1').state;
      expect(rules.blockerOf(state, 'r1'), 'h2');
      state = rules.tap(state, 'h2').state;
      expect(rules.blockerOf(state, 'r1'), isNull);
      final result = rules.tap(state, 'r1');
      expect(result.moved, isTrue);
      expect(result.state.status, JamStatus.won);
    });

    test('tapping a departed vehicle reports gone; unknown ids throw', () {
      final rules = JamRules(lane());
      final state = rules.tap(rules.initialState(), 'h1').state;
      expect(rules.tap(state, 'h1').block, const JamBlock(JamBlockReason.gone));
      expect(() => rules.tap(state, 'nope'), throwsArgumentError);
    });

    test('fullBays is reported for a hand-built state with no free slot', () {
      final level = rowLevel(
        bays: 1,
        passengers: crowd([(red, 4), (blue, 4), (green, 4)]),
      );
      final rules = JamRules(level);
      final state = JamState(
        remaining: const ['b1', 'g1'],
        bays: const [JamBay('r1', 0)],
        passengerIndex: 0,
        moveCount: 1,
        status: JamStatus.playing,
      );
      expect(
        rules.tap(state, 'b1').block,
        const JamBlock(JamBlockReason.fullBays),
      );
    });
  });

  group('parking and boarding', () {
    test('parks in the lowest free slot, reusing freed slots', () {
      final level = rowLevel(
        bays: 3,
        passengers: crowd([(red, 2), (green, 2), (blue, 2)]),
        buses: const [('r1', red, 2), ('b1', blue, 2), ('g1', green, 2)],
      );
      final rules = JamRules(level);
      var result = rules.tap(rules.initialState(), 'b1');
      expect(result.events, const [JamPark('b1', 0)]);
      expect(result.state.bays, const [JamBay('b1', 0), null, null]);

      result = rules.tap(result.state, 'r1');
      expect(result.events, const [
        JamPark('r1', 1),
        JamBoard(0, 1, 'r1'),
        JamBoard(1, 1, 'r1'),
        JamDepart('r1', 1),
      ]);
      expect(result.state.bays, const [JamBay('b1', 0), null, null]);

      // Slot 1 was freed and is lower than slot 2.
      result = rules.tap(result.state, 'g1');
      expect(result.events.first, const JamPark('g1', 1));
    });

    test('only the front passenger boards', () {
      final level = rowLevel(
        bays: 3,
        passengers: crowd([(blue, 4), (red, 4), (green, 4)]),
      );
      final rules = JamRules(level);
      final result = rules.tap(rules.initialState(), 'r1');
      expect(result.events, const [JamPark('r1', 0)]);
      expect(result.state.passengerIndex, 0);
      expect(result.state.bays.first, const JamBay('r1', 0));
    });

    test('a bus keeps loading across groups once its colour returns', () {
      final level = rowLevel(
        bays: 2,
        passengers: crowd([(red, 2), (blue, 1), (red, 2)]),
        buses: const [('r1', red, 4), ('b1', blue, 1)],
      );
      final rules = JamRules(level);
      var result = rules.tap(rules.initialState(), 'r1');
      expect(result.events, const [
        JamPark('r1', 0),
        JamBoard(0, 0, 'r1'),
        JamBoard(1, 0, 'r1'),
      ]);
      expect(result.state.bays, const [JamBay('r1', 2), null]);
      expect(result.state.status, JamStatus.playing);

      result = rules.tap(result.state, 'b1');
      expect(result.events, const [
        JamPark('b1', 1),
        JamBoard(2, 1, 'b1'),
        JamDepart('b1', 1),
        JamBoard(3, 0, 'r1'),
        JamBoard(4, 0, 'r1'),
        JamDepart('r1', 0),
      ]);
      expect(result.state.status, JamStatus.won);
    });

    test('a full bus departs and frees its slot immediately', () {
      final level = rowLevel(
        bays: 3,
        passengers: crowd([(red, 4), (blue, 4), (green, 4)]),
      );
      final rules = JamRules(level);
      final result = rules.tap(rules.initialState(), 'r1');
      expect(result.events.last, const JamDepart('r1', 0));
      expect(result.state.bays, const [null, null, null]);
      expect(result.state.remaining, {'b1', 'g1'});
      expect(result.state.passengerIndex, 4);
    });

    test('departure cascades into boarding of waiting buses', () {
      final level = rowLevel(
        bays: 3,
        passengers: crowd([(red, 4), (blue, 4), (green, 4)]),
      );
      final rules = JamRules(level);
      var state = rules.initialState();
      state = rules.tap(state, 'g1').state;
      state = rules.tap(state, 'b1').state;
      expect(state.bays, const [JamBay('g1', 0), JamBay('b1', 0), null]);
      final result = rules.tap(state, 'r1');
      expect(result.events, [
        const JamPark('r1', 2),
        for (var i = 0; i < 4; i++) JamBoard(i, 2, 'r1'),
        const JamDepart('r1', 2),
        for (var i = 4; i < 8; i++) JamBoard(i, 1, 'b1'),
        const JamDepart('b1', 1),
        for (var i = 8; i < 12; i++) JamBoard(i, 0, 'g1'),
        const JamDepart('g1', 0),
      ]);
      expect(result.state.status, JamStatus.won);
      expect(result.state.bays, const [null, null, null]);
      expect(result.state.remaining, isEmpty);
      expect(result.state.moveCount, 3);
    });

    test('the lowest slot wins between same-colour buses', () {
      final level = rowLevel(
        bays: 3,
        passengers: crowd([(blue, 1), (red, 4)]),
        buses: const [('r1', red, 2), ('r2', red, 2), ('b1', blue, 1)],
      );
      final rules = JamRules(level);
      var state = rules.initialState();
      state = rules.tap(state, 'r1').state;
      state = rules.tap(state, 'r2').state;
      final result = rules.tap(state, 'b1');
      expect(result.events, const [
        JamPark('b1', 2),
        JamBoard(0, 2, 'b1'),
        JamDepart('b1', 2),
        JamBoard(1, 0, 'r1'),
        JamBoard(2, 0, 'r1'),
        JamDepart('r1', 0),
        JamBoard(3, 1, 'r2'),
        JamBoard(4, 1, 'r2'),
        JamDepart('r2', 1),
      ]);
    });
  });

  group('win and lose', () {
    test('loses when all bays are full and the front matches no bus', () {
      final level = rowLevel(
        bays: 2,
        passengers: crowd([(blue, 4), (red, 4), (green, 4)]),
      );
      final rules = JamRules(level);
      var state = rules.tap(rules.initialState(), 'r1').state;
      expect(state.status, JamStatus.playing);
      state = rules.tap(state, 'g1').state;
      expect(state.status, JamStatus.lost);
      expect(
        rules.tap(state, 'b1').block,
        const JamBlock(JamBlockReason.notPlaying),
      );
      expect(rules.legalTaps(state), isEmpty);
    });

    test('full bays are fine while boarding still resolves', () {
      final level = rowLevel(
        bays: 2,
        passengers: crowd([(blue, 4), (red, 4), (green, 4)]),
      );
      final rules = JamRules(level);
      var state = rules.tap(rules.initialState(), 'r1').state;
      state = rules.tap(state, 'b1').state; // both depart
      expect(state.status, JamStatus.playing);
      expect(state.bays, const [null, null]);
    });

    JamLevel deadlock({bool withEscape = true}) => JamLevel(
      id: 'deadlock',
      width: 5,
      height: 3,
      bayCount: 3,
      vehicles: [
        bus('o1', orange, right, 1, 0),
        bus('p1', purple, left, 2, 0),
        if (withEscape) bus('r1', red, up, 4, 1),
      ],
      passengers: crowd([if (withEscape) (red, 4), (orange, 4), (purple, 4)]),
    );

    test('loses when no bus can be tapped while passengers wait', () {
      final rules = JamRules(deadlock());
      final start = rules.initialState();
      expect(start.status, JamStatus.playing);
      expect(rules.legalTaps(start), ['r1']);
      final result = rules.tap(start, 'r1');
      expect(result.state.passengerIndex, 4);
      expect(result.state.status, JamStatus.lost);
    });

    test('a level that starts deadlocked is lost immediately', () {
      expect(
        JamState.initial(deadlock(withEscape: false)).status,
        JamStatus.lost,
      );
    });

    test('wins when every passenger has boarded', () {
      final level = rowLevel(
        bays: 3,
        passengers: crowd([(red, 4), (blue, 4), (green, 4)]),
      );
      final session = JamSession(level);
      for (final id in ['r1', 'b1']) {
        expect(session.tap(id).state.status, JamStatus.playing);
      }
      final last = session.tap('g1');
      expect(last.state.status, JamStatus.won);
      expect(last.state.passengerIndex, level.passengers.length);
      expect(
        session.tap('g1').block,
        const JamBlock(JamBlockReason.notPlaying),
      );
    });
  });

  group('session', () {
    JamLevel level() =>
        rowLevel(bays: 2, passengers: crowd([(blue, 4), (red, 4), (green, 4)]));

    test('undo restores each prior state exactly', () {
      final session = JamSession(level());
      final s0 = session.state;
      expect(session.canUndo, isFalse);
      expect(session.undo(), isFalse);
      session.tap('r1');
      final s1 = session.state;
      session.tap('b1');
      expect(session.canUndo, isTrue);
      expect(session.undo(), isTrue);
      expect(session.state, same(s1));
      expect(session.undo(), isTrue);
      expect(session.state, same(s0));
      expect(session.state, JamState.initial(level()));
      expect(session.canUndo, isFalse);
    });

    test('blocked taps do not push history', () {
      final session = JamSession(level());
      session.tap('r1');
      session.tap('g1'); // lost
      expect(session.tap('b1').moved, isFalse);
      expect(session.undo(), isTrue);
      expect(session.undo(), isTrue);
      expect(session.canUndo, isFalse);
    });

    test('undo works after a loss and the game continues', () {
      final session = JamSession(level());
      session.tap('r1');
      final beforeLoss = session.state;
      session.tap('g1');
      expect(session.state.status, JamStatus.lost);
      expect(session.canUndo, isTrue);
      session.undo();
      expect(session.state, beforeLoss);
      expect(session.state.status, JamStatus.playing);
      session.tap('b1');
      session.tap('g1');
      expect(session.state.status, JamStatus.won);
    });

    test('retry restores the initial state and clears undo', () {
      final session = JamSession(level());
      session.tap('r1');
      session.tap('g1');
      session.retry();
      expect(session.state, same(session.initialState));
      expect(session.state, JamState.initial(level()));
      expect(session.canUndo, isFalse);
      expect(session.state.bays, const [null, null]);
      expect(session.state.moveCount, 0);
    });
  });

  group('validation', () {
    List<String> errorsOf(JamLevel Function() build) {
      try {
        build();
      } on JamLevelValidationException catch (e) {
        expect(e.levelId, 'bad');
        expect(e.message, contains('"bad"'));
        return e.errors;
      }
      fail('expected a validation error');
    }

    JamLevel make({
      int width = 4,
      int height = 4,
      int bays = 3,
      List<JamVehicle>? vehicles,
      List<JamColor>? passengers,
    }) => JamLevel(
      id: 'bad',
      width: width,
      height: height,
      bayCount: bays,
      vehicles: vehicles ?? [bus('r1', red, up, 0, 1)],
      passengers: passengers ?? crowd([(red, 4)]),
    );

    test('valid baseline builds', () {
      expect(make().vehicles, hasLength(1));
    });

    test('out of bounds', () {
      expect(
        errorsOf(() => make(vehicles: [bus('r1', red, up, 0, 3)])),
        contains(contains('r1" cell (0, 4) is outside the 4x4 lot')),
      );
    });

    test('overlap', () {
      expect(
        errorsOf(
          () => make(
            vehicles: [bus('r1', red, up, 0, 1), bus('r2', red, left, 0, 2)],
            passengers: crowd([(red, 8)]),
          ),
        ),
        contains('vehicle "r2" overlaps vehicle "r1" at (0, 2)'),
      );
    });

    test('duplicate and empty ids', () {
      final errors = errorsOf(
        () => make(
          vehicles: [
            bus('r1', red, up, 0, 1),
            bus('r1', red, up, 1, 1),
            bus('', red, up, 2, 1),
          ],
          passengers: crowd([(red, 12)]),
        ),
      );
      expect(errors, contains('duplicate vehicle id "r1"'));
      expect(errors, contains('vehicle ids must be non-empty'));
    });

    test('length and capacity', () {
      final errors = errorsOf(
        () => make(
          vehicles: [
            bus('a', red, up, 0, 0, length: 1, capacity: 4),
            bus('b', red, up, 1, 0, length: 5, capacity: 4),
            bus('c', red, up, 2, 1, capacity: 0),
          ],
        ),
      );
      expect(errors, contains('vehicle "a" length 1 must be 2..4'));
      expect(errors, contains('vehicle "b" length 5 must be 2..4'));
      expect(errors, contains('vehicle "c" capacity 0 must be at least 1'));
    });

    test('seats must equal riders per colour', () {
      final errors = errorsOf(
        () => make(passengers: crowd([(red, 3), (blue, 1)])),
      );
      expect(errors, contains('red: 4 seats but 3 riders (must be equal)'));
      expect(errors, contains('blue: 0 seats but 1 riders (must be equal)'));
    });

    test('bay count 1..8, empty passengers and vehicles', () {
      expect(
        errorsOf(() => make(bays: 0)),
        contains('bayCount 0 must be within 1..8'),
      );
      expect(
        errorsOf(() => make(bays: 9)),
        contains('bayCount 9 must be within 1..8'),
      );
      expect(
        errorsOf(() => make(vehicles: const [], passengers: const [])),
        containsAll([
          'level needs at least one vehicle',
          'level needs at least one passenger',
        ]),
      );
      expect(make(bays: 1).bayCount, 1);
      expect(make(bays: 8).bayCount, 8);
    });
  });
}
