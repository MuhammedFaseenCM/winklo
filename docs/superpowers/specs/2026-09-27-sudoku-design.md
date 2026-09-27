# Sudoku — Design Spec

**Date:** 2026-09-27  
**Status:** Approved (design sections §1–§4)  
**Working product name:** Sudoku  
**Scope:** Daily competitive 6×6 Sudoku with Flame board, seeded generator, rotating difficulty, notes/unlimited hints/auto-check, Zip-style score/streak/leaderboard/results.

---

## 1. Goals

1. Ship a new daily game **Sudoku** beside Zip and Path Words.
2. **6×6** board (digits 1–6, **2×3** boxes), one shared puzzle per calendar day.
3. Difficulty **rotates by day** (easy / medium / hard) from the date seed.
4. Full assists: **notes**, **unlimited hints**, **auto-reject wrong placements** — assists do **not** affect score.
5. Follow Winklo architecture: feature-first UI + BLoC, pure domain rules, Flame as **thin renderer/input** only (Bloc owns play state).
6. Reuse **SubmitScore**, **RecordDailyClear**, **SubmitLeaderboardTime**, results screen, and home/routing patterns from Zip / Path Words.

### Non-goals (v1)

- 9×9 or other sizes
- Unlimited / practice boards
- Hint penalties or “hinted = no leaderboard”
- Cloud-authored puzzles or admin puzzle upload
- Multiplayer

---

## 2. Decisions (locked)

| Topic | Choice |
|-------|--------|
| Product model | Daily competitive (one clear / day) |
| Grid | 6×6, digits 1–6, boxes 2×3 |
| Difficulty | Rotates easy/medium/hard by day |
| Assists | Notes + unlimited hints + auto-check wrong |
| Scoring | Time-only Zip formula: `(1000 - elapsedSeconds * 5).clamp(50, 1000)` |
| Board UI | Flame (Bloc owns state) |
| Puzzle source | Seeded client generator |
| Feature folder | `lib/features/sudoku/` |
| Game id | `GameIds.sudoku = 'sudoku'` |
| Copy | All user-facing strings via `AppStrings` |
| State modeling | `freezed` events/states |

---

## 3. Architecture

### 3.1 Feature layout

```text
lib/features/sudoku/
  bloc/           # SudokuBloc + freezed events/states
  view/           # SudokuScreen + chrome (pad, notes, how-to-play)
  game/           # SudokuGame — draw + forward cell taps only
```

### 3.2 Domain

- **Entities**
  - `SudokuDifficulty`: `easy | medium | hard`
  - `SudokuPuzzle`: `id` / `dateId`, `size: 6`, `boxRows: 2`, `boxCols: 3`, `given` (36 ints, 0=empty), `solution` (36 ints), `difficulty`
- **Game id:** `GameIds.sudoku`
- **Generator:** pure Dart, deterministic for `(dateId, generatorVersion)`
- **Rules:** place/erase digit, toggle notes, auto-check vs solution, hint cell pick, win detection
- **Scoring:** `SudokuScoring.pointsForElapsed` (same formula as Path Words)

### 3.3 Integration

- Router: `/sudoku`
- Home: new card/entry beside Zip and Path Words
- Score key: `sudoku_<playId>`
- On win: `SubmitScore` + `RecordDailyClear` + `SubmitLeaderboardTime` → `/results` with `ResultsArgs` (`replayRoute: '/sudoku'`)
- Leaderboard allowlist includes `sudoku`

### 3.4 Flame ↔ Bloc contract

- **Source of truth:** Bloc state (puzzle, grid, notes, selection, notes mode, timer, status, flashes).
- **Flame responsibilities:** layout cells; paint givens, filled digits, notes, selection, hint/reject flash; map pointer → `Cell`; emit tap callbacks upward.
- **Flame must not:** own notes mode, hint logic, win submission, or timer.
- Number pad / notes / hint / reset stay Flutter chrome outside Flame.

---

## 4. Gameplay rules

1. Tap a cell to select; givens are locked.
2. Number pad places 1–6 in the selected empty cell (or clears with erase).
3. **Notes mode:** pad toggles pencil candidates in the cell instead of a firm digit.
4. **Auto-check:** placing a digit that ≠ solution is rejected (brief flash); cell stays empty or keeps prior value. Wrong entries never stick.
5. **Hint (unlimited):** fills one empty cell with its correct solution digit (prefer selected empty cell, else first empty in row-major order); flash that cell.
6. **Reset:** clears all player digits/notes; restores same daily puzzle; timer keeps running from first start.
7. **Win:** all cells match solution → points from elapsed → submit → results. Already cleared today → locked (view result).

### Chrome

- Top: title, difficulty badge, timer
- Board: Flame 6×6 with thick 2×3 box lines
- Bottom: notes toggle, pad 1–6 + erase, Hint, Reset, How to play

---

## 5. Daily generator

**Inputs:** calendar `DateTime` day (local).  
**Output:** `SudokuPuzzle` with unique solution.

**Algorithm:**

1. Seed RNG from `Object.hash(dateId, generatorVersion)`.
2. Map day → difficulty: `dayOrdinal % 3` → easy / medium / hard.
3. Build a random valid full 6×6 (band/stack pattern + remaps, or backtracking).
4. Dig clues while keeping **unique solution**; stop at clue-count targets:
   - easy 22–26, medium 16–21, hard 12–15 of 36.
5. Same `(dateId, generatorVersion)` → identical puzzle for everyone.
6. Fallback: if dig fails after bounded retries, use deterministic canned full grid + dig with same seed index.

---

## 6. Scoring & persistence

- Points: `(1000 - elapsedSeconds * 5).clamp(50, 1000)`
- Mode key: `sudoku_<playId>` where `playId = PlayPeriod.id(...)`
- Streak via `RecordDailyClear(gameId: GameIds.sudoku, ...)`
- Leaderboard via `SubmitLeaderboardTime(gameId: GameIds.sudoku, ...)` on improved local best
- Assists (hints, notes, auto-check) do **not** change points

---

## 7. Testing

- Domain: generator determinism, uniqueness, difficulty rotation, place/reject, notes, hint, win, scoring
- Bloc: started → locked if cleared; digit/notes/hint/reset; reject wrong; complete → score submit
- Widget smoke: screen renders pad + board; how-to-play opens
- Update home/leaderboard tests that enumerate games

---

## 8. Errors / edge cases

- Generator failure: retry then canned fallback (still deterministic)
- Double-submit win: one-shot guard
- Tap given / locked day: no-op
- Analytics: game open + clear with `GameIds.sudoku`
