import 'dart:io';

import 'package:busster/game/game_model.dart';
import 'package:busster/game/level_bundle.dart';
import 'package:busster/game/level_variant.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2 || args.length > 4) {
    _usage();
    exitCode = 64;
    return;
  }
  final levelId = args[0];
  final axis = switch (args[1]) {
    'x' => MirrorAxis.x,
    'y' => MirrorAxis.y,
    _ => null,
  };
  if (axis == null ||
      (args.length > 2 && (args.length != 4 || args[2] != '--output'))) {
    _usage();
    exitCode = 64;
    return;
  }

  final source = LevelBundleCodec.decode(
    await File('assets/levels/levels.json').readAsString(),
  );
  final matches = source.where((level) => level.id == levelId);
  if (matches.isEmpty) {
    stderr.writeln('Unknown level ID: $levelId');
    exitCode = 2;
    return;
  }
  final variant = LevelVariant.mirror(matches.first, axis);
  final solution = LevelSolver.findSolution(variant);
  if (solution == null) {
    stderr.writeln('${variant.id} has no solution within the solver limit.');
    exitCode = 1;
    return;
  }

  final outputPath = args.length == 4
      ? args[3]
      : 'build/level-variants/${variant.id}.json';
  final file = File(outputPath);
  await file.parent.create(recursive: true);
  await file.writeAsString(
    '${LevelBundleCodec.encode([variant])}\n',
    flush: true,
  );
  stdout.writeln(
    'Wrote ${variant.id} to ${file.path}; solver path: ${solution.join(' → ')}.',
  );
  stdout.writeln(
    'Review the generated layout and prompt with players before release.',
  );
}

void _usage() {
  stderr.writeln(
    'Usage: dart run tools/level_variants.dart <level-id> <x|y> [--output path.json]',
  );
}
