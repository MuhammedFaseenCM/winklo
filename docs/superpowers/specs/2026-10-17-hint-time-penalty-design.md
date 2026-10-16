# Unlimited hints with a time penalty

Date: 2026-10-17 · Branch: `feat/hint-time-penalty` (stacked on `feat/profile-badges`)

## Why

The daily boards rank by time alone, and a hint costs no time: the only price
is losing the Hint-free chip. The 3-hint cap was the only thing keeping a
hinted clear from beating a clean one. Charging time for each hint keeps the
boards fair without a cap, so players who are stuck can always finish.

The user proposed a cooldown before the next hint, with the waiting time
counted in the solve time. We went with an instant penalty instead:

- A cooldown only costs time if the player sits idle. Someone who keeps
  solving during the countdown gets the hint for free.
- The run clock pauses while the app is in the background, so a wall-clock
  cooldown could be waited out with the app minimized.
- A locked hint button is dead time, and dead time is when people quit.

## Rules

- Hints have no cap in any mode.
- In dailies and the archive, the nth hint of a run adds `min(10 × n, 60)`
  seconds to the run clock: +10s, +20s, +30s, +40s, +50s, then +60s each.
  `HintPenalty` (`lib/domain/hint_penalty.dart`) is the one place to tune it.
- Practice hints stay free (no penalty, plain "Hint" label).
- The penalty goes straight into the clock's elapsed time
  (`PlayRunClock.addPenalty`). The saved draft, points, local bests, the score,
  the leaderboard time and the weekly totals all read that clock, so they
  include the penalty with no other changes.
- A run that starts with hints already counted for its period (the board was
  replaced by ops, or the run was started on another device) starts its clock
  at those hints' total penalty, so switching boards or devices can't wipe it.
- Sudoku's "No simple hint right now" costs nothing (no hint is spent).
- Hint-free chips and badges are unchanged: any hint still loses them.

## UI

- The hint button shows the cost of the next hint: "Hint +10s", then
  "Hint +20s". Practice keeps "Hint". The button is never disabled for
  running out.
- The run timer is a debug-only label, so players don't watch it jump. The
  results card adds a line under TIME when hints added time:
  "Includes +30s from hints" (daily and archive results).
- Sudoku's How to play no longer promises 3 hints and explains the cost.

## Data and server

- `HintQuotaRepository` loses `cap` and `remaining`. `consume` spends a hint
  and returns the run's hint count. `usedFor` and `restoreUsed` are unchanged.
- Zip's bloc now spends the hint (it used to be the screen), like the other
  two games. The Flame game only reveals the cells.
- `logHintUsed` sends `hints_used` and `penalty_seconds` instead of
  `hints_remaining`.
- Firestore rules cap `hintsUsed` at 50 and the client already clamps to that
  on sync. Neither the rules nor the leaderboard Worker read hint counts for
  ranking, so no deploy is needed.
