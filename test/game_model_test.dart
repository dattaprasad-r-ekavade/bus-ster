import 'package:busster/game/game_model.dart';
import 'package:busster/game/game_session.dart';
import 'package:busster/game/levels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('depot rules', () {
    test('pathfinding reports a bus that is blocked by the center bus', () {
      final level = levels.first;
      final state = BoardState.initial(level);

      expect(GameRules.routeToExit(level, state, 'blue'), isNotNull);
      expect(GameRules.routeToExit(level, state, 'coral'), isNull);
      expect(GameRules.dispatch(level, state, 'coral').changed, isFalse);
    });

    test('correct dispatch order boards riders and clears the level', () {
      final level = levels.first;
      var state = BoardState.initial(level);

      state = GameRules.dispatch(level, state, 'blue').state;
      expect(state.parked.single.route, RouteKind.blue);
      expect(state.queueIndex, 0);

      state = GameRules.dispatch(level, state, 'coral').state;
      expect(state.queueIndex, 4);
      expect(state.parked, isEmpty);

      final finalMove = GameRules.dispatch(level, state, 'mint');
      expect(finalMove.state.status, GameStatus.won);
      expect(finalMove.state.queueIndex, level.passengers.length);
    });

    test('all prototype levels have a complete solver path', () {
      for (final level in levels) {
        expect(LevelSolver.findSolution(level), isNotNull, reason: level.id);
      }
    });

    test('session marks a full, unrecoverable bay state as stuck', () {
      final base = levels.first;
      final oneBayLevel = LevelSpec(
        id: 'one-bay-trap',
        title: base.title,
        width: base.width,
        height: base.height,
        exit: base.exit,
        roads: base.roads,
        buses: base.buses,
        passengers: base.passengers,
        bayCount: 1,
      );
      final session = GameSession(levelList: [oneBayLevel]);

      session.dispatch('blue');

      expect(session.state.status, GameStatus.stuck);
      expect(session.canUndo, isTrue);
      session.dispose();
    });
  });
}
