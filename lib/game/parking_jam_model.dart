// Provisional, UI-independent rules for the replacement parking-jam slice.
// This does not claim to reproduce Bus Fever Party!'s exact rules. Keep the
// model separate from the superseded road-network prototype until direct
// reference play and owner review settle the interaction contract.
import 'dart:collection';

enum JamFacing { up, right, down, left }

enum JamRoute { coral, blue, mint, gold }

enum JamStatus { playing, won, stuck }

enum JamBlock { vehicle, fullBays, alreadyGone }

class JamCell {
  const JamCell(this.x, this.y);

  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      other is JamCell && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

class JamVehicle {
  const JamVehicle({
    required this.id,
    required this.origin,
    required this.facing,
    required this.length,
    this.route,
    this.capacity = 0,
  });

  final String id;
  final JamCell origin;
  final JamFacing facing;
  final int length;
  final JamRoute? route;
  final int capacity;

  bool get isBus => route != null;

  Iterable<JamCell> get cells sync* {
    for (var offset = 0; offset < length; offset++) {
      yield switch (facing) {
        JamFacing.left ||
        JamFacing.right => JamCell(origin.x + offset, origin.y),
        JamFacing.up || JamFacing.down => JamCell(origin.x, origin.y + offset),
      };
    }
  }

  /// Cells between the nose and the lot edge, in travel order.
  Iterable<JamCell> laneToEdge(int width, int height) sync* {
    switch (facing) {
      case JamFacing.up:
        for (var y = origin.y - 1; y >= 0; y--) {
          yield JamCell(origin.x, y);
        }
      case JamFacing.right:
        for (var x = origin.x + length; x < width; x++) {
          yield JamCell(x, origin.y);
        }
      case JamFacing.down:
        for (var y = origin.y + length; y < height; y++) {
          yield JamCell(origin.x, y);
        }
      case JamFacing.left:
        for (var x = origin.x - 1; x >= 0; x--) {
          yield JamCell(x, origin.y);
        }
    }
  }
}

class JamLevel {
  JamLevel({
    required this.width,
    required this.height,
    required this.bayCount,
    required Iterable<JamVehicle> vehicles,
    required Iterable<JamRoute> passengers,
  }) : vehicles = List.unmodifiable(vehicles),
       passengers = List.unmodifiable(passengers) {
    if (width < 1 || height < 1 || bayCount < 1) {
      throw ArgumentError('Lot size and bay count must be positive.');
    }
    final ids = <String>{};
    final occupied = <JamCell>{};
    final seats = <JamRoute, int>{};
    final riders = <JamRoute, int>{};
    for (final route in this.passengers) {
      riders.update(route, (value) => value + 1, ifAbsent: () => 1);
    }
    for (final vehicle in this.vehicles) {
      if (vehicle.id.isEmpty || !ids.add(vehicle.id)) {
        throw ArgumentError('Vehicle IDs must be unique and nonempty.');
      }
      if (vehicle.length < 2 || vehicle.length > 3) {
        throw ArgumentError('Vehicle length must be 2 or 3.');
      }
      if (vehicle.isBus != (vehicle.capacity > 0)) {
        throw ArgumentError('Buses need positive capacity; cars need zero.');
      }
      final route = vehicle.route;
      if (route != null) {
        seats.update(
          route,
          (value) => value + vehicle.capacity,
          ifAbsent: () => vehicle.capacity,
        );
      }
      for (final cell in vehicle.cells) {
        if (cell.x < 0 || cell.x >= width || cell.y < 0 || cell.y >= height) {
          throw ArgumentError('Vehicle ${vehicle.id} is outside the lot.');
        }
        if (!occupied.add(cell)) {
          throw ArgumentError('Vehicle footprints overlap.');
        }
      }
    }
    for (final route in JamRoute.values) {
      if ((seats[route] ?? 0) != (riders[route] ?? 0)) {
        throw ArgumentError('Seats and riders must match for $route.');
      }
    }
  }

  final int width;
  final int height;
  final int bayCount;
  final List<JamVehicle> vehicles;
  final List<JamRoute> passengers;

  JamVehicle vehicle(String id) =>
      vehicles.firstWhere((vehicle) => vehicle.id == id);
}

class JamParkedBus {
  const JamParkedBus(this.id, this.loaded);

  final String id;
  final int loaded;
}

class JamState {
  JamState({
    required Iterable<String> activeVehicleIds,
    required Iterable<JamParkedBus> parked,
    required this.passengerIndex,
    required this.moveCount,
    required this.status,
  }) : activeVehicleIds = UnmodifiableSetView(activeVehicleIds.toSet()),
       parked = List.unmodifiable(parked);

  factory JamState.initial(JamLevel level) => JamState(
    activeVehicleIds: level.vehicles.map((vehicle) => vehicle.id),
    parked: const [],
    passengerIndex: 0,
    moveCount: 0,
    status: JamStatus.playing,
  );

  final Set<String> activeVehicleIds;
  final List<JamParkedBus> parked;
  final int passengerIndex;
  final int moveCount;
  final JamStatus status;

  String get solverKey {
    final active = activeVehicleIds.toList()..sort();
    final bays = parked.map((bus) => '${bus.id}:${bus.loaded}').join(',');
    return '${active.join(',')}|$bays|$passengerIndex';
  }
}

class JamMove {
  const JamMove({
    required this.state,
    required this.vehicleId,
    this.block,
    this.blockingVehicleId,
    this.boarded = 0,
    this.departedBusIds = const [],
  });

  final JamState state;
  final String vehicleId;
  final JamBlock? block;
  final String? blockingVehicleId;
  final int boarded;
  final List<String> departedBusIds;

  bool get moved => block == null;
}

class JamRules {
  const JamRules(this.level);

  final JamLevel level;

  JamMove release(JamState state, String vehicleId) {
    if (!state.activeVehicleIds.contains(vehicleId)) {
      return JamMove(
        state: state,
        vehicleId: vehicleId,
        block: JamBlock.alreadyGone,
      );
    }
    final vehicle = level.vehicle(vehicleId);
    final occupiedBy = <JamCell, String>{};
    for (final other in level.vehicles) {
      if (!state.activeVehicleIds.contains(other.id) || other.id == vehicleId) {
        continue;
      }
      for (final cell in other.cells) {
        occupiedBy[cell] = other.id;
      }
    }
    for (final cell in vehicle.laneToEdge(level.width, level.height)) {
      final blocker = occupiedBy[cell];
      if (blocker != null) {
        return JamMove(
          state: state,
          vehicleId: vehicleId,
          block: JamBlock.vehicle,
          blockingVehicleId: blocker,
        );
      }
    }
    if (vehicle.isBus && state.parked.length >= level.bayCount) {
      return JamMove(
        state: state,
        vehicleId: vehicleId,
        block: JamBlock.fullBays,
      );
    }

    final active = state.activeVehicleIds.toSet()..remove(vehicleId);
    final bays = state.parked.toList();
    if (vehicle.isBus) bays.add(JamParkedBus(vehicleId, 0));
    var passengerIndex = state.passengerIndex;
    var boarded = 0;
    final departed = <String>[];

    // Existing bays have priority. Process again after a full bus departs so a
    // newly exposed passenger group can board another waiting bus.
    var changed = true;
    while (changed && passengerIndex < level.passengers.length) {
      changed = false;
      for (var bay = 0; bay < bays.length; bay++) {
        final parked = bays[bay];
        final parkedVehicle = level.vehicle(parked.id);
        if (parkedVehicle.route != level.passengers[passengerIndex]) continue;
        var loaded = parked.loaded;
        while (loaded < parkedVehicle.capacity &&
            passengerIndex < level.passengers.length &&
            parkedVehicle.route == level.passengers[passengerIndex]) {
          loaded++;
          passengerIndex++;
          boarded++;
          changed = true;
        }
        if (loaded == parkedVehicle.capacity) {
          bays.removeAt(bay);
          departed.add(parked.id);
        } else {
          bays[bay] = JamParkedBus(parked.id, loaded);
        }
        break;
      }
    }

    final status =
        active.isEmpty &&
            bays.isEmpty &&
            passengerIndex == level.passengers.length
        ? JamStatus.won
        : _hasLegalRelease(active, bays)
        ? JamStatus.playing
        : JamStatus.stuck;
    return JamMove(
      state: JamState(
        activeVehicleIds: active,
        parked: bays,
        passengerIndex: passengerIndex,
        moveCount: state.moveCount + 1,
        status: status,
      ),
      vehicleId: vehicleId,
      boarded: boarded,
      departedBusIds: List.unmodifiable(departed),
    );
  }

  bool _hasLegalRelease(Set<String> active, List<JamParkedBus> bays) {
    final occupiedBy = <JamCell, String>{};
    for (final vehicle in level.vehicles) {
      if (!active.contains(vehicle.id)) continue;
      for (final cell in vehicle.cells) {
        occupiedBy[cell] = vehicle.id;
      }
    }
    for (final vehicle in level.vehicles) {
      if (!active.contains(vehicle.id)) continue;
      if (vehicle.isBus && bays.length >= level.bayCount) continue;
      if (vehicle
          .laneToEdge(level.width, level.height)
          .every((cell) => !occupiedBy.containsKey(cell))) {
        return true;
      }
    }
    return false;
  }

  /// Returns a release sequence, or null when no win is reachable within [limit].
  List<String>? solve({JamState? from, int limit = 100000}) {
    final start = from ?? JamState.initial(level);
    if (start.status == JamStatus.won) return const [];
    final queue = Queue<(JamState, List<String>)>()..add((start, const []));
    final seen = <String>{start.solverKey};
    while (queue.isNotEmpty && seen.length <= limit) {
      final (state, path) = queue.removeFirst();
      for (final vehicle in level.vehicles) {
        if (!state.activeVehicleIds.contains(vehicle.id)) continue;
        final move = release(state, vehicle.id);
        if (!move.moved) continue;
        final next = [...path, vehicle.id];
        if (move.state.status == JamStatus.won) return next;
        if (seen.add(move.state.solverKey) &&
            move.state.status == JamStatus.playing) {
          queue.add((move.state, next));
        }
      }
    }
    return null;
  }
}

class JamSession {
  JamSession(this.level)
    : rules = JamRules(level),
      state = JamState.initial(level);

  final JamLevel level;
  final JamRules rules;
  final List<JamState> _history = [];
  JamState state;

  JamMove release(String vehicleId) {
    final move = rules.release(state, vehicleId);
    if (move.moved) {
      _history.add(state);
      state = move.state;
    }
    return move;
  }

  bool undo() {
    if (_history.isEmpty) return false;
    state = _history.removeLast();
    return true;
  }

  void retry() {
    _history.clear();
    state = JamState.initial(level);
  }
}
