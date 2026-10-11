// Chunky passenger figures and the serpentine queue they stand in.
import 'dart:math' as math;

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

  // Ground shadow stays on the ground while the rider hops.
  canvas.drawOval(
    Rect.fromCenter(
      center: feet,
      width: bodyW * (1.05 - lift * 0.01),
      height: k * 0.16,
    ),
    Paint()..color = Color.fromRGBO(0, 0, 0, 0.22 * opacity),
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
    bottomLeft: Radius.circular(bodyW * 0.2),
    bottomRight: Radius.circular(bodyW * 0.2),
  );
  final alpha = opacity.clamp(0.0, 1.0);
  canvas.drawRRect(
    body,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          shade.light.withValues(alpha: alpha),
          shade.base.withValues(alpha: alpha),
          shade.dark.withValues(alpha: alpha),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(bodyRect),
  );
  canvas.drawRRect(
    body,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, k * 0.035)
      ..color = shade.dark.withValues(alpha: alpha),
  );
  // Symbol on the chest.
  if (k >= 12) {
    final symC = Offset(base.dx, bodyRect.top + bodyH * 0.55);
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
  canvas.drawCircle(
    headC,
    headR,
    Paint()..color = skin.withValues(alpha: alpha),
  );
  // Hair cap.
  canvas.drawArc(
    Rect.fromCircle(center: headC, radius: headR),
    math.pi * 1.05,
    math.pi * 0.9,
    true,
    Paint()..color = hair.withValues(alpha: alpha),
  );
  canvas.drawCircle(
    headC,
    headR,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, k * 0.025)
      ..color = Color.fromRGBO(60, 40, 30, 0.45 * alpha),
  );
  if (k >= 18) {
    final eye = Paint()..color = Color.fromRGBO(40, 30, 30, alpha);
    canvas.drawCircle(
      headC + Offset(-headR * 0.36, headR * 0.12),
      k * 0.022,
      eye,
    );
    canvas.drawCircle(
      headC + Offset(headR * 0.36, headR * 0.12),
      k * 0.022,
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
