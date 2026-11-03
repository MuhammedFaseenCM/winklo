# Admin Levels — design

Date: 2026-11-02
Status: approved, not built
Branch: `feat/admin-levels` (from `master` at `849f27d`); winklo-admin work on a branch of the same name
Builds on: [Zip Levels](2026-10-31-zip-levels-design.md) (this replaces its [Admin](2026-10-31-zip-levels-design.md#admin-winklo-admin) section, "plan 2")

## Problem

Zip Levels is live in the app (plans 1 and 3a), but winklo-admin knows nothing about it. An admin can't see the worlds, can't make or publish a world without a script, and can't tell how far anyone has got, which levels people retry, or where they stop. The app also saves only a level's best clear, so attempts and abandoned runs aren't recorded anywhere.

## Goal

A **Levels** page in winklo-admin with three tabs: **Worlds** (see, edit, generate and publish worlds), **Players** (each player's progress and play counts) and **Stats** (per-level reach, clears, stars, times and drop-off). The app starts counting starts, clears and hints per level so the admin can show plays, not just clears.

## Decisions

| Topic | Choice |
|-------|--------|
| Scope | Progress views **and** the world editor in one design, shipped as two plans (2a: tracking + views, 2b: editor) |
| Play data | The app **tracks plays**: per level `starts`, `clears`, `hints`, `lastPlayedAt` |
| Where plays live | **Counters**, one doc per player per game, `users/{uid}/level_stats/{game}`, written with server-side increments. Not a per-run log, not GA4 |
| Unfinished runs | **Derived**: `starts − clears`. The app never detects a quit |
| Who does the maths | The Worker **fetches and trims**; the browser **aggregates** (`levelsModel.ts`, pure TS) |
| Read cost | One load ≈ 2 reads per player who has played Levels, cached 5 minutes, and capped at 1,000 docs per collection group (the Worker's CPU on the Workers Free plan is the limit). A capped load says so; a nightly rollup is out of scope until the player count needs it |
| Editing progress | **Read-only.** Admin never changes a player's progress or counters |

## 1. App: recording plays

### `users/{uid}/level_stats/{game}`

```jsonc
{
  "levels": {
    "zip_1_07": { "starts": 4, "clears": 2, "hints": 3, "lastPlayedAt": "<server timestamp>" }
  },
  "updatedAt": "<server timestamp>"
}
```

- **Separate from `level_progress` on purpose.** Progress merges conflict-free because every field only improves (max stars, min time). Counters can't merge that way: two phones that each saw 3 starts can't be combined by max (loses plays) or by sum on sync (double counts). Server increments make each phone's writes add up exactly once.
- **Every write** is `set({levels: {<id>: {<counter>: FieldValue.increment(1), lastPlayedAt: serverTimestamp}}, updatedAt: serverTimestamp}, SetOptions(merge: true))`. Firestore queues it offline and sends it later.
- **The app never reads this doc.** Nothing in the progress sync changes.
- **One doc per game**, so the admin's all-players view costs one read per player, not one per level.

### When it counts

All in `ZipBloc` level mode, through a new domain interface `LevelPlayStatsRepository` (`recordStart`, `recordClear`, `recordHint`, each taking the game and level id) and its Firestore implementation.

| Event | Where | Writes |
|---|---|---|
| A new run starts | the board loads with **no saved run**: a first play, a Replay, a draft dropped for a changed board | `starts` +1, `lastPlayedAt` |
| A run is cleared | `_finishLevel`, next to `recordLevelClear` | `clears` +1, `lastPlayedAt` |
| A hint is spent | the hint handler, level mode only | `hints` +1, `lastPlayedAt` |

- Resuming a saved run is **not** a start. Reset (clear the path, keep the run) is **not** a start.
- Writes are fire-and-forget: never awaited by the UI, never blocking play. A failure goes through the existing client-error report (code `level_stats_write_failed`, rate-limited like `level_progress_sync_failed`).
- No signed-in uid → nothing is written.
- Daily, archive and practice runs write nothing here.

### Rules

```
// users/{uid}/level_stats/{gameId}: {levels: map, updatedAt}. Play counters
// for admin views only; the app never reads them back. Entries aren't
// checked one by one (rules can't walk a map with dynamic keys): a hand-edited
// doc only skews its owner's numbers, and the admin drops invalid values.
function validLevelStats(gameId) {
  let data = request.resource.data;
  return validGame(gameId)
    && data.keys().hasOnly(['levels', 'updatedAt'])
    && data.levels is map
    && data.updatedAt == request.time;
}

match /users/{uid}/level_stats/{gameId} {
  allow read: if false;
  allow create, update: if isOwner(uid) && validLevelStats(gameId);
  allow delete: if false;
}
```

`allow read: if false` is safe for merge writes: a `set` with merge needs no read permission.

### Account deletion

`workers/account-deletion/src/firestore_wipe.ts`: add `level_stats` to `USER_SUBCOLLECTIONS`, with its test. (That Worker's deploy is already an open follow-up.)

### Existing players

Players who cleared levels before this release have `level_progress` but no `level_stats`. The admin shows their clears from progress and "—" for starts, unfinished and hints.

## 1b. App fixes shipped with plan 2a

### Play from the level sheet while signed out

**Bug**: a signed-out player taps Play (or Replay) in the level sheet and lands on Home. The sheet pushes `/zip?mode=level…` directly; `playAuthRedirect` sends any signed-out play location to `/`.

**Fix**: the sheet's Play calls `ensureSignedInForPlay(context)` first, like Home, Archive, More play and the Leaderboard do. The sign-in sheet opens over the level sheet (both on the root navigator); the level is pushed only when it returns true, after closing the level sheet. Cancelling the sign-in leaves the level sheet open. The router redirect stays as the backstop for links.

### A dark Ink world

**Problem**: the Ink world's backdrop is light rice paper (`#EFE8D8`); the rest of the app (`ZipColors.ink` `#0F172A`) and the Metro world (`#13233A`) are dark, so the Levels tab is the one light screen.

**Fix**: Ink becomes **ink-stone**, a warm near-black ground, so it stays distinct from Metro's navy while matching the app. Same material, inverted: the line is rice-paper white on the stone.

| Element | Was | Becomes |
|---|---|---|
| Ground (backdrop, node discs, the star-mark patch) | `#EFE8D8` paper | `#1C1915` ink-stone |
| Grid | vermilion `#C2410C` at 0.28 | vermilion at 0.30 |
| Reached line | `#2B2724` ink, 8 px | `#EFE8D8` rice paper, 8 px |
| Unreached road (dots), locked ring | `#A8A29E` pencil | `#78716C` |
| Node ensō and number | `#111111` | `#EFE8D8`; locked number `#A8A29E` |
| Star seals | `#B91C1C` | `#DC2626` (contrast on stone) |

The colours move into one `InkPalette` class (`lib/features/levels/view/widgets/ink_palette.dart`) that the backdrop, path, node and star painters read, instead of each painter keeping its own copy. World labels already sit on a dark chip and don't change. A render of the map at 360 px is checked before the task is done.

## 2. admin-api (Cloudflare Worker)

All routes go behind the existing `requireAdmin`. `:game` accepts only `zip` for now (a list, so Path Words and Sudoku can join later).

### Worlds (the editor) — plan 2b, except `GET /worlds`, which plan 2a needs for the read-only list and the level numbering

| Route | Does |
|---|---|
| `GET /v1/levels/:game/worlds` | Every world of the game, published or not: `id`, `order`, `theme`, `title`, `published`, `updatedAt`, and per level `{id, size, targetSeconds}` (no boards) |
| `GET /v1/levels/:game/worlds/:order` | One world in full, plus its Firestore `updateTime` |
| `PUT /v1/levels/:game/worlds/:order` | Save (create or replace). Body includes the `updateTime` it loaded (absent for a new world) |
| `POST /v1/levels/:game/worlds/:order/publish` | Publish |
| `POST /v1/levels/:game/worlds/:order/unpublish` | Unpublish |
| `DELETE /v1/levels/:game/worlds/:order` | Delete an unpublished world that has no world after it |

Save checks (any failure → 400 with the list of problems, nothing written):

- `order` is a whole number ≥ 1. The doc id is `{game}_{order}`; the doc's `game` and `order` fields match it.
- `theme` is one of `ink`, `metro`, `embroidery`, `neon`, `sparkler`. `title` is a non-empty string.
- `levels` has 1–40 entries. Each `id` is `{game}_{order}_{nn}` (two digits, from `01`), unique, and numbered in play order.
- Every board passes the existing Zip validator (the same checks `validateCmsDocument` runs for `zip_levels`), and every board in a world has the world's size.
- `targetSeconds` is a whole number ≥ 1, or absent (the app hides the time goal).
- **Publish lock**: if the stored world is published, the new `levels` must have the same ids in the same order. Boards, targets, theme and title stay editable.
- **Stale save**: the write uses the loaded `updateTime` as a Firestore precondition. A mismatch returns 409, shown as "Changed elsewhere. Reload to see the latest." A create uses `exists: false` the same way.

Publish order (keeps every level number fixed, as the Zip Levels spec requires):

- Publish world *n* is refused (409) while world *n − 1* is missing or unpublished. The message names that world.
- Unpublish world *n* is refused (409) while world *n + 1* is published.
- Both set `updatedAt` to the server time.

Board coordinates: Firestore can't hold an array directly inside an array, so `level_worlds` stores `solution` cells and wall ends as `"r,c"` strings (as the seeded World 1 does; the app's `Cell.fromJson` reads them). The Worker converts `"r,c"` ↔ `[r, c]` on read and write, so the admin editors keep the `[r, c]` shape they use for `zip_levels`. A round-trip test pins this.

### Progress (the read views) — plan 2a

| Route | Does |
|---|---|
| `GET /v1/levels/:game/progress` | Every player who has played Levels, as compact rows |
| `GET /v1/levels/:game/players/:uid` | The same row for one player (404 if they have neither doc) |

`/progress` runs two collection-group queries over the Firestore REST API (`level_progress` and `level_stats`), keeps documents whose id is `:game`, takes the uid from each document path, and joins them by uid:

```jsonc
{
  "players": [
    {
      "uid": "abc",
      "records":  { "zip_1_01": { "stars": 3, "bestSeconds": 14 } },          // from level_progress, may be {}
      "counters": { "zip_1_01": { "starts": 2, "clears": 1, "hints": 0, "lastPlayedAt": "2026-11-02T10:00:00Z" } },
      "hasCounters": true,                                                   // false when no level_stats doc
      "updatedAt": "2026-11-02T10:00:00Z"                                    // the later of the two docs
    }
  ],
  "truncated": false,                                                        // true when a collection group hit the cap
  "limit": 1000                                                              // docs read per collection group at most
}
```

- **The cap.** Each collection group is read 500 docs a page, 2 pages at most (≤ 1,000 docs), ordered by document name. A truncated load drops players past the earlier of the two groups' cutoffs, so no player comes back half-joined; the Players and Stats tabs show a warning with the limit. Check the Worker's CPU time in the Cloudflare dashboard before raising it.

- **The Worker only trims.** It drops invalid values with the app's rules (stars 1–3, best time ≥ 1, counters whole numbers ≥ 0) and sends nothing else. All counting, joining with worlds and sorting is in the browser. This keeps the Worker's CPU time small on its plan.
- Collection-group queries with no filter need no new index.

## 3. Admin UI — the Levels page

A **Levels** item in the sidebar (lucide icon, matching the others), lazy-loaded like every page (`pageLoaders.levels`). Route `/levels`, tabs in `?tab=worlds|players|stats` via `useTabParam` (default `worlds`). A Zip badge in the header names the game; a switcher comes when a second game has levels.

### Worlds tab

- **List** (plan 2a, read-only): a card per world — "World N · Theme", board size, level count, a Published or Draft badge, last updated.
- **New world** (2b): the next order, size defaulting to order + 3, theme defaulting to the next of Ink → Metro → Embroidery → Neon → Sparkler.
- **World page** `/levels/zip/:order` (2b):
  - Header: theme dropdown, title, Save, Publish or Unpublish, Generate world (drafts only), Delete (drafts with no later world).
  - A row per level: Level N (worked out across published worlds, as in the app), id, number count, wall count, target time.
  - A row opens the existing **`ZipBoardEditor`** with a target-time field, checked live by `validateZip`.
  - Adding, removing and reordering levels is disabled on a published world, with a line saying why.
  - Leaving with unsaved changes asks first (`useUnsavedChanges`).

### Generate world (2b)

Inputs: size (4–8) and level count (default 20). Output replaces the draft's levels after a confirm.

- For level *i* of *N* (`t = i / (N − 1)`, `t = 0` when `N = 1`): numbers fall and walls rise linearly between per-size bounds (`levelRamp(size, t)` in a new `levelRamp.ts`, beside `zipDifficulty.ts`). Early levels have many numbers and no walls; the last ones are as sparse as the daily "Hard" band.
- Boards come from the existing seeded `generateZip`, extended with an optional exact `{numbers, walls}` count, run in the existing generator web worker. The seed is derived from world order and level index, so a regenerate is reproducible.
- Each board must pass `validateZip`; a failure retries with the next seed (bounded; after the bound, generation stops and names the level).
- Suggested `targetSeconds` = round(size² × seconds per cell): 4×4 → 1.25, 5×5 → 1.2, 6×6 → 1.15, 7×7 → 1.1, 8×8 → 1.05 (4×4 → 20 s, as the Zip Levels spec's example). Starting values, editable per level.

### Players tab (2a)

| Column | From |
|---|---|
| Player | name and email from the existing `/v1/platform/users/lookup` route, in batches; the uid under it. A uid with no Auth account shows "Deleted account" |
| Current level | the first published level, in map order, that isn't cleared; "All cleared" when none |
| Cleared | records ∩ published levels, as "14 / 40" |
| Stars | sum of stars, as "35 / 118": each level counts up to 3 stars, or 2 when it has no target time (as the app does) |
| Starts | sum of `starts`, or "—" without counters |
| Unfinished | sum of `max(0, starts − clears)`, or "—" |
| Hints | sum of `hints`, or "—" |
| Last played | the latest `lastPlayedAt`, else the progress `updatedAt` |

- Every column sorts. A search box filters loaded rows by name, email or uid. Default sort: Last played, newest first.
- A Refresh button refetches; the query is cached 5 minutes (React Query `staleTime`).
- A row opens **`/levels/zip/players/:uid`**: a summary (current level, cleared, stars, starts, unfinished, hints) and a row per published level — Level N, world, stars (drawn, not emoji), best time against the target, starts, clears, hints, last played. Levels the player hasn't reached are dimmed.
- **Users tab**: each row's menu gets **View levels**, linking to that page.

### Stats tab (2a)

Per world: players who reached it, players who cleared all of it, stars earned of the stars possible.

Per level:

| Column | Definition |
|---|---|
| Reached | players for whom it is Level 1, or who cleared the level before it |
| Cleared · rate | players with a record for it · cleared ÷ reached |
| Avg stars · 3★ | mean stars of those who cleared · share with 3 stars |
| Median best | median `bestSeconds`, shown against `targetSeconds` |
| Tries per clear | Σ starts ÷ Σ clears, players with counters only |
| Unfinished | Σ `max(0, starts − clears)`, players with counters only |

A **"Where players are stuck" chart** (the repo's `RankedBars`) shows players by the level they are on now — their first uncleared level — a bar per map level in map order, with players who cleared everything counted separately below it. A long bar is a level that stops people. (Built this way instead of "furthest level cleared": that version hid players who tried Level 1 and quit, and showed finished players as drop-off at the last level.)

Players without counters are left out of the counter columns, and the tab says how many that is ("Play counts cover 31 of 42 players").

## Errors

| Situation | Behaviour |
|---|---|
| A route fails | The existing `ApiError` handling: a toast, the page keeps its last data, Retry |
| Nobody has played Levels | Players and Stats: "No one has played Levels yet" |
| No worlds | Worlds: "No worlds yet" and New world (2b) |
| Publish out of order / unpublish with a later world | 409; the toast names the world that has to change first |
| Stale save | 409: "Changed elsewhere. Reload to see the latest." |
| Invalid board on save | 400 with each problem; the row is marked |
| A player's doc holds bad values | Dropped by the Worker; the rest of the row shows |
| A uid with no Auth account | "Deleted account" (the deletion Worker wipes both docs once it is deployed) |

## Testing

- **App** (`flutter test`):
  - `bloc_test` for ZipBloc level mode: a fresh run and a Replay record a start; a resumed run and Reset don't; each hint records one; a clear records one; signed out records nothing; a repository failure is reported and play goes on.
  - The Firestore implementation against a fake: merge writes, increments on the right nested field, server timestamps.
  - Daily, archive and practice record nothing.
- **Rules**: the `level_stats` cases written beside the existing ones (owner create/update, extra keys refused, no read, no delete). They still need Java to run in the emulator, as before.
- **Deletion Worker** (vitest): `level_stats` is wiped.
- **winklo-admin** (vitest):
  - `levelsModel`: current level, reached, medians, tries per clear, players without counters, bad values, all cleared.
  - Worker routes: auth, the `zip` game list, the progress join, bad values dropped; (2b) publish order, publish lock, id checks, size checks, the `"r,c"` round trip, the stale-save 409, delete rules.
  - `levelRamp` and Generate world: monotonic ramp, every board valid, reproducible by seed, targets as listed.
  - UI: the three tabs, sorting and search, player page, the Users tab link, empty and error states.
  - The existing Playwright mobile checks extended to the Levels page.

## Build order

**Plan 2a — tracking and views**

1. App: `LevelPlayStatsRepository`, ZipBloc counting, rules, the deletion list; the two fixes in 1b (sign-in from the level sheet, the dark Ink world).
2. admin-api: `/progress` and `/players/:uid`.
3. Admin: `levelsModel.ts`, the Levels page with the read-only Worlds list, Players, the player page, Stats, the Users tab link.

**Plan 2b — the editor**

4. admin-api: worlds routes, checks, publish order, `"r,c"` conversion.
5. Admin: New world, the world page with `ZipBoardEditor`, Generate world (`levelRamp.ts`, exact counts in `generateZip`).

Deploys stay with the user: Firestore rules, an app release, the admin-api Worker, the admin site, and the account-deletion Worker.

## Out of scope

Editing a player's progress or counters; a per-run history; a nightly rollup for large player counts; GA4 level events; Path Words and Sudoku levels (the routes, docs and page are already keyed by game).
