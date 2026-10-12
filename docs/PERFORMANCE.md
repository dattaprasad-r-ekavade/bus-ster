# Frame performance

How the play screen is measured, what was changed for 60 fps, and the
numbers before and after.

**All numbers below come from an Android emulator, not a phone**
(`Busster_QA_API35`, Android 15 / API 35, x86_64, 1080x2400 at 2.625 dpr,
host GPU passed through the emulator's GLES translator, Impeller on
OpenGL ES, Flutter 3.41.6, profile build). Use them to compare before with
after, not as phone figures. The metrics that do not depend on the device
are UI-thread build time, raster-thread work, frames painted while idle and
sprite-cache misses.

## How to re-run

```sh
flutter drive --profile --no-dds \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/perf_test.dart -d <device-id>
```

`--no-dds` is required: `traceAction` connects to the VM service from the
device, and that connection is refused when DDS sits in between.

Output goes to `build/perf/`:

- `frame_stats.json`: one entry per phase with FrameTiming build and
  raster stats (avg / p50 / p90 / p99 / worst, plus worst excluding the
  first frame), frames over the 16.7 ms budget, delivered fps, dropped
  frames (gaps between vsyncs), `animation_frames`, `scene_paints` and
  sprite-cache hits, misses and memory.
- `timeline_<phase>.timeline.json` and `.timeline_summary.json`: the
  traced timeline for each phase. The timeline buffer keeps roughly the
  last 300 frames of a phase.

The scripted phases (in `integration_test/perf_test.dart`):

| Phase | What happens |
|---|---|
| `tutorial` | Level 1 solved one tap every 0.9 s, with the hand, bubble and win confetti |
| `level12_opening` | Level 12, first 4 solver moves, one tap every 0.4 s |
| `idle` | 3 s with nothing animating (the emulator screenshot is taken here) |
| `level12` | Rest of level 12, one tap every 0.3 s |
| `densest_rapid` | Level 27 (19 buses, the most riders), one tap every 0.15 s, so several buses drive and many riders board at once |

### Checking for idle frames

The live test binding keeps asking for engine frames once one frame has
been drawn, so raw frame counts mean nothing in the `idle` phase. The test
counts these instead:

- `animation_frames`: frames after which a ticker still wanted another
  frame;
- `scene_paints`: repaints of the play scene.

Both must be 0 while idle. On the device itself, check that logcat stops
printing EGL `app_time_stats` lines once the scene is at rest. These lines
appear about once a second while frames are being drawn:

```sh
adb logcat -c; sleep 6; adb logcat -d | grep -c app_time_stats   # 0 at rest
```

The test `test/jam/ui/jam_scene_idle_test.dart` covers the same rule in CI:
when the scene is at rest, no frame is scheduled, no ticker runs and the
scene does not repaint.

## Results (emulator)

Each value is the mean of two runs per side. Baseline is commit `41a6297`
(main) with only this harness and a paint counter back-ported. "After" is
this branch.

| Phase | Metric | Baseline | After |
|---|---|---|---|
| tutorial | UI build ms avg / p90 / p99 / worst | 0.99 / 1.40 / 2.56 / 3.75 | 0.98 / 1.42 / 2.20 / 3.09 |
| tutorial | Raster work excl. present, ms avg / p90 / p99 / worst | 3.26 / 4.76 / 9.68 / 13.42 | 2.16 / 4.18 / 7.32 / 11.35 |
| tutorial | Raster (FrameTiming) ms avg / p90 / p99 / worst | 13.33 / 17.25 / 23.34 / 34.60 | 13.92 / 17.28 / 22.28 / 42.19 |
| tutorial | Delivered fps / dropped frames | 59.5 / 3.5 | 59.6 / 2.5 |
| level12_opening | UI build ms avg / p90 / p99 / worst | 1.47 / 2.04 / 3.45 / 3.85 | 1.05 / 1.53 / 2.82 / 3.26 |
| level12_opening | Raster work excl. present, ms avg / p90 / p99 / worst | 4.12 / 4.83 / 8.17 / 13.14 | 2.00 / 3.07 / 4.36 / 8.62 |
| level12_opening | Raster (FrameTiming) ms avg / p90 / p99 / worst | 15.66 / 17.48 / 21.86 / 44.94 | 11.90 / 16.99 / 20.23 / 38.60 |
| level12_opening | Delivered fps / dropped frames | 59.6 / 3.5 | 59.7 / 2.0 |
| level12 | UI build ms avg / p90 / p99 / worst | 1.30 / 2.00 / 3.66 / 4.13 | 1.04 / 1.39 / 2.20 / 3.32 |
| level12 | Raster work excl. present, ms avg / p90 / p99 / worst | 3.22 / 4.54 / 9.15 / 11.38 | 2.19 / 3.03 / 6.89 / 15.86* |
| level12 | Raster (FrameTiming) ms avg / p90 / p99 / worst | 14.31 / 17.30 / 20.16 / 39.36 | 12.13 / 17.07 / 19.73 / 39.99 |
| level12 | Delivered fps / dropped frames | 59.7 / 3.0 | 59.7 / 3.0 |
| densest_rapid | UI build ms avg / p90 / p99 / worst | 1.79 / 2.50 / 4.10 / 6.67 | 1.48 / 2.18 / 3.55 / 5.10 |
| densest_rapid | Raster work excl. present, ms avg / p90 / p99 / worst | 4.69 / 6.52 / 9.88 / 11.57 | 2.76 / 4.17 / 5.63 / 6.35 |
| densest_rapid | Raster (FrameTiming) ms avg / p90 / p99 / worst | 15.69 / 17.41 / 23.92 / 44.44 | 14.41 / 17.32 / 19.82 / 38.25 |
| densest_rapid | Delivered fps / dropped frames | 59.4 / 8.5 | 59.7 / 4.5 |
| idle | Animation frames / scene repaints in 3 s | 0 / 0 | 0 / 0 |

No phase had a frame over the 16.7 ms build budget, before or after.

Sprite cache after a full run of `densest_rapid`: 110 sprites, 12.5 MB,
65 misses against 27,500 hits. The budget is 32 MB and 320 entries.

\* One frame in the second run in which the emulator's GL driver stalled
for 15 ms inside `RenderPassGLES::EncodeCommandsInReactor`. The frame also
held the level's first `saveLayer`, so it was probably the win overlay
appearing. Without that frame, the worst in that run is 10 ms.

### Reading the raster numbers

FrameTiming's raster time on this emulator is about one vsync (about
15–17 ms) whenever frames are drawn back to back. This holds whatever the
scene contains: it is the same for an idle scene with nothing changing,
for a lone `CircularProgressIndicator` in one probe run, and with
`--no-enable-impeller` (Skia). In the timeline, nearly all of it is inside
`SurfaceFrame::Submit` but outside `SurfaceFrame::Encode`. That is the
present on the goldfish GL pipe blocking until the host composites. So
the FrameTiming raster p90 target (under 12 ms) cannot be reached on this
emulator, and the number does not say how expensive the scene is.

**Raster work excl. present** is per frame
`GPURasterizer::Draw − SurfaceFrame::Submit + SurfaceFrame::Encode`, from
the timeline. This is the time the raster thread spends encoding and
issuing the frame's GL commands, and it is the number the scene changes
affect. Targets against it: p90 under 12 ms is met in every phase (at most
4.2 ms), and worst under 16.7 ms is met in every phase.

### Shader compilation

Impeller is the default on Android in this Flutter version. On this
emulator it runs on OpenGL ES (`ReactorGLES`). Its shaders are compiled
ahead of time, and no frame showed the long first-use compile spikes that
Skia used to have. The remaining raster spikes are of two kinds:

- one-off GL stalls when an effect is used for the first time (the win
  overlay's `saveLayer`, and `CreateGlyphAtlas` taking about 2 ms when new
  text appears);
- 35–60 ms emulator hiccups that also show up in the idle phase, where the
  app does no work.

## What changed

1. **Static board as one bitmap** (`lib/jam/ui/board_layer.dart`). A
   RepaintBoundary only spares the UI thread from re-recording the board.
   Impeller still replays every board path on every animated frame: tiles,
   dashed lines (one path each), lot markings, grass tufts and trees, which
   is hundreds of operations. The board is now drawn once per layout and
   device pixel ratio with `JamBoardPainter`, turned into an image with
   `Picture.toImageSync`, and drawn as a single textured quad.
2. **Sprite cache** (`lib/jam/ui/sprite_cache.dart`, `jam_sprites.dart`).
   Lot buses, queued riders and the tutorial hand are drawn once by the art
   painters (`paintBus`, `paintRider`, `paintPointerHand`) into a
   device-resolution `ui.Image`. Later frames place that image with a
   transform. The cache does not depend on how the painters work inside:
   the key holds colour, length, size in quarter device pixels, heading,
   seat count, quantised flash / glow / dim, rider variant and device
   pixel ratio, and whatever the painter draws inside the padded bounds is
   cached. Blurred shadows and glow halos are baked into the bitmap, so no
   `MaskFilter.blur` runs per sprite per frame. Lurch is a translation,
   squash and pop are a scale, and rider fade and scale are a paint alpha
   and a scale. Sprites at rest are snapped to the device pixel grid so
   they map 1:1. Memory is bounded by an LRU with an entry cap and a byte
   budget, and evicted images are disposed.
3. **What stays live, and why**: bay buses (at most a few on screen) change
   heading, size, seat count or squash nearly every frame. Riders in the
   air keep their shadow on the ground while the body hops. Sparkles and
   stall pulses are brief. Rasterising any of these anew costs more than
   drawing them: a cache miss is one offscreen render, about 1.5–3 ms on
   the emulator. Caching moving buses by heading and size bucket was tried
   and dropped. It produced about 500 misses per dense run and pushed the
   cache to its byte budget. The "+N" chip is kept as a recorded
   `ui.Picture` (no text layout per frame, and no rasterising for each
   count).
4. **Fewer per-frame allocations in the choreographer**. Each rider's walk
   route and its length are worked out once per walk instead of on every
   frame (this also makes the walker-spacing search at tap time cheaper).
   `takeCues` returns a constant empty list when no cue is due. The
   `where().length` and `any` closures that ran every frame are now plain
   loops. Bay buses are split into reused resting and moving lists.
5. **Idle**: the ticker already stopped once the timeline finished; this
   is now covered by a widget test and by the benchmark's
   `animation_frames` and `scene_paints` counters.

Visual output: rendering the same scene states in a widget test at
2.625 dpr shows no change except anti-aliasing along sprite edges, where a
sprite moved by less than half a device pixel when it was snapped to the
pixel grid. The two emulator screenshots of the idle scene match by eye.

## Remaining hotspots

- On the emulator, the present (`eglSwapBuffers` on the GL pipe) sets the
  frame time, not the app. To check the raster numbers, measure on a real
  device.
- A sprite-cache miss is rendered synchronously on the raster thread with
  `toImageSync`, at about 1.5–3 ms on the emulator. Most misses happen when
  a level opens (lot buses, visible riders). After that there is about one
  per rider who comes into view.
- The win overlay's first frame (first `saveLayer`, new text for the glyph
  atlas) is the most expensive frame of a level.
- In the benchmark the semantics tree is on and costs about 0.5 ms of UI
  time per frame. A phone with no accessibility service running does not
  pay this.
