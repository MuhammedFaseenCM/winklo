# Post-game Mini Leaderboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After Zip/Path Words finish, show a mini Daily leaderboard (top 3 + neighborhood around the player, medal images for ranks 1–3) with “See full leaderboard” and “Back home”, instead of the score card.

**Architecture:** Reuse `/results`: when `ResultsArgs.gameId` is Zip or Path Words, render a mini board powered by existing `LeaderboardCubit` + `WatchLeaderboard`. Pure `sliceLeaderboardForMini` builds the window. Extract a shared row widget (with medal leading) used by full and mini boards. Word Match / null `gameId` keep the existing score card.

**Tech Stack:** Flutter / Dart, `flutter_bloc`, `go_router`, existing Firestore leaderboard stack, `flutter_test` / `bloc_test` / `mocktail`.

## Global Constraints

- Follow spec: `docs/superpowers/specs/2026-09-24-post-game-mini-leaderboard-design.md`
- All user-facing copy via `AppStrings`
- Domain / pure helpers must not import Flutter UI
- Zip + Path Words only for mini board; Word Match unchanged
- No time / points / streak card on post-game mini path
- Mini period is Daily only (no period tabs on mini view)
- Analyze with timed `dart analyze <changed files>` — never MCP `analyze_files`
- Run `dart format` on touched Dart files
- Commits only when the user asks (skip commit steps unless explicitly requested)

---

## File structure map

| Path | Responsibility |
|------|----------------|
| `lib/features/leaderboard/logic/mini_leaderboard_slice.dart` | Pure windowing + gap model |
| `test/features/leaderboard/logic/mini_leaderboard_slice_test.dart` | Slice unit tests |
| `assets/medals/medal_gold.png` | Rank 1 medal |
| `assets/medals/medal_silver.png` | Rank 2 medal |
| `assets/medals/medal_bronze.png` | Rank 3 medal |
| `pubspec.yaml` | Register `assets/medals/` |
| `lib/features/leaderboard/view/widgets/leaderboard_row.dart` | Shared row + medal leading |
| `lib/features/leaderboard/view/leaderboard_screen.dart` | Use shared row |
| `lib/core/strings/app_strings.dart` | `seeFullLeaderboard` (+ gap ellipsis if needed) |
| `lib/features/results/view/mini_leaderboard_panel.dart` | Mini board UI + cubit wiring |
| `lib/features/results/results_screen.dart` | Branch Zip/Path Words → mini panel |
| `test/features/results/results_screen_test.dart` | Score-card vs mini paths |
| `test/features/leaderboard/view/leaderboard_row_test.dart` | Medal vs numeric leading |

---

### Task 1: Pure mini-board windowing helper

**Files:**
- Create: `lib/features/leaderboard/logic/mini_leaderboard_slice.dart`
- Test: `test/features/leaderboard/logic/mini_leaderboard_slice_test.dart`

**Interfaces:**
- Produces:
  - `sealed class MiniLeaderboardItem` with `MiniLeaderboardEntryItem(LeaderboardEntry entry)` and `MiniLeaderboardGap`
  - `List<MiniLeaderboardItem> sliceLeaderboardForMini({ required List<LeaderboardEntry> entries, required String? currentUid, int above = 2, int below = 2 })`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/leaderboard_entry.dart';
import 'package:winklo/features/leaderboard/logic/mini_leaderboard_slice.dart';

LeaderboardEntry e({
  required int rank,
  String uid = 'u',
  int time = 10,
}) {
  return LeaderboardEntry(
    uid: 'uid$rank',
    displayName: 'P$rank',
    timeSeconds: time,
    updatedAt: DateTime.utc(2026, 9, 24),
    rank: rank,
    photoUrl: null,
  );
}

List<LeaderboardEntry> board(int n) =>
    List.generate(n, (i) => e(rank: i + 1, uid: 'uid${i + 1}'));

void main() {
  test('missing user → top 3 only', () {
    final items = sliceLeaderboardForMini(
      entries: board(10),
      currentUid: 'missing',
    );
    expect(items.whereType<MiniLeaderboardEntryItem>().map((i) => i.entry.rank), [
      1, 2, 3,
    ]);
    expect(items.whereType<MiniLeaderboardGap>(), isEmpty);
  });

  test('user in top 3 → top 3 + up to below after 3, no gap', () {
    final items = sliceLeaderboardForMini(
      entries: board(10),
      currentUid: 'uid2',
      below: 2,
    );
    expect(items.whereType<MiniLeaderboardGap>(), isEmpty);
    expect(items.whereType<MiniLeaderboardEntryItem>().map((i) => i.entry.rank), [
      1, 2, 3, 4, 5,
    ]);
  });

  test('user at 25 → 1,2,3,gap,23,24,25,26,27', () {
    final items = sliceLeaderboardForMini(
      entries: board(30),
      currentUid: 'uid25',
    );
    final ranks = <Object>[];
    for (final item in items) {
      if (item is MiniLeaderboardGap) {
        ranks.add('gap');
      } else if (item is MiniLeaderboardEntryItem) {
        ranks.add(item.entry.rank);
      }
    }
    expect(ranks, [1, 2, 3, 'gap', 23, 24, 25, 26, 27]);
  });

  test('near end clamps below', () {
    final items = sliceLeaderboardForMini(
      entries: board(26),
      currentUid: 'uid25',
    );
    final ranks = items
        .whereType<MiniLeaderboardEntryItem>()
        .map((i) => i.entry.rank)
        .toList();
    expect(ranks, containsAll([1, 2, 3, 23, 24, 25, 26]));
    expect(ranks, isNot(contains(27)));
  });

  test('small board < 3', () {
    final items = sliceLeaderboardForMini(
      entries: board(2),
      currentUid: 'uid1',
    );
    expect(
      items.whereType<MiniLeaderboardEntryItem>().map((i) => i.entry.rank),
      [1, 2],
    );
  });

  test('empty board', () {
    expect(
      sliceLeaderboardForMini(entries: const [], currentUid: 'x'),
      isEmpty,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/features/leaderboard/logic/mini_leaderboard_slice_test.dart`

Expected: FAIL (library / function not found)

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/leaderboard/logic/mini_leaderboard_slice.dart
import '../../../domain/entities/leaderboard_entry.dart';

sealed class MiniLeaderboardItem {
  const MiniLeaderboardItem();
}

final class MiniLeaderboardEntryItem extends MiniLeaderboardItem {
  const MiniLeaderboardEntryItem(this.entry);
  final LeaderboardEntry entry;
}

final class MiniLeaderboardGap extends MiniLeaderboardItem {
  const MiniLeaderboardGap();
}

List<MiniLeaderboardItem> sliceLeaderboardForMini({
  required List<LeaderboardEntry> entries,
  required String? currentUid,
  int above = 2,
  int below = 2,
}) {
  if (entries.isEmpty) return const [];

  final byRank = <int, LeaderboardEntry>{
    for (final e in entries) e.rank: e,
  };
  final ranks = byRank.keys.toList()..sort();

  LeaderboardEntry? me;
  if (currentUid != null) {
    for (final e in entries) {
      if (e.uid == currentUid) {
        me = e;
        break;
      }
    }
  }

  final selected = <int>{};
  for (final r in ranks) {
    if (r <= 3) selected.add(r);
  }

  if (me == null) {
    return [
      for (final r in selected.toList()..sort())
        MiniLeaderboardEntryItem(byRank[r]!),
    ];
  }

  if (me.rank <= 3) {
    for (final r in ranks) {
      if (r > 3 && r <= 3 + below) selected.add(r);
    }
  } else {
    final lo = me.rank - above;
    final hi = me.rank + below;
    for (final r in ranks) {
      if (r >= lo && r <= hi) selected.add(r);
    }
  }

  final ordered = selected.toList()..sort();
  final items = <MiniLeaderboardItem>[];
  int? prev;
  for (final r in ordered) {
    if (prev != null && r > prev + 1) {
      items.add(const MiniLeaderboardGap());
    }
    items.add(MiniLeaderboardEntryItem(byRank[r]!));
    prev = r;
  }
  return items;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `dart test test/features/leaderboard/logic/mini_leaderboard_slice_test.dart`

Expected: All PASS

- [ ] **Step 5: Format**

Run: `dart format lib/features/leaderboard/logic/mini_leaderboard_slice.dart test/features/leaderboard/logic/mini_leaderboard_slice_test.dart`

- [ ] **Step 6: Commit** (only if user asked)

```bash
git add lib/features/leaderboard/logic/mini_leaderboard_slice.dart \
  test/features/leaderboard/logic/mini_leaderboard_slice_test.dart
git commit -m "$(cat <<'EOF'
feat: add mini leaderboard windowing helper

EOF
)"
```

---

### Task 2: Medal assets + pubspec

**Files:**
- Create: `assets/medals/medal_gold.png`
- Create: `assets/medals/medal_silver.png`
- Create: `assets/medals/medal_bronze.png`
- Modify: `pubspec.yaml` (under `flutter: assets:`)

**Interfaces:**
- Produces: asset paths used by Task 3:
  - `assets/medals/medal_gold.png`
  - `assets/medals/medal_silver.png`
  - `assets/medals/medal_bronze.png`

- [ ] **Step 1: Generate three medal images with Cursor `GenerateImage`**

Generate separately (aspect ratio `1:1`), flat game-UI style suitable for a dark app row leading icon (~28–32px):

1. **Gold** — circular gold medal with ribbon, no text, transparent background, simple flat vector look.
2. **Silver** — same composition, silver metal.
3. **Bronze** — same composition, bronze metal.

Save/copy outputs into:

- `assets/medals/medal_gold.png`
- `assets/medals/medal_silver.png`
- `assets/medals/medal_bronze.png`

Create the directory if needed: `mkdir -p assets/medals`

- [ ] **Step 2: Register assets in pubspec.yaml**

Add under existing `flutter: assets:` list:

```yaml
    - assets/medals/
```

- [ ] **Step 3: Verify assets resolve**

Run: `flutter pub get`

Expected: exit 0

- [ ] **Step 4: Commit** (only if user asked)

```bash
git add assets/medals pubspec.yaml
git commit -m "$(cat <<'EOF'
chore: add leaderboard medal assets

EOF
)"
```

---

### Task 3: Shared `LeaderboardRow` with medals

**Files:**
- Create: `lib/features/leaderboard/view/widgets/leaderboard_row.dart`
- Modify: `lib/features/leaderboard/view/leaderboard_screen.dart` (remove private `_LeaderboardRow`; import shared widget; keep `_formatTime` or move a tiny `formatLeaderboardTime` into the row file as a top-level function)
- Test: `test/features/leaderboard/view/leaderboard_row_test.dart`

**Interfaces:**
- Consumes: medal asset paths from Task 2; `LeaderboardEntry`; `AppStrings.youLabel`
- Produces:
  - `class LeaderboardRow extends StatelessWidget` with ctor:
    - `required LeaderboardEntry entry`
    - `required String timeLabel`
    - `required bool isYou`
  - Leading: rank 1/2/3 → `Image.asset` medal (size 28); on error / unknown → numeric fallback; rank ≥4 → numeric text width 28

- [ ] **Step 1: Write the failing widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/entities/leaderboard_entry.dart';
import 'package:winklo/features/leaderboard/view/widgets/leaderboard_row.dart';

LeaderboardEntry entry(int rank) => LeaderboardEntry(
  uid: 'u$rank',
  displayName: 'Player $rank',
  timeSeconds: 30,
  updatedAt: DateTime.utc(2026, 9, 24),
  rank: rank,
);

void main() {
  testWidgets('rank 1 shows gold medal asset, not numeral', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: LeaderboardRow(
            entry: entry(1),
            timeLabel: '0:30',
            isYou: false,
          ),
        ),
      ),
    );
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('1'), findsNothing);
  });

  testWidgets('rank 4 shows numeral', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: LeaderboardRow(
            entry: entry(4),
            timeLabel: '0:40',
            isYou: true,
          ),
        ),
      ),
    );
    expect(find.text('4'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/leaderboard/view/leaderboard_row_test.dart`

Expected: FAIL (widget not found)

- [ ] **Step 3: Implement `LeaderboardRow`**

Move logic from current `_LeaderboardRow` in `leaderboard_screen.dart` into the new public widget. Leading:

```dart
Widget _leading(BuildContext context) {
  final rank = entry.rank;
  final asset = switch (rank) {
    1 => 'assets/medals/medal_gold.png',
    2 => 'assets/medals/medal_silver.png',
    3 => 'assets/medals/medal_bronze.png',
    _ => null,
  };
  if (asset != null) {
    return SizedBox(
      width: 28,
      height: 28,
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _rankText(context),
      ),
    );
  }
  return SizedBox(width: 28, child: _rankText(context));
}
```

Preserve avatar, name, `AppStrings.youLabel`, time, and you-highlight decoration from the existing private row.

- [ ] **Step 4: Refactor full leaderboard screen**

Replace `_LeaderboardRow(...)` usages with `LeaderboardRow(...)`. Delete the private class.

- [ ] **Step 5: Run tests**

Run:

```bash
flutter test test/features/leaderboard/view/leaderboard_row_test.dart \
  test/features/leaderboard/cubit/leaderboard_cubit_test.dart
```

Expected: PASS

- [ ] **Step 6: Analyze + format**

Run:

```bash
dart format lib/features/leaderboard/view/widgets/leaderboard_row.dart \
  lib/features/leaderboard/view/leaderboard_screen.dart \
  test/features/leaderboard/view/leaderboard_row_test.dart
dart analyze lib/features/leaderboard/view/widgets/leaderboard_row.dart \
  lib/features/leaderboard/view/leaderboard_screen.dart
```

Expected: no issues

- [ ] **Step 7: Commit** (only if user asked)

```bash
git add lib/features/leaderboard/view/widgets/leaderboard_row.dart \
  lib/features/leaderboard/view/leaderboard_screen.dart \
  test/features/leaderboard/view/leaderboard_row_test.dart
git commit -m "$(cat <<'EOF'
feat: share leaderboard row with top-3 medals

EOF
)"
```

---

### Task 4: AppStrings + mini panel + ResultsScreen branch

**Files:**
- Modify: `lib/core/strings/app_strings.dart`
- Create: `lib/features/results/view/mini_leaderboard_panel.dart`
- Modify: `lib/features/results/results_screen.dart`
- Test: `test/features/results/results_screen_test.dart` (extend)

**Interfaces:**
- Consumes: `sliceLeaderboardForMini`, `LeaderboardRow`, `LeaderboardCubit`, `WatchLeaderboard`, `AuthRepository`, `AuthCubit`, `GameIds`
- Produces:
  - `AppStrings.seeFullLeaderboard = 'See full leaderboard'`
  - `AppStrings.leaderboardGapEllipsis = '…'` (for gap row)
  - `class MiniLeaderboardPanel extends StatelessWidget` with `required String gameId`
  - `ResultsScreen` shows mini path when `args.gameId == GameIds.zip || args.gameId == GameIds.pathWords`

- [ ] **Step 1: Add strings**

In `app_strings.dart` under Auth / leaderboard:

```dart
  static const seeFullLeaderboard = 'See full leaderboard';
  static const leaderboardGapEllipsis = '…';
```

- [ ] **Step 2: Implement `MiniLeaderboardPanel`**

Create `lib/features/results/view/mini_leaderboard_panel.dart`:

- `BlocProvider` + `LeaderboardCubit(initialGameId: gameId)` (Daily default from cubit state)
- Title: `AppStrings.leaderboardTitle`
- Body: signed-out hint / loading / failure+retry / empty / sliced list
- Gap rows: centered `AppStrings.leaderboardGapEllipsis`
- Entry rows: `LeaderboardRow`
- Primary: `ZipPrimaryButton` `AppStrings.seeFullLeaderboard` → `context.push('/leaderboard?game=$gameId')`
- Secondary: `TextButton` `AppStrings.backHome` → `context.go('/')`

Reuse sign-in / retry patterns from `leaderboard_screen.dart`. If `AppStrings.retry` is missing, add `static const retry = 'Retry';` (match label already used on the full board).

- [ ] **Step 3: Branch `ResultsScreen`**

At the start of `build`, after reading args:

```dart
final gameId = args.gameId;
final useMiniLeaderboard =
    gameId == GameIds.zip || gameId == GameIds.pathWords;

if (useMiniLeaderboard) {
  return Scaffold(
    body: ZipAtmosphere(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: MiniLeaderboardPanel(gameId: gameId!),
        ),
      ),
    ),
  );
}
```

Keep the existing score-card body for all other cases. Import `GameIds` and `mini_leaderboard_panel.dart`.

Note: avoid bang if possible — after the boolean check, assign `final id = gameId;` where `gameId` is promoted, or use a local non-null `String` from a switch.

- [ ] **Step 4: Extend results widget tests**

Keep existing Word Match / null-`gameId` tests (score card).

Add coverage that Zip/Path Words branch shows mini UI:

- Prefer `find.byType(MiniLeaderboardPanel)` when pumping `ResultsScreen(args: … gameId: GameIds.zip)` with the DI providers the panel needs (`WatchLeaderboard`, `AuthRepository`, `AuthCubit`), **or**
- A focused `MiniLeaderboardPanel` widget test with mocked stream + signed-in auth, asserting `AppStrings.seeFullLeaderboard`, `AppStrings.backHome`, and absence of score-card copy (`AppStrings.newPersonalBest`, literal `points`).

- [ ] **Step 5: Run tests**

Run:

```bash
flutter test test/features/results/results_screen_test.dart \
  test/features/leaderboard/logic/mini_leaderboard_slice_test.dart \
  test/features/leaderboard/view/leaderboard_row_test.dart
```

Expected: PASS

- [ ] **Step 6: Analyze + format**

Run:

```bash
dart format lib/core/strings/app_strings.dart \
  lib/features/results/view/mini_leaderboard_panel.dart \
  lib/features/results/results_screen.dart \
  test/features/results/results_screen_test.dart
dart analyze lib/features/results/results_screen.dart \
  lib/features/results/view/mini_leaderboard_panel.dart \
  lib/core/strings/app_strings.dart
```

Expected: no issues

- [ ] **Step 7: Manual smoke (optional)**

Play Zip or Path Words to clear → confirm mini board, medals on 1–3, neighborhood + gap when ranked mid-board, “See full leaderboard” opens correct game tab, “Back home” works. Word Match clear still shows score card.

- [ ] **Step 8: Commit** (only if user asked)

```bash
git add lib/core/strings/app_strings.dart \
  lib/features/results/view/mini_leaderboard_panel.dart \
  lib/features/results/results_screen.dart \
  test/features/results/results_screen_test.dart
git commit -m "$(cat <<'EOF'
feat: show mini leaderboard after Zip and Path Words

EOF
)"
```

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Zip/Path Words post-game → mini board | Task 4 |
| No time/points/streak on that path | Task 4 |
| See full leaderboard + Back home | Task 4 |
| Daily period default | Task 4 (`LeaderboardCubit` default) |
| Top 3 + gap + 2 above/below | Task 1 |
| Medals on full + mini | Tasks 2–3 |
| Shared row | Task 3 |
| Word Match unchanged | Task 4 branch |
| Slice unit tests | Task 1 |
| Asset error → numeric fallback | Task 3 `errorBuilder` |

## Notes

- `GameIds.zip` / `GameIds.pathWords` already set on `ResultsArgs` in zip/path_words blocs — no bloc changes required.
- Do not change Firestore submit/ranking.
