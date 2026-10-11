import 'dart:io';

import 'package:busster/game/level_bundle.dart';
import 'package:busster/game/level_candidates.dart';

Future<void> main(List<String> args) async {
  final options = _parseArguments(args);
  if (options == null) {
    _usage();
    exitCode = 64;
    return;
  }

  final source = await File('assets/levels/levels.json').readAsString();
  final levels = LevelBundleCodec.decode(source);
  final batch = LevelCandidateGenerator.generate(
    sources: levels,
    seed: options.seed,
    candidatesPerSource: options.candidatesPerLevel,
    maxAttemptsPerSource: options.maxAttemptsPerLevel,
  );
  final output = File(options.outputPath);
  await output.parent.create(recursive: true);
  await output.writeAsString(
    '${LevelBundleCodec.encode(batch.candidates.map((candidate) => candidate.level))}\n',
    flush: true,
  );

  stdout.writeln(
    'Wrote ${batch.candidates.length} solver-checked candidates to ${output.path}.',
  );
  for (final candidate in batch.candidates) {
    final analysis = candidate.analysis;
    stdout.writeln(
      'PASS ${candidate.level.id}: ${analysis.solutionDepth} moves, '
      '${analysis.reachableStates} states, '
      '${analysis.shortestPathChoicePoints} shortest-path choice points',
    );
  }
  stdout.writeln(
    'Attempts: ${batch.attemptedQueues}; duplicate queues: '
    '${batch.duplicateQueues}; unsolved: ${batch.unsolvedQueues}; '
    'analysis limit reached: ${batch.truncatedQueues}.',
  );

  final shortfalls = batch.acceptedBySource.entries
      .where((entry) => entry.value < options.candidatesPerLevel)
      .toList();
  if (shortfalls.isNotEmpty) {
    stderr.writeln(
      'Could not reach ${options.candidatesPerLevel} candidates for: '
      '${shortfalls.map((entry) => '${entry.key} (${entry.value})').join(', ')}.',
    );
    exitCode = 1;
  }
  stdout.writeln(
    'These are unrated candidates. Review each layout and teaching prompt '
    'with players before copying it into assets/levels/levels.json.',
  );
}

_CandidateOptions? _parseArguments(List<String> args) {
  var seed = 20261011;
  var candidatesPerLevel = 2;
  var maxAttemptsPerLevel = 500;
  String? outputPath;

  for (var index = 0; index < args.length; index++) {
    if (index + 1 >= args.length) return null;
    final value = args[++index];
    switch (args[index - 1]) {
      case '--seed':
        final parsed = int.tryParse(value);
        if (parsed == null) return null;
        seed = parsed;
      case '--per-level':
        final parsed = int.tryParse(value);
        if (parsed == null || parsed < 1) return null;
        candidatesPerLevel = parsed;
      case '--attempts-per-level':
        final parsed = int.tryParse(value);
        if (parsed == null || parsed < 1) return null;
        maxAttemptsPerLevel = parsed;
      case '--output':
        if (value.trim().isEmpty) return null;
        outputPath = value;
      default:
        return null;
    }
  }

  return _CandidateOptions(
    seed: seed,
    candidatesPerLevel: candidatesPerLevel,
    maxAttemptsPerLevel: maxAttemptsPerLevel,
    outputPath:
        outputPath ?? 'build/level-candidates/candidates-seed-$seed.json',
  );
}

void _usage() {
  stderr.writeln(
    'Usage: dart run tools/generate_level_candidates.dart '
    '[--seed integer] [--per-level count] [--attempts-per-level count] '
    '[--output path.json]',
  );
}

class _CandidateOptions {
  const _CandidateOptions({
    required this.seed,
    required this.candidatesPerLevel,
    required this.maxAttemptsPerLevel,
    required this.outputPath,
  });

  final int seed;
  final int candidatesPerLevel;
  final int maxAttemptsPerLevel;
  final String outputPath;
}
