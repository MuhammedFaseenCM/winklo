# Stepped how-to-play tutorials — design

Date: 2026-09-25  
Status: approved for implementation

## Goal

Replace the auto-looping, single-screen how-to-play overlay with a **stepped** tutorial for both Zip and Path Words. Users can **Skip** the whole tutorial or tap **Next** through steps. Path Words must teach more than drawing “CAT” — include start markers, locked letters, and clearing every word.

## Product decisions

| Topic | Choice |
|-------|--------|
| Step control | Auto-advance on beat timer (~2.2s), with **Next** / **Skip** |
| Skip | Exits the entire tutorial from any non-final step; same dismiss path as Got it / barrier |
| Last step | **Got it** only (no Skip) |
| Zip content | Keep today’s 4 beats (start → finish → fill every cell → walls) |
| Path Words content | Core play + key constraints (6 steps; no undo/hint/reset chrome) |
| Approach | Evolve shared `GameTutorialOverlay`; game tutorials keep captions + demos |
| First-run / How-to-play button | Same stepped overlay; existing `TutorialRepository` mark-seen behavior |
| Analytics | No new events; keep shown / dismissed / how-to-play-opened |

## Current state

`GameTutorialOverlay` loops captions on a repeating `AnimationController`. Only **Got it** dismisses. Path Words demos three beats (drag → lift → list check) on a CAT path. Zip demos four beats. Both auto-show once via `maybeShow` and reopen from the How-to-play button.

## Approach

Upgrade **`GameTutorialOverlay`** to own step index, auto-advance, and button chrome. `ZipTutorial` / `PathWordsTutorial` continue to pass `captions` + `demoBuilder(context, beat, beatT)`. Extend Path Words captions/demos and, if needed, `TutorialMiniBoard` so start markers and locked cells are visible.

## Shared overlay behavior

### Controls

| Situation | Actions |
|-----------|---------|
| Steps 0 … n−2 | Text **Skip** + filled **Next** |
| Last step | Filled **Got it** only |
| Barrier tap / system dismiss | Same as Skip / Got it → `onDismissed` |

- Auto-advance advances to the next step when the beat timer elapses; on the last step, the demo may loop within that step until the user taps Got it (or barrier dismiss).
- **Next** advances immediately and resets the beat timer / `beatT` for the new step.
- **Skip**, **Got it**, and barrier dismiss all exit and run `onDismissed` once (marks tutorial seen; first-run analytics unchanged).

### Progress

Show simple step dots under the caption (current step highlighted) so progress is obvious without reading button labels.

### Strings (`AppStrings`)

- Add `tutorialSkip` = `Skip`, `tutorialNext` = `Next`
- Reuse `tutorialGotIt` = `Got it`
- Path Words captions (existing + new):
  - `pathWordsTutorialDrag` = `Drag letter to letter`
  - `pathWordsTutorialLift` = `Lift anytime — keep going`
  - `pathWordsTutorialMatchList` = `Match a word on the list`
  - `pathWordsTutorialStartMarker` = `Start from a marked letter`
  - `pathWordsTutorialLockedLetters` = `Used letters stay locked`
  - `pathWordsTutorialFindEveryWord` = `Find every word`
- Zip: no caption changes

### API shape

Keep existing constructor / `show` parameters (`title`, `captions`, `demoBuilder`, `beatDuration`, `gotItLabel`, `onDismissed`). Optionally allow overriding skip/next labels; default to the new shared strings. `demoBuilder` continues to receive `(beat, beatT)` where `beat` is the **current step index** (not a looping total timeline).

Implementation note: replace the single repeating controller spanning all captions with per-step timing (controller duration = one `beatDuration`, restart on step change / Next / auto-advance).

## Path Words steps

| # | Caption intent | Demo focus |
|---|----------------|------------|
| 0 | Drag letter to letter | Finger draws CAT across adjacent cells |
| 1 | Lift anytime — keep going | Mid-path lift, then continue |
| 2 | Match a word on the list | Path completes → list row checks off |
| 3 | Start from a marked letter | Highlight start-cell marker(s) on the mini board |
| 4 | Used letters stay locked | Completed CAT locked; cannot reuse those cells |
| 5 | Find every word | Second short word (e.g. RUN) completes → both checked |

Reuse the existing 3×3 letter grid. Add a second solution path for steps 4–5. Extend `TutorialMiniBoard` only as needed for start markers and locked/completed cell styling. Captions use the `AppStrings` keys listed above.

## Zip steps

Unchanged captions and demo beats:

1. Start at 1  
2. Finish on the last number  
3. Fill every cell  
4. Walls block the path  

Only the shared stepped chrome changes.

## Out of scope

- Undo / hint / reset tutorial tips
- Changing first-run auto-show triggers or “seen” storage keys
- New analytics event names
- Interactive (user-draws) tutorials — demos stay canned
- Redesigning the How-to-play entry button

## Testing

- `game_tutorial_overlay_test`: auto-advance; Next advances early; Skip exits; last step shows Got it only; dismiss completes `onDismissed`
- Path Words tutorial test: six captions / stepped UI; dismiss marks seen
- Zip tutorial test: four captions still; stepped UI; dismiss marks seen
- Update screen smoke tests if they assert old single-button copy

## Success criteria

- Both games show how-to-play as discrete steps with Skip / Next / Got it as specified
- Path Words teaches drag, lift, list match, start markers, locked letters, and finding every word
- Zip keeps its four rules with the new controls
- Skip and Got it both mark the tutorial seen so auto-show does not repeat
