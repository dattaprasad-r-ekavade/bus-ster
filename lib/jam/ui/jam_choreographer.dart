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

  /// When the last free seat was taken (null while seats remain).
  double? get fullAt {
    if (boardArrivals.isEmpty) return null;
    if (baseLoaded + boardArrivals.length < vehicle.capacity) return null;
    return lastArrival;
  }

  /// "Full!" pop: a quick overshooting scale bounce once the bus fills.
  double popAt(double t) {
    final f = fullAt;
    if (f == null) return 0;
    final d = t - f;
    if (d < 0 || d >= JamChoreographer.popTime) return 0;
    final u = d / JamChoreographer.popTime;
    return math.sin(u * math.pi) * (1 - u * 0.5) * 0.16 -
        math.sin(u * math.pi * 2) * 0.03 * u;
  }

  /// 0..1 progress of the sparkle burst around a freshly filled bus.
  double? sparkleAt(double t) {
    final f = fullAt;
    if (f == null) return null;
    final d = t - f;
    if (d < 0 || d >= JamChoreographer.sparkleTime) return null;
    return d / JamChoreographer.sparkleTime;
  }

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

  /// Walking riders keep at least this many rider widths between them.
  static const double minRiderGap = 1.1;

  /// Latest a boarding rider may start after the previous one. Keeps a full
  /// 8-seat bus boarding in about 2 s.
  static const double maxBoardGap = 0.22;

  /// Step while searching for a non-overlapping boarding start, and the
  /// sampling interval used to check walker clearance.
  static const double _startStep = 0.01;
  static const double _clearanceSample = 1 / 240;

  static const double shuffleTime = 0.3;
  static const double lurchTime = 0.5;
  static const double hintTime = 2.6;
  static const double popTime = 0.32;
  static const double sparkleTime = 0.6;

  /// Pause between the last rider boarding and the bus backing out, long
  /// enough for the full pop to read.
  static const double departDelay = 0.36;

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

  /// 0..1 envelope for idle flourishes (front-rider bob). It only rises
  /// while the clock is running anyway and reaches 0 exactly when the clock
  /// stops, so it never keeps the ticker alive or freezes mid-pose.
  double liveliness(double t) {
    final until = math.max(_endTime, _effectsEnd);
    return ((until - t) / 0.35).clamp(0.0, 1.0);
  }

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
    // Shrink over a short stretch of road just past the lot edge, so the bus
    // never shrinks on the asphalt and fits the road for the rest of the ring.
    final (exit, turn, total) = layout.routeMilestones(route);
    final scale = probe.length / math.max(1e-6, total);
    final sizeFrom = (exit * scale / probe.length).clamp(0.0, 0.6);
    final sizeTo = (turn * scale / probe.length).clamp(sizeFrom + 0.1, 0.97);
    final leg = MotionLeg(
      path: path,
      start: start,
      duration: duration,
      fromSize: layout.lotBusSize(v),
      toSize: layout.parkedBusSize(v.length),
      sizeFrom: sizeFrom,
      sizeTo: sizeTo,
      sizeCurve: MotionSizeCurve.gentle,
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
    final route = layout.riderRoute(
      layout.queuePoint(0),
      sprite.slot,
      sprite.vehicle.length,
    );
    final duration = (0.22 + _polyLength(route) / 1150).clamp(0.28, 0.5);
    // Earliest start keeps the queue order and the stagger. Walkers start
    // from the moving queue front, so a fixed time gap cannot guarantee
    // spacing; instead take the first start (within [maxBoardGap] of the
    // previous rider) whose path keeps [minRiderGap] widths clear of every
    // walker already scheduled. Poses only depend on earlier starts, so
    // this is deterministic.
    final earliest = [
      now,
      sprite.arriveAt + 0.04,
      _lastBoardStart + boardStagger,
    ].reduce(math.max);
    final limit = math.max(earliest, _lastBoardStart + maxBoardGap);
    final minDist = minRiderGap * layout.riderSpacing;
    var start = earliest;
    var bestClear = double.negativeInfinity;
    for (var s = earliest; s <= limit + 1e-9; s += _startStep) {
      final clear = _clearance(_walkAt(index, sprite, s, duration));
      if (clear > bestClear) {
        bestClear = clear;
        start = s;
      }
      if (clear >= minDist) break;
    }
    final walk = _walkAt(index, sprite, start, duration);
    walks.add(walk);
    _boardStarts.add(start);
    _lastBoardStart = start;
    sprite.boardArrivals.add(walk.end);
    _cues.add(ChoreoCue(walk.end, ChoreoCueKind.board));
    _extend(math.max(walk.end + 0.25, start + shuffleTime));
  }

  RiderWalk _walkAt(
    int index,
    BusSprite sprite,
    double start,
    double duration,
  ) => RiderWalk(
    index: index,
    color: level.passengers[index],
    start: start,
    end: start + duration,
    bus: sprite,
  );

  /// Smallest distance between the candidate's rider and any already
  /// scheduled walker, sampled while both are on the walkway.
  double _clearance(RiderWalk candidate) {
    var clear = double.infinity;
    for (final other in walks) {
      final from = math.max(candidate.start, other.start);
      final to = math.min(candidate.end, other.end);
      for (var t = from; t <= to; t += _clearanceSample) {
        final d = (walkPose(candidate, t).$1 - walkPose(other, t).$1).distance;
        if (d < clear) clear = d;
      }
    }
    return clear;
  }

  void _depart(String vehicleId, int slot, double now) {
    final sprite = _byVehicle.remove(vehicleId);
    if (sprite == null) return;
    final start = math.max(now, sprite.lastArrival + departDelay);
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
  ///
  /// Riders hop along [JamLayout.riderRoute]: each hop eases forward while
  /// airborne and lands on a short pause, so the motion reads as a series of
  /// little arcs rather than a slide.
  (Offset, double, double, double) walkPose(RiderWalk walk, double t) {
    final from = layout.queuePoint(walk.index - frontAt(walk.start));
    final route = layout.riderRoute(
      from,
      walk.bus.slot,
      walk.bus.vehicle.length,
    );
    final p = ((t - walk.start) / (walk.end - walk.start)).clamp(0.0, 1.0);
    final s = layout.riderSpacing;
    final length = _polyLength(route);
    final hops = math.max(2, (length / (s * 1.3)).round());
    final h = (p * hops).clamp(0.0, hops - 1e-9);
    final i = h.floor();
    final u = h - i;
    // Airborne for 86% of each hop, a brief touch-down for the rest.
    final air = (u / 0.86).clamp(0.0, 1.0);
    final along = (i + smoothstep(0, 1, air)) / hops;
    final pos = _pointAlong(route, along * length);
    final hopH = s * (0.26 + 0.06 * math.min(1.0, length / (s * 6)));
    final lift = math.sin(air * math.pi) * hopH;
    final scale = p < 0.8 ? 1.0 : 1 - (p - 0.8) / 0.2 * 0.45;
    final opacity = p < 0.88 ? 1.0 : 1 - (p - 0.88) / 0.12;
    return (pos, lift, scale, opacity);
  }

  static double _polyLength(List<Offset> pts) {
    var len = 0.0;
    for (var i = 1; i < pts.length; i++) {
      len += (pts[i] - pts[i - 1]).distance;
    }
    return len;
  }

  static Offset _pointAlong(List<Offset> pts, double d) {
    for (var i = 1; i < pts.length; i++) {
      final seg = (pts[i] - pts[i - 1]).distance;
      if (d <= seg) {
        return Offset.lerp(pts[i - 1], pts[i], seg == 0 ? 0 : d / seg)!;
      }
      d -= seg;
    }
    return pts.last;
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
