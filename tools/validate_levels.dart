import 'dart:io';

import 'package:busster/game/game_model.dart';
import 'package:busster/game/level_bundle.dart';

Future<void> main() async {
  final source = await File('assets/levels/levels.json').readAsString();
  final levels = LevelBundleCodec.decode(source);
  var failures = 0;

  for (final level in levels) {
    final problems = <String>[];

    if (level.tutorialPrompt.trim().isEmpty) {
      problems.add('missing first-pass tutorial prompt');
    }
    if (level.difficultyBand == 'unrated') {
      problems.add('missing provisional difficulty band');
    }
    if (level.mechanicTags.isEmpty) {
      problems.add('missing mechanic tags');
    }

    for (final road in level.roads) {
      if (road.x < 0 ||
          road.y < 0 ||
          road.x >= level.width ||
          road.y >= level.height) {
        problems.add(
          'road $road is outside the ${level.width}x${level.height} board',
        );
      }
    }

    for (final route in RouteKind.values) {
      final seats = level.buses
          .where((bus) => bus.route == route)
          .fold<int>(0, (sum, bus) => sum + bus.capacity);
      final riders = level.passengers.where((rider) => rider == route).length;
      if (seats != riders) {
        problems.add('${route.label}: $seats seats for $riders riders');
      }
    }

    final solution = LevelSolver.findSolution(level);
    if (solution == null) {
      problems.add('no complete solution found');
    }

    if (problems.isEmpty) {
      stdout.writeln(
        'PASS ${level.id}: ${level.buses.length} buses, '
        '${level.passengers.length} riders, ${solution!.length} dispatches',
      );
    } else {
      failures++;
      stderr.writeln('FAIL ${level.id}: ${problems.join('; ')}');
    }
  }

  stdout.writeln('${levels.length - failures}/${levels.length} levels valid');
  if (failures > 0) exitCode = 1;
}
