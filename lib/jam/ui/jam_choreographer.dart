// Visual timeline for Bus Jam.
//
// The rules (`JamSession`) are always applied immediately; the screen then
// hands the resulting `JamEvent`s to [JamChoreographer.play]. The
// choreographer turns them into *scheduled* motions on a visual clock:
//
//  * park   -> a [BusSprite] with a [MotionLeg] from the lot, round the
//              ring, into its stall (start delayed only if the stall is
//              still being vacated by a departing bus);
//  * board  -> a [RiderWalk] from the queue front to the bus door, started
//              no earlier than the bus arrival and strictly in queue order;
//  * depart -> reverse-out + drive-off legs after the bus's last rider.
//
// Every visual quantity is then a pure function of time (bus pose, seats
// filled, queue shuffle, walking riders), so several taps can overlap
// freely and nothing can race the rules. [snap] discards the timeline and
// rebuilds the visual model from a [JamState] (undo, retry, level change,
// reduced motion, and compaction once the timeline has finished).
import 'dart:math' as math;
import 'dart:ui';

import '../jam_model.dart';
import 'jam_layout.dart';
import 'jam_motion.dart';
import 'jam_theme.dart';

/// A bus that has left the lot: driving to, parked in, or leaving a bay.
class BusSprite {
  BusSprite({
    required this.vehicle,
    required this.slot,
    required this.parked,
    this.baseLoaded = 0,
    this.arriveAt = double.negativeInfinity,
  });

  final JamVehicle vehicle;
  final int slot;
  final BusPose parked;
  final int baseLoaded;
  double arriveAt;
  double? departAt;

  /// The lot-to-stall leg, when this sprite drove in during play.
  MotionLeg? parkLeg;
  double goneAt = double.infinity;
  final List<MotionLeg> legs = [];
  final List<double> boardArrivals = [];

  double get lastArrival =>
      boardArrivals.isEmpty ? arriveAt : boardArrivals.reduce(math.max);

  BusPose poseAt(double t) {
    var pose = parked;
    final park = parkLeg;
    if (park != null && t < park.start) return park.poseAt(park.start);
    for (final leg in legs) {
      if (t >= leg.start) pose = leg.poseAt(t);
    }
    return pose;
  }

  bool isMovingAt(double t) =>
      legs.any((leg) => t >= leg.start - 1e-6 && t <= leg.end);

  int loadedAt(double t) =>
      baseLoaded + boardArrivals.where((a) => a <= t).length;

  /// Little squash-and-stretch each time a rider climbs aboard.
  double bumpAt(double t) {
    var b = 0.0;
    for (final a in boardArrivals) {
      final d = t - a;
      if (d >= 0 && d < 0.24) b = math.max(b, math.sin(d / 0.24 * math.pi));
    }
    return b * 0.07;
  }
}

/// A rider walking from the queue front to a bus door.
class RiderWalk {
  RiderWalk({
    required this.index,
    required this.color,
    required this.start,
    required this.end,
    required this.bus,
  });

  final int index;
  final JamColor color;
  final double start;
  final double end;
  final BusSprite bus;
}

enum ChoreoCueKind { board, depart, park }

class ChoreoCue {
  const ChoreoCue(this.time, this.kind);
  final double time;
  final ChoreoCueKind kind;
}

class JamChoreographer {
  JamChoreographer({required this.level, required this.layout}) {
    _slotFreeAt = List.filled(level.bayCount, double.negativeInfinity);
  }

  final JamLevel level;
  JamLayout layout;

  // Tunables (seconds).
  static const double boardStagger = 0.13;
  static const double shuffleTime = 0.3;
  static const double lurchTime = 0.5;
  static const double hintTime = 2.6;

  final List<BusSprite> sprites = [];
  final Map<String, BusSprite> _byVehicle = {};
  final List<RiderWalk> walks = [];
  final List<double> _boardStarts = [];
  final List<ChoreoCue> _cues = [];
  late List<double> _slotFreeAt;
  int queueBase = 0;
  double _lastBoardStart = double.negativeInfinity;
  double _endTime = double.negativeInfinity;

  // Transient effects.
  final Map<String, double> lurches = {};
  final Map<String, double> flashes = {};
  final Map<int, double> stallPulses = {};
  String? hintTarget;
  double hintStart = double.negativeInfinity;
  double _effectsEnd = double.negativeInfinity;

  /// End of the scheduled choreography (not counting effects).
  double get endTime => _endTime;

  bool busyAt(double t) => _endTime > t;

  /// Whether anything (choreography or effects) still animates at [t].
  bool animatingAt(double t) => _endTime > t || _effectsEnd > t;

  /// Discards every scheduled motion and rebuilds the resting picture of
  /// [state]. Effects are cleared too.
  void snap(JamState state) {
    sprites.clear();
    _byVehicle.clear();
    walks.clear();
    _boardStarts.clear();
    _cues.clear();
    lurches.clear();
    flashes.clear();
    stallPulses.clear();
    hintTarget = null;
    _effectsEnd = double.negativeInfinity;
    _endTime = double.negativeInfinity;
    _lastBoardStart = double.negativeInfinity;
    _slotFreeAt = List.filled(level.bayCount, double.negativeInfinity);
    queueBase = state.passengerIndex;
    for (var slot = 0; slot < state.bays.length; slot++) {
      final bay = state.bays[slot];
      if (bay == null) continue;
      final v = level.vehicle(bay.vehicleId);
      final sprite = BusSprite(
        vehicle: v,
        slot: slot,
        parked: layout.parkedPose(slot, v.length),
        baseLoaded: bay.loaded,
      );
      sprites.add(sprite);
      _byVehicle[v.id] = sprite;
    }
  }

  /// Schedules [events] (from one successful tap) starting at [now].
  void play(List<JamEvent> events, double now) {
    for (final e in events) {
      switch (e) {
        case JamPark(:final vehicleId, :final slot):
          _park(level.vehicle(vehicleId), slot, now);
        case JamBoard(:final passengerIndex, :final vehicleId):
          _board(passengerIndex, vehicleId, now);
        case JamDepart(:final vehicleId, :final slot):
          _depart(vehicleId, slot, now);
      }
    }
  }

  void _park(JamVehicle v, int slot, double now) {
    final route = layout.parkRoute(v, slot);
    final path = roundedPolyline(route, layout.cornerRadius);
    final probe = MotionLeg(
      path: path,
      start: 0,
      duration: 1,
      fromSize: Size.zero,
      toSize: Size.zero,
    );
    final duration = (0.4 + probe.length / 1500).clamp(0.6, 0.9);
    final start = math.max(now, _slotFreeAt[slot] - duration + 0.12);
    final parked = layout.parkedPose(slot, v.length);
    final sprite = BusSprite(vehicle: v, slot: slot, parked: parked);
    final leg = MotionLeg(
      path: path,
      start: start,
      duration: duration,
      fromSize: layout.lotBusSize(v),
      toSize: layout.parkedBusSize(v.length),
      sizeFrom: 0.3,
      sizeTo: 0.85,
      accel: 0.2,
      decel: 0.28,
    );
    sprite
      ..parkLeg = leg
      ..legs.add(leg);
    sprite.arriveAt = start + duration;
    sprites.add(sprite);
    _byVehicle[v.id] = sprite;
    _cues.add(ChoreoCue(sprite.arriveAt, ChoreoCueKind.park));
    _extend(sprite.arriveAt);
  }

  void _board(int index, String vehicleId, double now) {
    final sprite = _byVehicle[vehicleId];
    if (sprite == null) return;
    final start = [
      now,
      sprite.arriveAt + 0.04,
      _lastBoardStart + boardStagger,
    ].reduce(math.max);
    final from = layout.queuePoint(0);
    final to = layout.doorPoint(sprite.slot, sprite.vehicle.length);
    final duration = (0.22 + (to - from).distance / 900).clamp(0.26, 0.5);
    final walk = RiderWalk(
      index: index,
      color: level.passengers[index],
      start: start,
      end: start + duration,
      bus: sprite,
    );
    walks.add(walk);
    _boardStarts.add(start);
    _lastBoardStart = start;
    sprite.boardArrivals.add(walk.end);
    _cues.add(ChoreoCue(walk.end, ChoreoCueKind.board));
    _extend(math.max(walk.end + 0.25, start + shuffleTime));
  }

  void _depart(String vehicleId, int slot, double now) {
    final sprite = _byVehicle.remove(vehicleId);
    if (sprite == null) return;
    final start = math.max(now, sprite.lastArrival + 0.2);
    sprite.departAt = start;
    final p = sprite.parked;
    final sx = p.center.dx;
    final dir = sx >= layout.size.width / 2 ? 1.0 : -1.0;
    final r = layout.roadW * 0.9;
    final streetY = layout.streetY;
    final reverse = MotionLeg(
      path: roundedPolyline([
        p.center,
        Offset(sx, streetY),
        Offset(sx - dir * r * 2, streetY),
      ], r),
      start: start,
      duration: 0.34,
      fromSize: Size(p.length, p.width),
      toSize: Size(p.length, p.width),
      reverse: true,
      accel: 0.35,
      decel: 0.35,
    );
    final startX = sx - dir * r * 2;
    final endX = dir > 0 ? layout.size.width + p.length * 1.2 : -p.length * 1.2;
    final distance = (endX - startX).abs();
    final drive = MotionLeg(
      path: roundedPolyline([
        Offset(startX, streetY),
        Offset(endX, streetY),
      ], r),
      start: reverse.end + 0.04,
      duration: (distance / 950).clamp(0.32, 0.7),
      fromSize: Size(p.length, p.width),
      toSize: Size(p.length, p.width),
      accel: 0.5,
      decel: 0.0,
    );
    sprite.legs
      ..add(reverse)
      ..add(drive);
    sprite.goneAt = drive.end;
    _slotFreeAt[slot] = reverse.end;
    _cues.add(ChoreoCue(start, ChoreoCueKind.depart));
    _extend(drive.end);
  }

  void _extend(double t) => _endTime = math.max(_endTime, t);

  /// Removes and returns cues due at or before [t], in time order.
  List<ChoreoCue> takeCues(double t) {
    final due = _cues.where((c) => c.time <= t).toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    _cues.removeWhere((c) => c.time <= t);
    return due;
  }

  // ---- Queue -------------------------------------------------------------

  /// Continuous queue front: rises smoothly as riders step out.
  double frontAt(double t) {
    var f = queueBase.toDouble();
    for (final s in _boardStarts) {
      f += smoothstep(s, s + shuffleTime, t);
    }
    return f;
  }

  /// First passenger index still standing in the queue at [t].
  int firstQueuedAt(double t) =>
      queueBase + _boardStarts.where((s) => s <= t).length;

  /// Where [walk]'s rider is at [t] (feet), plus hop lift and scale.
  (Offset, double, double, double) walkPose(RiderWalk walk, double t) {
    final from = layout.queuePoint(walk.index - frontAt(walk.start));
    final to = layout.doorPoint(walk.bus.slot, walk.bus.vehicle.length);
    final p = ((t - walk.start) / (walk.end - walk.start)).clamp(0.0, 1.0);
    final e = p < 0.5 ? 2 * p * p : 1 - math.pow(-2 * p + 2, 2) / 2;
    final pos = Offset.lerp(from, to, e.toDouble())!;
    final s = layout.riderSpacing;
    final lift = (math.sin(p * math.pi * 2)).abs() * s * 0.22;
    final scale = p < 0.75 ? 1.0 : 1 - (p - 0.75) / 0.25 * 0.45;
    final opacity = p < 0.85 ? 1.0 : 1 - (p - 0.85) / 0.15;
    return (pos, lift, scale, opacity);
  }

  // ---- Effects -----------------------------------------------------------

  void lurch(String vehicleId, String? blockerId, double now) {
    lurches[vehicleId] = now;
    if (blockerId != null) flashes[blockerId] = now;
    _effectsEnd = math.max(_effectsEnd, now + lurchTime);
  }

  void pulseStalls(double now) {
    for (var i = 0; i < level.bayCount; i++) {
      stallPulses[i] = now;
    }
    _effectsEnd = math.max(_effectsEnd, now + 0.8);
  }

  void hint(String vehicleId, double now) {
    hintTarget = vehicleId;
    hintStart = now;
    _effectsEnd = math.max(_effectsEnd, now + hintTime);
  }

  /// Keeps the clock running until [t] (e.g. for a toast or hand bob).
  void holdUntil(double t) => _effectsEnd = math.max(_effectsEnd, t);

  /// Forward offset of a lurching bus, in pixels.
  double lurchAt(String vehicleId, double t) {
    final s = lurches[vehicleId];
    if (s == null) return 0;
    final d = t - s;
    if (d < 0 || d > lurchTime) return 0;
    final a = layout.cell * 0.2;
    const out = 0.08;
    if (d < out) return a * math.sin(d / out * math.pi / 2);
    final u = d - out;
    return a * math.cos(u * math.pi * 2 / 0.2) * math.exp(-u * 9);
  }

  double flashAt(String vehicleId, double t) {
    final s = flashes[vehicleId];
    if (s == null) return 0;
    final d = t - s;
    if (d < 0 || d > lurchTime) return 0;
    return 0.65 *
        (math.sin(d / lurchTime * math.pi * 3)).abs() *
        (1 - d / lurchTime);
  }

  double hintGlowAt(String vehicleId, double t) {
    if (hintTarget != vehicleId) return 0;
    final d = t - hintStart;
    if (d < 0 || d > hintTime) return 0;
    final fade = d > hintTime - 0.4 ? (hintTime - d) / 0.4 : 1.0;
    return (0.55 + 0.45 * math.sin(d * math.pi * 2 / 0.75 - math.pi / 2)) *
        fade;
  }

  double stallPulseAt(int slot, double t) {
    final s = stallPulses[slot];
    if (s == null) return 0;
    final d = t - s;
    if (d < 0 || d > 0.8) return 0;
    return (math.sin(d / 0.8 * math.pi * 2)).abs() * (1 - d / 0.8);
  }
}
