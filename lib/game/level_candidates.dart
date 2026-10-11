import 'level_analysis.dart';
import 'game_model.dart';

class LevelCandidate {
  const LevelCandidate({required this.level, required this.analysis});

  final LevelSpec level;
  final LevelAnalysis analysis;
}

class LevelCandidateBatch {
  LevelCandidateBatch({
    required Iterable<LevelCandidate> candidates,
    required this.attemptedQueues,
    required this.duplicateQueues,
    required this.unsolvedQueues,
    required this.truncatedQueues,
    required Map<String, int> acceptedBySource,
  }) : candidates = List.unmodifiable(candidates),
       acceptedBySource = Map.unmodifiable(acceptedBySource);

  final List<LevelCandidate> candidates;
  final int attemptedQueues;
  final int duplicateQueues;
  final int unsolvedQueues;
  final int truncatedQueues;
  final Map<String, int> acceptedBySource;
}

/// Creates separate, reproducible queue-order candidates from authored levels.
/// Candidates stay unrated and must be human-reviewed before shipping.
class LevelCandidateGenerator {
  static LevelCandidateBatch generate({
    required Iterable<LevelSpec> sources,
    required int seed,
    required int candidatesPerSource,
    int maxAttemptsPerSource = 500,
    int maxStates = 100000,
  }) {
    if (candidatesPerSource < 0) {
      throw ArgumentError.value(candidatesPerSource, 'candidatesPerSource');
    }
    if (maxAttemptsPerSource < 0) {
      throw ArgumentError.value(maxAttemptsPerSource, 'maxAttemptsPerSource');
    }
    if (maxStates < 1) throw ArgumentError.value(maxStates, 'maxStates');

    final sourceList = sources.toList(growable: false);
    final sourceIds = sourceList.map((level) => level.id).toSet();
    if (sourceIds.length != sourceList.length) {
      throw ArgumentError('Source level IDs must be unique.');
    }

    final random = _SeededShuffle(seed);
    final candidates = <LevelCandidate>[];
    final acceptedBySource = <String, int>{};
    var attemptedQueues = 0;
    var duplicateQueues = 0;
    var unsolvedQueues = 0;
    var truncatedQueues = 0;

    for (final source in sourceList) {
      final acceptedQueues = <String>{_queueKey(source.passengers)};
      var acceptedForSource = 0;
      for (
        var attempt = 0;
        attempt < maxAttemptsPerSource &&
            acceptedForSource < candidatesPerSource;
        attempt++
      ) {
        attemptedQueues++;
        final queue = _shuffle(source.passengers, random);
        final queueKey = _queueKey(queue);
        if (!acceptedQueues.add(queueKey)) {
          duplicateQueues++;
          continue;
        }

        final candidateNumber = acceptedForSource + 1;
        final candidate = LevelSpec(
          id: '${source.id}-candidate-${candidateNumber.toString().padLeft(2, '0')}',
          title: '${source.title} (queue candidate $candidateNumber)',
          width: source.width,
          height: source.height,
          exit: source.exit,
          roads: source.roads,
          buses: source.buses,
          passengers: queue,
          tutorialPrompt: source.tutorialPrompt,
          bayCount: source.bayCount,
          mechanicTags: [...source.mechanicTags, 'queue-order-candidate'],
          difficultyBand: 'unrated',
          seed: seed,
        );
        final analysis = LevelAnalyzer.analyze(candidate, maxStates: maxStates);
        if (!analysis.isComplete) {
          truncatedQueues++;
          continue;
        }
        if (analysis.solution == null) {
          unsolvedQueues++;
          continue;
        }
        candidates.add(LevelCandidate(level: candidate, analysis: analysis));
        acceptedForSource++;
      }
      acceptedBySource[source.id] = acceptedForSource;
    }

    return LevelCandidateBatch(
      candidates: candidates,
      attemptedQueues: attemptedQueues,
      duplicateQueues: duplicateQueues,
      unsolvedQueues: unsolvedQueues,
      truncatedQueues: truncatedQueues,
      acceptedBySource: acceptedBySource,
    );
  }

  static List<RouteKind> _shuffle(
    List<RouteKind> source,
    _SeededShuffle random,
  ) {
    final result = source.toList();
    for (var index = result.length - 1; index > 0; index--) {
      final other = random.nextInt(index + 1);
      final value = result[index];
      result[index] = result[other];
      result[other] = value;
    }
    return result;
  }

  static String _queueKey(Iterable<RouteKind> queue) =>
      queue.map((route) => route.name).join(',');
}

/// Small specified PRNG so generated queues do not depend on `Random`'s
/// implementation changing with a Dart SDK update.
class _SeededShuffle {
  _SeededShuffle(int seed) : _state = seed & 0xffffffff {
    if (_state == 0) _state = 0x6d2b79f5;
  }

  int _state;

  int nextInt(int max) {
    _state ^= (_state << 13) & 0xffffffff;
    _state ^= _state >> 17;
    _state ^= (_state << 5) & 0xffffffff;
    _state &= 0xffffffff;
    return _state % max;
  }
}
