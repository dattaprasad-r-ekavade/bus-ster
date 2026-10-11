// Bay stalls: painted parking slots that open onto the street.
import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'jam_layout.dart';
import 'jam_theme.dart';

/// Static stall art for bay [slot].
void paintStall(Canvas canvas, JamLayout layout, int slot) {
  final r = layout.stallRect(slot);
  final radius = Radius.circular(math.min(10, r.width * 0.2));
  final floor = RRect.fromRectAndCorners(r, topLeft: radius, topRight: radius);
  // Inset shadow so the stall reads as a recessed bay.
  canvas.drawRRect(
    floor.shift(const Offset(0, -1.5)),
    Paint()..color = JamPalette.plazaEdge,
  );
  canvas.drawRRect(floor, Paint()..color = JamPalette.stallFloor);

  final line = Paint()
    ..color = const Color(0xE6FFFFFF)
    ..strokeWidth = math.max(1.6, layout.parkedW * 0.08)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final inset = line.strokeWidth * 1.4;
  final u = Path()
    ..moveTo(r.left + inset, r.bottom - 1)
    ..lineTo(r.left + inset, r.top + inset + radius.x * 0.4)
    ..quadraticBezierTo(
      r.left + inset,
      r.top + inset,
      r.left + inset + radius.x * 0.4,
      r.top + inset,
    )
    ..lineTo(r.right - inset - radius.x * 0.4, r.top + inset)
    ..quadraticBezierTo(
      r.right - inset,
      r.top + inset,
      r.right - inset,
      r.top + inset + radius.x * 0.4,
    )
    ..lineTo(r.right - inset, r.bottom - 1);
  canvas.drawPath(u, line);

  // Yellow entry chevron on the stall floor.
  final cx = r.center.dx;
  final cy = r.bottom - layout.parkedW * 0.35;
  final cw = math.min(r.width * 0.22, layout.parkedW * 0.32);
  final chevron = Paint()
    ..color = JamPalette.roadDash.withValues(alpha: 0.7)
    ..strokeWidth = math.max(1.5, cw * 0.28)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  canvas.drawPath(
    Path()
      ..moveTo(cx - cw, cy + cw * 0.5)
      ..lineTo(cx, cy - cw * 0.3)
      ..lineTo(cx + cw, cy + cw * 0.5),
    chevron,
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
