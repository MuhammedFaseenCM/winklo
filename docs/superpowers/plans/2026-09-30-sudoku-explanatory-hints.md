# Sudoku Explanatory Hints + Daily Hint Quota Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Teach Sudoku moves with LinkedIn-style banner + highlights (no auto-fill), and persist **3 hints per gameId per play period** for Sudoku, Zip, and Path Words across reset.

**Architecture:** Pure `SudokuHintCoach` returns structured evidence without mutating the grid. Shared `HintQuotaRepository` stores used counts in SharedPreferences keyed by `gameId` + `PlayPeriod.id`. Feature blocs/UI consume the quota; Sudoku Flame paints target/evidence/excluded cells; Zip/Path Words keep reveal UX but stop refilling on reset.

**Tech Stack:** Flutter/Dart, BLoC + freezed, SharedPreferences, Flame (Sudoku/Zip), `bloc_test` / `flutter_test` / `mocktail`

**Spec:** `docs/superpowers/specs/2026-09-30-sudoku-explanatory-hints-design.md`

## Global Constraints

- All user-facing copy via `AppStrings` (no inline UI strings)
- `domain/` must not import Flutter/UI
- Prefer `Cubit`/`Bloc` patterns already in each feature; inject repos via `RepositoryProvider`
- Hint quota: **3 per `gameId` per `PlayPeriod` bucket**; reset must not refill
- Sudoku hint: **explain only** — never write `solution[index]` on Hint
- Techniques v1 only: last-remaining region/row/col + naked single
- Prefer `dart format`; run timed `dart analyze` / `flutter test` on touched files only
- No drive-by refactors outside this feature

## File map

| File | Responsibility |
| --- | --- |
| `lib/domain/repositories/hint_quota_repository.dart` | Quota interface + cap constant |
| `lib/data/repositories/hint_quota_repository_impl.dart` | SharedPreferences persistence |
| `lib/domain/sudoku/sudoku_hint_coach.dart` | Technique finder + evidence (no mutate) |
| `lib/domain/sudoku/sudoku_rules.dart` | Remove fill-based `applyHint` / `SudokuHintResult` |
| `lib/core/di/app_repositories.dart` | Register `HintQuotaRepository` |
| `lib/core/strings/app_strings.dart` | Banner / unit / how-to / hint-with-count copy |
| `lib/features/sudoku/bloc/*` | Quota + active coach hint + dismiss; no fill on hint |
| `lib/features/sudoku/view/sudoku_screen.dart` | Banner UI + `Hint (n)` |
| `lib/features/sudoku/game/sudoku_board_view.dart` | Coach highlight sets for Flame |
| `lib/features/sudoku/game/sudoku_game.dart` | Paint target border / evidence / excluded |
| `lib/features/path_words/bloc/path_words_bloc.dart` | Load/consume quota; reset does not refill |
| `lib/features/zip/game/zip_game.dart` | Init remaining from outside; clearPath does not refill |
| `lib/features/zip/view/zip_screen.dart` | Sync quota from repo on start/hint/clear |
| Tests under `test/domain/…`, `test/data/…`, `test/features/…` | TDD coverage |

---

### Task 1: Hint quota repository (TDD)

**Files:**
- Create: `lib/domain/repositories/hint_quota_repository.dart`
- Create: `lib/data/repositories/hint_quota_repository_impl.dart`
- Create: `test/data/repositories/hint_quota_repository_impl_test.dart`
- Modify: `lib/core/di/app_repositories.dart` (register provider)

**Interfaces:**
- Produces:
  - `abstract class HintQuotaRepository` with:
    - `static const int cap = 3;`
    - `int remaining(String gameId);`
    - `Future<int> tryConsume(String gameId);` — returns remaining after attempt (unchanged if already 0)
  - `class HintQuotaRepositoryImpl implements HintQuotaRepository` constructor:
    - `HintQuotaRepositoryImpl(SharedPreferences prefs, {required Duration playPeriod, DateTime Function()? now})`

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/hint_quota_repository_impl.dart';
import 'package:winklo/domain/play_period.dart';
import 'package:winklo/domain/repositories/hint_quota_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late DateTime clock;

  HintQuotaRepositoryImpl repo({Duration period = PlayPeriod.daily}) {
    return HintQuotaRepositoryImpl(
      prefs,
      playPeriod: period,
      now: () => clock,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    clock = DateTime(2026, 9, 30, 10, 0);
  });

  test('fresh period has full remaining', () {
    expect(repo().remaining('sudoku'), HintQuotaRepository.cap);
  });

  test('tryConsume decrements until zero and does not go negative', () async {
    final r = repo();
    expect(await r.tryConsume('sudoku'), 2);
    expect(await r.tryConsume('sudoku'), 1);
    expect(await r.tryConsume('sudoku'), 0);
    expect(await r.tryConsume('sudoku'), 0);
    expect(r.remaining('sudoku'), 0);
  });

  test('gameIds are independent', () async {
    final r = repo();
    await r.tryConsume('sudoku');
    expect(r.remaining('sudoku'), 2);
    expect(r.remaining('zip'), HintQuotaRepository.cap);
  });

  test('new play period refreshes quota', () async {
    final r = repo(period: PlayPeriod.minute);
    await r.tryConsume('zip');
    expect(r.remaining('zip'), 2);
    clock = clock.add(const Duration(minutes: 1));
    expect(r.remaining('zip'), HintQuotaRepository.cap);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/data/repositories/hint_quota_repository_impl_test.dart`

Expected: FAIL — library / type not found

- [ ] **Step 3: Implement interface + impl + DI**

`lib/domain/repositories/hint_quota_repository.dart`:

```dart
abstract class HintQuotaRepository {
  static const int cap = 3;

  int remaining(String gameId);

  /// Decrements used count for the current play period when remaining > 0.
  /// Returns remaining after the attempt (0 if already exhausted).
  Future<int> tryConsume(String gameId);
}
```

`lib/data/repositories/hint_quota_repository_impl.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/domain/play_period.dart';
import 'package:winklo/domain/repositories/hint_quota_repository.dart';

class HintQuotaRepositoryImpl implements HintQuotaRepository {
  HintQuotaRepositoryImpl(
    this._prefs, {
    required Duration playPeriod,
    DateTime Function()? now,
  }) : _playPeriod = playPeriod,
       _now = now ?? DateTime.now;

  final SharedPreferences _prefs;
  final Duration _playPeriod;
  final DateTime Function() _now;

  static const _prefix = 'hints_used_';

  String _key(String gameId) =>
      '$_prefix${gameId}_${PlayPeriod.id(_now(), _playPeriod)}';

  int _used(String gameId) => _prefs.getInt(_key(gameId)) ?? 0;

  @override
  int remaining(String gameId) {
    final left = HintQuotaRepository.cap - _used(gameId);
    return left < 0 ? 0 : left;
  }

  @override
  Future<int> tryConsume(String gameId) async {
    final left = remaining(gameId);
    if (left <= 0) return 0;
    final nextUsed = _used(gameId) + 1;
    await _prefs.setInt(_key(gameId), nextUsed);
    return HintQuotaRepository.cap - nextUsed;
  }
}
```

In `buildRepositoryProviders` add (near `ScoreRepository`):

```dart
RepositoryProvider<HintQuotaRepository>(
  create: (context) => HintQuotaRepositoryImpl(
    context.read<SharedPreferences>(),
    playPeriod: DevFlags.playPeriod,
  ),
),
```

Import `DevFlags`, `HintQuotaRepository`, `HintQuotaRepositoryImpl`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/data/repositories/hint_quota_repository_impl_test.dart`

Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add lib/domain/repositories/hint_quota_repository.dart \
  lib/data/repositories/hint_quota_repository_impl.dart \
  test/data/repositories/hint_quota_repository_impl_test.dart \
  lib/core/di/app_repositories.dart
git commit -m "$(cat <<'EOF'
feat: add per-game play-period hint quota repository

EOF
)"
```

---

### Task 2: Sudoku hint coach (TDD)

**Files:**
- Create: `lib/domain/sudoku/sudoku_hint_coach.dart`
- Create: `test/domain/sudoku/sudoku_hint_coach_test.dart`

**Interfaces:**
- Produces:
  - `enum SudokuHintTechnique { lastRemainingRegion, lastRemainingRow, lastRemainingCol, nakedSingle }`
  - `class SudokuCoachHint` with fields: `technique`, `targetIndex`, `digit`, `evidenceIndices` (`Set<int>`), `excludedIndices` (`Set<int>`)
  - `abstract final class SudokuHintCoach` with:
    - `static SudokuCoachHint? find({required SudokuPuzzle puzzle, required List<int> grid, int? preferredIndex})`
- Technique priority on one cell: region → row → col → naked single
- Scan: preferred cell first if empty+non-given; else row-major empty non-given cells

- [ ] **Step 1: Write the failing tests**

Use a handcrafted 6×6 grid mirroring the LinkedIn “region last-remaining for 6” case:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/sudoku_difficulty.dart';
import 'package:winklo/domain/entities/sudoku_puzzle.dart';
import 'package:winklo/domain/sudoku/sudoku_hint_coach.dart';

/// 6×6, boxes 2×3. Middle-right box (rows 2–3, cols 3–5):
/// - 6 at index 12 (r2c0) blocks row 2
/// - 6 at index 33 (r5c3) blocks col 3
/// - digit 3 at index 23 (r3c5)
/// → only index 22 (r3c4) can be 6 in that box.
List<int> regionLastRemainingGrid() {
  return <int>[
    0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0,
    6, 0, 0, 0, 0, 0, // index 12 = 6
    0, 0, 0, 0, 0, 3, // index 22 empty target; 23 = 3
    0, 0, 0, 0, 0, 0,
    0, 0, 0, 6, 0, 0, // index 33 = 6
  ];
}

SudokuPuzzle puzzleFor(List<int> grid) {
  // solution unused by coach; provide zeros + size metadata
  return SudokuPuzzle(
    id: 't',
    dateId: 't',
    given: List<int>.filled(36, 0),
    solution: List<int>.filled(36, 1),
    difficulty: SudokuDifficulty.easy,
  );
}

void main() {
  test('finds last-remaining region for digit 6', () {
    final grid = regionLastRemainingGrid();
    final hint = SudokuHintCoach.find(
      puzzle: puzzleFor(grid),
      grid: grid,
    );
    expect(hint, isNotNull);
    expect(hint!.technique, SudokuHintTechnique.lastRemainingRegion);
    expect(hint.targetIndex, 22);
    expect(hint.digit, 6);
    expect(hint.evidenceIndices, containsAll(<int>[12, 33]));
    expect(hint.excludedIndices.contains(22), isFalse);
  });

  test('prefers selected cell when it has a teachable move', () {
    final grid = regionLastRemainingGrid();
    final hint = SudokuHintCoach.find(
      puzzle: puzzleFor(grid),
      grid: grid,
      preferredIndex: 22,
    );
    expect(hint!.targetIndex, 22);
  });

  test('falls back when preferred cell has no teachable move', () {
    final grid = regionLastRemainingGrid();
    final hint = SudokuHintCoach.find(
      puzzle: puzzleFor(grid),
      grid: grid,
      preferredIndex: 0, // empty but not the region single
    );
    expect(hint, isNotNull);
    expect(hint!.targetIndex, 22);
  });

  test('naked single when preferred cell has only one candidate', () {
    // Cell 0: peers eliminate every digit except 5.
    // Row 0 has 1,2,3,4 elsewhere; col 0 has 6 below — leaving only 5.
    // Prefer index 0 so scan does not pick a last-remaining elsewhere first.
    final grid = <int>[
      0, 1, 2, 3, 4, 0, // r0: cell0 empty; 1–4 present in row
      6, 0, 0, 0, 0, 0, // r1: 6 in col0
      0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0,
    ];
    // Box (0,0) also needs digit conflicts for naked single of 5:
    // already have 1,2 in row and 6 in box via (1,0). Add 3,4 already in row.
    // Missing elimination of nothing else — candidates at 0 are {5} if box
    // doesn't also need more. Digits in box rows0-1 cols0-2: 1,2 at r0c1-2, 6 at r1c0.
    // Still missing peer that blocks nothing for 5. candidates = {5} ✓
    final hint = SudokuHintCoach.find(
      puzzle: puzzleFor(grid),
      grid: grid,
      preferredIndex: 0,
    );
    expect(hint, isNotNull);
    expect(hint!.technique, SudokuHintTechnique.nakedSingle);
    expect(hint.targetIndex, 0);
    expect(hint.digit, 5);
  });

  test('last-remaining row', () {
    // Row 0 empties: only col5 can hold digit 6 (cols0–4 blocked by a 6 in each col).
    final grid = List<int>.filled(36, 0);
    grid[6] = 6; // r1c0 blocks col0
    grid[13] = 6; // r2c1 blocks col1
    grid[20] = 6; // r3c2 blocks col2
    grid[27] = 6; // r4c3 blocks col3
    grid[34] = 6; // r5c4 blocks col4
    // row0 col5 (index 5) is the only place for 6 in row 0
    final hint = SudokuHintCoach.find(
      puzzle: puzzleFor(grid),
      grid: grid,
      preferredIndex: 5,
    );
    expect(hint, isNotNull);
    expect(hint!.technique, SudokuHintTechnique.lastRemainingRow);
    expect(hint.targetIndex, 5);
    expect(hint.digit, 6);
  });

  test('last-remaining column', () {
    final grid = List<int>.filled(36, 0);
    // Col 0: only row5 can hold 6 — block rows0–4 via a 6 in each of those rows (other cols).
    grid[1] = 6; // r0c1
    grid[8] = 6; // r1c2
    grid[15] = 6; // r2c3
    grid[22] = 6; // r3c4
    grid[29] = 6; // r4c5
    final hint = SudokuHintCoach.find(
      puzzle: puzzleFor(grid),
      grid: grid,
      preferredIndex: 30, // r5c0
    );
    expect(hint, isNotNull);
    expect(hint!.technique, SudokuHintTechnique.lastRemainingCol);
    expect(hint.targetIndex, 30);
    expect(hint.digit, 6);
  });

  test('returns null when no v1 technique applies', () {
    final grid = List<int>.filled(36, 0);
    expect(
      SudokuHintCoach.find(puzzle: puzzleFor(grid), grid: grid),
      isNull,
    );
  });
}
```

Complete the naked-single fixture in the test file with a concrete grid (no placeholder). Example approach: fill every peer of cell 0 with digits that leave only `5` legal in cell 0, while ensuring no unit has a unique last-remaining for another digit that would win the scan earlier — or set `preferredIndex: 0` so only that cell is evaluated.

Also add at least one row last-remaining and one column last-remaining fixture test.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/domain/sudoku/sudoku_hint_coach_test.dart`

Expected: FAIL — missing library

- [ ] **Step 3: Implement coach**

`SudokuHintCoach.find` algorithm:

1. `candidatesFor(index)` = digits 1–6 not present in same row/col/box.
2. For a cell, try techniques in order:
   - **lastRemainingRegion/Row/Col:** for digit `d` in candidates, if among empty cells of that unit exactly one can hold `d`, and that cell is `index`, build evidence = existing `d` cells that block the other empties; excluded = other cells in unit that cannot hold `d` (empties blocked + filled cells in unit optional — include empties + filled non-target as soft wash matching screenshots).
   - **nakedSingle:** candidates size == 1; evidence = minimal peer cells that eliminate other digits (all peers containing conflicting digits is fine for v1).
3. Preferred index path → else row-major scan.

Do **not** use `puzzle.solution` to decide the digit.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/domain/sudoku/sudoku_hint_coach_test.dart`

Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add lib/domain/sudoku/sudoku_hint_coach.dart \
  test/domain/sudoku/sudoku_hint_coach_test.dart
git commit -m "$(cat <<'EOF'
feat(sudoku): add technique-based hint coach without filling cells

EOF
)"
```

---

### Task 3: Remove fill-based `applyHint` + AppStrings

**Files:**
- Modify: `lib/domain/sudoku/sudoku_rules.dart` (delete `SudokuHintResult`, `applyHint`, `_hintIndex`)
- Modify: `test/domain/sudoku/sudoku_rules_test.dart` (remove applyHint tests)
- Modify: `lib/core/strings/app_strings.dart`

**Interfaces:**
- Consumes: none new
- Produces: AppStrings helpers used by Task 4 UI

- [ ] **Step 1: Update strings**

Add:

```dart
static String sudokuHintWithCount(int n) => 'Hint ($n)';
static const sudokuHintUnitRegion = 'region';
static const sudokuHintUnitRow = 'row';
static const sudokuHintUnitColumn = 'column';
static String sudokuHintLastRemaining({
  required int digit,
  required String unit,
}) =>
    'This cell has to be $digit due to all other cells in this $unit being blocked by other ${digit}s.';
static String sudokuHintNakedSingle({required int digit}) =>
    'This cell has to be $digit — every other digit conflicts with the row, column, or region.';
static const sudokuHintNoSimple =
    'No simple hint right now.';
```

Change `sudokuHowToPlayBody` to say notes are unlimited and hints are **3 per day** (play period), not unlimited.

- [ ] **Step 2: Delete fill-based hint API from rules + fix rules tests**

Remove `SudokuHintResult`, `applyHint`, `_hintIndex`. Delete corresponding tests in `sudoku_rules_test.dart`.

- [ ] **Step 3: Verify**

Run: `flutter test test/domain/sudoku/sudoku_rules_test.dart`

Expected: PASS (remaining tests)

- [ ] **Step 4: Commit**

```bash
git add lib/domain/sudoku/sudoku_rules.dart \
  test/domain/sudoku/sudoku_rules_test.dart \
  lib/core/strings/app_strings.dart
git commit -m "$(cat <<'EOF'
refactor(sudoku): drop fill-from-solution hints; add coach copy strings

EOF
)"
```

---

### Task 4: SudokuBloc — coach hint + quota (no grid mutate)

**Files:**
- Modify: `lib/features/sudoku/bloc/sudoku_state.dart`
- Modify: `lib/features/sudoku/bloc/sudoku_event.dart`
- Modify: `lib/features/sudoku/bloc/sudoku_bloc.dart`
- Modify: `lib/features/sudoku/view/sudoku_screen.dart` (inject `HintQuotaRepository` into bloc ctor)
- Modify: `test/features/sudoku/bloc/sudoku_bloc_test.dart`
- Run build_runner for freezed

**Interfaces:**
- Consumes: `HintQuotaRepository`, `SudokuHintCoach.find`
- Produces state fields:
  - `int hintsRemaining` (default from quota)
  - `SudokuCoachHint? activeCoachHint`
  - `bool showNoSimpleHint` (default false)
- Events: existing `hint`; add `dismissHint`

- [ ] **Step 1: Extend freezed state/events**

State additions:

```dart
@Default(3) int hintsRemaining,
SudokuCoachHint? activeCoachHint,
@Default(false) bool showNoSimpleHint,
```

Remove reliance on `hintFlashIndex` for coach teaching (keep field for now unused, or stop setting it on hint — do not flash-fill). Prefer clearing `hintFlashIndex` on coach hint path.

Event:

```dart
const factory SudokuEvent.dismissHint() = SudokuDismissHint;
```

- [ ] **Step 2: Run codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`

Expected: freezed files regenerate

- [ ] **Step 3: Wire bloc**

Constructor: add `required HintQuotaRepository hintQuota`.

On `started` / `reset`: `hintsRemaining: hintQuota.remaining(GameIds.sudoku)`; clear `activeCoachHint` / `showNoSimpleHint`. **Do not** set remaining to 3.

`_onHint`:

```dart
if (!_canPlay) return;
if (state.hintsRemaining <= 0) return;
final puzzle = state.puzzle;
if (puzzle == null) return;

final coach = SudokuHintCoach.find(
  puzzle: puzzle,
  grid: state.grid,
  preferredIndex: state.selectedIndex,
);
if (coach == null) {
  emit(state.copyWith(
    showNoSimpleHint: true,
    activeCoachHint: null,
    rejectFlashIndex: null,
  ));
  return;
}

final remaining = await hintQuota.tryConsume(GameIds.sudoku);
emit(state.copyWith(
  hintsRemaining: remaining,
  activeCoachHint: coach,
  showNoSimpleHint: false,
  selectedIndex: coach.targetIndex,
  hintFlashIndex: null,
  rejectFlashIndex: null,
));
await analytics.logHintUsed(
  gameId: GameIds.sudoku,
  hintsRemaining: remaining,
);
```

`_onDismissHint`: clear `activeCoachHint` + `showNoSimpleHint`.

On successful `tryPlaceDigit` where `index == activeCoachHint?.targetIndex` && digit matches: clear active coach hint.

- [ ] **Step 4: Write/extend bloc tests**

Cover with a fake `HintQuotaRepository`:

1. Hint with teachable grid → grid unchanged, `activeCoachHint` set, remaining decremented, analytics called.
2. No teachable move → `showNoSimpleHint` true, remaining unchanged, no analytics.
3. Reset after consume → remaining stays consumed (fake returns same remaining).
4. Dismiss clears banner/highlights.

Use `bloc_test` + `mocktail` Fake/Mock for quota + analytics.

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/sudoku/bloc/sudoku_bloc_test.dart`

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/features/sudoku/bloc/ \
  lib/features/sudoku/view/sudoku_screen.dart \
  test/features/sudoku/bloc/sudoku_bloc_test.dart
git commit -m "$(cat <<'EOF'
feat(sudoku): show coach hints and consume play-period quota without filling

EOF
)"
```

---

### Task 5: Sudoku UI banner + Hint (n) + board highlights

**Files:**
- Modify: `lib/features/sudoku/view/sudoku_screen.dart`
- Modify: `lib/features/sudoku/game/sudoku_board_view.dart`
- Modify: `lib/features/sudoku/game/sudoku_game.dart`

**Interfaces:**
- Consumes: `state.activeCoachHint`, `state.showNoSimpleHint`, `state.hintsRemaining`, AppStrings
- Board view fields:
  - `int? coachTargetIndex`
  - `Set<int> coachEvidenceIndices`
  - `Set<int> coachExcludedIndices`

- [ ] **Step 1: Map state → board view**

When building `SudokuBoardView`, pass coach sets from `activeCoachHint` (empty sets when null).

- [ ] **Step 2: Paint in `SudokuGame._paintCell`**

Order (under selection, over empty background):

1. If index in `coachExcludedIndices`: soft success wash (~0.22 alpha).
2. If index in `coachEvidenceIndices`: stronger success fill (~0.40 alpha).
3. If index == `coachTargetIndex`: draw bright success **border** (stroke ~2.5) — do not require digit present.

Keep existing reject/unit/celebrate paints.

- [ ] **Step 3: Banner + pad**

Between `GameWidget` and `_NumberPad`, when `activeCoachHint != null || showNoSimpleHint`:

```dart
Material(
  color: ZipColors.success.withValues(alpha: 0.85),
  borderRadius: BorderRadius.circular(12),
  child: Padding(
    padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            showNoSimple
                ? AppStrings.sudokuHintNoSimple
                : _coachMessage(active),
            style: const TextStyle(color: Colors.white, height: 1.25),
          ),
        ),
        IconButton(
          onPressed: () => context.read<SudokuBloc>().add(
                const SudokuEvent.dismissHint(),
              ),
          icon: const Icon(Icons.close, color: Colors.white),
        ),
      ],
    ),
  ),
)
```

`_coachMessage` maps technique → `AppStrings.sudokuHintLastRemaining` / `sudokuHintNakedSingle` with unit strings.

Hint button: `onPressed: remaining > 0 ? onHint : null`, label `AppStrings.sudokuHintWithCount(remaining)`.

Inject `hintQuota: context.read<HintQuotaRepository>()` in screen’s `SudokuBloc(...)` ctor (if not done in Task 4).

- [ ] **Step 4: Manual smoke (optional in agent)** / analyze touched files

Run: `dart analyze lib/features/sudoku lib/core/strings/app_strings.dart`

Expected: No issues

- [ ] **Step 5: Commit**

```bash
git add lib/features/sudoku/view/sudoku_screen.dart \
  lib/features/sudoku/game/sudoku_board_view.dart \
  lib/features/sudoku/game/sudoku_game.dart
git commit -m "$(cat <<'EOF'
feat(sudoku): render coach hint banner and evidence highlights

EOF
)"
```

---

### Task 6: Path Words — persist quota across reset

**Files:**
- Modify: `lib/features/path_words/bloc/path_words_bloc.dart`
- Modify: Path Words screen / DI site that constructs the bloc (pass `HintQuotaRepository`)
- Modify: `test/features/path_words/...` (existing bloc tests if any; add quota cases)

**Interfaces:**
- Consumes: `HintQuotaRepository.remaining` / `tryConsume`
- Keep reveal UX (`hintRevealLength` etc.) unchanged

- [ ] **Step 1: Inject repo; load remaining on start/reset**

Replace every `hintsRemaining: 3` with `hintQuota.remaining(GameIds.pathWords)`.

- [ ] **Step 2: Consume on successful hint**

In hint handlers, after a successful reveal:

```dart
final remaining = await hintQuota.tryConsume(GameIds.pathWords);
emit(state.copyWith(hintsRemaining: remaining, /* existing reveal fields */));
analytics.logHintUsed(gameId: GameIds.pathWords, hintsRemaining: remaining);
```

Do not decrement with `state.hintsRemaining - 1` alone.

- [ ] **Step 3: Tests**

Assert reset after two consumes leaves remaining at 1 (fake repo).

- [ ] **Step 4: Run Path Words tests**

Run: `flutter test test/features/path_words`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/path_words/ test/features/path_words/
git commit -m "$(cat <<'EOF'
feat(path_words): use play-period hint quota that survives reset

EOF
)"
```

---

### Task 7: Zip — persist quota across clear/reset

**Files:**
- Modify: `lib/features/zip/game/zip_game.dart`
- Modify: `lib/features/zip/view/zip_screen.dart`
- Modify tests if Zip game/screen covered

**Interfaces:**
- Flame must not own SharedPreferences
- `ZipGame` keeps a synced `hintsRemaining` int for UI/`canHint`
- `clearPath` must **not** set `hintsRemaining = 3`

- [ ] **Step 1: Stop refill on clear**

In `ZipGame.clearPath`, delete `hintsRemaining = 3;`.

Allow constructing / assigning initial remaining:

```dart
ZipGame({..., int initialHintsRemaining = HintQuotaRepository.cap})
  : hintsRemaining = initialHintsRemaining, ...
```

- [ ] **Step 2: Screen wires quota**

On game create / after clear:

```dart
final remaining = context.read<HintQuotaRepository>().remaining(GameIds.zip);
game.hintsRemaining = remaining;
```

On Hint button success (`game.hint()` true):

```dart
final remaining =
    await context.read<HintQuotaRepository>().tryConsume(GameIds.zip);
game.hintsRemaining = remaining;
_bloc.add(ZipEvent.hint(hintsRemaining: remaining));
setState(() {});
```

Ensure `canHint` still requires `hintsRemaining > 0`.

- [ ] **Step 3: Verify Zip hint / clear behavior with a focused test if one exists; otherwise add a small unit test that `clearPath` does not change `hintsRemaining`**

Example:

```dart
test('clearPath does not restore hintsRemaining', () {
  final game = ZipGame(/* minimal level */, initialHintsRemaining: 1);
  game.hintsRemaining = 1;
  game.clearPath();
  expect(game.hintsRemaining, 1);
});
```

(Adapt to actual `ZipGame` constructor — keep fixture minimal.)

- [ ] **Step 4: Run**

Run: `flutter test test/features/zip`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/zip/ test/features/zip/
git commit -m "$(cat <<'EOF'
feat(zip): bind hints to play-period quota without refill on clear

EOF
)"
```

---

### Task 8: Final verification + design status

**Files:**
- Modify: `docs/superpowers/specs/2026-09-30-sudoku-explanatory-hints-design.md` (Status → Implemented)

- [ ] **Step 1: Run focused regression**

```bash
flutter test \
  test/data/repositories/hint_quota_repository_impl_test.dart \
  test/domain/sudoku/sudoku_hint_coach_test.dart \
  test/domain/sudoku/sudoku_rules_test.dart \
  test/features/sudoku \
  test/features/path_words \
  test/features/zip
```

Expected: All PASS

- [ ] **Step 2: Analyze touched libs**

```bash
dart analyze \
  lib/domain/repositories/hint_quota_repository.dart \
  lib/data/repositories/hint_quota_repository_impl.dart \
  lib/domain/sudoku/sudoku_hint_coach.dart \
  lib/domain/sudoku/sudoku_rules.dart \
  lib/features/sudoku \
  lib/features/path_words/bloc \
  lib/features/zip/game/zip_game.dart \
  lib/features/zip/view/zip_screen.dart \
  lib/core/di/app_repositories.dart \
  lib/core/strings/app_strings.dart
```

Expected: No issues

- [ ] **Step 3: Mark spec implemented + commit**

```bash
git add docs/superpowers/specs/2026-09-30-sudoku-explanatory-hints-design.md
git commit -m "$(cat <<'EOF'
docs: mark Sudoku explanatory hints design implemented

EOF
)"
```

---

## Spec coverage checklist

| Spec requirement | Task |
| --- | --- |
| Explain-only Sudoku hints | 2, 3, 4, 5 |
| Last-remaining row/col/region + naked single | 2 |
| Prefer selected else scan | 2, 4 |
| No simple hint, no consume | 4, 5 |
| Banner + evidence/excluded/target paint | 5 |
| 3 per gameId per play period | 1, 4, 6, 7 |
| Reset does not refill | 4, 6, 7 |
| Zip/Path Words reveal UX unchanged | 6, 7 |
| AppStrings / how-to update | 3 |
| Analytics post-consume only | 4, 6, 7 |
| Tests for coach, quota, blocs | 1–7 |
