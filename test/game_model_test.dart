import 'dart:convert';
import 'dart:io';

import 'package:busster/game/game_model.dart';
import 'package:busster/game/game_progress.dart';
import 'package:busster/game/level_bundle.dart';
import 'package:busster/game/game_replay.dart';
import 'package:busster/game/game_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<LevelSpec> levels;

  setUpAll(() async {
    levels = LevelBundleCodec.decode(
      await File('assets/levels/levels.json').readAsString(),
    );
  });

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
      final session = GameSession(levelList: levels);
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

    test('saved progress restores the board and keeps undo history', () {
      final original = GameSession(levelList: levels)..dispatch('blue');
      final saved = original.progress;
      final restored = GameSession(levelList: levels)..restoreProgress(saved);

      expect(restored.level.id, original.level.id);
      expect(
        GameRules.stateKey(restored.state),
        GameRules.stateKey(original.state),
      );
      expect(restored.canUndo, isTrue);

      restored.undo();
      expect(restored.state.moveCount, 0);
      expect(restored.replayRecord.dispatches, isEmpty);
      original.dispose();
      restored.dispose();
    });

    test('route tips spend credits once and empty balance stays optional', () {
      final session = GameSession(levelList: levels);
      expect(session.earnedHints, GameProgress.initialHintCredits);

      session.showHint();
      expect(session.earnedHints, 2);
      session.showHint();
      expect(session.earnedHints, 2);

      session
        ..dispatch('blue')
        ..showHint()
        ..dispatch('coral')
        ..showHint()
        ..dispatch('mint');
      expect(session.state.status, GameStatus.won);
      expect(session.earnedHints, 1);

      session.restart();
      session
        ..dispatch('blue')
        ..dispatch('coral')
        ..dispatch('mint');
      expect(session.earnedHints, 1);
      session.dispose();
    });

    test(
      'level selection unlocks in order and confirms losing partial progress',
      () {
        final session = GameSession(levelList: levels);
        expect(session.isLevelUnlocked(0), isTrue);
        expect(session.isLevelUnlocked(1), isFalse);

        session
          ..dispatch('blue')
          ..dispatch('coral')
          ..dispatch('mint');
        expect(session.isLevelUnlocked(1), isTrue);
        session.nextLevel();
        expect(session.level.id, 'depot-02');

        session.selectLevel(0);
        session.dispatch('blue');
        expect(session.selectLevel(1), isFalse);
        expect(session.selectLevel(1, discardCurrentProgress: true), isTrue);
        expect(session.level.id, 'depot-02');
        expect(session.state.moveCount, 0);
        expect(session.progress.completedLevelIds, contains('depot-01'));
        session.dispose();
      },
    );

    test('restored win retains completion and advances to the next depot', () {
      final original = GameSession(levelList: levels)
        ..dispatch('blue')
        ..dispatch('coral')
        ..dispatch('mint');
      final restored = GameSession(levelList: levels)
        ..restoreProgress(original.progress);

      expect(restored.state.status, GameStatus.won);
      expect(restored.progress.completedLevelIds, contains('depot-01'));
      expect(restored.earnedHints, GameProgress.initialHintCredits + 1);
      restored.nextLevel();
      expect(restored.level.id, 'depot-02');
      expect(restored.progress.dispatches, isEmpty);
      expect(restored.progress.completedLevelIds, contains('depot-01'));

      original.dispose();
      restored.dispose();
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
      final session = GameSession(levelList: levels);
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
        final session = GameSession(levelList: levels);
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
