import 'dart:collection';

import 'game_model.dart';

/// Structural puzzle metrics computed from the reachable state graph.
class LevelAnalysis {
  LevelAnalysis({
    required Iterable<String>? solution,
    required this.reachableStates,
    required this.examinedStates,
    required this.legalBranchingStates,
    required this.maximumLegalMoves,
    required this.unwinnableStates,
    required this.deadEndStates,
    required this.shortestPathChoicePoints,
    required this.isComplete,
  }) : solution = solution == null ? null : List.unmodifiable(solution);

  final List<String>? solution;
  final int reachableStates;
  final int examinedStates;
  final int legalBranchingStates;
  final int maximumLegalMoves;
  final int unwinnableStates;
  final int deadEndStates;
  final int shortestPathChoicePoints;
  final bool isComplete;

  int? get solutionDepth => solution?.length;
}

class LevelAnalyzer {
  static LevelAnalysis analyze(
    LevelSpec level, {
    BoardState? start,
    int maxStates = 100000,
  }) {
    final initial = start ?? BoardState.initial(level);
    if (initial.status == GameStatus.won) {
      return LevelAnalysis(
        solution: const [],
        reachableStates: 1,
        examinedStates: 0,
        legalBranchingStates: 0,
        maximumLegalMoves: 0,
        unwinnableStates: 0,
        deadEndStates: 0,
        shortestPathChoicePoints: 0,
        isComplete: true,
      );
    }

    final nodes = <_AnalysisNode>[
      _AnalysisNode(state: initial, depth: 0, path: const []),
    ];
    final queue = Queue<int>()..add(0);
    final nodeByKey = <String, int>{GameRules.stateKey(initial): 0};
    int? firstSolutionDepth;
    List<String>? solution;
    var examined = 0;

    while (queue.isNotEmpty && examined < maxStates) {
      final nodeIndex = queue.removeFirst();
      final node = nodes[nodeIndex];
      examined++;
      final candidates = node.state.activeBusIds.toList()..sort();
      for (final busId in candidates) {
        if (GameRules.routeToExit(level, node.state, busId) == null ||
            node.state.parked.length >= level.bayCount) {
          continue;
        }
        final result = GameRules.dispatch(level, node.state, busId);
        if (!result.changed) continue;
        node.legalMoves++;

        if (result.state.status == GameStatus.won) {
          node.winningMoves++;
          firstSolutionDepth ??= node.depth + 1;
          solution ??= [...node.path, busId];
          node.distanceToWin = 1;
          continue;
        }

        final key = GameRules.stateKey(result.state);
        var childIndex = nodeByKey[key];
        if (childIndex == null) {
          childIndex = nodes.length;
          nodeByKey[key] = childIndex;
          nodes.add(
            _AnalysisNode(
              state: result.state,
              depth: node.depth + 1,
              path: [...node.path, busId],
            ),
          );
          queue.add(childIndex);
        }
        node.children.add(childIndex);
        nodes[childIndex].parents.add(nodeIndex);
      }
    }

    final reverseQueue = Queue<int>();
    for (var index = 0; index < nodes.length; index++) {
      if (nodes[index].distanceToWin == 1) reverseQueue.add(index);
    }
    while (reverseQueue.isNotEmpty) {
      final childIndex = reverseQueue.removeFirst();
      final child = nodes[childIndex];
      for (final parentIndex in child.parents) {
        final parent = nodes[parentIndex];
        final candidateDistance = child.distanceToWin! + 1;
        if (parent.distanceToWin == null ||
            candidateDistance < parent.distanceToWin!) {
          parent.distanceToWin = candidateDistance;
          reverseQueue.add(parentIndex);
        }
      }
    }

    final shortestDepth = firstSolutionDepth;
    var branchingStates = 0;
    var maximumLegalMoves = 0;
    var unwinnableStates = 0;
    var deadEndStates = 0;
    var shortestPathChoicePoints = 0;
    for (final node in nodes) {
      if (node.legalMoves > 1) branchingStates++;
      if (node.legalMoves > maximumLegalMoves) {
        maximumLegalMoves = node.legalMoves;
      }
      if (node.distanceToWin == null) unwinnableStates++;
      if (node.legalMoves == 0) deadEndStates++;

      final distanceToWin = node.distanceToWin;
      if (shortestDepth == null ||
          distanceToWin == null ||
          node.depth + distanceToWin != shortestDepth) {
        continue;
      }
      var shortestOptions = node.winningMoves;
      for (final childIndex in node.children) {
        final childDistance = nodes[childIndex].distanceToWin;
        if (childDistance == distanceToWin - 1) shortestOptions++;
      }
      if (shortestOptions > 1) shortestPathChoicePoints++;
    }

    return LevelAnalysis(
      solution: solution,
      reachableStates: nodes.length,
      examinedStates: examined,
      legalBranchingStates: branchingStates,
      maximumLegalMoves: maximumLegalMoves,
      unwinnableStates: unwinnableStates,
      deadEndStates: deadEndStates,
      shortestPathChoicePoints: shortestPathChoicePoints,
      isComplete: queue.isEmpty,
    );
  }
}

class _AnalysisNode {
  _AnalysisNode({required this.state, required this.depth, required this.path});

  final BoardState state;
  final int depth;
  final List<String> path;
  final List<int> children = [];
  final List<int> parents = [];
  int legalMoves = 0;
  int winningMoves = 0;
  int? distanceToWin;
}
