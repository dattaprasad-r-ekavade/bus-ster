import 'dart:ui' as ui;

import 'package:busster/jam/ui/sprite_cache.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

SpriteKey key(int a, {String kind = 'bus', int dpr = 200}) =>
    SpriteKey(kind, a: a, dpr: dpr);

const box = Rect.fromLTRB(-10, -5, 10, 5);

void main() {
  group('SpriteKey', () {
    test('equal fields give equal keys and hashes', () {
      const a = SpriteKey('bus', a: 1, b: 2, c: 3, d: 4, e: 5, f: 6, dpr: 263);
      const b = SpriteKey('bus', a: 1, b: 2, c: 3, d: 4, e: 5, f: 6, dpr: 263);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('every field takes part in equality', () {
      const base = SpriteKey('bus', dpr: 100);
      final variants = [
        const SpriteKey('rider', dpr: 100),
        const SpriteKey('bus', a: 1, dpr: 100),
        const SpriteKey('bus', b: 1, dpr: 100),
        const SpriteKey('bus', c: 1, dpr: 100),
        const SpriteKey('bus', d: 1, dpr: 100),
        const SpriteKey('bus', e: 1, dpr: 100),
        const SpriteKey('bus', f: 1, dpr: 100),
        const SpriteKey('bus', dpr: 200),
      ];
      for (final v in variants) {
        expect(v, isNot(base), reason: '$v');
      }
      expect(variants.toSet(), hasLength(variants.length));
    });
  });

  group('SpriteCache', () {
    test('paints a sprite once and serves later requests from cache', () {
      final cache = SpriteCache();
      addTearDown(cache.clear);
      var painted = 0;
      void paint(Canvas c) {
        painted++;
        c.drawRect(box, Paint()..color = const Color(0xFFFF0000));
      }

      final first = cache.obtain(key(1), box, 2, paint);
      final second = cache.obtain(key(1), box, 2, paint);
      expect(identical(first, second), isTrue);
      expect(painted, 1);
      expect(cache.misses, 1);
      expect(cache.hits, 1);

      cache.obtain(key(1, dpr: 300), box, 3, paint);
      expect(painted, 2, reason: 'device pixel ratio is part of the key');
    });

    test('rasterises at device resolution with pixel-snapped bounds', () {
      final cache = SpriteCache();
      addTearDown(cache.clear);
      final sprite = cache.obtain(
        key(1),
        const Rect.fromLTRB(-10.2, -5.1, 10.2, 5.1),
        2,
        (_) {},
      );
      // -20.4 .. 20.4 device px snaps outwards to -21 .. 21.
      expect(sprite.image.width, 42);
      expect(sprite.image.height, 22);
      expect(sprite.bounds, const Rect.fromLTRB(-10.5, -5.5, 10.5, 5.5));
      expect(sprite.bytes, 42 * 22 * 4);
      expect(cache.bytes, sprite.bytes);
    });

    test('evicts the least recently used sprite past the entry cap', () {
      final cache = SpriteCache(maxEntries: 3);
      addTearDown(cache.clear);
      final a = cache.obtain(key(1), box, 1, (_) {});
      cache.obtain(key(2), box, 1, (_) {});
      cache.obtain(key(3), box, 1, (_) {});
      // Touch 1 so 2 becomes the oldest.
      cache.obtain(key(1), box, 1, (_) {});
      cache.obtain(key(4), box, 1, (_) {});

      expect(cache.length, 3);
      expect(cache.evictions, 1);
      expect(cache.containsKey(key(1)), isTrue);
      expect(cache.containsKey(key(2)), isFalse);
      expect(cache.keys, [key(3), key(1), key(4)]);
      expect(a.image.debugDisposed, isFalse);
    });

    test('keeps memory under the byte budget and frees evicted images', () {
      // Each 20x10 sprite at 1x is 800 bytes; the budget fits two.
      final cache = SpriteCache(maxBytes: 1700);
      addTearDown(cache.clear);
      final sprites = [
        for (var i = 0; i < 6; i++) cache.obtain(key(i), box, 1, (_) {}),
      ];
      expect(cache.length, 2);
      expect(cache.bytes, lessThanOrEqualTo(1700));
      expect(cache.evictions, 4);
      for (var i = 0; i < 4; i++) {
        expect(sprites[i].image.debugDisposed, isTrue, reason: 'sprite $i');
      }
      expect(sprites[4].image.debugDisposed, isFalse);
      expect(sprites[5].image.debugDisposed, isFalse);
    });

    test('memory stays bounded under heavy churn', () {
      final cache = SpriteCache(maxEntries: 16, maxBytes: 10000);
      addTearDown(cache.clear);
      for (var i = 0; i < 500; i++) {
        cache.obtain(key(i), box, 1, (_) {});
        expect(cache.length, lessThanOrEqualTo(16));
        expect(cache.bytes, lessThanOrEqualTo(10000));
      }
    });

    test('a single sprite larger than the budget is still served', () {
      final cache = SpriteCache(maxBytes: 10);
      addTearDown(cache.clear);
      final s = cache.obtain(key(1), box, 1, (_) {});
      expect(cache.length, 1);
      expect(s.image.debugDisposed, isFalse);
    });

    test('clear frees every image', () {
      final cache = SpriteCache();
      final sprites = [
        for (var i = 0; i < 3; i++) cache.obtain(key(i), box, 1, (_) {}),
      ];
      cache.clear();
      expect(cache.length, 0);
      expect(cache.bytes, 0);
      expect(sprites.every((s) => s.image.debugDisposed), isTrue);
    });

    test('uses the injected rasteriser', () {
      final sizes = <(int, int)>[];
      final cache = SpriteCache(
        rasterizer: (ui.Picture p, int w, int h) {
          sizes.add((w, h));
          return p.toImageSync(w, h);
        },
      );
      addTearDown(cache.clear);
      cache.obtain(key(1), box, 3, (_) {});
      expect(sizes, [(60, 30)]);
    });
  });
}
