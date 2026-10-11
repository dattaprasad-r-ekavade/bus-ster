import 'dart:collection';

enum RouteKind { coral, blue, mint, gold }

extension RouteKindPresentation on RouteKind {
  int get colorValue => switch (this) {
    RouteKind.coral => 0xFFFF806B,
    RouteKind.blue => 0xFF67D8F2,
    RouteKind.mint => 0xFF8DE0A7,
    RouteKind.gold => 0xFFFFD166,
  };

  String get symbol => switch (this) {
    RouteKind.coral => '●',
    RouteKind.blue => '◆',
    RouteKind.mint => '▲',
    RouteKind.gold => '✦',
  };

  String get label => switch (this) {
    RouteKind.coral => 'Coral',
    RouteKind.blue => 'Blue',
    RouteKind.mint => 'Mint',
    RouteKind.gold => 'Gold',
  };
}

enum GameStatus { playing, won, stuck }

class GridPoint {
  const GridPoint(this.x, this.y);

  final int x;
  final int y;

  Iterable<GridPoint> get neighbors sync* {
    yield GridPoint(x + 1, y);
    yield GridPoint(x - 1, y);
    yield GridPoint(x, y + 1);
    yield GridPoint(x, y - 1);
  }

  @override
  bool operator ==(Object other) =>
      other is GridPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x,$y)';
}

class BusSpec {
  const BusSpec({
    required this.id,
    required this.route,
    required this.position,
    required this.capacity,
  });

  final String id;
  final RouteKind route;
  final GridPoint position;
  final int capacity;
}

class LevelSpec {
  LevelSpec({
    required this.id,
    required this.title,
    required this.width,
    required this.height,
    required this.exit,
    required Iterable<GridPoint> roads,
    required Iterable<BusSpec> buses,
    required Iterable<RouteKind> passengers,
    this.bayCount = 3,
  }) : roads = UnmodifiableSetView(roads.toSet()),
       buses = List.unmodifiable(buses),
       passengers = List.unmodifiable(passengers) {
    if (!this.roads.contains(exit)) {
      throw ArgumentError('The exit must be part of the road network.');
    }
    if (this.buses.map((bus) => bus.id).toSet().length != this.buses.length) {
      throw ArgumentError('Bus IDs must be unique.');
    }
    if (this.buses.any((bus) => !this.roads.contains(bus.position))) {
      throw ArgumentError('Every bus must start on a road tile.');
    }
    if (this.buses.map((bus) => bus.position).toSet().length !=
        this.buses.length) {
      throw ArgumentError('Two buses cannot occupy the same road tile.');
    }
  }

  final String id;
  final String title;
  final int width;
  final int height;
  final GridPoint exit;
  final Set<GridPoint> roads;
  final List<BusSpec> buses;
  final List<RouteKind> passengers;
  final int bayCount;

  BusSpec busById(String id) => buses.firstWhere((bus) => bus.id == id);
}

class ParkedBus {
  const ParkedBus({
    required this.id,
    required this.route,
    required this.capacity,
    this.loaded = 0,
  });

  final String id;
  final RouteKind route;
  final int capacity;
  final int loaded;

  ParkedBus withLoaded(int value) =>
      ParkedBus(id: id, route: route, capacity: capacity, loaded: value);
}

class BoardState {
  BoardState({
    required Iterable<String> activeBusIds,
    required Iterable<ParkedBus> parked,
    this.queueIndex = 0,
    this.moveCount = 0,
    this.status = GameStatus.playing,
  }) : activeBusIds = UnmodifiableSetView(activeBusIds.toSet()),
       parked = List.unmodifiable(parked);

  factory BoardState.initial(LevelSpec level) => BoardState(
    activeBusIds: level.buses.map((bus) => bus.id),
    parked: const [],
  );

  final Set<String> activeBusIds;
  final List<ParkedBus> parked;
  final int queueIndex;
  final int moveCount;
  final GameStatus status;

  BoardState copyWith({
    Iterable<String>? activeBusIds,
    Iterable<ParkedBus>? parked,
    int? queueIndex,
    int? moveCount,
    GameStatus? status,
  }) => BoardState(
    activeBusIds: activeBusIds ?? this.activeBusIds,
    parked: parked ?? this.parked,
    queueIndex: queueIndex ?? this.queueIndex,
    moveCount: moveCount ?? this.moveCount,
    status: status ?? this.status,
  );
}

class DispatchResult {
  const DispatchResult({
    required this.state,
    required this.message,
    required this.changed,
  });

  final BoardState state;
  final String message;
  final bool changed;
}

class GameRules {
  static List<GridPoint>? routeToExit(
    LevelSpec level,
    BoardState state,
    String busId,
  ) {
    if (!state.activeBusIds.contains(busId)) return null;
    final start = level.busById(busId).position;
    final occupied = <GridPoint>{
      for (final id in state.activeBusIds)
        if (id != busId) level.busById(id).position,
    };
    if (occupied.contains(start)) return null;

    final frontier = Queue<GridPoint>()..add(start);
    final previous = <GridPoint, GridPoint?>{start: null};

    while (frontier.isNotEmpty) {
      final current = frontier.removeFirst();
      if (current == level.exit) {
        final path = <GridPoint>[];
        GridPoint? cursor = current;
        while (cursor != null) {
          path.add(cursor);
          cursor = previous[cursor];
        }
        return path.reversed.toList();
      }

      for (final neighbor in current.neighbors) {
        if (!level.roads.contains(neighbor) ||
            occupied.contains(neighbor) ||
            previous.containsKey(neighbor)) {
          continue;
        }
        previous[neighbor] = current;
        frontier.add(neighbor);
      }
    }
    return null;
  }

  static DispatchResult dispatch(
    LevelSpec level,
    BoardState state,
    String busId,
  ) {
    if (state.status != GameStatus.playing) {
      return DispatchResult(
        state: state,
        message: 'This route is finished. Start the next depot.',
        changed: false,
      );
    }
    if (!state.activeBusIds.contains(busId)) {
      return DispatchResult(
        state: state,
        message: 'That bus has already left the depot.',
        changed: false,
      );
    }

    final bus = level.busById(busId);
    final path = routeToExit(level, state, busId);
    if (path == null) {
      return DispatchResult(
        state: state,
        message: 'Another bus is blocking every route to the gate.',
        changed: false,
      );
    }
    if (state.parked.length >= level.bayCount) {
      return DispatchResult(
        state: state,
        message: 'All departure bays are occupied. Undo a bus to make room.',
        changed: false,
      );
    }

    final active = {...state.activeBusIds}..remove(busId);
    final parked = [
      ...state.parked,
      ParkedBus(id: bus.id, route: bus.route, capacity: bus.capacity),
    ];
    var queueIndex = state.queueIndex;

    while (queueIndex < level.passengers.length) {
      final passenger = level.passengers[queueIndex];
      final matchingIndex = parked.indexWhere(
        (waitingBus) =>
            waitingBus.route == passenger &&
            waitingBus.loaded < waitingBus.capacity,
      );
      if (matchingIndex < 0) break;

      final waitingBus = parked[matchingIndex];
      final loadedBus = waitingBus.withLoaded(waitingBus.loaded + 1);
      queueIndex++;
      if (loadedBus.loaded == loadedBus.capacity) {
        parked.removeAt(matchingIndex);
      } else {
        parked[matchingIndex] = loadedBus;
      }
    }

    final won =
        queueIndex == level.passengers.length &&
        active.isEmpty &&
        parked.isEmpty;
    final nextState = state.copyWith(
      activeBusIds: active,
      parked: parked,
      queueIndex: queueIndex,
      moveCount: state.moveCount + 1,
      status: won ? GameStatus.won : GameStatus.playing,
    );
    final message = won
        ? 'Depot clear! Every rider reached the right bus.'
        : path.length > 1
        ? '${bus.route.label} route dispatched through ${path.length - 1} road tiles.'
        : '${bus.route.label} route entered a departure bay.';
    return DispatchResult(state: nextState, message: message, changed: true);
  }

  static String stateKey(BoardState state) {
    final active = state.activeBusIds.toList()..sort();
    final parked = state.parked
        .map((bus) => '${bus.id}:${bus.loaded}')
        .join(',');
    return '${active.join(',')}|$parked|${state.queueIndex}';
  }
}

class LevelSolver {
  static List<String>? findSolution(
    LevelSpec level, {
    BoardState? start,
    int maxStates = 100000,
  }) {
    final initial = start ?? BoardState.initial(level);
    if (initial.status == GameStatus.won) return const [];

    final queue = Queue<_SolverNode>()..add(_SolverNode(initial, const []));
    final visited = <String>{GameRules.stateKey(initial)};
    var examined = 0;

    while (queue.isNotEmpty && examined < maxStates) {
      final node = queue.removeFirst();
      examined++;
      final candidates = node.state.activeBusIds.toList()..sort();
      for (final busId in candidates) {
        if (GameRules.routeToExit(level, node.state, busId) == null ||
            node.state.parked.length >= level.bayCount) {
          continue;
        }
        final result = GameRules.dispatch(level, node.state, busId);
        if (!result.changed) continue;
        final solution = [...node.path, busId];
        if (result.state.status == GameStatus.won) return solution;
        final key = GameRules.stateKey(result.state);
        if (visited.add(key)) {
          queue.add(_SolverNode(result.state, solution));
        }
      }
    }
    return null;
  }
}

class _SolverNode {
  const _SolverNode(this.state, this.path);

  final BoardState state;
  final List<String> path;
}
