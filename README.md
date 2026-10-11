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

The depot board, buses, route markers, rider marks, and bay indicators use original vector artwork drawn in the app. Four short, original synthesized sound effects play offline for dispatch, boarding, depot clear, and stuck feedback. This art and audio direction is still awaiting player review; the asset sources and release checks are tracked in [`docs/ASSET_LEDGER.md`](docs/ASSET_LEDGER.md).

Progress, unlocked depots, and earned Route Tips save locally on Android; the core game works offline. Android system backup can transfer the allow-listed progress and settings files when enabled in the user's device/account settings. Players start with three tips, earn one on each depot’s first clear (up to five), and unlock depots in order. Switching away from an unfinished attempt asks first. The progress format is versioned and tested for migration and recovery.

The first 10 depots have no ads. Later, if free Route Tips are exhausted and a consent-approved rewarded ad is ready, a player can explicitly opt in to earn one tip. Closing the ad without its reward callback grants nothing. Debug test ads stay off by default; to exercise Google's official test IDs on an Android emulator/device, run:

```sh
flutter run --dart-define=BUSSTER_ENABLE_TEST_ADS=true
```

The default release configuration does not request consent or load ads. The ads SDK remains in the Android package and contributes network, advertising-ID, and Privacy Sandbox permissions, so final Play ads/Data safety declarations and privacy disclosures must account for the configured SDK behavior. Production IDs and consent messages are not set up; never publish the validation APK/AAB as-is. See Stage 5 and Stage 6 in [`GAME_PLAN.md`](GAME_PLAN.md) for the full configuration and release gates.

When a publisher account exists, the Android manifest app ID comes from the `BUSSTER_ADMOB_APP_ID` environment variable. The release Dart build must receive the same app ID through `--dart-define=BUSSTER_ADMOB_APP_ID=...`, plus `BUSSTER_REWARDED_AD_UNIT_ID=...` and `BUSSTER_ENABLE_PRODUCTION_ADS=true`. Keep the manifest and Dart app IDs identical. Production ads are not configured in this repository.

Pause the game to control sound effects and haptics independently, or enable reduced motion. These preferences save locally; haptics accompany successful bus dispatches only. Audio mix and haptic feel still need physical-device testing.

## Check the project

```sh
dart format lib test tools integration_test
flutter analyze
flutter test
dart run tools/validate_levels.dart
dart run tools/preview_levels.dart
flutter build apk --debug
```

Edit `assets/levels/levels.json` to author levels. The validator checks the versioned schema, geometry, passenger capacity, tutorial metadata, and solver path. The preview tool writes an HTML overview to `build/level-preview.html`. To generate two seeded queue-order candidates from each authored depot, run `dart run tools/generate_level_candidates.dart --seed 20261011 --per-level 2`; candidates go under `build/level-candidates/`, stay outside the shipping pack, and need human review. To create a solver-checked mirrored layout, run `dart run tools/level_variants.dart depot-03 x`; mirrored candidates go under `build/level-variants/` and also need human review before release.

With an Android emulator or device connected, run the first-dispatch smoke test:

```sh
flutter test integration_test/first_dispatch_test.dart -d <device-id>
```

After installing a release APK on an emulator, collect repeatable process-launch time, one-second post-launch PSS, and artifact-size samples with:

```powershell
.\tools\measure_android_emulator.ps1 -DeviceId emulator-5554 -Samples 5
```

The JSON report is written under the ignored `build/android-metrics/` folder. `am start -W` and emulator memory readings are diagnostics; they do not measure first-input latency or replace physical-device frame-time, thermal, and touch testing.

## Project documents

- [Step-by-step game plan](GAME_PLAN.md)
- [Stage 0 research and playtest workbook](docs/STAGE_0_FIELDWORK.md)
- [Level schema and authoring workflow](docs/LEVEL_SCHEMA.md)
- [Asset and license ledger](docs/ASSET_LEDGER.md)
- [Level validation tool](tools/validate_levels.dart)
- [Gameplay analytics event schema](docs/ANALYTICS_EVENT_SCHEMA.md)
- [Internal privacy-policy draft (not release-ready)](docs/PRIVACY_POLICY_DRAFT.md)

The game and all eventual store assets must use original art, level layouts, sounds, and copy. The plan tracks playtest, production, monetization, and release gates.
