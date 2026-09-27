# Post-game celebration polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Amp guest Zip/Path Words results with staged celebration motion and make Save-to-board the primary CTA.

**Architecture:** Enhance `_CelebrateAndClaimResults` / `_ResultsCelebrationCard` with count-up time, ember burst, haptic, and CTA swap. No new packages.

**Tech Stack:** Flutter, flutter_animate, CustomPainter, HapticFeedback, AppStrings

## Global Constraints

- All copy via `AppStrings`
- Guest leave remains one tap
- No new pub dependencies
- Prefer dart format; touch only results celebration path + tests

---

### Task 1: Failing tests for CTA hierarchy

**Files:**
- Modify: `test/features/results/results_screen_test.dart`

- [ ] Assert guest Save CTA uses primary styling / appears before Home in tree order as primary action
- [ ] Assert Back home still navigates home
- [ ] Run RED

### Task 2: Count-up + ember burst + haptic + CTA flip

**Files:**
- Modify: `lib/features/results/results_screen.dart`
- Create (optional): `lib/features/results/view/ember_burst.dart`, `counting_play_time.dart`

- [ ] Flip guest CTAs (Save primary, Home text)
- [ ] Counting time + badge stagger + ember burst + light haptic
- [ ] Run GREEN + format + analyze
