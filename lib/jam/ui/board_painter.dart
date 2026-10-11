// Static scenery: plaza, bay stalls, street + road ring, asphalt lot and
// grass. Painted once per layout behind a RepaintBoundary.
import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import 'bay_painter.dart';
import 'crowd_painter.dart';
import 'jam_layout.dart';
import 'jam_theme.dart';

class JamBoardPainter extends CustomPainter {
  JamBoardPainter(this.layout, this.bayCount);

  final JamLayout layout;
  final int bayCount;

  @override
  void paint(Canvas canvas, Size size) {
    final l = layout;
    final w = size.width;
    final h = size.height;

    // Grass everywhere first.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [JamPalette.grassLight, JamPalette.grass],
        ).createShader(Offset.zero & size),
    );
    _grassTufts(canvas, size);

    // Plaza (crowd + bay strip sidewalk).
    final plaza = Rect.fromLTRB(0, 0, w, l.streetTop);
    canvas.drawRect(plaza, Paint()..color = JamPalette.plaza);
    _tiles(canvas, plaza);
    paintQueueBarriers(canvas, l);

    // Street (full width) and the ring road.
    final road = Paint()..color = JamPalette.road;
    canvas.drawRect(
      Rect.fromLTRB(0, l.streetTop, w, l.streetTop + l.roadW),
      road,
    );
    final ring = l.ringRect;
    final rr = l.roadW * 1.1;
    final ringPath = Path()
      ..moveTo(ring.left, ring.top)
      ..lineTo(ring.left, ring.bottom - rr)
      ..quadraticBezierTo(ring.left, ring.bottom, ring.left + rr, ring.bottom)
      ..lineTo(ring.right - rr, ring.bottom)
      ..quadraticBezierTo(ring.right, ring.bottom, ring.right, ring.bottom - rr)
      ..lineTo(ring.right, ring.top);
    canvas.drawPath(
      ringPath,
      Paint()
        ..color = JamPalette.road
        ..style = PaintingStyle.stroke
        ..strokeWidth = l.roadW,
    );
    // Kerb on the plaza side of the street.
    canvas.drawRect(
      Rect.fromLTRB(0, l.streetTop - 2, w, l.streetTop + 1.5),
      Paint()..color = JamPalette.kerb,
    );

    // Lot asphalt.
    final lot = RRect.fromRectAndRadius(
      l.lotRect.inflate(3),
      Radius.circular(l.roadW * 0.5),
    );
    canvas.drawRRect(lot, Paint()..color = JamPalette.kerb);
    canvas.drawRRect(
      RRect.fromRectAndRadius(l.lotRect, Radius.circular(l.roadW * 0.4)),
      Paint()
        ..shader = const RadialGradient(
          colors: [JamPalette.asphaltLight, JamPalette.asphalt],
          radius: 0.9,
        ).createShader(l.lotRect),
    );
    _lotMarkings(canvas);

    // Dashed centre lines along street and ring.
    final dash = Paint()
      ..color = JamPalette.roadDash.withValues(alpha: 0.85)
      ..strokeWidth = math.max(1.5, l.roadW * 0.07)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    _dashed(
      canvas,
      Path()
        ..moveTo(0, l.streetY)
        ..lineTo(w, l.streetY),
      dash,
      l.roadW * 0.45,
      l.roadW * 0.45,
    );
    _dashed(canvas, ringPath, dash, l.roadW * 0.45, l.roadW * 0.45);

    // Bay stalls.
    for (var i = 0; i < bayCount; i++) {
      paintStall(canvas, l, i);
    }

    // Bushes in the grass corners.
    _bush(canvas, Offset(4, h - 6), l.roadW * 0.6);
    _bush(canvas, Offset(w - 4, h - 6), l.roadW * 0.6);
  }

  void _tiles(Canvas canvas, Rect r) {
    final paint = Paint()
      ..color = JamPalette.plazaTile
      ..strokeWidth = 1;
    final step = math.max(18.0, layout.riderSpacing * 0.9);
    for (var y = r.top + step; y < r.bottom; y += step) {
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), paint);
    }
    var row = 0;
    for (var y = r.top; y < r.bottom; y += step) {
      final off = row.isEven ? 0.0 : step / 2;
      for (var x = r.left + off; x < r.right; x += step) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x, math.min(r.bottom, y + step)),
          paint,
        );
      }
      row++;
    }
  }

  void _lotMarkings(Canvas canvas) {
    final l = layout;
    final c = l.cell;
    final g = l.gridRect;
    final mark = Paint()
      ..color = const Color(0x2EFFFFFF)
      ..strokeWidth = math.max(1.2, c * 0.04)
      ..strokeCap = StrokeCap.round;
    final t = c * 0.12;
    for (var i = 0; i <= l.columns; i++) {
      for (var j = 0; j <= l.rows; j++) {
        final p = Offset(g.left + i * c, g.top + j * c);
        canvas.drawLine(p - Offset(t, 0), p + Offset(t, 0), mark);
        canvas.drawLine(p - Offset(0, t), p + Offset(0, t), mark);
      }
    }
  }

  void _grassTufts(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = JamPalette.grassDark.withValues(alpha: 0.5)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final rnd = math.Random(7);
    for (var i = 0; i < 60; i++) {
      final p = Offset(
        rnd.nextDouble() * size.width,
        layout.streetTop + rnd.nextDouble() * (size.height - layout.streetTop),
      );
      canvas.drawLine(p, p + const Offset(-2, -4), paint);
      canvas.drawLine(p, p + const Offset(2, -4), paint);
    }
  }

  void _bush(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(
      c + Offset(r * 0.1, r * 0.25),
      r,
      Paint()..color = const Color(0x33000000),
    );
    canvas.drawCircle(c, r, Paint()..color = JamPalette.bush);
    canvas.drawCircle(
      c + Offset(-r * 0.3, -r * 0.3),
      r * 0.5,
      Paint()..color = JamPalette.bushLight,
    );
  }

  static void _dashed(
    Canvas canvas,
    Path path,
    Paint paint,
    double on,
    double off,
  ) {
    for (final metric in path.computeMetrics()) {
      var d = off / 2;
      while (d < metric.length) {
        canvas.drawPath(
          metric.extractPath(d, math.min(metric.length, d + on)),
          paint,
        );
        d += on + off;
      }
    }
  }

  @override
  bool shouldRepaint(JamBoardPainter old) =>
      old.layout != layout || old.bayCount != bayCount;
}
