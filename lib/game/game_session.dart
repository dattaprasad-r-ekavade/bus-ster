import 'package:flutter/foundation.dart';

import 'game_model.dart';
import 'game_replay.dart';
import 'levels.dart';

class GameSession extends ChangeNotifier {
  GameSession({List<LevelSpec>? levelList}) : _levels = levelList ?? levels {
    _state = BoardState.initial(level);
    _message = _levelStartMessage;
  }

  static const _defaultStartMessage =
      'Send the right buses to the gate. Follow the rider queue.';

  final List<LevelSpec> _levels;
  final List<BoardState> _history = [];
  final List<String> _dispatchLog = [];
  late BoardState _state;
  int _levelIndex = 0;
  String _message = _defaultStartMessage;
  String? _hintedBusId;
  DispatchAnimation? _lastDispatchAnimation;
  int _animationSerial = 0;
  bool _isPaused = false;

  LevelSpec get level => _levels[_levelIndex];
  BoardState get state => _state;
  int get levelIndex => _levelIndex;
  String get message => _message;
  bool get canUndo => _history.isNotEmpty;
  String? get hintedBusId => _hintedBusId;
  DispatchAnimation? get lastDispatchAnimation => _lastDispatchAnimation;
  int get animationSerial => _animationSerial;
  bool get isPaused => _isPaused;
  GameReplayRecord get replayRecord =>
      GameReplayRecord(levelId: level.id, dispatches: _dispatchLog);
  String get _levelStartMessage {
    final prompt = level.tutorialPrompt.trim();
    return prompt.isEmpty ? _defaultStartMessage : prompt;
  }

  void dispatch(String busId) {
    if (_isPaused) return;
    _hintedBusId = null;
    final path = GameRules.routeToExit(level, _state, busId);
    final result = GameRules.dispatch(level, _state, busId);
    if (!result.changed) {
      _message = result.message;
      notifyListeners();
      return;
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
    notifyListeners();
  }

  void showHint() {
    if (_isPaused || _state.status != GameStatus.playing) return;
    final solution = LevelSolver.findSolution(level, start: _state);
    if (solution == null || solution.isEmpty) {
      _message = 'No route found. Undo a dispatch or retry the depot.';
    } else {
      final bus = level.busById(solution.first);
      _hintedBusId = bus.id;
      _message =
          'Route tip: dispatch the ${bus.route.label} bus (${bus.route.symbol}).';
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
    _message = 'Last dispatch undone. Check the rider queue and road.';
    notifyListeners();
  }

  void restart() {
    _hintedBusId = null;
    _lastDispatchAnimation = null;
    _animationSerial++;
    _state = BoardState.initial(level);
    _history.clear();
    _dispatchLog.clear();
    _message = _levelStartMessage;
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
      _hintedBusId = null;
      _lastDispatchAnimation = null;
      _animationSerial++;
      _message = _levelStartMessage;
    } else {
      restart();
      return;
    }
    notifyListeners();
  }
}

class DispatchAnimation {
  const DispatchAnimation({required this.route, required this.path});

  final RouteKind route;
  final List<GridPoint> path;
}
