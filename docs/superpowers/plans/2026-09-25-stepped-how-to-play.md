# Stepped How-to-Play Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn Zip and Path Words how-to-play into stepped tutorials with auto-advance, Skip (exit), Next, and Got it on the last step — expanding Path Words to teach start markers, locked letters, and finding every word.

**Architecture:** Evolve shared `GameTutorialOverlay` to own step index and chrome. Game tutorials keep supplying `captions` + `demoBuilder`. Extend `TutorialMiniBoard` for start markers, locked cells, and fully-drawn completed paths so Path Words demos can show CAT then RUN.

**Tech Stack:** Flutter / Dart, existing `ZipColors` / `AppStrings`, `flutter_test` + `mocktail`.

## Global Constraints

- Follow spec: `docs/superpowers/specs/2026-09-25-stepped-how-to-play-design.md`
- User-facing copy only via `AppStrings`
- Skip exits whole tutorial; last step shows Got it only; barrier dismiss ≡ dismiss
- Zip keeps 4 captions; Path Words becomes 6
- No new analytics events; keep mark-seen via `TutorialRepository`
- Analyze with timed `dart analyze <changed files>` — never MCP `analyze_files`
- Run `dart format` on touched Dart files
- Commits only when the user asks (skip commit steps unless explicitly requested)

---

## File structure map

| Path | Responsibility |
|------|----------------|
| `lib/core/strings/app_strings.dart` | `tutorialSkip`, `tutorialNext`, Path Words step captions |
| `lib/core/widgets/game_tutorial_overlay.dart` | Stepped chrome: auto-advance, dots, Skip/Next/Got it |
| `test/core/widgets/game_tutorial_overlay_test.dart` | Overlay step / button / dismiss behavior |
| `lib/core/widgets/tutorial_mini_board.dart` | Start markers, locked cells, completed paths |
| `test/core/widgets/tutorial_mini_board_test.dart` | Mini-board option smoke (create if missing) |
| `lib/features/path_words/view/widgets/path_words_tutorial.dart` | 6-step captions + demos (CAT + RUN) |
| `test/features/path_words/view/path_words_tutorial_test.dart` | Show / Skip marks seen; six captions |
| `lib/features/zip/view/widgets/zip_tutorial.dart` | Unchanged captions; works via overlay (verify) |
| `test/features/zip/view/zip_tutorial_test.dart` | Dismiss via Skip or Got it on last step |
| `test/features/path_words/view/path_words_screen_test.dart` | Smoke: opens overlay on first caption |

---

### Task 1: Stepped `GameTutorialOverlay` + strings

**Files:**
- Modify: `lib/core/strings/app_strings.dart`
- Modify: `lib/core/widgets/game_tutorial_overlay.dart`
- Modify: `test/core/widgets/game_tutorial_overlay_test.dart`

**Interfaces:**
- Consumes: existing `TutorialDemoBuilder`, `AppStrings`
- Produces (behavior contract):

```dart
// AppStrings additions
static const tutorialSkip = 'Skip';
static const tutorialNext = 'Next';
// pathWordsTutorialStartMarker / LockedLetters / FindEveryWord added in Task 3
// (do not add Path Words strings in this task)

// Overlay behavior
// - step index 0..captions.length-1
// - per-step AnimationController duration = beatDuration; value = beatT in [0,1)
// - on controller complete: if not last → advance step + restart; if last → repeat within step
// - non-last: TextButton Skip + FilledButton Next
// - last: FilledButton Got it only
// - Skip / Got it / barrier → pop / onGotIt / onDismissed (unchanged show() completeOnce)
// - step dots under caption
```

- [ ] **Step 1: Add shared strings**

In `lib/core/strings/app_strings.dart`, after `tutorialGotIt`:

```dart
static const tutorialSkip = 'Skip';
static const tutorialNext = 'Next';
```

- [ ] **Step 2: Rewrite failing overlay tests**

Replace `test/core/widgets/game_tutorial_overlay_test.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/widgets/game_tutorial_overlay.dart';
import 'package:winklo/core/widgets/tutorial_mini_board.dart';
import 'package:winklo/domain/entities/cell.dart';

void main() {
  Widget harness({
    required List<String> captions,
    required VoidCallback onGotIt,
    Duration beatDuration = const Duration(milliseconds: 400),
  }) {
    return MaterialApp(
      home: Scaffold(
        body: GameTutorialOverlay(
          title: AppStrings.zipHowToPlayTitle,
          captions: captions,
          beatDuration: beatDuration,
          onGotIt: onGotIt,
          demoBuilder: (context, beat, beatT) {
            return TutorialMiniBoard(
              size: 2,
              labels: {const Cell(0, 0): '1', const Cell(1, 1): '2'},
              path: const [Cell(0, 0), Cell(0, 1), Cell(1, 1)],
              pathProgress: beat == 0 ? 0 : beatT,
              drawnFill: beat > 0,
            );
          },
        ),
      ),
    );
  }

  testWidgets('auto-advances captions; last step shows Got it only', (
    tester,
  ) async {
    var gotIt = false;
    await tester.pumpWidget(
      harness(
        captions: const [
          AppStrings.zipTutorialStart,
          AppStrings.zipTutorialFinish,
        ],
        onGotIt: () => gotIt = true,
      ),
    );

    expect(find.text(AppStrings.zipTutorialStart), findsOneWidget);
    expect(find.text(AppStrings.tutorialNext), findsOneWidget);
    expect(find.text(AppStrings.tutorialSkip), findsOneWidget);
    expect(find.text(AppStrings.tutorialGotIt), findsNothing);

    await tester.pump(const Duration(milliseconds: 450));
    expect(find.text(AppStrings.zipTutorialFinish), findsOneWidget);
    expect(find.text(AppStrings.tutorialGotIt), findsOneWidget);
    expect(find.text(AppStrings.tutorialNext), findsNothing);
    expect(find.text(AppStrings.tutorialSkip), findsNothing);

    await tester.tap(find.text(AppStrings.tutorialGotIt));
    await tester.pump();
    expect(gotIt, isTrue);
  });

  testWidgets('Next advances early; Skip dismisses', (tester) async {
    var gotIt = false;
    await tester.pumpWidget(
      harness(
        captions: const [
          AppStrings.zipTutorialStart,
          AppStrings.zipTutorialFinish,
          AppStrings.zipTutorialFillEveryCell,
        ],
        onGotIt: () => gotIt = true,
        beatDuration: const Duration(seconds: 10),
      ),
    );

    expect(find.text(AppStrings.zipTutorialStart), findsOneWidget);
    await tester.tap(find.text(AppStrings.tutorialNext));
    await tester.pump();
    expect(find.text(AppStrings.zipTutorialFinish), findsOneWidget);

    await tester.tap(find.text(AppStrings.tutorialSkip));
    await tester.pump();
    expect(gotIt, isTrue);
  });
}
```

- [ ] **Step 3: Run tests — expect FAIL**

Run:

```bash
flutter test test/core/widgets/game_tutorial_overlay_test.dart
```

Expected: FAIL (Skip/Next not found; still only Got it / looping).

- [ ] **Step 4: Implement stepped overlay**

Rewrite `lib/core/widgets/game_tutorial_overlay.dart` state to:

1. Hold `int _step = 0`.
2. `AnimationController` duration = `widget.beatDuration` only (not × caption count).
3. On init: `_controller.forward()`.
4. Listener: when status is `completed`:
   - if `_step < captions.length - 1` → `setState(() => _step++)`, `_controller.forward(from: 0)`
   - else → `_controller.repeat()` so last-step demo keeps moving
5. `beat` = `_step`; `beatT` = `_controller.value`.
6. Caption = `captions[_step]`.
7. Buttons:
   - if not last:

```dart
Row(
  children: [
    TextButton(
      onPressed: widget.onGotIt,
      child: Text(AppStrings.tutorialSkip),
    ),
    const SizedBox(width: 8),
    Expanded(
      child: FilledButton(
        onPressed: _goNext,
        child: Text(AppStrings.tutorialNext),
      ),
    ),
  ],
)
```

   - if last: full-width `FilledButton` Got it → `widget.onGotIt`.

8. `_goNext`: if last return; else `setState` increment step, stop any repeat, `_controller.forward(from: 0)`.

9. Step dots: `Row` of small circles; active = `ZipColors.sky`, inactive = `ZipColors.outlineQuiet`.

10. Keep `show()` API the same (`barrierDismissible: true`, `whenComplete(completeOnce)`).

Keep visual card (title, demo, caption, buttons) matching current padding/colors.

- [ ] **Step 5: Run tests — expect PASS**

```bash
flutter test test/core/widgets/game_tutorial_overlay_test.dart
```

Expected: PASS.

- [ ] **Step 6: Format + analyze**

```bash
dart format lib/core/strings/app_strings.dart lib/core/widgets/game_tutorial_overlay.dart test/core/widgets/game_tutorial_overlay_test.dart
dart analyze lib/core/widgets/game_tutorial_overlay.dart lib/core/strings/app_strings.dart
```

---

### Task 2: `TutorialMiniBoard` start markers, locked cells, completed paths

**Files:**
- Modify: `lib/core/widgets/tutorial_mini_board.dart`
- Create: `test/core/widgets/tutorial_mini_board_test.dart`

**Interfaces:**
- Consumes: existing `TutorialMiniBoard` API
- Produces: additional optional params:

```dart
final Set<Cell> startMarkers; // default {}
final Color startMarkerColor; // default ZipColors.sky
final Set<Cell> lockedCells; // default {} — dim fill + muted label
final List<(List<Cell> cells, Color color)> completedPaths; // default const []
// Always paint completedPaths fully filled + stroked before active `path`
```

`shouldRepaint` must include the new fields.

- [ ] **Step 1: Write failing smoke test**

Create `test/core/widgets/tutorial_mini_board_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/core/widgets/tutorial_mini_board.dart';
import 'package:winklo/domain/entities/cell.dart';

void main() {
  testWidgets('builds with startMarkers, lockedCells, completedPaths', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: TutorialMiniBoard(
            size: 3,
            labels: {
              const Cell(0, 0): 'C',
              const Cell(0, 1): 'A',
              const Cell(0, 2): 'T',
              const Cell(2, 0): 'R',
              const Cell(2, 1): 'U',
              const Cell(2, 2): 'N',
            },
            path: const [Cell(2, 0), Cell(2, 1), Cell(2, 2)],
            pathProgress: 0.5,
            drawnFill: true,
            startMarkers: const {Cell(0, 0), Cell(2, 0)},
            lockedCells: const {Cell(0, 0), Cell(0, 1), Cell(0, 2)},
            completedPaths: const [
              ([Cell(0, 0), Cell(0, 1), Cell(0, 2)], ZipColors.sky),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(TutorialMiniBoard), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test — expect FAIL** (unknown named params)

```bash
flutter test test/core/widgets/tutorial_mini_board_test.dart
```

- [ ] **Step 3: Implement mini-board extensions**

In `TutorialMiniBoard` / painter:

1. Add fields with defaults `const {}` / `const []` / `ZipColors.sky`.
2. When painting cell fill:
   - if cell in any `completedPaths` → that path’s color @ ~0.28 alpha
   - else if `lockedCells` → muted fill (`ZipColors.inkSoft` with low alpha, or dimmed wall)
   - else existing `drawnFill` / path logic
3. After labels (or before finger): for each `startMarkers` cell, draw double ring like Path Words `_drawStartRing` (white stroke + colored stroke).
4. Paint each `completedPaths` stroke fully (pathProgress=1) in its color before the active path.
5. Locked labels: slightly lower opacity text when in `lockedCells`.
6. Update `shouldRepaint`.

Keep existing callers compiling (new params optional).

- [ ] **Step 4: Run test — expect PASS**

```bash
flutter test test/core/widgets/tutorial_mini_board_test.dart
```

- [ ] **Step 5: Format + analyze**

```bash
dart format lib/core/widgets/tutorial_mini_board.dart test/core/widgets/tutorial_mini_board_test.dart
dart analyze lib/core/widgets/tutorial_mini_board.dart
```

---

### Task 3: Path Words 6-step tutorial

**Files:**
- Modify: `lib/core/strings/app_strings.dart`
- Modify: `lib/features/path_words/view/widgets/path_words_tutorial.dart`
- Modify: `test/features/path_words/view/path_words_tutorial_test.dart`
- Modify: `test/features/path_words/view/path_words_screen_test.dart` (only if assertions break)

**Interfaces:**
- Consumes: stepped overlay; mini-board new params
- Produces:

```dart
// AppStrings
static const pathWordsTutorialStartMarker = 'Start from a marked letter';
static const pathWordsTutorialLockedLetters = 'Used letters stay locked';
static const pathWordsTutorialFindEveryWord = 'Find every word';

// PathWordsTutorial
static const captions = <String>[
  AppStrings.pathWordsTutorialDrag,
  AppStrings.pathWordsTutorialLift,
  AppStrings.pathWordsTutorialMatchList,
  AppStrings.pathWordsTutorialStartMarker,
  AppStrings.pathWordsTutorialLockedLetters,
  AppStrings.pathWordsTutorialFindEveryWord,
];

static const wordPath = <Cell>[Cell(0, 0), Cell(0, 1), Cell(0, 2)]; // CAT
static const secondWordPath = <Cell>[Cell(2, 0), Cell(2, 1), Cell(2, 2)]; // RUN
static const word = 'CAT';
static const secondWord = 'RUN';
```

Demo mapping:

| beat | Board | Word list |
|------|-------|-----------|
| 0 | Draw CAT; no lift | CAT incomplete |
| 1 | CAT with mid lift/continue | incomplete until end |
| 2 | CAT complete; highlight | CAT checked |
| 3 | No finger path; `startMarkers: {C, R}` pulsing | both incomplete |
| 4 | CAT in `completedPaths` + `lockedCells`; finger idle | CAT checked |
| 5 | CAT completed/locked; draw RUN on `path`; both checked at end | CAT + RUN checked |

Replace `_MiniWordListRow` with a column of two rows (or pass a list of `(label, complete)`).

- [ ] **Step 1: Add Path Words strings**

```dart
static const pathWordsTutorialStartMarker = 'Start from a marked letter';
static const pathWordsTutorialLockedLetters = 'Used letters stay locked';
static const pathWordsTutorialFindEveryWord = 'Find every word';
```

Keep existing drag/lift/match strings.

- [ ] **Step 2: Update tutorial tests (TDD)**

Replace/extend `test/features/path_words/view/path_words_tutorial_test.dart`:

```dart
testWidgets('PathWordsTutorial.show marks seen on Skip', (tester) async {
  // same RepositoryProvider + open button setup as existing test
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));

  expect(find.byType(GameTutorialOverlay), findsOneWidget);
  expect(find.text(AppStrings.pathWordsTutorialDrag), findsOneWidget);
  expect(find.text(AppStrings.tutorialSkip), findsOneWidget);

  await tester.tap(find.text(AppStrings.tutorialSkip));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));

  verify(() => repo.markSeen(GameIds.pathWords)).called(1);
});

testWidgets('PathWordsTutorial exposes all six captions via Next', (
  tester,
) async {
  // same open setup; when(() => repo.markSeen(...)).thenAnswer((_) async {});
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));

  final expected = [
    AppStrings.pathWordsTutorialDrag,
    AppStrings.pathWordsTutorialLift,
    AppStrings.pathWordsTutorialMatchList,
    AppStrings.pathWordsTutorialStartMarker,
    AppStrings.pathWordsTutorialLockedLetters,
    AppStrings.pathWordsTutorialFindEveryWord,
  ];
  for (var i = 0; i < expected.length; i++) {
    expect(find.text(expected[i]), findsOneWidget);
    if (i < expected.length - 1) {
      await tester.tap(find.text(AppStrings.tutorialNext));
      await tester.pump();
    }
  }
  expect(find.text(AppStrings.tutorialGotIt), findsOneWidget);
  await tester.tap(find.text(AppStrings.tutorialGotIt));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  verify(() => repo.markSeen(GameIds.pathWords)).called(1);
});
```

- [ ] **Step 3: Run tests — expect FAIL** (missing strings / Skip / six captions)

```bash
flutter test test/features/path_words/view/path_words_tutorial_test.dart
```

- [ ] **Step 4: Implement Path Words tutorial demos**

Update `path_words_tutorial.dart`:

1. Add `secondWordPath`, `secondWord`, expand `captions`.
2. In `demoBuilder`, `switch (beat)` per table above.
3. Word list UI: two rows; CAT complete on beats 2, 4, 5; RUN complete on beat 5 when `pathProgress >= 0.98`.
4. Use `startMarkers`, `lockedCells`, `completedPaths` on `TutorialMiniBoard`.
5. Keep `show` / `maybeShow` / analytics / markSeen unchanged.

- [ ] **Step 5: Run tests — expect PASS**

```bash
flutter test test/features/path_words/view/path_words_tutorial_test.dart test/features/path_words/view/path_words_screen_test.dart
```

Fix screen test only if it taps Got it on first step (today it only opens and asserts first caption — should still pass).

- [ ] **Step 6: Format + analyze**

```bash
dart format lib/core/strings/app_strings.dart lib/features/path_words/view/widgets/path_words_tutorial.dart test/features/path_words/view/path_words_tutorial_test.dart
dart analyze lib/features/path_words/view/widgets/path_words_tutorial.dart lib/core/strings/app_strings.dart
```

---

### Task 4: Zip tutorial tests + smoke

**Files:**
- Modify: `test/features/zip/view/zip_tutorial_test.dart`
- Verify: `lib/features/zip/view/widgets/zip_tutorial.dart` (no caption changes required)

**Interfaces:**
- Consumes: stepped overlay
- Produces: Zip still 4 captions; dismiss via Skip marks seen

- [ ] **Step 1: Update Zip tutorial test to use Skip**

Replace Got it tap on first step with Skip (first step is no longer Got it):

```dart
expect(find.text(AppStrings.zipTutorialStart), findsOneWidget);
expect(find.text(AppStrings.tutorialSkip), findsOneWidget);

await tester.tap(find.text(AppStrings.tutorialSkip));
await tester.pump();
await tester.pump(const Duration(milliseconds: 300));

verify(() => repo.markSeen(GameIds.zip)).called(1);
```

Optional: add a second test that taps Next through all 4 captions then Got it.

- [ ] **Step 2: Run Zip + overlay regression**

```bash
flutter test test/features/zip/view/zip_tutorial_test.dart test/core/widgets/game_tutorial_overlay_test.dart
```

Expected: PASS. Zip tutorial `switch (beat)` cases 0–3 stay as-is.

- [ ] **Step 3: Format if test file changed**

```bash
dart format test/features/zip/view/zip_tutorial_test.dart
```

---

### Task 5: Full verification

- [ ] **Step 1: Run all tutorial-related tests**

```bash
flutter test \
  test/core/widgets/game_tutorial_overlay_test.dart \
  test/core/widgets/tutorial_mini_board_test.dart \
  test/features/path_words/view/path_words_tutorial_test.dart \
  test/features/path_words/view/path_words_screen_test.dart \
  test/features/zip/view/zip_tutorial_test.dart
```

Expected: all PASS.

- [ ] **Step 2: Analyze touched libs**

```bash
dart analyze \
  lib/core/strings/app_strings.dart \
  lib/core/widgets/game_tutorial_overlay.dart \
  lib/core/widgets/tutorial_mini_board.dart \
  lib/features/path_words/view/widgets/path_words_tutorial.dart \
  lib/features/zip/view/widgets/zip_tutorial.dart
```

Expected: no issues.

- [ ] **Step 3: Manual checklist (device/simulator)**

1. Open Zip first-run or How to play → Skip exits; reopen → Next through 4 steps → Got it.
2. Open Path Words How to play → confirm 6 captions and CAT/RUN demos for start/lock/every-word.
3. Confirm auto-advance still moves steps without tapping Next.
4. Confirm tutorial does not auto-show again after Skip/Got it.

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Auto-advance + Next / Skip | 1 |
| Skip exits whole tutorial; marks seen | 1, 3, 4 |
| Last step Got it only | 1 |
| Step dots | 1 |
| `tutorialSkip` / `tutorialNext` | 1 |
| Zip 4 beats unchanged | 4 |
| Path Words 6 steps + strings | 3 |
| Start markers / locked / every word demos | 2, 3 |
| Mini-board extensions | 2 |
| No new analytics | — (unchanged call sites) |
| Tests for overlay / Path Words / Zip | 1–5 |
