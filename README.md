# Bus-ster

Bus-ster is an original portrait-mode Android bus dispatch puzzle built with Flutter and Flame. Players clear a road network, send buses through a shared exit, and board a visible first-in-first-out rider queue.

## Run the prototype

Install Flutter and the Android SDK, then run:

```sh
flutter pub get
flutter run
```

Release-profile validation builds:

```sh
flutter build apk --release
flutter build appbundle --release
```

The current Android Gradle release variant uses the debug signing key. These artifacts are for local validation only and must not be uploaded to Play Console.

The first 10 depots are playable. Tap a bus on the road to send it toward the exit. If it cannot board the next riders, it waits in a departure bay. Use **Route Tip** for a solver hint or **Undo** to reverse a dispatch.
Open **How to play** in the top bar for the core rules.

Progress, unlocked depots, and earned Route Tips save locally on Android; the core game works offline. Android system backup can transfer the allow-listed progress and settings files when enabled in the user's device/account settings. Players start with three tips, earn one on each depot’s first clear (up to five), and unlock depots in order. Switching away from an unfinished attempt asks first. The progress format is versioned and tested for migration and recovery.

Pause the game to turn haptics on or off and enable reduced motion. These preferences save locally; haptics accompany successful bus dispatches only. Their feel still needs physical-device testing.

## Check the project

```sh
dart format lib test tools integration_test
flutter analyze
flutter test
dart run tools/validate_levels.dart
dart run tools/preview_levels.dart
flutter build apk --debug
```

Edit `assets/levels/levels.json` to author levels. The validator checks the versioned schema, geometry, passenger capacity, tutorial metadata, and solver path. The preview tool writes an HTML overview to `build/level-preview.html`. To create a solver-checked mirrored candidate, run `dart run tools/level_variants.dart depot-03 x`; generated variants go under `build/level-variants/` and still need human playtesting before release.

With an Android emulator or device connected, run the first-dispatch smoke test:

```sh
flutter test integration_test/first_dispatch_test.dart -d <device-id>
```

## Project documents

- [Step-by-step game plan](GAME_PLAN.md)
- [Stage 0 research and playtest workbook](docs/STAGE_0_FIELDWORK.md)
- [Level schema and authoring workflow](docs/LEVEL_SCHEMA.md)
- [Asset and license ledger](docs/ASSET_LEDGER.md)
- [Level validation tool](tools/validate_levels.dart)
- [Gameplay analytics event schema](docs/ANALYTICS_EVENT_SCHEMA.md)
- [Internal privacy-policy draft (not release-ready)](docs/PRIVACY_POLICY_DRAFT.md)

The game and all eventual store assets must use original art, level layouts, sounds, and copy. The plan tracks playtest, production, monetization, and release gates.
