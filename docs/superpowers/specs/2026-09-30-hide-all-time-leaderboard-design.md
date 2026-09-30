# Hide All-time Leaderboard (admin-controlled) — design

Date: 2026-09-30  
Status: approved for implementation  
Repos: winklo + winklo-admin

## Goal

Admins can hide the mobile All-time leaderboard from Ops → Remote Config. When hidden, players only see Daily rankings. All-time scores still save so the board can be re-enabled later without a data gap.

## Decisions

| Decision | Choice |
|----------|--------|
| Scope | Global (Zip, Path Words, Sudoku) |
| Effect | Hide UI only; Firestore all-time writes continue |
| Control surface | Ops → Remote Config |
| Transport | Firebase Remote Config boolean `showAllTimeLeaderboard` (default `true`) |

## Admin

- Extend Ops RC keys with `showAllTimeLeaderboard`
- OpsPage toggle: **Show All-time Leaderboard** (VISIBLE / HIDDEN)
- Admin Leaderboard page unchanged (ops can still inspect all-time data)

## Mobile

- `RemoteConfigClient` exposes `showAllTimeLeaderboard` (default `true` on missing/fetch fail)
- Full Leaderboard screen: when `false`, omit Daily/All-time period pills and force `LeaderboardPeriod.daily`
- Submit path unchanged (still writes daily + all-time)
- Results mini-leaderboard already defaults to daily — no change
- `LeaderboardScreen` accepts optional `showAllTimeLeaderboard` for tests; production reads Remote Config

## Edge cases

| Case | Behavior |
|------|----------|
| RC missing / fetch fail | Default `true` (All-time visible) |
| Player was on All-time when hide publishes | Next open forces Daily; pills gone |
| Flag turned back on | Pills return; period starts at Daily |
| Admin Leaderboard All-time tab | Still works |

## Out of scope

- Per-game visibility
- Stopping all-time score writes
- Realtime push (uses existing RC fetch timing)
