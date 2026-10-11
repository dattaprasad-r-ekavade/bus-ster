# Bus-ster — staged Android game plan

_Research and planning snapshot: 11 October 2026. Owner: Bus-ster team. Status: ready for Stage 0._

## 1. Product decision

Build a polished, original, single-player, portrait-mode **bus dispatch puzzle** for Android. A player untangles buses, chooses which one can reach a departure bay, and boards the visible passenger queue. Short, readable puzzles and satisfying dispatch animations are the core value. The first release should work offline, start quickly on midrange phones, and be fun without paying or watching ads.

**Reference, not source material.** [Bus Fever Party! on Google Play](https://play.google.com/store/apps/details?id=gridplus.busjam.carpuzzle) describes tapping buses to clear a jam, matching passengers to buses, and using boosters. Its public reviews include praise for distinguishable colors and complaints about early difficulty, ad load, and expensive VIP parking. These are directional signals, not a statistically valid survey. Play the current app and at least three competing bus jam games during Stage 0 to confirm precise rules, pacing, and gaps. Do not copy its levels, screenshots, UI layout, icon, audio, store copy, or name. The [US Copyright Office](https://www.copyright.gov/register/tx-games.html) distinguishes game methods from protected expression, and [Google Play's IP policy](https://support.google.com/googleplay/android-developer/answer/9888072) requires rights to app and listing content. Have the final title and icon checked for confusing similarity before store submission.

### Player promise and differentiation

- One-thumb play: most levels take 1–3 minutes; a failed move is explained immediately.
- **Readable dispatch:** each bus has both a color and a high-contrast route symbol; passenger groups use the same pair. A monochrome mode is viable from day one.
- **Route cards:** optional, limited special objectives (for example, send a bus through a marked depot lane) add planning depth after the basic loop is proven. Keep the launch rule set small.
- **Fair recovery:** undo and a limited earned hint path exist without a purchase. Rewarded ads only offer extra convenience.
- **Original presentation:** a small, bright city depot, distinct bus silhouettes, clear movement arcs, and restrained sound/haptics. Avoid the competitor's layouts and visual language.

### Provisional rules for the vertical slice

1. A board contains stationary buses, lanes, one exit, 3–4 departure bays, and an ordered, visible passenger queue. Every bus has a route color/symbol and seat capacity.
2. Tap a bus. The rules engine checks an unblocked path from its current location to an available bay. An invalid selection shows the blocker/path reason; it never spends a life or currency.
3. A bus in a bay boards only the currently accessible matching passengers. When full, it leaves and frees the bay. The player chooses bus order to avoid filling all bays with non-matches.
4. Win when the required passengers have boarded and the required buses have departed. A loss is declared only when the solver finds no legal progress from the current state; offer undo/retry.
5. A deterministic rules core, with animation driven from state changes, is required. Precise geometry, queue behavior, capacities, and bay count are **design hypotheses** to settle after the reference teardown and 10-player paper/gray-box test.

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

**Local environment checked:** Flutter 3.41.6, Dart 3.11.4, Android SDK 36 and Android Studio are installed. `flutter doctor -v` reports Android licenses not fully accepted; the developer must review and accept them with `flutter doctor --android-licenses` before Android builds. Check plugin compatibility and select current stable package versions at implementation time; do not pin versions based on this planning snapshot.

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

Use a pure `apply(BoardState, Command) -> Result<BoardState, GameEvent>` function. Keep a seed and command log so any bug report can replay a level deterministically. Define stable level IDs and a format version; bundle launch levels locally. A draft level record includes `id`, `schemaVersion`, `grid`, `lanes`, `exit`, `bays`, `buses` (position, size, route symbol/color, capacity), `passengerQueue`, `objectives`, `difficultyTags`, `seed`, and `solutionMetadata`. The schema and solver are the source of truth, not animation state. Validate no overlapping pieces, valid routes, legal capacities, at least one solution, intended move depth, and no soft lock without an undo path.

### MCPs for development (not runtime game dependencies)

MCP servers help the team **build and operate** the game; the Android app should not ship an MCP server or depend on an AI connection to play. Configure only the tools needed for a task, scope access to this repository/project, and keep tokens and service credentials out of Git.

| MCP | Practical use | Decision |
| --- | --- | --- |
| Official [Dart/Flutter tooling MCP](https://dart.googlesource.com/ai/+/HEAD/pkgs/dart_mcp_server/README.md) (`dart mcp-server`; inspect `--help` for this installed SDK) | Analyze/format code, search pub.dev, run tests, inspect widget tree/runtime errors and screenshots, hot reload. Pair with CLI and DevTools. | **Install/configure in Stage 1** after a Flutter project exists; use workspace roots. |
| Official [Firebase MCP](https://firebase.google.com/docs/ai-assistance/mcp-server) | Inspect Firebase project/configuration, rules and Crashlytics issues once Firebase exists. | **Stage 4**, scoped to a dev project first; review any project mutation. |
| Official [GitHub MCP](https://github.com/github/github-mcp-server) or the available GitHub connector | Read issues/PRs, triage bugs, link milestones to code. | **Stage 1** if the team uses issue tracking; grant least privilege. |
| [Blender MCP](https://www.blender.org/lab/mcp-server/) | Optional generation/inspection of Blender scenes for prerendered original sprites. | **Only if Blender art is chosen.** It executes generated Python without guards; use a disposable/isolated asset workspace, inspect outputs before importing. |
| Play Console / AdMob administration | Product IDs, store listing, testing tracks, policy and revenue data. | Use official UIs/APIs and human review; **do not adopt an unverified third-party MCP** with publishing or payment access. |

## 4. Stepwise delivery plan

Estimated elapsed time for a small team: **12–16 weeks**, with art/content running alongside engineering. Each stage has a deliverable and a gate; fail a gate, fix it before adding scope.

### Stage 0 — competitive teardown and product brief (week 1)

- [ ] Install/play the current Bus Fever Party! and three genre peers. Record first 30 minutes, level 1–20 progression, exact movement/boarding rules, bay behavior, fail states, booster economy, ad placements, shop, accessibility, and store positioning. Keep recordings private as research; no copied assets or levels.
- [ ] Write a one-page original game design brief with the final core rule set, 2–3 visual directions, audience, and the first 10-level teaching sequence.
- [ ] Run 10 rapid gray-box/paper sessions with people unfamiliar with the genre. Note where they misread routes, queue order, and blockers.
- [ ] Make an asset/license ledger and choose a distinctive title/icon direction. Check title and listing for IP/impersonation risk.
- [ ] Decide the target device matrix: small/large phone, low/mid/high GPU, Android versions supported by current plugins; establish memory and APK/AAB size budgets.
- **Exit:** written rules and at least one genuinely differentiated mechanic; ≥ 8/10 participants can explain the core objective after the tutorial without coaching.

### Stage 1 — playable vertical slice (weeks 2–4)

- [ ] Create `flutter create --platforms=android` app; set a unique application ID under the team's domain, portrait orientation, app icon placeholder, min SDK based on plugin requirements, and current Play target SDK. Use Flutter/Flame stable compatible versions.
- [ ] Implement pure-Dart board state, command validation, queue/boarding, bay occupancy, win/loss, undo, and deterministic replays; unit-test tricky transitions and deadlocks.
- [ ] Render a responsive board in Flame with placeholder art, readable color + symbol labels, tap feedback, move/board/leave animations, pause/resume, and safe-area handling.
- [ ] Hand-author 10 levels: 3 tutorial, 4 easy, 3 medium. Add level JSON validation and a debug overlay showing state, seed, and legal moves.
- [ ] Test touch accuracy, 60 fps, loading, and background/foreground behavior on two real Android phones.
- **Exit:** 10 complete levels, no unsolvable states in validation, no blocker that requires a payment/ad, first level playable within 10 seconds on target devices.

### Stage 2 — content pipeline and difficulty (weeks 4–6)

- [ ] Build a solver (BFS/A* or equivalent over canonicalized board states) to verify all authored levels and to return an explainable hint. Add limits so validation cannot hang.
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

1. Complete the Stage 0 teardown and settle the exact rules and original visual direction.
2. Create the Flutter Android scaffold and 10-level vertical slice; configure CI and Dart tooling MCP.
3. Use this file as the milestone checklist. Open issues per stage with measurable acceptance criteria and update assumptions after the first playtests.

## Source notes

Primary references used for this plan: [Bus Fever Party! listing](https://play.google.com/store/apps/details?id=gridplus.busjam.carpuzzle); [Flutter Casual Games Toolkit](https://docs.flutter.dev/resources/games-toolkit); [Flame documentation](https://docs.flame-engine.org/latest/); [Flutter ads](https://docs.flutter.dev/cookbook/plugins/google-mobile-ads) and [IAP package](https://pub.dev/packages/in_app_purchase); [Google Play ads policy](https://support.google.com/googleplay/android-developer/answer/9857753), [target API](https://support.google.com/googleplay/android-developer/answer/11926878), [testing](https://support.google.com/googleplay/android-developer/answer/14151465), [data safety](https://support.google.com/googleplay/android-developer/answer/10787469), and [IP](https://support.google.com/googleplay/android-developer/answer/9888072); [Firebase MCP](https://firebase.google.com/docs/ai-assistance/mcp-server); [Dart tooling MCP](https://dart.googlesource.com/ai/+/HEAD/pkgs/dart_mcp_server/README.md); [GitHub MCP](https://github.com/github/github-mcp-server); [Blender MCP](https://www.blender.org/lab/mcp-server/). Recheck mutable store policies, SDK support, fees, and tool commands at the stage where they are used.
