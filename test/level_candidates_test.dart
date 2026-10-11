import 'dart:io';

import 'package:busster/game/game_model.dart';
import 'package:busster/game/level_bundle.dart';
import 'package:busster/game/level_candidates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<LevelSpec> levels;

  setUpAll(() async {
    levels = LevelBundleCodec.decode(
      await File('assets/levels/levels.json').readAsString(),
    );
  });

  test(
    'seeded generation is reproducible and returns unrated solvable queues',
    () {
      final first = LevelCandidateGenerator.generate(
        sources: levels,
        seed: 20261011,
        candidatesPerSource: 2,
      );
      final second = LevelCandidateGenerator.generate(
        sources: levels,
        seed: 20261011,
        candidatesPerSource: 2,
      );
      final firstBundle = LevelBundleCodec.encode(
        first.candidates.map((candidate) => candidate.level),
      );
      final secondBundle = LevelBundleCodec.encode(
        second.candidates.map((candidate) => candidate.level),
      );

      expect(firstBundle, secondBundle);
      expect(first.candidates, hasLength(20));
      expect(first.acceptedBySource.values, everyElement(2));
      expect(
        first.candidates.map((candidate) => candidate.level.id).toSet(),
        hasLength(first.candidates.length),
      );
      for (final candidate in first.candidates) {
        final level = candidate.level;
        final sourceId = level.id.substring(0, level.id.indexOf('-candidate-'));
        final source = levels.firstWhere((level) => level.id == sourceId);
        expect(level.passengers, isNot(source.passengers));
        expect(level.difficultyBand, 'unrated');
        expect(level.mechanicTags, contains('queue-order-candidate'));
        expect(candidate.analysis.isComplete, isTrue);
        expect(candidate.analysis.solution, isNotNull);
        for (final route in RouteKind.values) {
          final seats = source.buses
              .where((bus) => bus.route == route)
              .fold<int>(0, (sum, bus) => sum + bus.capacity);
          final riders = level.passengers
              .where((rider) => rider == route)
              .length;
          expect(riders, seats);
        }
      }
    },
  );

  test('rejects invalid generation bounds', () {
    expect(
      () => LevelCandidateGenerator.generate(
        sources: levels,
        seed: 7,
        candidatesPerSource: -1,
      ),
      throwsArgumentError,
    );
    expect(
      () => LevelCandidateGenerator.generate(
        sources: levels,
        seed: 7,
        candidatesPerSource: 1,
        maxStates: 0,
      ),
      throwsArgumentError,
    );
  });
}
