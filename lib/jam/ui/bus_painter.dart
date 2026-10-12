// Top-down chunky toy bus, drawn entirely with canvas primitives.
//
// Local frame: nose points to +x, the body is centred on the origin. Front
// and back read from the windshield + headlights (front) and the red tail
// lights (back); the symbol badge on the roof is counter-rotated so it is
// always upright.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../jam_model.dart';
import 'jam_motion.dart';
import 'jam_theme.dart';

class BusLook {
  const BusLook({
    this.seatsFilled,
    this.capacity,
    this.flash = 0,
    this.glow = 0,
    this.squash = 0,
    this.dim = 0,
    this.pop = 0,
  });

  /// When non-null the roof shows a seat grid instead of a big badge.
  final int? seatsFilled;
  final int? capacity;

  /// 0..1 white flash (blocker feedback).
  final double flash;

  /// 0..1 golden halo (hint / tutorial target).
  final double glow;

  /// Boarding bounce; positive grows the body slightly.
  final double squash;

  /// 0..1 darkening (unused buses while a modal is up, etc.).
  final double dim;

  /// Uniform scale bump (the "full!" pop); 0 = natural size.
  final double pop;
}

/// Screen-space light direction (from the top-left) shared by the shading,
/// so every bus is lit the same way whatever its heading.
const Offset _light = Offset(-0.45, -0.89);

/// Below this body width (logical px) the fine detail (window pillars,
/// specular strip, light glows) is dropped so small buses stay clean.
const double _detailWidth = 26;

/// [v] (screen space) expressed in a frame rotated by [angle].
Offset _toLocal(Offset v, double angle) {
  final c = math.cos(angle);
  final s = math.sin(angle);
  return Offset(v.dx * c + v.dy * s, -v.dx * s + v.dy * c);
}

/// Soft-edged fill built from a few stacked translucent layers: a cheap
/// stand-in for a blurred shadow (no mask filter).
void _softFill(
  Canvas canvas,
  RRect r,
  double spread,
  Color color, {
  int steps = 4,
}) {
  final paint = Paint()..color = color.withValues(alpha: color.a / steps);
  for (var i = 0; i < steps; i++) {
    final grow = spread * (1 - 2 * i / (steps - 1));
    canvas.drawRRect(r.inflate(grow), paint);
  }
}

/// Outline width: about 1/22 of the body width, kept between ~3 and ~6
/// device pixels on a typical phone.
double _strokeFor(double w) => (w * 0.045).clamp(1.1, 2.2);

void paintBus(Canvas canvas, BusPose pose, JamColor color, BusLook look) {
  final shade = JamPalette.of(color);
  final grow = 1 + look.pop;
  final l = pose.length * (1 + look.squash * 0.6) * grow;
  final w = pose.width * (1 + look.squash) * grow;
  final halfL = l / 2;
  final halfW = w / 2;
  final detailed = w >= _detailWidth;
  final light = _toLocal(_light, pose.angle);
  final outline = Color.lerp(shade.dark, const Color(0xFF000000), 0.28)!;

  final body = RRect.fromRectAndCorners(
    Rect.fromCenter(center: Offset.zero, width: l, height: w),
    topLeft: Radius.circular(w * 0.24),
    bottomLeft: Radius.circular(w * 0.24),
    topRight: Radius.circular(w * 0.36),
    bottomRight: Radius.circular(w * 0.36),
  );

  // Glow halo (hint / tutorial target), behind everything.
  if (look.glow > 0) {
    canvas.save();
    canvas.translate(pose.center.dx, pose.center.dy);
    canvas.rotate(pose.angle);
    _softFill(
      canvas,
      body.inflate(w * 0.2),
      w * 0.16,
      const Color(0xFFFFE066).withValues(alpha: 0.85 * look.glow),
      steps: 8,
    );
    canvas.restore();
  }

  // Soft contact shadow, offset toward the bottom-right in screen space.
  canvas.save();
  canvas.translate(pose.center.dx + w * 0.07, pose.center.dy + w * 0.13);
  canvas.rotate(pose.angle);
  _softFill(canvas, body.deflate(w * 0.02), w * 0.07, const Color(0x52000000));
  canvas.restore();

  canvas.save();
  canvas.translate(pose.center.dx, pose.center.dy);
  canvas.rotate(pose.angle);

  // Tyres tucked under the body: only a rounded sliver shows at the sides.
  final tyre = Paint()..color = JamPalette.tyre;
  final axles = l > w * 3.6 ? [-0.36, 0.0, 0.34] : [-0.3, 0.3];
  final tyreW = math.min(w * 0.36, l * 0.15);
  for (final ax in axles) {
    for (final sy in [-1.0, 1.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(ax * l, sy * (halfW - w * 0.075)),
            width: tyreW,
            height: w * 0.2,
          ),
          Radius.circular(w * 0.09),
        ),
        tyre,
      );
    }
  }

  // Body: lit from the screen's top-left.
  final reach = light.dx.abs() * halfL + light.dy.abs() * halfW;
  canvas.drawRRect(
    body,
    Paint()
      ..shader = ui.Gradient.linear(
        light * reach,
        light * -reach,
        [shade.light, shade.base, shade.base, shade.dark],
        const [0.0, 0.3, 0.62, 1.0],
      ),
  );

  canvas.save();
  canvas.clipRRect(body);
  // Bevel: a dark band on the side away from the light and a bright rim on
  // the lit side give the body some thickness.
  canvas.drawRRect(
    body.shift(light * (w * 0.06)),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.1
      ..color = shade.dark.withValues(alpha: 0.55),
  );
  canvas.drawRRect(
    body.shift(light * (-w * 0.045)),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.05
      ..color = shade.light.withValues(alpha: 0.75),
  );
  // Bumpers.
  final bumper = Paint()..color = outline.withValues(alpha: 0.35);
  canvas.drawRect(
    Rect.fromLTRB(halfL - w * 0.075, -halfW, halfL, halfW),
    bumper,
  );
  canvas.drawRect(
    Rect.fromLTRB(-halfL, -halfW, -halfL + w * 0.055, halfW),
    bumper,
  );

  // Side glass: one continuous rounded strip per side, thin pillars.
  final gx0 = -halfL + w * 0.15;
  final gx1 = halfL - w * 0.45;
  final gOut = halfW - w * 0.085;
  final gIn = halfW - w * 0.245;
  final gH = gOut - gIn;
  for (final sy in [-1.0, 1.0]) {
    final strip = Rect.fromLTRB(
      gx0,
      sy < 0 ? -gOut : gIn,
      gx1,
      sy < 0 ? -gIn : gOut,
    );
    final rr = RRect.fromRectAndRadius(strip, Radius.circular(gH * 0.45));
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, sy * gOut),
          Offset(0, sy * gIn),
          const [JamPalette.glassDeep, JamPalette.glassMid],
        ),
    );
    if (detailed) {
      canvas.save();
      canvas.clipRRect(rr);
      // Sky reflection along the inner edge.
      canvas.drawRect(
        Rect.fromLTRB(
          gx0,
          sy < 0 ? -gIn - gH * 0.38 : gIn,
          gx1,
          sy < 0 ? -gIn : gIn + gH * 0.38,
        ),
        Paint()..color = JamPalette.glassSky.withValues(alpha: 0.55),
      );
      final panes = math.max(2, ((gx1 - gx0) / (w * 0.95)).round());
      final pillar = Paint()..color = shade.base;
      for (var i = 1; i < panes; i++) {
        final x = gx0 + (gx1 - gx0) * i / panes;
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(x, sy * (gIn + gOut) / 2),
            width: w * 0.045,
            height: gH + 1,
          ),
          pillar,
        );
      }
      canvas.restore();
    }
  }

  // Roof panel with a soft top-light gradient.
  final roofLeft = -halfL + w * 0.11;
  final roofRight = halfL - w * 0.47;
  final roofHalfW = gIn - w * 0.03;
  final roofRect = Rect.fromLTRB(roofLeft, -roofHalfW, roofRight, roofHalfW);
  final roof = RRect.fromRectAndRadius(roofRect, Radius.circular(w * 0.12));
  final roofReach =
      light.dx.abs() * roofRect.width / 2 + light.dy.abs() * roofHalfW;
  canvas.drawRRect(
    roof,
    Paint()
      ..shader = ui.Gradient.linear(
        roofRect.center + light * roofReach,
        roofRect.center - light * roofReach,
        [Color.lerp(shade.light, shade.base, 0.35)!, shade.base, shade.roof],
        const [0.0, 0.45, 1.0],
      ),
  );
  if (detailed) {
    canvas.drawRRect(
      roof,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.022
        ..color = shade.dark.withValues(alpha: 0.35),
    );
    // Specular strip along the roof edge facing the light.
    final side = light.dy < 0 ? -1.0 : 1.0;
    final y = side * (roofHalfW - w * 0.08);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset((roofLeft + roofRight) / 2 + light.dx * w * 0.1, y),
          width: math.max(0, roofRect.width - w * 0.3),
          height: w * 0.06,
        ),
        Radius.circular(w * 0.03),
      ),
      Paint()..color = const Color(0x66FFFFFF),
    );
  }

  // Windshield at the nose, with a reflection streak.
  final wsRect = Rect.fromLTRB(
    halfL - w * 0.4,
    -halfW + w * 0.1,
    halfL - w * 0.15,
    halfW - w * 0.1,
  );
  final ws = RRect.fromRectAndCorners(
    wsRect,
    topLeft: Radius.circular(w * 0.06),
    bottomLeft: Radius.circular(w * 0.06),
    topRight: Radius.circular(w * 0.2),
    bottomRight: Radius.circular(w * 0.2),
  );
  canvas.drawRRect(
    ws,
    Paint()
      ..shader = ui.Gradient.linear(
        wsRect.centerLeft,
        wsRect.centerRight,
        const [JamPalette.glassMid, JamPalette.glassDeep],
      ),
  );
  canvas.save();
  canvas.clipRRect(ws);
  final wl = wsRect.left;
  final ww = wsRect.width;
  canvas.drawPath(
    Path()
      ..moveTo(wl + ww * 0.42, wsRect.top)
      ..lineTo(wl + ww * 0.78, wsRect.top)
      ..lineTo(wl + ww * 0.3, wsRect.bottom)
      ..lineTo(wl - ww * 0.06, wsRect.bottom)
      ..close(),
    Paint()..color = const Color(0x55FFFFFF),
  );
  if (detailed) {
    canvas.drawPath(
      Path()
        ..moveTo(wl + ww * 0.9, wsRect.top)
        ..lineTo(wl + ww * 1.02, wsRect.top)
        ..lineTo(wl + ww * 0.54, wsRect.bottom)
        ..lineTo(wl + ww * 0.42, wsRect.bottom)
        ..close(),
      Paint()..color = const Color(0x33FFFFFF),
    );
  }
  canvas.restore();

  // Head and tail lights, inset inside the outline.
  final stroke = _strokeFor(w);
  final headPaint = Paint()..color = JamPalette.headlight;
  final tailPaint = Paint()..color = JamPalette.taillight;
  for (final sy in [-1.0, 1.0]) {
    final hc = Offset(halfL - stroke - w * 0.045, sy * w * 0.29);
    final tc = Offset(-halfL + stroke + w * 0.035, sy * w * 0.29);
    if (detailed) {
      canvas.drawCircle(
        hc,
        w * 0.14,
        Paint()
          ..shader = ui.Gradient.radial(hc, w * 0.14, [
            JamPalette.headlight.withValues(alpha: 0.7),
            JamPalette.headlight.withValues(alpha: 0),
          ]),
      );
      canvas.drawCircle(
        tc,
        w * 0.11,
        Paint()
          ..shader = ui.Gradient.radial(tc, w * 0.11, [
            JamPalette.taillight.withValues(alpha: 0.55),
            JamPalette.taillight.withValues(alpha: 0),
          ]),
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: hc, width: w * 0.07, height: w * 0.16),
        Radius.circular(w * 0.035),
      ),
      headPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: tc, width: w * 0.05, height: w * 0.13),
        Radius.circular(w * 0.025),
      ),
      tailPaint,
    );
  }
  canvas.restore(); // body clip

  // One continuous outline around the whole silhouette.
  canvas.drawRRect(
    body.deflate(stroke / 2),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = outline,
  );

  final symbol = JamPalette.symbolOf(color);
  final cap = look.capacity;
  final seatRect = Rect.fromLTRB(roofLeft, -w * 0.31, roofRight, w * 0.31);
  if (look.seatsFilled != null && cap != null) {
    _paintSeats(canvas, seatRect, w, look.seatsFilled!, cap, shade);
    // Small badge on the tail end of the roof.
    final badgeC = Offset(roofLeft + w * 0.26, 0);
    _paintBadge(canvas, badgeC, w * 0.22, symbol, shade, pose.angle);
  } else {
    final roofLen = roofRight - roofLeft;
    final r = math.min(w * 0.3, roofLen * 0.42);
    _paintBadge(
      canvas,
      Offset((roofLeft + roofRight) / 2, 0),
      r,
      symbol,
      shade,
      pose.angle,
    );
  }

  if (look.flash > 0) {
    canvas.drawRRect(
      body,
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: look.flash),
    );
  }
  if (look.dim > 0) {
    canvas.drawRRect(
      body,
      Paint()..color = const Color(0xFF000000).withValues(alpha: look.dim),
    );
  }
  canvas.restore();
}

void _paintBadge(
  Canvas canvas,
  Offset c,
  double r,
  JamSymbol symbol,
  JamShade shade,
  double angle,
) {
  canvas.drawCircle(
    c + Offset(0, r * 0.08),
    r * 1.04,
    Paint()..color = const Color(0x33000000),
  );
  canvas.drawCircle(c, r, Paint()..color = const Color(0xFFFFFFFF));
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(-angle);
  paintJamSymbol(
    canvas,
    symbol,
    Offset.zero,
    r * 0.58,
    shade.base,
    outline: shade.dark,
  );
  canvas.restore();
}

void _paintSeats(
  Canvas canvas,
  Rect roof,
  double w,
  int filled,
  int capacity,
  JamShade shade,
) {
  final rows = (capacity / 2).ceil();
  // Seats occupy the front part of the roof; the badge sits at the tail.
  final left = roof.left + w * 0.5;
  final right = roof.right - w * 0.04;
  final span = math.max(w * 0.2, right - left);
  final pitch = span / rows;
  final r = math.min(pitch * 0.36, w * 0.13);
  final empty = Paint()..color = const Color(0x55000000);
  final full = Paint()..color = const Color(0xFFFFFFFF);
  final rim = Paint()
    ..color = shade.dark
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(0.7, r * 0.3);
  var k = 0;
  // Fill from the nose backwards, alternating sides.
  for (var row = rows - 1; row >= 0; row--) {
    for (final sy in [-1.0, 1.0]) {
      if (k >= capacity) break;
      final c = Offset(left + pitch * (row + 0.5), sy * roof.height * 0.26);
      if (k < filled) {
        canvas.drawCircle(c, r * 1.12, full);
        canvas.drawCircle(c, r * 1.12, rim);
      } else {
        canvas.drawCircle(c, r * 0.8, empty);
      }
      k++;
    }
  }
}

/// Burst of little four-point stars flying out of a bus that just filled.
/// [progress] runs 0..1; the pattern is fixed per [seed].
void paintSparkles(
  Canvas canvas,
  BusPose pose,
  double progress,
  JamColor color,
  int seed,
) {
  if (progress <= 0 || progress >= 1) return;
  final shade = JamPalette.of(color);
  final ease = 1 - math.pow(1 - progress, 3).toDouble();
  final fade = progress < 0.6 ? 1.0 : 1 - (progress - 0.6) / 0.4;
  // Stars fly out on an ellipse that wraps the bus body (local frame:
  // x along the nose, y across), from just inside the outline outwards.
  final rx = pose.length * 0.5 + pose.width * (0.15 + 0.55 * ease);
  final ry = pose.width * (0.45 + 0.7 * ease);
  final ca = math.cos(pose.angle);
  final sa = math.sin(pose.angle);
  const count = 9;
  for (var i = 0; i < count; i++) {
    final jitter = ((seed * 7 + i * 13) % 17) / 17.0;
    final a = (i / count) * math.pi * 2 + jitter * 0.5;
    final lx = math.cos(a) * rx;
    final ly = math.sin(a) * ry;
    final c = pose.center + Offset(lx * ca - ly * sa, lx * sa + ly * ca);
    final r = pose.width * (0.27 + 0.13 * jitter) * (1 - progress * 0.55);
    final colour = i.isEven ? const Color(0xFFFFF3A0) : shade.light;
    _star(
      canvas,
      c,
      r,
      colour.withValues(alpha: fade),
      shade.dark.withValues(alpha: fade * 0.85),
      progress * 2 + i,
    );
  }
  // Soft ring flash right at the start.
  if (progress < 0.4) {
    final k = progress / 0.4;
    canvas.save();
    canvas.translate(pose.center.dx, pose.center.dy);
    canvas.rotate(pose.angle);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: pose.length * (1.05 + 0.35 * k),
          height: pose.width * (1.1 + 0.6 * k),
        ),
        Radius.circular(pose.width * 0.6),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, pose.width * 0.12 * (1 - k))
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.8 * (1 - k)),
    );
    canvas.restore();
  }
}

void _star(
  Canvas canvas,
  Offset c,
  double r,
  Color color,
  Color outline,
  double spin,
) {
  final path = Path();
  for (var i = 0; i < 8; i++) {
    final rr = i.isEven ? r : r * 0.32;
    final a = spin * 0.6 + i * math.pi / 4;
    final p = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  path.close();
  canvas.drawPath(path, Paint()..color = color);
  canvas.drawPath(
    path,
    Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, r * 0.16)
      ..strokeJoin = StrokeJoin.round,
  );
}
