// Validates the Bus Jam level pack: schema, rules contract, solvability and
// difficulty metrics. Exits non-zero on any failure (CI-ready).
//
//   dart run tools/validate_jam_levels.dart [path] [--playouts N]
//
// Checks per level: decodes and validates; solveJam (default node limit)
// returns Solvable and the path replays to a win; the solve takes < 2 s;
// lot within 8x10 and bays within 3..7 (generated levels); at least two
// initially tappable buses and failRate > 0 for every non-tutorial level;
// hint solves from sampled mid-game states stay within the node limit.
import 'dart:io';
import 'dart:math';

import 'package:busster/jam/jam_level_codec.dart';
import 'package:busster/jam/jam_model.dart';
import 'package:busster/jam/jam_solver.dart';

const maxWidth = 8;
const maxHeight = 10;
const maxSolveMs = 2000;
const hintSamples = 12;

void main(List<String> args) {
  var path = 'assets/levels/jam_levels.json';
  var playouts = 500;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--playouts') {
      playouts = int.parse(args[++i]);
    } else {
      path = args[i];
    }
  }

  final total = Stopwatch()..start();
  final List<JamLevel> levels;
  try {
    levels = JamLevelCodec.decodeBundle(File(path).readAsStringSync());
  } on Object catch (e) {
    stderr.writeln('FAIL: cannot load $path: $e');
    exit(1);
  }

  final failures = <String>[];
  stdout.writeln(
    'id           lot   bays veh col  pax free minMv fail   '
    'nodes  solve  hintMax',
  );
  for (final level in levels) {
    void fail(String message) => failures.add('${level.id}: $message');
    final tutorial = level.id.startsWith('tutorial-');

    final watch = Stopwatch()..start();
    final result = solveJam(level);
    final solveMs = watch.elapsedMilliseconds;
    if (result is! Solvable) {
      fail('solver verdict $result');
    } else {
      final rules = JamRules(level);
      var state = rules.initialState();
      for (final id in result.path) {
        state = rules.tap(state, id).state;
      }
      if (state.status != JamStatus.won) fail('solution does not replay');
    }
    if (solveMs > maxSolveMs) fail('solve took ${solveMs}ms');

    final analysis = analyzeJam(level, playouts: playouts, seed: 1);
    final rules = JamRules(level);
    final free = rules.legalTaps(rules.initialState()).length;
    final colors = level.vehicles.map((v) => v.color).toSet().length;
    if (level.width > maxWidth || level.height > maxHeight) {
      fail('lot ${level.width}x${level.height} exceeds ${maxWidth}x$maxHeight');
    }
    if (!tutorial) {
      if (level.bayCount < 3 || level.bayCount > 7) {
        fail('bayCount ${level.bayCount} outside 3..7');
      }
      if (free < 2) fail('only $free initially tappable buses');
      if (analysis.failRate <= 0) fail('failRate is 0 (no way to lose)');
    }

    final hint = _hintProbe(level, rules);
    if (hint.unknown > 0) {
      fail('${hint.unknown} sampled hint solves hit the node limit');
    }
    if (hint.maxMs > maxSolveMs) fail('hint solve took ${hint.maxMs}ms');

    stdout.writeln(
      [
        level.id.padRight(12),
        '${level.width}x${level.height}'.padRight(5),
        '${level.bayCount}'.padLeft(4),
        '${level.vehicles.length}'.padLeft(3),
        '$colors'.padLeft(3),
        '${level.passengers.length}'.padLeft(4),
        '$free'.padLeft(4),
        '${analysis.minMoves ?? '-'}'.padLeft(5),
        analysis.failRate.toStringAsFixed(3).padLeft(5),
        '${result.nodesExpanded}'.padLeft(7),
        '${solveMs}ms'.padLeft(6),
        '${hint.maxMs}ms/${hint.maxNodes}n'.padLeft(10),
      ].join(' '),
    );
  }

  final ids = levels.map((l) => l.id).toList();
  if (ids.toSet().length != ids.length) failures.add('duplicate level ids');

  stdout.writeln('validated ${levels.length} levels in ${total.elapsed}');
  if (failures.isNotEmpty) {
    for (final f in failures) {
      stderr.writeln('FAIL: $f');
    }
    exit(1);
  }
  stdout.writeln('OK');
}

/// Solves from mid-game states reached by random play (as in-game hints
/// would) and reports the worst time and node count.
({int maxMs, int maxNodes, int unknown}) _hintProbe(
  JamLevel level,
  JamRules rules,
) {
  final random = Random(7);
  var maxMs = 0;
  var maxNodes = 0;
  var unknown = 0;
  for (var i = 0; i < hintSamples; i++) {
    var state = rules.initialState();
    final depth = random.nextInt(level.vehicles.length);
    for (var d = 0; d < depth && state.isPlaying; d++) {
      final taps = rules.legalTaps(state);
      state = rules.tap(state, taps[random.nextInt(taps.length)]).state;
    }
    if (!state.isPlaying) continue;
    final watch = Stopwatch()..start();
    final result = solveJam(level, from: state);
    maxMs = max(maxMs, watch.elapsedMilliseconds);
    maxNodes = max(maxNodes, result.nodesExpanded);
    if (result is Unknown) unknown++;
  }
  return (maxMs: maxMs, maxNodes: maxNodes, unknown: unknown);
}
