---
name: check
description: Run Bus-ster's full verification gate — format check, flutter analyze, all tests, the level-pack validator, and the docs link checker — and report pass/fail per step. Use before committing, before merging an agent's branch, or when asked to verify the project. Pass "perf" to also run the profile-mode frame benchmark on the emulator.
---

# Bus-ster verification gate

Run from the repo root. Run every step even if an earlier one fails, then report a
one-line pass/fail per step with the failing output.

```bash
bash .claude/skills/check/check.sh
```

The script runs, in order:

1. `dart format --set-exit-if-changed lib test tools integration_test test_driver`
2. `flutter analyze`
3. `flutter test`
4. `dart run tools/validate_jam_levels.dart` — every level decodes, is solvable, and hints stay fast
5. `python tools/check_links.py` — relative links and anchors in README, GAME_PLAN and docs/

## With `perf`

If the arguments include `perf`, also run the profile benchmark on the emulator
(boot it first with the demo-video skill's `ensure_emulator` step if `adb devices`
shows nothing):

```bash
flutter drive --profile --no-dds --driver=test_driver/integration_test.dart \
  --target=integration_test/perf_test.dart -d emulator-5554
```

Then summarise `build/perf/frame_stats.json` per phase: fps, dropped frames, UI build
p90, sprite entries. Emulator raster times include a ~16 ms GL present; judge raster
on a real phone (see docs/PERFORMANCE.md).

## Reporting

- All green: say so in one line with the test count.
- Any failure: show the failing step's relevant output and the likely cause. Do not
  "fix" a failing test by weakening its assertion without saying so explicitly.
