// Screen geometry for one level at one size: crowd plaza, bay stalls, the
// street and road ring, the asphalt lot and its cell grid, plus the routes
// buses and riders follow. Pure geometry; no painting.
import 'dart:math' as math;
import 'dart:ui';

import '../jam_model.dart';
import 'jam_motion.dart';

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
  });

  /// Computes the layout for [level] inside a scene of [size] (the area
  /// below the HUD).
  factory JamLayout.compute(Size size, JamLevel level) {
    final w = size.width;
    final p = size.height;
    const margin = 8.0;
    const kerb = 3.0;
    const innerPad = 6.0;
    const maxCell = 68.0;
    final n = level.bayCount;

    final target = level.passengers.length.clamp(8, 26);
    // The crowd band is only as tall as the queue it holds.
    final probe = _queueFor(Rect.fromLTWH(0, 0, w, p * 0.19), w, target);
    final rowsUsed = probe.$4;
    var crowdH = math.max(
      p * 0.12,
      (rowsUsed - 1) * probe.$1 * 1.12 + probe.$1 * 0.98 + 12,
    );
    final bayTarget = p * 0.13;
    final pitch0 = (w - 16) / n;
    final parkedW = math
        .min(pitch0 * 0.62, (bayTarget - 14) / parkedLengthFactor(4))
        .clamp(12.0, 46.0);
    // Stalls are exactly deep enough for the longest bus.
    final bayH = parkedW * parkedLengthFactor(4) + 14;
    final pitch = math.min(pitch0, parkedW * 1.55);
    final roadW = (parkedW * 1.3).clamp(22.0, 42.0);
    late double cell;
    for (var pass = 0; pass < 2; pass++) {
      final lotRegionH = p - crowdH - bayH;
      final availW = w - 2 * margin - 2 * roadW - 2 * kerb - 2 * innerPad;
      final availH = lotRegionH - 2 * roadW - margin - 2 * kerb - 2 * innerPad;
      cell = math.min(
        maxCell,
        math.min(availW / level.width, availH / level.height),
      );
      final excessH = availH - cell * level.height;
      if (pass == 0 && excessH > 1 && crowdH < p * 0.16) {
        // Spare height: a little more crowd room, the rest pads the lot.
        crowdH += math.min(excessH * 0.3, p * 0.16 - crowdH);
      } else {
        break;
      }
    }

    final crowdRect = Rect.fromLTWH(0, 0, w, crowdH);
    final bayRect = Rect.fromLTWH(0, crowdH, w, bayH);
    final streetTop = crowdH + bayH;
    // Ring centre-line rectangle: top edge is the street centre line.
    final ringRect = Rect.fromLTRB(
      margin + roadW / 2,
      streetTop + roadW / 2,
      w - margin - roadW / 2,
      p - margin - roadW / 2,
    );
    final lotRect = Rect.fromLTRB(
      margin + roadW + kerb,
      streetTop + roadW + kerb,
      w - margin - roadW - kerb,
      p - margin - roadW - kerb,
    );
    final gridSize = Size(cell * level.width, cell * level.height);
    final gridOrigin = Offset(
      lotRect.center.dx - gridSize.width / 2,
      lotRect.center.dy - gridSize.height / 2,
    );
    final stallCenters = [
      for (var i = 0; i < n; i++) w / 2 + (i - (n - 1) / 2) * pitch,
    ];

    // Crowd serpentine: pick the biggest figure that still shows ~26.
    final queue = _queueFor(crowdRect, w, target);

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
      columns: level.width,
      rows: level.height,
      parkedW: parkedW,
      stallPitch: pitch,
      stallCenters: stallCenters,
      riderSpacing: queue.$1,
      queuePoints: queue.$2,
      queueCapacity: queue.$3,
    );
  }

  static (double, List<Offset>, int, int) _queueFor(
    Rect rect,
    double w,
    int target,
  ) {
    const side = 10.0;
    const bottomPad = 5.0;
    const topPad = 4.0;
    for (var s = 44.0; s >= 14; s -= 1) {
      for (var r = 2; r <= 5; r++) {
        if ((r - 1) * s * 1.12 + s * 0.98 + topPad + bottomPad > rect.height) {
          break;
        }
        final pts = _serpentine(rect, w, s, r, side, bottomPad);
        final len = _polyLength(pts);
        final cap = (len / s).floor() + 1;
        if (cap >= target) return (s, pts, math.min(cap, 30), r);
      }
    }
    const s = 14.0;
    final r = math.max(
      1,
      ((rect.height - 9 - s * 0.98) / (s * 1.12)).floor() + 1,
    );
    final pts = _serpentine(rect, w, s, r, side, bottomPad);
    return (s, pts, math.min(30, (_polyLength(pts) / s).floor() + 1), r);
  }

  static List<Offset> _serpentine(
    Rect rect,
    double w,
    double s,
    int rows,
    double side,
    double bottomPad,
  ) {
    final xl = side + s / 2;
    final xr = w - side - s / 2;
    final rowGap = s * 1.12;
    final y0 = rect.bottom - bottomPad;
    final pts = <Offset>[Offset(w / 2, y0), Offset(xr, y0)];
    for (var k = 1; k < rows; k++) {
      final y = y0 - k * rowGap;
      final x = k.isOdd ? xr : xl;
      final other = k.isOdd ? xl : xr;
      pts.add(Offset(x, y));
      pts.add(Offset(other, y));
    }
    return pts;
  }

  static double _polyLength(List<Offset> pts) {
    var len = 0.0;
    for (var i = 1; i < pts.length; i++) {
      len += (pts[i] - pts[i - 1]).distance;
    }
    return len;
  }

  /// Parked length = parkedW × factor(length).
  static double parkedLengthFactor(int length) => 0.9 + 0.38 * length;

  final Size size;
  final Rect crowdRect;
  final Rect bayRect;
  final double roadW;
  final double streetTop;

  /// Road centre lines: top = street, left/right = side roads, bottom.
  final Rect ringRect;
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
      Size(v.length * cell - cell * 0.16, cell * 0.78);

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
      bayRect.top + 3,
      x + stallPitch * 0.44,
      streetTop,
    );
  }

  /// Parked buses sit nose-up with the nose near the top of the stall.
  BusPose parkedPose(int slot, int length) {
    final s = parkedBusSize(length);
    final top = stallRect(slot).top + 5;
    return BusPose(
      center: Offset(stallCenters[slot], top + s.width / 2),
      angle: -math.pi / 2,
      length: s.width,
      width: s.height,
    );
  }

  /// Point at the bus nose where riders climb aboard.
  Offset doorPoint(int slot, int length) =>
      Offset(stallCenters[slot], stallRect(slot).top + 6);

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
        final goLeft = start.dx + sx < size.width;
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

  double get cornerRadius => math.max(roadW * 0.9, cell * 0.5);
}
