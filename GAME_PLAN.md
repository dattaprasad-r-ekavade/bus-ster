# Bus-ster — staged Android game plan

_Updated: 11 October 2026. Owner: Bus-ster team. Status: prototype in progress; Stage 0 research and Stage 1 device/player gates remain open._

## Current progress snapshot — 11 October 2026

This is an active build plan, not a release-ready game. The repository contains a Flutter/Flame Android prototype with 10 hand-authored JSON depots, provisional mechanic tags and difficulty bands, a pure-Dart rules model, a bounded breadth-first solver, a versioned level codec and runtime asset loader, a batch validator with reachable-state branch/trap metrics, an HTML level preview, solver-checked mirror variants, and a deterministic queue-order candidate generator that has produced 20 separate unrated candidates, an ordered depot picker, three starter Route Tips plus one earned on each depot’s first clear (up to five), hint/undo/retry, an animated dispatch, an optional rules-help dialog, versioned JSON-serializable dispatch replays, local progress save/resume with schema migration and last-good recovery, pause/resume with app-background handling, boarding/departure feedback, an original vector-art v1 for buses, riders, roads, buildings, exits, and bays, accessible vector route markers, separate persisted haptics/sound/reduced-motion settings, four original generated sound effects, distinct clear/stuck recovery feedback, 44 passing unit/widget tests, Android integration coverage, a GitHub Actions workflow, and successful debug and release-profile APK/AAB validation builds. The progress file and Android DataStore settings have explicit cloud/device-transfer backup rules. The integration test covers menu pause/resume, Flutter lifecycle transitions, first-dispatch auto-save, and native audio pool readiness/playback on an Android 15 / API 35 emulator (`Busster_QA_API35`). The earlier manual tap and short FPS check were on `LLM_Clicker_API35`, a generic `sdk_gphone64_x86_64` emulator; its startup sample was around 60 fps. Neither emulator result is a physical-device performance result.

The competitive research below is a desk review of Google Play listings and a few public review excerpts. The current games have not yet been installed and played hands-on, and no outside player sessions have been run. The prototype has a first original, resolution-independent vector art pass and an original synthesized SFX pass; visual direction, audio mix, and accessibility still need player review. It has no analytics, ads, billing, production signing, or store-ready package. Local progress, unlocked depots, and hint credits save in Android private storage; the core game has no network dependency, and Android backup can transfer the allow-listed save and settings under the user's system settings. Do not treat the prototype or the revenue example as evidence that the game is ready to launch or will earn a particular amount.

| Workstream | Current evidence | Remaining gate |
| --- | --- | --- |
| Market and product | Four current Play listings reviewed; category overlap and monetization patterns recorded below. | Hands-on teardown of the reference and at least three peers; 10 first-time player sessions; prove an original mechanic. |
| Stage 1 playable slice | Ten levels with provisional teaching prompts, route/queue/bay rules, help dialog, hints, undo, dispatch animation, rider boarding/departure feedback, pause/resume and lifecycle handling, versioned deterministic replay, debug overlay, compact-viewport layout, unit/widget tests, level validation, CI workflow, API 36 debug build. Emulator integration covers pause/resume and first dispatch. | Player-review the teaching curve; test on two physical Android devices and with players. |
| Stage 2 content | Ten JSON depots load at runtime and pass schema, geometry, capacity, prompt, and complete state-graph analysis. A deterministic tool has generated 20 separate queue-order candidates; each passes complete solver analysis and remains unrated outside the app. Preview reports shortest solution, reachable/branching/no-win/dead-end states, shortest-path choices, opening buses, and junctions. Local save/resume, depot unlocks, earned-hint balance, and migrations pass tests; Android emulator smoke confirms auto-save. | Human review of levels and candidates, player-validated difficulty/teaching curve, completion time and solve rate, and 60–100 reviewed launch levels. |
| Production and business | Offline core, original vector art v1, and monetization guardrails are in place. | Player approval of the art and accessibility, production audio, analytics/retention evidence, consent, ads/billing, Play Console testing, and measured unit economics. |

## Market scan and product risk

Snapshot from Google Play listings reviewed on 11 October 2026. Listing install and review counts are store signals only: they do not reveal revenue, retention, acquisition cost, or profitability. Review excerpts are self-selected anecdotes, not a representative survey. Hands-on play is still required to verify the exact gameplay and ad cadence.

| Game | Public listing signals | What Bus-ster should take from it |
| --- | --- | --- |
| [Bus Fever Party!](https://play.google.com/store/apps/details?id=gridplus.busjam.carpuzzle) | Listing showed 1M+ downloads, about 18.6K reviews, ads and in-app purchases. It describes clearing traffic, matching passengers to buses, and boosters. A few visible reviews praised color distinction and criticized early difficulty, ad load, or short VIP pricing. | This validates visible category interest, not an open niche. Keep the early game readable and fair; verify reviews across a larger sample before changing the design. |
| [Bus Jam: Traffic Escape](https://play.google.com/store/apps/details?id=com.ashlabs.busjam) | Promotes solver-verified levels, offline play, color-blind-friendly colors, several themed worlds, optional reward ads, interstitials after level 15, and a no-ads purchase. | Solver validation, offline play, color accessibility, and optional ads are table stakes among direct peers; they are good quality requirements, not differentiation. |
| [Bus Go! Car Traffic Jam](https://play.google.com/store/apps/details?id=bus.go.car.jam.traffic) | Listing showed 5M+ downloads, about 63K reviews, ads and in-app purchases; it combines bus/car traffic puzzles, passenger matching, and boosters. A visible review alleges levels become pay/help dependent. | There is category scale, but no public revenue proof. Test solvability and ad fairness with players, and do not design difficulty around booster use. |
| [Bus Away: Traffic Jam](https://play.google.com/store/apps/details?id=com.fc.bus.away.traffic.jam) | Listing showed 1M+ downloads, about 32K reviews, ads and in-app purchases; it combines traffic, passenger pickup, parking, and power-ups. | The basic bus/traffic/passenger/booster loop is broadly repeated. Store art, title, level layouts, copy, and game feel need a distinct identity. |

**Positioning risk:** the current prototype also combines a shared exit, bus blocking, FIFO riders, and limited boarding bays. A visible road graph helps explain routes but may not be a strong enough reason to choose Bus-ster over existing games. During Stage 0, compare actual play and test one distinctive mechanic, such as a player-controlled junction signal that changes which road branch is open. Keep this as a hypothesis until first-time players understand it and prefer it in a small gray-box test; do not spend heavily on production art or user acquisition before that evidence.

**Revenue evidence:** public Play listings do not disclose competitor revenue. The model in Section 2 is an arithmetic scenario, not an estimate for this product. “Decent revenue” depends on finding and retaining a large enough audience at a net contribution margin that exceeds acquisition and operating costs. Validate retention, ad tolerance, conversion, and country-level net revenue in a small test before buying installs.

**Working-title check:** Play currently lists [Busster](https://play.google.com/store/apps/details?id=com.colixsystems.android.busster), a Swedish business workflow app, rather than a bus puzzle game. That is a near-name collision and a discoverability risk, even though the category differs. Keep “Bus-ster” provisional until a proper trademark, domain, and Play title search is done; this listing search is not legal clearance.

## 1. Product decision

Build a polished, original, single-player, portrait-mode **bus dispatch puzzle** for Android. A player untangles buses, chooses which one can reach a departure bay, and boards the visible passenger queue. Short, readable puzzles and satisfying dispatch animations are the core value. The first release should work offline, start quickly on midrange phones, and be fun without paying or watching ads.

**Reference, not source material.** [Bus Fever Party! on Google Play](https://play.google.com/store/apps/details?id=gridplus.busjam.carpuzzle) describes tapping buses to clear a jam, matching passengers to buses, and using boosters. Its public reviews include praise for distinguishable colors and complaints about early difficulty, ad load, and expensive VIP parking. These are directional signals, not a statistically valid survey. Play the current app and at least three competing bus jam games during Stage 0 to confirm precise rules, pacing, and gaps. Do not copy its levels, screenshots, UI layout, icon, audio, store copy, or name. The [US Copyright Office](https://www.copyright.gov/register/tx-games.html) distinguishes game methods from protected expression, and [Google Play's IP policy](https://support.google.com/googleplay/android-developer/answer/9888072) requires rights to app and listing content. Have the final title and icon checked for confusing similarity before store submission.

### Player promise and differentiation

- One-thumb play: most levels take 1–3 minutes; a failed move is explained immediately.
- **Readable dispatch:** each bus has both a color and a high-contrast route symbol; passenger groups use the same pair. A monochrome mode is viable from day one.
- **Route cards:** optional, limited special objectives (for example, send a bus through a marked depot lane) add planning depth after the basic loop is proven. Keep the launch rule set small.
- **Fair recovery:** undo and a limited earned hint path exist without a purchase. Rewarded ads only offer extra convenience.
- **Original presentation:** a small, bright city depot, distinct bus silhouettes, clear movement arcs, and restrained sound/haptics. Avoid the competitor's layouts and visual language.

**Audience hypothesis:** people who enjoy short, one-thumb visual logic puzzles about traffic, ordering, and route planning. Recruit adults unfamiliar with the genre for the first usability rounds; decide age rating and any child-directed features only after content and privacy review.

**Visual directions to compare:** (A) bright, flat transit-map depot with bold route signs; (B) miniature paper-and-enamel bus terminal with subtle depth; (C) high-contrast evening depot with luminous route markings. The current implementation is an initial evening-depot candidate with layered urban façades, enamel buses, pale lane markings, and a warm gate; players have not compared it with alternatives. Measure route and symbol readability before locking the art direction. The first-10 teaching sequence and playtest protocol are in [`docs/STAGE_0_FIELDWORK.md`](docs/STAGE_0_FIELDWORK.md).

### Current gray-box rules (still a design hypothesis)

1. Each depot is a grid of road nodes and blocked yard tiles, a shared gate, a small number of boarding bays, and a visible FIFO rider queue. Each bus has a route color and symbol, a fixed road node, and a seat capacity.
2. Tap a bus. The rules engine finds an unblocked path over connected road nodes to the gate. A blocked bus remains in place and explains the issue without spending currency or a life.
3. A dispatched bus occupies a bay and boards matching riders only from the head of the FIFO queue. A full bus leaves and frees the bay. The player chooses bus order to avoid filling bays with buses that cannot serve the next rider.
4. Win when all riders are boarded and all buses have left. After a move, the bounded solver checks for a complete route; if none remains, offer undo/retry and explain the stuck state.
5. Keep the rules core in plain Dart; animation follows a state transition. The exact network, queue behavior, capacities, and bay pressure remain **design hypotheses** until hands-on teardown and player testing.

## 2. Scope and commercial strategy

### Launch scope

| In v1 | Later only if metrics justify it |
| --- | --- |
| 60–100 authored/verified levels in 4 difficulty bands; daily challenge from a seeded library; save/resume; undo; earned hints; settings; accessible color/symbol system; analytics; crash reporting; opt-in rewarded ads; a modest ad-removal purchase | Hundreds of procedural levels, live events, leaderboards/achievements, cloud save, subscriptions, multiple cities, multiplayer, complex 3D |

Do not build an online backend for the core game. Store progress locally with versioned migrations. Add cloud accounts only if cross-device demand is demonstrated. Keep the first 10 levels ad-free and make the first session playable before any account, consent prompt that is not required, or store offer. Any ad experiment must preserve puzzle clarity and completion rates.

### Revenue design

1. **Primary:** opt-in rewarded video for an extra hint or undo after a fair free allowance. The prototype starts with three Route Tips, grants one on each depot’s first clear, and caps the balance at five. Treat these defaults as hypotheses to test, and keep solving possible without an ad. State the reward before the ad; grant it from the reward callback and prevent duplicate grants.
2. **Secondary:** a single permanent “remove forced ads” product, if interstitials are introduced. Purchases must be restored; rewarded ads can remain optional if clearly explained. Start the soft launch with rewarded ads only.
3. **Optional after evidence:** restrained interstitials after a results screen, never during play, at level start, or in the first session. Frequency cap and disable remotely if retention drops. Google Play [restricts unexpected full-screen ads](https://support.google.com/googleplay/android-developer/answer/9857753); follow its policy and test actual flows.
4. **Avoid initially:** expensive short-lived VIP products, energy timers, deliberately impossible levels, pay-gated bays, and subscriptions without continuing value. They can improve near-term spend at the cost of trust and retention.
5. Use [Google Play Billing for digital goods](https://support.google.com/googleplay/android-developer/answer/10281818) through Flutter's [in_app_purchase](https://pub.dev/packages/in_app_purchase). Verify entitlements, handle pending/cancelled/refunded transactions, acknowledge purchases, and use Play's license testers. Localized prices come from Play, not hardcoded strings.

**Illustrative unit economics, not a revenue forecast.** Use realized eCPM and actual Play payouts after launch. This example assumes 10,000 daily active users (DAU), 40,000 monthly active users (MAU), 0.6 rewarded impressions per DAU per day at $6 eCPM, 0.25 interstitial impressions at $3 eCPM, 1% of MAU buying $5 of digital goods in a month, and a placeholder 20% store/tax/refund deduction on IAP. Ads: `10,000 × (0.6×6 + 0.25×3) ÷ 1,000 × 30 = $1,305/month`. IAP: `40,000 × 1% × $5 × 80% = $1,600/month`. Combined **$2,905/month before acquisition, server/tools, content, support, and income taxes**. With rewarded only, the ad portion is $1,080/month under the same assumptions. Geography, fill, consent, retention, and ad load can change this sharply. “Decent revenue” requires both scale and positive lifetime value after costs; do not purchase installs until measured contribution margin per acquired user exceeds acquisition cost with a safety margin.

| Operating target (hypothesis, to revise in soft launch) | Why it matters |
| --- | --- |
| Tutorial completion ≥ 80%; first 10 levels completion without paid help ≥ 70% | Proves the game teaches rather than traps players |
| D1 retention ≥ 35%, D7 ≥ 10%, D30 ≥ 4% in a stable cohort | Baseline for sustainable discovery; these are internal gates, not claimed industry benchmarks |
| Crash-free users ≥ 99.5%; ANR rate trending down; 60 fps on target midrange devices | A playable, reviewable product |
| Rewarded ad opt-in without a fall in D7 retention; purchases/refunds tracked | Monetization adds value without wrecking the game |
| 30-day contribution LTV/CAC ≥ 1.3 before scaling paid acquisition | Avoids buying revenue at a loss; use longer LTV only when observed |

For each cohort and geography, track DAU/MAU, sessions/user, level attempts and solve rate, stuck/retry/undo/hint use, D1/D7/D30 retention, ad availability/show/reward, ad ARPDAU, IAP conversion, refunds, net revenue, support themes, and install source. Instrument events with a stable schema (`level_start`, `move`, `level_fail`, `level_complete`, `hint_use`, `ad_offer`, `ad_reward`, `purchase_*`) and version it. Never put personal data in event names or parameters.

## 3. Technical architecture and tools

### Recommended stack

| Need | Choice and reason | When |
| --- | --- | --- |
| App shell, UI, Android build | Flutter stable, Dart, Material widgets for menus/settings, Android Studio and SDK. Flutter's [Casual Games Toolkit](https://docs.flutter.dev/resources/games-toolkit) explicitly supports this class of puzzle and provides samples. | Stage 1 |
| Board rendering/input/animation | [Flame](https://docs.flame-engine.org/latest/), embedded with `GameWidget`; 2D components, sprites, tap input, effects. Keep puzzle logic in plain Dart, independent of Flame. Avoid physics/Forge2D unless a tested mechanic needs it. | Stage 1 |
| Level authoring | Canonical versioned JSON pack at `assets/levels/levels.json`, strict Dart codec, solver-backed batch validator, generated HTML preview, deterministic mirror variants, and seeded FIFO queue-order candidates. Keep generated candidates separate until they pass human review. Tiled is optional only if map geometry becomes complex. | Stage 2: schema, runtime loading, validator, preview, mirror helper, and seeded queue candidate generator implemented; 10 authored depots and 20 unreviewed candidates exist; content scale and human review remain open |
| Local state | Versioned JSON in Android's private files directory via [`path_provider`](https://pub.dev/packages/path_provider) for the small progress record; writes use a validated same-directory temporary file and last-good backup, with migration/recovery tests. Use [`shared_preferences`](https://pub.dev/packages/shared_preferences) `SharedPreferencesAsync` with the Android DataStore backend only for simple settings, not critical progress. Android cloud/device-transfer backup is explicitly allow-listed to the current progress file, last-good copy, and `files/datastore/FlutterSharedPreferences.preferences_pb`. Move to SQLite only if saved data outgrows this format. | Stage 2: progress persistence, depot unlocks, and earned-hint balance implemented; Stage 3: Android backup rules configured and release-manifest verified; restore testing on real devices remains open |
| Audio/haptics | [`audioplayers`](https://pub.dev/packages/audioplayers) 6.7.1 `AudioPool` preloads four short, locally bundled original PCM WAV cues for dispatch, boarding, depot clear, and stuck feedback; `PlayerMode.lowLatency` is used for short effects. The release-independent `GameAudio` adapter keeps audio optional/offline and easy to fake in tests. Sound and platform haptics have separate persisted switches. The app's Flutter 3.41.6 / Dart 3.11.4 toolchain cannot use the newer 6.8.1 SDK constraint, so keep 6.7.1 until the SDK is upgraded and rechecked. | Stage 3: code/assets and emulator integration implemented; physical latency, loudness, audio-focus behavior, and player mix review remain open |
| Observability | [Firebase Analytics](https://firebase.google.com/docs/analytics/flutter/get-started), [Crashlytics](https://firebase.google.com/docs/crashlytics/flutter/get-started), [Remote Config](https://firebase.google.com/docs/remote-config/flutter/get-started). Put each behind an adapter so the core works offline and in tests. | Stage 4: gameplay event contract and no-op adapter are implemented; SDK setup, consent, dashboards, and alerts remain gated. |
| Ads | Official [google_mobile_ads](https://docs.flutter.dev/cookbook/plugins/google-mobile-ads) with Google test IDs during development. UMP consent flow and privacy review before production requests. Mediation is a later optimization after a baseline. | Stage 5 |
| Billing | Official Flutter [in_app_purchase](https://pub.dev/packages/in_app_purchase), Play product catalog, entitlement verification, restore/refund handling. | Stage 5 |
| Optional social | [Play Games Services](https://developer.android.com/games/pgs/start) for achievements/leaderboards only after retention evidence; verify any Flutter bridge uses PGS v2 because [v1 is being retired](https://developer.android.com/games/pgs/deprecation). | Post-launch |
| Quality/release | `flutter analyze`, `flutter test`, integration tests on emulator and real devices, Flutter DevTools, Android Studio profiler, GitHub Actions, Play internal/closed tracks. | Every stage |
| Art production | Inkscape/Krita for 2D originals; Blender only if prerendered 2.5D buses are chosen. Maintain an asset provenance/licensing ledger. | Stages 0–3 |

**Local environment checked:** Flutter 3.41.6, Dart 3.11.4, Android SDK 36 and Android Studio are installed. `flutter doctor -v` reports some Android SDK licenses not accepted. The debug APK built successfully, but the developer still needs to review/accept the applicable terms with `flutter doctor --android-licenses` before release work. Check plugin compatibility and select current stable package versions at implementation time; do not pin versions based on this planning snapshot.

The built APK reports `minSdkVersion 24` and `targetSdkVersion 36`. Proposed QA profiles are (1) minimum API 24 for install/start/basic rules compatibility, (2) a low-cost Android 13 / API 33 phone with about 3–4 GB RAM and a 720p display, and (3) a current Android 16 / API 36 phone with about 6–8 GB RAM and a 1080p or higher display. Confirm the final support floor using expected launch-market device data and plugin requirements; run physical touch, background/resume, frame-time, and thermal checks before release. The current generic API 35 emulator covers none of the low-end physical-device risks.

### Module boundaries

```text
lib/
  app/                 navigation, settings, accessibility, localization
  game/domain/         immutable BoardState, commands, legal moves, win/loss, solver
  game/content/        level parser, schema, generated/authored packs
  game/presentation/   Flame components, effects, input-to-command mapping
  services/            save, analytics, ads, billing, remote config adapters
  ui/                  home, level map, results, shop, consent/help
assets/                original sprites, audio, fonts, level packs
test/                  rules and level validation
integration_test/      first-session, save/resume, ads/IAP test doubles
tools/                 level validator, generator, replay and metrics scripts
```

Use a pure `apply(BoardState, Command) -> Result<BoardState, GameEvent>` function. Keep a seed and command log so any bug report can replay a level deterministically. Define stable level IDs and a format version; bundle launch levels locally. The canonical schema is documented in [`docs/LEVEL_SCHEMA.md`](docs/LEVEL_SCHEMA.md). The versioned bundle stores stable ID, title, dimensions, road coordinates, exit, bay count, bus ID/route/position/capacity, passenger queue, tutorial prompt, provisional difficulty band, mechanic tags, and optional seed. Solver-derived data such as a solution route and move depth appears in the preview rather than being trusted as authored truth. The runtime loader reads this same asset; the animation layer never defines puzzle state. Validate no overlapping pieces, valid roads/routes, legal capacities, a complete solution, and no soft lock without an undo path.

### MCPs for development (not runtime game dependencies)

MCP servers help the team **build and operate** the game; the Android app should not ship an MCP server or depend on an AI connection to play. Configure only the tools needed for a task, scope access to this repository/project, and keep tokens and service credentials out of Git.

| MCP | Practical use | Decision |
| --- | --- | --- |
| Official [Dart/Flutter tooling MCP](https://dart.googlesource.com/ai/+/HEAD/pkgs/dart_mcp_server/README.md) (`dart mcp-server`) | Analyze/format code, search pub.dev, run tests, inspect widget/runtime errors and screenshots, and hot reload. Pair with CLI and DevTools. | A repository-scoped VS Code entry is in `.vscode/mcp.json`, and `dart mcp-server --help` works in this environment. The full IDE MCP handshake still needs verification. Development only; never a game runtime dependency. |
| Official [Firebase MCP](https://firebase.google.com/docs/ai-assistance/mcp-server) | Inspect Firebase project/configuration, rules, and Crashlytics issues once Firebase exists. | Stage 4 only, with a separate dev project and least privilege. Not configured; no Firebase project exists. |
| Official [GitHub MCP](https://github.com/github/github-mcp-server) or the available GitHub connector | Read issues/PRs, triage bugs, and link milestones to code. | Optional when issue tracking starts. Use least privilege; normal Git and GitHub Actions already cover source control and CI. |
| [Blender MCP](https://www.blender.org/lab/mcp-server/) | Optional generation/inspection of Blender scenes for prerendered original sprites. | Only if Blender art is chosen. It executes generated Python without guards; use a disposable asset workspace and inspect outputs before importing. Not configured. |
| Play Console / AdMob administration | Product IDs, store listing, testing tracks, policy and revenue data. | Use official UIs/APIs and human review; **do not adopt an unverified third-party MCP** with publishing or payment access. |

## 4. Stepwise delivery plan

Estimated elapsed time for a small team: **12–16 weeks**, with art/content running alongside engineering. Each stage has a deliverable and a gate; fail a gate, fix it before adding scope.

### Stage 0 — competitive teardown and product brief (week 1)

- [x] Review current Play listings for Bus Fever Party! and three genre peers; record advertised mechanics, public scale signals, monetization and a small number of review themes in the Market Scan above. This is desk research only.
- [ ] Install and play the current Bus Fever Party! and at least three genre peers. Record the first 30 minutes, levels 1–20 progression, exact movement/boarding rules, bay behavior, fail states, booster economy, ad placements, shop, accessibility, and store positioning. Keep recordings private as research; copy no assets or levels.
- [x] Draft the original product decision and provisional rules in Section 1, add an optional in-game rules-help dialog, and prepare an audience hypothesis, three visual directions, and a first-10 teaching sequence. The audience, visual direction, and final differentiator still need to be settled through playtests.
- [x] Prepare the 10-session protocol and anonymized notes table in [`docs/STAGE_0_FIELDWORK.md`](docs/STAGE_0_FIELDWORK.md); the sessions themselves have not run.
- [x] Start the asset/license ledger in [`docs/ASSET_LEDGER.md`](docs/ASSET_LEDGER.md). Final art and icon provenance are pending.
- [x] Search Play for title collisions and record the existing Busster business app above. A full trademark/domain check and final icon/title decision remain pending.
- [ ] Confirm the target device matrix: small/large phone, low/mid/high GPU, Android versions supported by current plugins; establish memory and APK/AAB size budgets. Generic and Pixel 6 Android 15 / API 35 emulator profiles have been used, but no physical devices; the device matrix and budgets remain open.
- **Exit:** written final rules and at least one genuinely differentiated mechanic; ≥ 8/10 participants can explain the core objective after the tutorial without coaching. **Not met:** hands-on teardown and external playtests are still open.

### Stage 1 — playable vertical slice (weeks 2–4)

- [x] Create the Flutter Android scaffold. Portrait orientation, `Bus-ster` label, application ID `com.busster.busster`, Android target API 36, and compatible Flutter/Flame dependencies are set. Confirm the application ID is available to the team before Play Console setup; the current APK uses debug signing.
- [x] Implement the pure-Dart state/rules model, queue/boarding, bay occupancy, win/stuck detection, undo, and deterministic replay. Versioned JSON replay records store dispatch IDs, replay through the rules engine, and stay in sync with Undo; unit tests verify the reproduced state.
- [x] Finish the responsive Stage 1 board with color + symbol labels, touch outcome feedback, move/board/leave feedback, pause/resume, and safe areas. Dispatch feedback reports rider and bus counts, bay and objective changes animate, a pause overlay blocks play, and the Flame engine pauses when the app is inactive. A compact 320×568 layout has a widget check.
- [x] Hand-author 10 playable levels and validate them with the bounded solver and batch validator. Each has a provisional first-session prompt, but the ten prototypes are not yet reviewed as a three-tutorial/four-easy/three-medium teaching curve. A debug overlay exposes solver output and route legality; serialized level JSON and a preview/editor remain open.
- [ ] Test touch accuracy, stable 60 fps, cold loading, and background/foreground behavior on two real Android phones. Emulator integration verifies first dispatch, menu pause/resume, and Flutter lifecycle transitions; the short startup FPS sample around 60 fps came from a separate generic emulator. Physical-device checks remain open; the team currently has no test phones or player participants available.
- **Exit:** 10 complete levels, no unsolvable states in validation, no blocker that requires a payment/ad, first level playable within 10 seconds on target devices. **Partial:** 10 levels and solver validation are present; tutorial mapping, real-device/player QA, and first-level timing gates remain.

### Stage 2 — content pipeline and difficulty (weeks 4–6)

- [x] Build a bounded BFS solver to verify levels and return a next-dispatch hint. It currently stops after 100,000 examined states; the ten prototype levels all solve. State canonicalization and more diverse rule coverage remain future work.
- [x] Add a versioned JSON level bundle, strict codec, runtime asset loading, batch validation, and generated HTML preview. The pack is the canonical source; solver checks run before the app or validator accepts it.
- [x] Add a deterministic horizontal/vertical mirror helper that emits separate candidate files and verifies each candidate with the solver. Generated layouts still require human review before joining the authored pack.
- [x] Add a reproducible seeded queue-order candidate generator. It preserves each authored board and route capacities, shuffles the FIFO rider queue with a specified PRNG, rejects duplicate/unsolved candidates, and writes candidates outside the shipping level pack. Twenty seed-20261011 candidates currently pass complete solver analysis; all are marked unrated and still require layout/prompt edits and player review before release.
- [x] Add provisional mechanic tags and difficulty bands to the first 10 depots; the preview reports shortest solution, reachable states, legal/branching choices, no-win/dead-end states, and road junctions.
- [ ] Validate the teaching curve with players; record observed completion time and solve rate. Structural solver metrics do not establish perceived difficulty. Create 60–100 launch levels across four bands; ensure first 20 introduce one idea at a time.
- [x] Add local save/resume, schema-v0/v1 migration, last-good backup recovery, damaged-save handling, future-schema read-only protection, and an offline core. Unit tests cover save recovery/migration; Android emulator integration confirms auto-save after dispatch.
- [x] Add an ordered depot picker that unlocks one depot per clear, and persist an earned-hint balance. New saves start with three Route Tips; each depot’s first clear earns one, capped at five. Warn before switching away from an unfinished attempt; retries, Undo, and solver tips stay local and ad-free.
- [ ] Playtest weekly with 15–20 new testers; tune spike levels from data and recordings. Put hard puzzles after a confidence-building run.
- **Exit:** every launch level has a known solution and passed human QA; target tutorial and early completion rates from Section 2 are met in tests.

### Stage 3 — production feel and accessibility (weeks 6–8)

- [x] Create the first original, resolution-independent vector art set in Flutter Canvas and CustomPainter: directional enamel buses, small passenger silhouettes with route marks, building façades, paved roads, an exit/crosswalk, motion traces, and bay/bus indicators. The v1 uses runtime vector drawing, so it has no bitmap atlas to export. Sources and asset status are recorded in [`docs/ASSET_LEDGER.md`](docs/ASSET_LEDGER.md); emulator screenshot review and the dispatch integration test pass, while visual direction and player/accessibility review remain open below.
- [x] Establish a typography hierarchy using Android's platform sans-serif through Flutter Material styles; no custom font file is bundled. System text scaling remains supported and the core controls pass the compact 1.5× text-size widget check.
- [x] Replace the Flutter template launcher icon with a custom native vector bus mark, including adaptive and legacy Android variants; match the launch-screen background and record provenance in the asset ledger. Verify launcher masks and cold start on physical devices before release.
- [x] Add a pause-screen settings panel with persisted Haptics, Sound effects, and Reduce motion switches. Haptics fire only after successful dispatch; reduced motion skips bus travel animations. Widget tests cover preference loading/saving, independent controls, and live motion changes; Android emulator integration confirms the reduced-motion path. Physical haptic feel and device-matrix checks remain open because no test phones are available.
- [x] Distinguish depot-clear and stuck states with status-colored feedback; let players undo a stuck move or retry. A widget test reproduces the full-bay trap and confirms Undo recovers.
- [x] Add four original, locally synthesized WAV effects for dispatch, boarding, depot clear, and stuck feedback; record the reproducible generator and provenance in [`docs/ASSET_LEDGER.md`](docs/ASSET_LEDGER.md). Bundle them for offline `audioplayers` low-latency playback, stop them on pause/background, and add separate persisted Sound effects and Haptics switches. Widget tests cover sound routing, sound-off behavior, and independent preferences; Android integration runs the native audio adapter on the API 35 emulator. Sound mix/loudness, physical-device latency, audio-focus behavior, and player review remain open because there are no physical phones or testers.
- [x] Replace font glyphs with platform-independent vector route shapes in the bus, rider queue, and bay views; add screen-reader labels to queued riders and parked buses. Widget tests check route shapes and rider labels.
- [ ] Verify color-vision readability through contrast checks, grayscale screenshots, and player sessions. Confirm every rule-critical object remains distinguishable without color.
- [x] Check the core controls at 1.5× system text size in the compact 320×568 layout. Repeat the text and layout review on physical Android devices when available.
- [x] Keep the help dialog and pause-screen settings available; draft a source-checked privacy data inventory for the current prototype in [`docs/PRIVACY_POLICY_DRAFT.md`](docs/PRIVACY_POLICY_DRAFT.md).
- [x] Configure Android Auto Backup for only the current progress file, last-good copy, and DataStore settings file, with legacy and Android 12+ rules; inspect the release manifest. Backup restore still needs real-device verification. Record the OS-managed cloud/device transfer behavior in the internal privacy draft.
- [ ] Complete publisher/support details, verify backup restore on physical Android devices, publish and link the final privacy policy in-app/Play Console, and prepare localization-ready strings. Localize only markets that can be QA'd.
- [ ] Measure frame times, memory, battery/thermal behavior, cold start, and AAB size on the device matrix; optimize overdraw and oversized textures.
- **Exit:** stable, understandable, accessible build with no placeholder art and no device-specific blocker.

### Stage 4 — analytics and retention loop (weeks 8–10)

- [x] Define stable gameplay events and a provider adapter; instrument starts, dispatch outcomes, tips, undo, restart, completion, and stuck states. The default adapter is a no-op and stores/sends nothing. See [`docs/ANALYTICS_EVENT_SCHEMA.md`](docs/ANALYTICS_EVENT_SCHEMA.md).
- [ ] Integrate Firebase Analytics and Crashlytics through the adapter after Firebase project setup and a consent/privacy review. Add consent flow, dashboard, crash/ANR alerts, and source/version fields.
- [ ] Add a daily challenge from a vetted seeded level library, gentle streak display without punishment, and a route-map progression that rewards completion rather than ad consumption.
- [ ] Add Remote Config with bundled safe defaults for difficulty order, ad caps, and feature flags; protect against invalid remote values. Do not make a core puzzle unsolvable remotely.
- [ ] Run an internal test cohort; evaluate tutorial funnel, D1/D7, solve rates, failure reasons, and qualitative enjoyment. Fix the three biggest friction points.
- **Exit:** analytics agree with manual test events, crashes are symbolicated, game remains fully usable offline, and retention gates are plausible without ads.

### Stage 5 — monetization with guardrails (weeks 10–11)

- [ ] Set up AdMob app and **test** ad units, UMP consent flow where required, privacy options entry, ad load timeout/retry, reward deduplication, and offline fallback. Use production units only after app/ad readiness and policy checks. Google documents [rewarded ads](https://developers.google.com/admob/flutter/rewarded) and [consent](https://developers.google.com/admob/flutter/privacy).
- [ ] Offer a rewarded hint/undo only after the normal free path is visible. Never force an ad to finish the tutorial or a level. Test reward callbacks, failed loads, app resume, and repeated taps.
- [ ] Set up one permanent ad-removal product in Play and Billing test track. Verify purchase tokens/entitlements, acknowledge/restore/revoke states, and retain receipts or a minimal verification service if fraud exposure warrants it. Follow current [Billing guidance](https://developer.android.com/google/play/billing).
- [ ] Run a small randomized soft-launch experiment: rewarded-only baseline vs a conservative post-results interstitial variant, with a kill switch. Measure D1/D7, level completions, ad ARPDAU, complaints, and total revenue; revert if experience degrades.
- [ ] Publish `app-ads.txt` on a developer-controlled site before full ad serving, as required by the [Flutter AdMob recipe](https://docs.flutter.dev/cookbook/plugins/google-mobile-ads).
- **Exit:** purchases restore and refunds revoke properly, ad rewards grant exactly once, consent and privacy disclosures match SDK behavior, and measured retention is not harmed.

### Stage 6 — Android release preparation (weeks 11–13)

- [x] Build and inspect local release-profile artifacts: API 36 target, API 24 minimum, no `INTERNET` permission in the merged release manifest, and the configured backup-rule resources in the AAB. The universal APK is 45.0 MB and the AAB is 39.3 MB; both use the debug signing key and are validation builds only.
- [ ] Target **Android 16 / API 36 or higher** for new Google Play submissions under the rule effective 31 August 2026; recheck policy before upload. Build a signed `.aab`, configure Play App Signing, confirm final permissions and download size, and keep upload keys outside Git. [Target API policy](https://support.google.com/googleplay/android-developer/answer/11926878), [App Bundle](https://developer.android.com/guide/app-bundle), [signing](https://developer.android.com/studio/publish/app-signing).
- [ ] Create Play Console app, content rating, target audience, privacy policy, Data safety declaration (including all SDK collection), ads declaration, app access, store text/screenshots, and support channel. Avoid listing claims not present in game. [Data safety guidance](https://support.google.com/googleplay/android-developer/answer/10787469).
- [ ] Run `flutter analyze`, unit/integration tests, device matrix QA, TalkBack/text scaling checks, ad/IAP test flows, offline and airplane-mode tests, and Play pre-launch report. Fix ANRs and crashes.
- [ ] Release to internal then closed testing. If the developer account is a new personal account, Play currently requires **12 continuously opted-in testers for 14 days** before production access; confirm account eligibility in Play Console. [Testing requirement](https://support.google.com/googleplay/android-developer/answer/14151465).
- [ ] Freeze content and create release notes, rollback plan, support FAQ, and incident owner. Do not upload signing material or service-account secrets to the repository.
- **Exit:** Play checks pass, stable closed-test cohort, policies and disclosures reviewed, support process ready.

### Stage 7 — soft launch, decision, and scale (weeks 13–16+)

- [ ] Roll out to one or two markets with manageable support and representative devices. Budget organic channels first: distinctive store creative, short gameplay clips from original levels, creator outreach with disclosure, and community feedback.
- [ ] Read 7-day cohorts weekly, separate by country and acquisition channel. Prioritize retention and level friction before tuning ads. Compare actual net ARPDAU/LTV with the model above.
- [ ] Start small paid user-acquisition tests only after a stable D7 signal; record CPI, attributed retention, incremental installs, and contribution LTV. Pause spending when unit economics are negative or attribution is unclear.
- [ ] Ship a weekly content/quality cadence: validate levels, stage with Remote Config, monitor crashes, review complaints/refunds, and publish clear notes. Add mediation, more purchases, or social features only with a specific measured reason.
- **Exit:** move to broader launch only when gameplay and reliability gates are met and at least one acquisition path shows sustainable contribution margin. Otherwise continue iteration or reduce scope.

## 5. Immediate next actions

1. Use Android emulators for repeatable layout, flow, art, and backup-rule build checks now. When Android phones and adult participants become available, install/play the reference and at least three peers, then run the 10 gray-box sessions in [`docs/STAGE_0_FIELDWORK.md`](docs/STAGE_0_FIELDWORK.md). Resolve whether a route-switch mechanic and the current visual direction are understandable and distinctive before locking the game design; emulators cannot establish real-player comprehension or OEM backup/restore behavior.
2. Complete the remaining vertical slice gates: playtest the provisional first-10 prompts and difficulty curve, then verify comprehension and performance on two physical Android devices with players. Boarding/departure feedback, pause/resume, lifecycle handling, replay records, and the debug overlay are implemented.
3. Continue the Stage 2 content pipeline: human-review the ten current layouts and mirrored candidates, measure teaching and solve data when testers are available, and expand the authored pack only after solver and human QA. Local progress, depot unlocks, earned hints, and migrations are implemented and tested.
4. Keep the app offline and ad-free while testing; add production art, analytics, ads, and billing only at their stage gates, and judge revenue from measured cohort and acquisition data.
5. Treat this file as the milestone checklist; track stage gates with concrete acceptance evidence and update assumptions after each playtest.

## Source notes

Primary references used for this plan: [Bus Fever Party! listing](https://play.google.com/store/apps/details?id=gridplus.busjam.carpuzzle); [Flutter Casual Games Toolkit](https://docs.flutter.dev/resources/games-toolkit); [Flame documentation](https://docs.flame-engine.org/latest/); [path_provider](https://pub.dev/packages/path_provider) and [shared_preferences](https://pub.dev/packages/shared_preferences); [Flutter ads](https://docs.flutter.dev/cookbook/plugins/google-mobile-ads) and [IAP package](https://pub.dev/packages/in_app_purchase); [Google Play ads policy](https://support.google.com/googleplay/android-developer/answer/9857753), [target API](https://support.google.com/googleplay/android-developer/answer/11926878), [testing](https://support.google.com/googleplay/android-developer/answer/14151465), [data safety](https://support.google.com/googleplay/android-developer/answer/10787469), and [IP](https://support.google.com/googleplay/android-developer/answer/9888072); [Firebase MCP](https://firebase.google.com/docs/ai-assistance/mcp-server); [Dart tooling MCP](https://dart.googlesource.com/ai/+/HEAD/pkgs/dart_mcp_server/README.md); [GitHub MCP](https://github.com/github/github-mcp-server); [Blender MCP](https://www.blender.org/lab/mcp-server/). Recheck mutable store policies, SDK support, fees, and tool commands at the stage where they are used.
