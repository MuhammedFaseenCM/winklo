# Daily puzzle auto-generation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Auto-create Zip, Path Words, and Sudoku daily puzzles (UTC today + 2 days) via winklo-admin-api cron with AI-assisted params, validators, pause/lock kill switch, and admin UI controls.

**Architecture:** Extend Cloudflare Worker `scheduled()` to gap-fill missing `daily_YYYYMMDD` docs. Port Zip/Sudoku generators to the Worker; reuse Path Words AI. Config + run logs in `ops_config`. CMS saves mark docs manual/locked.

**Tech Stack:** Cloudflare Workers, Workers AI, Firestore REST, Vitest, React admin SPA.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-10-09-daily-puzzle-auto-design.md`
- Never overwrite `source: "manual"` or `locked: true`
- Cap ≤3 generations per cron tick
- Flutter app unchanged
- No email/Slack alerting in v1

---

## File map

| File | Responsibility |
| --- | --- |
| `winklo-admin/workers/admin-api/src/seeded_random.ts` | Shared PRNG |
| `.../zip_difficulty.ts` | Zip bands |
| `.../sudoku_clue_band.ts` | Sudoku clue bands |
| `.../generate_zip.ts` | Zip board generator |
| `.../generate_sudoku.ts` | Sudoku generator |
| `.../daily_puzzle_ai_params.ts` | AI size/difficulty proposal |
| `.../daily_puzzle_auto.ts` | Planner, generate, write, config, status |
| `.../index.ts` | Cron + HTTP ops routes; CMS manual lock |
| `winklo-admin/src/lib/adminApi.ts` | Client for ops endpoints |
| `winklo-admin/src/pages/GameContentPage.tsx` | Pause / Run now / status / badges |

---

### Task 1: Worker generators + AI params

- [x] Port `seededRandom`, zip bands, sudoku clue bands, `generateZip`, `generateSudoku` into Worker
- [x] Add `daily_puzzle_ai_params.ts` (Workers AI JSON `{size,difficulty}` + local defaults)
- [x] Vitest: generators pass `validateCmsDocument`

### Task 2: Auto pipeline + cron + APIs

- [x] Implement `daily_puzzle_auto.ts` (config, plan slots, skip protected, generate, put, run log)
- [x] Wire `scheduled()` and GET/PATCH/POST ops routes in `index.ts`
- [x] Vitest: planner dates, skip locked, generators schema

### Task 3: CMS manual lock

- [x] On content PUT, set `source: "manual"` and `locked: true` for daily game collections

### Task 4: Admin UI

- [x] `adminApi` helpers for config/status/run
- [x] Game Content strip: pause, run now, status, lock badge on cards

### Task 5: Verify

- [x] `npm test` in `workers/admin-api` (77 passed)
- [x] Spot-check TypeScript / lint on touched SPA files
