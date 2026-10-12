// Frame-performance benchmark (profile mode, real device or emulator).
//
//   flutter drive --profile --driver=test_driver/integration_test.dart \
//     --target=integration_test/perf_test.dart -d <device>
//
// Plays scripted solver paths on the tutorial, a dense mid level and the
// densest level (rapid taps so several buses drive and many riders board at
// once), then sits idle. Each phase is traced (timeline summaries land in
// build/perf/timeline_<phase>.timeline_summary.json) and its FrameTimings are
// summarised into build/perf/frame_stats.json.
//
// Idle check: the live test binding keeps scheduling engine frames once any
// frame has been drawn, so raw frame counts are not meaningful while idle.
// Instead each phase reports `animation_frames` (frames after which a
// ticker still wanted another frame) and `scene_paints` (repaints of the
// play scene); both must be zero while idle. On the device, the absence of
// EGL `app_time_stats` lines in logcat confirms the app renders nothing.
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:ui';

import 'package:busster/jam/jam_level_codec.dart';
import 'package:busster/jam/jam_solver.dart';
import 'package:busster/jam/ui/jam_game_screen.dart';
import 'package:busster/jam/ui/scene_painter.dart';
import 'package:busster/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Collects FrameTimings and framework frame counts per phase.
class FrameRecorder {
  FrameRecorder() {
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    SchedulerBinding.instance.addPersistentFrameCallback((_) {
      if (!_active) return;
      frames++;
      // Transient callbacks re-registered during this frame (tickers) mean
      // the app itself asked for the next frame.
      if (SchedulerBinding.instance.transientCallbackCount > 0) {
        animationFrames++;
      }
    });
  }

  final List<FrameTiming> _timings = [];
  bool _active = false;
  int _startUs = 0;
  int _endUs = 0;
  int frames = 0;
  int animationFrames = 0;
  int _paintsAtStart = 0;

  /// Scene repaints since [start].
  int get scenePaints => JamScenePainter.paintCount - _paintsAtStart;

  void _onTimings(List<FrameTiming> timings) => _timings.addAll(timings);

  void start() {
    _timings.clear();
    frames = 0;
    animationFrames = 0;
    _paintsAtStart = JamScenePainter.paintCount;
    _active = true;
    _startUs = developer.Timeline.now;
    _endUs = 1 << 62;
  }

  /// Stops counting; timings arrive in batches, so wait for stragglers.
  Future<List<FrameTiming>> stop() async {
    _active = false;
    _endUs = developer.Timeline.now;
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    return [
      for (final t in _timings)
        if (t.timestampInMicroseconds(FramePhase.vsyncStart) >= _startUs &&
            t.timestampInMicroseconds(FramePhase.vsyncStart) <= _endUs)
          t,
    ];
  }
}

Map<String, Object> summarise(
  List<FrameTiming> timings,
  FrameRecorder recorder,
) {
  double ms(Duration d) => d.inMicroseconds / 1000;
  Map<String, double> stats(List<double> xs) {
    if (xs.isEmpty) return const {};
    final s = [...xs]..sort();
    double pct(double p) => s[math.min(s.length - 1, (s.length * p).floor())];
    final rest = xs.length > 1 ? (xs.sublist(1)..sort()) : s;
    return {
      'avg': xs.reduce((a, b) => a + b) / xs.length,
      'p50': pct(0.5),
      'p90': pct(0.9),
      'p99': pct(0.99),
      'worst': s.last,
      'worst_excl_first': rest.last,
    };
  }

  final build = [for (final t in timings) ms(t.buildDuration)];
  // Delivered frame rate and dropped frames from vsync-to-vsync gaps.
  final starts = [
    for (final t in timings) t.timestampInMicroseconds(FramePhase.vsyncStart),
  ]..sort();
  var dropped = 0;
  for (var i = 1; i < starts.length; i++) {
    final gap = (starts[i] - starts[i - 1]) / 1000;
    if (gap > 1.5 * 1000 / 60 && gap < 250) {
      dropped += (gap / (1000 / 60)).round() - 1;
    }
  }
  final spanS = starts.length > 1 ? (starts.last - starts.first) / 1e6 : 0.0;
  final raster = [for (final t in timings) ms(t.rasterDuration)];
  const budget = 1000 / 60;
  return {
    'frames': timings.length,
    'span_s': spanS,
    'fps': spanS > 0 ? (timings.length - 1) / spanS : 0,
    'dropped_frames': dropped,
    'framework_frames': recorder.frames,
    'animation_frames': recorder.animationFrames,
    'scene_paints': recorder.scenePaints,
    'build_ms': stats(build),
    'raster_ms': stats(raster),
    'missed_build': build.where((x) => x > budget).length,
    'missed_raster': raster.where((x) => x > budget).length,
  };
}

Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('frame performance', (tester) async {
    final levels = JamLevelCodec.decodeBundle(
      await rootBundle.loadString('assets/levels/jam_levels.json'),
    );
    final recorder = FrameRecorder();
    final report = <String, Object>{};

    JamGameScreenState screen() =>
        tester.state<JamGameScreenState>(find.byType(JamGameScreen));

    Future<void> open(int index) async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: JamGameScreen(
            key: ValueKey('perf-$index'),
            levels: levels,
            initialLevelIndex: index,
          ),
        ),
      );
      await wait(1500);
    }

    Future<void> settle() async {
      for (var i = 0; i < 200 && screen().isAnimating; i++) {
        await wait(50);
      }
    }

    Future<void> play(
      int index,
      int stepMs, {
      int? moves,
      required String phase,
    }) async {
      final level = levels[index];
      final path = (solveJam(level) as Solvable).path;
      final from = screen().session.state.moveCount;
      final todo = path.skip(from).take(moves ?? path.length).toList();
      final cache = screen().spriteCache;
      final misses0 = cache.misses;
      final hits0 = cache.hits;
      recorder.start();
      await binding.traceAction(
        () async {
          for (final id in todo) {
            await tester.tap(
              find.byKey(ValueKey('jam-bus-$id')),
              warnIfMissed: false,
            );
            await wait(stepMs);
          }
          await settle();
          await wait(600);
        },
        streams: const ['Dart', 'Embedder', 'GC'],
        reportKey: 'timeline_$phase',
      );
      final timings = await recorder.stop();
      report[phase] = {
        ...summarise(timings, recorder),
        'sprite_misses': cache.misses - misses0,
        'sprite_hits': cache.hits - hits0,
        'sprite_entries': cache.length,
        'sprite_mb': cache.bytes / (1 << 20),
      };
      debugPrint('PERF $phase ${report[phase]}');
    }

    // 1. Tutorial level, relaxed pace (hand bob, bubble, a few buses).
    await open(0);
    await play(0, 900, phase: 'tutorial');

    // 2. Dense level 12: a few moves, then idle (screenshot point), then
    //    the rest of the solution at a brisk pace.
    await open(11);
    await play(11, 400, moves: 4, phase: 'level12_opening');
    await wait(1500);
    debugPrint('PERF_IDLE_BEGIN');
    recorder.start();
    await wait(3000);
    final idle = await recorder.stop();
    debugPrint('PERF_IDLE_END');
    report['idle'] = summarise(idle, recorder);
    debugPrint('PERF idle ${report['idle']}');
    await play(11, 300, phase: 'level12');

    // 3. Densest level, rapid taps: many buses on the move at once.
    final densest = levels.indexWhere((l) => l.id == 'level-027');
    await open(densest);
    await play(densest, 150, phase: 'densest_rapid');

    binding.reportData ??= <String, dynamic>{};
    binding.reportData!['frame_stats'] = report;
  });
}
