// Screen geometry for one level at one size: crowd plaza, bay stalls, the
// street and road ring, the asphalt lot and its cell grid, the routes buses
// and riders follow, and where the static park scenery goes. Pure geometry;
// no painting.
//
// Vertical stack (top to bottom): crowd plaza (only as tall as the queue it
// shows) -> bay stalls (only as deep as the longest parked bus) -> street ->
// lot, hugged by the ring road and sized to the level's grid aspect. Any
// height left over becomes a little park below the ring.
import 'dart:math' as math;
import 'dart:ui';

import '../jam_model.dart';
import 'jam_motion.dart';

/// One piece of static park scenery on the grass.
enum JamSceneryKind { tree, bush, bench, flowers, pond }

class JamScenery {
  const JamScenery(this.kind, this.center, this.radius, {this.seed = 0});

  final JamSceneryKind kind;
  final Offset center;

  /// Footprint radius (benches: half length).
  final double radius;
  final int seed;

  Rect get bounds => Rect.fromCircle(center: center, radius: radius);
}

class JamLayout {
  JamLayout._({
    required this.size,
    required this.crowdRect,
    required this.bayRect,
    required this.roadW,
    required this.streetTop,
    required this.ringRect,
    required this.lotRect,
    required this.gridOrigin,
    required this.cell,
    required this.columns,
    required this.rows,
    required this.parkedW,
    required this.stallPitch,
    required this.stallCenters,
    required this.riderSpacing,
    required this.queuePoints,
    required this.queueCapacity,
    required this.scenery,
  });

  // Fixed proportions.
  static const double _margin = 8.0;
  static const double _kerb = 3.0;
  static const double _stallTop = 3.0;
  static const double _noseGap = 5.0;
  static const double _tailGap = 6.0;

  /// Lot bus width as a fraction of the cell.
  static const double lotWidthFactor = 0.78;

  /// Computes the layout for [level] inside a scene of [size] (the area
  /// below the HUD).
  factory JamLayout.compute(Size size, JamLevel level) {
    final w = size.width;
    final p = size.height;
    final n = level.bayCount;
    final cols = level.width;
    final rows = level.height;
    final maxLen = level.vehicles.fold<int>(
      JamLevel.minLength,
      (m, v) => math.max(m, v.length),
    );
    // Small levels must not balloon: cap the cell relative to the width.
    final maxCell = math.min(60.0, w * 0.146);

    // 1. Crowd: the biggest figures that still show the queue's head.
    final want = math.max(1, math.min(level.passengers.length, 26));
    final queue = _queueFor(w, p * 0.18, want);
    final crowdH = queue.height;

    // 2. Lot cell and parked-bus size. Parked buses should stay close to
    // lot-bus width so the morph while driving is gentle; fall back to
    // narrower parked buses only when that costs the lot real size.
    final pitchMax = (w - 16) / n;
    _Fit? fitFor(double ratio) {
      for (var cell = maxCell; cell >= 14; cell -= 0.5) {
        final lotBusW = cell * lotWidthFactor;
        final parkedW = math.min(
          math.min(lotBusW * ratio, pitchMax / 1.42),
          44.0,
        );
        final roadW = math.max(parkedW * 1.3, lotBusW * 1.02).clamp(20.0, 44.0);
        final pad = math.max(4.0, cell * 0.12);
        final bayH =
            _stallTop +
            _noseGap +
            parkedW * parkedLengthFactor(maxLen) +
            _tailGap;
        final needW =
            2 * _margin + 2 * roadW + 2 * _kerb + 2 * pad + cols * cell;
        final needH =
            crowdH +
            bayH +
            2 * roadW +
            2 * _kerb +
            2 * pad +
            rows * cell +
            _margin;
        if (needW <= w && needH <= p) {
          return _Fit(cell, parkedW, roadW, pad, bayH);
        }
      }
      return null;
    }

    final fits = [
      for (final r in const [0.88, 0.8, 0.76, 0.7, 0.58, 0.46]) fitFor(r),
    ];
    final fallback = fits.lastWhere((f) => f != null, orElse: () => null);
    final fit =
        fits.firstWhere(
          (f) => f != null && f.cell >= fallback!.cell * 0.9,
          orElse: () => null,
        ) ??
        _Fit(14, 12, 20, 4, _stallTop + _noseGap + 12 * 3.1 + _tailGap);

    final cell = fit.cell;
    final roadW = fit.roadW;
    final parkedW = fit.parkedW;
    final pad = fit.pad;

    final crowdRect = Rect.fromLTWH(0, 0, w, crowdH);
    final bayRect = Rect.fromLTWH(0, crowdH, w, fit.bayH);
    final streetTop = crowdH + fit.bayH;
    final gridSize = Size(cell * cols, cell * rows);
    final lotRect = Rect.fromLTWH(
      (w - gridSize.width) / 2 - pad,
      streetTop + roadW + _kerb,
      gridSize.width + 2 * pad,
      gridSize.height + 2 * pad,
    );
    final gridOrigin = lotRect.topLeft + Offset(pad, pad);
    // Ring centre lines hug the lot; the top edge is the street centre line.
    final ringRect = Rect.fromLTRB(
      lotRect.left - _kerb - roadW / 2,
      streetTop + roadW / 2,
      lotRect.right + _kerb + roadW / 2,
      lotRect.bottom + _kerb + roadW / 2,
    );
    final pitch = math.min(pitchMax, parkedW * 1.5);
    final stallCenters = [
      for (var i = 0; i < n; i++) w / 2 + (i - (n - 1) / 2) * pitch,
    ];

    final queuePoints = _serpentine(
      w,
      crowdRect.bottom - queue.aisle,
      queue.spacing,
      queue.rows,
      queue.rowLength,
    );

    final scenery = _plantScenery(
      size,
      streetTop + roadW,
      ringRect.inflate(roadW / 2 + 2),
      math.max(roadW, 24.0),
      level.width * 31 + level.height * 7 + n,
    );

    return JamLayout._(
      size: size,
      crowdRect: crowdRect,
      bayRect: bayRect,
      roadW: roadW,
      streetTop: streetTop,
      ringRect: ringRect,
      lotRect: lotRect,
      gridOrigin: gridOrigin,
      cell: cell,
      columns: cols,
      rows: rows,
      parkedW: parkedW,
      stallPitch: pitch,
      stallCenters: stallCenters,
      riderSpacing: queue.spacing,
      queuePoints: queuePoints,
      queueCapacity: queue.capacity,
      scenery: scenery,
    );
  }

  // ---- Crowd queue ---------------------------------------------------------

  static const double _queueSide = 10.0;
  static const double _queueTop = 4.0;

  static double _rowGap(double s) => s * 1.12;

  /// Gap between the front row's feet and the stall tops: the walkway.
  static double _aisleFor(double s) => s * 0.58 + 4;

  static double _crowdHeight(double s, int rows) =>
      _queueTop + (rows - 1) * _rowGap(s) + s * 0.98 + _aisleFor(s);

  /// Picks the biggest rider size whose serpentine shows [want] riders
  /// within [maxH]; a queue that fits on one row is a short centred row.
  static _Queue _queueFor(double w, double maxH, int want) {
    _Queue build(double s, int r) {
      final full = w - 2 * _queueSide - s;
      final rowLength = r == 1 ? math.min(full, (want - 1) * s) : full;
      final len = r * rowLength + (r - 1) * _rowGap(s);
      final cap = math.min(30, (len / s).floor() + 1);
      return _Queue(s, r, rowLength, cap, _crowdHeight(s, r), _aisleFor(s));
    }

    for (var s = 40.0; s >= 14; s -= 1) {
      for (var r = 1; r <= 5; r++) {
        if (_crowdHeight(s, r) > maxH) break;
        final q = build(s, r);
        if (q.capacity >= want) return q;
      }
    }
    const s = 14.0;
    var r = 1;
    while (r < 5 && _crowdHeight(s, r + 1) <= maxH) {
      r++;
    }
    return build(s, r);
  }

  /// Serpentine from the front (bottom row, left end) backwards: the bottom
  /// row runs left to right, turns up, the next runs right to left, ...
  static List<Offset> _serpentine(
    double w,
    double y0,
    double s,
    int rows,
    double rowLength,
  ) {
    final xl = w / 2 - rowLength / 2;
    final xr = w / 2 + rowLength / 2;
    final pts = <Offset>[];
    for (var k = 0; k < rows; k++) {
      final y = y0 - k * _rowGap(s);
      final (a, b) = k.isEven ? (xl, xr) : (xr, xl);
      pts
        ..add(Offset(a, y))
        ..add(Offset(b, y));
    }
    if (pts.length == 2 && (pts[1] - pts[0]).distance < 1) {
      pts[1] = pts[0] + const Offset(1, 0);
    }
    return pts;
  }

  // ---- Scenery -------------------------------------------------------------

  /// Deterministic park dressing on the grass that is not road or lot.
  static List<JamScenery> _plantScenery(
    Size size,
    double grassTop,
    Rect keepOut,
    double unit,
    int seed,
  ) {
    final w = size.width;
    final h = size.height;
    final regions = <Rect>[
      Rect.fromLTRB(0, grassTop, keepOut.left, h),
      Rect.fromLTRB(keepOut.right, grassTop, w, h),
      Rect.fromLTRB(keepOut.left, keepOut.bottom, keepOut.right, h),
    ].where((r) => r.width >= 14 && r.height >= 14).toList();
    final rnd = math.Random(seed);
    final placed = <JamScenery>[];
    // A pond anchors a big park so it reads as designed, not left over.
    final bottom = Rect.fromLTRB(0, keepOut.bottom, w, h);
    if (bottom.height >= unit * 3.2 && bottom.width >= unit * 6) {
      final r = math.min(bottom.height * 0.22, unit * 1.15);
      final c = Offset(
        w * (0.3 + rnd.nextDouble() * 0.4),
        bottom.top + bottom.height * (0.45 + rnd.nextDouble() * 0.1),
      );
      placed.add(
        JamScenery(JamSceneryKind.pond, c, r, seed: rnd.nextInt(1000)),
      );
    }
    final area = regions.fold<double>(0, (a, r) => a + r.width * r.height);
    final budget = math.min(26, (area / (unit * unit * 2.2)).floor());
    for (var attempt = 0; attempt < 400 && placed.length < budget; attempt++) {
      final region = regions[rnd.nextInt(regions.length)];
      final roll = rnd.nextDouble();
      final roomy = math.min(region.width, region.height);
      JamSceneryKind kind;
      double r;
      if (roll < 0.34 && roomy >= unit * 1.1) {
        kind = JamSceneryKind.tree;
        r = unit * (0.42 + rnd.nextDouble() * 0.18);
      } else if (roll < 0.44 && region.width >= unit * 1.6) {
        kind = JamSceneryKind.bench;
        r = unit * 0.5;
      } else if (roll < 0.72) {
        kind = JamSceneryKind.bush;
        r = unit * (0.24 + rnd.nextDouble() * 0.1);
      } else {
        kind = JamSceneryKind.flowers;
        r = unit * 0.22;
      }
      r = math.min(r, roomy / 2 - 1);
      if (r < 5) continue;
      final c = Offset(
        region.left + r + rnd.nextDouble() * (region.width - 2 * r),
        region.top + r + rnd.nextDouble() * (region.height - 2 * r),
      );
      // Leave the screen's very bottom edge (gesture bar) mostly clear.
      if (c.dy > h - 4) continue;
      final clash = placed.any(
        (o) =>
            (o.center - c).distance <
            o.radius * (o.kind == JamSceneryKind.pond ? 1.5 : 1) +
                r +
                unit * 0.12,
      );
      if (clash) continue;
      placed.add(JamScenery(kind, c, r, seed: rnd.nextInt(1 << 20)));
    }
    // Ponds lie flat underneath; everything else paints far-to-near so
    // lower items overlap the ones above them.
    placed.sort((a, b) {
      final pa = a.kind == JamSceneryKind.pond ? 0 : 1;
      final pb = b.kind == JamSceneryKind.pond ? 0 : 1;
      return pa != pb ? pa - pb : a.center.dy.compareTo(b.center.dy);
    });
    return placed;
  }

  /// Parked length = parkedW × factor(length).
  static double parkedLengthFactor(int length) => 0.7 + 0.6 * length;

  final Size size;
  final Rect crowdRect;
  final Rect bayRect;
  final double roadW;
  final double streetTop;

  /// Road centre lines: top = street, left/right = side roads, bottom.
  final Rect ringRect;

  /// Asphalt lot: the cell grid plus a thin apron.
  final Rect lotRect;
  final Offset gridOrigin;
  final double cell;
  final int columns;
  final int rows;
  final double parkedW;
  final double stallPitch;
  final List<double> stallCenters;
  final double riderSpacing;
  final List<Offset> queuePoints;
  final int queueCapacity;
  final List<JamScenery> scenery;

  double get streetY => ringRect.top;
  Rect get gridRect =>
      Rect.fromLTWH(gridOrigin.dx, gridOrigin.dy, cell * columns, cell * rows);

  Rect cellRect(JamCell c) => Rect.fromLTWH(
    gridOrigin.dx + c.x * cell,
    gridOrigin.dy + c.y * cell,
    cell,
    cell,
  );

  /// Axis-aligned footprint of [v] on the lot.
  Rect footprint(JamVehicle v) {
    var r = cellRect(v.cells.first);
    for (final c in v.cells.skip(1)) {
      r = r.expandToInclude(cellRect(c));
    }
    return r;
  }

  static double headingOf(JamFacing f) => switch (f) {
    JamFacing.up => -math.pi / 2,
    JamFacing.right => 0,
    JamFacing.down => math.pi / 2,
    JamFacing.left => math.pi,
  };

  static Offset directionOf(JamFacing f) => switch (f) {
    JamFacing.up => const Offset(0, -1),
    JamFacing.right => const Offset(1, 0),
    JamFacing.down => const Offset(0, 1),
    JamFacing.left => const Offset(-1, 0),
  };

  Size lotBusSize(JamVehicle v) =>
      Size(v.length * cell - cell * 0.16, cell * lotWidthFactor);

  BusPose lotPose(JamVehicle v) {
    final s = lotBusSize(v);
    return BusPose(
      center: footprint(v).center,
      angle: headingOf(v.facing),
      length: s.width,
      width: s.height,
    );
  }

  Size parkedBusSize(int length) =>
      Size(parkedW * parkedLengthFactor(length), parkedW);

  Rect stallRect(int slot) {
    final x = stallCenters[slot];
    return Rect.fromLTRB(
      x - stallPitch * 0.44,
      bayRect.top + _stallTop,
      x + stallPitch * 0.44,
      streetTop,
    );
  }

  /// Parked buses sit nose-up with the nose near the top of the stall.
  BusPose parkedPose(int slot, int length) {
    final s = parkedBusSize(length);
    final top = stallRect(slot).top + _noseGap;
    return BusPose(
      center: Offset(stallCenters[slot], top + s.width / 2),
      angle: -math.pi / 2,
      length: s.width,
      width: s.height,
    );
  }

  /// Width of the opening in the stall's top line that riders walk through.
  double get gateWidth => math.min(stallPitch * 0.5, parkedW * 0.62);

  /// Point at the bus nose where riders climb aboard.
  Offset doorPoint(int slot, int length) =>
      Offset(stallCenters[slot], stallRect(slot).top + _noseGap + 2);

  /// Feet line of the walkway between the crowd and the stall tops.
  double get walkY => bayRect.top - 2;

  /// Path a boarding rider hops along: off the queue onto the walkway,
  /// along it to the stall's gate, then through the gate to the door. It
  /// never crosses a stall line.
  List<Offset> riderRoute(Offset from, int slot, int length) {
    final door = doorPoint(slot, length);
    final gate = Offset(door.dx, walkY);
    final dx = gate.dx - from.dx;
    final step = math.min(dx.abs(), riderSpacing * 0.5) * dx.sign;
    return [from, Offset(from.dx + step, walkY), gate, door];
  }

  /// Position along the queue at [u] slots from the front (feet point).
  Offset queuePoint(double u) {
    var d = math.max(0.0, u) * riderSpacing;
    for (var i = 1; i < queuePoints.length; i++) {
      final a = queuePoints[i - 1];
      final b = queuePoints[i];
      final seg = (b - a).distance;
      if (d <= seg) return Offset.lerp(a, b, seg == 0 ? 0 : d / seg)!;
      d -= seg;
    }
    final a = queuePoints[queuePoints.length - 2];
    final b = queuePoints.last;
    final dir = (b - a) / math.max(1e-6, (b - a).distance);
    return b + dir * d;
  }

  /// Route from the lot to bay [slot]: forward along the facing, onto the
  /// ring, round to the street, then up into the stall.
  List<Offset> parkRoute(JamVehicle v, int slot) {
    final start = footprint(v).center;
    final sx = stallCenters[slot];
    final end = parkedPose(slot, v.length).center;
    final ring = ringRect;
    final top = ring.top;
    final pts = <Offset>[start];
    switch (v.facing) {
      case JamFacing.up:
        pts.add(Offset(start.dx, top));
      case JamFacing.left:
        pts
          ..add(Offset(ring.left, start.dy))
          ..add(Offset(ring.left, top));
      case JamFacing.right:
        pts
          ..add(Offset(ring.right, start.dy))
          ..add(Offset(ring.right, top));
      case JamFacing.down:
        final goLeft = start.dx + sx < 2 * ring.center.dx;
        final sideX = goLeft ? ring.left : ring.right;
        pts
          ..add(Offset(start.dx, ring.bottom))
          ..add(Offset(sideX, ring.bottom))
          ..add(Offset(sideX, top));
    }
    pts
      ..add(Offset(sx, top))
      ..add(end);
    return pts;
  }

  /// Distance along [route] (as a polyline) at which the bus centre leaves
  /// the asphalt, and at which it turns off the street into its stall.
  (double, double, double) routeMilestones(List<Offset> route) {
    var total = 0.0;
    for (var i = 1; i < route.length; i++) {
      total += (route[i] - route[i - 1]).distance;
    }
    // First segment runs from the footprint centre straight out of the lot.
    final a = route[0];
    final b = route[1];
    final dir = (b - a) / math.max(1e-6, (b - a).distance);
    var exit = 0.0;
    final lot = lotRect;
    while (exit < (b - a).distance && lot.contains(a + dir * exit)) {
      exit += 2;
    }
    final stallLeg =
        (route[route.length - 1] - route[route.length - 2]).distance;
    return (exit, total - stallLeg, total);
  }

  double get cornerRadius => math.max(roadW * 0.9, cell * 0.5);
}

class _Fit {
  _Fit(this.cell, this.parkedW, this.roadW, this.pad, this.bayH);

  final double cell;
  final double parkedW;
  final double roadW;
  final double pad;
  final double bayH;
}

class _Queue {
  _Queue(
    this.spacing,
    this.rows,
    this.rowLength,
    this.capacity,
    this.height,
    this.aisle,
  );

  final double spacing;
  final int rows;
  final double rowLength;
  final int capacity;
  final double height;
  final double aisle;
}
