# Winklo Promo Reels Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Three vertical 1080×1920 promo reels for Winklo (A "One line", B "3 puzzles a day", C "Beat my time"), rendered to MP4.

**Architecture:** One HyperFrames project per video under `marketing/videos/<name>/`, sharing a copied `assets/` set (Lexend, app icon, CC0 sfx) and a shared, validated Zip puzzle (`marketing/videos/shared/zip-puzzle.json`). Boards are drawn as HTML/SVG in brand colours and animated with GSAP on paused timelines.

**Tech Stack:** HyperFrames CLI (Apache-2.0) via `node ~/.claude/skills/hyperframes/scripts/plugin-cli.mjs`, GSAP, ffmpeg, Node 20.

**Spec:** `docs/superpowers/specs/2026-11-23-winklo-promo-reels-design.md`

## Global Constraints

- 1080×1920, 30 fps, MP4; final files in `marketing/videos/out/winklo-<a|b|c>-<slug>.mp4`.
- Colours: bg #0F172A, card #243044, wall #1E293B, ember #FF6B2C, sky #38BDF8, teal #2DD4BF, star #FBBF24, number #FB7185. Font Lexend via `@font-face` from `assets/fonts/`.
- All words and boards inside y=168–1330px; nothing read under 28px; ≤5 words per claim line; frame 0 is the hook.
- Ends on the real `assets/branding/app_icon.png` + "Winklo" + "Free on Android".
- Audio only from `assets/sfx` (Kenney CC0); no paid assets; no fake ratings/download counts. "0:47" and ranks are examples.
- `npx hyperframes check --json` has 0 errors for every project before render.

## Review Focus

- The Zip solution drawn on screen must be a legal solve (every cell once, orthogonal steps, numbers in order, no wall crossed) — a puzzle fan will spot a fake. → Task 1 validator test.
- Text read at phone size (360px sheet) must stay legible → `snapshot --review` phone sheet checked in each video task.
- The hook frame (t=0) must not be empty/black → `first_frame_empty` must not appear in `check`.
- Sound peaks must land on the picture (tap per ribbon step, success on solve) → `hyperframes audio <mp4> --json` in each video task.
- Platform UI must not cover copy → `check` layout audit + manual look at y>1330 on the review sheet.

---

### Task 1: Shared assets + validated Zip puzzle

**Files:**
- Create: `marketing/videos/shared/zip-puzzle.json`, `marketing/videos/shared/validate-zip.mjs`, `marketing/videos/shared/assets/{fonts/Lexend-*.ttf, app_icon.png, sfx/*.ogg}`

**Interfaces:**
- Produces: `zip-puzzle.json` = `{ size: 8, path: [[r,c],…64], numbers: [{n, r, c}], walls: [{a:[r,c], b:[r,c]}] }` — numbers sit on path cells in increasing path order, first number on path[0], last on path[63].

- [ ] Write `validate-zip.mjs <file>`: exits 1 with a message unless path has 64 unique in-grid cells, each step orthogonally adjacent, no step crosses a wall, numbers appear on the path in ascending order starting at path[0] and ending at path[63].
- [ ] Run it on a deliberately broken file (one diagonal step) → expect exit 1.
- [ ] Author the real puzzle (a snake-with-detours path, 8 numbers, 4–6 walls that don't block the path) → validator exits 0.
- [ ] Copy app icon + sfx, download Lexend 400/600/800 (OFL) into `shared/assets/fonts/`.

### Task 2: Video A "One line" (~15s)

**Files:** Create `marketing/videos/a-one-line/` (from `hyperframes init`), scenes `compositions/{hook,solve,payoff,cta}.html`.

- [ ] `init`, copy shared assets, set 1080×1920, duration 15.
- [ ] Beats per spec: 0–2 hook text over empty board; 2–10 ember ribbon draws path over 64 steps (tap sfx every ~4 steps, rotated); 10–12 teal flash, "Solved 0:47", rank chip; 12–15 flash Path Words + Sudoku → "3 free puzzles. Every day." → logo CTA.
- [ ] `check --json` → 0 errors; `snapshot --review` → fix P0s; write `REVIEW.md`.
- [ ] Open Studio preview for the user; on approval render to `out/winklo-a-one-line.mp4`; `audio --json` confirms sound.

### Task 3: Video B "3 puzzles a day" (~25s)

Same steps as Task 2 in `marketing/videos/b-three-a-day/`; beats per spec section B (Path Words word "PUZZLE" traced through a sparse letter grid; 6×6 Sudoku with 2×3 boxes filling to teal; features: leaderboard, streak, "+10s hint"). Render `out/winklo-b-three-a-day.mp4`.

### Task 4: Video C "Beat my time" (~20s)

Same steps in `marketing/videos/c-beat-my-time/`; reuses the shared Zip puzzle with a large running clock that stops exactly at 0:47 on the solve frame. Render `out/winklo-c-beat-my-time.mp4`.
