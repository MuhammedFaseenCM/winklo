# Daily puzzle auto-generation — design

Date: 2026-10-09  
Status: approved  
Repos: winklo-admin (Worker + SPA); winklo Flutter app unchanged  

## Goal

Every day, Zip / Path Words / Sudoku `daily_YYYYMMDD` docs for **UTC today + next 2 days** are created automatically with **AI-assisted** params, validated generators, and auto-publish — with a global pause kill switch and per-doc manual locks so ops can override bad boards.

## Decisions

| Topic | Choice |
| --- | --- |
| Publish | Auto-write to Firestore; pause + manual lock as kill switch |
| Generation | AI proposes size/difficulty (and Path Words board via existing AI); deterministic generators + validators finalize |
| Buffer | UTC today + 2 days (3 dates × 3 games) |
| Runtime | Extend `winklo-admin-api` Cloudflare Worker cron |
| Overwrite | Never overwrite `source: "manual"` or `locked: true`; only fill missing docs |
| Alerting | Run log in Firestore + admin status UI (no email/Slack in v1) |
| App | No Flutter client changes |

## Architecture

```
Worker scheduled() (* * * * *)
  ├─ deliver scheduled announcements (existing)
  └─ runDailyPuzzleAuto()
       ├─ read ops_config/daily_puzzle_auto
       ├─ if !enabled or pausedUntil > now → skip
       ├─ plan missing slots (today..+2 × zip|path_words|sudoku)
       ├─ for up to N slots:
       │    AI params → generate → validateCmsDocument → put source=auto
       └─ write ops_config/daily_puzzle_auto_runs/{runId}
```

Admin SPA Game Content: Pause / Run now / last status; cards show locked/manual badge. CMS Save sets `source: "manual"` and `locked: true`.

## Per-game generation

| Game | AI | Final board | Fallback |
| --- | --- | --- | --- |
| Zip | `{ size, difficulty }` | Worker `generateZip` | Date-seeded local (no AI) |
| Sudoku | `{ size, difficulty }` | Worker `generateSudoku` | Date-seeded local |
| Path Words | Existing Workers AI board path | Validate + local dense fallback | Already in Worker |

Seed = FNV-ish hash of `dateId:game` so retries are stable.

## Config & document fields

`ops_config/daily_puzzle_auto`:

```json
{
  "enabled": true,
  "pausedUntil": null,
  "bufferDays": 2,
  "updatedAt": "ISO"
}
```

Puzzle docs (extra fields, ignored by Flutter `fromJson` extras):

- Auto: `source: "auto"`, `generatedAt`, `generatorMeta`
- Manual CMS save: `source: "manual"`, `locked: true`

## Scheduling & errors

- Gap-fill on existing minute cron; cap ≤3 generations per tick
- Idempotent: existing protected or auto docs left alone
- After AI retries fail → local fallback; if that fails → log failure, leave missing (app shows unavailable)

## APIs

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/v1/ops/daily-puzzles/config` | Read config |
| PATCH | `/v1/ops/daily-puzzles/config` | Update enabled / pausedUntil |
| POST | `/v1/ops/daily-puzzles/run` | Manual gap-fill now |
| GET | `/v1/ops/daily-puzzles/status` | Missing slots + last run |

Admin-auth required (same as other ops routes).

## Out of scope

- Word Match / Categories / Flow
- Overwriting manual dailies
- External alerting
- Flutter app changes
- Rewriting historical auto dailies on a schedule
