# Gameplay analytics event schema

The game emits a small, versionable set of gameplay events through `GameTelemetry`. The production app currently injects `NoopGameTelemetry`, so no events leave the device, enter local storage, or reach an analytics provider. This schema prepares the adapter boundary; it does not authorize data collection.

| Event | Parameters | Emitted when |
| --- | --- | --- |
| `level_started` | `level_id`, one-based `level_index`, `entry_source` (`new_run`, `next`, `selection`) | A new run, depot selection, or next depot begins. |
| `level_resumed` | `level_id`, `move_count` | A saved route is restored. |
| `dispatch_rejected` | `level_id`, `move_number`, `reason` (`level_finished`, `inactive_bus`, `blocked_path`, `bays_full`, `rule_rejected`) | A dispatch attempt cannot change the board. |
| `bus_dispatched` | `level_id`, `move_number`, `route`, `riders_boarded`, `buses_parked` | A bus move changes the board. |
| `route_tip_used` | `level_id`, `route`, `remaining` | A solver tip is shown and spent. |
| `route_tip_unavailable` | `level_id`, `reason` (`empty_balance`, `no_solution`) | A player asks for a tip that cannot be shown. |
| `move_undone` | `level_id`, `move_count` | The player undoes a move. |
| `level_restarted` | `level_id`, `moves_discarded` | The player restarts the current depot. |
| `level_completed` | `level_id`, `move_count`, integer `first_clear` (0 or 1) | All riders are delivered and buses leave. |
| `level_stuck` | `level_id`, `move_count`, `buses_parked` | A move leaves no solver path. |

## Collection rules for a future provider

- Keep stable event names and level IDs. Add schema changes deliberately so release cohorts can be compared.
- Do not attach player names, email, advertising IDs, free-form UI text, precise location, or device fingerprints. Route names and coarse move counts are the only gameplay details recorded here.
- Keep the no-op adapter as the default. Before enabling Firebase or another provider, add the appropriate consent flow, disclose the exact SDK behavior in the privacy policy and Play Data safety form, and verify the app remains playable offline when collection is unavailable.
- Catch provider failures outside game rules. Analytics must never delay a move, block progress, or make a puzzle unavailable.
- Add version/source fields at the provider boundary after release identity and consent are configured. Do not use Remote Config to change core puzzle rules until its values have safe bundled defaults and validation.

The fake adapter tests event names, rejection reasons, first-clear accuracy, resume behavior, and resilience to provider errors. Firebase dashboards, crash reporting, consent, and live network delivery remain Stage 4 work.
