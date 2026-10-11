// Generates levels 4–30 of the Bus Jam pack and writes them into
// assets/levels/jam_levels.json after the hand-authored tutorials.
//
//   dart run tools/generate_jam_levels.dart [--seed N] [--dry-run]
//       [--only 4,9] [--out path]
//
// Output is deterministic for a given master seed. Prints a metrics table.
import 'dart:convert';
import 'dart:io';

import 'package:busster/jam/jam_generator.dart';
import 'package:busster/jam/jam_level_codec.dart';
import 'package:busster/jam/jam_model.dart';
import 'package:busster/jam/jam_solver.dart';

const defaultMasterSeed = 20261011;
const firstGenerated = 4;
const lastGenerated = 30;
const levelsPath = 'assets/levels/jam_levels.json';

/// Breather levels: easier than their neighbours.
const breathers = {9, 14, 19, 24, 28};

/// Levels that drop to four bays for spice.
const fourBayLevels = {11, 17, 22};

/// Difficulty curve for level [n] (4–30).
JamGeneratorSpec specFor(int n) {
  final p = (n - firstGenerated) / (lastGenerated - firstGenerated);
  final width = 5 + (2 * p).round();
  final height = 6 + (3 * p).round();
  final colors = n <= 6
      ? 3
      : n <= 11
      ? 4
      : n <= 18
      ? 5
      : 6;
  var target = 0.3 + 0.55 * p;
  var vehicles = 7 + (13 * p).round();
  if (breathers.contains(n)) {
    // Smaller, gentler, one colour fewer.
    target -= 0.2;
    vehicles -= 3;
  }
  if (fourBayLevels.contains(n)) {
    // A difficulty spike with fewer buses.
    target += 0.05;
    vehicles -= 3;
  }
  return JamGeneratorSpec(
    id: 'level-${n.toString().padLeft(3, '0')}',
    width: width,
    height: height,
    minVehicles: vehicles - 1,
    maxVehicles: vehicles + 2,
    colorCount: breathers.contains(n) && colors > 3 ? colors - 1 : colors,
    bayCount: fourBayLevels.contains(n) ? 4 : 5,
    targetFailRate: target.clamp(0.2, 0.9),
  );
}

void main(List<String> args) {
  var seed = defaultMasterSeed;
  var dryRun = false;
  var out = levelsPath;
  Set<int>? only;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--seed':
        seed = int.parse(args[++i]);
      case '--dry-run':
        dryRun = true;
      case '--out':
        out = args[++i];
      case '--only':
        only = args[++i].split(',').map(int.parse).toSet();
      default:
        stderr.writeln('unknown argument ${args[i]}');
        exit(64);
    }
  }

  final existing = JamLevelCodec.decodeBundle(
    File(levelsPath).readAsStringSync(),
  );
  final tutorials = existing
      .where((l) => l.id.startsWith('tutorial-'))
      .toList();
  if (tutorials.length != firstGenerated - 1) {
    stderr.writeln('expected ${firstGenerated - 1} tutorials first');
    exit(1);
  }

  final total = Stopwatch()..start();
  final generated = <JamLevel>[];
  stdout.writeln(_header);
  for (var n = firstGenerated; n <= lastGenerated; n++) {
    if (only != null && !only.contains(n)) continue;
    final spec = specFor(n);
    final watch = Stopwatch()..start();
    final result = generateJamLevel(spec, seed: seed * 1000 + n);
    final genMs = watch.elapsedMilliseconds;
    watch
      ..reset()
      ..start();
    final solve = solveJam(result.level);
    final solveMs = watch.elapsedMilliseconds;
    if (solve is! Solvable) {
      stderr.writeln('${spec.id}: solver verdict $solve');
      exit(1);
    }
    generated.add(result.level);
    stdout.writeln(
      _row(
        result.level,
        failRate: result.failRate,
        target: spec.targetFailRate,
        nodes: solve.nodesExpanded,
        solveMs: solveMs,
        extra:
            'sq ${result.squeeze.toStringAsFixed(2)}, '
            'attempts ${result.attempts}, ${genMs}ms',
      ),
    );
  }
  stdout.writeln('generated ${generated.length} levels in ${total.elapsed}');

  if (dryRun || only != null) {
    stdout.writeln('dry run: nothing written');
    return;
  }
  File(out).writeAsStringSync(formatBundle([...tutorials, ...generated]));
  stdout.writeln('wrote ${tutorials.length + generated.length} levels to $out');
}

const _header =
    'id           lot   bays veh col occ   pax  free fail  target nodes  solve';

String _row(
  JamLevel level, {
  required double failRate,
  double? target,
  required int nodes,
  required int solveMs,
  String extra = '',
}) {
  final cells = level.vehicles.fold(0, (s, v) => s + v.length);
  final occ = cells / (level.width * level.height);
  final colors = level.vehicles.map((v) => v.color).toSet().length;
  final rules = JamRules(level);
  final free = rules.legalTaps(rules.initialState()).length;
  return [
    level.id.padRight(12),
    '${level.width}x${level.height}'.padRight(5),
    '${level.bayCount}'.padLeft(4),
    '${level.vehicles.length}'.padLeft(3),
    '$colors'.padLeft(3),
    occ.toStringAsFixed(2).padLeft(5),
    '${level.passengers.length}'.padLeft(4),
    '$free'.padLeft(4),
    failRate.toStringAsFixed(3).padLeft(5),
    (target == null ? '-' : target.toStringAsFixed(2)).padLeft(6),
    '$nodes'.padLeft(6),
    '${solveMs}ms'.padLeft(6),
    extra,
  ].join(' ');
}

/// Compact, diff-friendly JSON in the hand-authored style: one vehicle per
/// line, passenger groups four per line.
String formatBundle(List<JamLevel> levels) {
  String enc(Object? v) => jsonEncode(v);
  String obj(Map<String, Object?> m) =>
      '{${m.entries.map((e) => '${enc(e.key)}: ${enc(e.value)}').join(', ')}}';
  String group(List<Object> g) => '[${enc(g[0])}, ${g[1]}]';

  final out = StringBuffer()
    ..writeln('{')
    ..writeln('  "schema": ${JamLevelCodec.schemaVersion},')
    ..writeln('  "levels": [');
  for (var i = 0; i < levels.length; i++) {
    final json = JamLevelCodec.encodeLevel(levels[i]);
    out
      ..writeln('    {')
      ..writeln('      "id": ${enc(json['id'])},')
      ..writeln('      "width": ${json['width']},')
      ..writeln('      "height": ${json['height']},')
      ..writeln('      "bays": ${json['bays']},');
    if (json['hint'] != null) {
      out.writeln('      "hint": ${enc(json['hint'])},');
    }
    final vehicles = (json['vehicles']! as List).cast<Map<String, Object?>>();
    out
      ..writeln('      "vehicles": [')
      ..writeln(vehicles.map((v) => '        ${obj(v)}').join(',\n'))
      ..writeln('      ],');
    final groups = (json['passengers']! as List).cast<List<Object>>();
    if (groups.length <= 4) {
      out.writeln('      "passengers": [${groups.map(group).join(', ')}]');
    } else {
      out
        ..writeln('      "passengers": [')
        ..writeln(
          [
            for (var g = 0; g < groups.length; g += 4)
              '        ${groups.skip(g).take(4).map(group).join(', ')}',
          ].join(',\n'),
        )
        ..writeln('      ]');
    }
    out.writeln(i == levels.length - 1 ? '    }' : '    },');
  }
  out
    ..writeln('  ]')
    ..writeln('}');
  return out.toString();
}
