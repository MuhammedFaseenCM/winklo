# Pause-aware game run persistence — implementation plan

> **For agentic workers:** Follow this plan task-by-task. Spec:
> `docs/superpowers/specs/2026-10-03-pause-persist-game-timer-design.md`

**Goal:** Persist Zip / Path Words / Sudoku board + pausable elapsed time across leave / background / kill.

**Architecture:** `PlayRunClock` + `InProgressRunRepository` (SharedPreferences); blocs own clock and drafts; screens report lifecycle; Zip Flame no longer owns scoring time.

## Status

Implemented in-repo:

- [x] Design spec
- [x] `PlayRunClock` + prefs repository + DI
- [x] Sudoku / Path Words / Zip blocs + lifecycle screens
- [x] Draft clear on finish / lock
- [x] Unit / bloc tests for clock, restore, pause, reset-preserves-elapsed

## Manual check

- Start Sudoku, enter digits, home button, resume → same grid + elapsed continues from pause
- Reset mid-run → board clears, timer does not
- Finish clear → draft gone; reopen is locked
