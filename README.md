# Bus-ster

Bus-ster is a Flutter Android puzzle game in development. The current app opens an original bright parking-jam prototype with directional vehicles, a visible passenger queue, boarding bays, and a solver-generated hint. It replaces the earlier road-network design, which the owner rejected. The replacement rules and artwork are still provisional; see the [design review](docs/DESIGN_REVIEW_2026-10-11.md) and [staged plan](GAME_PLAN.md).

The rules live in a UI-independent [Dart model](lib/game/parking_jam_model.dart), connected to the Flutter screen in [`parking_jam_screen.dart`](lib/game/parking_jam_screen.dart). The first level is an eight-vehicle guided release chain; the second uses a dense 12-vehicle lot. Both have bounded-solver solutions. Movement, queue, capacity, and bay behavior remain hypotheses until direct reference play and owner review.

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

Tap a vehicle to send it out of the lot along its facing direction when its forward lane is clear. Buses wait in boarding bays and load riders from the visible matching queue. A blocked tap identifies the vehicle in the way. Use **Undo**, **Retry**, or **Hint** to recover. The demo is playable, but it is not a complete level pack and its exact rules still need review.

The new screen uses original Flutter-drawn vehicle and board artwork. Emulator captures show the [guided tutorial](docs/evidence/busster_parking_jam_stage1_api35_2026-10-11.png), [crowded second lot](docs/evidence/busster_parking_jam_level2_api35_2026-10-11.png), and [boarding move](docs/evidence/busster_parking_jam_move_api35_2026-10-11.png). The earlier evening-depot art remains on the legacy regression screen and is not used by the current launch path. The asset sources are tracked in [`docs/ASSET_LEDGER.md`](docs/ASSET_LEDGER.md).

The parking-jam demo runs offline. Its current play session is in memory and does not yet use the older local progress/settings system. Save/resume, level selection, persistent hints, and sound/haptic settings must be integrated into this screen before those existing systems count as current-game features.

The current parking-jam screen does not show ads or purchases. The repository retains an older consent-gated rewarded-ad integration for the superseded depot screen; keep production ads disabled until the new game has retention evidence and its ad flow is reviewed. Debug test ads stay off by default; to exercise the legacy integration with Google's official test IDs, run:

```sh
flutter run --dart-define=BUSSTER_ENABLE_TEST_ADS=true
```

The default release configuration does not request consent or load ads. The ads SDK remains in the Android package and contributes network, advertising-ID, and Privacy Sandbox permissions, so final Play ads/Data safety declarations and privacy disclosures must account for the configured SDK behavior. Production IDs and consent messages are not set up; never publish the validation APK/AAB as-is. See Stage 5 and Stage 6 in [`GAME_PLAN.md`](GAME_PLAN.md) for the full configuration and release gates.

When a publisher account exists, the Android manifest app ID comes from the `BUSSTER_ADMOB_APP_ID` environment variable. The release Dart build must receive the same app ID through `--dart-define=BUSSTER_ADMOB_APP_ID=...`, plus `BUSSTER_REWARDED_AD_UNIT_ID=...` and `BUSSTER_ENABLE_PRODUCTION_ADS=true`. Keep the manifest and Dart app IDs identical. Production ads are not configured in this repository.

The new screen does not yet expose the older sound, haptic, or reduced-motion settings. Integrate those only after the basic vehicle and passenger feedback is accepted.

The legacy depot UI uses Flutter localization with English source copy in [`lib/l10n/app_en.arb`](lib/l10n/app_en.arb). The new parking-jam slice is currently English-only; localize it with the new level schema after the core screen and instructions are reviewed.

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
