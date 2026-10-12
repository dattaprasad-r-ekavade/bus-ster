// Cached drawing of the scene's repeated sprites (lot buses, grounded
// riders, the tutorial hand). Each helper builds a quantised [SpriteKey],
// lets the art painter draw the sprite once into the [SpriteCache], then
// places the bitmap with a transform. Pose parameters that only move or
// scale a sprite are applied as transforms; parameters that change its
// look become part of the key. The "+N" chip is kept as a recorded
// picture instead.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../jam_model.dart';
import 'bus_painter.dart';
import 'crowd_painter.dart';
import 'jam_motion.dart';
import 'sprite_cache.dart';

final Paint _spritePaint = Paint()..filterQuality = FilterQuality.low;
final Paint _alphaPaint = Paint()..filterQuality = FilterQuality.low;

int _dprKey(double dpr) => (dpr * 100).round();

/// Key for a logical size: quarter device pixels. Sprites are painted at
/// the exact size of the first request (painters may floor() on sizes,
/// e.g. a window count), and requests within a quarter pixel share it.
int _sizeKey(double v, double dpr) => (v * dpr * 4).round();

int _unitKey(double v) => (v.clamp(0.0, 1.0) * 20).round();

/// Draws [paintBus] output for a resting [pose] from the cache.
///
/// Meant for buses whose look rarely changes (the lot): heading, size,
/// seats and the quantised flash / glow / dim levels are part of the key;
/// squash and pop are applied as a scale. Buses on the move change heading
/// and size every frame and are cheaper to paint directly than to
/// rasterise anew.
void drawCachedBus(
  SpriteCache cache,
  Canvas canvas,
  double dpr,
  BusPose pose,
  JamColor color,
  BusLook look, {
  required int length,
}) {
  final glow = _unitKey(look.glow);
  final flash = _unitKey(look.flash);
  final dim = _unitKey(look.dim);
  final seats = look.seatsFilled ?? -1;
  final cap = look.capacity ?? -1;
  final key = SpriteKey(
    'bus',
    a: color.index * 16 + length,
    b: _sizeKey(pose.length, dpr),
    c: _sizeKey(pose.width, dpr),
    d: (pose.angle * 1000).round(),
    e: (glow * 32 + flash) * 32 + dim,
    f: seats * 64 + cap,
    dpr: _dprKey(dpr),
  );
  final angle = pose.angle;
  final l = pose.length;
  final w = pose.width;
  final ca = math.cos(angle).abs();
  final sa = math.sin(angle).abs();
  final hx = l / 2 * ca + w / 2 * sa;
  final hy = l / 2 * sa + w / 2 * ca;
  // Room for the soft shadow and outline beyond the body, plus the glow
  // halo when there is one. Pop and squash are applied as transforms.
  final pad = w * (glow > 0 ? 1.0 : 0.6) + 2;
  final sprite = cache.obtain(
    key,
    Rect.fromLTRB(-hx - pad, -hy - pad, hx + pad, hy + pad),
    dpr,
    (c) => paintBus(
      c,
      BusPose(center: Offset.zero, angle: angle, length: l, width: w),
      color,
      BusLook(
        seatsFilled: look.seatsFilled,
        capacity: look.capacity,
        glow: glow / 20,
        flash: flash / 20,
        dim: dim / 20,
      ),
    ),
  );
  final grow = 1 + look.pop;
  final sl = (1 + look.squash * 0.6) * grow;
  final sw = (1 + look.squash) * grow;
  canvas.save();
  if (sl == 1 && sw == 1) {
    // Snap to the device pixel grid so the bitmap maps 1:1.
    canvas.translate(
      (pose.center.dx * dpr).roundToDouble() / dpr,
      (pose.center.dy * dpr).roundToDouble() / dpr,
    );
  } else {
    canvas.translate(pose.center.dx, pose.center.dy);
    canvas.rotate(angle);
    canvas.scale(sl, sw);
    canvas.rotate(-angle);
  }
  sprite.draw(canvas, _spritePaint);
  canvas.restore();
}

/// Draws a grounded rider ([paintRider] with no lift) from the cache.
/// Riders in the air are painted directly: their shadow stays on the
/// ground while the body hops, which a single bitmap cannot express.
void drawCachedRider(
  SpriteCache cache,
  Canvas canvas,
  double dpr,
  Offset feet,
  double s,
  JamColor color,
  int variant, {
  double opacity = 1,
  double scale = 1,
  double lift = 0,
}) {
  if (opacity <= 0 || scale <= 0) return;
  if (lift.abs() > 0.05) {
    paintRider(
      canvas,
      feet,
      s,
      color,
      variant,
      opacity: opacity,
      scale: scale,
      lift: lift,
    );
    return;
  }
  final sprite = cache.obtain(
    SpriteKey(
      'rider',
      a: color.index,
      b: variant,
      c: _sizeKey(s, dpr),
      dpr: _dprKey(dpr),
    ),
    Rect.fromLTRB(-s * 0.8, -s * 1.25, s * 0.8, s * 0.4),
    dpr,
    (c) => paintRider(c, Offset.zero, s, color, variant),
  );
  canvas.save();
  if ((scale - 1).abs() < 1e-3) {
    canvas.translate(
      (feet.dx * dpr).roundToDouble() / dpr,
      (feet.dy * dpr).roundToDouble() / dpr,
    );
  } else {
    canvas.translate(feet.dx, feet.dy);
    canvas.scale(scale);
  }
  if (opacity >= 1) {
    sprite.draw(canvas, _spritePaint);
  } else {
    _alphaPaint.color = Color.fromRGBO(0, 0, 0, opacity);
    sprite.draw(canvas, _alphaPaint);
  }
  canvas.restore();
}

ui.Picture? _chipPicture;
(int, int)? _chipKey;

/// [paintMoreChip] replayed from a recorded picture. The count changes as
/// riders board, so the chip is kept as a display list (no text layout per
/// frame) rather than a bitmap (no rasterisation per count).
void drawCachedMoreChip(Canvas canvas, Offset at, double s, int count) {
  final key = (count, (s * 64).round());
  var picture = _chipPicture;
  if (picture == null || _chipKey != key) {
    final recorder = ui.PictureRecorder();
    paintMoreChip(Canvas(recorder), Offset.zero, s, count);
    picture?.dispose();
    picture = _chipPicture = recorder.endRecording();
    _chipKey = key;
  }
  canvas.save();
  canvas.translate(at.dx, at.dy);
  canvas.drawPicture(picture);
  canvas.restore();
}

/// Cached sprite of an arbitrary painter that draws around the origin
/// within [bounds]; drawn translated to [at].
void drawCachedStatic(
  SpriteCache cache,
  Canvas canvas,
  double dpr,
  SpriteKey key,
  Rect bounds,
  Offset at,
  void Function(Canvas canvas) paint,
) {
  final sprite = cache.obtain(key, bounds, dpr, paint);
  canvas.save();
  canvas.translate(at.dx, at.dy);
  sprite.draw(canvas, _spritePaint);
  canvas.restore();
}
