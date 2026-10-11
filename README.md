# Bus-ster

Bus-ster is an original portrait-mode Android bus dispatch puzzle built with Flutter and Flame. Players clear a road network, send buses through a shared exit, and board a visible first-in-first-out rider queue.

## Run the prototype

Install Flutter and the Android SDK, then run:

```sh
flutter pub get
flutter run
```

The first 10 depots are playable. Tap a bus on the road to send it toward the exit. If it cannot board the next riders, it waits in a departure bay. Use **Route Tip** for a solver hint or **Undo** to reverse a dispatch.
Open **How to play** in the top bar for the core rules.

## Check the project

```sh
dart format lib test
flutter analyze
flutter test
dart run tools/validate_levels.dart
flutter build apk --debug
```

## Project documents

- [Step-by-step game plan](GAME_PLAN.md)
- [Stage 0 research and playtest workbook](docs/STAGE_0_FIELDWORK.md)
- [Asset and license ledger](docs/ASSET_LEDGER.md)
- [Level validation tool](tools/validate_levels.dart)

The game and all eventual store assets must use original art, level layouts, sounds, and copy. The plan tracks playtest, production, monetization, and release gates.
