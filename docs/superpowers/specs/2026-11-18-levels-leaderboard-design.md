# Levels leaderboard — design

Date: 2026-11-18
Status: approved, not built
Builds on: [Zip Levels](2026-10-31-zip-levels-design.md) (which listed "level leaderboards" as out of scope), [Realtime leaderboard](2026-09-24-realtime-leaderboard-design.md), the leaderboard Worker (`workers/leaderboard`)

## Why

Levels has stars, but they only matter on your own map. A board ranked by stars gives players a reason to collect every star, including going back to replay a level for the one they missed, and gives the players who already have everything a race to keep running.

## Decisions

| Topic | Choice | Whose |
|-------|--------|-------|
| What's ranked | **Total stars** across a game's levels; more is better | User |
| Ties | Stars ↓, then **fewer levels cleared** ↑, then **lower total best time** ↑. Equal on all three = same place (dense rank, as on the daily boards); `updatedAt` orders rows within a shared place | User |
| Trust | **The leaderboard Worker checks every level clear** (Approach A below). No client writes to the board | User |
| Stars from before launch | **Everyone starts at zero.** Only clears checked by the Worker count. The map keeps its stars | User |
| Where it shows | **Both**: a `Levels` choice next to Daily · Week · All time on the Board tab, and tapping the star total in the Levels header opens it | User |
| Scope | One global board per game for all time, plus league boards (members view, as for the other periods) | My call |
| Games | Zip only at launch; the paths and Worker route are per game so Path Words and Sudoku can join | My call |
| Unlock order | The Worker does **not** require earlier levels to be on the board. Players who cleared levels before launch can replay any of them in any order. Skipping gains nothing: 300 stars still needs all 100 levels | My call |

## Approaches

- **A. Worker-checked clears (chosen).** The app posts each level clear (path, time, hints flag) to the Worker. The Worker checks the path against the published level, works out the stars itself, keeps per-level bests on the server and writes the board row. Cheating is as hard as on the daily boards, which is the point: the top of a stars board is what everyone looks at. Costs a Worker route, a server-side copy of level bests, and one network call per clear.
- **B. The app writes its own row from its synced progress.** Small and immediate, and existing stars would count. Rejected: progress is player-written and barely checked, so anyone could post 300★ and the fastest times.
- Dropped: the Worker adding up `level_progress`. That doc is player-written, so the Worker would only be copying numbers it can't trust.

## Data

### `leaderboards/{gameId}/levels/{uid}` — the board row (public to signed-in players)

```jsonc
{
  "stars": 92,              // sum of best stars over levels the Worker has checked
  "levelsCleared": 40,      // levels with a checked clear
  "timeSeconds": 2531,      // sum of the best checked time of each of those levels (named like the other boards so the shared entry model and table work)
  "displayName": "…", "photoUrl": "…", "avatarId": "…",   // same identity fields and cleaning as the weekly board (identity.ts)
  "updatedAt": "<server timestamp>"
}
```

- Query: `orderBy stars desc, levelsCleared asc, timeSeconds asc, updatedAt asc, limit(50)`. A composite index in `firestore.indexes.json`, plus the same for `leaderboards_debug` if debug builds use it (follow what the weekly board does: it has no debug twin, so the level board on a debug build is empty unless the builder finds a reason otherwise).
- Rules: `allow read` as the weekly board; `create`/`update` only through `profileOnlyLeaderboardUpdate` (so a name or photo change still reaches the row); no client score writes; no delete.

### `leaderboards/{gameId}/level_records/{uid}` — the server's bests (owner read only)

```jsonc
{ "levels": { "zip_1_07": { "stars": 3, "bestSeconds": 14 } }, "updatedAt": "<server timestamp>" }
```

- Written only by the Worker. Same merge as `LevelProgress` (higher stars, lower time, each kept separately), so it only ever improves.
- The board row is always recomputed from this doc, never edited incrementally, so the two can't drift.
- The owner can read it, so the app knows which levels aren't on the board yet (see Levels screen).

## Worker: `POST /v1/level-clear`

Same auth (Firebase ID token), body size cap and 401/503 handling as `/v1/submit`.

Body: `{ gameId: "zip", levelId: "zip_1_07", timeSeconds, usedHints, proof: { path: [[r,c],…] }, identity }`.

1. `gameId` must be in a **level games** list (`['zip']` for now) → else 400.
2. `levelId` must match `^{gameId}_\d+_\d+$`; the world doc is `level_worlds/{gameId}_{worldOrder}`.
3. `timeSeconds` must be ≥ `MIN_SECONDS[gameId]` and ≤ `MAX_SECONDS` → else 422 `too_fast` / `too_slow`.
4. One `batchGet`: the world doc, the records doc, the board row.
5. The world must exist and be `published == true`, and must contain `levelId` → else 422 `not_live`.
6. `checkZipProof(level board, proof)` (the existing function; the level uses `ZipLevel` JSON) → else 422 with the proof's code.
7. **Stars are worked out on the Worker** with a TypeScript port of `starsFor(usedHints, seconds, targetSeconds)`, using the level's `targetSeconds` from the world doc. The client never sends stars. Add a shared test table both sides run, so the Dart and TS versions can't disagree.
8. Merge into records; if nothing improved, return 200 `{accepted: true, improved: false}` with no write.
9. Otherwise commit records + recomputed board row in one commit with update-time preconditions, retrying once on contention (the `/v1/submit` pattern), then 503 `busy`.

The hints flag is self-reported, as `usedHints` is on the daily boards. That's an accepted limit.

## App

### Sending clears

- On a level clear, after `RecordLevelClear`, if signed in: post the clear (new `SubmitLevelClear` usecase, behind `LeaderboardRepository` or a new `LevelLeaderboardRepository`, builder's choice). Send **every** level clear, not only map improvements: since the board starts at zero, a replay that doesn't improve the map can still be new to the board. The Worker is improve-only, so resends are harmless.
- `expectedUid` guard as `submitBestTime`: a clear made under one account never lands on another.
- **Offline or Worker unreachable**: keep the best unsent run per level (stars first, then time) with its proof, using the existing per-clear proof store (`setClearProof` with play id `level_zip_1_07`) or a sibling of it. `SyncProgress` resends unsent level clears in its pass. A final refusal (4xx) drops the pending one; a 503 keeps it.
- There's no direct-write fallback, unlike the daily boards. If the Worker is down, clears wait.

### Board tab

- `LeaderboardPeriod.levels` (or an equivalent; builder's call): a fourth choice in the filter row, `Levels`, after All time.
- `LeaderboardEntry` gets the `stars` / `levelsCleared` fields it needs, nullable like `daysCleared` for the weekly board.
- Rows show stars as the main figure and "40 levels · 42:11" as the secondary line. The podium shows stars. Your own row is pinned as on the other boards.
- Leagues: `watchMembersBoard` for this period reads members' rows from `levels`.
- Signed out: the existing signed-out mock.
- Empty board: copy saying no one's on it yet, with Play levels.
- When you're not on it: your pinned row reads "Clear a level to join". If your map has stars but the board has none: "Replay a level to count your stars".

### Levels tab

- The header's star total becomes tappable (chevron) and opens the Board tab on Zip · Levels.
- My call, can be dropped: the level sheet shows one quiet line, "Not on the board yet · replay to count", for a level the map has cleared but `level_records` doesn't have. This explains the gap between the map's 92★ and a board at 0 after launch. It costs one owner read per Levels load, cached like progress.

### Everything else

- Results for a level: no board rank shown (keeps Results as specified). Builder may add "Counted on the board" later; not in this scope.
- Strings: all copy in `AppStrings`, English and Malayalam.
- Analytics: `level_board_submit {level, accepted, improved, code}`.
- Account deletion (`workers/account-deletion`): wipe `leaderboards/{game}/levels/{uid}` and `level_records/{uid}`.

## Goals / non-goals / anti-goals

- Goals: a board where more stars ranks higher, which nobody can climb without solving levels; it's reachable from the Board tab and from Levels; leagues work.
- Non-goals: weekly or monthly level boards, per-level fastest-time boards, rank on Results, a rank-up push, Path Words or Sudoku level boards (only the shape is ready).
- Anti-goals: a #1 that's obviously faked; the map's stars changing because of the board; level runs leaking into daily streaks or daily boards (they stay `isDaily == false`).

## Errors

| Situation | Behaviour |
|---|---|
| Offline clear | Map updates; clear kept and sent on next sync |
| Worker 503 / unreachable | Kept and resent; no direct write |
| 422 (proof, too fast, level not published) | Pending clear dropped; reported through the client-error report |
| Board stream error | Existing error state + retry |
| Level edited in the CMS after a clear | The server keeps the earlier best; the new board is checked from then on |
| World unpublished (not allowed by admin, but defensively) | Clears for it are refused `not_live`; existing records stay |

## Testing

- Worker (vitest): route parsing; proof check against a level from a world fixture; unpublished/missing level; stars port vs shared table; improve-only merge; totals recomputed; no write when nothing improved; contention retry.
- `firestore/rules_test`: no client score writes to `levels` or `level_records`; owner-only read of records; profile-only update allowed.
- Dart: `starsFor` against the shared table; `SubmitLevelClear` (signed out does nothing, uid guard, pending kept on 503, dropped on 4xx); `SyncProgress` resends; leaderboard repo mapping and ordering; `LeaderboardCubit` with the Levels period; widget tests for the row, the empty and not-on-board states, the header tap, the sheet line.
- Account deletion: both docs wiped.

## Build order

1. Worker route, stars port, shared table, rules, index, deletion wipe.
2. App sending: usecase, pending store, sync resend.
3. Board tab: period, entry fields, rows, leagues.
4. Levels tab: header link, sheet line.

## Left to the builder

The name and home of the app-side repository; whether `levels` is a `LeaderboardPeriod` value or a separate type; the exact local storage of pending level clears; debug-board handling; the exact layout of the row's secondary line within the existing table.
