import 'dart:io';

import 'package:busster/game/game_model.dart';
import 'package:busster/game/level_analysis.dart';
import 'package:busster/game/level_bundle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<LevelSpec> levels;

  setUpAll(() async {
    levels = LevelBundleCodec.decode(
      await File('assets/levels/levels.json').readAsString(),
    );
  });

  test(
    'analyzes every authored level completely and finds a shortest path',
    () {
      for (final level in levels) {
        final analysis = LevelAnalyzer.analyze(level);
        final solution = LevelSolver.findSolution(level);

        expect(analysis.isComplete, isTrue, reason: level.id);
        expect(analysis.solution, isNotNull, reason: level.id);
        expect(analysis.solutionDepth, solution?.length, reason: level.id);
        expect(analysis.reachableStates, greaterThan(0), reason: level.id);
        expect(
          analysis.deadEndStates,
          lessThanOrEqualTo(analysis.unwinnableStates),
          reason: level.id,
        );
      }
    },
  );

  test('reports when the configured state limit truncates analysis', () {
    final analysis = LevelAnalyzer.analyze(levels.first, maxStates: 1);

    expect(analysis.isComplete, isFalse);
    expect(analysis.reachableStates, greaterThan(1));
  });
}
