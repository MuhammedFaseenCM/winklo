# Flow — Design Spec

**Date:** 2026-10-02  
**Status:** Approved (design sections §1–§4)  
**Working product name:** Flow  
**Scope:** Daily competitive freehand connect-the-pairs puzzle (no grid). Flame canvas, seeded generator + admin override, Zip-style score/streak/leaderboard/results.

---

## 1. Goals

1. Ship a new daily game **Flow** beside Zip, Path Words, and Sudoku.
2. Empty canvas with colored endpoint pairs — **no grid, no cells, no cell background**.
3. Player draws **freehand** from a colored point to its matching partner.
4. Only hard rule: **lines must not cross** (other completed paths or the active stroke itself).
5. Win when every pair is connected with valid non-crossing paths.
6. Full daily competitive stack: one clear / day, time score, streak/freeze, home tile, leaderboard tab, results mini-board.
7. Difficulty = **pair count + tangle level**; rotates by day; admin can override knobs or publish a full custom layout.
8. Follow Winklo architecture: feature-first UI + BLoC, pure domain rules, Flame as thin renderer/input only.

### Non-goals (v1)

- Grid, cell painting, or snap-to-grid validation
- “Fill every cell” / pack-the-board requirement
- Practice packs / unlimited boards
- Multiplayer
- Hint system (can add later; not required for v1)
- Reviving Word Match / Category Race as dailies

---

## 2. Decisions (locked)

| Topic | Choice |
|-------|--------|
| Product model | Daily competitive (one clear / day) |
| Board | Empty canvas; endpoints only |
| Input | Freehand polylines (Flame) |
| Core rule | No line crossings |
| Win | All pairs connected without crossings |
| Difficulty | Pair count + tangle; easy / medium / hard by day |
| Puzzle source | Hybrid: seeded client generator; Firestore daily override |
| Scoring | Time-only Zip formula: `(1000 - elapsedSeconds * 5).clamp(50, 1000)` |
| Board UI | Flame (Bloc owns state) |
| Feature folder | `lib/features/flow/` |
| Game id | `GameIds.flow = 'flow'` |
| Route | `/flow` |
| Copy | All user-facing strings via `AppStrings` |
| State modeling | `freezed` events/states |
| Architecture approach | Flame canvas + polyline strokes + domain crossing checks |

---

## 3. Architecture

### 3.1 Feature layout

```text
lib/features/flow/
  bloc/           # FlowBloc + freezed events/states
  view/           # FlowScreen + chrome (reset, how-to-play)
  game/           # FlowGame — draw dots/paths; forward pointer samples only
```

### 3.2 Domain

- **Entities**
  - `FlowDifficulty`: `easy | medium | hard`
  - `FlowEndpointPair`: `id`, `colorIndex`, `a` / `b` as normalized `Offset`-like points in `[0,1]×[0,1]`
  - `FlowPuzzle`: `id` / `dateId`, `pairs`, `pairCount`, `tangle`, `difficulty`, `generatorVersion`
  - `FlowPath`: ordered list of normalized points for one pair (completed or active)
- **Game id:** `GameIds.flow`
- **Generator:** pure Dart, deterministic for `(dateId, generatorVersion)`; outputs a layout known to be solvable at the chosen band
- **Rules:** start stroke on endpoint; extend with samples; finish on matching endpoint; reject on cross; replace path when redrawing a color; win detection
- **Crossing:** pure geometry on polyline segments (active vs completed; active vs itself)
- **Scoring:** `FlowScoring.pointsForElapsed` (same formula as Zip / Path Words / Sudoku)

### 3.3 Flame ↔ Bloc contract

- **Source of truth:** Bloc (puzzle, completed paths, active stroke, timer, status, reject flash).
- **Flame responsibilities:** layout canvas; paint endpoints and paths; map pointer → normalized point; emit down/move/up samples upward.
- **Flame must not:** own timer, win submission, crossing policy, or puzzle loading.

### 3.4 Integration

- Router: `/flow`
- Home: new daily tile beside Zip / Path Words / Sudoku
- Score key: `flow_<playId>`
- On win: `SubmitScore` + `RecordDailyClear` + `SubmitLeaderboardTime` → `/results` with `ResultsArgs` (`replayRoute: '/flow'`, `gameId: GameIds.flow`)
- Leaderboard allowlist includes `flow`
- Analytics / tutorials / how-to-play follow existing game patterns

---

## 4. Daily puzzle + admin

### 4.1 Default (no admin doc)

Client generator from `dateId` + `generatorVersion`:

1. Map day → difficulty band (easy / medium / hard rotation).
2. Band → `pairCount` + `tangle`.
3. Place endpoint pairs in normalized space so a solution exists without forced crossings.

### 4.2 Difficulty bands

| Band | Pairs (approx) | Tangle |
|------|----------------|--------|
| Easy | 4 | low |
| Medium | 6 | medium |
| Hard | 8 | high |

Exact numeric tangle parameters live in the generator implementation; bands are the product-facing dial. Admin may override `pairCount` and/or `tangle` independently.

### 4.3 Admin override (hybrid)

- Firestore collection e.g. `flow_levels` with doc id `daily_YYYYMMDD` (same override pattern as Zip / Path Words / Sudoku).
- Admin CMS can:
  - set band / `pairCount` / `tangle` and **Generate**, or
  - drag endpoints and **Save** a full custom layout.
- Client validator in admin blocks Save on unsolvable / invalid layouts (duplicate colors, missing partners, endpoints out of bounds).
- Mobile load order: try Firestore override → else seeded client puzzle. If override is malformed at runtime, fall back to seeded puzzle.

### 4.4 Play UX

- Start stroke only on an endpoint; finish only on its matching partner.
- Redrawing a color replaces that color’s previous completed path.
- Crossing while drawing rejects the **active** stroke only (flash + cancel that drag); completed paths stay.
- Stroke start off-dot → ignored.
- Pointer leaves canvas mid-drag → cancel active stroke.
- Reset clears all paths (and counts against a clean-run chip if/when wired like other dailies).

---

## 5. Scoring, errors, testing

### 5.1 Scoring

- Formula: `(1000 - elapsedSeconds * 5).clamp(50, 1000)`
- Timer starts on first accepted stroke down.
- No pause in v1.

### 5.2 Errors / edge cases

| Case | Behavior |
|------|----------|
| Stroke starts off-dot | Ignore |
| Lift on wrong-color endpoint | Reject active stroke |
| Cross detected | Reject active stroke; keep completed paths |
| Leave canvas mid-drag | Cancel active stroke |
| Bad / missing override | Fall back to seeded client puzzle |
| Unsolvable admin layout | CMS validator blocks Save |

### 5.3 Testing

- Domain: segment intersection, win check, generator determinism, solvability smoke for each band
- Bloc: start / extend / finish / reject / reset / win → submit usecases
- Widget/smoke: home tile → `/flow` → results

---

## 6. Admin / platform follow-ups (same release train preferred)

- Add Flow to winklo-admin Game Content CMS (generate + endpoint editor + validator)
- Leaderboard / ops allowlists include `flow`
- Firestore rules: read override docs; client write still false
- Home / leaderboard / store copy updated for four dailies

---

## 7. Open naming note

Working title is **Flow**. Final store/UI name can change before ship if trademark / brand review prefers another label; `GameIds.flow` and feature folder stay unless explicitly renamed in a follow-up.
