# Bus-ster

Flutter (Dart 3.11) Android bus-jam puzzle. All art is procedural `CustomPainter` code;
no game engine, no ads/analytics SDKs. See README.md for the player-facing rules and
docs/REBUILD_PLAN.md for the rules contract and project history.

## Commands

- Full gate (format, analyze, test, level validator, doc links): `/check`, or
  `bash .claude/skills/check/check.sh`
- Single test file: `flutter test test/jam/jam_model_test.dart`
- Regenerate levels 4–30: `dart run tools/generate_jam_levels.dart` (deterministic seed),
  then `dart run tools/validate_jam_levels.dart`
- Localized strings: edit `lib/l10n/app_en.arb`, then `flutter gen-l10n`
- Frame benchmark (profile, emulator): see docs/PERFORMANCE.md
- Demo video: `/demo-video`

## Layout

- `lib/jam/` — pure-Dart rules (`jam_model.dart`), solver/analysis (`jam_solver.dart`),
  level codec (schema v2), generator, progress model/store, app controller.
- `lib/jam/ui/` — game screen, choreographer (visual timeline), layout geometry,
  painters (`bus_`, `crowd_`, `bay_`, `board_painter.dart`), sprite cache, HUD, overlays,
  home, settings.
- `lib/game/` — small shared adapters: audio, settings store, no-op telemetry.
- `assets/levels/jam_levels.json` — 3 hand-authored tutorials + 27 generated levels.
- `integration_test/` — app smoke test, scripted demo tour, perf benchmark.

## Invariants (don't break these)

- **Rules first.** `JamSession.tap` applies the move immediately; the choreographer only
  animates the returned events. Never delay rules for animation. Undo/Retry/level change
  snap the choreographer to the true state.
- **Model is pure Dart** (no Flutter imports) and immutable.
- **Painters are pure** functions of their inputs (no time, no globals) — the sprite
  cache relies on it. Any new visual input must be added to the sprite-cache key.
- **No idle frames.** Tickers stop when nothing animates; `pumpAndSettle` must finish.
- **Levels:** don't hand-edit levels 4+; keep vehicles listed in plan order (fast
  hints). Every level must pass the validator.
- **Progress** is keyed by level id; writes are atomic with a `.bak` copy.
- **Strings** go through `AppLocalizations`. Never edit generated
  `lib/l10n/app_localizations*.dart` (a hook blocks it).

## Working conventions

- Parallel agents must each use their own git worktree
  (`git worktree add -b <branch> ../bus-ster-<name> main`) — never two agents switching
  branches in one folder.
- Verify UI changes visually (the `visual-qa` agent, or emulator screenshots), not just
  with tests; layout regressions have passed the test suite before.
- Emulator results are interim: they don't replace real-phone performance checks or
  player testing. Label emulator numbers as such.
- QA screenshots/videos go in PRs or scratch folders, not the repo (`docs/evidence/` is
  ignored).

## Environment (Windows, Git Bash)

- Android SDK: `%LOCALAPPDATA%\Android\sdk`; emulator AVD `Busster_QA_API35`
  (`emulator-5554`). It sometimes exits between runs — reboot it rather than assuming
  it's up.
- In Git Bash set `MSYS_NO_PATHCONV=1` before `adb shell ... /sdcard/...`, or the path
  gets rewritten.
- After `adb shell wm size/density` changes, always `wm size reset; wm density reset`.
