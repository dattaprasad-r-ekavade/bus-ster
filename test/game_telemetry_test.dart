import 'dart:io';

import 'package:busster/game/game_model.dart';
import 'package:busster/game/game_progress.dart';
import 'package:busster/game/game_session.dart';
import 'package:busster/game/game_telemetry.dart';
import 'package:busster/game/level_bundle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<LevelSpec> levels;

  setUpAll(() async {
    levels = LevelBundleCodec.decode(
      await File('assets/levels/levels.json').readAsString(),
    );
  });

  test('records gameplay events with stable, minimal parameters', () {
    final telemetry = _RecordingTelemetry();
    final session = GameSession(levelList: levels, telemetry: telemetry);

    session.dispatch('coral');
    session.showHint();
    session.dispatch('blue');
    session.undo();
    session.dispatch('blue');
    session.dispatch('coral');
    session.dispatch('mint');

    expect(telemetry.events.map((event) => event.name), [
      GameEventNames.levelStarted,
      GameEventNames.dispatchRejected,
      GameEventNames.routeTipUsed,
      GameEventNames.busDispatched,
      GameEventNames.moveUndone,
      GameEventNames.busDispatched,
      GameEventNames.busDispatched,
      GameEventNames.busDispatched,
      GameEventNames.levelCompleted,
    ]);
    expect(telemetry.events[1].parameters['reason'], 'blocked_path');
    expect(telemetry.events[2].parameters['route'], 'blue');
    expect(telemetry.events.last.parameters['first_clear'], 1);
    expect(session.state.status, GameStatus.won);

    session.nextLevel();
    expect(session.selectLevel(0), isTrue);
    session
      ..dispatch('blue')
      ..dispatch('coral')
      ..dispatch('mint');
    final completionEvents = telemetry.events
        .where((event) => event.name == GameEventNames.levelCompleted)
        .toList();
    expect(completionEvents.map((event) => event.parameters['first_clear']), [
      1,
      0,
    ]);
  });

  test('a saved run records a resume without a fresh level start', () {
    final telemetry = _RecordingTelemetry();
    final session = GameSession(
      levelList: levels,
      telemetry: telemetry,
      logInitialLevelStart: false,
    );

    session.restoreProgress(
      GameProgress(
        currentLevelId: 'depot-02',
        dispatches: const ['coral'],
        completedLevelIds: const ['depot-01'],
      ),
    );

    expect(telemetry.events.map((event) => event.name), [
      GameEventNames.levelResumed,
    ]);
    expect(telemetry.events.single.parameters['level_id'], 'depot-02');
  });

  test('a telemetry adapter failure does not interrupt gameplay', () {
    final session = GameSession(
      levelList: levels,
      telemetry: const _ThrowingTelemetry(),
    );

    session.dispatch('blue');

    expect(session.state.moveCount, 1);
    expect(session.state.activeBusIds, isNot(contains('blue')));
  });

  test('rewarded hint offer and reward events stay gated by live play', () {
    final telemetry = _RecordingTelemetry();
    final session = GameSession(levelList: levels, telemetry: telemetry);
    session.restoreProgress(
      GameProgress(
        currentLevelId: 'depot-01',
        dispatches: const [],
        earnedHints: 0,
      ),
    );

    session
      ..recordRewardedHintOffer()
      ..pause();
    expect(session.grantRewardedHint(), isFalse);
    expect(session.earnedHints, 0);

    session.resume();
    session.recordRewardedHintOffer();
    expect(session.grantRewardedHint(), isTrue);
    expect(session.earnedHints, 1);
    expect(
      telemetry.events.where((event) => event.name == GameEventNames.adOffer),
      hasLength(2),
    );
    expect(
      telemetry.events.where((event) => event.name == GameEventNames.adReward),
      hasLength(1),
    );
    expect(telemetry.events.last.parameters['reward'], 'one_route_tip');
  });
}

class _RecordingTelemetry implements GameTelemetry {
  final List<GameEvent> events = [];

  @override
  void record(GameEvent event) => events.add(event);
}

class _ThrowingTelemetry implements GameTelemetry {
  const _ThrowingTelemetry();

  @override
  void record(GameEvent event) => throw StateError('offline adapter');
}
