# Post-game celebrate + soft claim Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Zip/Path Words results celebrate the run first; guests get an optional “save this time” sign-in CTA, never a locked leaderboard wall.

**Architecture:** Reuse `ResultsArgs` celebration fields on the Zip/Path Words `/results` path. Guests see celebration + soft claim → existing `showSignInSheet` + `SubmitLeaderboardTime`. Signed-in users see celebration + existing `MiniLeaderboardPanel`.

**Tech Stack:** Flutter, Bloc/Cubit, AppStrings, existing auth/leaderboard usecases

## Global Constraints

- All user-facing copy via `AppStrings`
- No sign-in required to play or leave results
- Remote leaderboard write still requires Firebase auth
- Word Match / non-Zip-PathWords results unchanged
- Prefer dart format; no drive-by refactors

---

### Task 1: Failing tests for celebrate + soft claim

**Files:**
- Modify: `test/features/results/results_screen_test.dart`

- [ ] **Step 1: Update Zip/Path Words signed-in test** — expect celebration time label + `MiniLeaderboardPanel` + PB when `improved`
- [ ] **Step 2: Add guest Zip results test** — expect formatted time / soft claim CTA; no `leaderboardSignInHint` as sole body; `backHome` present; no mini board until signed in
- [ ] **Step 3: Run tests — confirm RED**

```bash
flutter test test/features/results/results_screen_test.dart
```

### Task 2: Copy + optional claim sign-in sheet

**Files:**
- Modify: `lib/core/strings/app_strings.dart`
- Modify: `lib/features/auth/view/sign_in_sheet.dart`

- [ ] **Step 1: Add strings** — `saveTimeToBoard(timeLabel)`, claim sheet title/body; keep board-focused defaults for Leaderboard tab
- [ ] **Step 2: Parameterize `showSignInSheet`** — optional title/body override for claim context
- [ ] **Step 3: Format helper** — reuse or add `formatResultsTime` if needed for CTA label

### Task 3: ResultsScreen celebrate + soft claim

**Files:**
- Modify: `lib/features/results/results_screen.dart`
- Optionally: `lib/features/results/view/soft_claim_cta.dart` (if extracted)

- [ ] **Step 1: Replace `_miniLeaderboardScaffold` path** with celebration + guest soft claim / signed-in mini board
- [ ] **Step 2: Wire sign-in → `SubmitLeaderboardTime`** then show mini board (AuthCubit watch)
- [ ] **Step 3: Guest footer** — Back home only; omit “See full leaderboard”
- [ ] **Step 4: Run tests — GREEN**

```bash
flutter test test/features/results/results_screen_test.dart
dart format lib/features/results lib/features/auth/view/sign_in_sheet.dart lib/core/strings/app_strings.dart test/features/results
```

### Task 4: Spec status + verify

- [ ] Mark design spec status approved/implemented-ready
- [ ] `flutter analyze` on touched files
