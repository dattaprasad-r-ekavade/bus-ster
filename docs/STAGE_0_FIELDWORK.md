# Stage 0 fieldwork workbook

_Prepared 11 October 2026; references updated for the bus-jam rebuild. No hands-on competitor session or external player session has been run yet. The team currently has no physical test phones or adult playtest participants available._

> **Current target:** the rebuilt bus-jam game (rules contract in [REBUILD_PLAN.md](REBUILD_PLAN.md#rules-contract-v2--single-source-of-truth)): tap a bus with a clear lane, it parks in the lowest free bay, the front of the colour-grouped crowd boards matching buses, full buses leave. The build ships 3 tutorial levels (`tutorial.tapToPark`, `tutorial.clearBlocker`, `tutorial.watchTheBays`) before generated levels. The teaching beats below remain hypotheses until the owner accepts the feel and first-time players are observed.

Use this workbook to close the research and player-testing gates in [`GAME_PLAN.md`](../GAME_PLAN.md). Store-listing descriptions and review snippets are useful discovery signals, but do not substitute for playing the apps or observing people try Bus-ster.

## Competitor teardown record

For each title, record observations from a clean install and first 30 minutes. Keep screenshots/recordings private to the research team and use them only to describe mechanics, pacing, and flows. Do not reproduce a level, screenshot, sound, text, icon, or distinctive layout in Bus-ster.

| Field | Notes |
| --- | --- |
| Game, developer, Play URL, date, country/device | |
| First screen and time until first playable move | |
| Tutorial wording and what it teaches | |
| What the player taps/drags; how vehicles move | |
| Passenger matching and queue/order behavior | |
| Bay/parking capacity and what happens when full | |
| Invalid moves, fail states, retry, undo, hints | |
| Levels 1–5 / 6–10 / 11–20: new mechanics and difficulty changes | |
| Ads: exact trigger, timing, skip/close behavior, frequency observed | |
| Purchases/boosters: offer, price shown in local currency, stated benefit | |
| Accessibility: symbols, contrast, color-vision options, sound controls | |
| Strongest satisfying moment and most confusing/frustrating moment | |
| What is common across peers; what is truly distinctive | |
| Follow-up hypothesis for Bus-ster (no copying) | |

Run one worksheet per title. If an app is unavailable in the test region or cannot be installed on a test device, record that limitation and use its public listing as desk research only.

## Replacement-slice player session

### Setup

- Recruit 10 adults who have not played a bus-jam game recently. This is a formative usability sample, not market validation or a representative survey.
- Test in person with the current bus-jam Android build, starting every participant at tutorial 1 with fresh app data. Ask for permission before taking notes or recording; a recording is optional. Do not record names, contact details, or other personal information in this workbook.
- Use tutorial 1 as the first level and a mid-pack generated level (for example `level-010`) as the crowded follow-up.
- Tell each participant: “We are testing the game, not you. Please say what you think as you play.” Do not coach during the first attempt.

### Session steps (about 15 minutes)

1. Show the opening screen and ask what they think the goal is. Do not explain the controls.
2. Let them play the tutorials for up to three minutes. Record time to first move, facing-arrow misreads, blocked taps, and whether the passenger group and boarding spaces are understood.
3. Ask them to explain why a vehicle cannot leave, what space a departing vehicle opens, how matching riders board, and what makes a boarding space fill or clear.
4. If they did not understand the loop, explain it in one sentence and note that you did; let them use Undo, Retry or Hint freely (the build has no ads or purchases).
5. Ask what felt satisfying, what felt unfair or unclear, and whether they would try another level. Do not ask them to rate hypothetical willingness to pay as evidence of actual revenue.
6. Show one crowded follow-up level. Ask what move they would make first and why. Record whether the player predicts which vehicle becomes free after that move.

### Pass/fail observations

- **Comprehension gate:** at least 8 of 10 participants can explain the objective, facing/blocked-path rule, space opened by a departure, and matching-bus behavior after the tutorial without coaching.
- **Friction gate:** any repeated misunderstanding by three or more participants becomes a design issue, even if the comprehension threshold passes.
- **Spatial-planning gate:** at least 7 of 10 can predict one newly available vehicle after a departure on the crowded follow-up level without coaching. Treat this as an internal usability target, not a market benchmark.
- **Next step:** summarize counts and observations only. Change one rule or tutorial element at a time, then rerun with new participants.

### Anonymized notes

| Participant | First move time | Explained goal after tutorial? | Misread or invalid action | Facing/boarding understood? | Predicted next free vehicle? | Change to test |
| --- | --- | --- | --- | --- | --- | --- |
| P01 | | | | | | |
| P02 | | | | | | |
| P03 | | | | | | |
| P04 | | | | | | |
| P05 | | | | | | |
| P06 | | | | | | |
| P07 | | | | | | |
| P08 | | | | | | |
| P09 | | | | | | |
| P10 | | | | | | |

## First 10 teaching beats (proposal)

These are design targets for a future hand-authored first-ten sequence; the current build has three tutorials followed by generated levels. They describe intended instruction, not evidence that players learn the rule or that the difficulty curve works. Revise the sequence after direct competitor play, owner review, and player sessions.

| Level | Intended lesson | Candidate prompt, to rewrite with the final rules | Keep out of this level |
| --- | --- | --- | --- |
| 1 | Notice the vehicle's facing and release one with a clear forward path. | “Follow the arrow. Tap a bus with room ahead.” | Bay traps, undo dependence, hidden color |
| 2 | Recognize that a blocker prevents a forward release. | “This bus is blocked. Free the one in front first.” | Multiple colors or capacities |
| 3 | See that a departure opens the cells it occupied. | “Now the bus behind it can move.” | Bay pressure |
| 4 | Match one visible passenger group to its bus symbol/color. | “Bring the matching bus to the waiting group.” | Mixed groups |
| 5 | Compare two possible releases and choose the useful one. | “Which move opens the next bus?” | Timers and boosters |
| 6 | Understand the selected queue or grouping rule after direct rule validation. | “Watch which riders board next.” | Additional new mechanic |
| 7 | Understand one waiting bus in a boarding space. | “Leave a space for the bus you need.” | Hard deadlock |
| 8 | Use Undo after a poor but legal choice. | “Try another order. Undo is free.” | Required ad or purchase |
| 9 | Plan a short release chain across mixed orientations. | “Clear the vehicle in front, then release the one behind.” | Randomness |
| 10 | Combine facing, blockers, passengers, and bays. | “Check the lane, the riders, and the open spaces.” | Untested difficulty spike |
