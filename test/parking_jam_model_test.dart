import 'package:busster/game/parking_jam_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  JamLevel chainLevel() => JamLevel(
    width: 5,
    height: 5,
    bayCount: 1,
    vehicles: const [
      JamVehicle(
        id: 'blue',
        origin: JamCell(1, 1),
        facing: JamFacing.left,
        length: 2,
        route: JamRoute.blue,
        capacity: 1,
      ),
      JamVehicle(
        id: 'coral',
        origin: JamCell(2, 2),
        facing: JamFacing.up,
        length: 2,
        route: JamRoute.coral,
        capacity: 1,
      ),
    ],
    passengers: const [JamRoute.blue, JamRoute.coral],
  );

  test(
    'blocked tap identifies the first vehicle and keeps state unchanged',
    () {
      final session = JamSession(chainLevel());
      final before = session.state;
      final move = session.release('coral');

      expect(move.moved, isFalse);
      expect(move.block, JamBlock.vehicle);
      expect(move.blockingVehicleId, 'blue');
      expect(session.state, same(before));
      expect(session.undo(), isFalse);
    },
  );

  test('directional release opens a chain and boards matching riders', () {
    final session = JamSession(chainLevel());
    final blueMove = session.release('blue');
    expect(blueMove.moved, isTrue);
    expect(blueMove.boarded, 1);
    expect(blueMove.departedBusIds, ['blue']);
    expect(blueMove.state.activeVehicleIds, {'coral'});
    expect(blueMove.state.status, JamStatus.playing);

    final coralMove = session.release('coral');
    expect(coralMove.moved, isTrue);
    expect(coralMove.boarded, 1);
    expect(coralMove.state.passengerIndex, 2);
    expect(coralMove.state.status, JamStatus.won);
    expect(JamRules(chainLevel()).solve(), ['blue', 'coral']);
  });

  test('full boarding space blocks release and undo restores all state', () {
    final level = JamLevel(
      width: 5,
      height: 4,
      bayCount: 1,
      vehicles: const [
        JamVehicle(
          id: 'coral',
          origin: JamCell(0, 1),
          facing: JamFacing.left,
          length: 2,
          route: JamRoute.coral,
          capacity: 2,
        ),
        JamVehicle(
          id: 'blue',
          origin: JamCell(3, 2),
          facing: JamFacing.right,
          length: 2,
          route: JamRoute.blue,
          capacity: 1,
        ),
      ],
      passengers: const [JamRoute.coral, JamRoute.blue, JamRoute.coral],
    );
    final session = JamSession(level);
    final initial = session.state;
    final first = session.release('coral');
    expect(first.boarded, 1);
    expect(first.state.parked.single.loaded, 1);
    expect(first.state.status, JamStatus.stuck);

    final blocked = session.release('blue');
    expect(blocked.block, JamBlock.fullBays);
    expect(session.state, same(first.state));

    expect(session.undo(), isTrue);
    expect(session.state, same(initial));
    expect(session.state.passengerIndex, 0);
    expect(session.state.activeVehicleIds, {'coral', 'blue'});
    expect(session.state.parked, isEmpty);
    expect(session.release('blue').moved, isTrue);
    session.retry();
    expect(session.state.solverKey, initial.solverKey);
    expect(session.state.moveCount, 0);
  });

  test('every selectable piece is a colored bus that serves riders', () {
    final level = JamLevel(
      width: 5,
      height: 5,
      bayCount: 2,
      vehicles: const [
        JamVehicle(
          id: 'blue-blocker-bus',
          origin: JamCell(1, 1),
          facing: JamFacing.left,
          length: 2,
          route: JamRoute.blue,
          capacity: 1,
        ),
        JamVehicle(
          id: 'mint-bus',
          origin: JamCell(2, 2),
          facing: JamFacing.up,
          length: 2,
          route: JamRoute.mint,
          capacity: 1,
        ),
      ],
      passengers: const [JamRoute.blue, JamRoute.mint],
    );
    final session = JamSession(level);
    expect(session.release('mint-bus').blockingVehicleId, 'blue-blocker-bus');
    final blockerBus = session.release('blue-blocker-bus');
    expect(blockerBus.moved, isTrue);
    expect(blockerBus.boarded, 1);
    expect(blockerBus.departedBusIds, ['blue-blocker-bus']);
    expect(blockerBus.state.parked, isEmpty);
    expect(session.release('mint-bus').state.status, JamStatus.won);
  });

  test(
    'a bus may wait in a stop until its passenger group reaches the front',
    () {
      final level = JamLevel(
        width: 4,
        height: 3,
        bayCount: 2,
        vehicles: const [
          JamVehicle(
            id: 'coral',
            origin: JamCell(0, 0),
            facing: JamFacing.left,
            length: 2,
            route: JamRoute.coral,
            capacity: 1,
          ),
          JamVehicle(
            id: 'blue',
            origin: JamCell(2, 1),
            facing: JamFacing.right,
            length: 2,
            route: JamRoute.blue,
            capacity: 1,
          ),
        ],
        passengers: const [JamRoute.blue, JamRoute.coral],
      );
      final session = JamSession(level);

      final earlyCoral = session.release('coral');
      expect(earlyCoral.moved, isTrue);
      expect(earlyCoral.boarded, 0);
      expect(earlyCoral.state.parked.single.id, 'coral');
      expect(earlyCoral.state.status, JamStatus.playing);

      final blue = session.release('blue');
      expect(blue.boarded, 2);
      expect(blue.departedBusIds, ['blue', 'coral']);
      expect(blue.state.status, JamStatus.won);
    },
  );

  test('invalid overlapping footprints and seat counts are rejected', () {
    expect(
      () => JamLevel(
        width: 4,
        height: 4,
        bayCount: 1,
        vehicles: const [
          JamVehicle(
            id: 'a',
            origin: JamCell(1, 1),
            facing: JamFacing.left,
            length: 2,
            route: JamRoute.blue,
            capacity: 1,
          ),
          JamVehicle(
            id: 'b',
            origin: JamCell(2, 1),
            facing: JamFacing.right,
            length: 2,
            route: JamRoute.coral,
            capacity: 1,
          ),
        ],
        passengers: const [],
      ),
      throwsArgumentError,
    );
    expect(
      () => JamLevel(
        width: 4,
        height: 4,
        bayCount: 1,
        vehicles: const [
          JamVehicle(
            id: 'bus',
            origin: JamCell(0, 0),
            facing: JamFacing.right,
            length: 2,
            route: JamRoute.gold,
            capacity: 2,
          ),
        ],
        passengers: const [JamRoute.gold],
      ),
      throwsArgumentError,
    );
  });
}
