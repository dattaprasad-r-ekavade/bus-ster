import 'dart:io';
import 'dart:ui';

import 'package:busster/jam/jam_level_codec.dart';
import 'package:busster/jam/jam_model.dart';
import 'package:busster/jam/ui/jam_choreographer.dart';
import 'package:busster/jam/ui/jam_layout.dart';
import 'package:busster/jam/ui/jam_motion.dart';
import 'package:flutter_test/flutter_test.dart';

final List<JamLevel> levels = JamLevelCodec.decodeBundle(
  File('assets/levels/jam_levels.json').readAsStringSync(),
);

// Scene sizes below the HUD on a 412×915 phone and a 320×568 compact phone.
const sizes = [Size(412, 790), Size(320, 480)];

/// The four corners of a bus drawn at [pose] (nose along [BusPose.angle]).
List<Offset> _busCorners(BusPose pose) {
  final nose = pose.noseDirection;
  final side = Offset(-nose.dy, nose.dx);
  final a = nose * (pose.length / 2);
  final b = side * (pose.width / 2);
  return [
    pose.center + a + b,
    pose.center + a - b,
    pose.center - a + b,
    pose.center - a - b,
  ];
}

void main() {
  for (final size in sizes) {
    group('at $size', () {
      for (final level in levels) {
        test(level.id, () {
          final l = JamLayout.compute(size, level);
          if (Platform.environment['JAM_LAYOUT_DUMP'] != null) {
            final lotW = l.cell * JamLayout.lotWidthFactor;
            // ignore: avoid_print
            print(
              '${level.id} ${size.width.toInt()} cell=${l.cell} '
              'crowd=${l.crowdRect.height.toStringAsFixed(0)} '
              'bay=${l.bayRect.height.toStringAsFixed(0)} '
              'parked/lot=${(l.parkedW / lotW).toStringAsFixed(2)} '
              's=${l.riderSpacing} cap=${l.queueCapacity} '
              'spare=${(size.height - l.ringRect.bottom - l.roadW / 2).toStringAsFixed(0)} '
              'scenery=${l.scenery.length}',
            );
          }
          final scene = Offset.zero & size;
          // Everything fits on screen.
          expect(scene.contains(l.lotRect.topLeft), isTrue);
          expect(
            l.ringRect.bottom + l.roadW / 2,
            lessThanOrEqualTo(size.height),
          );
          expect(l.ringRect.left - l.roadW / 2, greaterThanOrEqualTo(0));
          expect(l.ringRect.right + l.roadW / 2, lessThanOrEqualTo(size.width));
          // The lot hugs the grid: no big empty asphalt band.
          expect(l.lotRect.height - l.gridRect.height, lessThan(l.cell * 0.5));
          expect(l.lotRect.width - l.gridRect.width, lessThan(l.cell * 0.5));
          expect(l.gridRect.center.dx, closeTo(size.width / 2, 0.5));
          // Cells are capped so small levels stay toy-sized.
          expect(l.cell, lessThanOrEqualTo(60));
          // Parked buses stay close to lot-bus width.
          final lotW = l.cell * JamLayout.lotWidthFactor;
          // (The compact screen trades a little of that for lot size.)
          expect(
            l.parkedW / lotW,
            greaterThanOrEqualTo(size.width >= 400 ? 0.75 : 0.68),
          );
          // Stalls are just deep enough for the longest bus in the level.
          final maxLen = level.vehicles
              .map((v) => v.length)
              .reduce((a, b) => a > b ? a : b);
          for (var slot = 0; slot < level.bayCount; slot++) {
            final stall = l.stallRect(slot);
            final bus = l.parkedPose(slot, maxLen);
            expect(bus.center.dy + bus.length / 2, lessThan(stall.bottom));
            expect(
              stall.bottom - (bus.center.dy + bus.length / 2),
              lessThan(12),
            );
            expect(stall.left, greaterThanOrEqualTo(0));
            expect(stall.right, lessThanOrEqualTo(size.width));
          }
          // The queue starts at the left end of the front row and is never
          // a lone mid-row start.
          final front = l.queuePoint(0);
          expect(front.dy, closeTo(l.queuePoints.first.dy, 1e-6));
          expect(
            front.dx,
            closeTo(
              l.queuePoints.map((p) => p.dx).reduce((a, b) => a < b ? a : b),
              1e-6,
            ),
          );
          expect(l.crowdRect.top, 0);
          final top = l.queuePoints
              .map((p) => p.dy)
              .reduce((a, b) => a < b ? a : b);
          expect(top - l.riderSpacing, greaterThan(-1));
          // Scenery stays on the grass.
          final road = l.ringRect.inflate(l.roadW / 2);
          for (final item in l.scenery) {
            expect(item.bounds.overlaps(road), isFalse, reason: '$item');
            expect(item.center.dy, greaterThan(l.streetTop + l.roadW));
          }
          // Compact screens: riders stay readable; extras go to the +N chip.
          if (size.width < 400) {
            expect(l.riderSpacing, greaterThanOrEqualTo(28));
          }
          // The whole ring road, kerb to outer edge, is on screen.
          final outer = l.ringRect.inflate(l.roadW / 2);
          expect(outer.left, greaterThanOrEqualTo(0));
          expect(outer.top, greaterThanOrEqualTo(0));
          expect(outer.right, lessThanOrEqualTo(size.width));
          expect(outer.bottom, lessThanOrEqualTo(size.height));
          // Every vehicle's park drive: once the bus is off the lot it is at
          // road-fit width and its whole box stays on screen.
          for (final v in level.vehicles) {
            for (var slot = 0; slot < level.bayCount; slot++) {
              final choreo = JamChoreographer(level: level, layout: l)
                ..play([JamPark(v.id, slot)], 0);
              final leg = choreo.sprites.single.parkLeg!;
              for (var i = 0; i <= 200; i++) {
                final t = leg.start + leg.duration * i / 200;
                final pose = leg.poseAt(t);
                if (l.lotRect.contains(pose.center)) continue;
                final where = '${v.id} slot $slot t=$t';
                expect(
                  pose.width,
                  lessThanOrEqualTo(0.9 * l.roadW),
                  reason: where,
                );
                for (final c in _busCorners(pose)) {
                  expect(
                    c.dx,
                    inInclusiveRange(-0.5, size.width + 0.5),
                    reason: where,
                  );
                  expect(
                    c.dy,
                    inInclusiveRange(-0.5, size.height + 0.5),
                    reason: where,
                  );
                }
              }
            }
          }
        });
      }
    });
  }

  test('rider route enters the stall through its gate', () {
    final level = levels.firstWhere((l) => l.id == 'level-012');
    final l = JamLayout.compute(sizes.first, level);
    for (var slot = 0; slot < level.bayCount; slot++) {
      final route = l.riderRoute(l.queuePoint(0), slot, 4);
      final stall = l.stallRect(slot);
      // Every point before the last two stays above the stall tops.
      for (final p in route.take(route.length - 1)) {
        expect(p.dy, lessThanOrEqualTo(stall.top));
      }
      // The last leg is vertical through the gate centre.
      final gate = route[route.length - 2];
      final door = route.last;
      expect(gate.dx, closeTo(door.dx, 1e-6));
      expect((door.dx - stall.center.dx).abs(), lessThan(l.gateWidth / 2));
    }
  });

  test('layout and scenery are deterministic', () {
    final a = JamLayout.compute(sizes.first, levels[5]);
    final b = JamLayout.compute(sizes.first, levels[5]);
    expect(
      a.scenery.map((s) => '${s.kind}${s.center}'),
      b.scenery.map((s) => '${s.kind}${s.center}'),
    );
    expect(a.queuePoints, b.queuePoints);
  });
}
