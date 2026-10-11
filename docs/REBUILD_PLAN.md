# Bus-ster rebuild plan (2026-10-11)

Supersedes the "seven-bay loop" spike (snapshot commit `54bd914`). Owner feedback: visuals and gameplay both miss the Bus Jam / Bus Fever Party feel.

## What went wrong in the previous iteration

| # | Mistake | Consequence |
|---|---------|-------------|
| 1 | Every bus `capacity: 1`; riders = buses 1:1; 7 bays for 8–12 buses. | No colour-matching/capacity puzzle; levels are practically unloseable Rush Hour exits. |
| 2 | Passenger queue interleaved one-by-one, not grouped crowds. | No reading of the crowd, no planning. |
| 3 | Tapped bus slides off the lot edge (clipped) and a bay fades in; riders pop (index-based keys). | No "bus drives to bay, people walk in, bus leaves" loop — the core feel. |
| 4 | Rules applied after a 300 ms delay; Undo/Retry unguarded during it. | State corruption race. |
| 5 | Header + hint banner + loop panel + bay panel + actions ≈ 50% of screen; dead gap above controls. | Small board, app-like chrome. |
| 6 | Rush-Hour grid lines, flat rectangle buses, font-glyph symbols at 7–12 px, decorative oval. | Doesn't read as a toy bus game. |
| 7 | Levels hardcoded in a 1,443-line screen file; tutorial text keyed on vehicle IDs that misname colours. | Unmaintainable; broken guidance after riders 2+. |
| 8 | Solver returns null for both "unsolvable" and "limit hit"; runs on UI thread; only 2 levels. | Unreliable validation; no content. |
| 9 | Legacy depot game (≈1,450 lines in `main.dart`, Flame, AdMob, old levels/tools/tests) still compiled and tested; CI validates rejected levels. | APK bloat, ad permissions in a prototype, misleading 70-test "green". |
| 10 | Integration test asserts old strings; never run in CI; docs (GAME_PLAN 59 KB, README, design review) claim stale/rejected work as done. | False sense of progress. |

## Rules contract (v2) — single source of truth

- **Lot**: `width × height` grid. **Vehicle**: `id`, `color` (one of: red, blue, green, yellow, purple, orange), `facing` (up/right/down/left), `length` 2–4, `capacity` (default by length: 2→4, 3→6, 4→8). Footprint extends *backwards* from the nose cell (`head`).
- **Passengers**: ordered queue of colours (authored in groups). Per colour, total seats == total riders (validated).
- **Bays**: fixed `bayCount` slots (typically 4–6). Slots are stable indices; a bus takes the **lowest free slot**.
- **Tap**: if any cell between the nose and the lot edge is occupied → blocked (report first blocker; state unchanged). If no free bay → blocked (`fullBays`). Otherwise the bus leaves the lot and parks in a bay.
- **Boarding** (resolved after every park): while the front passenger's colour matches a parked bus with free seats (lowest slot wins), that passenger boards. A bus that becomes full departs immediately, freeing its slot. Repeat until the front passenger matches no parked bus.
- **Lose**: all bays occupied and no boarding possible (or no tappable bus remains while passengers wait). **Win**: all passengers boarded.
- **Move result** carries an event list for animation: `park(vehicleId, slot)`, `board(passengerIndex, slot)`, `depart(vehicleId, slot)` in order.
- Undo restores exactly; Retry restores the initial state; undo is allowed after a loss.
- **Solver**: returns `solvable(path) | unsolvable | unknown(limit)`; canonical state key; runs off the UI thread for hints.

## Work phases

1. **Cleanup** — remove legacy depot game, Flame, AdMob, old levels/tools/tests; keep reusable settings/storage/audio/l10n/CI skeleton.
2. **Core rules v2** — new model, solver, JSON level schema v2 + loader, exhaustive tests.
3. **Content** — level generator + validator tool; 3 hand-made tutorial levels + ≥27 generated levels with rising difficulty; every level solver-verified with measured fail pressure.
4. **Screen rebuild** — board ≥ 60% of the viewport, minimal HUD, chunky drawn buses, grouped crowd queue feeding bays, full choreography (drive out → road → bay, riders walk in, full bus leaves), blocked-tap shake + haptic, win/lose overlays, 320×568 support.
5. **Integration** — level select + progress save, settings (sound/haptics/reduced motion), audio cues, l10n strings.
6. **Verification & docs** — full tests, analyze, integration test on API 35 emulator, screenshots; replace stale docs with a concise current-state README + backlog; CI updated.

Owner acceptance of feel, physical-device checks and player tests remain open gates; emulator results are interim.

## Status (2026-10-11)

| Phase | Outcome |
|-------|---------|
| 1. Cleanup | **Done** (`d7ad09b`). Legacy depot game, Flame, AdMob, old levels/tools/tests removed. |
| 2. Core rules v2 | **Done** (`d5c5cb6`). `jam_model`, tri-state `jam_solver`, schema-v2 `jam_level_codec`, exhaustive tests. |
| 3. Content | **Done** (`f9a4911`). Seeded generator + validator (in CI); 3 tutorials + 27 generated levels, measured random-playout fail rate ~0.26 → ~0.87. |
| 4. Screen rebuild | **Done** (`51fcaf2`). Board-dominant layout, drawn buses/crowd, full choreography, blocked-tap lurch + haptic, win/lose overlays, 320×568. |
| 5. Integration | **Done** (uncommitted at time of writing). Home/level select, progress save with `.bak` recovery, settings screen, audio cues, l10n strings, integration smoke test rewritten. |
| 6. Verification & docs | **Docs done**: README, GAME_PLAN roadmap, LEVEL_SCHEMA, analytics, privacy draft and asset ledger rewritten; superseded docs moved to `docs/archive/`; rejected-design screenshots removed. **Verification pending** the final test / analyze / validator / emulator integration run. |

Open gates are unchanged: owner acceptance of feel, physical-device checks, player tests.
