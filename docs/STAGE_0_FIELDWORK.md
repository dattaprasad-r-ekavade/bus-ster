# Stage 0 fieldwork workbook

_Prepared 11 October 2026. No hands-on competitor session or external player session has been run yet._

Use this workbook to close the Stage 0 evidence gates in [`GAME_PLAN.md`](../GAME_PLAN.md). Store-listing descriptions and review snippets are useful discovery signals, but do not substitute for playing the apps or observing people try Bus-ster.

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

## Gray-box player session

### Setup

- Recruit 10 adults who have not played a bus-jam game recently. This is a formative usability sample, not market validation or a representative survey.
- Test in person with the same Android build and the same starting level. Ask for permission before taking notes or recording; a recording is optional. Do not record names, contact details, or other personal information in this workbook.
- Prepare two paper variants: the current shared-exit/FIFO/bay rules and one route-switch junction concept. Randomize which concept is shown first across sessions where practical.
- Tell each participant: “We are testing the game, not you. Please say what you think as you play.” Do not coach during the first attempt.

### Session steps (about 15 minutes)

1. Show the opening screen and ask what they think the goal is. Do not explain the controls.
2. Let them play Depot 01 for up to three minutes. Record time to first move, route misreads, invalid taps, and whether the visible queue is understood.
3. Ask them to explain what happens to a dispatched bus, how riders board, and what makes the bay fill or clear.
4. Show the optional “How to play” dialog if they did not understand the loop; let them retry or use Undo/Route Tip without prompting a purchase or ad.
5. Ask what felt satisfying, what felt unfair or unclear, and whether they would try another depot. Do not ask them to rate hypothetical willingness to pay as evidence of actual revenue.
6. Show the route-switch paper variant. Ask them to solve one small board, compare it with the baseline, and say what changed. Record confusion as carefully as preference.

### Pass/fail observations

- **Comprehension gate:** at least 8 of 10 participants can explain the objective, route blocker, FIFO order, and matching-bus behavior after the tutorial without coaching.
- **Friction gate:** any repeated misunderstanding by three or more participants becomes a design issue, even if the comprehension threshold passes.
- **Differentiation gate:** participants can describe the route-switch mechanic unaided after play, and prefer its strategic choice to the baseline often enough to justify a second prototype. Do not claim differentiation from one small round of tests.
- **Next step:** summarize counts and observations only. Change one rule or tutorial element at a time, then rerun with new participants.

### Anonymized notes

| Participant | First move time | Explained goal after tutorial? | Misread or invalid action | Queue/bay understood? | Route-switch variant reaction | Change to test |
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

These are sequencing goals, not a claim that the current ten prototype levels already teach them cleanly. Revise after the teardown and sessions.

| Level | Intended lesson | Keep out of this level |
| --- | --- | --- |
| 1 | A clear-route bus can be dispatched; identify the exit and route symbol. | Bay traps, undo dependence, hidden colors |
| 2 | The visible FIFO queue determines who boards next. | Multiple new blockers |
| 3 | A mismatched bus can wait safely while the player sends a needed bus. | New booster or timer |
| 4 | A bus blocks a road node; opening the road changes which bus can move. | Tight bay pressure |
| 5 | Compare two reachable buses and choose the order that serves the next riders. | Extra route colors beyond what is needed |
| 6 | A second bay gives temporary flexibility, but a full bus leaves and frees space. | Hard deadlock |
| 7 | Follow a branch through a junction to the shared exit. | Color-only distinctions |
| 8 | Plan a short dispatch sequence around both queue order and road blocking. | Randomness |
| 9 | Introduce the tested route-switch mechanic only if Stage 0 validates it. | Combining it with several unlearned rules |
| 10 | Review the first eight lessons in a compact capstone; allow Undo and a solver hint. | Required ad/purchase or an untested difficulty spike |
