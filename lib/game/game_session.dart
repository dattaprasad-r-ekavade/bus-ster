import 'package:flutter/foundation.dart';

import 'game_model.dart';
import 'game_progress.dart';
import 'game_replay.dart';
import 'game_telemetry.dart';

class GameSession extends ChangeNotifier {
  GameSession({
    required List<LevelSpec> levelList,
    GameTelemetry telemetry = const NoopGameTelemetry(),
    bool logInitialLevelStart = true,
  }) : _levels = List.unmodifiable(levelList),
       _telemetry = telemetry {
    if (_levels.isEmpty) {
      throw ArgumentError.value(levelList, 'levelList', 'Must not be empty.');
    }
    _state = BoardState.initial(level);
    _message = _levelStartMessage;
    if (logInitialLevelStart) {
      _recordLevelStarted('new_run');
    }
  }

  static const _defaultStartMessage =
      'Send the right buses to the gate. Follow the rider queue.';

  final List<LevelSpec> _levels;
  final GameTelemetry _telemetry;
  final List<BoardState> _history = [];
  final List<String> _dispatchLog = [];
  final Set<String> _completedLevelIds = {};
  late BoardState _state;
  int _levelIndex = 0;
  String _message = _defaultStartMessage;
  String? _hintedBusId;
  DispatchAnimation? _lastDispatchAnimation;
  int _animationSerial = 0;
  bool _isPaused = false;
  int _earnedHints = GameProgress.initialHintCredits;

  LevelSpec get level => _levels[_levelIndex];
  BoardState get state => _state;
  int get levelIndex => _levelIndex;
  int get earnedHints => _earnedHints;
  String get message => _message;
  bool get canUndo => _history.isNotEmpty;
  String? get hintedBusId => _hintedBusId;
  DispatchAnimation? get lastDispatchAnimation => _lastDispatchAnimation;
  int get animationSerial => _animationSerial;
  bool get isPaused => _isPaused;
  bool get hasUncommittedMoves =>
      _dispatchLog.isNotEmpty && _state.status != GameStatus.won;
  GameReplayRecord get replayRecord =>
      GameReplayRecord(levelId: level.id, dispatches: _dispatchLog);
  GameProgress get progress => GameProgress(
    currentLevelId: level.id,
    dispatches: _dispatchLog,
    completedLevelIds: _completedLevelIds,
    earnedHints: _earnedHints,
  );
  String get _levelStartMessage {
    final prompt = level.tutorialPrompt.trim();
    return prompt.isEmpty ? _defaultStartMessage : prompt;
  }

  DispatchResult? dispatch(String busId) {
    if (_isPaused) return null;
    _hintedBusId = null;
    final path = GameRules.routeToExit(level, _state, busId);
    final result = GameRules.dispatch(level, _state, busId);
    if (!result.changed) {
      _record(GameEventNames.dispatchRejected, {
        'level_id': level.id,
        'move_number': _state.moveCount,
        'reason': _dispatchRejectionReason(busId, path),
      });
      _message = result.message;
      notifyListeners();
      return result;
    }

    _history.add(_state);
    _dispatchLog.add(busId);
    _state = result.state;
    if (path != null) {
      _lastDispatchAnimation = DispatchAnimation(
        route: level.busById(busId).route,
        path: path,
      );
      _animationSerial++;
    }
    _message = _dispatchFeedback(busId, path, result);
    if (_state.status != GameStatus.won &&
        LevelSolver.findSolution(level, start: _state) == null) {
      _state = _state.copyWith(status: GameStatus.stuck);
      _message = 'No clear route remains. Undo a dispatch or retry the depot.';
    }
    final firstClear =
        _state.status == GameStatus.won && _completedLevelIds.add(level.id);
    if (firstClear) {
      _earnedHints = (_earnedHints + 1)
          .clamp(0, GameProgress.maxHintCredits)
          .toInt();
    }
    _record(GameEventNames.busDispatched, {
      'level_id': level.id,
      'move_number': _state.moveCount,
      'route': level.busById(busId).route.name,
      'riders_boarded': result.boardedRiders.length,
      'buses_parked': _state.parked.length,
    });
    if (_state.status == GameStatus.won) {
      _record(GameEventNames.levelCompleted, {
        'level_id': level.id,
        'move_count': _state.moveCount,
        'first_clear': firstClear ? 1 : 0,
      });
    } else if (_state.status == GameStatus.stuck) {
      _record(GameEventNames.levelStuck, {
        'level_id': level.id,
        'move_count': _state.moveCount,
        'buses_parked': _state.parked.length,
      });
    }
    notifyListeners();
    return result;
  }

  void showHint() {
    if (_isPaused || _state.status != GameStatus.playing) return;
    if (_hintedBusId != null) return;
    if (_earnedHints == 0) {
      _record(GameEventNames.routeTipUnavailable, {
        'level_id': level.id,
        'reason': 'empty_balance',
      });
      _message = 'No route tips left. Clear a depot to earn one.';
      notifyListeners();
      return;
    }
    final solution = LevelSolver.findSolution(level, start: _state);
    if (solution == null || solution.isEmpty) {
      _record(GameEventNames.routeTipUnavailable, {
        'level_id': level.id,
        'reason': 'no_solution',
      });
      _message = 'No route found. Undo a dispatch or retry the depot.';
    } else {
      final bus = level.busById(solution.first);
      _earnedHints--;
      _hintedBusId = bus.id;
      _message =
          'Route tip ($_earnedHints left): dispatch the '
          '${bus.route.label} bus.';
      _record(GameEventNames.routeTipUsed, {
        'level_id': level.id,
        'route': bus.route.name,
        'remaining': _earnedHints,
      });
    }
    notifyListeners();
  }

  void undo() {
    if (_isPaused || _history.isEmpty) return;
    _hintedBusId = null;
    _lastDispatchAnimation = null;
    _animationSerial++;
    _state = _history.removeLast();
    _dispatchLog.removeLast();
    _record(GameEventNames.moveUndone, {
      'level_id': level.id,
      'move_count': _state.moveCount,
    });
    _message = 'Last dispatch undone. Check the rider queue and road.';
    notifyListeners();
  }

  void restart() {
    final discardedMoves = _state.moveCount;
    _hintedBusId = null;
    _lastDispatchAnimation = null;
    _animationSerial++;
    _state = BoardState.initial(level);
    _history.clear();
    _dispatchLog.clear();
    _message = _levelStartMessage;
    _record(GameEventNames.levelRestarted, {
      'level_id': level.id,
      'moves_discarded': discardedMoves,
    });
    notifyListeners();
  }

  void pause() {
    if (_isPaused) return;
    _isPaused = true;
    notifyListeners();
  }

  void resume() {
    if (!_isPaused) return;
    _isPaused = false;
    notifyListeners();
  }

  void restoreProgress(GameProgress progress) {
    final levelIndex = _levels.indexWhere(
      (candidate) => candidate.id == progress.currentLevelId,
    );
    if (levelIndex < 0) {
      throw FormatException(
        'Saved level "${progress.currentLevelId}" is not in this build.',
      );
    }

    final level = _levels[levelIndex];
    final states = progress.replay.replayStates(level);
    final knownLevelIds = _levels.map((candidate) => candidate.id).toSet();
    _levelIndex = levelIndex;
    _state = states.last;
    _history
      ..clear()
      ..addAll(states.take(states.length - 1));
    _dispatchLog
      ..clear()
      ..addAll(progress.dispatches);
    _completedLevelIds
      ..clear()
      ..addAll(progress.completedLevelIds.where(knownLevelIds.contains));
    for (var previous = 0; previous < levelIndex; previous++) {
      _completedLevelIds.add(_levels[previous].id);
    }
    _earnedHints = progress.earnedHints;
    if (_state.status == GameStatus.won) _completedLevelIds.add(level.id);
    _hintedBusId = null;
    _lastDispatchAnimation = null;
    _animationSerial++;
    _isPaused = false;
    _message = switch (_state.status) {
      GameStatus.playing => 'Progress restored. Continue this depot.',
      GameStatus.stuck => 'This saved route is stuck. Undo or retry the depot.',
      GameStatus.won => 'This depot is clear. Continue to the next depot.',
    };
    _record(GameEventNames.levelResumed, {
      'level_id': level.id,
      'move_count': _state.moveCount,
    });
    notifyListeners();
  }

  String _dispatchFeedback(
    String busId,
    List<GridPoint>? path,
    DispatchResult result,
  ) {
    final route = level.busById(busId).route;
    final details = <String>[
      if (_state.status == GameStatus.won)
        'Depot clear!'
      else if (path != null && path.length == 1)
        '${route.label} entered a bay.'
      else
        '${route.label} sent.',
    ];
    final boardedCount = result.boardedRiders.length;
    if (boardedCount > 0) {
      details.add(
        '$boardedCount ${boardedCount == 1 ? 'rider' : 'riders'} boarded',
      );
    }
    final departedCount = result.departedBusIds.length;
    if (departedCount > 0) {
      details.add(
        '$departedCount ${departedCount == 1 ? 'bus' : 'buses'} left the depot',
      );
    }
    if (_state.status != GameStatus.won &&
        boardedCount == 0 &&
        departedCount == 0) {
      details.add('No riders matched; bus waits in a bay');
    }
    return details.join(' · ');
  }

  String _dispatchRejectionReason(String busId, List<GridPoint>? path) {
    if (_state.status != GameStatus.playing) return 'level_finished';
    if (!_state.activeBusIds.contains(busId)) return 'inactive_bus';
    if (path == null) return 'blocked_path';
    if (_state.parked.length >= level.bayCount) return 'bays_full';
    return 'rule_rejected';
  }

  void _record(String name, Map<String, Object> parameters) {
    try {
      _telemetry.record(GameEvent(name: name, parameters: parameters));
    } on Object {
      // A future analytics adapter must not interfere with offline gameplay.
    }
  }

  void nextLevel() {
    if (_state.status == GameStatus.won && _levelIndex < _levels.length - 1) {
      _levelIndex++;
      _state = BoardState.initial(level);
      _history.clear();
      _dispatchLog.clear();
      _hintedBusId = null;
      _lastDispatchAnimation = null;
      _animationSerial++;
      _message = _levelStartMessage;
    } else if (_state.status == GameStatus.won) {
      _levelIndex = 0;
      _state = BoardState.initial(level);
      _history.clear();
      _dispatchLog.clear();
      _hintedBusId = null;
      _lastDispatchAnimation = null;
      _animationSerial++;
      _message = _levelStartMessage;
    } else {
      restart();
      return;
    }
    _recordLevelStarted('next');
    notifyListeners();
  }

  bool isLevelUnlocked(int index) {
    if (index < 0 || index >= _levels.length) return false;
    var furthestUnlocked = 0;
    for (var previous = 0; previous < _levels.length - 1; previous++) {
      if (!_completedLevelIds.contains(_levels[previous].id)) break;
      furthestUnlocked = previous + 1;
    }
    return index <= furthestUnlocked;
  }

  bool selectLevel(int index, {bool discardCurrentProgress = false}) {
    if (!isLevelUnlocked(index)) return false;
    if (hasUncommittedMoves && !discardCurrentProgress) return false;
    if (index == _levelIndex) return true;

    _levelIndex = index;
    _state = BoardState.initial(level);
    _history.clear();
    _dispatchLog.clear();
    _hintedBusId = null;
    _lastDispatchAnimation = null;
    _animationSerial++;
    _isPaused = false;
    _message = _levelStartMessage;
    _recordLevelStarted('selection');
    notifyListeners();
    return true;
  }

  void _recordLevelStarted(String entrySource) {
    _record(GameEventNames.levelStarted, {
      'level_id': level.id,
      'level_index': _levelIndex + 1,
      'entry_source': entrySource,
    });
  }
}

class DispatchAnimation {
  const DispatchAnimation({required this.route, required this.path});

  final RouteKind route;
  final List<GridPoint> path;
}
