# Zip Initial Shimmer Loading Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a board + bottom-chrome shimmer on Zip open until the daily level fetch finishes; no playable `GameWidget` until `ready`/`locked`.

**Architecture:** Start bloc in `ZipStatus.initial`. After `fetchDailyLevel`, emit `ready` or `locked` as today. `ZipScreen` shows `ZipShimmer` (grid + two button placeholders) under the title bar while initial. Mirror Path Words loading contract.

**Tech Stack:** Flutter, `AppShimmer` / `AppShimmerBox`, Bloc, `AppStrings`, `flutter_test` / `bloc_test`

**Spec:** `docs/superpowers/specs/2026-09-30-zip-initial-shimmer-design.md`

## Global Constraints

- All user-facing copy via `AppStrings`
- No new packages
- Title bar stays visible while loading (shimmer is under it)
- No `GameWidget` / tutorial while `ZipStatus.initial`
- Prefer `dart format`; no drive-by refactors
- Stage/commit only files for the current task (dirty tree may have unrelated work)

## File map

| File | Responsibility |
| --- | --- |
| `lib/features/zip/bloc/zip_state.dart` | `ZipState.initial` → `ZipStatus.initial` |
| `lib/features/zip/bloc/zip_bloc.dart` | Do not early-lock in ctor; lock only after fetch in `_onStarted` |
| `lib/core/strings/app_strings.dart` | `zipLoading` Semantics string |
| `lib/features/zip/view/widgets/zip_shimmer.dart` | Board + bottom chrome shimmer |
| `lib/features/zip/view/zip_screen.dart` | Show shimmer when initial; defer game/tutorial |
| `test/features/zip/bloc/zip_bloc_test.dart` | Initial → ready/locked expectations |
| `test/features/zip/view/widgets/zip_shimmer_test.dart` | Shimmer builds |

---

### Task 1: Bloc starts `initial` until fetch completes

**Files:**
- Modify: `lib/features/zip/bloc/zip_state.dart`
- Modify: `lib/features/zip/bloc/zip_bloc.dart`
- Modify: `test/features/zip/bloc/zip_bloc_test.dart`

**Interfaces:**
- Produces: `ZipState.initial(...)` returns `status: ZipStatus.initial`; ctor no longer sets `locked` before fetch; `_onStarted` still emits `ready`/`locked`

- [ ] **Step 1: Update failing / expected bloc tests first**

In `test/features/zip/bloc/zip_bloc_test.dart`:

1. Change `'starts locked when today is already cleared'` to expect **initial** at construction (not locked), e.g.:

```dart
blocTest<ZipBloc, ZipState>(
  'starts initial when today is already cleared (await fetch)',
  build: () {
    when(() => getBestPoints('zip_daily_20260913')).thenReturn(900);
    when(() => getBestTimeSeconds('zip_daily_20260913')).thenReturn(12);
    return buildBloc();
  },
  expect: () => <ZipState>[],
  verify: (b) {
    expect(b.state.status, ZipStatus.initial);
    expect(b.state.finished, isFalse);
  },
);
```

2. Change `'minute play period uses a new lock key each minute'` verify to expect `ZipStatus.initial` (and keep level id check). Lock happens only after `ZipStarted`.

3. Add:

```dart
blocTest<ZipBloc, ZipState>(
  'ZipStarted transitions from initial to ready',
  build: buildBloc,
  act: (b) => b.add(ZipEvent.started(date: DateTime.utc(2026, 9, 14))),
  verify: (b) {
    // After act, status is ready (seed was initial before act).
    expect(b.state.status, ZipStatus.ready);
  },
);
```

(Optional: fold into existing `'ZipStarted loads daily level for date'` by asserting seed status in `build` via a custom `build` + `verify` on a separately constructed bloc — prefer one explicit test that constructs without act and checks `initial`.)

4. For `'ZipCompleted is ignored when the daily puzzle is already locked'`: after build, the bloc is no longer locked at ctor. Either:
   - `act`: add `ZipEvent.started(...)` first (with cleared mocks) then `completed`, and expect only the started emission (no celebrate), **or**
   - keep ctor early-lock only when cleared — **do not**; follow spec (lock after fetch). Update this test to seed via `ZipStarted` then `completed`.

Example pattern:

```dart
blocTest<ZipBloc, ZipState>(
  'ZipCompleted is ignored when the daily puzzle is already locked',
  build: () {
    when(() => getBestPoints('zip_daily_20260913')).thenReturn(900);
    return buildBloc();
  },
  act: (b) async {
    b.add(ZipEvent.started(date: DateTime.utc(2026, 9, 13)));
    await b.stream.firstWhere((s) => s.status == ZipStatus.locked);
    b.add(const ZipEvent.completed(points: 900, timeSeconds: 12));
  },
  // expect: only locked from started; no celebrating
);
```

Adjust `expect` to the single locked emission from started (and empty after completed). Prefer matching existing `bloc_test` style in this file — if async act is awkward, use `seed` is unavailable; use two-step verify with wait, or inject sync `fetchDailyLevel`.

Simplest fix matching this codebase: keep `fetchDailyLevel` default sync enough that `blocTest` act with both events in one `act` and `expect` the locked state then no further celebrate:

```dart
act: (b) {
  b.add(ZipEvent.started(date: DateTime.utc(2026, 9, 13)));
  b.add(const ZipEvent.completed(points: 900, timeSeconds: 12));
},
expect: () => [
  isA<ZipState>().having((s) => s.status, 'status', ZipStatus.locked),
],
```

- [ ] **Step 2: Run tests — confirm RED**

```bash
flutter test test/features/zip/bloc/zip_bloc_test.dart
```

Expected: failures where ctor still returns `ready`/`locked`.

- [ ] **Step 3: Implement state + bloc**

`zip_state.dart` — change factory:

```dart
factory ZipState.initial(DateTime now, {Duration period = PlayPeriod.daily}) {
  final day = DateTime(now.year, now.month, now.day);
  final level = DailyPuzzleGenerator.forDate(now, period: period);
  return ZipState(day: day, level: level, status: ZipStatus.initial);
}
```

`zip_bloc.dart` — simplify `_initialState` to **always** return `ZipState.initial(...)` without flipping to locked:

```dart
static ZipState _initialState(
  DateTime now,
  GetBestPoints getBestPoints,
  GetBestTimeSeconds getBestTimeSeconds, {
  required bool ignoreDailyLock,
  required Duration playPeriod,
}) {
  return ZipState.initial(now, period: playPeriod);
}
```

Remove unused `_isCleared` from `_initialState` path only — keep `_isCleared` for `_onStarted`. If analyzer flags unused params on `_initialState`, drop unused `getBestPoints` / `getBestTimeSeconds` / `ignoreDailyLock` from `_initialState` signature and update the `super(_initialState(...))` call accordingly.

`_onStarted` unchanged aside from already emitting ready/locked after fetch.

- [ ] **Step 4: Run tests — GREEN**

```bash
flutter test test/features/zip/bloc/zip_bloc_test.dart
dart format lib/features/zip/bloc/zip_state.dart lib/features/zip/bloc/zip_bloc.dart test/features/zip/bloc/zip_bloc_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/zip/bloc/zip_state.dart lib/features/zip/bloc/zip_bloc.dart test/features/zip/bloc/zip_bloc_test.dart
git commit -m "$(cat <<'EOF'
feat(zip): start in initial status until daily level loads

EOF
)"
```

---

### Task 2: `ZipShimmer` widget + string

**Files:**
- Create: `lib/features/zip/view/widgets/zip_shimmer.dart`
- Create: `test/features/zip/view/widgets/zip_shimmer_test.dart`
- Modify: `lib/core/strings/app_strings.dart`

**Interfaces:**
- Produces: `class ZipShimmer extends StatelessWidget` with optional `gridSize` (default `6`); `AppStrings.zipLoading`

- [ ] **Step 1: Add string**

Near other Zip strings in `app_strings.dart`:

```dart
static const zipLoading = 'Building today’s puzzle…';
```

(Same wording as `pathWordsLoading` is fine — product-consistent.)

- [ ] **Step 2: Write failing widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/widgets/app_shimmer.dart';
import 'package:winklo/features/zip/view/widgets/zip_shimmer.dart';

void main() {
  testWidgets('ZipShimmer builds grid and bottom chrome placeholders', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SizedBox(height: 480, child: ZipShimmer())),
      ),
    );
    expect(find.byType(AppShimmer), findsOneWidget);
    expect(find.byType(AppShimmerBox), findsWidgets);
  });
}
```

- [ ] **Step 3: Run test — RED**

```bash
flutter test test/features/zip/view/widgets/zip_shimmer_test.dart
```

- [ ] **Step 4: Implement `ZipShimmer`**

```dart
import 'package:flutter/material.dart';

import '../../../../core/widgets/app_shimmer.dart';

/// Board + bottom-chrome loading placeholder for Zip (replaces a spinner).
class ZipShimmer extends StatelessWidget {
  const ZipShimmer({super.key, this.gridSize = 6});

  final int gridSize;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    for (var row = 0; row < gridSize; row++) ...[
                      if (row > 0) const SizedBox(height: 6),
                      Expanded(
                        child: Row(
                          children: [
                            for (var col = 0; col < gridSize; col++) ...[
                              if (col > 0) const SizedBox(width: 6),
                              const Expanded(
                                child: AppShimmerBox(
                                  height: double.infinity,
                                  borderRadius: 10,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Row(
                children: [
                  Expanded(child: AppShimmerBox(height: 48, borderRadius: 24)),
                  SizedBox(width: 12),
                  Expanded(child: AppShimmerBox(height: 48, borderRadius: 24)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run test — GREEN + format**

```bash
flutter test test/features/zip/view/widgets/zip_shimmer_test.dart
dart format lib/features/zip/view/widgets/zip_shimmer.dart lib/core/strings/app_strings.dart test/features/zip/view/widgets/zip_shimmer_test.dart
```

- [ ] **Step 6: Commit**

```bash
git add lib/features/zip/view/widgets/zip_shimmer.dart test/features/zip/view/widgets/zip_shimmer_test.dart lib/core/strings/app_strings.dart
git commit -m "$(cat <<'EOF'
feat(zip): add ZipShimmer board and chrome placeholders

EOF
)"
```

---

### Task 3: Wire shimmer into `ZipScreen`

**Files:**
- Modify: `lib/features/zip/view/zip_screen.dart`

**Interfaces:**
- Consumes: `ZipShimmer`, `AppStrings.zipLoading`, `ZipStatus.initial`

- [ ] **Step 1: Defer game + tutorial while initial**

In `_ensureGame`:

```dart
bool _ensureGame(ZipState state) {
  if (state.status == ZipStatus.initial) return false;
  // ... existing body
}
```

In `_maybeShowTutorial`:

```dart
if (state.status == ZipStatus.initial) return;
if (state.status == ZipStatus.locked || state.finished) return;
```

In `initState`, keep calling `_ensureGame` / `_maybeShowTutorial` (they no-op on initial). Also listen for status leaving initial — existing level listener may not fire if level id unchanged from placeholder. Add listener:

```dart
BlocListener<ZipBloc, ZipState>(
  listenWhen: (prev, curr) =>
      prev.status == ZipStatus.initial && curr.status != ZipStatus.initial,
  listener: (context, state) {
    if (_ensureGame(state)) setState(() {});
    _maybeShowTutorial(state);
  },
),
```

Keep the existing level-identity listener.

- [ ] **Step 2: Render shimmer under title when initial**

Import:

```dart
import 'widgets/zip_shimmer.dart';
```

In the `Column` children after the title `Padding`, replace the always-on `Expanded` game + bottom buttons with a branch:

When `state.status == ZipStatus.initial`:

```dart
Expanded(
  child: Semantics(
    label: AppStrings.zipLoading,
    child: const ZipShimmer(),
  ),
),
```

Else: existing `Expanded` (`GameWidget` …) + rule tip + bottom button row (unchanged).

Disable clear when initial (already covered if `canPlay` is false because finished/isReview — ensure `canPlay` is false while initial):

```dart
final isLoading = state.status == ZipStatus.initial;
final canPlay = !isLoading && !finished && !isReview;
```

Hide refresh affordance or leave disabled via `!canPlay` (current clear button already uses `!canPlay`).

- [ ] **Step 3: Regression tests**

```bash
flutter test test/features/zip/
dart format lib/features/zip/view/zip_screen.dart
```

Expected: all Zip tests PASS.

- [ ] **Step 4: Manual checklist**

1. Open Zip cold → shimmer board + two bottom bars under title  
2. After load → real board; can draw  
3. Cleared day → shimmer then locked/review board  
4. No tutorial sheet during shimmer  

- [ ] **Step 5: Commit**

```bash
git add lib/features/zip/view/zip_screen.dart
git commit -m "$(cat <<'EOF'
feat(zip): show ZipShimmer until daily level is ready

EOF
)"
```

---

### Task 4: Spec status + analyze

**Files:**
- Modify: `docs/superpowers/specs/2026-09-30-zip-initial-shimmer-design.md`

- [ ] **Step 1:** Status → `Implemented`

- [ ] **Step 2:**

```bash
dart analyze lib/features/zip/bloc/zip_state.dart lib/features/zip/bloc/zip_bloc.dart lib/features/zip/view/widgets/zip_shimmer.dart lib/features/zip/view/zip_screen.dart lib/core/strings/app_strings.dart
```

Expected: no issues.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/2026-09-30-zip-initial-shimmer-design.md
git commit -m "$(cat <<'EOF'
docs: mark Zip initial shimmer design implemented

EOF
)"
```

---

## Self-review (plan vs spec)

| Spec requirement | Task |
| --- | --- |
| `ZipStatus.initial` until fetch | Task 1 |
| Title bar + shimmer body (grid + bottom chrome) | Task 2–3 |
| No GameWidget / tutorial while initial | Task 3 |
| ready/locked after fetch | Task 1 (`_onStarted`) |
| `AppStrings.zipLoading` Semantics | Task 2–3 |
| Bloc + shimmer tests | Task 1–2 |
| No mid-draw level swap | Task 1 + 3 (no game until ready) |

No placeholders. Types: `ZipShimmer`, `ZipStatus.initial`, `AppStrings.zipLoading` consistent across tasks.
