// The play scene must cost nothing while nothing moves: no scheduled
// frames, no running ticker, no scene repaints. Also checks that the scene
// is served from the sprite cache once warm.
import 'package:busster/jam/jam_solver.dart';
import 'package:busster/jam/ui/scene_painter.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import 'jam_game_screen_test.dart'
    show levels, pumpScreen, screen, tapBus, indexOf;

Future<void> expectIdle(WidgetTester tester) async {
  final paints = JamScenePainter.paintCount;
  for (var i = 0; i < 5; i++) {
    expect(
      tester.binding.hasScheduledFrame,
      isFalse,
      reason: 'a frame is scheduled while idle',
    );
    expect(SchedulerBinding.instance.transientCallbackCount, 0);
    await tester.pump(const Duration(seconds: 1));
  }
  expect(JamScenePainter.paintCount, paints, reason: 'scene repainted');
}

void main() {
  testWidgets('no frames are scheduled once the scene is at rest', (
    tester,
  ) async {
    final index = indexOf('level-012');
    await pumpScreen(tester, index: index);
    await expectIdle(tester);

    // Play a few moves, let every animation finish, and check again.
    final path = (solveJam(levels[index]) as Solvable).path;
    for (final id in path.take(3)) {
      await tapBus(tester, id);
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(screen(tester).isAnimating, isTrue);
    await tester.pumpAndSettle();
    expect(screen(tester).isAnimating, isFalse);
    await expectIdle(tester);
  });

  testWidgets('tutorial hand stops animating after its bob', (tester) async {
    await pumpScreen(tester, index: 0);
    await expectIdle(tester);
  });

  testWidgets('a warm scene repaints from the sprite cache', (tester) async {
    await pumpScreen(tester, index: indexOf('level-027'));
    final cache = screen(tester).spriteCache;
    expect(cache.length, greaterThan(0));
    final misses = cache.misses;
    final path = (solveJam(levels[indexOf('level-027')]) as Solvable).path;
    // A blocked-free tap animates the scene: every lot bus and queued rider
    // repaints each frame, all from cached sprites.
    await tapBus(tester, path.first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(cache.misses - misses, lessThanOrEqualTo(2));
    expect(cache.hits, greaterThan(100));
    await tester.pumpAndSettle();
  });
}
