# Guest play — sign-in only for leaderboard — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Guests play Zip/Path Words without sign-in; sign-in only for live leaderboard viewing, with soft prompt on post-game mini board and sync of that run’s time after sign-in.

**Architecture:** Remove Home auth gate. Keep Leaderboard/Profile signed-out teases. Pass `timeSeconds` into `MiniLeaderboardPanel`; after successful sign-in from its CTA, best-effort `SubmitLeaderboardTime`. Update `AppStrings` so copy no longer says “sign in to play.”

**Tech stack:** Flutter, Cubit, existing `SubmitLeaderboardTime` / `showSignInSheet`.

**Spec:** `docs/superpowers/specs/2026-09-26-guest-play-leaderboard-signin-design.md`

---

### Task 1: Ungate Home play

**Files:**
- Modify: `lib/features/home/view/home_screen.dart`

- [ ] Remove `ensureSignedInForPlay` and calls from `openZip` / `openPathWords`
- [ ] Drop unused auth / sign-in sheet imports

### Task 2: Results-time sync on mini-board sign-in

**Files:**
- Modify: `lib/features/results/view/mini_leaderboard_panel.dart`
- Modify: `lib/features/results/results_screen.dart`

- [ ] Add `timeSeconds` to `MiniLeaderboardPanel`
- [ ] On sign-in success, call `SubmitLeaderboardTime` when `timeSeconds > 0`
- [ ] Pass `args.timeSeconds` from `ResultsScreen`

### Task 3: Copy

**Files:**
- Modify: `lib/core/strings/app_strings.dart`

- [ ] Update `signInTitle`, `signInBody`, `signInRequired`, `signOutConfirmBody`

### Task 4: Tests

**Files:**
- Modify: `test/features/home/view/home_screen_test.dart`
- Modify: `test/features/results/results_screen_test.dart`

- [ ] Signed-out Home can open Zip / Path Words without sign-in sheet
- [ ] Signed-out mini board → sign-in → submit results time → show board

### Task 5: Spec

**Files:**
- Create: `docs/superpowers/specs/2026-09-26-guest-play-leaderboard-signin-design.md`
