# Zip initial shimmer loading — Design

**Date:** 2026-09-30  
**Status:** Implemented  
**Scope:** Show a board + chrome shimmer on Zip open until the daily level is fetched; no playable board until ready/locked.

## Goal

Match Path Words’ loading feel: Zip’s first paint is a shimmer under the title bar (grid + undo/hint placeholders), not a spinner and not a premature playable board that may swap after fetch.

## Non-goals

- Shimmer on reset / hint / celebrate
- Changing fetch / puzzle generation logic beyond status timing
- Full-screen shimmer that hides the Zip title bar
- New packages

## Behavior

| Phase | UI |
| --- | --- |
| `ZipStatus.initial` (open → fetch in flight) | Title bar visible; body = `ZipShimmer` (grid + two bottom button placeholders). No `GameWidget`. Clear disabled. Tutorial deferred. |
| `ready` / `locked` after fetch | Current Zip screen (game + real chrome) |
| Other statuses | Unchanged |

## Architecture

1. **`ZipState.initial` / bloc ctor:** Start with `ZipStatus.initial` (placeholder level still allowed for non-null `level`, but UI ignores it while initial).
2. **`ZipBloc._onStarted`:** After `fetchDailyLevel`, emit `ready` or `locked` as today.
3. **`ZipShimmer`** (`lib/features/zip/view/widgets/zip_shimmer.dart`): `AppShimmer` + grid of `AppShimmerBox` (like `PathWordsShimmer`) + row of two rounded shimmer bars for undo/hint.
4. **`ZipScreen`:** When `status == initial`, show shimmer under title; do not create/show `GameWidget` or prompt tutorial until not initial.
5. **Copy:** Optional `AppStrings.zipLoading` for Semantics (mirror `pathWordsLoading`).

## Testing

- Bloc: initial status before async fetch completes; then ready/locked.
- Widget: shimmer builds; screen shows shimmer when initial.
- Regression: Zip game draw/hint tests unchanged.

## Success criteria

1. Opening Zip shows shimmer (board + bottom chrome) under the title until load finishes.
2. User cannot draw on a placeholder level that then swaps.
3. After load, play/review behavior matches today.
