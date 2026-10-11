# Bus-ster — staged Android game plan

_Updated: 11 October 2026. Owner: Bus-ster team. Status: prototype in progress; Stage 0 research and Stage 1 device/player gates remain open._

## Current progress snapshot — 11 October 2026

This is an active build plan, not a release-ready game. The repository now contains a Flutter/Flame Android prototype with 10 hand-authored depots, a pure-Dart rules model, a bounded breadth-first solver, a level validator, hint/undo/retry, an animated dispatch, an optional rules-help dialog, five passing tests, a GitHub Actions workflow, and a successful debug APK build. The prototype was installed and tapped through on the Android 15 / API 35 emulator `LLM_Clicker_API35` (generic `sdk_gphone64_x86_64`). One visual alignment issue was fixed during that check. A short emulator FPS sample was around 60 fps after startup; this is not a physical-device performance result.

The competitive research below is a desk review of Google Play listings and a few public review excerpts. The current games have not yet been installed and played hands-on, and no outside player sessions have been run. The art is placeholder vector drawing; there is no save system, analytics, ads, billing, production signing, or release package. Do not treat the prototype or the revenue example as evidence that the game is ready to launch or will earn a particular amount.

| Workstream | Current evidence | Remaining gate |
| --- | --- | --- |
| Market and product | Four current Play listings reviewed; category overlap and monetization patterns recorded below. | Hands-on teardown of the reference and at least three peers; 10 first-time player sessions; prove an original mechanic. |
| Stage 1 playable slice | Ten levels, route/queue/bay rules, help dialog, hints, undo, dispatch animation, unit/widget tests, level validation, CI workflow, API 36 debug build, emulator touch smoke. | Tutorial teaching sequence, replay/debug support, fuller feedback and pause/resume; test on two physical Android devices and with players. |
| Stage 2 content | Bounded BFS solver returns a dispatch sequence; all 10 depots pass the validator. | JSON/schema and preview tool, generator, save/resume and migrations, and a human-tested launch content set. |
| Production and business | Offline core and monetization guardrails are planned. | Original production assets, analytics/retention evidence, consent, ads/billing, Play Console testing, and measured unit economics. |

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

**Visual directions to compare:** (A) bright, flat transit-map depot with bold route signs; (B) miniature paper-and-enamel bus terminal with subtle depth; (C) high-contrast evening depot with luminous route markings. The current dark board is placeholder rendering, not a final art decision. Measure route and symbol readability before investing in the chosen direction. The first-10 teaching sequence and playtest protocol are in [`docs/STAGE_0_FIELDWORK.md`](docs/STAGE_0_FIELDWORK.md).

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

1. **Primary:** opt-in rewarded video for an extra hint or undo after a fair free allowance. State the reward before the ad; grant it from the reward callback and prevent duplicate grants.
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
| Level authoring | Versioned JSON or Dart data + schema validation, small in-repo editor/preview, solver and batch validation. Tiled is optional only if map geometry becomes complex. | Stages 1–2 |
| Local state | `shared_preferences` for settings; a structured local store such as Isar/SQLite only if progress/history outgrows a small versioned file. Atomic writes and migration tests. | Stage 2 |
| Audio/haptics | `audioplayers` or `flutter_soloud` after latency/device tests; original or properly licensed SFX; platform haptics with off switch. | Stage 3 |
| Observability | [Firebase Analytics](https://firebase.google.com/docs/analytics/flutter/get-started), [Crashlytics](https://firebase.google.com/docs/crashlytics/flutter/get-started), [Remote Config](https://firebase.google.com/docs/remote-config/flutter/get-started). Put each behind an adapter so the core works offline and in tests. | Stage 4 |
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

Use a pure `apply(BoardState, Command) -> Result<BoardState, GameEvent>` function. Keep a seed and command log so any bug report can replay a level deterministically. Define stable level IDs and a format version; bundle launch levels locally. The current prototype has a Dart `LevelSpec`, not the planned serialized format. A draft record should include `id`, `schemaVersion`, `width`, `height`, `roads` (grid coordinates), `exit`, `bayCount`, `buses` (id, position, route symbol/color, capacity), `passengerQueue`, `difficultyTags`, `seed`, and `solutionMetadata`. The schema and solver are the source of truth, not animation state. Validate no overlapping pieces, valid roads/routes, legal capacities, at least one solution, intended move depth, and no soft lock without an undo path.

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
- [ ] Confirm the target device matrix: small/large phone, low/mid/high GPU, Android versions supported by current plugins; establish memory and APK/AAB size budgets. So far only the generic Android 15 / API 35 emulator named above has been used.
- **Exit:** written final rules and at least one genuinely differentiated mechanic; ≥ 8/10 participants can explain the core objective after the tutorial without coaching. **Not met:** hands-on teardown and external playtests are still open.

### Stage 1 — playable vertical slice (weeks 2–4)

- [x] Create the Flutter Android scaffold. Portrait orientation, `Bus-ster` label, application ID `com.busster.busster`, Android target API 36, and compatible Flutter/Flame dependencies are set. Confirm the application ID is available to the team before Play Console setup; the current APK uses debug signing.
- [ ] Finish the pure-Dart command/state model, queue/boarding, bay occupancy, win/stuck detection, undo, and deterministic replay. Core rules and undo exist and are unit-tested; a replay log is not implemented.
- [ ] Finish a responsive Flame board with color + symbol labels, touch feedback, move/board/leave feedback, pause/resume, and safe areas. The board scales within a Flutter safe area and bus dispatch animates; boarding/departure feedback and pause/resume remain.
- [x] Hand-author 10 playable levels and validate them with the bounded solver and batch validator. The current ten are prototypes, not yet reviewed as a three-tutorial/four-easy/three-medium teaching curve. Level JSON, preview/editor, and an in-game debug overlay are not implemented.
- [ ] Test touch accuracy, stable 60 fps, cold loading, and background/foreground behavior on two real Android phones. Current evidence is one emulator smoke test and a short startup FPS sample only.
- **Exit:** 10 complete levels, no unsolvable states in validation, no blocker that requires a payment/ad, first level playable within 10 seconds on target devices. **Partial:** 10 levels and solver validation are present; tutorial, feedback, device, external playtest, and timing gates remain.

### Stage 2 — content pipeline and difficulty (weeks 4–6)

- [x] Build a bounded BFS solver to verify levels and return a next-dispatch hint. It currently stops after 100,000 examined states; the ten prototype levels all solve. State canonicalization and more diverse rule coverage remain future work.
- [ ] Build a level preview/editor and a reverse-construction generator or variant tool; never publish raw generated levels without solver and human play checks.
- [ ] Tag levels by mechanics, solution depth, branch count, traps, expected time, and observed solve rate. Create 60–100 launch levels across four bands; ensure first 20 introduce one idea at a time.
- [ ] Add save/resume, atomic progress migration, level selection, retry, earned hints, and a no-network path.
- [ ] Playtest weekly with 15–20 new testers; tune spike levels from data and recordings. Put hard puzzles after a confidence-building run.
- **Exit:** every launch level has a known solution and passed human QA; target tutorial and early completion rates from Section 2 are met in tests.

### Stage 3 — production feel and accessibility (weeks 6–8)

- [ ] Replace placeholders with owned original assets: buses, passenger groups, bays, roads, motion cues, icon, and typography. Export optimized atlases; document sources/licenses.
- [ ] Add animation, audio mix, haptics, win/lose feedback, reduced-motion option, sound/haptic toggles, and text scaling where applicable.
- [ ] Verify color-blind readability using symbols/patterns, contrast, grayscale screenshots, and real testers. Add text or shape cues to every rule-critical object.
- [ ] Build help, settings, privacy link placeholder, support contact, and localization-ready strings; ship at least clear English, then localize only markets that can be QA'd.
- [ ] Measure frame times, memory, battery/thermal behavior, cold start, and AAB size on the device matrix; optimize overdraw and oversized textures.
- **Exit:** stable, understandable, accessible build with no placeholder art and no device-specific blocker.

### Stage 4 — analytics and retention loop (weeks 8–10)

- [ ] Integrate Analytics and Crashlytics through adapters; review data collection and consent behavior. Add event schema, dashboard, crash/ANR alerts, and source/version fields.
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

- [ ] Target **Android 16 / API 36 or higher** for new Google Play submissions under the rule effective 31 August 2026; recheck policy before upload. Build a signed `.aab`, configure Play App Signing, and keep upload keys outside Git. [Target API policy](https://support.google.com/googleplay/android-developer/answer/11926878), [App Bundle](https://developer.android.com/guide/app-bundle), [signing](https://developer.android.com/studio/publish/app-signing).
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

1. Install/play the reference and at least three peers, then run 10 gray-box sessions. Resolve whether a route-switch mechanic is understandable and distinctive before locking the game design.
2. Complete the vertical slice gates: set the first 10 tutorial beats, add replay/debug support and boarding/departure feedback, verify pause/resume, and test two physical Android devices.
3. Build the Stage 2 authoring/save pipeline: serialized level schema, preview/editor, solver-backed validation, progress persistence/migration, then expand content only after human QA.
4. Keep the app offline and ad-free while testing; add production art, analytics, ads, and billing only at their stage gates, and judge revenue from measured cohort and acquisition data.
5. Treat this file as the milestone checklist; track stage gates with concrete acceptance evidence and update assumptions after each playtest.

## Source notes

Primary references used for this plan: [Bus Fever Party! listing](https://play.google.com/store/apps/details?id=gridplus.busjam.carpuzzle); [Flutter Casual Games Toolkit](https://docs.flutter.dev/resources/games-toolkit); [Flame documentation](https://docs.flame-engine.org/latest/); [Flutter ads](https://docs.flutter.dev/cookbook/plugins/google-mobile-ads) and [IAP package](https://pub.dev/packages/in_app_purchase); [Google Play ads policy](https://support.google.com/googleplay/android-developer/answer/9857753), [target API](https://support.google.com/googleplay/android-developer/answer/11926878), [testing](https://support.google.com/googleplay/android-developer/answer/14151465), [data safety](https://support.google.com/googleplay/android-developer/answer/10787469), and [IP](https://support.google.com/googleplay/android-developer/answer/9888072); [Firebase MCP](https://firebase.google.com/docs/ai-assistance/mcp-server); [Dart tooling MCP](https://dart.googlesource.com/ai/+/HEAD/pkgs/dart_mcp_server/README.md); [GitHub MCP](https://github.com/github/github-mcp-server); [Blender MCP](https://www.blender.org/lab/mcp-server/). Recheck mutable store policies, SDK support, fees, and tool commands at the stage where they are used.
