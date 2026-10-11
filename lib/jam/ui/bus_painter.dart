// Top-down chunky toy bus, drawn entirely with canvas primitives.
//
// Local frame: nose points to +x, the body is centred on the origin. Front
// and back read from the windshield + headlights (front) and the red tail
// lights (back); the symbol badge on the roof is counter-rotated so it is
// always upright.
import 'dart:math' as math;

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

final Paint _shadowPaint = Paint()..color = const Color(0x47000000);

void paintBus(Canvas canvas, BusPose pose, JamColor color, BusLook look) {
  final shade = JamPalette.of(color);
  final grow = 1 + look.pop;
  final l = pose.length * (1 + look.squash * 0.6) * grow;
  final w = pose.width * (1 + look.squash) * grow;
  final halfL = l / 2;
  final halfW = w / 2;

  // Glow halo (screen space, behind everything).
  if (look.glow > 0) {
    canvas.save();
    canvas.translate(pose.center.dx, pose.center.dy);
    canvas.rotate(pose.angle);
    final halo = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset.zero,
        width: l + w * 0.55,
        height: w * 1.55,
      ),
      Radius.circular(w * 0.6),
    );
    canvas.drawRRect(
      halo,
      Paint()
        ..color = const Color(0xFFFFE066).withValues(alpha: 0.75 * look.glow)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.22),
    );
    canvas.restore();
  }

  // Soft drop shadow, offset in screen space (light from the top-left).
  canvas.save();
  canvas.translate(pose.center.dx + w * 0.07, pose.center.dy + w * 0.16);
  canvas.rotate(pose.angle);
  _shadowPaint.maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.11);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: l * 0.98, height: w * 0.96),
      Radius.circular(w * 0.3),
    ),
    _shadowPaint,
  );
  canvas.restore();

  canvas.save();
  canvas.translate(pose.center.dx, pose.center.dy);
  canvas.rotate(pose.angle);

  // Wheels peeking out from under the body.
  final wheelPaint = Paint()..color = const Color(0xFF22252E);
  final axles = l > w * 3.6 ? [-0.36, 0.0, 0.34] : [-0.3, 0.3];
  for (final ax in axles) {
    final cx = ax * l;
    for (final sy in [-1.0, 1.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx, sy * (halfW - w * 0.02)),
            width: math.min(w * 0.42, l * 0.16),
            height: w * 0.2,
          ),
          Radius.circular(w * 0.07),
        ),
        wheelPaint,
      );
    }
  }

  // Body.
  final bodyRect = Rect.fromCenter(center: Offset.zero, width: l, height: w);
  final body = RRect.fromRectAndCorners(
    bodyRect,
    topLeft: Radius.circular(w * 0.26),
    bottomLeft: Radius.circular(w * 0.26),
    topRight: Radius.circular(w * 0.38),
    bottomRight: Radius.circular(w * 0.38),
  );
  canvas.drawRRect(
    body,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [shade.light, shade.base, shade.base, shade.dark],
        stops: const [0.0, 0.28, 0.7, 1.0],
      ).createShader(bodyRect),
  );
  // Front bumper band.
  canvas.save();
  canvas.clipRRect(body);
  canvas.drawRect(
    Rect.fromLTRB(halfL - w * 0.08, -halfW, halfL, halfW),
    Paint()..color = shade.dark.withValues(alpha: 0.55),
  );
  canvas.drawRect(
    Rect.fromLTRB(-halfL, -halfW, -halfL + w * 0.06, halfW),
    Paint()..color = shade.dark.withValues(alpha: 0.6),
  );
  canvas.restore();

  // Roof panel (darker), behind the windshield.
  final roofLeft = -halfL + w * 0.14;
  final roofRight = halfL - w * 0.44;
  final roofHalfW = halfW - w * 0.19;
  final roofRect = Rect.fromLTRB(roofLeft, -roofHalfW, roofRight, roofHalfW);
  final roof = RRect.fromRectAndRadius(roofRect, Radius.circular(w * 0.16));

  // Side window strips between the roof edge and the body edge.
  final paneCount = math.max(2, ((roofRight - roofLeft) / (w * 0.62)).floor());
  final paneGap = w * 0.09;
  final paneW = (roofRight - roofLeft - paneGap * (paneCount - 1)) / paneCount;
  final paneT = w * 0.13;
  final panePaint = Paint()..color = JamPalette.windshield;
  for (final sy in [-1.0, 1.0]) {
    for (var i = 0; i < paneCount; i++) {
      final x0 = roofLeft + i * (paneW + paneGap);
      final y0 = sy < 0 ? -roofHalfW - paneT - w * 0.02 : roofHalfW + w * 0.02;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x0, y0, paneW, paneT),
          Radius.circular(w * 0.04),
        ),
        panePaint,
      );
    }
  }

  canvas.drawRRect(roof, Paint()..color = shade.roof);
  // Roof gloss.
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTRB(
        roofLeft + w * 0.08,
        -roofHalfW + w * 0.05,
        roofRight - w * 0.08,
        -roofHalfW + w * 0.13,
      ),
      Radius.circular(w * 0.05),
    ),
    Paint()..color = const Color(0x40FFFFFF),
  );

  // Windshield at the nose.
  final wsRect = Rect.fromLTRB(
    halfL - w * 0.4,
    -halfW + w * 0.12,
    halfL - w * 0.12,
    halfW - w * 0.12,
  );
  canvas.drawRRect(
    RRect.fromRectAndCorners(
      wsRect,
      topLeft: Radius.circular(w * 0.07),
      bottomLeft: Radius.circular(w * 0.07),
      topRight: Radius.circular(w * 0.2),
      bottomRight: Radius.circular(w * 0.2),
    ),
    Paint()
      ..shader = const LinearGradient(
        colors: [JamPalette.windshieldDeep, JamPalette.windshield],
      ).createShader(wsRect),
  );
  // Windshield glint.
  canvas.drawLine(
    Offset(wsRect.left + w * 0.08, wsRect.top + w * 0.1),
    Offset(wsRect.left + w * 0.16, wsRect.top + w * 0.3),
    Paint()
      ..color = const Color(0xCCFFFFFF)
      ..strokeWidth = w * 0.05
      ..strokeCap = StrokeCap.round,
  );

  // Headlights and tail lights.
  final headPaint = Paint()..color = JamPalette.headlight;
  final headR = w * 0.085;
  for (final sy in [-1.0, 1.0]) {
    canvas.drawCircle(
      Offset(halfL - w * 0.06, sy * w * 0.31),
      headR,
      headPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(-halfL + w * 0.035, sy * w * 0.3),
          width: w * 0.07,
          height: w * 0.18,
        ),
        Radius.circular(w * 0.03),
      ),
      Paint()..color = JamPalette.taillight,
    );
  }

  // Outline.
  canvas.drawRRect(
    body,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, w * 0.05)
      ..color = shade.dark,
  );

  final symbol = JamPalette.symbolOf(color);
  final cap = look.capacity;
  if (look.seatsFilled != null && cap != null) {
    _paintSeats(canvas, roofRect, w, look.seatsFilled!, cap, shade);
    // Small badge on the tail end of the roof.
    final badgeC = Offset(roofLeft + w * 0.26, 0);
    _paintBadge(canvas, badgeC, w * 0.22, symbol, shade, pose.angle);
  } else {
    final roofLen = roofRight - roofLeft;
    final r = math.min(roofHalfW * 0.95, roofLen * 0.42);
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
