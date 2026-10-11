# Bus-ster

Bus-ster is a Flutter/Flame Android game in development. The intended product is an original, bright parking-jam puzzle with direction-marked vehicles, visible passengers, and boarding spaces. **The runnable build below is a superseded road-network technical prototype:** its gameplay and visual style were rejected in the owner review. See the [design review and replacement brief](docs/DESIGN_REVIEW_2026-10-11.md) and the [revised staged plan](GAME_PLAN.md) before adding content or art.

A separate [provisional parking-jam rules spike](lib/game/parking_jam_model.dart) has begun. It is tested in plain Dart but is not yet connected to the runnable Flutter screen.

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

The ten historical depots are playable for technical inspection only. Tap a bus on the road to send it toward the exit. If it cannot board the next riders, it waits in a departure bay. Use **Route Tip** for a solver hint or **Undo** to reverse a dispatch. These mechanics are being replaced and the ten levels do not count toward launch content.
Open **How to play** in the top bar for the core rules.

The technical prototype uses original vector artwork and four original synthesized sound effects. The owner rejected its evening-depot visual direction; the assets are recorded in [`docs/ASSET_LEDGER.md`](docs/ASSET_LEDGER.md) and may be replaced or adapted after the new layout review.

Progress, unlocked depots, and earned Route Tips save locally on Android; the core game works offline. Android system backup can transfer the allow-listed progress and settings files when enabled in the user's device/account settings. Players start with three tips, earn one on each depot’s first clear (up to five), and unlock depots in order. Switching away from an unfinished attempt asks first. The progress format is versioned and tested for migration and recovery.

The first 10 depots have no ads. Later, if free Route Tips are exhausted and a consent-approved rewarded ad is ready, a player can explicitly opt in to earn one tip. Closing the ad without its reward callback grants nothing. Debug test ads stay off by default; to exercise Google's official test IDs on an Android emulator/device, run:

```sh
flutter run --dart-define=BUSSTER_ENABLE_TEST_ADS=true
```

The default release configuration does not request consent or load ads. The ads SDK remains in the Android package and contributes network, advertising-ID, and Privacy Sandbox permissions, so final Play ads/Data safety declarations and privacy disclosures must account for the configured SDK behavior. Production IDs and consent messages are not set up; never publish the validation APK/AAB as-is. See Stage 5 and Stage 6 in [`GAME_PLAN.md`](GAME_PLAN.md) for the full configuration and release gates.

When a publisher account exists, the Android manifest app ID comes from the `BUSSTER_ADMOB_APP_ID` environment variable. The release Dart build must receive the same app ID through `--dart-define=BUSSTER_ADMOB_APP_ID=...`, plus `BUSSTER_REWARDED_AD_UNIT_ID=...` and `BUSSTER_ENABLE_PRODUCTION_ADS=true`. Keep the manifest and Dart app IDs identical. Production ads are not configured in this repository.

Pause the game to control sound effects and haptics independently, or enable reduced motion. These preferences save locally; haptics accompany successful bus dispatches only. Audio mix and haptic feel still need physical-device testing.

The UI uses Flutter's generated localization support with English source copy in [`lib/l10n/app_en.arb`](lib/l10n/app_en.arb). Level titles and tutorial prompts use locale-keyed content in schema version 2; the codec still reads version 1. Only English is currently shipped. Add a locale only after translating both the UI and level copy and checking text fit and gameplay instructions for that language.

## Check the project

```sh
dart format lib test tools integration_test
flutter gen-l10n
flutter analyze
flutter test
dart run tools/validate_levels.dart
dart run tools/preview_levels.dart
flutter build apk --debug
```

The current `assets/levels/levels.json`, validator, HTML preview, queue-order generator, and mirror helper belong to the superseded road-network model. Keep them for regression checks during the redesign; **do not author or generate more old-schema levels**. Replace the schema and tools after the new parking-jam rules are implemented.

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
- [Design review and replacement acceptance brief](docs/DESIGN_REVIEW_2026-10-11.md)
- [Preliminary phone-scale screen concepts](docs/concepts/parking-jam-direction.html)
- [Stage 0 research and playtest workbook](docs/STAGE_0_FIELDWORK.md)
- [Level schema and authoring workflow](docs/LEVEL_SCHEMA.md)
- [Asset and license ledger](docs/ASSET_LEDGER.md)
- [Level validation tool](tools/validate_levels.dart)
- [Gameplay analytics event schema](docs/ANALYTICS_EVENT_SCHEMA.md)
- [Internal privacy-policy draft (not release-ready)](docs/PRIVACY_POLICY_DRAFT.md)

The game and all eventual store assets must use original art, level layouts, sounds, and copy. The plan tracks playtest, production, monetization, and release gates.
