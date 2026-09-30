# Sudoku explanatory hints + daily hint quota — Design

**Date:** 2026-09-30  
**Status:** Implemented  
**Scope:** Replace Sudoku’s fill-from-solution hints with LinkedIn Mini Sudoku–style teachable hints (text + highlights, no auto-fill). Add a shared **HintQuota** persistence layer used by Sudoku, Zip, and Path Words — **3 hints per gameId per play period**, surviving game reset.

---

## 1. Goals

1. Sudoku Hint **explains** a move (banner copy + grid highlights) instead of writing the solution digit.
2. Player still enters the digit themselves after seeing the hint.
3. Support v1 techniques: **last-remaining in row / column / region**, plus **naked single** (only candidate in a cell).
4. Cap assists at **3 hints per game per play period**; reset / clear / re-enter must **not** refill.
5. Apply the same quota model to **Zip** and **Path Words** (keep their existing reveal UX).

### Non-goals

- Advanced techniques (pairs, pointing, X-Wing, etc.)
- Auto-fill after explaining
- Shared global pool across games (quota is **per gameId**)
- Buying / unlocking extra hints
- Backend / cloud sync of hint usage
- Word Match / Category Race hints
- Changing Sudoku scoring or “hinted = no leaderboard”

---

## 2. Decisions (locked)

| Topic | Choice |
|-------|--------|
| Hint fill behavior | **Explain only** — never write the digit |
| v1 techniques | Last-remaining (row / col / region) + naked single |
| Cell selection | Prefer selected empty non-given cell if teachable; else any easy move |
| No teachable move | Banner “No simple hint right now”; **do not** consume quota; **do not** fill |
| Daily quota | **3 per gameId** per play-period bucket |
| Period key | Follow existing `PlayPeriod` / `DevFlags.playPeriod` (daily in prod; minute buckets in debug) |
| Reset | Does **not** restore hints |
| Zip / Path Words | Same quota persistence; keep current reveal hint behavior |
| Copy | All user-facing strings via `AppStrings` |

---

## 3. Architecture

### 3.1 Sudoku hint coach (domain)

Pure Dart helper (e.g. `lib/domain/sudoku/sudoku_hint_coach.dart`) that **does not mutate** the grid.

**Input:** current grid, puzzle metadata (size / box shape), optional `preferredIndex`.

**Output:** `SudokuCoachHint?`:

| Field | Meaning |
|-------|---------|
| `technique` | `lastRemainingRow` / `lastRemainingCol` / `lastRemainingRegion` / `nakedSingle` |
| `targetIndex` | Empty cell the player should fill |
| `digit` | Digit that must go there |
| `evidenceIndices` | Cells that justify the move (blocking same-digit cells, and/or peers that eliminate other candidates for naked single) |
| `excludedIndices` | Other cells in the focused unit that cannot hold `digit` (soft wash) |
| `messageKey` / params | Enough to build `AppStrings` copy (digit + unit kind) |

**Technique priority (when multiple apply to one cell):**  
`lastRemainingRegion` → `lastRemainingRow` → `lastRemainingCol` → `nakedSingle`.

**Search order:**

1. If `preferredIndex` is empty + non-given and has any v1 technique → return the highest-priority one for that cell.
2. Else scan empty non-given cells in row-major order; for each cell evaluate techniques in the priority above; return the first hit.
3. Else return `null`.

**Last-remaining (hidden single in unit):** For digit `d` and a unit (row / col / box), exactly one empty cell in that unit can hold `d` (all other empties are blocked by an existing `d` in their crossing line). Evidence = those blocking `d` cells; excluded = other cells in the unit that cannot hold `d`.

**Naked single:** An empty cell whose candidate set (digits not conflicting with row/col/box) has size 1. Evidence = peer cells that eliminate the other digits (minimal set sufficient to explain); excluded may be empty or unused for this technique’s paint.

Replace `SudokuRules.applyHint` fill behavior: Bloc no longer writes `solution[index]` on hint. Keep placement / validation APIs unchanged for normal play.

### 3.2 Shared hint quota

| Piece | Role |
|-------|------|
| `HintQuotaRepository` (domain interface) | `remaining(gameId)`, `tryConsume(gameId)` → remaining after attempt |
| `HintQuotaRepositoryImpl` (data) | SharedPreferences; key `hints_used_${gameId}_${periodId}` |
| Cap | Constant `3` |
| Period id | `PlayPeriod.id(now, DevFlags.playPeriod)` (same clock source games already use for puzzle ids) |

**Semantics:**

- `remaining` = `max(0, 3 - usedForCurrentPeriod)`.
- `tryConsume`: if remaining == 0, return 0 and do not write; else increment used, return new remaining.
- Missing / stale period key → treat used as 0 for the **current** period (do not migrate old run counters).
- Game **reset**, clear path, or leaving/re-entering the screen must call `remaining` again — never hardcode `hintsRemaining: 3`.

Register in `lib/core/di/` and inject into Sudoku / Zip / Path Words blocs (and Zip Flame only via callbacks that already flow through the app layer — Flame must not own quota persistence).

### 3.3 Feature wiring

**Sudoku**

- State gains: `hintsRemaining`, active coach hint fields (or a single optional `activeHint` value), banner visibility.
- `SudokuEvent.hint()` → if remaining == 0 return; run coach; on `null` emit no-simple banner without consume; on hit `tryConsume`, emit highlights + banner, select target, **grid unchanged**.
- Clear active hint on: banner dismiss, successful place of hinted digit on target, or a new successful hint.
- Wrong digit on target: keep hint UI; existing auto-reject still applies.
- UI: green banner between board and number pad (dismiss ✕); Hint button shows `Hint (n)` and disables at 0.
- Flame / board view: paint target border, evidence fill, excluded wash (extend beyond today’s single-cell `hintFlashIndex`).

**Zip**

- Stop resetting `hintsRemaining = 3` on game reset.
- On start / reset: load `remaining(GameIds.zip)` from repo.
- On successful tip hint: `tryConsume`, pass remaining up for analytics / UI (same reveal behavior as today).

**Path Words**

- Stop setting `hintsRemaining: 3` on start/reset.
- Load from repo; consume on successful hint reveal; reset keeps remaining from repo.

**Analytics**

- Keep `logHintUsed(gameId, hintsRemaining)` with **post-consume** remaining.
- Do not log when Sudoku shows “no simple hint.”

---

## 4. UX copy & visuals

### Banner (Sudoku)

- Teachable last-remaining: e.g. *“This cell has to be {digit} due to all other cells in this {region\|row\|column} being blocked by other {digit}s.”*
- Naked single: e.g. *“This cell has to be {digit} — every other digit conflicts with the row, column, or region.”*
- No move: *“No simple hint right now.”*
- All via `AppStrings`; update how-to-play text that currently says hints are unlimited.

### Grid paint (Sudoku)

| Role | Visual |
|------|--------|
| Target | Bright green border; cell stays empty until player fills |
| Evidence | Solid green background on justifying cells |
| Excluded | Softer green wash on other cells in the focused unit |

Reuse / extend existing green flash palette where possible so the board stays coherent with unit-complete celebration.

---

## 5. Error handling & edge cases

| Case | Behavior |
|------|----------|
| Quota 0 | Hint control disabled; tap no-ops |
| Coach returns null | Soft banner; no consume |
| Preferred cell not teachable | Fall back to another cell’s teachable move |
| Preferred cell filled / given | Ignore preference; scan board |
| Play period rolls over mid-session | Next `remaining` / `tryConsume` uses new period id → fresh 3 |
| Puzzle already solved | Hint no-ops (existing finished guards) |

---

## 6. Testing

1. **Coach unit tests** — fixtures for region / row / col last-remaining and naked single; prefer-selected; null when only harder logic remains.
2. **HintQuotaRepositoryImpl** — consume down to 0; no over-consume; period rollover refreshes; independent `gameId`s; reset path does not refill (tested via repo + bloc).
3. **SudokuBloc** — hint shows coach state without mutating grid; consume once; no-simple does not consume; dismiss / correct place clears active hint.
4. **Zip / Path Words** — reset does not restore remaining; consume persists across bloc recreate with same prefs.

---

## 7. Migration / compatibility

- First launch after change: no prefs key → 3 remaining (same as a fresh period).
- Existing in-memory “3 per run” behavior is removed; players who reset mid-day keep spent hints.
- Sudoku how-to / tagline strings that advertise unlimited hints must be updated.
