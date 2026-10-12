// Chunky passenger figures and the serpentine queue they stand in.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../jam_model.dart';
import 'jam_layout.dart';
import 'jam_theme.dart';

/// Paints one rider whose feet are at [feet]; [s] is the slot spacing.
/// [variant] picks skin / hair tones deterministically.
void paintRider(
  Canvas canvas,
  Offset feet,
  double s,
  JamColor color,
  int variant, {
  double opacity = 1,
  double scale = 1,
  double lift = 0,
}) {
  if (opacity <= 0 || scale <= 0) return;
  final shade = JamPalette.of(color);
  final k = s * scale;
  final bodyW = k * 0.6;
  final bodyH = k * 0.5;
  final headR = k * 0.2;

  final alpha = opacity.clamp(0.0, 1.0);
  final stroke = math.max(1.0, k * 0.05);
  final ink = Color.lerp(
    shade.dark,
    const Color(0xFF000000),
    0.3,
  )!.withValues(alpha: alpha);

  // Ground shadow stays on the ground while the rider hops: a soft core
  // inside a fainter skirt, nudged toward the bottom-right like the buses.
  final shadowC = feet + Offset(k * 0.03, 0);
  final shrink = 1 - (lift / k).clamp(0.0, 0.5) * 0.4;
  canvas.drawOval(
    Rect.fromCenter(
      center: shadowC,
      width: bodyW * 1.15 * shrink,
      height: k * 0.2 * shrink,
    ),
    Paint()..color = Color.fromRGBO(0, 0, 0, 0.1 * alpha),
  );
  canvas.drawOval(
    Rect.fromCenter(
      center: shadowC,
      width: bodyW * 0.9 * shrink,
      height: k * 0.13 * shrink,
    ),
    Paint()..color = Color.fromRGBO(0, 0, 0, 0.16 * alpha),
  );

  final base = feet - Offset(0, lift);
  final bodyRect = Rect.fromLTWH(
    base.dx - bodyW / 2,
    base.dy - bodyH - k * 0.02,
    bodyW,
    bodyH,
  );
  final body = RRect.fromRectAndCorners(
    bodyRect,
    topLeft: Radius.circular(bodyW * 0.48),
    topRight: Radius.circular(bodyW * 0.48),
    bottomLeft: Radius.circular(bodyW * 0.22),
    bottomRight: Radius.circular(bodyW * 0.22),
  );
  canvas.drawRRect(
    body,
    Paint()
      ..shader = ui.Gradient.radial(
        bodyRect.topLeft + Offset(bodyW * 0.32, bodyH * 0.28),
        bodyH * 1.25,
        [
          shade.light.withValues(alpha: alpha),
          shade.base.withValues(alpha: alpha),
          shade.dark.withValues(alpha: alpha),
        ],
        const [0.0, 0.5, 1.0],
      ),
  );
  if (k >= 14) {
    // Soft shoulder highlight.
    canvas.drawOval(
      Rect.fromCenter(
        center: bodyRect.topLeft + Offset(bodyW * 0.3, bodyH * 0.24),
        width: bodyW * 0.26,
        height: bodyH * 0.16,
      ),
      Paint()..color = Color.fromRGBO(255, 255, 255, 0.45 * alpha),
    );
  }
  canvas.drawRRect(
    body.deflate(stroke / 2),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = ink,
  );
  // Symbol on the chest.
  if (k >= 12) {
    final symC = Offset(base.dx, bodyRect.top + bodyH * 0.56);
    paintJamSymbol(
      canvas,
      JamPalette.symbolOf(color),
      symC,
      k * 0.12,
      Color.fromRGBO(255, 255, 255, alpha),
    );
  }

  // Head.
  final headC = Offset(base.dx, bodyRect.top - headR * 0.72);
  final skin = JamPalette.skin[variant % JamPalette.skin.length];
  final hair =
      JamPalette.hair[(variant ~/ 4 + variant) % JamPalette.hair.length];
  final skinLight = Color.lerp(skin, const Color(0xFFFFFFFF), 0.3)!;
  canvas.drawCircle(
    headC,
    headR,
    Paint()
      ..shader = ui.Gradient.radial(
        headC + Offset(-headR * 0.3, -headR * 0.1),
        headR * 1.3,
        [skinLight.withValues(alpha: alpha), skin.withValues(alpha: alpha)],
      ),
  );
  // Hair cap.
  canvas.drawArc(
    Rect.fromCircle(center: headC, radius: headR),
    math.pi * 1.05,
    math.pi * 0.9,
    true,
    Paint()..color = hair.withValues(alpha: alpha),
  );
  if (k >= 14) {
    canvas.drawArc(
      Rect.fromCircle(center: headC, radius: headR * 0.7),
      math.pi * 1.2,
      math.pi * 0.3,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = headR * 0.16
        ..color = Color.fromRGBO(255, 255, 255, 0.3 * alpha),
    );
  }
  final headStroke = math.max(0.9, k * 0.04);
  canvas.drawCircle(
    headC,
    headR - headStroke / 2,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = headStroke
      ..color = Color.fromRGBO(70, 42, 28, 0.6 * alpha),
  );
  if (k >= 18) {
    final eye = Paint()..color = Color.fromRGBO(40, 30, 30, alpha);
    canvas.drawCircle(
      headC + Offset(-headR * 0.36, headR * 0.14),
      k * 0.024,
      eye,
    );
    canvas.drawCircle(
      headC + Offset(headR * 0.36, headR * 0.14),
      k * 0.024,
      eye,
    );
  }
}

/// Draws the queue barriers (posts + ropes) between serpentine rows.
void paintQueueBarriers(Canvas canvas, JamLayout layout) {
  final pts = layout.queuePoints;
  final s = layout.riderSpacing;
  final rope = Paint()
    ..color = const Color(0xFFD9534F)
    ..strokeWidth = math.max(1.5, s * 0.07)
    ..strokeCap = StrokeCap.round;
  final post = Paint()..color = const Color(0xFF8D96A8);
  final postTop = Paint()..color = const Color(0xFFE2E7EF);
  // Rows are pts[0..1], pts[2..3], ... ; a barrier runs between each pair of
  // adjacent rows, leaving the turn-around end open.
  final rowsY = <double>[];
  for (var i = 0; i < pts.length; i += 2) {
    rowsY.add(pts[i].dy);
  }
  final xl = layout.queuePoints.map((p) => p.dx).reduce(math.min);
  final xr = layout.queuePoints.map((p) => p.dx).reduce(math.max);
  for (var k = 0; k + 1 < rowsY.length; k++) {
    // Between the upper row's feet and the lower row's heads.
    final y = rowsY[k + 1] + s * 0.06;
    // Row k turns up at the right when k is even.
    final openRight = k.isEven;
    final x0 = openRight ? xl - s * 0.2 : xl + s * 0.75;
    final x1 = openRight ? xr - s * 0.75 : xr + s * 0.2;
    canvas.drawLine(Offset(x0, y), Offset(x1, y), rope);
    final posts = math.max(2, ((x1 - x0) / (s * 3.2)).round());
    for (var i = 0; i <= posts; i++) {
      final x = x0 + (x1 - x0) * i / posts;
      canvas.drawCircle(Offset(x, y + s * 0.04), s * 0.1, post);
      canvas.drawCircle(Offset(x, y), s * 0.07, postTop);
    }
  }
}

/// "+N" chip for riders beyond the visible queue.
void paintMoreChip(Canvas canvas, Offset at, double s, int count) {
  final tp = TextPainter(
    text: TextSpan(
      text: '+$count',
      style: TextStyle(
        color: const Color(0xFFFFFFFF),
        fontSize: math.max(10, s * 0.38),
        fontWeight: FontWeight.w900,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final rect = Rect.fromCenter(
    center: at,
    width: tp.width + s * 0.42,
    height: tp.height + s * 0.12,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      rect.shift(const Offset(0, 2)),
      Radius.circular(rect.height / 2),
    ),
    Paint()..color = const Color(0x33000000),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)),
    Paint()..color = JamPalette.hud,
  );
  tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
}
