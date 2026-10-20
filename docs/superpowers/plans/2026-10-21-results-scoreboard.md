# Results Scoreboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the daily Results screen (Zip, Path Words, Sudoku) as a scoreboard. It has a top bar, a time with a rank badge, stat tiles, a table card (with a Board | Words switch for Path Words) and one action bar.

**Architecture:**
- The signed-in layout owns one `LeaderboardCubit`, shared by the rank badge and the mini table.
- Pure rules live in `logic/` and are unit-tested:
  - which stat tiles show (`result_tiles.dart`)
  - which board rows fit (`fitLeaderboardForMini`)
- Widgets are split per piece under `features/results/view/`.
- The table rows reuse the podium branch's `LeaderboardTableRow`.

**Tech Stack:** Flutter, flutter_bloc, flutter_animate, go_router, mocktail; Phosphor via `AppIcons`/`AppIcon`.

**Spec:** `docs/superpowers/specs/2026-10-21-results-scoreboard-design.md`

**Conventions:**
- Run `dart format` only on files you touch.
- After `flutter pub get`, run `git checkout pubspec.lock`.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Work in the `.worktrees/results-scoreboard` worktree.

**One deviation from the spec:** the loading state keeps today's centred `CircularProgressIndicator`. The podium branch's `LeaderboardShimmer` draws a podium, and its row shimmer is private, so it doesn't fit the card.

---

## File map

| File | Change |
|---|---|
| `lib/domain/entities/leaderboard_period.dart` | + `leaderboardDailyLimit = 50` |
| `lib/data/repositories/leaderboard_repository_impl.dart` | `.limit(50)` → `.limit(leaderboardDailyLimit)` |
| `lib/core/strings/app_text.dart`, `app_text_en.dart`, `app_text_ml.dart`, `app_strings.dart` | 6 new strings |
| `test/core/strings/app_text_test.dart` | sample entries + allowlist `resultsHintTimeTile` |
| `lib/features/results/logic/result_tiles.dart` | **new**, pure tile rules |
| `test/features/results/logic/result_tiles_test.dart` | **new** |
| `lib/features/leaderboard/logic/mini_leaderboard_slice.dart` | + `fitLeaderboardForMini` |
| `test/features/leaderboard/logic/mini_leaderboard_slice_test.dart` | + fit tests |
| `lib/features/leaderboard/view/widgets/leaderboard_table.dart` | `showMedals` on `LeaderboardTableRow` |
| `lib/features/results/view/results_top_bar.dart` | **new**: game chip + countdown |
| `lib/features/results/view/results_hero.dart` | **new**: time + `ResultsRankBadge` |
| `lib/features/results/view/result_tiles_row.dart` | **new** |
| `lib/features/results/view/results_board_card.dart` | **new**: card, switch, words |
| `lib/features/results/view/results_board_tease.dart` | + `framed` |
| `lib/features/results/view/mini_leaderboard_panel.dart` | rewritten: table body only |
| `lib/features/results/view/results_actions.dart` | rewritten: action bar |
| `lib/features/results/results_screen.dart` | `_CelebrateAndClaimResults` rebuilt, `_NextPuzzleLine` moved |
| `test/features/results/*.dart` | updated, plus the screenshots test |

---

### Task 1: Board limit constant and strings

**Files:**
- Modify: `lib/domain/entities/leaderboard_period.dart` (end of file)
- Modify: `lib/data/repositories/leaderboard_repository_impl.dart:442`
- Modify: `lib/core/strings/app_text.dart` (Results block, after `resultsBoardTeaseHint`)
- Modify: `lib/core/strings/app_text_en.dart`, `app_text_ml.dart` (after `resultsBoardTeaseHint`)
- Modify: `lib/core/strings/app_strings.dart` (Results block)
- Test: `test/core/strings/app_text_test.dart`

- [ ] **Step 1: Add the sample entries to the strings test (fails: members missing)**

In `_members`, after `'resultsBoardTeaseHint'`:

```dart
  'resultsRankOfToday': (t) => t.resultsRankOfToday(18),
  'resultsRankSemantics': (t) => t.resultsRankSemantics(14, 18),
  'resultsHintTimeTile': (t) => t.resultsHintTimeTile(20),
  'resultsFromHints': (t) => t.resultsFromHints,
  'resultsBoardTab': (t) => t.resultsBoardTab,
  'resultsWordsTab': (t) => t.resultsWordsTab(5),
```

The first test compares `_members.keys` with the declared names, so the capped variant gets its own test instead of a `_members` entry:

```dart
  test('a capped board reads "+" after the total', () {
    expect(en.resultsRankOfToday(50, capped: true), 'of 50+ today');
    expect(ml.resultsRankOfToday(50, capped: true), contains('50+'));
  });
```

Add `'resultsHintTimeTile',` to `_sameInEveryLanguage`, because "+20s" reads the same in both languages, as `resultsHintPenalty`'s number does.

- [ ] **Step 2: Run, expect a compile failure**

Run: `flutter test test/core/strings/app_text_test.dart`
Expected: FAIL, "The method 'resultsRankOfToday' isn't defined".

- [ ] **Step 3: Declare and implement**

`app_text.dart`, after `String get resultsBoardTeaseHint;`:

```dart
  /// "of 18 today" under the rank on Results; "of 50+ today" when the board
  /// filled its row limit.
  String resultsRankOfToday(int total, {bool capped = false});

  /// "Rank 14 of 18 today", read for the rank badge.
  String resultsRankSemantics(int rank, int total, {bool capped = false});

  /// "+20s", the time hints added, on a Results tile.
  String resultsHintTimeTile(int seconds);

  /// "from hints", under [resultsHintTimeTile].
  String get resultsFromHints;

  /// The two sides of the Board | Words switch on a Path Words result.
  String get resultsBoardTab;
  String resultsWordsTab(int count);
```

`app_text_en.dart`, after `resultsBoardTeaseHint`:

```dart
  @override
  String resultsRankOfToday(int total, {bool capped = false}) =>
      'of $total${capped ? '+' : ''} today';

  @override
  String resultsRankSemantics(int rank, int total, {bool capped = false}) =>
      'Rank $rank of $total${capped ? '+' : ''} today';

  @override
  String resultsHintTimeTile(int seconds) => '+${seconds}s';

  @override
  String get resultsFromHints => 'from hints';

  @override
  String get resultsBoardTab => 'Board';

  @override
  String resultsWordsTab(int count) => 'Words · $count';
```

`app_text_ml.dart`, after `resultsBoardTeaseHint` (first pass, for native review):

```dart
  @override
  String resultsRankOfToday(int total, {bool capped = false}) =>
      'ഇന്ന് $total${capped ? '+' : ''} പേരിൽ';

  @override
  String resultsRankSemantics(int rank, int total, {bool capped = false}) =>
      'ഇന്ന് $total${capped ? '+' : ''} പേരിൽ $rank-ാം സ്ഥാനം';

  @override
  String resultsHintTimeTile(int seconds) => '+${seconds}s';

  @override
  String get resultsFromHints => 'സൂചനകളിൽ നിന്ന്';

  @override
  String get resultsBoardTab => 'ബോർഡ്';

  @override
  String resultsWordsTab(int count) => 'വാക്കുകൾ · $count';
```

`app_strings.dart`, after `resultsBoardTeaseHint`:

```dart
  static String resultsRankOfToday(int total, {bool capped = false}) =>
      _t.resultsRankOfToday(total, capped: capped);
  static String resultsRankSemantics(
    int rank,
    int total, {
    bool capped = false,
  }) => _t.resultsRankSemantics(rank, total, capped: capped);
  static String resultsHintTimeTile(int seconds) =>
      _t.resultsHintTimeTile(seconds);
  static String get resultsFromHints => _t.resultsFromHints;
  static String get resultsBoardTab => _t.resultsBoardTab;
  static String resultsWordsTab(int count) => _t.resultsWordsTab(count);
```

`leaderboard_period.dart`, end of file:

```dart
/// The most rows a daily board query returns; a board this long may have
/// more players than it shows.
const int leaderboardDailyLimit = 50;
```

`leaderboard_repository_impl.dart`: `.limit(50)` becomes `.limit(leaderboardDailyLimit)`. The file already imports `leaderboard_period.dart`; check that it does.

- [ ] **Step 4: Run, expect PASS**

Run: `flutter test test/core/strings/app_text_test.dart test/data/repositories/leaderboard_repository_impl_test.dart`
Expected: the strings tests pass. `leaderboard_repository_impl_test` has failures already on master (see the podium memory), so compare its counts with a run before this change rather than expecting it to pass.

- [ ] **Step 5: Commit**

```bash
git add lib/core/strings lib/domain/entities/leaderboard_period.dart lib/data/repositories/leaderboard_repository_impl.dart test/core/strings/app_text_test.dart
git commit -m "feat(results): strings for the rank badge, hint tile and Board | Words switch"
```

---

### Task 2: Tile rules

**Files:**
- Create: `lib/features/results/logic/result_tiles.dart`
- Test: `test/features/results/logic/result_tiles_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/features/results/logic/result_tiles.dart';

void main() {
  test('streak, best and hint time, in that order', () {
    final tiles = resultTilesFor(
      gameId: GameIds.zip,
      improved: true,
      currentStreak: 6,
      longestStreak: 11,
      usedHints: true,
      hintPenaltySeconds: 20,
    );
    expect(tiles, [
      isA<StreakTile>()
          .having((t) => t.days, 'days', 6)
          .having((t) => t.longest, 'longest', 11),
      isA<PersonalBestTile>(),
      isA<HintTimeTile>().having((t) => t.seconds, 'seconds', 20),
    ]);
  });

  test('the longest streak shows only when it beats the current one', () {
    final tiles = resultTilesFor(
      gameId: GameIds.zip,
      improved: false,
      currentStreak: 11,
      longestStreak: 11,
    );
    expect(tiles.single, isA<StreakTile>().having((t) => t.longest, 'l', null));
  });

  test('no hints is hint-free; Sudoku without mistakes too is flawless', () {
    expect(
      resultTilesFor(gameId: GameIds.zip, improved: false, usedHints: false),
      [isA<HintFreeTile>()],
    );
    expect(
      resultTilesFor(
        gameId: GameIds.sudoku,
        improved: false,
        usedHints: false,
        hadMistakes: false,
      ),
      [isA<FlawlessTile>()],
    );
    expect(
      resultTilesFor(
        gameId: GameIds.sudoku,
        improved: false,
        usedHints: false,
        hadMistakes: true,
      ),
      [isA<HintFreeTile>()],
    );
  });

  test('unknown hint use earns no clean-run tile', () {
    expect(resultTilesFor(gameId: GameIds.zip, improved: false), isEmpty);
  });

  test('Path Words bonus words fill a free slot', () {
    expect(
      resultTilesFor(
        gameId: GameIds.pathWords,
        improved: false,
        currentStreak: 6,
        usedHints: false,
        bonusWords: 2,
      ),
      [
        isA<StreakTile>(),
        isA<HintFreeTile>(),
        isA<BonusWordsTile>().having((t) => t.count, 'count', 2),
      ],
    );
  });

  test('at most three, and hint time is never the one dropped', () {
    final tiles = resultTilesFor(
      gameId: GameIds.pathWords,
      improved: true,
      currentStreak: 3,
      usedHints: true,
      hintPenaltySeconds: 10,
      bonusWords: 4,
    );
    expect(tiles, hasLength(resultTilesMax));
    expect(tiles.last, isA<HintTimeTile>());
    expect(tiles.whereType<BonusWordsTile>(), isEmpty);
  });

  test('bonus words only count for Path Words', () {
    expect(
      resultTilesFor(gameId: GameIds.zip, improved: false, bonusWords: 3),
      isEmpty,
    );
  });
}
```

- [ ] **Step 2: Run, expect FAIL** (the file doesn't exist yet)

Run: `flutter test test/features/results/logic/result_tiles_test.dart`

- [ ] **Step 3: Implement**

```dart
import '../../../domain/game_ids.dart';

/// One stat tile under a daily result's time.
sealed class ResultTile {
  const ResultTile();
}

/// "6-day streak", with the longest streak when it's longer.
final class StreakTile extends ResultTile {
  const StreakTile({required this.days, this.longest});

  final int days;
  final int? longest;
}

final class PersonalBestTile extends ResultTile {
  const PersonalBestTile();
}

/// The seconds hints added to the time, so it doesn't read as a slow solve.
final class HintTimeTile extends ResultTile {
  const HintTimeTile(this.seconds);

  final int seconds;
}

final class HintFreeTile extends ResultTile {
  const HintFreeTile();
}

/// Sudoku with no hints and no mistakes.
final class FlawlessTile extends ResultTile {
  const FlawlessTile();
}

/// Path Words' bonus words found beyond the list.
final class BonusWordsTile extends ResultTile {
  const BonusWordsTile(this.count);

  final int count;
}

/// The most tiles a result shows.
const int resultTilesMax = 3;

/// The tiles for a daily clear, in order: the streak, a new best, one
/// clean-run tile, then Path Words' bonus words, keeping the first
/// [resultTilesMax]. Only what's true shows; unknown (null) facts show
/// nothing. Hint time sits before the bonus words, so a time that hints
/// pushed up is always explained.
List<ResultTile> resultTilesFor({
  required String gameId,
  required bool improved,
  int? currentStreak,
  int? longestStreak,
  bool? usedHints,
  bool? hadMistakes,
  int hintPenaltySeconds = 0,
  int bonusWords = 0,
}) {
  final streak = currentStreak ?? 0;
  final longest = longestStreak;
  final tiles = <ResultTile>[
    if (streak > 0)
      StreakTile(
        days: streak,
        longest: longest != null && longest > streak ? longest : null,
      ),
    if (improved) const PersonalBestTile(),
    if (hintPenaltySeconds > 0)
      HintTimeTile(hintPenaltySeconds)
    else if (gameId == GameIds.sudoku &&
        usedHints == false &&
        hadMistakes == false)
      const FlawlessTile()
    else if (usedHints == false)
      const HintFreeTile(),
    if (gameId == GameIds.pathWords && bonusWords > 0)
      BonusWordsTile(bonusWords),
  ];
  return tiles.take(resultTilesMax).toList();
}
```

- [ ] **Step 4: Run, expect PASS**

- [ ] **Step 5: Commit** with the message `feat(results): rules for the stat tiles under the time`.

---

### Task 3: Fit the mini board to the card's height

**Files:**
- Modify: `lib/features/leaderboard/logic/mini_leaderboard_slice.dart` (append)
- Test: `test/features/leaderboard/logic/mini_leaderboard_slice_test.dart` (append tests inside `main`)

- [ ] **Step 1: Failing tests** (they reuse the file's `e()` and `board()` helpers)

```dart
  List<int?> ranksOf(List<MiniLeaderboardItem> items) => [
    for (final item in items)
      switch (item) {
        MiniLeaderboardEntryItem(:final entry) => entry.rank,
        MiniLeaderboardGap() => null,
      },
  ];

  group('fitLeaderboardForMini', () {
    test('room for everyone shows everyone, no gap', () {
      final items = fitLeaderboardForMini(
        entries: board(6),
        currentUid: 'uid5',
        maxRows: 8,
      );
      expect(ranksOf(items), [1, 2, 3, 4, 5, 6]);
    });

    test('mid-board: podium, gap, then neighbours above first', () {
      final items = fitLeaderboardForMini(
        entries: board(18),
        currentUid: 'uid14',
        maxRows: 8,
      );
      // 3 podium + you + 4 neighbours: 12, 13 above; 15, 16 below.
      expect(ranksOf(items), [1, 2, 3, null, 12, 13, 14, 15, 16]);
    });

    test('an odd slot goes above', () {
      final items = fitLeaderboardForMini(
        entries: board(18),
        currentUid: 'uid14',
        maxRows: 7,
      );
      expect(ranksOf(items), [1, 2, 3, null, 12, 13, 14, 15]);
    });

    test('last place takes every slot above', () {
      final items = fitLeaderboardForMini(
        entries: board(18),
        currentUid: 'uid18',
        maxRows: 6,
      );
      expect(ranksOf(items), [1, 2, 3, null, 16, 17, 18]);
    });

    test('next to the podium there is no gap', () {
      final items = fitLeaderboardForMini(
        entries: board(18),
        currentUid: 'uid5',
        maxRows: 7,
      );
      expect(ranksOf(items), [1, 2, 3, 4, 5, 6, 7]);
    });

    test('on the podium, or off the board: the top rows', () {
      expect(
        ranksOf(
          fitLeaderboardForMini(
            entries: board(18),
            currentUid: 'uid2',
            maxRows: 5,
          ),
        ),
        [1, 2, 3, 4, 5],
      );
      expect(
        ranksOf(
          fitLeaderboardForMini(
            entries: board(18),
            currentUid: 'missing',
            maxRows: 5,
          ),
        ),
        [1, 2, 3, 4, 5],
      );
    });

    test('too little room still keeps the podium and you', () {
      final items = fitLeaderboardForMini(
        entries: board(18),
        currentUid: 'uid14',
        maxRows: 2,
      );
      expect(ranksOf(items), [1, 2, 3, null, 14]);
    });

    test('an empty board has no rows', () {
      expect(
        fitLeaderboardForMini(entries: const [], currentUid: 'x', maxRows: 5),
        isEmpty,
      );
    });
  });
```

- [ ] **Step 2: Run, expect FAIL** (`fitLeaderboardForMini` isn't defined)

Run: `flutter test test/features/leaderboard/logic/mini_leaderboard_slice_test.dart`

- [ ] **Step 3: Implement** (append; add `import 'board_layout.dart';` at the top for `leaderboardPodiumSize`)

```dart
/// The mini board's rows when its card has room for [maxRows] entry rows.
/// It always shows the podium and the current player; the other rows go to
/// the player's neighbours, alternating above (the players to catch) and
/// below, starting above. A player on the podium or off the board gets the
/// top rows instead. A gap marks each jump in the board.
List<MiniLeaderboardItem> fitLeaderboardForMini({
  required List<LeaderboardEntry> entries,
  required String? currentUid,
  required int maxRows,
}) {
  if (entries.isEmpty) return const [];
  final podium = entries.length < leaderboardPodiumSize
      ? entries.length
      : leaderboardPodiumSize;
  final me = currentUid == null
      ? -1
      : entries.indexWhere((e) => e.uid == currentUid);
  final keep = <int>{for (var i = 0; i < podium; i++) i, if (me >= 0) me};

  final candidates = <int>[];
  if (me < podium) {
    for (var i = podium; i < entries.length; i++) {
      candidates.add(i);
    }
  } else {
    for (var d = 1; d < entries.length; d++) {
      if (me - d >= podium) candidates.add(me - d);
      if (me + d < entries.length) candidates.add(me + d);
    }
  }
  for (final i in candidates) {
    if (keep.length >= maxRows) break;
    keep.add(i);
  }

  final sorted = keep.toList()..sort();
  final items = <MiniLeaderboardItem>[];
  int? previous;
  for (final i in sorted) {
    if (previous != null && i > previous + 1) {
      items.add(const MiniLeaderboardGap());
    }
    items.add(MiniLeaderboardEntryItem(entries[i]));
    previous = i;
  }
  return items;
}
```

- [ ] **Step 4: Run, expect PASS**

- [ ] **Step 5: Commit** with the message `feat(leaderboard): fit the mini board's rows to its height`.

---

### Task 4: Medals on table rows (opt-in)

**Files:**
- Modify: `lib/features/leaderboard/view/widgets/leaderboard_table.dart` (`LeaderboardTableRow`)
- Test: `test/features/leaderboard/view/leaderboard_table_test.dart` (create it if missing, or add to the existing table-row test file)

- [ ] **Step 1: Failing test**

```dart
  testWidgets('showMedals draws a medal for the top three, numbers after', (
    tester,
  ) async {
    Future<void> pumpRow(int rank) => tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: LeaderboardTableRow(
            entry: LeaderboardEntry(
              uid: 'u$rank',
              displayName: 'P$rank',
              timeSeconds: 40 + rank,
              updatedAt: DateTime.utc(2026, 10, 21),
              rank: rank,
            ),
            period: LeaderboardPeriod.daily,
            gameId: GameIds.zip,
            isYou: false,
            showMedals: true,
          ),
        ),
      ),
    );
    await pumpRow(2);
    expect(find.byType(MedalCoin), findsOneWidget);
    await pumpRow(4);
    expect(find.byType(MedalCoin), findsNothing);
    expect(find.text('4'), findsOneWidget);
  });
```

- [ ] **Step 2: Run, expect FAIL** (no named parameter `showMedals`)

- [ ] **Step 3: Implement**
  - Constructor: add `this.showMedals = false,` and the field `final bool showMedals;` with the doc comment `/// A medal instead of the number for ranks 1–3 (the Results mini board; the tab's podium shows them otherwise).`
  - In `_rank`:

```dart
  Widget _rank(BuildContext context) {
    final rank = entry.rank;
    if (showMedals && rank >= 1 && rank <= leaderboardPodiumSize) {
      return MedalCoin(rank: rank, size: 22);
    }
    return Text(
      '$rank',
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: isYou ? ZipColors.ember : ZipColors.inkSoft,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
```

Import `medal_coin.dart`. The file already imports `board_layout.dart`.

- [ ] **Step 4: Run, expect PASS.** Also run `flutter test test/features/leaderboard`, which should show no new failures.
- [ ] **Step 5: Commit** with the message `feat(leaderboard): opt-in medals on table rows`.

---

### Task 5: Top bar, hero and rank badge, tiles row

**Files:**
- Create: `lib/features/results/view/results_top_bar.dart`, `results_hero.dart`, `result_tiles_row.dart`
- Modify: `lib/features/results/view/results_actions.dart`: make `_titleFor`/`_routeFor` public statics `titleFor`/`routeFor` (rename call sites)
- Test: `test/features/results/results_pieces_test.dart` (new)

- [ ] **Step 1: Failing widget tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/features/results/logic/result_tiles.dart';
import 'package:winklo/features/results/view/result_tiles_row.dart';
import 'package:winklo/features/results/view/results_hero.dart';
import 'package:winklo/features/results/view/results_top_bar.dart';

Widget _app(Widget child) => MaterialApp(
  theme: buildAppTheme(),
  home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
);

void main() {
  testWidgets('the top bar names the game and counts down', (tester) async {
    await tester.pumpWidget(
      _app(ResultsTopBar(gameId: GameIds.pathWords, day: DateTime.now())),
    );
    expect(find.text(AppStrings.pathWordsTitle), findsOneWidget);
    expect(find.textContaining('New puzzle in'), findsOneWidget);
  });

  testWidgets('the rank badge reads its rank and total', (tester) async {
    await tester.pumpWidget(
      _app(const ResultsRankBadge(rank: 14, total: 18)),
    );
    expect(find.text('#14'), findsOneWidget);
    expect(find.text(AppStrings.resultsRankOfToday(18)), findsOneWidget);
    expect(
      find.bySemanticsLabel(AppStrings.resultsRankSemantics(14, 18)),
      findsOneWidget,
    );
  });

  testWidgets('a loading badge is an empty outline', (tester) async {
    await tester.pumpWidget(_app(const ResultsRankBadge()));
    expect(find.textContaining('#'), findsNothing);
  });

  testWidgets('the hero lands on the time', (tester) async {
    await tester.pumpWidget(
      _app(const ResultsHero(title: 'Puzzle cleared!', timeSeconds: 107)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Puzzle cleared!'), findsOneWidget);
    expect(find.text(AppStrings.formatPlayTime(107)), findsOneWidget);
  });

  testWidgets('tiles show their titles and captions', (tester) async {
    await tester.pumpWidget(
      _app(
        const ResultTilesRow(
          tiles: [
            StreakTile(days: 6, longest: 11),
            PersonalBestTile(),
            HintTimeTile(20),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.streakLabel(6)), findsOneWidget);
    expect(find.text(AppStrings.longestStreakLabel(11)), findsOneWidget);
    expect(find.text(AppStrings.newPersonalBest), findsOneWidget);
    expect(find.text(AppStrings.resultsHintTimeTile(20)), findsOneWidget);
    expect(find.text(AppStrings.resultsFromHints), findsOneWidget);
  });

  testWidgets('no tiles, no row', (tester) async {
    await tester.pumpWidget(_app(const ResultTilesRow(tiles: [])));
    expect(find.byType(Row), findsNothing);
  });
}
```

- [ ] **Step 2: Run, expect FAIL** (the files don't exist)

- [ ] **Step 3: Implement `results_top_bar.dart`**

```dart
import 'package:flutter/material.dart';

import '../../../core/dev_flags.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/next_puzzle_countdown.dart';
import '../../../domain/game_ids.dart';
import '../../../domain/play_period.dart';
import 'results_actions.dart';

/// The top of a daily result: which game, and when the next puzzle opens.
class ResultsTopBar extends StatelessWidget {
  const ResultsTopBar({super.key, required this.gameId, this.day});

  final String gameId;

  /// The run's day, so a run finished after midnight says the next puzzle
  /// is already out.
  final DateTime? day;

  static (IconData, Color) _iconFor(String gameId) => switch (gameId) {
    GameIds.pathWords => (AppIcons.path, ZipColors.sky),
    GameIds.sudoku => (AppIcons.grid, ZipColors.number),
    _ => (AppIcons.lightning, ZipColors.ember),
  };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (icon, color) = _iconFor(gameId);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: ZipColors.inkSoft.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: ZipColors.inkSoft.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                ResultsActions.titleFor(gameId),
                style: textTheme.labelLarge?.copyWith(
                  color: ZipColors.onInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: _NextPuzzleLine(day: day)),
      ],
    );
  }
}

/// "New puzzle in 6h 12m", at the bar's end.
class _NextPuzzleLine extends StatelessWidget {
  const _NextPuzzleLine({this.day});

  final DateTime? day;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: ZipColors.inkSoft,
      fontWeight: FontWeight.w600,
    );
    final period = DevFlags.playPeriod;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        AppIcon(AppIcons.clock, size: 14, color: style?.color),
        const SizedBox(width: 5),
        Flexible(
          child: NextPuzzleCountdown(
            period: period,
            // The run's day is a date, which can't place a minute-long
            // debug period.
            periodOf: PlayPeriod.isSubDaily(period) ? null : day,
            style: style,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Implement `results_hero.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/haptics/haptics_service.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import 'counting_play_time.dart';
import 'ember_burst.dart';

/// "Puzzle cleared!" over the counting time, and the rank badge beside it.
class ResultsHero extends StatefulWidget {
  const ResultsHero({
    super.key,
    required this.title,
    required this.timeSeconds,
    this.rankBadge,
    this.compact = false,
  });

  final String title;
  final int timeSeconds;

  /// Usually a live [ResultsRankBadge]; null for none (guests).
  final Widget? rankBadge;
  final bool compact;

  @override
  State<ResultsHero> createState() => _ResultsHeroState();
}

class _ResultsHeroState extends State<ResultsHero> {
  var _showBurst = false;

  void _landed() {
    if (!mounted || _showBurst) return;
    context.read<HapticsService?>()?.play(HapticKind.light);
    setState(() => _showBurst = true);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final timeStyle = textTheme.displayLarge?.copyWith(
      color: ZipColors.ember,
      fontWeight: FontWeight.w900,
      letterSpacing: -2,
      height: 1,
      fontSize: widget.compact ? 48 : 56,
      shadows: [
        Shadow(
          color: ZipColors.emberGlow.withValues(alpha: 0.75),
          blurRadius: 32,
        ),
        Shadow(color: ZipColors.ember.withValues(alpha: 0.35), blurRadius: 16),
      ],
    );
    final badge = widget.rankBadge;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall?.copyWith(
                  color: ZipColors.inkSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (_showBurst) const Positioned.fill(child: EmberBurst()),
                    CountingPlayTime(
                      timeSeconds: widget.timeSeconds,
                      style: timeStyle,
                      textAlign: TextAlign.start,
                      onCompleted: _landed,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ?badge,
      ],
    );
  }
}

/// "#14 / of 18 today" in an ember square; an empty outline while [rank] is
/// null (the board is loading).
class ResultsRankBadge extends StatelessWidget {
  const ResultsRankBadge({
    super.key,
    this.rank,
    this.total = 0,
    this.capped = false,
    this.compact = false,
  });

  final int? rank;
  final int total;

  /// The board filled its row limit, so "of 50+".
  final bool capped;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final size = compact ? 68.0 : 76.0;
    final rank = this.rank;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: ZipColors.ember.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ZipColors.ember.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: rank == null
          ? null
          : Semantics(
              label: AppStrings.resultsRankSemantics(
                rank,
                total,
                capped: capped,
              ),
              excludeSemantics: true,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '#$rank',
                      style: textTheme.headlineSmall?.copyWith(
                        color: ZipColors.ember,
                        fontWeight: FontWeight.w900,
                        fontSize: compact ? 22 : 24,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      AppStrings.resultsRankOfToday(total, capped: capped),
                      style: textTheme.labelSmall?.copyWith(
                        color: ZipColors.inkSoft,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
```

- [ ] **Step 5: Implement `result_tiles_row.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_icon.dart';
import '../logic/result_tiles.dart';

/// Up to three equal tiles under the time; nothing when [tiles] is empty.
class ResultTilesRow extends StatelessWidget {
  const ResultTilesRow({super.key, required this.tiles, this.compact = false});

  final List<ResultTile> tiles;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: _Tile(tile: tiles[i], compact: compact)
                  .animate()
                  .fadeIn(delay: (520 + 60 * i).ms, duration: 350.ms)
                  .scale(
                    begin: const Offset(0.86, 0.86),
                    curve: Curves.easeOutBack,
                    duration: 420.ms,
                    delay: (520 + 60 * i).ms,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.tile, required this.compact});

  final ResultTile tile;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (icon, color, title, caption) = switch (tile) {
      StreakTile(:final days, :final longest) => (
        AppIcons.streak,
        ZipColors.ember,
        AppStrings.streakLabel(days),
        longest == null ? null : AppStrings.longestStreakLabel(longest),
      ),
      PersonalBestTile() => (
        AppIcons.star,
        ZipColors.success,
        AppStrings.newPersonalBest,
        null,
      ),
      HintTimeTile(:final seconds) => (
        AppIcons.hint,
        ZipColors.onInk.withValues(alpha: 0.8),
        AppStrings.resultsHintTimeTile(seconds),
        AppStrings.resultsFromHints,
      ),
      HintFreeTile() => (
        AppIcons.noHints,
        ZipColors.teal,
        AppStrings.statsHintFree,
        null,
      ),
      FlawlessTile() => (
        AppIcons.flawless,
        ZipColors.sky,
        AppStrings.leaderboardNoMistakesChip,
        null,
      ),
      BonusWordsTile(:final count) => (
        AppIcons.sparkle,
        ZipColors.sky,
        AppStrings.pathWordsBonusCount(count),
        null,
      ),
    };
    return MergeSemantics(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: compact ? 6 : 8, horizontal: 6),
        decoration: BoxDecoration(
          color: ZipColors.inkSoft.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ZipColors.inkSoft.withValues(alpha: 0.16)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon(icon, size: compact ? 16 : 18, color: color),
            const SizedBox(height: 3),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelLarge?.copyWith(
                color: ZipColors.onInk,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                height: 1.2,
              ),
            ),
            if (caption != null)
              Text(
                caption,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(
                  color: ZipColors.inkSoft,
                  fontSize: 10,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

Check `AppStrings.leaderboardNoMistakesChip` exists (the podium branch has it in the en table). Also check `pathWordsBonusCount`.

- [ ] **Step 6: Rename the helpers in `results_actions.dart`:** `_routeFor` becomes `static String routeFor(String gameId)` and `_titleFor` becomes `static String titleFor(String gameId)`. Update their uses.

- [ ] **Step 7: Run, expect PASS:** `flutter test test/features/results/results_pieces_test.dart`
- [ ] **Step 8: Commit** with the message `feat(results): top bar, hero with rank badge, and stat tiles`.

---

### Task 6: Board card with the Board | Words switch, framed-less tease

**Files:**
- Create: `lib/features/results/view/results_board_card.dart`
- Modify: `lib/features/results/view/results_board_tease.dart`
- Test: `test/features/results/results_pieces_test.dart` (append)

- [ ] **Step 1: Failing tests** (append to `main`; add imports for `PathWordsClearSummary` and `ResultsBoardCard`)

```dart
  testWidgets('Path Words cards switch between the board and the words', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const SizedBox(
          height: 400,
          child: ResultsBoardCard(
            board: Text('the board'),
            pathWords: PathWordsClearSummary(
              theme: 'Kitchen tools',
              words: ['ladle', 'kettle'],
              bonusWords: ['tale'],
            ),
          ),
        ),
      ),
    );
    expect(find.text('the board'), findsOneWidget);
    expect(find.text('LADLE'), findsNothing);

    await tester.tap(find.text(AppStrings.resultsWordsTab(2)));
    await tester.pumpAndSettle();
    expect(find.text('the board'), findsNothing);
    expect(find.text('LADLE'), findsOneWidget);
    expect(find.text(AppStrings.pathWordsBonusCount(1)), findsOneWidget);

    await tester.tap(find.text(AppStrings.resultsBoardTab));
    await tester.pumpAndSettle();
    expect(find.text('the board'), findsOneWidget);
  });

  testWidgets('other games get no switch', (tester) async {
    await tester.pumpWidget(
      _app(
        const SizedBox(
          height: 300,
          child: ResultsBoardCard(board: Text('the board')),
        ),
      ),
    );
    expect(find.text(AppStrings.resultsBoardTab), findsNothing);
  });
```

- [ ] **Step 2: Run, expect FAIL**

- [ ] **Step 3: Implement `results_board_card.dart`**

```dart
import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../domain/entities/path_words_clear_summary.dart';
import '../../leaderboard/view/widgets/leaderboard_table.dart';
import '../../path_words/view/widgets/path_words_results_panel.dart';

/// The Board | Words switch's height, margins included.
const double resultsBoardSwitchHeight = 46;

/// The card under the tiles: the day's board, and for Path Words a switch
/// to the words found.
class ResultsBoardCard extends StatefulWidget {
  const ResultsBoardCard({super.key, required this.board, this.pathWords});

  /// The mini table, or the guest's tease.
  final Widget board;

  /// Path Words only: shows the switch and the Words side.
  final PathWordsClearSummary? pathWords;

  @override
  State<ResultsBoardCard> createState() => _ResultsBoardCardState();
}

class _ResultsBoardCardState extends State<ResultsBoardCard> {
  // View-only: which side of the switch is showing.
  var _showWords = false;

  @override
  Widget build(BuildContext context) {
    final words = widget.pathWords;
    return DecoratedBox(
      decoration: leaderboardTableDecoration(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (words != null)
              _BoardWordsSwitch(
                showWords: _showWords,
                wordCount: words.words.length,
                onChanged: (value) => setState(() => _showWords = value),
              ),
            Expanded(
              child: IndexedStack(
                index: _showWords && words != null ? 1 : 0,
                sizing: StackFit.expand,
                children: [
                  widget.board,
                  if (words != null) _WordsSide(summary: words),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardWordsSwitch extends StatelessWidget {
  const _BoardWordsSwitch({
    required this.showWords,
    required this.wordCount,
    required this.onChanged,
  });

  final bool showWords;
  final int wordCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: resultsBoardSwitchHeight - 12,
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: ZipColors.ink.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Segment(
              key: const Key('resultsBoardTab'),
              icon: AppIcons.ranking,
              label: AppStrings.resultsBoardTab,
              selected: !showWords,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _Segment(
              key: const Key('resultsWordsTab'),
              icon: AppIcons.textAa,
              label: AppStrings.resultsWordsTab(wordCount),
              selected: showWords,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? ZipColors.onInk : ZipColors.inkSoft;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? ZipColors.mistDeep : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WordsSide extends StatelessWidget {
  const _WordsSide({required this.summary});

  final PathWordsClearSummary summary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - 22).clamp(0, double.infinity),
          ),
          child: Center(child: PathWordsResultsPanel(summary: summary)),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: `ResultsBoardTease` gains `framed`**
  - Constructor: add `this.framed = true`, and the field `/// False inside a card that draws its own frame.` `final bool framed;`.
  - In `build`, the `Ink` decoration becomes `framed ? BoxDecoration(<today's>) : null`. The border radius on `InkWell`/`ClipRRect` stays.
  - The mock gets `rowCount: 5` when not framed, and is wrapped in `OverflowBox(alignment: Alignment.topCenter, maxHeight: double.infinity, child: …)`. A short card then clips the blurred rows instead of overflowing. Keep `rowCount: 3` when framed.

- [ ] **Step 5: Run, expect PASS.** Commit with the message `feat(results): board card with a Board | Words switch for Path Words`.

---

### Task 7: Mini table body

**Files:**
- Rewrite: `lib/features/results/view/mini_leaderboard_panel.dart`
- Test: `test/features/results/results_screen_test.dart` ("MiniLeaderboardPanel lists entries when signed in")

- [ ] **Step 1: Update the panel test** (red first)

In 'MiniLeaderboardPanel lists entries when signed in', replace the footer expectations:

```dart
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text(AppStrings.seeFullLeaderboard), findsNothing);
    expect(find.byType(LeaderboardTableRow), findsWidgets);
```

Also wrap the panel in that test in `SizedBox(height: 400, …)`, because the panel no longer has its own `Column` with a title.

- [ ] **Step 2: Rewrite the panel**

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/centered_message_body.dart';
import '../../../domain/entities/leaderboard_entry.dart';
import '../../../domain/entities/leaderboard_period.dart';
import '../../../domain/entities/leaderboard_proof.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/usecases/submit_leaderboard_time.dart';
import '../../../domain/usecases/watch_leaderboard.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/view/sign_in_sheet.dart';
import '../../leaderboard/cubit/leaderboard_cubit.dart';
import '../../leaderboard/cubit/leaderboard_state.dart';
import '../../leaderboard/logic/board_layout.dart';
import '../../leaderboard/logic/mini_leaderboard_slice.dart';
import '../../leaderboard/view/widgets/leaderboard_table.dart';
import '../../leaderboard/view/widgets/player_card_sheet.dart';

/// The "···" row between the podium and the player's part of the board.
const double miniLeaderboardGapRowHeight = 20;

/// The day's board on Results: the podium, the player and their neighbours,
/// as many as fit the height it's given.
class MiniLeaderboardPanel extends StatelessWidget {
  const MiniLeaderboardPanel({
    super.key,
    required this.gameId,
    this.cubit,
    this.timeSeconds = 0,
    this.usedHints,
    this.hadMistakes,
    this.currentStreak,
    this.dayId,
    this.leaderboardProof,
  });

  final String gameId;

  /// The board the Results screen already watches (its rank badge reads it
  /// too); null makes one here.
  final LeaderboardCubit? cubit;
  final int timeSeconds;
  final bool? usedHints;
  final bool? hadMistakes;
  final int? currentStreak;

  /// The cleared day's board (`yyyy-MM-dd`) and the run's proof, for a
  /// guest who signs in here to save the time.
  final String? dayId;
  final LeaderboardProof? leaderboardProof;

  @override
  Widget build(BuildContext context) {
    final body = _MiniLeaderboardBody(
      gameId: gameId,
      timeSeconds: timeSeconds,
      usedHints: usedHints,
      hadMistakes: hadMistakes,
      currentStreak: currentStreak,
      dayId: dayId,
      leaderboardProof: leaderboardProof,
    );
    final existing = cubit;
    if (existing != null) {
      return BlocProvider.value(value: existing, child: body);
    }
    return BlocProvider(
      create: (context) => LeaderboardCubit(
        watchLeaderboard: context.read<WatchLeaderboard>(),
        authRepository: context.read<AuthRepository>(),
        initialGameId: gameId,
      )..selectDay(dayId),
      child: body,
    );
  }
}

class _MiniLeaderboardBody extends StatelessWidget {
  const _MiniLeaderboardBody({
    required this.gameId,
    required this.timeSeconds,
    this.usedHints,
    this.hadMistakes,
    this.currentStreak,
    this.dayId,
    this.leaderboardProof,
  });

  final String gameId;
  final int timeSeconds;
  final bool? usedHints;
  final bool? hadMistakes;
  final int? currentStreak;
  final String? dayId;
  final LeaderboardProof? leaderboardProof;

  Future<void> _signInAndSync(BuildContext context) async {
    final ok = await showSignInSheet(context);
    if (!ok || !context.mounted) return;
    if (timeSeconds <= 0) return;
    try {
      await context.read<SubmitLeaderboardTime>()(
        gameId: gameId,
        timeSeconds: timeSeconds,
        usedHints: usedHints ?? true,
        hadMistakes: hadMistakes ?? true,
        currentStreak: currentStreak ?? 0,
        dayId: dayId,
        proof: leaderboardProof,
      );
    } catch (_) {
      // Best-effort remote sync; signed-in UI still shows live board.
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LeaderboardCubit, LeaderboardState>(
      builder: (context, state) {
        final signedIn = context.watch<AuthCubit>().isSignedIn;
        if (!signedIn) {
          return CenteredMessageBody(
            message: AppStrings.leaderboardSignInHint,
            actionLabel: AppStrings.signInWithGoogle,
            onAction: () => _signInAndSync(context),
          );
        }
        switch (state.status) {
          case LeaderboardStatus.loading:
            return const Center(child: CircularProgressIndicator());
          case LeaderboardStatus.failure:
            return CenteredMessageBody(
              message: AppStrings.leaderboardFailed,
              actionLabel: AppStrings.retry,
              onAction: () => context.read<LeaderboardCubit>().retry(),
            );
          case LeaderboardStatus.ready:
            if (state.entries.isEmpty) {
              return CenteredMessageBody(message: AppStrings.leaderboardEmpty);
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                final rows =
                    ((constraints.maxHeight - miniLeaderboardGapRowHeight) /
                            leaderboardTableRowHeight)
                        .floor();
                return _MiniTable(
                  gameId: gameId,
                  entries: state.entries,
                  currentUid: state.currentUid,
                  items: fitLeaderboardForMini(
                    entries: state.entries,
                    currentUid: state.currentUid,
                    maxRows: math.max(1, rows),
                  ),
                );
              },
            );
        }
      },
    );
  }
}

/// The fitted rows. When even the podium and the player don't fit, the
/// list scrolls, and starts with the player's row in view.
class _MiniTable extends StatefulWidget {
  const _MiniTable({
    required this.gameId,
    required this.entries,
    required this.currentUid,
    required this.items,
  });

  final String gameId;
  final List<LeaderboardEntry> entries;
  final String? currentUid;
  final List<MiniLeaderboardItem> items;

  @override
  State<_MiniTable> createState() => _MiniTableState();
}

class _MiniTableState extends State<_MiniTable> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showMe());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _heightOf(MiniLeaderboardItem item) => switch (item) {
    MiniLeaderboardGap() => miniLeaderboardGapRowHeight,
    MiniLeaderboardEntryItem() => leaderboardTableRowHeight,
  };

  void _showMe() {
    if (!mounted || !_controller.hasClients) return;
    final position = _controller.position;
    if (position.maxScrollExtent <= 0) return;
    var top = 0.0;
    for (final item in widget.items) {
      if (item case MiniLeaderboardEntryItem(:final entry)
          when entry.uid == widget.currentUid) {
        final centred =
            top - (position.viewportDimension - leaderboardTableRowHeight) / 2;
        _controller.jumpTo(centred.clamp(0, position.maxScrollExtent));
        return;
      }
      top += _heightOf(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final leader = widget.entries.first;
    return ListView.builder(
      controller: _controller,
      padding: EdgeInsets.zero,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final last = index == items.length - 1;
        return switch (items[index]) {
          MiniLeaderboardGap() => const _GapRow(),
          MiniLeaderboardEntryItem(:final entry) => LeaderboardTableRow(
            entry: entry,
            period: LeaderboardPeriod.daily,
            gameId: widget.gameId,
            isYou: entry.uid == widget.currentUid,
            showMedals: true,
            showDivider: !last,
            gapSeconds: leaderboardGapSeconds(
              entry: entry,
              ahead: leader,
              period: LeaderboardPeriod.daily,
            ),
            onTap: () => showPlayerCardSheet(
              context,
              entry: entry,
              gameId: widget.gameId,
              period: LeaderboardPeriod.daily,
              isYou: entry.uid == widget.currentUid,
            ),
          ),
        };
      },
    );
  }
}

class _GapRow extends StatelessWidget {
  const _GapRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: miniLeaderboardGapRowHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: ZipColors.outlineQuiet.withValues(alpha: 0.22),
          ),
        ),
      ),
      child: Text(
        AppStrings.leaderboardGapEllipsis,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: ZipColors.inkSoft,
          height: 1,
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Run** `flutter test test/features/results/results_screen_test.dart --plain-name "MiniLeaderboardPanel"`. The panel tests are expected to pass. The screen tests still use the old layout until Task 9.
- [ ] **Step 4: Commit** with the message `feat(results): mini board as fitted table rows`.

---

### Task 8: Action bar

**Files:**
- Rewrite: `lib/features/results/view/results_actions.dart` (`build` and helpers; `_share`, `_log` and the static helpers stay)
- Test: `test/features/results/results_actions_test.dart`

- [ ] **Step 1: Update the tests** (red)
  - Full board: `find.text(AppStrings.resultsFullBoard)` becomes `find.byTooltip(AppStrings.resultsFullBoard)`.
  - Share, when a next daily exists: `find.text(AppStrings.shareResult)` becomes `find.byTooltip(AppStrings.shareResult)`.
  - Share on a perfect day is the primary button and keeps `find.text`. Check `nextIs` in each share test; the default in `setUp` is whatever `pumpZipResults` gets.
  - In the perfect-day test, add `expect(find.byType(ZipPrimaryButton), findsOneWidget); expect(find.text(AppStrings.shareResult), findsOneWidget);`.
  - The compact test: height `lessThan(112)` stays true. Add: `expect(find.byTooltip(AppStrings.shareResult), findsOneWidget);`.
  - Add a fit test:

```dart
  testWidgets('a narrow bar names just the next game', (tester) async {
    nextIs(GameIds.pathWords);
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<NextUnclearedDaily>.value(value: next),
          RepositoryProvider<AnalyticsRepository>.value(value: analytics),
          RepositoryProvider<AppReviewRepository>.value(value: review),
          RepositoryProvider<ShareRepository>.value(value: share),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: ResultsActions(
                  args: ResultsArgs(
                    title: 'Puzzle cleared!',
                    subtitle: '',
                    timeSeconds: 72,
                    improved: false,
                    gameId: GameIds.zip,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final primary = tester.widget<ZipPrimaryButton>(
      find.byType(ZipPrimaryButton),
    );
    expect(primary.label, AppStrings.pathWordsTitle);
  });
```

- [ ] **Step 2: Rewrite `build`**

```dart
  @override
  Widget build(BuildContext context) {
    // The game routes open today's puzzle, so ask about today even when the
    // run just cleared was left open over midnight.
    final next = context.read<NextUnclearedDaily>()(
      justCleared: _gameId,
      playId: PlayPeriod.id(DateTime.now(), DevFlags.playPeriod),
    );

    Future<void> openBoard() async {
      await _log(context, 'leaderboard');
      if (!context.mounted) return;
      context.go('/leaderboard?game=$_gameId');
    }

    Future<void> goHome() async {
      await _log(context, 'home');
      if (!context.mounted) return;
      context.go('/');
    }

    final board = ResultsIconAction(
      tooltip: AppStrings.resultsFullBoard,
      icon: AppIcons.ranking,
      onPressed: openBoard,
    );
    final home = ResultsIconAction(
      tooltip: AppStrings.backHome,
      icon: AppIcons.home,
      onPressed: goHome,
    );

    final Widget bar;
    if (next != null) {
      bar = Row(
        children: [
          _OneAtATime(
            onPressed: () => _share(context),
            builder: (onPressed) => ResultsIconAction(
              tooltip: AppStrings.shareResult,
              icon: AppIcons.share,
              onPressed: onPressed,
            ),
          ),
          const SizedBox(width: 8),
          board,
          const SizedBox(width: 8),
          home,
          const SizedBox(width: 8),
          Expanded(
            child: _FittedPrimary(
              label: AppStrings.playNextGame(titleFor(next)),
              shortLabel: titleFor(next),
              icon: AppIcons.play,
              onPressed: () async {
                await _log(context, 'play_next');
                if (!context.mounted) return;
                context.pushReplacement(routeFor(next));
              },
            ),
          ),
        ],
      );
    } else {
      bar = Row(
        children: [
          board,
          const SizedBox(width: 8),
          home,
          const SizedBox(width: 8),
          Expanded(
            child: _OneAtATime(
              onPressed: () => _share(context),
              builder: (onPressed) => ZipPrimaryButton(
                label: AppStrings.shareResult,
                icon: AppIcons.share,
                compact: true,
                onPressed: onPressed,
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (next == null) ...[
          Text(
            AppStrings.perfectDay,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: ZipColors.success,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
        ],
        bar,
      ],
    );
  }
```

Helpers, which replace `_OneAtATimeButton`:

```dart
/// A 46 dp outlined icon button of the Results action bar.
class ResultsIconAction extends StatelessWidget {
  const ResultsIconAction({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  /// The bar's height, and each icon button's side.
  static const double size = 46;

  @override
  Widget build(BuildContext context) {
    return IconButton.outlined(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(size),
        minimumSize: const Size.square(size),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: AppIcon(icon, size: 20),
    );
  }
}

/// Builds a button that ignores taps until its last press finishes, so a
/// double tap can't open the share sheet twice.
class _OneAtATime extends StatefulWidget {
  const _OneAtATime({required this.onPressed, required this.builder});

  final Future<void> Function() onPressed;
  final Widget Function(VoidCallback? onPressed) builder;

  @override
  State<_OneAtATime> createState() => _OneAtATimeState();
}

class _OneAtATimeState extends State<_OneAtATime> {
  var _busy = false;

  Future<void> _press() async {
    setState(() => _busy = true);
    try {
      await widget.onPressed();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(_busy ? null : _press);
}

/// The primary button, with [shortLabel] when [label] won't fit on one line
/// beside the icon buttons ("Play Path Words next" on a 360 dp phone).
class _FittedPrimary extends StatelessWidget {
  const _FittedPrimary({
    required this.label,
    required this.shortLabel,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final String shortLabel;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = AppLayout.of(context);
        final style = (Theme.of(context).textTheme.labelLarge ??
                const TextStyle())
            .copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: 0.2,
            );
        final painter = TextPainter(
          text: TextSpan(text: label, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        // The compact button's padding, icon and gap, plus a hair of slack
        // for its border.
        final room =
            constraints.maxWidth -
            layout.compactButtonPadding.horizontal -
            layout.space(18) -
            layout.space(6) -
            4;
        return ZipPrimaryButton(
          label: painter.width <= room ? label : shortLabel,
          icon: icon,
          compact: true,
          onPressed: onPressed,
        );
      },
    );
  }
}
```

Imports: add `../../../core/theme/app_layout.dart` and `../../../core/widgets/app_icon.dart`. Check that `AppLayout.of` is exported from `app_layout.dart`. Delete the old `_OneAtATimeButton`.

- [ ] **Step 3: Run** `flutter test test/features/results/results_actions_test.dart`, expecting PASS.
- [ ] **Step 4: Commit** with the message `feat(results): one action bar with icon buttons and a fitted primary`.

---

### Task 9: Screen layout

**Files:**
- Modify: `lib/features/results/results_screen.dart`:
  - Replace `_CelebrateAndClaimResults` (its `build` and `_celebrationHeader`).
  - Remove `_NextPuzzleLine` (it moved to the top bar).
  - Keep `_ReviewPromptHost`, the legacy branch and `_ResultsCelebrationCard`.
- Tests: `test/features/results/results_screen_test.dart`, `results_path_words_test.dart`

- [ ] **Step 1: Update the screen tests** (red)
  1. 'Zip clear signed-in…':
     - Remove `expect(find.text(AppStrings.resultsTimeLabel), findsOneWidget)`.
     - `find.text(AppStrings.resultsFullBoard)` and `find.text(AppStrings.shareResult)` become `find.byTooltip(...)`.
     - Add `expect(find.text(AppStrings.newPersonalBest), findsOneWidget)` (already there).
  2. Guest:
     - Remove the `resultsTimeLabel` expectation.
     - `find.text(AppStrings.backHome)` becomes `find.byTooltip(AppStrings.backHome)` for the expectation and for the tap. Drop the `ensureVisible`, since the bar is always in view.
     - Keep `streakLabel(2)`, `saveTimeToBoard`, `ResultsBoardTease` and the hint expectations.
  3. Sideways and split screen: the final share checks use `find.byTooltip(AppStrings.shareResult)` in place of `find.text(...)`.
  4. 'a typical phone shows the whole celebration…' (412×915), rewritten as:

```dart
    expect(find.textContaining('New puzzle in').hitTestable(), findsOneWidget);
    expect(find.text(AppStrings.longestStreakLabel(14)), findsOneWidget);
    expect(find.text(AppStrings.resultsHintTimeTile(30)), findsOneWidget);
    expect(find.text(AppStrings.resultsFromHints), findsOneWidget);
    expect(find.text(AppStrings.resultsHintPenalty(30)), findsNothing);
    expect(find.byTooltip(AppStrings.shareResult).hitTestable(), findsOneWidget);
```

     (Drop the header `SingleChildScrollView` ancestor check, since there's no inner header scroll any more.)
  5. New test, 'the rank badge reads the player's place on the board'. Use the signed-in Zip setup with the board stream adding `[LeaderboardEntry(uid:'p1', rank:1, …), LeaderboardEntry(uid:'u1', rank:2, …)]`, and expect `find.text('#2')` plus `find.text(AppStrings.resultsRankOfToday(2))`. Then, after `boardController.add([only p1])` and `pumpAndSettle`, expect `find.textContaining('#')` to find nothing.
  6. `results_path_words_test.dart`:
     - Before the theme and chip expectations: `await tester.tap(find.byKey(const Key('resultsWordsTab'))); await tester.pumpAndSettle();`.
     - `find.text('3 bonus words')` becomes `findsNWidgets(2)` (the tile plus the panel).
     - 'other games show no Path Words panel' also expects `find.byKey(const Key('resultsWordsTab'))` to find nothing.

- [ ] **Step 2: Replace `_CelebrateAndClaimResults`**

```dart
/// Zip / Path Words / Sudoku: the scoreboard. Guests get the same page with
/// a soft claim in place of the board and no rank.
class _CelebrateAndClaimResults extends StatelessWidget {
  const _CelebrateAndClaimResults({required this.args});

  final ResultsArgs args;

  Future<void> _signInAndSync(BuildContext context) async {
    final ok = await showSignInSheet(
      context,
      title: AppStrings.saveTimeSignInTitle,
      body: AppStrings.saveTimeSignInBody,
    );
    if (!ok || !context.mounted) return;
    if (args.timeSeconds <= 0) return;
    final gameId = args.gameId;
    if (gameId == null || gameId.isEmpty) return;
    try {
      await context.read<SubmitLeaderboardTime>()(
        gameId: gameId,
        timeSeconds: args.timeSeconds,
        usedHints: args.usedHints ?? true,
        hadMistakes: args.hadMistakes ?? true,
        currentStreak: args.currentStreak ?? 0,
        dayId: args.leaderboardDay,
        proof: args.leaderboardProof,
      );
    } catch (_) {
      // Best-effort remote sync; signed-in UI still shows live board.
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = context.watch<AuthCubit>().isSignedIn;
    final gameId = args.gameId!;
    final Widget page = signedIn
        ? BlocProvider(
            create: (context) => LeaderboardCubit(
              watchLeaderboard: context.read<WatchLeaderboard>(),
              authRepository: context.read<AuthRepository>(),
              initialGameId: gameId,
            )..selectDay(args.leaderboardDay),
            child: _Scoreboard(args: args, signedIn: true),
          )
        : _Scoreboard(
            args: args,
            signedIn: false,
            onSave: () => _signInAndSync(context),
          );
    return _ReviewPromptHost(
      args: args,
      child: Scaffold(
        body: ZipAtmosphere(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: page,
            ),
          ),
        ),
      ),
    );
  }
}

/// The page: top bar, hero, tiles, (new badges), board card, action bar.
/// The card takes what's left; below [_scrollBelow] the whole page scrolls
/// and the card keeps four rows.
class _Scoreboard extends StatelessWidget {
  const _Scoreboard({required this.args, required this.signedIn, this.onSave});

  final ResultsArgs args;
  final bool signedIn;

  /// Guests: sign in and save the time.
  final VoidCallback? onSave;

  /// Shorter than this (sideways, split screen) and the page scrolls.
  static const double _scrollBelow = 560;

  /// Below this height the hero, badge and tiles take a smaller step.
  static const double _compactBelow = 640;

  @override
  Widget build(BuildContext context) {
    final gameId = args.gameId!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final compact = height < _compactBelow;
        final gap = compact ? 8.0 : 12.0;
        final tiles = resultTilesFor(
          gameId: gameId,
          improved: args.improved,
          currentStreak: args.currentStreak,
          longestStreak: args.longestStreak,
          usedHints: args.usedHints,
          hadMistakes: args.hadMistakes,
          hintPenaltySeconds: args.hintPenaltySeconds,
          bonusWords: args.pathWords?.bonusWords.length ?? 0,
        );

        final header = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ResultsTopBar(gameId: gameId, day: args.day),
            SizedBox(height: gap),
            ResultsHero(
              title: args.title,
              timeSeconds: args.timeSeconds,
              compact: compact,
              rankBadge: signedIn ? _LiveRankBadge(compact: compact) : null,
            ).animate().fadeIn(duration: 400.ms),
            if (tiles.isNotEmpty) ...[
              SizedBox(height: gap),
              ResultTilesRow(tiles: tiles, compact: compact),
            ],
            NewAchievementsBanner(occasion: args),
          ],
        );

        final card = ResultsBoardCard(
          pathWords: args.pathWords,
          board: signedIn
              ? MiniLeaderboardPanel(
                  gameId: gameId,
                  cubit: context.read<LeaderboardCubit>(),
                  timeSeconds: args.timeSeconds,
                  usedHints: args.usedHints,
                  hadMistakes: args.hadMistakes,
                  currentStreak: args.currentStreak,
                  dayId: args.leaderboardDay,
                  leaderboardProof: args.leaderboardProof,
                )
              : ResultsBoardTease(framed: false, onTap: onSave!),
        ).animate().fadeIn(delay: 300.ms, duration: 400.ms).slideY(
          begin: 0.06,
          curve: Curves.easeOutCubic,
        );

        final bar = (signedIn
                ? ResultsActions(args: args)
                : _GuestBar(timeSeconds: args.timeSeconds, onSave: onSave!))
            .animate()
            .fadeIn(delay: 400.ms, duration: 350.ms);

        if (height < _scrollBelow) {
          final cardHeight =
              4 * leaderboardTableRowHeight +
              miniLeaderboardGapRowHeight +
              (args.pathWords != null ? resultsBoardSwitchHeight : 0);
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                SizedBox(height: gap),
                SizedBox(height: cardHeight, child: card),
                SizedBox(height: gap),
                bar,
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            SizedBox(height: gap),
            Expanded(child: card),
            SizedBox(height: gap),
            bar,
          ],
        );
      },
    );
  }
}

/// The rank badge, fed by the board: an outline while it loads, nothing
/// when the player isn't on it.
class _LiveRankBadge extends StatelessWidget {
  const _LiveRankBadge({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LeaderboardCubit, LeaderboardState>(
      builder: (context, state) {
        Widget child = const SizedBox.shrink(key: ValueKey('none'));
        if (state.status == LeaderboardStatus.loading) {
          child = Padding(
            key: const ValueKey('loading'),
            padding: const EdgeInsets.only(left: 12),
            child: ResultsRankBadge(compact: compact),
          );
        } else if (state.status == LeaderboardStatus.ready) {
          final me = state.entries
              .where((e) => e.uid == state.currentUid)
              .firstOrNull;
          if (me != null) {
            child = Padding(
              key: const ValueKey('rank'),
              padding: const EdgeInsets.only(left: 12),
              child: ResultsRankBadge(
                rank: me.rank,
                total: state.entries.length,
                capped: state.entries.length >= leaderboardDailyLimit,
                compact: compact,
              ),
            );
          }
        }
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween(begin: 0.85, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
              ),
              child: child,
            ),
          ),
          child: child,
        );
      },
    );
  }
}

/// A guest's bar: home, and save the time to today's board.
class _GuestBar extends StatelessWidget {
  const _GuestBar({required this.timeSeconds, required this.onSave});

  final int timeSeconds;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ResultsIconAction(
          tooltip: AppStrings.backHome,
          icon: AppIcons.home,
          onPressed: () => context.go('/'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ZipPrimaryButton(
            label: AppStrings.saveTimeToBoard(
              AppStrings.formatPlayTime(timeSeconds),
            ),
            icon: AppIcons.trophy,
            compact: true,
            onPressed: onSave,
          ),
        ),
      ],
    );
  }
}
```

`NewAchievementsBanner` keeps its own `Padding(top: 12)`, which gives the spacing above it. Remove the unused imports (`dart:math`, `next_puzzle_countdown`, `dev_flags`, `play_period`, `path_words_results_panel`, `results_board_tease` stays). Add imports for the new view files, `leaderboard_cubit.dart`, `leaderboard_state.dart`, `leaderboard_period.dart`, `leaderboard_table.dart`, `auth_repository.dart`, `watch_leaderboard.dart` and `result_tiles.dart`.

- [ ] **Step 3: Run** `flutter test test/features/results`, expecting all pass.
- [ ] **Step 4: Run** `flutter analyze lib test`, expecting no new issues.
- [ ] **Step 5: Commit** with the message `feat(results): scoreboard layout for daily results`.

---

### Task 10: Screenshots

**Files:**
- Create: `test/features/results/results_screenshots_test.dart` (the session's draft, extended)

- [ ] **Step 1: Cases**
  - Zip signed in at 390×844 and 360×640 (PB, 6-day streak, longest 11, +20s, #14 of 18).
  - Path Words signed in at 390×844, Board tab, plus a Words-tab shot after `tap(find.byKey(Key('resultsWordsTab')))`.
  - Sudoku perfect day at 360×640 (`next: null`, rank 2 of 9, `usedHints: false`, `hadMistakes: false`).
  - Guest Zip at 390×844.
  - Guest Path Words at 360×640.

  Each case asserts `overflows` is empty.
- [ ] **Step 2: Run** `WINKLO_SCREENSHOTS=1 flutter test test/features/results/results_screenshots_test.dart`, then read each PNG in `build/screenshots/` and fix anything off.
- [ ] **Step 3: Commit** with the message `test(results): screenshots of the scoreboard`.

---

### Task 11: Verify and ship

- [ ] Run `dart format` on the touched files only, then `git status` to check for stray changes and `git checkout pubspec.lock` if it changed.
- [ ] Run `flutter analyze`, expecting no issues in the touched files.
- [ ] Run `flutter test`. Compare the failures with the 11 known on master and the podium branch (profile_screen_test, signed-out mock overflow, leagues dialog text, app_layout_test, leaderboard_repository_impl_test). There should be no new ones.
- [ ] README: in "Project status", add a line for `feat/results-scoreboard` that says it merges after `feat/leaderboard-podium`.
- [ ] Commit and push: `git push -u origin feat/results-scoreboard`.
