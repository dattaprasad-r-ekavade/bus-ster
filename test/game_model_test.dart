import 'dart:convert';

import 'package:busster/game/game_model.dart';
import 'package:busster/game/game_replay.dart';
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

      final coralDispatch = GameRules.dispatch(level, state, 'coral');
      expect(coralDispatch.boardedRiders, [
        RouteKind.coral,
        RouteKind.coral,
        RouteKind.blue,
        RouteKind.blue,
      ]);
      expect(coralDispatch.departedBusIds, ['coral', 'blue']);
      state = coralDispatch.state;
      expect(state.queueIndex, 4);
      expect(state.parked, isEmpty);

      final finalMove = GameRules.dispatch(level, state, 'mint');
      expect(finalMove.state.status, GameStatus.won);
      expect(finalMove.state.queueIndex, level.passengers.length);
    });

    test('all prototype levels have a complete solver path', () {
      for (final level in levels) {
        expect(LevelSolver.findSolution(level), isNotNull, reason: level.id);
        expect(level.tutorialPrompt.trim(), isNotEmpty, reason: level.id);
      }
    });

    test('tutorial prompt follows the active level and restarts', () {
      final session = GameSession();
      expect(session.message, levels[0].tutorialPrompt);

      session.restart();
      expect(session.message, levels[0].tutorialPrompt);

      session
        ..dispatch('blue')
        ..dispatch('coral')
        ..dispatch('mint')
        ..nextLevel();
      expect(session.levelIndex, 1);
      expect(session.message, levels[1].tutorialPrompt);
      session.dispose();
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

    test('paused session ignores dispatches until resumed', () {
      final session = GameSession();
      final initialKey = GameRules.stateKey(session.state);

      session.pause();
      session.dispatch('blue');
      expect(session.isPaused, isTrue);
      expect(GameRules.stateKey(session.state), initialKey);

      session.resume();
      session.dispatch('blue');
      expect(session.isPaused, isFalse);
      expect(session.state.activeBusIds, isNot(contains('blue')));
      session.dispose();
    });

    test(
      'dispatch replay reproduces state and undo removes the last command',
      () {
        final session = GameSession();
        session
          ..dispatch('blue')
          ..dispatch('coral')
          ..dispatch('mint');

        final encoded = jsonEncode(session.replayRecord.toJson());
        final decoded = GameReplayRecord.fromJson(
          jsonDecode(encoded) as Map<String, Object?>,
        );
        final replayedState = decoded.replay(session.level);

        expect(replayedState.status, GameStatus.won);
        expect(
          GameRules.stateKey(replayedState),
          GameRules.stateKey(session.state),
        );

        session.undo();
        expect(session.replayRecord.dispatches, ['blue', 'coral']);
        expect(session.state.status, GameStatus.playing);
        session.dispose();
      },
    );
  });
}
