# Gameplay analytics event schema

The game screen emits a small set of gameplay events through the `GameTelemetry` interface in [`lib/game/game_telemetry.dart`](../lib/game/game_telemetry.dart). The app only ever uses `NoopGameTelemetry`: **events are discarded immediately.** Nothing is stored, logged or sent, and no analytics SDK is in the app. This schema defines the adapter boundary; it does not authorize data collection.

## Events

Every event carries:

| Parameter | Type | Meaning |
| --- | --- | --- |
| `level_id` | string | Stable level id from the pack, e.g. `tutorial-1`, `level-012`. |
| `level_index` | int | Zero-based position of the level in the current pack. |

| Event (`GameEventNames`) | Extra parameters | Emitted when |
| --- | --- | --- |
| `level_start` | — | A level opens (from home or level select, or Next after a win). Retry does not emit it. |
| `level_win` | `moves` (int) | Every passenger has boarded, after the final animation. |
| `level_lose` | `moves` (int) | The level is lost (bays full with no boarding possible, or no bus can move). |
| `undo` | — | The player taps Undo and a move is actually undone. |
| `retry` | — | The player restarts the level (HUD, pause menu or lose overlay). |
| `hint_used` | — | The player asks for a hint (emitted before the solver runs). |

`moves` is the current state's move count (successful taps, net of undos) when the result is announced. Win/lose is emitted once per result.

## Rules for any future provider

- The no-op adapter stays the default. Before wiring Firebase or any other provider: add a consent flow where required, update [PRIVACY_POLICY_DRAFT.md](PRIVACY_POLICY_DRAFT.md) and the Play Data safety answers to match the SDK's real behaviour, and confirm the game stays fully playable offline.
- Never attach names, emails, advertising IDs, free-form text, location or device fingerprints. Level ids, indices and move counts are the only gameplay details.
- Providers must be best-effort: `record` must never throw into gameplay, delay a move, or block progress. The screen already wraps each call in a `try`.
- Change event names or parameters deliberately and record the change here so release cohorts stay comparable. Add app version / build fields at the provider boundary, not per event.

`test/game_telemetry_test.dart` pins the event-name set and checks that the default adapter is a no-op.
