import 'dart:io';

import 'package:busster/game/game_model.dart';
import 'package:busster/game/level_bundle.dart';
import 'package:busster/game/level_variant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<LevelSpec> levels;

  setUpAll(() async {
    levels = LevelBundleCodec.decode(
      await File('assets/levels/levels.json').readAsString(),
    );
  });

  test('horizontal mirror preserves the puzzle and remains solver-valid', () {
    final original = levels.first;
    final variant = LevelVariant.mirror(original, MirrorAxis.x);

    expect(variant.id, 'depot-01-mirror-x');
    expect(variant.roads, hasLength(original.roads.length));
    expect(
      variant.exit,
      GridPoint(original.width - 1 - original.exit.x, original.exit.y),
    );
    expect(
      variant.buses.map((bus) => bus.route).toList(),
      original.buses.map((bus) => bus.route).toList(),
    );
    expect(LevelSolver.findSolution(variant), isNotNull);
  });
}
