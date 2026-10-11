# Bus-ster design review and course correction

_11 October 2026. Status: owner rejected the current visual direction and gameplay feel. This is the acceptance brief for the replacement vertical slice._

## Evidence and limits

- The [official Bus Fever Party! Play listing](https://play.google.com/store/apps/details?id=gridplus.busjam.carpuzzle) describes a gridlocked parking area, shifting vehicles through tight spaces, and matching waiting passengers to the correct bus. Its current screenshots show a visible crowd and passenger route at the top, boarding spaces near the middle, and a dense field of colored, direction-marked vehicles below. These are observations of public listing material, **not** a hands-on rules teardown.
- The [current Bus-ster API 35 emulator capture](evidence/busster_api35_emulator_play_screen_2026-10-11.png) shows a dark menu-like shell, small FIFO chips, three buses on a sparse road graph, large empty regions, and detached bays at the bottom. The implementation in [`game_model.dart`](../lib/game/game_model.dart) sends a tapped bus along a computed route to a shared exit. `BusSpec` has no facing or vehicle footprint.
- A [third-party level guide](https://levelsensei.com/bus-fever-party/level/1/) describes facing-direction release. This is secondary evidence only. The exact movement, boarding, bay, and failure rules still require direct play before being treated as facts about the reference.
- The owner has confirmed that **both visuals and gameplay** miss the intended experience. The team has no physical Android phones or external first-time testers at present. Emulator review can check layout and behavior but cannot prove player comprehension or device performance.

## What is wrong with the current slice

| Area | Current prototype | Intended next slice | Consequence |
| --- | --- | --- | --- |
| Primary decision | Tap one of a few buses; an unrestricted graph search finds a route to the exit. | Read vehicle orientation and occupied space; release a vehicle only when its forward path is clear. | The present puzzle feels like route dispatch rather than a parking jam. |
| Board | Sparse 5×5 road nodes with three or four one-cell buses. | Tightly arranged, rectangular vehicles of different lengths and facing, with visible blockers and a clear opening chain. | Removing a bus presently creates little spatial satisfaction. |
| Passenger flow | Small FIFO tokens in a separate strip; bays below the road. | Readable waiting groups above the lot, with boarding spaces and bus arrival visually connected to them. | The matching/boarding reward is peripheral instead of central. |
| Visual hierarchy | Navy dashboard, prominent text and controls, unused vertical gaps. | Light, playful parking scene occupying most of the portrait viewport; controls recede around the puzzle. | The first screenshot communicates utility software more than a casual game. |
| Motion and feedback | Abstract route trace and state change. | Vehicle slides out along its facing, unblocks others, arrives at a bay, boards matching riders, then leaves. | The cause-and-effect loop is hard to see. |
| Content | Ten solver-valid road-network levels plus queue-order candidates. | A newly authored tutorial and progression using the accepted parking-jam rules. | More old levels would deepen the mismatch. |

**Root cause:** we chose a speculative shared-road/BFS mechanic and an evening-depot art treatment before checking the reference's visual and interaction loop with the owner. Solver validity, tests, APK builds, and emulator checks establish that the prototype runs; they do not establish that it is the game the owner wanted.

## Replacement design target

Bus-ster should be an **original, bright, tactile bus parking puzzle**. The player sees many vehicles in a compact lot and a crowd with colored route symbols near the top. Each vehicle has an unmistakable nose/facing arrow and a rectangular footprint. A legal tap sends it along its facing direction through a clear lane. Its departure visibly opens space for blocked vehicles. A bus then enters a boarding space; matching passengers visibly board; a completed bus departs. Limited boarding spaces make selection order matter. Invalid taps immediately show which vehicle or boundary blocks the path. Undo and retry are visible, free recovery controls.

This is a **Bus-ster rule proposal**, not a claim that every detail matches Bus Fever Party!. During direct reference play, record whether tapping, sliding, passenger ordering, mixed vehicles, capacity, and bay rules actually behave as assumed. Change the proposal if the evidence warrants it. Preserve original level geometry, art, copy, branding, audio, and screen composition. Do not trace or import competitor screenshots.

### First replacement screen

| Portrait region | Required content |
| --- | --- |
| Top 20–25% | A compact level label and goal; many individually visible passengers or grouped figures following a route toward the boarding area. Route symbols accompany colors. |
| Middle 15–20% | Clearly marked boarding spaces and a short, visible path from lot to bays/crowd. Arrival, boarding, and departure occur here. |
| Lower 50–60% | A dense parking puzzle: at least eight clearly distinct vehicle bodies in the review fixture, mixed horizontal/vertical footprints, obvious facing arrows, minimal empty tiles, readable blockers. This count is an internal visual-review fixture, not a claimed reference rule or launch difficulty target. |
| Edge/bottom controls | Small, reachable Undo, Retry, Help, and optional hint; no header or control panel should dominate the board. Keep safe areas and 320×568 layout support. |

Use a warm, light ground plane, saturated but accessible vehicle colors, soft depth/shadows, and simple original toy-like shapes. Favor legible silhouettes and motion over decorative buildings. Retain symbol cues so color is never the only rule-critical signal. Create at least two original static compositions (tutorial and crowded midgame) and inspect them at phone scale before polishing sprites.

Two preliminary original compositions are in [`concepts/parking-jam-direction.html`](concepts/parking-jam-direction.html): a first lesson and a crowded follow-up state. They are layout proposals only, not approved art, playable levels, or proof of final mechanics. Their phone-scale rendering still needs visual inspection and owner feedback.

### Core interaction contract for the first slice

1. A level defines a rectangular lot, vehicle ID/color/symbol, footprint, facing, occupied cells, passenger groups, boarding-space count, and a target departure path.
2. A tap on a blocked vehicle leaves state unchanged and highlights the first obstruction. A tap on a free vehicle moves it deterministically along its facing to the pickup/staging area. Animation follows the state transition and cannot alter rules.
3. Leaving a footprint releases every occupied cell; vehicles blocked behind it become selectable. A visible passenger group of the matching route boards in order. Full buses leave; waiting buses occupy bays. The exact queue/capacity rule must be chosen after direct play and then explained in-game.
4. Undo restores vehicle positions, passenger state, bays, and move count exactly. Retry returns to the authored initial state. A stuck state is explained without requiring an ad, purchase, or scarce currency.
5. A small plain-Dart solver checks every new level and provides hints. New content has its own schema version; old `roads`/`exit` levels are archived as prototype fixtures and never silently interpreted as parking-jam levels.

## Work disposition

| Keep and adapt | Replace or retire |
| --- | --- |
| Flutter/Flame Android scaffold; lifecycle/pause/settings; localization foundation; audio and haptic adapters; progress storage and migration patterns; consent-gated ad adapter kept disabled; CI and emulator harness. | `routeToExit()` graph traversal, one-cell `BusSpec`, old board renderer and screen hierarchy, ten road-node levels as shipping content, road-specific tutorial copy, mirror/queue candidate content generation, road-specific solver metrics and hints. |

Old code can remain temporarily behind the existing playable prototype while the new slice is built. Label it accurately. Do not generate or promote more old-schema levels. The 20 old queue-order candidates are archived technical experiments, not new product content.

## Stepwise recovery and gates

1. **Design lock candidate:** capture this mismatch review; draw two original phone-scale layouts; specify a sample 8–12-vehicle parking arrangement and one passenger sequence. Show both a tutorial and a crowded midgame state. **Gate:** the owner accepts the visual composition and describes the intended move/boarding loop in their own words. No production asset pass before this.
2. **Rules spike:** implement independent plain-Dart occupancy, facing-path clearance, release, bay/boarding, undo, and win/stuck semantics. Add targeted tests for a blocked nose, edge, chain release, full bay, capacity, undo, and a solver-verified sample level. **Gate:** one level produces a clear chain of spatial releases and no unexplained legal move.
3. **Playable replacement slice:** use the approved composition in Flutter/Flame, with a crowded board, passengers, bays, movement, tap feedback, and small controls. Capture screenshots/video from 320×568 and a modern tall emulator. **Gate:** the owner reviews the actual build and accepts both visual feel and interaction; revise until accepted.
4. **Tutorial and content:** replace the first ten lessons and level schema; add level preview and solver validation for the new rules. **Gate:** levels are individually solvable and teach one concept at a time. Quantitative difficulty claims wait for player sessions.
5. **External validation when available:** install and play the reference and three peers on a suitable device; then recruit ten adult first-time testers and test on two physical Android phones. Record exact rule corrections, comprehension, touch/animation issues, and performance. Until devices/testers exist, keep these gates open and use emulator plus owner review for iteration.
6. **Commercial continuation:** only after the accepted loop and early retention evidence, resume content scale, analytics, rewarded ads, billing, and store preparation. Keep production ads off. Revenue assumptions in the plan remain scenarios, not a forecast.

## Review decision

The current app is a **technical spike, not an accepted vertical slice**. Stage 1 product acceptance is reopened. Stage 2 level scaling and Stage 3 art lock are paused until the replacement slice passes the owner review gate. Infrastructure can continue to support the rebuild, but no old-road-network content counts toward launch content.

**Implementation note:** [`parking_jam_model.dart`](../lib/game/parking_jam_model.dart) and its [focused tests](../test/parking_jam_model_test.dart) are the first isolated rules spike. They implement forward clearance, vehicle/capacity validation, boarding bays, undo/retry, stuck/win states, and a bounded solution search. The example test board has only two vehicles, so the crowded review fixture and playable integration remain open. Queue and bay semantics are provisional until reference play and owner review.
