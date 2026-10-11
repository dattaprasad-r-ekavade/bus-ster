# Bus-ster roadmap

_Updated 11 October 2026, after the bus-jam rebuild (branch `rebuild/bus-jam-core`)._

This is a short, honest roadmap. Why the game was rebuilt, the rules contract and the rebuild phases are in [docs/REBUILD_PLAN.md](docs/REBUILD_PLAN.md). Market, policy, monetization and tooling research from before the rebuild is preserved in [docs/archive/RESEARCH_2026-10.md](docs/archive/RESEARCH_2026-10.md) as historical desk research.

## Product in one paragraph

An original, offline, single-player portrait bus-jam puzzle for Android. Tap direction-facing buses out of a crowded lot into a few bays; a colour-grouped crowd boards matching buses; full buses leave. Short levels, readable cause and effect, satisfying motion. Fun without paying or watching ads. Audience direction from the owner: adults / general audience, worldwide ambition (no launch countries chosen).

## Stages

| # | Stage | Status | Notes |
| --- | --- | --- | --- |
| 0 | Research and reference | Partly done | Desk research of Play listings done. Hands-on play of the reference and peers, and player sessions, **not done** (no test phones or participants yet). |
| 1 | Core rules and solver | **Done** | Rules v2 in pure Dart, tri-state solver (`solvable` / `unsolvable` / `unknown`), undo/retry, event list for animation, exhaustive tests. |
| 2 | Content pipeline | **Done (30 levels)** | Schema v2 codec, seeded generator, CI validator; 3 tutorials + 27 generated levels, random-playout fail rate rising ~0.26 → ~0.87. |
| 3 | Playable game screen | **Done, awaiting owner review** | Board-dominant layout, drawn buses and crowd, full choreography (drive out → road → bay, riders walk in, full bus departs), blocked-tap lurch + haptic, win/lose overlays, 320×568 support. |
| 4 | Meta layer | **Done** | Home / level select, progress save with `.bak` recovery, settings (sound, vibration, reduced motion), audio cues, English l10n. |
| 5 | Verification and docs | **In progress** | Docs rewritten; final test / analyze / emulator run pending. |
| 6 | Feel acceptance | **Next — blocked on owner** | Owner plays the build and accepts or redirects visuals, motion and difficulty. |
| 7 | Device and player testing | **Blocked** | Needs physical phones and first-time adult players. |
| 8 | Content and retention design | Not started | Starts after Stage 6. |
| 9 | Release preparation | Not started | Signing, Play Console, policy forms. |
| 10 | Monetization | Not started, deliberately | Only after retention evidence. |

## Open gates

None of these is closed by emulator runs or green tests.

1. **Owner acceptance of feel.** The previous iteration was rejected on feel; this one has not been reviewed yet.
2. **Physical-device testing.** Touch accuracy, frame time on a low/mid phone, haptics, audio latency and loudness, cold start, background/resume, Android backup restore. Proposed device profiles are in the research archive.
3. **Player testing.** Ten first-time sessions using [docs/STAGE_0_FIELDWORK.md](docs/STAGE_0_FIELDWORK.md): can players explain the goal, the blocked-lane rule and bay pressure without coaching?
4. **Release signing.** The release build type uses the debug key. Artifacts are for local validation only.
5. **Store setup.** No Play Console app, listing, content rating, Data safety form, published privacy policy, or support contact.
6. **Name.** "Busster" already exists on Google Play (an unrelated Swedish business app). "Bus-ster" stays a working title until a trademark, domain and Play title search is done.

## Next steps

### Now (before any new scope)

- Run the final verification pass: `flutter analyze`, `flutter test`, `dart run tools/validate_jam_levels.dart`, and the integration test on the API 35 emulator. Attach screenshots to the PR, not the repo.
- Hand the build to the owner for feel review. Record what to change; iterate on motion, art and difficulty before adding content.

### After feel is accepted

- **Content beyond 30 levels.** Extend `specFor` in `tools/generate_jam_levels.dart` (or add a second pack) for levels 31+; keep the validator green and the curve gentle around breathers. Consider hand-authoring a few signature levels. Target 60–100 levels for a first release, with the first 20 introducing one idea at a time.
- **New mechanics, one at a time** (for example multi-colour buses, hidden passengers, locked bays), each with a tutorial level, solver support and validator rules.
- **Boosters and economy — design deferred.** Do not design boosters, currencies or hint limits until the base loop is accepted and players have been observed. Hints stay free while testing. Never make a level require a booster.
- **Accessibility pass:** colour + symbol readability in grayscale, TalkBack labels, text scaling on real devices.

### After device and player testing

- Fix the top friction points found in sessions; re-test with new participants.
- **Analytics** only after a consent and privacy review: wire a real provider behind the existing `GameTelemetry` adapter (currently no-op, see [docs/ANALYTICS_EVENT_SCHEMA.md](docs/ANALYTICS_EVENT_SCHEMA.md)); update the privacy draft and Data safety answers first.

### Monetization — only after retention evidence

- Requires a closed-test cohort with measured D1/D7 retention and level completion.
- Start with opt-in rewarded ads for a convenience (extra hint/undo), never a required unlock; keep the first levels ad-free. Interstitials only if evidence supports them, after results screens, frequency-capped.
- Implement Google UMP consent before any ad request; update Data safety, privacy policy and ads declaration to match the SDK's real behaviour (it adds network and advertising-ID permissions).
- An optional one-time "remove ads" purchase via Play Billing, with restore and refund handling.
- Details and guardrails: [docs/archive/RESEARCH_2026-10.md](docs/archive/RESEARCH_2026-10.md#4-monetization-design-notes).

### Release preparation

- **Signing:** create an upload key (kept outside Git; `android/key.properties` and `*.jks` are already ignored), configure the release signing config, enrol in Play App Signing, build a signed `.aab`.
- **Play listing:** app name (after the name check), description, original screenshots and feature graphic, icon review under launcher masks.
- **Policy forms:** content rating, target audience (adult/general; review Families policy before any child age group), Data safety, ads declaration (currently "no ads"), app access, privacy policy URL ([draft](docs/PRIVACY_POLICY_DRAFT.md)).
- **Account requirements:** confirm developer verification / package registration for `com.busster.busster`, and the closed-testing requirement (12 testers for 14 days on new personal accounts). Recheck target-API rules (API 36 at time of writing).
- **Name / trademark check** before the listing goes live.
- Internal → closed testing → production, with release notes, rollback plan and a support contact.

## Principles

- Rules first, visuals second: the pure-Dart model is the single source of truth; animation never decides state.
- Every shipped level is solver-verified and validator-checked in CI.
- Offline core. No backend, account or network dependency for play.
- Original art, audio, levels and copy only; record provenance in [docs/ASSET_LEDGER.md](docs/ASSET_LEDGER.md).
- Docs state what is actually done; emulator results are labelled as interim.
