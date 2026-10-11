// Procedural Bus Jam level generator. Pure Dart, deterministic from a seed.
//
// Algorithm (one attempt):
//  1. Pack: randomly tile the lot with straight vehicles (length 2–4, both
//     orientations) up to a target occupancy.
//  2. Peel: repeatedly pick a remaining vehicle that has a clear lane to the
//     lot edge (ignoring vehicles already peeled) in one of its two axis
//     directions, fix its facing that way and peel it. Vehicles caught in a
//     blocking cycle are deleted. Every vehicle's lane then only contains
//     vehicles peeled *before* it, so the blocking graph is acyclic and the
//     lot is always clearable.
//  3. Plan: pick a random topological clearing order of the blocking graph
//     and colour it from balanced per-colour quotas (gentle attempts keep
//     runs of one colour together). Vehicles are listed in plan order, so
//     the solver's DFS finds the planned line first and hints stay instant.
//  4. Queue: simulate the planned order with the exact bay rules and emit the
//     passenger queue in small colour groups. At each step the queue either
//     feeds a parked bus (its passengers board at once) or introduces a
//     "stopper" colour whose bus is further down the plan, which forces the
//     player to park the buses before it first. A `squeeze` knob in [-1, 1]
//     controls how often and how far ahead stoppers reach (how close to full
//     the planned run keeps the bays) and how often a bus gets its whole load
//     in one group. The planned order wins by construction; random play that
//     parks the wrong buses runs out of bays.
//  5. Measure: uniform random playouts (identical to [analyzeJam]) give the
//     fail rate; [solveJam] confirms the level within the node limit.
//
// [generateJamLevel] retries attempts (seeded from the master seed) and keeps
// the one closest to the target fail rate.
import 'dart:math';

import 'jam_model.dart';
import 'jam_solver.dart';

/// Colour introduction order: the first `colorCount` are used.
const List<JamColor> jamColorOrder = [
  JamColor.red,
  JamColor.blue,
  JamColor.green,
  JamColor.yellow,
  JamColor.purple,
  JamColor.orange,
];

/// What to generate.
class JamGeneratorSpec {
  const JamGeneratorSpec({
    required this.id,
    required this.width,
    required this.height,
    required this.minVehicles,
    required this.maxVehicles,
    required this.colorCount,
    required this.bayCount,
    this.targetFailRate = 0.5,
    this.failTolerance = 0.05,
    this.minOccupancy = 0.65,
    this.maxOccupancy = 0.85,
    this.minInitialTaps = 2,
    this.requireLoss = true,
    this.playouts = 500,
    this.playoutSeed = 1,
    this.maxAttempts = 300,
    this.nodeLimit = defaultJamNodeLimit,
    this.hint,
  }) : assert(colorCount >= 1 && colorCount <= 6),
       assert(minVehicles <= maxVehicles);

  final String id;
  final int width;
  final int height;
  final int minVehicles;
  final int maxVehicles;
  final int colorCount;
  final int bayCount;

  /// Desired fraction of random playouts that lose.
  final double targetFailRate;

  /// Stop searching once an attempt lands this close to [targetFailRate].
  final double failTolerance;

  /// Occupied cells / lot cells.
  final double minOccupancy;
  final double maxOccupancy;

  /// Buses tappable in the initial state.
  final int minInitialTaps;

  /// Require at least one losing playout (there is a way to lose).
  final bool requireLoss;

  /// Random playouts used to measure the fail rate (same scheme and seed as
  /// [analyzeJam], so the numbers match).
  final int playouts;
  final int playoutSeed;

  final int maxAttempts;
  final int nodeLimit;
  final String? hint;
}

/// A generated level plus the metrics gathered while generating it.
class JamGeneratedLevel {
  const JamGeneratedLevel({
    required this.level,
    required this.plannedOrder,
    required this.failRate,
    required this.squeeze,
    required this.attempts,
    required this.solveNodes,
  });

  final JamLevel level;

  /// The clearing order the queue was built around (a known solution).
  final List<String> plannedOrder;

  /// Fraction of [JamGeneratorSpec.playouts] random playouts that lost.
  final double failRate;
  final double squeeze;

  /// Attempts consumed (valid or not).
  final int attempts;

  /// Nodes [solveJam] expanded to verify the level.
  final int solveNodes;

  int get occupiedCells => level.vehicles.fold(0, (s, v) => s + v.length);
  double get occupancy => occupiedCells / (level.width * level.height);
  int get colorCount => level.vehicles.map((v) => v.color).toSet().length;
}

/// Thrown when no attempt produced a valid level.
class JamGenerationException implements Exception {
  const JamGenerationException(this.message);
  final String message;
  @override
  String toString() => 'JamGenerationException: $message';
}

/// Generates a level for [spec], deterministically from [seed].
JamGeneratedLevel generateJamLevel(JamGeneratorSpec spec, {required int seed}) {
  final master = Random(seed);
  JamGeneratedLevel? best;
  var attempts = 0;
  final rejected = <String, int>{};
  while (attempts < spec.maxAttempts) {
    attempts++;
    final attemptSeed = master.nextInt(1 << 31);
    // Squeeze in [-1, 1]: negative = gentle queue, positive = tight bays.
    final squeeze = master.nextDouble() * 2 - 1;
    final candidate = _attempt(spec, Random(attemptSeed), squeeze);
    if (candidate == null) {
      rejected.update('layout', (n) => n + 1, ifAbsent: () => 1);
      continue;
    }
    final (level, plan) = candidate;
    final fail = jamPlayoutFailRate(
      level,
      playouts: spec.playouts,
      seed: spec.playoutSeed,
    );
    if (spec.requireLoss && fail == 0) {
      rejected.update('no-loss', (n) => n + 1, ifAbsent: () => 1);
      continue;
    }
    final error = (fail - spec.targetFailRate).abs();
    if (best != null && error >= (best.failRate - spec.targetFailRate).abs()) {
      continue;
    }
    final solved = solveJam(level, nodeLimit: spec.nodeLimit);
    if (solved is! Solvable) {
      rejected.update('solver', (n) => n + 1, ifAbsent: () => 1);
      continue;
    }
    best = JamGeneratedLevel(
      level: level,
      plannedOrder: plan,
      failRate: fail,
      squeeze: squeeze,
      attempts: attempts,
      solveNodes: solved.nodesExpanded,
    );
    if (error <= spec.failTolerance) break;
  }
  if (best == null) {
    throw JamGenerationException(
      'no valid level for "${spec.id}" in $attempts attempts '
      '(rejected: $rejected)',
    );
  }
  return JamGeneratedLevel(
    level: best.level,
    plannedOrder: best.plannedOrder,
    failRate: best.failRate,
    squeeze: best.squeeze,
    attempts: attempts,
    solveNodes: best.solveNodes,
  );
}

/// Fraction of [playouts] uniformly random legal playouts that lose; the same
/// procedure (and random stream) as [analyzeJam]'s fail rate.
double jamPlayoutFailRate(JamLevel level, {int playouts = 500, int seed = 1}) {
  if (playouts <= 0) return 0;
  final rules = JamRules(level);
  final start = rules.initialState();
  final random = Random(seed);
  var losses = 0;
  for (var i = 0; i < playouts; i++) {
    var state = start;
    while (state.status == JamStatus.playing) {
      final taps = rules.legalTaps(state);
      state = rules.tap(state, taps[random.nextInt(taps.length)]).state;
    }
    if (state.status == JamStatus.lost) losses++;
  }
  return losses / playouts;
}

// --- one attempt -----------------------------------------------------------

class _Car {
  _Car(this.x, this.y, this.length, this.horizontal);

  /// Top-left footprint cell.
  final int x;
  final int y;
  final int length;
  final bool horizontal;
  late JamFacing facing;
  late JamColor color;
  String id = '';

  Iterable<(int, int)> get cells sync* {
    for (var i = 0; i < length; i++) {
      yield horizontal ? (x + i, y) : (x, y + i);
    }
  }

  JamCell headFor(JamFacing f) => switch (f) {
    JamFacing.up => JamCell(x, y),
    JamFacing.left => JamCell(x, y),
    JamFacing.down => JamCell(x, y + length - 1),
    JamFacing.right => JamCell(x + length - 1, y),
  };

  List<JamFacing> get axisFacings => horizontal
      ? const [JamFacing.left, JamFacing.right]
      : const [JamFacing.up, JamFacing.down];

  JamVehicle toVehicle() => JamVehicle(
    id: id,
    color: color,
    facing: facing,
    head: headFor(facing),
    length: length,
  );
}

List<(int, int)> _lane(_Car car, JamFacing f, int width, int height) {
  final head = car.headFor(f);
  final (dx, dy) = switch (f) {
    JamFacing.up => (0, -1),
    JamFacing.right => (1, 0),
    JamFacing.down => (0, 1),
    JamFacing.left => (-1, 0),
  };
  final out = <(int, int)>[];
  var x = head.x + dx;
  var y = head.y + dy;
  while (x >= 0 && x < width && y >= 0 && y < height) {
    out.add((x, y));
    x += dx;
    y += dy;
  }
  return out;
}

(JamLevel, List<String>)? _attempt(
  JamGeneratorSpec spec,
  Random rng,
  double squeeze,
) {
  final w = spec.width;
  final h = spec.height;
  final area = w * h;
  final targetVehicles =
      spec.minVehicles + rng.nextInt(spec.maxVehicles - spec.minVehicles + 1);
  final targetOccupancy =
      spec.minOccupancy +
      (spec.maxOccupancy - spec.minOccupancy) *
          (0.35 + 0.65 * rng.nextDouble());
  final targetCells = (area * targetOccupancy).round();
  final avgLength = (targetCells / targetVehicles).clamp(2.0, 4.0);

  // 1. Pack.
  final t = (avgLength - 2) / 2;
  final weights = [pow(1 - t, 1.5) + 0.05, 0.5, pow(t, 1.5) + 0.05];
  final weightSum = weights.fold<double>(0, (s, x) => s + x);
  int sampleLength() {
    var r = rng.nextDouble() * weightSum;
    for (var i = 0; i < 3; i++) {
      r -= weights[i];
      if (r < 0) return i + 2;
    }
    return 4;
  }

  final owner = List<_Car?>.filled(area, null);
  final cars = <_Car>[];
  var filled = 0;
  final order = List.generate(area, (i) => i)..shuffle(rng);
  // Overfill slightly: peeling may delete some vehicles.
  final packCells = targetCells + 2;
  for (final cell in order) {
    if (filled >= packCells) break;
    if (owner[cell] != null) continue;
    final cx = cell % w;
    final cy = cell ~/ w;
    final first = sampleLength();
    final firstHorizontal = rng.nextBool();
    _Car? placed;
    outer:
    for (final length in [first, for (var l = 4; l >= 2; l--) l]) {
      for (final horizontal in [firstHorizontal, !firstHorizontal]) {
        final offsets = List.generate(length, (i) => i)..shuffle(rng);
        for (final off in offsets) {
          final car = horizontal
              ? _Car(cx - off, cy, length, true)
              : _Car(cx, cy - off, length, false);
          final fits = car.cells.every(
            (c) =>
                c.$1 >= 0 &&
                c.$1 < w &&
                c.$2 >= 0 &&
                c.$2 < h &&
                owner[c.$2 * w + c.$1] == null,
          );
          if (fits) {
            placed = car;
            break outer;
          }
        }
      }
    }
    if (placed == null) continue;
    for (final c in placed.cells) {
      owner[c.$2 * w + c.$1] = placed;
    }
    filled += placed.length;
    cars.add(placed);
  }

  // 2. Peel.
  final remaining = cars.toSet();
  final peeled = <_Car>[];
  bool laneClear(_Car car, JamFacing f) => _lane(car, f, w, h).every((c) {
    final o = owner[c.$2 * w + c.$1];
    return o == null || !remaining.contains(o);
  });
  int laneLoad(_Car car, JamFacing f) => _lane(
    car,
    f,
    w,
    h,
  ).map((c) => owner[c.$2 * w + c.$1]).whereType<_Car>().toSet().length;
  while (remaining.isNotEmpty) {
    final candidates = <(_Car, List<JamFacing>)>[];
    for (final car in cars) {
      if (!remaining.contains(car)) continue;
      final ok = car.axisFacings.where((f) => laneClear(car, f)).toList();
      if (ok.isNotEmpty) candidates.add((car, ok));
    }
    if (candidates.isEmpty) {
      // Blocking cycle: delete a random remaining vehicle.
      final list = cars.where(remaining.contains).toList();
      final victim = list[rng.nextInt(list.length)];
      remaining.remove(victim);
      for (final c in victim.cells) {
        owner[c.$2 * w + c.$1] = null;
      }
      continue;
    }
    final (car, facings) = candidates[rng.nextInt(candidates.length)];
    if (facings.length == 2 && rng.nextDouble() < 0.7) {
      // Prefer the lane through more (earlier-peeled) vehicles: deeper jams.
      final a = laneLoad(car, facings[0]);
      final b = laneLoad(car, facings[1]);
      car.facing = a == b
          ? facings[rng.nextInt(2)]
          : (a > b ? facings[0] : facings[1]);
    } else {
      car.facing = facings[rng.nextInt(facings.length)];
    }
    remaining.remove(car);
    peeled.add(car);
  }

  final n = peeled.length;
  final occupied = peeled.fold(0, (s, c) => s + c.length);
  final occupancy = occupied / area;
  if (n < spec.minVehicles || n > spec.maxVehicles) return null;
  if (occupancy < spec.minOccupancy || occupancy > spec.maxOccupancy) {
    return null;
  }
  if (n < spec.colorCount) return null;

  // Blockers of each car (vehicles in its lane).
  final blockers = {
    for (final car in peeled)
      car: _lane(
        car,
        car.facing,
        w,
        h,
      ).map((c) => owner[c.$2 * w + c.$1]).whereType<_Car>().toSet(),
  };
  final initiallyFree = peeled.where((c) => blockers[c]!.isEmpty).length;
  if (initiallyFree < spec.minInitialTaps) return null;

  // 3. Plan: random topological order.
  final plan = <_Car>[];
  final gone = <_Car>{};
  while (plan.length < n) {
    final ready = [
      for (final car in peeled)
        if (!gone.contains(car) && blockers[car]!.every(gone.contains)) car,
    ];
    final pick = ready[rng.nextInt(ready.length)];
    gone.add(pick);
    plan.add(pick);
  }

  // Colours: balanced quotas, every colour used at least once. Gentle
  // (negative squeeze) levels keep runs of one colour together in the plan,
  // so buses that free up together tend to share a colour.
  final colors = jamColorOrder.take(spec.colorCount).toList();
  final quota = {
    for (var i = 0; i < colors.length; i++)
      colors[i]: n ~/ colors.length + (i < n % colors.length ? 1 : 0),
  };
  final coherence = (-0.8 * squeeze).clamp(0.0, 0.85);
  JamColor? current;
  for (final car in plan) {
    if (current == null ||
        quota[current] == 0 ||
        rng.nextDouble() >= coherence) {
      final open = colors.where((c) => quota[c]! > 0 && c != current).toList();
      current = open.isEmpty ? current : open[rng.nextInt(open.length)];
    }
    car.color = current!;
    quota[current] = quota[current]! - 1;
  }
  // Ids in plan order: the solver's DFS tries vehicles in list order, so
  // listing them this way makes the first solve (and most hints) instant.
  final counters = <JamColor, int>{};
  for (final car in plan) {
    final k = counters.update(car.color, (v) => v + 1, ifAbsent: () => 1);
    car.id = '${car.color.name[0]}$k';
  }

  // 4. Queue.
  final queue = _buildQueue(plan, spec.bayCount, squeeze, rng);
  final level = JamLevel(
    id: spec.id,
    width: w,
    height: h,
    bayCount: spec.bayCount,
    vehicles: [for (final car in plan) car.toVehicle()],
    passengers: queue,
    hint: spec.hint,
  );
  final planIds = [for (final car in plan) car.id];

  // Sanity: the planned order wins under the real rules.
  final rules = JamRules(level);
  var state = rules.initialState();
  for (final id in planIds) {
    final result = rules.tap(state, id);
    if (!result.moved) return null;
    state = result.state;
  }
  if (state.status != JamStatus.won) return null;
  return (level, planIds);
}

class _Open {
  _Open(this.color, this.free);
  final JamColor color;
  int free;
}

List<JamColor> _buildQueue(
  List<_Car> plan,
  int bays,
  double squeeze,
  Random rng,
) {
  final slots = List<_Open?>.filled(bays, null);
  final queue = <JamColor>[];
  var next = 0;

  bool boardable(JamColor c) => slots.any((s) => s != null && s.color == c);
  int freeSeats(JamColor c) =>
      slots.fold(0, (sum, s) => s != null && s.color == c ? sum + s.free : sum);

  void park(_Car car) {
    final slot = slots.indexOf(null);
    slots[slot] = _Open(car.color, car.length * 2);
  }

  void emit(JamColor c) {
    final total = freeSeats(c);
    var size = 2 + rng.nextInt(3); // 2..4
    final roll = rng.nextDouble();
    if (roll < 0.1) {
      size = 1;
    } else if (roll < 0.2 - 0.3 * squeeze) {
      // Easy queues hand a bus its whole load at once.
      size = total;
    }
    size = min(size, total);
    for (var i = 0; i < size; i++) {
      final slot = slots.indexWhere((s) => s != null && s.color == c);
      queue.add(c);
      final open = slots[slot]!;
      open.free--;
      if (open.free == 0) slots[slot] = null;
    }
  }

  while (next < plan.length || slots.any((s) => s != null)) {
    final openCount = slots.where((s) => s != null).length;
    // Stopper candidates: (colour, index of its first bus in the plan).
    final stoppers = <(JamColor, int)>[];
    final seen = <JamColor>{};
    for (var j = next; j < plan.length; j++) {
      if (openCount + (j - next + 1) > bays) break;
      final c = plan[j].color;
      if (!seen.add(c) || boardable(c)) continue;
      stoppers.add((c, j));
    }
    final feeds = {
      for (final s in slots)
        if (s != null) s.color,
    }.toList()..sort((a, b) => a.index - b.index);

    final useStopper =
        feeds.isEmpty ||
        (stoppers.isNotEmpty && rng.nextDouble() < 0.3 + 0.4 * squeeze);
    if (useStopper) {
      // Weight far stoppers up as squeeze grows.
      final exponent = 3 * squeeze;
      final weights = [
        for (final (_, j) in stoppers) pow(j - next + 1, exponent).toDouble(),
      ];
      var r = rng.nextDouble() * weights.fold<double>(0, (s, x) => s + x);
      var pick = stoppers.last;
      for (var i = 0; i < stoppers.length; i++) {
        r -= weights[i];
        if (r < 0) {
          pick = stoppers[i];
          break;
        }
      }
      final (c, j) = pick;
      for (var k = next; k <= j; k++) {
        park(plan[k]);
      }
      next = j + 1;
      emit(c);
    } else {
      emit(feeds[rng.nextInt(feeds.length)]);
    }
  }
  return queue;
}
