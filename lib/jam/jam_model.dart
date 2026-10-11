// Bus Jam core rules, v2. Pure Dart: no Flutter imports.
//
// The rules contract lives in docs/REBUILD_PLAN.md ("Rules contract (v2)").
// Summary: tapping a bus whose lane to the lot edge is clear parks it in the
// lowest free bay; then the front passenger repeatedly boards the lowest-slot
// parked bus of their colour; a bus that fills departs immediately and frees
// its slot. The level is won when every passenger has boarded and lost when
// the bays are all full (with no boarding possible) or no bus can be tapped
// while passengers still wait.

/// Passenger and bus colours.
enum JamColor { red, blue, green, yellow, purple, orange }

/// Direction a vehicle's nose points; it leaves the lot this way.
enum JamFacing { up, right, down, left }

/// Overall state of a play-through.
enum JamStatus { playing, won, lost }

/// Why a tap did not move anything.
enum JamBlockReason {
  /// Another vehicle sits between the nose and the lot edge.
  vehicle,

  /// Every bay is occupied.
  fullBays,

  /// The vehicle already left the lot.
  gone,

  /// The game is already won or lost.
  notPlaying,
}

/// Lot grid cell. `(0, 0)` is the top-left corner; y grows downwards.
class JamCell {
  const JamCell(this.x, this.y);

  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      other is JamCell && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x, $y)';
}

/// A bus on the lot.
///
/// [head] is the nose cell; the body extends *backwards* from it, opposite to
/// [facing]. A bus facing up with head `(2, 1)` and length 3 covers
/// `(2, 1)`, `(2, 2)`, `(2, 3)`.
class JamVehicle {
  const JamVehicle({
    required this.id,
    required this.color,
    required this.facing,
    required this.head,
    required this.length,
    int? capacity,
  }) : capacity = capacity ?? (length * 2);

  final String id;
  final JamColor color;
  final JamFacing facing;
  final JamCell head;

  /// Footprint length in cells, 2–4.
  final int length;

  /// Seats. Defaults to `2 × length` (2→4, 3→6, 4→8).
  final int capacity;

  /// Default seats for a vehicle of [length].
  static int defaultCapacity(int length) => length * 2;

  /// Whether [capacity] equals the default for [length].
  bool get hasDefaultCapacity => capacity == defaultCapacity(length);

  /// Footprint cells, nose first.
  List<JamCell> get cells {
    final (dx, dy) = _step(facing);
    return [
      for (var i = 0; i < length; i++)
        JamCell(head.x - dx * i, head.y - dy * i),
    ];
  }

  /// Cells between the nose and the lot edge, in travel order.
  List<JamCell> laneToEdge(int width, int height) {
    final (dx, dy) = _step(facing);
    final lane = <JamCell>[];
    var x = head.x + dx;
    var y = head.y + dy;
    while (x >= 0 && x < width && y >= 0 && y < height) {
      lane.add(JamCell(x, y));
      x += dx;
      y += dy;
    }
    return lane;
  }

  static (int, int) _step(JamFacing facing) => switch (facing) {
    JamFacing.up => (0, -1),
    JamFacing.right => (1, 0),
    JamFacing.down => (0, 1),
    JamFacing.left => (-1, 0),
  };

  @override
  bool operator ==(Object other) =>
      other is JamVehicle &&
      other.id == id &&
      other.color == color &&
      other.facing == facing &&
      other.head == head &&
      other.length == length &&
      other.capacity == capacity;

  @override
  int get hashCode => Object.hash(id, color, facing, head, length, capacity);

  @override
  String toString() =>
      'JamVehicle($id, ${color.name}, ${facing.name}, head $head, '
      'len $length, cap $capacity)';
}

/// Thrown when a level breaks the rules contract.
class JamLevelValidationException implements Exception {
  JamLevelValidationException(this.levelId, List<String> errors)
    : errors = List.unmodifiable(errors);

  final String levelId;
  final List<String> errors;

  String get message => 'Level "$levelId" is invalid: ${errors.join('; ')}';

  @override
  String toString() => 'JamLevelValidationException: $message';
}

/// An authored puzzle. Construction validates and throws
/// [JamLevelValidationException] listing every problem found.
class JamLevel {
  JamLevel({
    required this.id,
    required this.width,
    required this.height,
    required this.bayCount,
    required Iterable<JamVehicle> vehicles,
    required Iterable<JamColor> passengers,
    this.hint,
  }) : vehicles = List.unmodifiable(vehicles),
       passengers = List.unmodifiable(passengers) {
    final errors = validate(
      id: id,
      width: width,
      height: height,
      bayCount: bayCount,
      vehicles: this.vehicles,
      passengers: this.passengers,
    );
    if (errors.isNotEmpty) {
      throw JamLevelValidationException(id, errors);
    }
    _byId = {for (final v in this.vehicles) v.id: v};
  }

  static const int minBays = 1;
  static const int maxBays = 8;
  static const int minLength = 2;
  static const int maxLength = 4;
  static const int maxSide = 16;

  final String id;
  final int width;
  final int height;
  final int bayCount;
  final List<JamVehicle> vehicles;

  /// Passenger queue, front first.
  final List<JamColor> passengers;

  /// Optional tutorial / hint text key for the UI to localise.
  final String? hint;

  late final Map<String, JamVehicle> _byId;

  /// Looks up a vehicle; throws [ArgumentError] for unknown ids.
  JamVehicle vehicle(String id) =>
      _byId[id] ?? (throw ArgumentError.value(id, 'id', 'Unknown vehicle'));

  bool hasVehicle(String id) => _byId.containsKey(id);

  /// Returns every contract violation; empty when valid.
  static List<String> validate({
    required String id,
    required int width,
    required int height,
    required int bayCount,
    required List<JamVehicle> vehicles,
    required List<JamColor> passengers,
  }) {
    final errors = <String>[];
    if (id.trim().isEmpty) errors.add('level id must be non-empty');
    if (width < 1 || width > maxSide || height < 1 || height > maxSide) {
      errors.add(
        'lot size ${width}x$height must be within 1..$maxSide on each side',
      );
    }
    if (bayCount < minBays || bayCount > maxBays) {
      errors.add('bayCount $bayCount must be within $minBays..$maxBays');
    }
    if (vehicles.isEmpty) errors.add('level needs at least one vehicle');
    if (passengers.isEmpty) errors.add('level needs at least one passenger');

    final ids = <String>{};
    final occupied = <JamCell, String>{};
    final seats = <JamColor, int>{};
    for (final v in vehicles) {
      final label = 'vehicle "${v.id}"';
      if (v.id.trim().isEmpty) {
        errors.add('vehicle ids must be non-empty');
      } else if (!ids.add(v.id)) {
        errors.add('duplicate vehicle id "${v.id}"');
      }
      if (v.length < minLength || v.length > maxLength) {
        errors.add('$label length ${v.length} must be $minLength..$maxLength');
        continue;
      }
      if (v.capacity < 1) {
        errors.add('$label capacity ${v.capacity} must be at least 1');
      }
      seats.update(v.color, (s) => s + v.capacity, ifAbsent: () => v.capacity);
      for (final cell in v.cells) {
        if (cell.x < 0 || cell.x >= width || cell.y < 0 || cell.y >= height) {
          errors.add('$label cell $cell is outside the ${width}x$height lot');
          continue;
        }
        final other = occupied[cell];
        if (other != null) {
          errors.add('$label overlaps vehicle "$other" at $cell');
        } else {
          occupied[cell] = v.id;
        }
      }
    }
    final riders = <JamColor, int>{};
    for (final c in passengers) {
      riders.update(c, (r) => r + 1, ifAbsent: () => 1);
    }
    for (final c in JamColor.values) {
      final s = seats[c] ?? 0;
      final r = riders[c] ?? 0;
      if (s != r) {
        errors.add('${c.name}: $s seats but $r riders (must be equal)');
      }
    }
    return errors;
  }

  @override
  String toString() =>
      'JamLevel($id, ${width}x$height, $bayCount bays, '
      '${vehicles.length} vehicles, ${passengers.length} passengers)';
}

/// A bus parked in a bay.
class JamBay {
  const JamBay(this.vehicleId, this.loaded);

  final String vehicleId;

  /// Passengers already on board.
  final int loaded;

  @override
  bool operator ==(Object other) =>
      other is JamBay && other.vehicleId == vehicleId && other.loaded == loaded;

  @override
  int get hashCode => Object.hash(vehicleId, loaded);

  @override
  String toString() => '$vehicleId:$loaded';
}

/// Immutable snapshot of a play-through.
class JamState {
  JamState({
    required Iterable<String> remaining,
    required Iterable<JamBay?> bays,
    required this.passengerIndex,
    required this.moveCount,
    required this.status,
  }) : remaining = Set.unmodifiable(remaining),
       bays = List.unmodifiable(bays);

  /// Initial state for [level] (status already evaluated).
  factory JamState.initial(JamLevel level) => JamRules(level).initialState();

  /// Ids of vehicles still on the lot.
  final Set<String> remaining;

  /// Fixed-length bay slots (`level.bayCount`); `null` = free.
  final List<JamBay?> bays;

  /// Index of the front passenger in `level.passengers`.
  final int passengerIndex;

  /// Successful taps so far.
  final int moveCount;
  final JamStatus status;

  bool get isPlaying => status == JamStatus.playing;
  int get freeBays => bays.where((b) => b == null).length;

  /// Lowest free slot, or `null` when all bays are occupied.
  int? get lowestFreeSlot {
    for (var i = 0; i < bays.length; i++) {
      if (bays[i] == null) return i;
    }
    return null;
  }

  JamState copyWith({
    Iterable<String>? remaining,
    Iterable<JamBay?>? bays,
    int? passengerIndex,
    int? moveCount,
    JamStatus? status,
  }) => JamState(
    remaining: remaining ?? this.remaining,
    bays: bays ?? this.bays,
    passengerIndex: passengerIndex ?? this.passengerIndex,
    moveCount: moveCount ?? this.moveCount,
    status: status ?? this.status,
  );

  @override
  bool operator ==(Object other) {
    if (other is! JamState) return false;
    if (other.passengerIndex != passengerIndex ||
        other.moveCount != moveCount ||
        other.status != status ||
        other.bays.length != bays.length ||
        other.remaining.length != remaining.length) {
      return false;
    }
    for (var i = 0; i < bays.length; i++) {
      if (other.bays[i] != bays[i]) return false;
    }
    return remaining.containsAll(other.remaining);
  }

  @override
  int get hashCode => Object.hash(
    passengerIndex,
    moveCount,
    status,
    Object.hashAll(bays),
    Object.hashAllUnordered(remaining),
  );

  @override
  String toString() {
    final ids = remaining.toList()..sort();
    return 'JamState(${status.name}, remaining $ids, bays $bays, '
        'passenger $passengerIndex, moves $moveCount)';
  }
}

/// Animation-ready event emitted by a successful tap, in order.
sealed class JamEvent {
  const JamEvent();
}

/// [vehicleId] left the lot and parked in bay [slot].
final class JamPark extends JamEvent {
  const JamPark(this.vehicleId, this.slot);

  final String vehicleId;
  final int slot;

  @override
  bool operator ==(Object other) =>
      other is JamPark && other.vehicleId == vehicleId && other.slot == slot;

  @override
  int get hashCode => Object.hash('park', vehicleId, slot);

  @override
  String toString() => 'park($vehicleId, $slot)';
}

/// Passenger [passengerIndex] boarded [vehicleId] in bay [slot].
final class JamBoard extends JamEvent {
  const JamBoard(this.passengerIndex, this.slot, this.vehicleId);

  final int passengerIndex;
  final int slot;
  final String vehicleId;

  @override
  bool operator ==(Object other) =>
      other is JamBoard &&
      other.passengerIndex == passengerIndex &&
      other.slot == slot &&
      other.vehicleId == vehicleId;

  @override
  int get hashCode => Object.hash('board', passengerIndex, slot, vehicleId);

  @override
  String toString() => 'board($passengerIndex, $slot)';
}

/// Full bus [vehicleId] left bay [slot], freeing it.
final class JamDepart extends JamEvent {
  const JamDepart(this.vehicleId, this.slot);

  final String vehicleId;
  final int slot;

  @override
  bool operator ==(Object other) =>
      other is JamDepart && other.vehicleId == vehicleId && other.slot == slot;

  @override
  int get hashCode => Object.hash('depart', vehicleId, slot);

  @override
  String toString() => 'depart($vehicleId, $slot)';
}

/// Why a tap was refused.
class JamBlock {
  const JamBlock(this.reason, {this.blockerId});

  final JamBlockReason reason;

  /// First vehicle in the lane when [reason] is [JamBlockReason.vehicle].
  final String? blockerId;

  @override
  bool operator ==(Object other) =>
      other is JamBlock &&
      other.reason == reason &&
      other.blockerId == blockerId;

  @override
  int get hashCode => Object.hash(reason, blockerId);

  @override
  String toString() =>
      'JamBlock(${reason.name}${blockerId == null ? '' : ', $blockerId'})';
}

/// Outcome of [JamRules.tap].
class JamMoveResult {
  JamMoveResult({
    required this.state,
    required this.vehicleId,
    Iterable<JamEvent> events = const [],
    this.block,
  }) : events = List.unmodifiable(events);

  /// New state, or the unchanged input state when [block] is set.
  final JamState state;
  final String vehicleId;
  final List<JamEvent> events;
  final JamBlock? block;

  bool get moved => block == null;
}

/// Pure rules engine for one level.
class JamRules {
  JamRules(this.level) {
    for (final v in level.vehicles) {
      for (final c in v.cells) {
        _owner[c] = v.id;
      }
      _lanes[v.id] = v.laneToEdge(level.width, level.height);
    }
  }

  final JamLevel level;
  final Map<JamCell, String> _owner = {};
  final Map<String, List<JamCell>> _lanes = {};

  JamState initialState() {
    final remaining = level.vehicles.map((v) => v.id).toSet();
    final bays = List<JamBay?>.filled(level.bayCount, null);
    return JamState(
      remaining: remaining,
      bays: bays,
      passengerIndex: 0,
      moveCount: 0,
      status: _evaluate(remaining, bays, 0),
    );
  }

  /// First remaining vehicle in [vehicleId]'s lane, or `null` when clear.
  String? blockerOf(JamState state, String vehicleId) {
    level.vehicle(vehicleId);
    for (final cell in _lanes[vehicleId]!) {
      final owner = _owner[cell];
      if (owner != null && state.remaining.contains(owner)) return owner;
    }
    return null;
  }

  /// Why tapping [vehicleId] would be refused, or `null` if it would move.
  JamBlock? check(JamState state, String vehicleId) {
    level.vehicle(vehicleId);
    if (state.status != JamStatus.playing) {
      return const JamBlock(JamBlockReason.notPlaying);
    }
    if (!state.remaining.contains(vehicleId)) {
      return const JamBlock(JamBlockReason.gone);
    }
    final blocker = blockerOf(state, vehicleId);
    if (blocker != null) {
      return JamBlock(JamBlockReason.vehicle, blockerId: blocker);
    }
    if (state.lowestFreeSlot == null) {
      return const JamBlock(JamBlockReason.fullBays);
    }
    return null;
  }

  /// Vehicles that a tap would move right now, in level order.
  List<String> legalTaps(JamState state) => [
    for (final v in level.vehicles)
      if (state.remaining.contains(v.id) && check(state, v.id) == null) v.id,
  ];

  /// Applies a tap. Throws [ArgumentError] for an unknown vehicle id.
  JamMoveResult tap(JamState state, String vehicleId) {
    final block = check(state, vehicleId);
    if (block != null) {
      return JamMoveResult(state: state, vehicleId: vehicleId, block: block);
    }
    final events = <JamEvent>[];
    final remaining = state.remaining.toSet()..remove(vehicleId);
    final bays = state.bays.toList();
    final slot = state.lowestFreeSlot!;
    bays[slot] = JamBay(vehicleId, 0);
    events.add(JamPark(vehicleId, slot));

    var index = state.passengerIndex;
    final passengers = level.passengers;
    while (index < passengers.length) {
      final color = passengers[index];
      var target = -1;
      for (var i = 0; i < bays.length; i++) {
        final bay = bays[i];
        if (bay != null && level.vehicle(bay.vehicleId).color == color) {
          target = i;
          break;
        }
      }
      if (target < 0) break;
      final bay = bays[target]!;
      final loaded = bay.loaded + 1;
      events.add(JamBoard(index, target, bay.vehicleId));
      index++;
      if (loaded >= level.vehicle(bay.vehicleId).capacity) {
        bays[target] = null;
        events.add(JamDepart(bay.vehicleId, target));
      } else {
        bays[target] = JamBay(bay.vehicleId, loaded);
      }
    }

    return JamMoveResult(
      state: JamState(
        remaining: remaining,
        bays: bays,
        passengerIndex: index,
        moveCount: state.moveCount + 1,
        status: _evaluate(remaining, bays, index),
      ),
      vehicleId: vehicleId,
      events: events,
    );
  }

  JamStatus _evaluate(Set<String> remaining, List<JamBay?> bays, int index) {
    if (index >= level.passengers.length) return JamStatus.won;
    // Boarding has already been resolved, so the front passenger matches no
    // parked bus. Progress needs a free bay and a bus with a clear lane.
    if (!bays.contains(null)) return JamStatus.lost;
    for (final id in remaining) {
      final clear = _lanes[id]!.every((cell) {
        final owner = _owner[cell];
        return owner == null || !remaining.contains(owner);
      });
      if (clear) return JamStatus.playing;
    }
    return JamStatus.lost;
  }
}

/// Mutable play session with undo and retry.
class JamSession {
  JamSession(this.level) : rules = JamRules(level) {
    initialState = rules.initialState();
    _state = initialState;
  }

  final JamLevel level;
  final JamRules rules;
  late final JamState initialState;
  final List<JamState> _history = [];
  late JamState _state;

  JamState get state => _state;
  bool get canUndo => _history.isNotEmpty;

  /// Applies a tap; on success pushes the previous state for undo.
  JamMoveResult tap(String vehicleId) {
    final result = rules.tap(_state, vehicleId);
    if (result.moved) {
      _history.add(_state);
      _state = result.state;
    }
    return result;
  }

  /// Restores the state before the last successful tap (also after a loss).
  bool undo() {
    if (_history.isEmpty) return false;
    _state = _history.removeLast();
    return true;
  }

  /// Restores the initial state and clears the undo stack.
  void retry() {
    _history.clear();
    _state = initialState;
  }
}
