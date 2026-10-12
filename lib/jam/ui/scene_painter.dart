// Per-frame painter: lot buses, the crowd, bay buses, walking riders and
// pointer effects, all evaluated from the choreographer at the clock time.
//
// Buses, grounded riders, the "+N" chip and the tutorial hand are drawn from
// a [SpriteCache] (rasterised once, then placed with a transform), so a
// frame costs a few dozen textured quads on the raster thread rather than
// every sprite's paths, gradients and blurred shadows.
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../jam_model.dart';
import 'bay_painter.dart';
import 'bus_painter.dart';
import 'jam_choreographer.dart';
import 'jam_layout.dart';
import 'jam_sprites.dart';
import 'jam_theme.dart';
import 'sprite_cache.dart';

class JamScenePainter extends CustomPainter {
  JamScenePainter({
    required this.chor,
    required this.layout,
    required this.state,
    required this.clock,
    required this.sprites,
    required this.devicePixelRatio,
    this.tutorialTarget,
    this.tutorialStart = 0,
  }) : super(repaint: clock);

  final JamChoreographer chor;
  final JamLayout layout;
  final JamState state;
  final ValueListenable<double> clock;
  final String? tutorialTarget;
  final double tutorialStart;
  final SpriteCache sprites;
  final double devicePixelRatio;

  static const double handBobTime = 3.6;

  /// Number of scene paints so far; lets tests and benchmarks check that
  /// nothing repaints while the scene is idle.
  static int paintCount = 0;

  // Bay buses split by whether they move at the clock time (reused).
  final List<BusSprite> _resting = [];
  final List<BusSprite> _moving = [];

  @override
  void paint(Canvas canvas, Size size) {
    paintCount++;
    final t = clock.value;
    final level = chor.level;
    final dpr = devicePixelRatio;

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
      drawCachedBus(
        sprites,
        canvas,
        dpr,
        pose,
        v.color,
        BusLook(flash: chor.flashAt(v.id, t), glow: glow),
        length: v.length,
      );
    }

    _paintQueue(canvas, t);

    // Bay buses: resting ones first, moving ones on top.
    _resting.clear();
    _moving.clear();
    for (final s in chor.sprites) {
      if (t >= s.goneAt) continue;
      (s.isMovingAt(t) ? _moving : _resting).add(s);
    }
    for (final group in [_resting, _moving]) {
      for (final s in group) {
        // Bay buses are few and change every frame (motion, boarding
        // bounce, seat count), so they are painted directly.
        final seats = t >= s.arriveAt - 0.12;
        paintBus(
          canvas,
          s.poseAt(t),
          s.vehicle.color,
          BusLook(
            seatsFilled: seats ? s.loadedAt(t) : null,
            capacity: seats ? s.vehicle.capacity : null,
            squash: s.bumpAt(t),
            pop: s.popAt(t),
          ),
        );
      }
    }

    // Sparkle bursts over freshly filled buses (they stay put while the
    // burst plays, so it is drawn at the parked pose). Bus order does not
    // matter here, so walk both groups.
    for (final group in [_resting, _moving]) {
      for (final s in group) {
        final k = s.sparkleAt(t);
        if (k == null) continue;
        paintSparkles(canvas, s.parked, k, s.vehicle.color, s.slot + 1);
      }
    }

    // Walking riders.
    for (final w in chor.walks) {
      if (t < w.start || t >= w.end) continue;
      final (pos, lift, scale, opacity) = chor.walkPose(w, t);
      drawCachedRider(
        sprites,
        canvas,
        dpr,
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
      final tip = pose.center + Offset(pose.width * 0.3, pose.width * 0.55);
      final cell = layout.cell;
      final u = cell.clamp(30.0, 52.0);
      drawCachedStatic(
        sprites,
        canvas,
        dpr,
        SpriteKey('hand', a: (u * 64).round(), dpr: (dpr * 100).round()),
        Rect.fromLTRB(-u, -u * 0.6, u * 1.2, u * 1.5),
        tip - Offset(0, bob * u * 0.28),
        (c) => paintPointerHand(c, Offset.zero, cell, 0),
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
    // Subtle bob on the front rider while the scene is alive; it fades to
    // rest exactly when the clock stops.
    final live = chor.liveliness(t);
    final visible = <(int, double)>[];
    for (var i = first; i < passengers.length; i++) {
      final u = i - front;
      if (u >= limit) break;
      visible.add((i, u));
    }
    // Back of the queue first so the front row overlaps the rows behind.
    for (final (i, u) in visible.reversed) {
      final fadeIn = (limit - u).clamp(0.0, 1.0);
      final front = (1 - u.abs()).clamp(0.0, 1.0);
      final bob = live * front * (math.sin(t * math.pi * 2 / 0.7)).abs();
      drawCachedRider(
        sprites,
        canvas,
        devicePixelRatio,
        layout.queuePoint(u),
        s,
        passengers[i],
        i,
        opacity: fadeIn,
        scale: 0.85 + 0.15 * fadeIn,
        lift: bob * s * 0.1,
      );
    }
    if (hasMore) {
      final shown = visible.length;
      final rest = waiting - shown;
      if (rest > 0) {
        drawCachedMoreChip(
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
      old.sprites != sprites ||
      old.devicePixelRatio != devicePixelRatio ||
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
