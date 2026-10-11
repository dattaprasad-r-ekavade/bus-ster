# Level bundle schema

The canonical authored level pack is [`assets/levels/levels.json`](../assets/levels/levels.json). The app loads this asset at startup through `LevelBundleCodec`; level rules and solver checks remain in plain Dart.

## Bundle shape

The top-level object has `schemaVersion: 1` and a non-empty `levels` array. Each level contains:

| Field | Type | Rule |
| --- | --- | --- |
| `id` | string | Stable, unique ID. Keep it unchanged after release so saves and analytics keep their meaning. |
| `title` | string | Short player-facing depot title. |
| `width`, `height` | integer | Positive grid dimensions. |
| `exit` | `{ "x": int, "y": int }` | Must point to a road tile. |
| `roads` | array of points | Unique, in-bounds grid coordinates. |
| `bayCount` | integer | Positive number of staging bays. |
| `buses` | array | Each bus has a unique `id`, `route`, `position`, and positive `capacity`. Bus positions must be unique road tiles. |
| `passengerQueue` | array of routes | Non-empty first-in-first-out queue. Routes are `coral`, `blue`, `mint`, or `gold`. |
| `tutorialPrompt` | string | Provisional teaching line shown when the depot starts. |
| `difficultyBand` | string | `tutorial`, `easy`, `medium`, `hard`, or `unrated`. Current bands are design hypotheses, not player-measured ratings. |
| `mechanicTags` | array of strings | Author notes such as `branch`, `fifo-queue`, or `bay-pressure`; use consistent kebab-case tags. |
| `seed` | integer or null | Reserved for deterministic generated layouts; authored levels currently use `null`. |

The codec rejects unsupported schema versions and invalid coordinates, duplicate IDs/tiles, missing routes, and malformed metadata. The batch validator also checks that passenger counts match bus capacity for each route and that the bounded solver finds a complete dispatch sequence (up to 100,000 explored states). The preview counts reachable nonterminal states, legal branching states, dead ends, states with no path to a win, and choice points along a shortest solution. These are puzzle-graph properties, not measured player difficulty; they do not replace completion time, solve rate, or usability observations from playtests.

The seeded candidate generator in [`tools/generate_level_candidates.dart`](../tools/generate_level_candidates.dart) shuffles rider order for each authored layout, keeps route totals and bus geometry intact, and writes a separate versioned JSON bundle under `build/level-candidates/`. It uses a small specified PRNG so a seed regenerates the same candidate bundle across runs. Candidates are tagged `queue-order-candidate`, have difficulty `unrated`, and are never loaded by the game unless deliberately copied into the canonical pack. They reuse the source prompt, so revise the prompt after reviewing the new queue. Solver success proves only that a solution exists; it does not prove the layout is fair, distinct, or well taught.

## Authoring and review

1. Edit the canonical JSON file. Preserve stable level IDs and keep route symbols/colors readable in the board.
2. Run `dart run tools/validate_levels.dart`. Fix every structural, capacity, tutorial, or solver failure.
3. Run `dart run tools/preview_levels.dart`. Open `build/level-preview.html` to review geometry, queue, prompt, mechanic tags, shortest solution, reachable/branching/no-win/dead-end states, legal opening buses, and road junction count.
4. Generate more queue variants with `dart run tools/generate_level_candidates.dart --seed 20261011 --per-level 2`. Open the output with `dart run tools/preview_levels.dart build/level-candidates/candidates-seed-20261011.json build/level-candidates/preview.html`. The generator creates solver-checked queue candidates while preserving source geometry; revise their reused prompts and content after review.
5. If useful, make a mirrored layout with `dart run tools/level_variants.dart depot-03 x`. The `x` or `y` mirror tool writes one solver-checked JSON candidate under `build/level-variants/`.
6. Copy a candidate into the canonical authored pack only after human review, then assign its stable release ID and a provisional band/tag. Do not count a solver pass as human QA. Record first-time player confusion, completion time, retries, and observed solve rate before treating a band or tutorial as validated.

`build/` is generated and ignored by Git. Keep only reviewed authored levels in the canonical pack.
