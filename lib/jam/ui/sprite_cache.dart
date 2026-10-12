// Bitmap sprite cache for the play scene.
//
// Each distinct sprite (a bus of one colour, size, heading and seat count, a
// rider of one colour and variant, ...) is recorded once with the regular
// painter into a ui.Picture and rasterised at device resolution into a
// ui.Image. Later frames draw that image with a transform, so the raster
// thread replays one textured quad instead of the painter's paths,
// gradients and blurred shadows. The cache does not know how a sprite is
// painted: whatever the painter draws (inside the declared bounds) is what
// gets cached.
//
// Memory is bounded: least-recently-used sprites are evicted (and their
// images disposed) once either the entry cap or the byte budget is
// exceeded.
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Identifies one rasterised sprite. All fields are integers so equal
/// requests hit exactly; callers quantise continuous values (size, angle)
/// before building a key.
@immutable
class SpriteKey {
  const SpriteKey(
    this.kind, {
    this.a = 0,
    this.b = 0,
    this.c = 0,
    this.d = 0,
    this.e = 0,
    this.f = 0,
    required this.dpr,
  });

  /// Sprite family, e.g. 'bus' or 'rider'.
  final String kind;

  /// Family-specific integer parameters (colour, size bucket, ...).
  final int a, b, c, d, e, f;

  /// Device pixel ratio in hundredths.
  final int dpr;

  @override
  bool operator ==(Object other) =>
      other is SpriteKey &&
      other.kind == kind &&
      other.a == a &&
      other.b == b &&
      other.c == c &&
      other.d == d &&
      other.e == e &&
      other.f == f &&
      other.dpr == dpr;

  @override
  int get hashCode => Object.hash(kind, a, b, c, d, e, f, dpr);

  @override
  String toString() => 'SpriteKey($kind,$a,$b,$c,$d,$e,$f@$dpr)';
}

/// A rasterised sprite: [image] covers [bounds] (logical pixels, relative
/// to the sprite's anchor) at the device pixel ratio it was made for.
class Sprite {
  Sprite(this.image, this.bounds);

  final ui.Image image;
  final Rect bounds;

  int get bytes => image.width * image.height * 4;

  late final Rect _src = Rect.fromLTWH(
    0,
    0,
    image.width.toDouble(),
    image.height.toDouble(),
  );

  /// Draws the sprite with its anchor at the canvas origin.
  void draw(Canvas canvas, Paint paint) =>
      canvas.drawImageRect(image, _src, bounds, paint);
}

/// Turns a recorded picture into an image of the given pixel size.
typedef SpriteRasterizer =
    ui.Image Function(ui.Picture picture, int width, int height);

ui.Image _toImageSync(ui.Picture picture, int width, int height) =>
    picture.toImageSync(width, height);

class SpriteCache {
  SpriteCache({
    this.maxEntries = 320,
    this.maxBytes = 32 << 20,
    SpriteRasterizer rasterizer = _toImageSync,
  }) : _rasterize = rasterizer;

  final int maxEntries;
  final int maxBytes;
  final SpriteRasterizer _rasterize;

  // Insertion order doubles as recency order: a hit is moved to the end.
  final LinkedHashMap<SpriteKey, Sprite> _sprites = LinkedHashMap();
  int _bytes = 0;

  int hits = 0;
  int misses = 0;
  int evictions = 0;

  int get length => _sprites.length;
  int get bytes => _bytes;
  bool containsKey(SpriteKey key) => _sprites.containsKey(key);
  Iterable<SpriteKey> get keys => _sprites.keys;

  /// Returns the sprite for [key], painting it with [paint] on a miss.
  ///
  /// [bounds] is the logical area (relative to the anchor at the origin)
  /// that [paint] draws into; it is snapped outwards to whole device
  /// pixels so sprites stay crisp.
  Sprite obtain(
    SpriteKey key,
    Rect bounds,
    double devicePixelRatio,
    void Function(Canvas canvas) paint,
  ) {
    final hit = _sprites.remove(key);
    if (hit != null) {
      _sprites[key] = hit;
      hits++;
      return hit;
    }
    misses++;
    final r = devicePixelRatio;
    final left = (bounds.left * r).floorToDouble();
    final top = (bounds.top * r).floorToDouble();
    final width = math.max(1, (bounds.right * r).ceil() - left.toInt());
    final height = math.max(1, (bounds.bottom * r).ceil() - top.toInt());
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..translate(-left, -top)
      ..scale(r);
    paint(canvas);
    final picture = recorder.endRecording();
    final image = _rasterize(picture, width, height);
    picture.dispose();
    final sprite = Sprite(
      image,
      Rect.fromLTWH(left / r, top / r, width / r, height / r),
    );
    _sprites[key] = sprite;
    _bytes += sprite.bytes;
    _evict();
    return sprite;
  }

  void _evict() {
    while (_sprites.length > 1 &&
        (_sprites.length > maxEntries || _bytes > maxBytes)) {
      final oldest = _sprites.keys.first;
      final sprite = _sprites.remove(oldest)!;
      _bytes -= sprite.bytes;
      sprite.image.dispose();
      evictions++;
    }
  }

  /// Drops every sprite and frees its image.
  void clear() {
    for (final s in _sprites.values) {
      s.image.dispose();
    }
    _sprites.clear();
    _bytes = 0;
  }
}
