import 'package:flutter/foundation.dart';

import 'game_model.dart';
import 'game_replay.dart';
import 'levels.dart';

class GameSession extends ChangeNotifier {
  GameSession({List<LevelSpec>? levelList}) : _levels = levelList ?? levels {
    _state = BoardState.initial(level);
  }

  final List<LevelSpec> _levels;
  final List<BoardState> _history = [];
  final List<String> _dispatchLog = [];
  late BoardState _state;
  int _levelIndex = 0;
  String _message = 'Send the right buses to the gate. Follow the rider queue.';
  String? _hintedBusId;
  DispatchAnimation? _lastDispatchAnimation;
  int _animationSerial = 0;

  LevelSpec get level => _levels[_levelIndex];
  BoardState get state => _state;
  int get levelIndex => _levelIndex;
  String get message => _message;
  bool get canUndo => _history.isNotEmpty;
  String? get hintedBusId => _hintedBusId;
  DispatchAnimation? get lastDispatchAnimation => _lastDispatchAnimation;
  int get animationSerial => _animationSerial;
  GameReplayRecord get replayRecord =>
      GameReplayRecord(levelId: level.id, dispatches: _dispatchLog);

  void dispatch(String busId) {
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
    _message = result.message;
    if (_state.status != GameStatus.won &&
        LevelSolver.findSolution(level, start: _state) == null) {
      _state = _state.copyWith(status: GameStatus.stuck);
      _message = 'No clear route remains. Undo a dispatch or retry the depot.';
    }
    notifyListeners();
  }

  void showHint() {
    if (_state.status != GameStatus.playing) return;
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
    if (_history.isEmpty) return;
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
    _message = 'Send the right buses to the gate. Follow the rider queue.';
    notifyListeners();
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
      _message = 'New depot. Read the queue, then clear the road to the gate.';
    } else if (_state.status == GameStatus.won) {
      _levelIndex = 0;
      _state = BoardState.initial(level);
      _history.clear();
      _hintedBusId = null;
      _lastDispatchAnimation = null;
      _animationSerial++;
      _message = 'Prototype route complete. Play the depots again.';
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
