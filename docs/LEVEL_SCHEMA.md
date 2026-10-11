# Level schema v2 and authoring workflow

The level pack is [`assets/levels/jam_levels.json`](../assets/levels/jam_levels.json). It is read by [`JamLevelCodec`](../lib/jam/jam_level_codec.dart) and validated by the [`JamLevel`](../lib/jam/jam_model.dart) constructor. Gameplay rules are defined in the rules contract in [REBUILD_PLAN.md](REBUILD_PLAN.md#rules-contract-v2--single-source-of-truth).

## Format

```json
{
  "schema": 2,
  "levels": [
    {
      "id": "example-1",
      "width": 4,
      "height": 4,
      "bays": 3,
      "hint": "tutorial.tapToPark",
      "vehicles": [
        {"id": "r1", "color": "red", "facing": "up", "x": 0, "y": 1, "length": 2},
        {"id": "b1", "color": "blue", "facing": "left", "x": 1, "y": 3, "length": 3, "capacity": 4}
      ],
      "passengers": [["red", 4], ["blue", 4]]
    }
  ]
}
```

### Bundle

| Field | Type | Rule |
| --- | --- | --- |
| `schema` | int | Must be `2`. Anything else is rejected. |
| `levels` | list | Level objects in play order. Ids must be unique. |

### Level

| Field | Type | Rule |
| --- | --- | --- |
| `id` | string | Non-empty, unique, stable. Saved progress keys on it, so never rename a shipped id. Tutorials use `tutorial-N`; generated levels use `level-NNN`. |
| `width`, `height` | int | Lot size in cells, 1–16 each (the validator further limits shipped levels to 8×10). |
| `bays` | int | Number of bay slots, 1–8 (validator: 3–7 for non-tutorial levels). |
| `hint` | string, optional | Tutorial text key. Known keys: `tutorial.tapToPark`, `tutorial.clearBlocker`, `tutorial.watchTheBays` (mapped to ARB strings in [`jam_strings.dart`](../lib/jam/ui/jam_strings.dart)). Unknown keys show no bubble. |
| `vehicles` | list | At least one vehicle (see below). |
| `passengers` | list | Queue, **front first**, as `[colour, count]` groups; `count ≥ 1`. At least one passenger. |

### Vehicle

| Field | Type | Rule |
| --- | --- | --- |
| `id` | string | Non-empty, unique within the level. |
| `color` | string | One of `red`, `blue`, `green`, `yellow`, `purple`, `orange`. |
| `facing` | string | `up`, `right`, `down` or `left`. The bus leaves the lot this way. |
| `x`, `y` | int | The **nose** (head) cell. `(0, 0)` is the top-left; `y` grows downward. |
| `length` | int | 2–4 cells. The body extends **backwards** from the nose, opposite to `facing`. |
| `capacity` | int, optional | Seats, ≥ 1. Defaults to `2 × length` (2→4, 3→6, 4→8); the writer omits it when it equals the default. |

Example: a bus facing `up` with nose `(2, 1)` and length 3 covers `(2, 1)`, `(2, 2)`, `(2, 3)`.

### Model validation (every load)

Construction of `JamLevel` collects every problem and rejects the level with a `JamLevelFormatException` naming it:

- lot size, bay count and vehicle length within the ranges above; capacity ≥ 1;
- every vehicle cell inside the lot; no two vehicles overlap;
- unique, non-empty vehicle ids;
- **per colour, total seats equal total riders.** Every bus must fill and leave, so every win taps every vehicle exactly once.

## Authoring workflow

### Generated levels (4–30)

[`tools/generate_jam_levels.dart`](../tools/generate_jam_levels.dart) rewrites levels 4–30 after the three hand-made tutorials, which it reads from the existing file and re-writes unchanged in content. Output is deterministic for a given master seed (default `20261011`).

```sh
dart run tools/generate_jam_levels.dart [--seed N] [--dry-run] [--only 4,9] [--out path]
```

| Flag | Effect |
| --- | --- |
| `--seed N` | Master seed; each level uses `N × 1000 + levelNumber`. |
| `--dry-run` | Print the metrics table only; write nothing. |
| `--only 4,9` | Generate just these level numbers (implies no write). |
| `--out path` | Write somewhere other than `assets/levels/jam_levels.json`. |

The curve lives in `specFor(n)`: lot grows from 5×6 to 7×9, colours from 3 to 6, vehicle count from ~7 to ~20, and the target random-playout fail rate from 0.30 to 0.85. Levels 9, 14, 19, 24 and 28 are "breathers" (easier, one colour fewer); levels 11, 17 and 22 drop to four bays as spikes. The generator ([`jam_generator.dart`](../lib/jam/jam_generator.dart)) packs and peels the lot so its blocking graph is acyclic, picks a planned clearing order, builds the passenger queue from that plan with a `squeeze` knob, then measures fail rate with 500 random playouts and keeps the attempt closest to the target. Each level is confirmed with `solveJam` before writing.

**Keep vehicles listed in plan order.** The generator writes vehicles in the order of its planned solution. The solver's depth-first search tries vehicles in list order, so it finds the planned line first and in-game hints return instantly. If you hand-edit or hand-author a level, list vehicles in the order you expect them to be cleared; a scrambled order still validates but can make hint solves slow enough to fail the validator's hint probe.

### Hand-authored levels (tutorials)

Edit the JSON directly. Keep the one-vehicle-per-line, four-groups-per-line style the generator uses so diffs stay readable. Tutorials must have a `hint`, and `test/jam/jam_levels_asset_test.dart` pins the tutorial ramp (for example, tutorial 1 has 3 bays and cannot be lost). If you add a new hint key, add the ARB string and the mapping in `jam_strings.dart`.

### Validate

Always run after any change:

```sh
dart run tools/validate_jam_levels.dart [path] [--playouts N]
```

It exits non-zero on any failure (CI runs it). Per level it checks:

| Check | Applies to |
| --- | --- |
| Decodes and passes model validation; ids unique across the pack | all |
| `solveJam` (200,000-node default limit) returns `Solvable`, and the path replays to a win | all |
| Solve takes < 2 s | all |
| Lot within 8×10 | all |
| Bays within 3–7 | generated |
| At least 2 buses tappable at the start | generated |
| Random-playout fail rate > 0 (the level can be lost) | generated |
| Hint probe: 12 solves from random mid-game states — none hit the node limit, none take > 2 s | all |

It prints a table of lot, bays, vehicles, colours, passengers, initially free buses, minimum moves, fail rate, solver nodes, solve time and worst hint time. The asset test (`flutter test test/jam/jam_levels_asset_test.dart`) repeats the structural checks and pins the pack shape (3 tutorials + 27 generated levels).

## Compatibility

- Schema v1 (the rejected road-network / parking-spike formats) is not readable; there is no migration because those levels were discarded.
- Progress keys on level ids and recomputes unlocks against the current order, so levels may be appended or reordered without breaking saves. Removing or renaming a shipped id drops its completion.
- A breaking format change must bump `schema` and update the codec, generator formatter, validator and this document together.
