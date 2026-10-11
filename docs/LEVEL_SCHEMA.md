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

## Authoring and review

1. Edit the canonical JSON file. Preserve stable level IDs and keep route symbols/colors readable in the board.
2. Run `dart run tools/validate_levels.dart`. Fix every structural, capacity, tutorial, or solver failure.
3. Run `dart run tools/preview_levels.dart`. Open `build/level-preview.html` to review geometry, queue, prompt, mechanic tags, shortest solution, reachable/branching/no-win/dead-end states, legal opening buses, and road junction count.
4. If useful, make a candidate with `dart run tools/level_variants.dart depot-03 x`. The `x` or `y` mirror tool writes one solver-checked JSON candidate under `build/level-variants/`; review its layout and prompt before copying it into the authored pack.
5. Do not count a solver pass as human QA. Record first-time player confusion, completion time, retries, and observed solve rate before treating a band or tutorial as validated.

`build/` is generated and ignored by Git. Keep only reviewed authored levels in the canonical pack.
