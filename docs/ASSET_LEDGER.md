# Bus-ster asset and license ledger

_Started 11 October 2026. This records the current gray-box project assets; it is not a release clearance. Update it whenever art, audio, fonts, or store media are added._

| Asset or group | Current source | Current status | Release action |
| --- | --- | --- | --- |
| Depot board, road network, yard tiles, buses, gate, route highlight | Shapes drawn at runtime in [`lib/game/depot_game.dart`](../lib/game/depot_game.dart) using Flutter Canvas APIs. | Project-created placeholder rendering; no image files imported. | Replace or refine with original production art; keep source and author records. |
| Route colors and passenger/bus symbols | [`lib/game/game_model.dart`](../lib/game/game_model.dart) palette and [`lib/game/route_symbol.dart`](../lib/game/route_symbol.dart) vector geometry. | Four project-authored shapes (circle, diamond, triangle, four-point star) accompany route colors in the board, queue, and bays. The queue and parked-bus icons have spoken route labels. | Verify contrast and grayscale/color-vision readability with players; keep each route distinguishable without color. |
| UI iconography and Material widgets | Flutter Material widgets/icons in [`lib/main.dart`](../lib/main.dart), bundled Flutter SDK icon font. | Framework-provided resources; no separate icon pack added. | Include third-party notices as required by the Flutter SDK and verify upstream Material Icons terms for the packaged font. |
| Android launcher icon | Native vector bus mark in `android/app/src/main/res/drawable/ic_launcher_foreground.xml`, composed by `mipmap-anydpi/ic_launcher.xml` and `mipmap-anydpi-v26/ic_launcher.xml`. | Original project-produced vector artwork authored with Codex assistance on 11 October 2026. No third-party source or stock asset used; no third-party attribution is required by the source materials. | Review appearance under Android launcher masks and on physical devices; clear the Bus-ster name and mark for store use before release. |
| Launch screen | `android/app/src/main/res/drawable*/launch_background.xml` using `ic_launcher_background` | Project-defined dark navy background, matched to the launcher mark. No external asset. | Review cold-start appearance and Android 12 splash behavior on the device matrix. |
| Fonts, SFX, music, sprites, screenshots, video | None added as separate project assets as of this date. | Not in the prototype. | Add only original or properly licensed assets. Record creator, source URL, license/version, proof of purchase or permission, attribution, and intended uses before importing. |
| Dependencies | [`pubspec.lock`](../pubspec.lock), including Flutter SDK and Flame. | Development/runtime packages; package versions are locked for reproducible builds. | Generate and review a dependency license inventory before release; retain required notices. |

## Recording rules

For every new asset, record the exact file path, creator/rightsholder, source, license and version, date obtained, attribution text, allowed commercial/mobile uses, modification rights, and proof of permission. Keep receipts and written permissions outside Git if they contain private information; keep a non-sensitive evidence reference here. Never put stock previews, reference-game screenshots, downloaded competitor assets, generated third-party logos, or unreviewed font files in the release bundle.

## Release gate

Before store submission, replace the Flutter launcher placeholder, confirm every shipped asset and dependency license, verify icon/title similarity, and make sure the store listing uses only Bus-ster screenshots and copy. The final approver should check the packaged APK/AAB as well as this ledger.
