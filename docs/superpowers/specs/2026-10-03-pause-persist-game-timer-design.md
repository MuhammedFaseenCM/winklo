# Pause-aware game run persistence — design

Date: 2026-10-03  
Status: approved for implementation  
Repos: winklo

## Goal

For Zip, Path Words, and Sudoku: start the run clock when the puzzle is first shown; never restart it on reset / erase / undo / hints; pause and save board + elapsed when the player leaves, backgrounds, or kills the app; resume board and clock when they return.

## Decisions

| Decision | Choice |
|----------|--------|
| Scope | Zip, Path Words, Sudoku |
| Clock model | Pausable `elapsedMs` + optional `resumedAt` (`PlayRunClock`) |
| Away time | Does **not** count (pause while not on game screen) |
| Persistence | Local SharedPreferences drafts |
| Key | `in_progress_<gameId>_<playId>` via `PlayPeriod.id` |
| Reset / erase / undo / hints | Do **not** touch the clock |
| Finish | Clear draft after successful clear path starts |

## Clock

```
displayedMs = elapsedMs + (resumedAt == null ? 0 : now - resumedAt)
```

- First playable view (`ready`): `elapsedMs = 0`, `resumedAt = now`
- Pause / leave / background: fold live delta into `elapsedMs`, clear `resumedAt`, persist
- Resume / reopen with draft: restore `elapsedMs`, set `resumedAt = now`
- Finish: `timeSeconds = displayedMs ~/ 1000`, then clear draft

## Storage

`InProgressRunRepository` (domain) + SharedPreferences impl.

Envelope: `gameId`, `playId`, `elapsedMs`, `usedHintsThisRun`, optional `hadMistakesThisRun`, plus game board body.

| Game | Board fields |
|------|----------------|
| Sudoku | `grid`, `notes`, `notesMode` |
| Path Words | `activePath`, `placedPaths`, `completedTargetIds`, `hintRevealLength` |
| Zip | `path` (cells) |

Write after meaningful board changes (debounced) and always on pause / dispose.  
Restore only when draft `playId` matches and day is not already cleared.  
Ignore / clear stale playId drafts.

## Ownership

- Blocs own clock + drafts; screens report lifecycle pause/resume.
- Zip: scoring time moves out of Flame (`ZipGame.startedAt`); game snapshots / restores path only.

## Out of scope

- Word Match / Category Race
- Cloud / cross-device sync
- Pausing for how-to-play modals (clock runs while puzzle is on screen under the modal)

## Success criteria

- Partial progress survives back navigation, home button, and kill.
- Away time does not inflate submitted `timeSeconds`.
- In-run reset / undo / erase keep elapsed continuous.
- Finish submits one time and removes the draft.
