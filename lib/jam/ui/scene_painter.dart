// Per-frame painter: lot buses, the crowd, bay buses, walking riders and
// pointer effects, all evaluated from the choreographer at the clock time.
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../jam_model.dart';
import 'bay_painter.dart';
import 'bus_painter.dart';
import 'crowd_painter.dart';
import 'jam_choreographer.dart';
import 'jam_layout.dart';
import 'jam_theme.dart';

class JamScenePainter extends CustomPainter {
  JamScenePainter({
    required this.chor,
    required this.layout,
    required this.state,
    required this.clock,
    this.tutorialTarget,
    this.tutorialStart = 0,
  }) : super(repaint: clock);

  final JamChoreographer chor;
  final JamLayout layout;
  final JamState state;
  final ValueListenable<double> clock;
  final String? tutorialTarget;
  final double tutorialStart;

  static const double handBobTime = 3.6;

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value;
    final level = chor.level;

    for (var i = 0; i < level.bayCount; i++) {
      paintStallPulse(
        canvas,
        layout,
        i,
        chor.stallPulseAt(i, t),
        const Color(0xFFFF5A5A),
      );
    }

    // Lot buses (rules truth).
    for (final v in level.vehicles) {
      if (!state.remaining.contains(v.id)) continue;
      var pose = layout.lotPose(v);
      final lurch = chor.lurchAt(v.id, t);
      if (lurch != 0) {
        pose = pose.copyWith(
          center: pose.center + JamLayout.directionOf(v.facing) * lurch,
        );
      }
      final glow = math.max(
        chor.hintGlowAt(v.id, t),
        tutorialTarget == v.id ? 0.55 : 0.0,
      );
      paintBus(
        canvas,
        pose,
        v.color,
        BusLook(flash: chor.flashAt(v.id, t), glow: glow),
      );
    }

    _paintQueue(canvas, t);

    // Bay buses: resting ones first, moving ones on top.
    final active = chor.sprites.where((s) => t < s.goneAt).toList();
    for (final moving in [false, true]) {
      for (final s in active) {
        if (s.isMovingAt(t) != moving) continue;
        final seats = t >= s.arriveAt - 0.12;
        paintBus(
          canvas,
          s.poseAt(t),
          s.vehicle.color,
          BusLook(
            seatsFilled: seats ? s.loadedAt(t) : null,
            capacity: seats ? s.vehicle.capacity : null,
            squash: s.bumpAt(t),
          ),
        );
      }
    }

    // Walking riders.
    for (final w in chor.walks) {
      if (t < w.start || t >= w.end) continue;
      final (pos, lift, scale, opacity) = chor.walkPose(w, t);
      paintRider(
        canvas,
        pos,
        layout.riderSpacing,
        w.color,
        w.index,
        lift: lift,
        scale: scale,
        opacity: opacity,
      );
    }

    final target = tutorialTarget;
    if (target != null &&
        level.hasVehicle(target) &&
        state.remaining.contains(target)) {
      final pose = layout.lotPose(level.vehicle(target));
      final d = t - tutorialStart;
      final bob = d >= 0 && d < handBobTime
          ? (math.sin(d * math.pi * 2 / 0.9)).abs()
          : 0.0;
      paintPointerHand(
        canvas,
        pose.center + Offset(pose.width * 0.3, pose.width * 0.55),
        layout.cell,
        bob,
      );
    }
  }

  void _paintQueue(Canvas canvas, double t) {
    final passengers = chor.level.passengers;
    final first = chor.firstQueuedAt(t);
    final waiting = passengers.length - first;
    if (waiting <= 0) return;
    final cap = layout.queueCapacity;
    final hasMore = waiting > cap;
    final limit = hasMore ? cap - 1 : cap;
    final front = chor.frontAt(t);
    final s = layout.riderSpacing;
    final visible = <(int, double)>[];
    for (var i = first; i < passengers.length; i++) {
      final u = i - front;
      if (u >= limit) break;
      visible.add((i, u));
    }
    // Back of the queue first so the front row overlaps the rows behind.
    for (final (i, u) in visible.reversed) {
      final fadeIn = (limit - u).clamp(0.0, 1.0);
      paintRider(
        canvas,
        layout.queuePoint(u),
        s,
        passengers[i],
        i,
        opacity: fadeIn,
        scale: 0.85 + 0.15 * fadeIn,
      );
    }
    if (hasMore) {
      final shown = visible.length;
      final rest = waiting - shown;
      if (rest > 0) {
        paintMoreChip(
          canvas,
          layout.queuePoint(limit.toDouble() + 0.15) - Offset(0, s * 0.4),
          s,
          rest,
        );
      }
    }
  }

  @override
  bool shouldRepaint(JamScenePainter old) =>
      old.chor != chor ||
      old.layout != layout ||
      old.state != state ||
      old.tutorialTarget != tutorialTarget ||
      old.tutorialStart != tutorialStart;
}

/// Cartoon pointing glove whose fingertip touches [tip].
void paintPointerHand(Canvas canvas, Offset tip, double cell, double bob) {
  final u = cell.clamp(30.0, 52.0);
  canvas.save();
  canvas.translate(tip.dx + u * 0.08, tip.dy - u * 0.05 - bob * u * 0.28);
  canvas.rotate(-0.35);
  final fill = Paint()..color = const Color(0xFFFFFFFF);
  final line = Paint()
    ..color = JamPalette.hud
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(1.8, u * 0.06)
    ..strokeJoin = StrokeJoin.round;
  final shadow = Paint()..color = const Color(0x40000000);
  final finger = RRect.fromRectAndRadius(
    Rect.fromLTWH(-u * 0.12, 0, u * 0.24, u * 0.62),
    Radius.circular(u * 0.12),
  );
  final palm = RRect.fromRectAndRadius(
    Rect.fromLTWH(-u * 0.16, u * 0.42, u * 0.58, u * 0.5),
    Radius.circular(u * 0.18),
  );
  final thumb = RRect.fromRectAndRadius(
    Rect.fromLTWH(-u * 0.32, u * 0.5, u * 0.26, u * 0.16),
    Radius.circular(u * 0.08),
  );
  final cuff = RRect.fromRectAndRadius(
    Rect.fromLTWH(-u * 0.12, u * 0.88, u * 0.5, u * 0.16),
    Radius.circular(u * 0.05),
  );
  for (final r in [finger, palm, thumb, cuff]) {
    canvas.drawRRect(r.shift(Offset(u * 0.05, u * 0.06)), shadow);
  }
  for (final r in [palm, thumb, finger]) {
    canvas.drawRRect(r, fill);
    canvas.drawRRect(r, line);
  }
  canvas.drawRRect(cuff, Paint()..color = JamPalette.accent);
  canvas.drawRRect(cuff, line);
  // Knuckle hints.
  for (var i = 1; i <= 2; i++) {
    final x = -u * 0.16 + u * 0.58 * i / 3 + u * 0.05;
    canvas.drawLine(
      Offset(x, u * 0.48),
      Offset(x, u * 0.6),
      Paint()
        ..color = JamPalette.hud.withValues(alpha: 0.5)
        ..strokeWidth = math.max(1.2, u * 0.035)
        ..strokeCap = StrokeCap.round,
    );
  }
  canvas.restore();
}
