// Bay stalls: painted parking slots that open onto the street.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'jam_layout.dart';
import 'jam_theme.dart';

/// Static stall art for bay [slot].
void paintStall(Canvas canvas, JamLayout layout, int slot) {
  final r = layout.stallRect(slot);
  final radius = Radius.circular(math.min(10, r.width * 0.2));
  final floor = RRect.fromRectAndCorners(r, topLeft: radius, topRight: radius);
  // Sunken bay: a warm rim on the plaza, a darker floor that lightens
  // toward the street, and a soft inner shadow under the top lip.
  canvas.drawRRect(floor.inflate(1.5), Paint()..color = JamPalette.plazaEdge);
  canvas.drawRRect(
    floor,
    Paint()
      ..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter, const [
        JamPalette.stallFloorDeep,
        JamPalette.stallFloor,
      ]),
  );
  canvas.save();
  canvas.clipRRect(floor);
  canvas.drawDRRect(
    floor.inflate(8),
    floor.shift(const Offset(0, 2.5)).deflate(0.5),
    Paint()..color = const Color(0x30000000),
  );
  canvas.restore();

  final lw = math.max(1.6, layout.parkedW * 0.075);
  final line = Paint()
    ..color = const Color(0xF2FFFFFF)
    ..strokeWidth = lw
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final inset = lw * 1.5;
  // U-shaped stall lines with a gate in the top edge: riders walk in
  // through the gate, never across a line.
  final gate = layout.gateWidth / 2;
  final cx = r.center.dx;
  final top = r.top + inset;
  final corner = math.max(radius.x - inset * 0.6, lw);
  final u = Path()
    ..moveTo(r.left + inset, r.bottom - lw)
    ..lineTo(r.left + inset, top + corner)
    ..arcToPoint(
      Offset(r.left + inset + corner, top),
      radius: Radius.circular(corner),
    )
    ..lineTo(cx - gate, top)
    ..moveTo(cx + gate, top)
    ..lineTo(r.right - inset - corner, top)
    ..arcToPoint(
      Offset(r.right - inset, top + corner),
      radius: Radius.circular(corner),
    )
    ..lineTo(r.right - inset, r.bottom - lw);
  canvas.drawPath(u, line);

  // Gate bollards: little yellow posts with a dark rim and a highlight.
  final postR = lw * 1.05;
  for (final x in [cx - gate, cx + gate]) {
    final c = Offset(x, top);
    canvas.drawCircle(
      c + Offset(postR * 0.25, postR * 0.45),
      postR * 1.1,
      Paint()..color = const Color(0x40000000),
    );
    canvas.drawCircle(c, postR * 1.12, Paint()..color = JamPalette.accentDark);
    canvas.drawCircle(c, postR * 0.86, Paint()..color = JamPalette.accent);
    canvas.drawCircle(
      c - Offset(postR * 0.3, postR * 0.3),
      postR * 0.3,
      Paint()..color = const Color(0xB3FFFFFF),
    );
  }

  // Rounded entry arrow painted on the floor, pointing into the bay.
  final cy = r.bottom - layout.parkedW * 0.42;
  final aw = math.min(r.width * 0.2, layout.parkedW * 0.28);
  final head = Path()
    ..moveTo(cx, cy - aw * 0.75)
    ..lineTo(cx + aw, cy + aw * 0.2)
    ..lineTo(cx + aw * 0.38, cy + aw * 0.2)
    ..lineTo(cx + aw * 0.38, cy + aw * 0.85)
    ..lineTo(cx - aw * 0.38, cy + aw * 0.85)
    ..lineTo(cx - aw * 0.38, cy + aw * 0.2)
    ..lineTo(cx - aw, cy + aw * 0.2)
    ..close();
  final arrowColor = JamPalette.roadDash.withValues(alpha: 0.78);
  canvas.drawPath(head, Paint()..color = arrowColor);
  canvas.drawPath(
    head,
    Paint()
      ..color = arrowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, aw * 0.22)
      ..strokeJoin = StrokeJoin.round,
  );
}

/// Pulsing outline over a stall (e.g. all bays full warning).
void paintStallPulse(
  Canvas canvas,
  JamLayout layout,
  int slot,
  double strength,
  Color color,
) {
  if (strength <= 0) return;
  final r = layout.stallRect(slot).deflate(1);
  canvas.drawRRect(
    RRect.fromRectAndRadius(r, const Radius.circular(8)),
    Paint()
      ..color = color.withValues(alpha: strength.clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3,
  );
}
