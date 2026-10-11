// Exhaustive solver and difficulty analysis for Bus Jam levels. Pure Dart; the
// top-level functions take a single request object so they can be passed to
// Flutter's `compute` and run off the UI thread.
import 'dart:math';

import 'jam_model.dart';

/// Default expansion budget for [solveJam].
const int defaultJamNodeLimit = 200000;

/// Tri-state solver verdict.
sealed class SolveResult {
  const SolveResult({required this.nodesExpanded});

  /// States expanded before the verdict.
  final int nodesExpanded;
}

/// A winning sequence of taps exists; [path] is one (vehicle ids in order).
final class Solvable extends SolveResult {
  Solvable(List<String> path, {required super.nodesExpanded})
    : path = List.unmodifiable(path);

  final List<String> path;

  @override
  String toString() => 'Solvable($path)';
}

/// The full reachable state space was searched and no win exists.
final class Unsolvable extends SolveResult {
  const Unsolvable({required super.nodesExpanded});

  @override
  String toString() => 'Unsolvable(nodes: $nodesExpanded)';
}

/// The node limit was hit before a verdict.
final class Unknown extends SolveResult {
  const Unknown({required this.nodeLimit, required super.nodesExpanded});

  final int nodeLimit;

  @override
  String toString() => 'Unknown(limit: $nodeLimit)';
}

/// Argument bundle for [solveJamRequest] (for `compute`).
class JamSolveRequest {
  const JamSolveRequest(
    this.level, {
    this.from,
    this.nodeLimit = defaultJamNodeLimit,
  });

  final JamLevel level;
  final JamState? from;
  final int nodeLimit;
}

/// `compute`-friendly entry point: `compute(solveJamRequest, request)`.
SolveResult solveJamRequest(JamSolveRequest request) =>
    solveJam(request.level, from: request.from, nodeLimit: request.nodeLimit);

/// Searches for a winning tap sequence from [from] (default: initial state).
///
/// Every win taps every vehicle exactly once (seats == riders, so every bus
/// must fill and depart), so all solutions have the same length and a DFS
/// is as good as a BFS for the path while being much cheaper.
SolveResult solveJam(
  JamLevel level, {
  JamState? from,
  int nodeLimit = defaultJamNodeLimit,
}) {
  final search = _Search(JamRules(level), nodeLimit);
  return search.solve(from ?? search.rules.initialState());
}

/// Canonical key for duplicate detection.
///
/// Remaining vehicle ids are sorted (set semantics). Bays are keyed per slot,
/// *in slot order*, by `(colour, free seats)`: once parked, a bus's identity
/// and footprint no longer matter, only what it can still absorb.
///
/// Slot order cannot be collapsed to a multiset: boarding goes to the
/// lowest-slot bus of the matching colour, so two same-colour buses with
/// different free seats behave differently when swapped (one may fill and
/// depart while the other would not), and which free slot a new bus takes
/// decides its rank against parked same-colour buses. The passenger index is
/// included for clarity (it is derivable, but cheap).
String jamStateKey(JamLevel level, JamState state) {
  final ids = state.remaining.toList()..sort();
  final buffer = StringBuffer()
    ..write(ids.join(','))
    ..write('|')
    ..write(state.passengerIndex)
    ..write('|');
  for (final bay in state.bays) {
    if (bay == null) {
      buffer.write('-;');
    } else {
      final v = level.vehicle(bay.vehicleId);
      buffer
        ..write(v.color.index)
        ..write(':')
        ..write(v.capacity - bay.loaded)
        ..write(';');
    }
  }
  return buffer.toString();
}

class _LimitHit implements Exception {
  const _LimitHit();
}

class _Search {
  _Search(this.rules, this.nodeLimit);

  final JamRules rules;
  final int nodeLimit;

  /// States fully explored without reaching a win. The move graph is a DAG
  /// (each tap removes a vehicle), so every visited state is dead.
  final Set<String> dead = {};
  int nodes = 0;

  SolveResult solve(JamState start) {
    final path = <String>[];
    try {
      if (_dfs(start, path)) {
        return Solvable(path, nodesExpanded: nodes);
      }
      return Unsolvable(nodesExpanded: nodes);
    } on _LimitHit {
      return Unknown(nodeLimit: nodeLimit, nodesExpanded: nodes);
    }
  }

  bool _dfs(JamState state, List<String> path) {
    if (state.status == JamStatus.won) return true;
    if (state.status == JamStatus.lost) return false;
    final key = jamStateKey(rules.level, state);
    if (dead.contains(key)) return false;
    if (++nodes > nodeLimit) throw const _LimitHit();
    for (final id in rules.legalTaps(state)) {
      final result = rules.tap(state, id);
      path.add(id);
      if (_dfs(result.state, path)) return true;
      path.removeLast();
    }
    dead.add(key);
    return false;
  }
}

/// Difficulty metrics for a level.
class JamAnalysis {
  const JamAnalysis({
    required this.levelId,
    required this.result,
    required this.firstMoves,
    required this.winningFirstMoves,
    required this.losingFirstMoves,
    required this.unknownFirstMoves,
    required this.playouts,
    required this.playoutLosses,
  });

  final String levelId;

  /// Solver verdict from the initial state.
  final SolveResult result;

  /// Legal taps from the initial state.
  final int firstMoves;

  /// First taps from which a win is still reachable.
  final int winningFirstMoves;

  /// First taps after which the level can no longer be won.
  final int losingFirstMoves;

  /// First taps whose sub-search hit the node limit.
  final int unknownFirstMoves;

  /// Uniform random legal playouts performed.
  final int playouts;

  /// Of [playouts], how many ended lost.
  final int playoutLosses;

  bool get solvable => result is Solvable;

  /// Taps in the shortest win. Every win taps each vehicle once, so this is
  /// the vehicle count whenever the level is solvable.
  int? get minMoves => switch (result) {
    Solvable(:final path) => path.length,
    _ => null,
  };

  /// Fraction of random playouts that lose — the difficulty metric.
  double get failRate => playouts == 0 ? 0 : playoutLosses / playouts;

  @override
  String toString() =>
      'JamAnalysis($levelId: solvable=$solvable, minMoves=$minMoves, '
      'firstMoves=$firstMoves win=$winningFirstMoves '
      'lose=$losingFirstMoves unknown=$unknownFirstMoves, '
      'failRate=${failRate.toStringAsFixed(3)} '
      '($playoutLosses/$playouts))';
}

/// Argument bundle for [analyzeJamRequest] (for `compute`).
class JamAnalyzeRequest {
  const JamAnalyzeRequest(
    this.level, {
    this.playouts = 500,
    this.seed = 1,
    this.nodeLimit = defaultJamNodeLimit,
  });

  final JamLevel level;
  final int playouts;
  final int seed;
  final int nodeLimit;
}

/// `compute`-friendly entry point for [analyzeJam].
JamAnalysis analyzeJamRequest(JamAnalyzeRequest request) => analyzeJam(
  request.level,
  playouts: request.playouts,
  seed: request.seed,
  nodeLimit: request.nodeLimit,
);

/// Solves [level], classifies each first move, and measures the fraction of
/// [playouts] uniformly random legal playouts (seeded by [seed]) that lose.
JamAnalysis analyzeJam(
  JamLevel level, {
  int playouts = 500,
  int seed = 1,
  int nodeLimit = defaultJamNodeLimit,
}) {
  final rules = JamRules(level);
  final start = rules.initialState();
  final result = solveJam(level, from: start, nodeLimit: nodeLimit);

  var winning = 0;
  var losing = 0;
  var unknown = 0;
  final firsts = rules.legalTaps(start);
  // Shared dead-state memo across first moves; each gets its own budget.
  final dead = <String>{};
  for (final id in firsts) {
    final search = _Search(rules, nodeLimit)..dead.addAll(dead);
    switch (search.solve(rules.tap(start, id).state)) {
      case Solvable():
        winning++;
      case Unsolvable():
        losing++;
      case Unknown():
        unknown++;
    }
    dead.addAll(search.dead);
  }

  final random = Random(seed);
  var losses = 0;
  for (var i = 0; i < playouts; i++) {
    var state = start;
    while (state.status == JamStatus.playing) {
      final taps = rules.legalTaps(state);
      state = rules.tap(state, taps[random.nextInt(taps.length)]).state;
    }
    if (state.status == JamStatus.lost) losses++;
  }

  return JamAnalysis(
    levelId: level.id,
    result: result,
    firstMoves: firsts.length,
    winningFirstMoves: winning,
    losingFirstMoves: losing,
    unknownFirstMoves: unknown,
    playouts: playouts,
    playoutLosses: losses,
  );
}
