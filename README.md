# Bus-ster

Bus-ster is an original bus-jam puzzle game for Android, built with Flutter. It is a work-in-progress rebuild: the rules, 30 levels, home/level select, settings, audio and full bus choreography are in place, but the owner has not yet accepted the feel, and nothing has been tested on a physical phone or with players. See [docs/REBUILD_PLAN.md](docs/REBUILD_PLAN.md) for why the game was rebuilt and [GAME_PLAN.md](GAME_PLAN.md) for the roadmap.

## How it plays

- A parking lot is packed with chunky buses. Each bus has a colour and points one way.
- Tap a bus. If nothing stands between its nose and the edge of the lot, it drives out and parks in the lowest free **bay**. If another bus is in the way, it lurches toward the blocker and stays put.
- A crowd of passengers waits in a queue, in colour groups. Whenever the person at the front matches a parked bus with free seats, they walk over and board.
- A full bus leaves and frees its bay. Seats per colour exactly match riders per colour, so every bus must eventually fill.
- **Win** when every passenger has boarded. **Lose** when all bays are full and nobody at the front can board (or no bus can move while people still wait).
- Undo, Retry and Hint (solver-backed, free, unlimited) are available while playing; Undo also works after a loss.

The exact rules contract is in [docs/REBUILD_PLAN.md](docs/REBUILD_PLAN.md#rules-contract-v2--single-source-of-truth).

The game is fully offline. There are no ads, purchases, accounts, or analytics network calls. Progress is saved locally in `busster-progress.json` (with a `.bak` last-good copy) and settings in SharedPreferences.

## Run and build

Requires Flutter 3.41.6 stable (Dart 3.11.4) and the Android SDK (target API 36).

```sh
flutter pub get
flutter run                     # on a connected device or emulator
flutter build apk --debug
flutter build appbundle --release   # validation only, see "Open gates"
```

## Check

```sh
dart format --output=none --set-exit-if-changed lib test tools integration_test
flutter gen-l10n
flutter analyze
flutter test
dart run tools/validate_jam_levels.dart          # schema, solvability, difficulty, hint speed
```

CI ([.github/workflows/flutter.yml](.github/workflows/flutter.yml)) runs the same steps plus a debug APK build on every push to `main` and every pull request. It does not run the integration test.

Integration smoke test (home → settings → play → tap a bus → back to levels), on a connected emulator or phone:

```sh
flutter test integration_test/app_smoke_test.dart -d <device-id>
```

## Levels

The pack lives in [assets/levels/jam_levels.json](assets/levels/jam_levels.json) (schema v2): 3 hand-made tutorials plus 27 generated levels whose measured random-playout fail rate rises from about 0.26 to 0.87, with easier "breather" levels and three four-bay spikes. Regenerate or tune with:

```sh
dart run tools/generate_jam_levels.dart --dry-run      # print metrics only
dart run tools/generate_jam_levels.dart                # rewrite levels 4–30
dart run tools/validate_jam_levels.dart                # always run afterwards
```

Format, generator flags and validation rules: [docs/LEVEL_SCHEMA.md](docs/LEVEL_SCHEMA.md).

## Project layout

```text
lib/
  main.dart                    app entry; MaterialApp + localisation
  jam/                         pure-Dart game core (no Flutter imports in rules)
    jam_model.dart             rules v2: vehicles, bays, boarding, undo, events
    jam_solver.dart            tri-state solver + random-playout difficulty analysis
    jam_level_codec.dart       JSON schema v2 reader/writer
    jam_generator.dart         seeded level generator
    jam_progress*.dart         progress model + atomic file store with .bak recovery
    jam_app_controller.dart    shared state: level pack, progress, settings
    ui/                        home, settings and game screens; CustomPainter art,
                               layout, choreography (drive → bay → board → depart)
  game/                        settings store, audio adapter, no-op telemetry
  l10n/                        English ARB source + generated localisations
assets/levels/jam_levels.json  the 30-level pack
assets/audio/*.wav             4 synthesized sound cues
tools/                         level generator/validator, audio generator,
                               emulator launch/memory sampler (PowerShell)
test/                          unit and widget tests
integration_test/              on-device smoke test
docs/                          plans, schema, privacy draft, asset ledger
```

## Current status and open gates

Done on emulator and in tests: rules v2 with exhaustive tests, solver, 30 validated levels, rebuilt screen with full choreography, level select and progress save, settings (sound, vibration, reduced motion), audio cues, English localisation, compact 320×568 layout.

Still open — do not treat the build as release-ready:

- **Owner acceptance of feel** (visuals, motion, difficulty) is pending.
- **Physical-device testing** has not happened (touch, frame time, haptics, audio latency, backup/restore). Emulator results are interim.
- **Player testing** has not happened; see [docs/STAGE_0_FIELDWORK.md](docs/STAGE_0_FIELDWORK.md).
- **Release signing:** the release build type still uses the debug key. Never upload these artifacts to Play.
- **No store setup:** no Play Console app, listing, Data safety form, published privacy policy, or name/trademark clearance ("Busster" is already taken on Play by an unrelated app).

QA screenshots belong in pull-request descriptions, not the repository (`docs/evidence/` is git-ignored).

## Documents

- [GAME_PLAN.md](GAME_PLAN.md) — roadmap and next steps
- [docs/REBUILD_PLAN.md](docs/REBUILD_PLAN.md) — rebuild rationale, rules contract, phase status
- [docs/LEVEL_SCHEMA.md](docs/LEVEL_SCHEMA.md) — level format and authoring workflow
- [docs/ANALYTICS_EVENT_SCHEMA.md](docs/ANALYTICS_EVENT_SCHEMA.md) — gameplay events (no-op only)
- [docs/PRIVACY_POLICY_DRAFT.md](docs/PRIVACY_POLICY_DRAFT.md) — internal data-inventory draft
- [docs/ASSET_LEDGER.md](docs/ASSET_LEDGER.md) — art/audio provenance
- [docs/STAGE_0_FIELDWORK.md](docs/STAGE_0_FIELDWORK.md) — competitor teardown and playtest workbook
- [docs/archive/](docs/archive/) — superseded design notes and October 2026 desk research
