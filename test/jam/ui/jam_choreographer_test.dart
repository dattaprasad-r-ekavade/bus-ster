import 'dart:io';
import 'dart:ui';

import 'package:busster/jam/jam_level_codec.dart';
import 'package:busster/jam/jam_model.dart';
import 'package:busster/jam/ui/jam_choreographer.dart';
import 'package:busster/jam/ui/jam_layout.dart';
import 'package:flutter_test/flutter_test.dart';

final List<JamLevel> levels = JamLevelCodec.decodeBundle(
  File('assets/levels/jam_levels.json').readAsStringSync(),
);

/// A rider's body is about one queue slot wide; walking riders must keep
/// at least this many widths between them.
const double minRiderGap = 1.1;

/// First tap of [level] from its start that boards at least [minBoards]
/// riders, or null when no such tap exists.
JamMoveResult? firstBoardingTap(JamLevel level, {int minBoards = 3}) {
  final session = JamSession(level);
  for (final id in session.rules.legalTaps(session.state)) {
    final result = session.rules.tap(session.initialState, id);
    final boards = result.events.whereType<JamBoard>().length;
    if (result.moved && boards >= minBoards) return result;
  }
  return null;
}

void main() {
  const size = Size(412, 790);

  for (final level in levels) {
    final tap = firstBoardingTap(level);
    if (tap == null) continue;

    test('${level.id}: walking riders keep spacing and boarding settles', () {
      final layout = JamLayout.compute(size, level);
      final chor = JamChoreographer(level: level, layout: layout)
        ..snap(JamSession(level).state)
        ..play(tap.events, 0);

      final walks = chor.walks;
      expect(walks.length, greaterThanOrEqualTo(3));
      final minDist = minRiderGap * layout.riderSpacing;

      // Sample the boarding window and check every pair of walking riders.
      final firstStart = walks
          .map((w) => w.start)
          .reduce((a, b) => a < b ? a : b);
      final lastEnd = walks.map((w) => w.end).reduce((a, b) => a > b ? a : b);
      var worst = double.infinity;
      for (var t = firstStart; t <= lastEnd; t += 1 / 240) {
        final active = [
          for (final w in walks)
            if (t >= w.start && t <= w.end) w,
        ];
        for (var i = 0; i < active.length; i++) {
          for (var j = i + 1; j < active.length; j++) {
            final a = chor.walkPose(active[i], t).$1;
            final b = chor.walkPose(active[j], t).$1;
            final d = (a - b).distance;
            if (d < worst) worst = d;
            expect(
              d,
              greaterThanOrEqualTo(minDist),
              reason:
                  'riders ${active[i].index} and ${active[j].index} at t=$t '
                  'are ${d.toStringAsFixed(1)} px apart (min $minDist)',
            );
          }
        }
      }

      // Seat-fill follows arrival: every seat dot fills no earlier than its
      // rider's walk end.
      for (final sprite in chor.sprites) {
        final mine = [
          for (final w in walks)
            if (w.bus == sprite) w,
        ];
        expect(
          sprite.boardArrivals.toList()..sort(),
          mine.map((w) => w.end).toList()..sort(),
        );
        if (mine.isEmpty) continue;
        // A bus boards no slower than about 2 s from its first rider.
        final span =
            mine.map((w) => w.end).reduce((a, b) => a > b ? a : b) -
            mine.map((w) => w.start).reduce((a, b) => a < b ? a : b);
        expect(span, lessThanOrEqualTo(2.0));
      }

      // The choreographer goes idle in finite time.
      expect(chor.endTime.isFinite, isTrue);
      var t = 0.0;
      while (chor.busyAt(t) && t < 60) {
        t += 1 / 60;
      }
      expect(chor.busyAt(t), isFalse);
      expect(t, lessThan(60));
      expect(chor.animatingAt(t + JamChoreographer.lurchTime + 1), isFalse);
    });
  }
}
