# Leaderboard Table Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Leaderboard tab's four stacked control rows with game tabs plus two picker pills, and replace the 64px card rows with a 48px table. On a 390×800 phone, at least 9 rows should show instead of about 5.

**Architecture:**
- **State.** `LeaderboardCubit` gains `selectBoard(period, dayId:)`, so a sheet pick loads once.
- **Pure logic.** `logic/board_calendar.dart` builds the Monday-first calendar and the pill labels.
- **Widgets.** New files: game tabs, filter pills, the board sheet, the scope sheet, the table card/header/row, and the sheet parts both sheets share.
- **Screen.** `leaderboard_screen.dart` wires them together. The scope bar and day strip are deleted.
- **Unchanged.** `LeaderboardRow` stays for the Results mini board.

**Tech Stack:** Flutter, flutter_bloc (Cubit), go_router, mocktail, flutter_test.

Spec: `docs/superpowers/specs/2026-10-17-leaderboard-table-design.md`

**Conventions:**
- Run `dart format` only on the files you touch.
- Run `git checkout pubspec.lock` if `flutter pub get` changes it.
- Tests: `flutter test <path>`.

---

## File map

| File | Status | Responsibility |
|---|---|---|
| `lib/core/strings/app_text.dart`, `app_text_en.dart`, `app_text_ml.dart`, `app_strings.dart` | modify | New copy |
| `test/core/strings/app_text_test.dart` | modify | Sample entries for new members |
| `lib/features/leaderboard/logic/board_calendar.dart` | create | Calendar weeks, day label, board label |
| `test/features/leaderboard/logic/board_calendar_test.dart` | create | |
| `lib/features/leaderboard/cubit/leaderboard_cubit.dart` | modify | `selectBoard` |
| `test/features/leaderboard/cubit/leaderboard_cubit_scope_test.dart` | modify | `selectBoard` tests |
| `lib/features/leaderboard/view/widgets/leaderboard_table.dart` | create | Card, header, row |
| `test/features/leaderboard/view/widgets/leaderboard_table_test.dart` | create | |
| `lib/features/leaderboard/view/widgets/leaderboard_game_tabs.dart` | create | Game segment track (moved from screen) |
| `lib/features/leaderboard/view/widgets/leaderboard_filter_row.dart` | create | Board + scope pills |
| `lib/features/leaderboard/view/widgets/leaderboard_sheet_parts.dart` | create | Sheet title + option tile |
| `lib/features/leaderboard/view/widgets/leaderboard_board_sheet.dart` | create | "Which board?" |
| `test/features/leaderboard/view/widgets/leaderboard_board_sheet_test.dart` | create | |
| `lib/features/leaderboard/view/widgets/leaderboard_scope_sheet.dart` | create | "Whose scores?" |
| `test/features/leaderboard/view/widgets/leaderboard_scope_sheet_test.dart` | create | |
| `lib/features/leaderboard/view/widgets/leaderboard_shimmer.dart` | modify | Table-shaped skeleton |
| `lib/features/leaderboard/view/leaderboard_screen.dart` | modify | New layout |
| `lib/features/leaderboard/view/widgets/leaderboard_scope_bar.dart`, `leaderboard_day_strip.dart` | delete | |
| `test/features/leaderboard/view/leaderboard_screen_area_c_test.dart`, `leaderboard_screen_test.dart` | modify | Go through the pills |

---

### Task 1: Strings

**Files:**
- Modify: `lib/core/strings/app_text.dart` (after `String get leaderboardLeagues;`)
- Modify: `lib/core/strings/app_text_en.dart` (after `leaderboardLeagues`)
- Modify: `lib/core/strings/app_text_ml.dart` (after `leaderboardLeagues`)
- Modify: `lib/core/strings/app_strings.dart` (after `leaderboardLeagues`)
- Test: `test/core/strings/app_text_test.dart`

- [ ] **Step 1: Add sample entries to the test** (`_members`, after `'leaderboardLeagues'` and in the parameterised block after `'leaderboardWeeklyRow'`)

```dart
  'leaderboardBoardSheetTitle': (t) => t.leaderboardBoardSheetTitle,
  'leaderboardScopeSheetTitle': (t) => t.leaderboardScopeSheetTitle,
  'leaderboardThisWeekHint': (t) => t.leaderboardThisWeekHint,
  'leaderboardAllTimeHint': (t) => t.leaderboardAllTimeHint,
  'leaderboardSingleDayLabel': (t) => t.leaderboardSingleDayLabel,
  'leaderboardColumnPlayer': (t) => t.leaderboardColumnPlayer,
  'leaderboardColumnTime': (t) => t.leaderboardColumnTime,
  'leaderboardColumnDays': (t) => t.leaderboardColumnDays,
  'leaderboardColumnTotal': (t) => t.leaderboardColumnTotal,
  'leaderboardColumnBest': (t) => t.leaderboardColumnBest,
  'leaderboardTop50': (t) => t.leaderboardTop50,
  'leaderboardManageLeagues': (t) => t.leaderboardManageLeagues,
  'leaderboardCreateOrJoinLeague': (t) => t.leaderboardCreateOrJoinLeague,
```

```dart
  'leaderboardLeaguePlayers': (t) => t.leaderboardLeaguePlayers(12),
  'leaderboardBoardPillLabel': (t) => t.leaderboardBoardPillLabel('Today'),
  'leaderboardScopePillLabel': (t) => t.leaderboardScopePillLabel('Everyone'),
```

- [ ] **Step 2: Run, expect FAIL** — `flutter test test/core/strings/app_text_test.dart` (compile error: getters missing).

- [ ] **Step 3: Declare in `AppText`**

```dart
  // Leaderboard: the board and scope pickers and the table
  String get leaderboardBoardSheetTitle;
  String get leaderboardScopeSheetTitle;
  String get leaderboardThisWeekHint;
  String get leaderboardAllTimeHint;
  String get leaderboardSingleDayLabel;
  String get leaderboardColumnPlayer;
  String get leaderboardColumnTime;
  String get leaderboardColumnDays;
  String get leaderboardColumnTotal;
  String get leaderboardColumnBest;
  String get leaderboardTop50;
  String get leaderboardManageLeagues;
  String get leaderboardCreateOrJoinLeague;
  String leaderboardLeaguePlayers(int count);
  String leaderboardBoardPillLabel(String board);
  String leaderboardScopePillLabel(String scope);
```

- [ ] **Step 4: English (`AppTextEn`)**

```dart
  // Leaderboard: the board and scope pickers and the table
  @override
  String get leaderboardBoardSheetTitle => 'Which board?';

  @override
  String get leaderboardScopeSheetTitle => 'Whose scores?';

  @override
  String get leaderboardThisWeekHint => 'Days cleared, then total time';

  @override
  String get leaderboardAllTimeHint => 'Best time ever';

  @override
  String get leaderboardSingleDayLabel => 'A single day · last 14 days';

  @override
  String get leaderboardColumnPlayer => 'Player';

  @override
  String get leaderboardColumnTime => 'Time';

  @override
  String get leaderboardColumnDays => 'Days';

  @override
  String get leaderboardColumnTotal => 'Total';

  @override
  String get leaderboardColumnBest => 'Best';

  @override
  String get leaderboardTop50 => 'Top 50';

  @override
  String get leaderboardManageLeagues => 'Manage leagues';

  @override
  String get leaderboardCreateOrJoinLeague => 'Create or join a league';

  @override
  String leaderboardLeaguePlayers(int count) =>
      count == 1 ? '1 player' : '$count players';

  @override
  String leaderboardBoardPillLabel(String board) => 'Board: $board';

  @override
  String leaderboardScopePillLabel(String scope) => 'Scores: $scope';
```

- [ ] **Step 5: Malayalam (`AppTextMl`)** — first pass, add to the native-review list

```dart
  // Leaderboard: the board and scope pickers and the table
  @override
  String get leaderboardBoardSheetTitle => 'ഏത് ബോർഡ്?';

  @override
  String get leaderboardScopeSheetTitle => 'ആരുടെ സ്കോറുകൾ?';

  @override
  String get leaderboardThisWeekHint =>
      'പൂർത്തിയാക്കിയ ദിവസങ്ങൾ, പിന്നെ ആകെ സമയം';

  @override
  String get leaderboardAllTimeHint => 'എക്കാലത്തെയും മികച്ച സമയം';

  @override
  String get leaderboardSingleDayLabel => 'ഒരു ദിവസം · കഴിഞ്ഞ 14 ദിവസം';

  @override
  String get leaderboardColumnPlayer => 'കളിക്കാർ';

  @override
  String get leaderboardColumnTime => 'സമയം';

  @override
  String get leaderboardColumnDays => 'ദിവസം';

  @override
  String get leaderboardColumnTotal => 'ആകെ';

  @override
  String get leaderboardColumnBest => 'മികച്ചത്';

  @override
  String get leaderboardTop50 => 'ആദ്യ 50 പേർ';

  @override
  String get leaderboardManageLeagues => 'ലീഗുകൾ നിയന്ത്രിക്കൂ';

  @override
  String get leaderboardCreateOrJoinLeague =>
      'ലീഗ് ഉണ്ടാക്കൂ അല്ലെങ്കിൽ ചേരൂ';

  @override
  String leaderboardLeaguePlayers(int count) => '$count പേർ';

  @override
  String leaderboardBoardPillLabel(String board) => 'ബോർഡ്: $board';

  @override
  String leaderboardScopePillLabel(String scope) => 'സ്കോറുകൾ: $scope';
```

- [ ] **Step 6: `AppStrings` accessors**

```dart
  // Leaderboard: the board and scope pickers and the table
  static String get leaderboardBoardSheetTitle =>
      _t.leaderboardBoardSheetTitle;
  static String get leaderboardScopeSheetTitle =>
      _t.leaderboardScopeSheetTitle;
  static String get leaderboardThisWeekHint => _t.leaderboardThisWeekHint;
  static String get leaderboardAllTimeHint => _t.leaderboardAllTimeHint;
  static String get leaderboardSingleDayLabel => _t.leaderboardSingleDayLabel;
  static String get leaderboardColumnPlayer => _t.leaderboardColumnPlayer;
  static String get leaderboardColumnTime => _t.leaderboardColumnTime;
  static String get leaderboardColumnDays => _t.leaderboardColumnDays;
  static String get leaderboardColumnTotal => _t.leaderboardColumnTotal;
  static String get leaderboardColumnBest => _t.leaderboardColumnBest;
  static String get leaderboardTop50 => _t.leaderboardTop50;
  static String get leaderboardManageLeagues => _t.leaderboardManageLeagues;
  static String get leaderboardCreateOrJoinLeague =>
      _t.leaderboardCreateOrJoinLeague;
  static String leaderboardLeaguePlayers(int count) =>
      _t.leaderboardLeaguePlayers(count);
  static String leaderboardBoardPillLabel(String board) =>
      _t.leaderboardBoardPillLabel(board);
  static String leaderboardScopePillLabel(String scope) =>
      _t.leaderboardScopePillLabel(scope);
```

- [ ] **Step 7: Run, expect PASS** — `flutter test test/core/strings/`

- [ ] **Step 8: Commit** — `git commit -m "feat(leaderboard): copy for the board and scope pickers and the table"`

---

### Task 2: Board calendar and labels

**Files:**
- Create: `lib/features/leaderboard/logic/board_calendar.dart`
- Test: `test/features/leaderboard/logic/board_calendar_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/domain/entities/leaderboard_period.dart';
import 'package:winklo/features/leaderboard/logic/board_calendar.dart';

void main() {
  group('boardCalendarWeeks', () {
    test('Saturday 17 Oct 2026: three Monday-first weeks', () {
      final days = recentLeaderboardDayIds(DateTime(2026, 10, 17, 9));
      final weeks = boardCalendarWeeks(days);

      expect(weeks, hasLength(3));
      expect(weeks.every((w) => w.length == 7), isTrue);
      expect(weeks.first.first.dayId, '2026-09-28');
      expect(weeks.first.first.inWindow, isFalse);
      expect(weeks.first.last.dayId, '2026-10-04');
      expect(weeks.first.last.inWindow, isTrue);
      expect(weeks.last[5].dayId, '2026-10-17');
      expect(weeks.last[5].inWindow, isTrue);
      expect(weeks.last.last.dayId, '2026-10-18');
      expect(weeks.last.last.inWindow, isFalse);
      expect(
        weeks.expand((w) => w).where((d) => d.inWindow).map((d) => d.dayId),
        unorderedEquals(days),
      );
    });

    test('a Monday today: three rows, today first in the last', () {
      final weeks = boardCalendarWeeks(
        recentLeaderboardDayIds(DateTime(2026, 10, 19, 9)),
      );
      expect(weeks, hasLength(3));
      expect(weeks.last.first.dayId, '2026-10-19');
      expect(weeks.last.first.inWindow, isTrue);
      expect(weeks.last.skip(1).every((d) => !d.inWindow), isTrue);
    });

    test('a Sunday today: exactly two full weeks', () {
      final weeks = boardCalendarWeeks(
        recentLeaderboardDayIds(DateTime(2026, 10, 18, 9)),
      );
      expect(weeks, hasLength(2));
      expect(weeks.expand((w) => w).every((d) => d.inWindow), isTrue);
    });

    test('crosses a year boundary', () {
      final weeks = boardCalendarWeeks(
        recentLeaderboardDayIds(DateTime(2027, 1, 3, 9)),
      );
      expect(weeks.first.first.dayId, '2026-12-21');
      expect(weeks.last.last.dayId, '2027-01-03');
      expect(weeks.last.last.dayOfMonth, 3);
    });

    test('no days, no weeks', () {
      expect(boardCalendarWeeks(const []), isEmpty);
    });
  });

  group('labels', () {
    final days = recentLeaderboardDayIds(DateTime(2026, 10, 17, 9));

    test('day label: Today, Yesterday, then a short date', () {
      expect(leaderboardDayLabel(days[0], 0), AppStrings.leaderboardToday);
      expect(leaderboardDayLabel(days[1], 1), AppStrings.leaderboardYesterday);
      expect(
        leaderboardDayLabel('2026-10-14', 3),
        AppStrings.leaderboardShortDate(14, 10),
      );
    });

    test('board label follows the period and day', () {
      String label(LeaderboardPeriod p, [String? day]) =>
          leaderboardBoardLabel(period: p, dayId: day, recentDayIds: days);

      expect(label(LeaderboardPeriod.daily), AppStrings.leaderboardToday);
      expect(
        label(LeaderboardPeriod.daily, '2026-10-16'),
        AppStrings.leaderboardYesterday,
      );
      expect(
        label(LeaderboardPeriod.daily, '2026-10-12'),
        AppStrings.leaderboardShortDate(12, 10),
      );
      expect(label(LeaderboardPeriod.weekly), AppStrings.leaderboardThisWeek);
      expect(label(LeaderboardPeriod.allTime), AppStrings.leaderboardAllTime);
    });
  });
}
```

- [ ] **Step 2: Run, expect FAIL** — `flutter test test/features/leaderboard/logic/board_calendar_test.dart` (file missing).

- [ ] **Step 3: Implement**

```dart
import '../../../core/strings/app_strings.dart';
import '../../../domain/entities/leaderboard_period.dart';

/// One day in the board sheet's calendar.
class BoardCalendarDay {
  const BoardCalendarDay({
    required this.dayId,
    required this.dayOfMonth,
    required this.inWindow,
  });

  /// `yyyy-MM-dd`.
  final String dayId;
  final int dayOfMonth;

  /// True for the days with a board to open: today and the 13 before it.
  final bool inWindow;
}

/// The board sheet's calendar: Monday-first weeks, like the ISO weeks of the
/// weekly board, from the week of the oldest day in [recentDayIds] to the
/// week of today. [recentDayIds] is today first (`recentLeaderboardDayIds`).
List<List<BoardCalendarDay>> boardCalendarWeeks(List<String> recentDayIds) {
  if (recentDayIds.isEmpty) return const [];
  final window = recentDayIds.toSet();
  final today = _parseDayId(recentDayIds.first);
  final oldest = _parseDayId(recentDayIds.last);
  final start = DateTime(
    oldest.year,
    oldest.month,
    oldest.day - (oldest.weekday - DateTime.monday),
  );
  final end = DateTime(
    today.year,
    today.month,
    today.day + (DateTime.sunday - today.weekday),
  );
  final weeks = <List<BoardCalendarDay>>[];
  var week = <BoardCalendarDay>[];
  for (var i = 0; ; i++) {
    // Field arithmetic, not Duration: a DST change can't skip or repeat a day.
    final date = DateTime(start.year, start.month, start.day + i);
    if (date.isAfter(end)) break;
    final dayId = leaderboardDayId(date);
    week.add(
      BoardCalendarDay(
        dayId: dayId,
        dayOfMonth: date.day,
        inWindow: window.contains(dayId),
      ),
    );
    if (week.length == 7) {
      weeks.add(week);
      week = <BoardCalendarDay>[];
    }
  }
  return weeks;
}

/// "Today", "Yesterday", or a short date for the board day [dayId]
/// (`yyyy-MM-dd`) at [index] in the recent days (today is 0).
String leaderboardDayLabel(String dayId, int index) {
  if (index == 0) return AppStrings.leaderboardToday;
  if (index == 1) return AppStrings.leaderboardYesterday;
  final date = _parseDayId(dayId);
  return AppStrings.leaderboardShortDate(date.day, date.month);
}

/// What the board pill says: the day, "This week" or "All-time". A null
/// [dayId] is today.
String leaderboardBoardLabel({
  required LeaderboardPeriod period,
  required String? dayId,
  required List<String> recentDayIds,
}) {
  switch (period) {
    case LeaderboardPeriod.weekly:
      return AppStrings.leaderboardThisWeek;
    case LeaderboardPeriod.allTime:
      return AppStrings.leaderboardAllTime;
    case LeaderboardPeriod.daily:
      if (dayId == null) return AppStrings.leaderboardToday;
      final index = recentDayIds.indexOf(dayId);
      // Outside the window (a stale day after midnight): just the date.
      return leaderboardDayLabel(dayId, index < 0 ? 2 : index);
  }
}

DateTime _parseDayId(String dayId) {
  final parts = dayId.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}
```

- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** — `feat(leaderboard): Monday-first board calendar and pill labels`

---

### Task 3: `LeaderboardCubit.selectBoard`

**Files:**
- Modify: `lib/features/leaderboard/cubit/leaderboard_cubit.dart` (after `selectDay`)
- Test: `test/features/leaderboard/cubit/leaderboard_cubit_scope_test.dart` (append inside `main`)

- [ ] **Step 1: Failing tests**

```dart
  group('selectBoard', () {
    test('a past day loads once, with that day', () {
      final cubit = build();
      addTearDown(cubit.close);
      final before = calls.length;

      cubit.selectBoard(LeaderboardPeriod.daily, dayId: '2026-10-13');

      expect(calls, hasLength(before + 1));
      expect(calls.last.period, LeaderboardPeriod.daily);
      expect(calls.last.dayId, '2026-10-13');
      expect(cubit.state.dayId, '2026-10-13');
    });

    test('from a past day to This week: one load, day cleared', () {
      final cubit = build();
      addTearDown(cubit.close);
      cubit.selectBoard(LeaderboardPeriod.daily, dayId: '2026-10-13');
      final before = calls.length;

      cubit.selectBoard(LeaderboardPeriod.weekly);

      expect(calls, hasLength(before + 1));
      expect(calls.last.period, LeaderboardPeriod.weekly);
      expect(cubit.state.period, LeaderboardPeriod.weekly);
      expect(cubit.state.dayId, isNull);
    });

    test('from This week to a past day: one load', () {
      final cubit = build();
      addTearDown(cubit.close);
      cubit.selectBoard(LeaderboardPeriod.weekly);
      final before = calls.length;

      cubit.selectBoard(LeaderboardPeriod.daily, dayId: '2026-10-14');

      expect(calls, hasLength(before + 1));
      expect(calls.last, (
        period: LeaderboardPeriod.daily,
        dayId: '2026-10-14',
        members: null,
      ));
    });

    test('today is the live board (null day)', () {
      final cubit = build();
      addTearDown(cubit.close);
      cubit.selectBoard(LeaderboardPeriod.daily, dayId: '2026-10-13');

      cubit.selectBoard(LeaderboardPeriod.daily, dayId: '2026-10-15');

      expect(cubit.state.dayId, isNull);
      expect(calls.last.dayId, isNull);
    });

    test('the board already showing does nothing', () {
      final cubit = build();
      addTearDown(cubit.close);
      final before = calls.length;
      cubit.selectBoard(LeaderboardPeriod.daily);
      cubit.selectBoard(LeaderboardPeriod.daily, dayId: '2026-10-15');
      expect(calls, hasLength(before));
    });

    test('a day outside the window is ignored', () {
      final cubit = build();
      addTearDown(cubit.close);
      final before = calls.length;
      cubit.selectBoard(LeaderboardPeriod.daily, dayId: '2026-09-01');
      expect(calls, hasLength(before));
      expect(cubit.state.dayId, isNull);
    });
  });
```

- [ ] **Step 2: Run, expect FAIL** (`selectBoard` undefined).

- [ ] **Step 3: Implement**

```dart
  /// Shows [period]'s board in one load; for the daily board, [dayId]'s
  /// (`yyyy-MM-dd`, today's for null). Weekly and all-time clear the day.
  void selectBoard(LeaderboardPeriod period, {String? dayId}) {
    String? nextDay;
    if (period == LeaderboardPeriod.daily) {
      final today = leaderboardDayId(_now());
      nextDay = dayId == today ? null : dayId;
      if (nextDay != null && !recentDayIds.contains(nextDay)) return;
    }
    final sameBoard =
        period == state.period &&
        (period != LeaderboardPeriod.daily || nextDay == state.dayId);
    if (sameBoard) return;
    emit(
      state.copyWith(
        period: period,
        dayId: nextDay,
        status: LeaderboardStatus.loading,
      ),
    );
    _resubscribe();
  }
```

- [ ] **Step 4: Run, expect PASS** — `flutter test test/features/leaderboard/cubit/`
- [ ] **Step 5: Commit** — `feat(leaderboard): selectBoard loads a period and day in one go`

---

### Task 4: Table card, header and row

**Files:**
- Create: `lib/features/leaderboard/view/widgets/leaderboard_table.dart`
- Test: `test/features/leaderboard/view/widgets/leaderboard_table_test.dart`

- [ ] **Step 1: Failing tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/entities/leaderboard_entry.dart';
import 'package:winklo/domain/entities/leaderboard_period.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/features/leaderboard/view/widgets/leaderboard_table.dart';

LeaderboardEntry _entry({
  int rank = 4,
  int seconds = 75,
  bool? usedHints,
  bool? hadMistakes,
  int? streak,
  int? days,
}) => LeaderboardEntry(
  uid: 'u$rank',
  displayName: 'Ada',
  timeSeconds: seconds,
  updatedAt: DateTime.utc(2026, 10, 15),
  rank: rank,
  usedHints: usedHints,
  hadMistakes: hadMistakes,
  currentStreak: streak,
  daysCleared: days,
);

/// A [Semantics] widget labelled [label] (icons carry their meaning there).
Finder _labelled(String label) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.label == label,
);

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('header columns follow the board', (tester) async {
    await _pump(
      tester,
      const LeaderboardTableHeader(period: LeaderboardPeriod.daily),
    );
    expect(find.text(AppStrings.leaderboardColumnPlayer), findsOneWidget);
    expect(find.text(AppStrings.leaderboardColumnTime), findsOneWidget);
    expect(find.text(AppStrings.leaderboardColumnDays), findsNothing);

    await _pump(
      tester,
      const LeaderboardTableHeader(period: LeaderboardPeriod.weekly),
    );
    expect(find.text(AppStrings.leaderboardColumnDays), findsOneWidget);
    expect(find.text(AppStrings.leaderboardColumnTotal), findsOneWidget);

    await _pump(
      tester,
      const LeaderboardTableHeader(period: LeaderboardPeriod.allTime),
    );
    expect(find.text(AppStrings.leaderboardColumnBest), findsOneWidget);
  });

  testWidgets('a daily row: rank, name, time and clean-run icons', (
    tester,
  ) async {
    await _pump(
      tester,
      LeaderboardTableRow(
        entry: _entry(usedHints: false, hadMistakes: false, streak: 5),
        period: LeaderboardPeriod.daily,
        gameId: GameIds.sudoku,
        isYou: false,
      ),
    );
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('1:15'), findsOneWidget);
    expect(_labelled(AppStrings.leaderboardNoHintChip), findsOneWidget);
    expect(_labelled(AppStrings.leaderboardNoMistakesChip), findsOneWidget);
    expect(_labelled(AppStrings.streakLabel(5)), findsOneWidget);
    expect(tester.getSize(find.byType(LeaderboardTableRow)).height, 48);
  });

  testWidgets('Flawless is Sudoku only; no icons off the daily board', (
    tester,
  ) async {
    await _pump(
      tester,
      LeaderboardTableRow(
        entry: _entry(hadMistakes: false),
        period: LeaderboardPeriod.daily,
        gameId: GameIds.zip,
        isYou: false,
      ),
    );
    expect(_labelled(AppStrings.leaderboardNoMistakesChip), findsNothing);

    await _pump(
      tester,
      LeaderboardTableRow(
        entry: _entry(usedHints: false, streak: 5),
        period: LeaderboardPeriod.allTime,
        gameId: GameIds.zip,
        isYou: false,
      ),
    );
    expect(_labelled(AppStrings.leaderboardNoHintChip), findsNothing);
    expect(_labelled(AppStrings.streakLabel(5)), findsNothing);
  });

  testWidgets('a weekly row shows days and the week total', (tester) async {
    await _pump(
      tester,
      LeaderboardTableRow(
        entry: _entry(seconds: 372, days: 5),
        period: LeaderboardPeriod.weekly,
        gameId: GameIds.zip,
        isYou: false,
      ),
    );
    expect(find.text('5'), findsOneWidget);
    expect(find.text('6:12'), findsOneWidget);
  });

  testWidgets('a long name ellipsises instead of overflowing', (tester) async {
    tester.view.physicalSize = const Size(320, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(
      tester,
      LeaderboardTableRow(
        entry: LeaderboardEntry(
          uid: 'x',
          displayName: 'Rahul Menon Kuttikkattil Parambil',
          timeSeconds: 3725,
          updatedAt: DateTime.utc(2026),
          rank: 12,
          usedHints: false,
          currentStreak: 30,
        ),
        period: LeaderboardPeriod.daily,
        gameId: GameIds.zip,
        isYou: true,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a row calls onTap', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      LeaderboardTableRow(
        entry: _entry(),
        period: LeaderboardPeriod.daily,
        gameId: GameIds.zip,
        isYou: false,
        onTap: () => taps++,
      ),
    );
    await tester.tap(find.text('Ada'));
    expect(taps, 1);
  });
}
```

- [ ] **Step 2: Run, expect FAIL** (file missing).

- [ ] **Step 3: Implement** `leaderboard_table.dart`

```dart
import 'package:flutter/material.dart';

import '../../../../core/config/static_assets_config.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../domain/entities/leaderboard_entry.dart';
import '../../../../domain/entities/leaderboard_period.dart';
import '../../../../domain/game_ids.dart';

/// A board row's height; the board's list uses it as its item extent.
const double leaderboardTableRowHeight = 48;

/// The table's widest; on tablets it sits centred.
const double leaderboardTableMaxWidth = 640;

const double _rankWidth = 28;
const double _avatarRadius = 14;
const double _daysWidth = 40;
const double _timeWidth = 56;
const double _gap = 10;

const _noHintColor = Color(0xFF7EE0C3);
const _flawlessColor = Color(0xFF9EC0FF);
const _streakColor = Color(0xFFFFC27A);

/// The card the board's rows sit in, used by the shimmer too.
BoxDecoration leaderboardTableDecoration() => BoxDecoration(
  color: ZipColors.wall.withValues(alpha: 0.55),
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: ZipColors.outlineQuiet.withValues(alpha: 0.6)),
);

/// The board as a table: [period]'s column header over [child], the rows.
class LeaderboardTableCard extends StatelessWidget {
  const LeaderboardTableCard({
    super.key,
    required this.period,
    required this.child,
  });

  final LeaderboardPeriod period;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: leaderboardTableMaxWidth),
        child: DecoratedBox(
          decoration: leaderboardTableDecoration(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LeaderboardTableHeader(period: period),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "# · Player · Time": the columns of [period]'s board.
class LeaderboardTableHeader extends StatelessWidget {
  const LeaderboardTableHeader({super.key, required this.period});

  final LeaderboardPeriod period;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: ZipColors.inkSoft,
      fontWeight: FontWeight.w600,
    );
    final timeLabel = switch (period) {
      LeaderboardPeriod.daily => AppStrings.leaderboardColumnTime,
      LeaderboardPeriod.weekly => AppStrings.leaderboardColumnTotal,
      LeaderboardPeriod.allTime => AppStrings.leaderboardColumnBest,
    };
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: ZipColors.outlineQuiet.withValues(alpha: 0.7),
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _rankWidth,
            child: Text('#', textAlign: TextAlign.center, style: style),
          ),
          const SizedBox(width: _gap + _avatarRadius * 2 + _gap),
          Expanded(
            child: Text(
              AppStrings.leaderboardColumnPlayer,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          if (period == LeaderboardPeriod.weekly)
            SizedBox(
              width: _daysWidth,
              child: Text(
                AppStrings.leaderboardColumnDays,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: style,
              ),
            ),
          SizedBox(
            width: _timeWidth,
            child: Text(
              timeLabel,
              textAlign: TextAlign.right,
              maxLines: 1,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

/// One player on the board: rank, avatar, name (with clean-run icons on the
/// daily board), then the time, or days and total on the weekly board.
class LeaderboardTableRow extends StatelessWidget {
  const LeaderboardTableRow({
    super.key,
    required this.entry,
    required this.period,
    required this.gameId,
    required this.isYou,
    this.onTap,
    this.showDivider = true,
  });

  final LeaderboardEntry entry;
  final LeaderboardPeriod period;
  final String gameId;
  final bool isYou;
  final VoidCallback? onTap;

  /// The hairline under the row; off for the last row and the pinned row.
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final numberStyle = textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Material(
      color: isYou
          ? ZipColors.ember.withValues(alpha: 0.12)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: leaderboardTableRowHeight,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border(
              left: isYou
                  ? const BorderSide(color: ZipColors.ember, width: 3)
                  : BorderSide.none,
              bottom: showDivider
                  ? BorderSide(
                      color: ZipColors.outlineQuiet.withValues(alpha: 0.35),
                    )
                  : BorderSide.none,
            ),
          ),
          child: Row(
            children: [
              SizedBox(width: _rankWidth, child: Center(child: _rank(context))),
              const SizedBox(width: _gap),
              UserAvatar(
                displayName: entry.displayName,
                photoUrl: entry.photoUrl,
                avatarId: entry.avatarId,
                radius: _avatarRadius,
              ),
              const SizedBox(width: _gap),
              Expanded(child: _name(context)),
              if (period == LeaderboardPeriod.weekly)
                SizedBox(
                  width: _daysWidth,
                  child: Text(
                    '${entry.daysCleared ?? 0}',
                    textAlign: TextAlign.center,
                    style: numberStyle?.copyWith(color: ZipColors.teal),
                  ),
                ),
              SizedBox(
                width: _timeWidth,
                child: Text(
                  AppStrings.formatPlayTime(entry.timeSeconds),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  style: numberStyle?.copyWith(
                    color: isYou ? ZipColors.ember : ZipColors.onInk,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rank(BuildContext context) {
    final text = Text(
      '${entry.rank}',
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: ZipColors.inkSoft,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    final medal = switch (entry.rank) {
      1 => 'medals/medal_gold.png',
      2 => 'medals/medal_silver.png',
      3 => 'medals/medal_bronze.png',
      _ => null,
    };
    if (medal == null) return text;
    return Semantics(
      label: '${entry.rank}',
      child: SizedBox(
        width: 24,
        height: 24,
        child: AppImage.network(
          StaticAssetsConfig.url(medal),
          fit: BoxFit.contain,
          errorWidget: text,
          placeholder: text,
        ),
      ),
    );
  }

  Widget _name(BuildContext context) {
    final daily = period == LeaderboardPeriod.daily;
    final streak = entry.currentStreak;
    return Row(
      children: [
        Flexible(
          child: Text(
            entry.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: ZipColors.onInk,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (daily && entry.usedHints == false) ...[
          const SizedBox(width: 6),
          const _NoHintIcon(),
        ],
        if (daily && gameId == GameIds.sudoku && entry.hadMistakes == false) ...[
          const SizedBox(width: 4),
          Semantics(
            label: AppStrings.leaderboardNoMistakesChip,
            excludeSemantics: true,
            child: const Icon(
              Icons.verified_rounded,
              size: 14,
              color: _flawlessColor,
            ),
          ),
        ],
        if (daily && streak != null && streak >= 2) ...[
          const SizedBox(width: 4),
          Semantics(
            label: AppStrings.streakLabel(streak),
            excludeSemantics: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  size: 14,
                  color: _streakColor,
                ),
                Text(
                  '$streak',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: _streakColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// A struck-through bulb: solved without a hint.
class _NoHintIcon extends StatelessWidget {
  const _NoHintIcon();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppStrings.leaderboardNoHintChip,
      excludeSemantics: true,
      child: const SizedBox(
        width: 14,
        height: 14,
        child: CustomPaint(
          foregroundPainter: _SlashPainter(_noHintColor),
          child: Icon(
            Icons.lightbulb_outline_rounded,
            size: 14,
            color: _noHintColor,
          ),
        ),
      ),
    );
  }
}

class _SlashPainter extends CustomPainter {
  const _SlashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.12, size.height * 0.12),
      Offset(size.width * 0.88, size.height * 0.88),
      paint,
    );
  }

  @override
  bool shouldRepaint(_SlashPainter oldDelegate) => oldDelegate.color != color;
}
```

- [ ] **Step 4: Run, expect PASS** — `flutter test test/features/leaderboard/view/widgets/leaderboard_table_test.dart`
- [ ] **Step 5: Commit** — `feat(leaderboard): 48px table row, header and card`

---

### Task 5: Game tabs (moved out of the screen)

**Files:**
- Create: `lib/features/leaderboard/view/widgets/leaderboard_game_tabs.dart`

These are the screen's `_LeaderboardSegment`, `_LeaderboardSegmentBar` and `_LeaderboardPillTrack`, minus the `isSecondary` variant that only the old period bar used. Segments are 32px tall and the track's padding is 3px, so the bar is 40px instead of 50px. The behaviour is covered by the existing screen test ('query game change selects game on a kept cubit').

- [ ] **Step 1: Create the file**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/game_ids.dart';

/// Zip · Path Words · Sudoku, with a sliding ember pill under the pick.
class LeaderboardGameTabs extends StatelessWidget {
  const LeaderboardGameTabs({
    super.key,
    required this.gameId,
    required this.onChanged,
  });

  final String gameId;
  final ValueChanged<String> onChanged;

  static final _segments = [
    (value: GameIds.zip, icon: Icons.bolt_rounded),
    (value: GameIds.pathWords, icon: Icons.route_rounded),
    (value: GameIds.sudoku, icon: Icons.grid_on_rounded),
  ];

  static String _label(String gameId) => switch (gameId) {
    GameIds.pathWords => AppStrings.pathWordsTab,
    GameIds.sudoku => AppStrings.sudokuTitle,
    _ => AppStrings.zipTitle,
  };

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _segments.indexWhere((s) => s.value == gameId);
    return Container(
      decoration: BoxDecoration(
        color: ZipColors.wall.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: ZipColors.outlineQuiet.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pillWidth = constraints.maxWidth / _segments.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                left: (selectedIndex < 0 ? 0 : selectedIndex) * pillWidth,
                top: 0,
                bottom: 0,
                width: pillWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: ZipColors.ember,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: ZipColors.emberGlow,
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (final segment in _segments)
                    Expanded(
                      child: _GameTab(
                        icon: segment.icon,
                        label: _label(segment.value),
                        selected: segment.value == gameId,
                        onTap: () => onChanged(segment.value),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GameTab extends StatelessWidget {
  const _GameTab({
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
    final color = selected ? Colors.white : ZipColors.inkSoft;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 32,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 17, color: color),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: withMalayalamFallback(
                        GoogleFonts.lexend(
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 13,
                          letterSpacing: 0.2,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2:** `flutter analyze lib/features/leaderboard/view/widgets/leaderboard_game_tabs.dart` → No issues.
- [ ] **Step 3: Commit** — `refactor(leaderboard): game tabs in their own widget`

---

### Task 6: Shared sheet parts and the filter pills

**Files:**
- Create: `lib/features/leaderboard/view/widgets/leaderboard_sheet_parts.dart`
- Create: `lib/features/leaderboard/view/widgets/leaderboard_filter_row.dart`

These two widgets are exercised by the sheet tests (Tasks 7–8) and the screen tests (Task 10).

- [ ] **Step 1: `leaderboard_sheet_parts.dart`**

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// The board and scope sheets' frame: a title over [children], scrolling
/// when the screen is short.
class LeaderboardSheetFrame extends StatelessWidget {
  const LeaderboardSheetFrame({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: ZipColors.onInk,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// A 52px choice in a picker sheet: [leading], [label], a quiet [subtitle]
/// on the right, ember when [selected].
class LeaderboardSheetOption extends StatelessWidget {
  const LeaderboardSheetOption({
    super.key,
    required this.leading,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final Widget leading;
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected
              ? ZipColors.emberSoft
              : ZipColors.wall.withValues(alpha: 0.65),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: selected
                  ? ZipColors.ember.withValues(alpha: 0.7)
                  : ZipColors.outlineQuiet.withValues(alpha: 0.7),
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 52,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    leading,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          color: selected ? ZipColors.ember : ZipColors.onInk,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: textTheme.labelMedium?.copyWith(
                            color: ZipColors.inkSoft,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: `leaderboard_filter_row.dart`**

```dart
import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_theme.dart';

/// The board pill ("Today ▾") and, when signed in, the scope pill
/// ("Everyone ▾"). Each opens its picker sheet.
class LeaderboardFilterRow extends StatelessWidget {
  const LeaderboardFilterRow({
    super.key,
    required this.boardIcon,
    required this.boardLabel,
    required this.onBoardTap,
    this.scopeIcon = Icons.public_rounded,
    this.scopeLabel,
    this.onScopeTap,
  });

  final IconData boardIcon;
  final String boardLabel;
  final VoidCallback onBoardTap;
  final IconData scopeIcon;

  /// Null hides the scope pill (signed out).
  final String? scopeLabel;
  final VoidCallback? onScopeTap;

  @override
  Widget build(BuildContext context) {
    final scope = scopeLabel;
    return Row(
      children: [
        _FilterPill(
          key: const Key('leaderboard_board_pill'),
          icon: boardIcon,
          label: boardLabel,
          semanticsLabel: AppStrings.leaderboardBoardPillLabel(boardLabel),
          onTap: onBoardTap,
        ),
        if (scope != null) ...[
          const SizedBox(width: 8),
          Flexible(
            child: _FilterPill(
              key: const Key('leaderboard_scope_pill'),
              icon: scopeIcon,
              label: scope,
              semanticsLabel: AppStrings.leaderboardScopePillLabel(scope),
              onTap: onScopeTap,
            ),
          ),
        ],
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    super.key,
    required this.icon,
    required this.label,
    required this.semanticsLabel,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String semanticsLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Material(
        color: ZipColors.wall.withValues(alpha: 0.8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: ZipColors.outline.withValues(alpha: 0.8)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 34,
            child: Padding(
              padding: const EdgeInsets.only(left: 10, right: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: ZipColors.ember),
                  const SizedBox(width: 6),
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(
                              color: ZipColors.onInk,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.expand_more_rounded,
                    size: 18,
                    color: ZipColors.inkSoft,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3:** `flutter analyze` on both files → No issues.
- [ ] **Step 4: Commit** — `feat(leaderboard): filter pills and sheet parts`

---

### Task 7: Board sheet

**Files:**
- Create: `lib/features/leaderboard/view/widgets/leaderboard_board_sheet.dart`
- Test: `test/features/leaderboard/view/widgets/leaderboard_board_sheet_test.dart`

- [ ] **Step 1: Failing tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/entities/leaderboard_period.dart';
import 'package:winklo/features/leaderboard/view/widgets/leaderboard_board_sheet.dart';

void main() {
  final days = recentLeaderboardDayIds(DateTime(2026, 10, 17, 9));

  Future<LeaderboardBoardChoice?> open(
    WidgetTester tester, {
    LeaderboardPeriod period = LeaderboardPeriod.daily,
    String? dayId,
    bool showAllTime = true,
    Future<void> Function()? act,
  }) async {
    LeaderboardBoardChoice? picked;
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                picked = await showLeaderboardBoardSheet(
                  context,
                  period: period,
                  dayId: dayId,
                  recentDayIds: days,
                  showAllTime: showAllTime,
                );
                closed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await act?.call();
    await tester.pumpAndSettle();
    expect(closed, act != null);
    return picked;
  }

  testWidgets('lists This week, All-time and the 14 days', (tester) async {
    await open(tester);
    expect(find.text(AppStrings.leaderboardBoardSheetTitle), findsOneWidget);
    expect(find.text(AppStrings.leaderboardThisWeek), findsOneWidget);
    expect(find.text(AppStrings.leaderboardAllTime), findsOneWidget);
    for (final day in days) {
      expect(find.byKey(Key('leaderboard_day_$day')), findsOneWidget);
    }
    // Before the window and after today: shown, not tappable.
    expect(find.byKey(const Key('leaderboard_day_2026-09-28')), findsNothing);
    expect(find.text('28'), findsOneWidget);
    expect(find.text('18'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides All-time when the flag is off', (tester) async {
    await open(tester, showAllTime: false);
    expect(find.text(AppStrings.leaderboardAllTime), findsNothing);
    expect(find.text(AppStrings.leaderboardThisWeek), findsOneWidget);
  });

  testWidgets('picking a day returns the daily board for it', (tester) async {
    final choice = await open(
      tester,
      act: () => tester.tap(find.byKey(const Key('leaderboard_day_2026-10-14'))),
    );
    expect(choice?.period, LeaderboardPeriod.daily);
    expect(choice?.dayId, '2026-10-14');
  });

  testWidgets('picking This week returns the weekly board', (tester) async {
    final choice = await open(
      tester,
      act: () => tester.tap(find.text(AppStrings.leaderboardThisWeek)),
    );
    expect(choice?.period, LeaderboardPeriod.weekly);
    expect(choice?.dayId, isNull);
  });

  testWidgets('picking All-time returns the all-time board', (tester) async {
    final choice = await open(
      tester,
      act: () => tester.tap(find.text(AppStrings.leaderboardAllTime)),
    );
    expect(choice?.period, LeaderboardPeriod.allTime);
  });

  testWidgets('the selected day is marked selected', (tester) async {
    await open(tester, dayId: '2026-10-13');
    expect(
      tester.getSemantics(find.byKey(const Key('leaderboard_day_2026-10-13'))),
      containsSemantics(isSelected: true, isButton: true),
    );
  });
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement**

```dart
import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/leaderboard_period.dart';
import '../../logic/board_calendar.dart';
import 'leaderboard_sheet_parts.dart';

/// What the board sheet picked: a period and, for the daily board, its day.
class LeaderboardBoardChoice {
  const LeaderboardBoardChoice(this.period, {this.dayId});

  final LeaderboardPeriod period;

  /// `yyyy-MM-dd`; only for [LeaderboardPeriod.daily].
  final String? dayId;
}

/// "Which board?": This week, All-time (when [showAllTime]), or one of the
/// [recentDayIds] (today first) on a Monday-first calendar. Null when
/// dismissed.
Future<LeaderboardBoardChoice?> showLeaderboardBoardSheet(
  BuildContext context, {
  required LeaderboardPeriod period,
  required String? dayId,
  required List<String> recentDayIds,
  required bool showAllTime,
}) {
  return showModalBottomSheet<LeaderboardBoardChoice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: ZipColors.ink,
    builder: (sheetContext) {
      void pick(LeaderboardBoardChoice choice) =>
          Navigator.of(sheetContext).pop(choice);
      final today = recentDayIds.isEmpty ? null : recentDayIds.first;
      return LeaderboardSheetFrame(
        title: AppStrings.leaderboardBoardSheetTitle,
        children: [
          LeaderboardSheetOption(
            key: const Key('leaderboard_board_weekly'),
            leading: const Icon(Icons.date_range_rounded, color: ZipColors.sky),
            label: AppStrings.leaderboardThisWeek,
            subtitle: AppStrings.leaderboardThisWeekHint,
            selected: period == LeaderboardPeriod.weekly,
            onTap: () =>
                pick(const LeaderboardBoardChoice(LeaderboardPeriod.weekly)),
          ),
          if (showAllTime)
            LeaderboardSheetOption(
              key: const Key('leaderboard_board_all_time'),
              leading: const Icon(
                Icons.military_tech_rounded,
                color: Color(0xFFFFD700),
              ),
              label: AppStrings.leaderboardAllTime,
              subtitle: AppStrings.leaderboardAllTimeHint,
              selected: period == LeaderboardPeriod.allTime,
              onTap: () =>
                  pick(const LeaderboardBoardChoice(LeaderboardPeriod.allTime)),
            ),
          const SizedBox(height: 10),
          Text(
            AppStrings.leaderboardSingleDayLabel,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: ZipColors.inkSoft),
          ),
          const SizedBox(height: 8),
          _BoardCalendar(
            weeks: boardCalendarWeeks(recentDayIds),
            todayId: today,
            selectedDayId: period == LeaderboardPeriod.daily
                ? (dayId ?? today)
                : null,
            onPicked: (id) => pick(
              LeaderboardBoardChoice(LeaderboardPeriod.daily, dayId: id),
            ),
          ),
        ],
      );
    },
  );
}

class _BoardCalendar extends StatelessWidget {
  const _BoardCalendar({
    required this.weeks,
    required this.todayId,
    required this.selectedDayId,
    required this.onPicked,
  });

  final List<List<BoardCalendarDay>> weeks;
  final String? todayId;
  final String? selectedDayId;
  final ValueChanged<String> onPicked;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    // narrowWeekdays starts on Sunday; the weekly board's weeks start Monday.
    final weekdays = [
      for (var i = 0; i < 7; i++) localizations.narrowWeekdays[(i + 1) % 7],
    ];
    return Column(
      children: [
        Row(
          children: [
            for (final weekday in weekdays)
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    weekday,
                    textAlign: TextAlign.center,
                    style: textTheme.labelSmall?.copyWith(
                      color: ZipColors.inkSoft,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (final week in weeks)
          Row(
            children: [
              for (final day in week)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: _DayCell(
                      day: day,
                      isToday: day.dayId == todayId,
                      selected: day.dayId == selectedDayId,
                      onTap: () => onPicked(day.dayId),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.selected,
    required this.onTap,
  });

  final BoardCalendarDay day;
  final bool isToday;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (!day.inWindow) {
      return ExcludeSemantics(
        child: SizedBox(
          height: 40,
          child: Center(
            child: Text(
              '${day.dayOfMonth}',
              style: textTheme.labelLarge?.copyWith(
                color: ZipColors.outlineQuiet,
              ),
            ),
          ),
        ),
      );
    }
    final parts = day.dayId.split('-').map(int.parse).toList();
    final date = DateTime(parts[0], parts[1], parts[2]);
    final color = selected
        ? Colors.white
        : isToday
        ? ZipColors.ember
        : ZipColors.onInk;
    return Semantics(
      key: Key('leaderboard_day_${day.dayId}'),
      button: true,
      selected: selected,
      label: MaterialLocalizations.of(context).formatMediumDate(date),
      excludeSemantics: true,
      child: Material(
        color: selected ? ZipColors.ember : ZipColors.mist.withValues(alpha: 0.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
          side: BorderSide(
            color: selected
                ? ZipColors.ember
                : isToday
                ? ZipColors.ember.withValues(alpha: 0.7)
                : ZipColors.outlineQuiet.withValues(alpha: 0.7),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: SizedBox(
            height: 40,
            child: Center(
              child: Text(
                '${day.dayOfMonth}',
                style: textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** — `feat(leaderboard): "Which board?" sheet with a 2-week calendar`

---

### Task 8: Scope sheet

**Files:**
- Create: `lib/features/leaderboard/view/widgets/leaderboard_scope_sheet.dart`
- Test: `test/features/leaderboard/view/widgets/leaderboard_scope_sheet_test.dart`

- [ ] **Step 1: Failing tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/entities/league.dart';
import 'package:winklo/features/leaderboard/view/widgets/leaderboard_scope_sheet.dart';

const _family = League(
  id: 'L1',
  name: 'Family',
  ownerUid: 'u1',
  code: 'ABC234',
  memberUids: ['u1', 'u2', 'u3'],
);

void main() {
  Future<LeaderboardScopeChoice?> open(
    WidgetTester tester, {
    List<League> leagues = const [_family],
    String? selected,
    Finder? tap,
  }) async {
    LeaderboardScopeChoice? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                picked = await showLeaderboardScopeSheet(
                  context,
                  leagues: leagues,
                  selectedLeagueId: selected,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    if (tap != null) {
      await tester.tap(tap);
      await tester.pumpAndSettle();
    }
    return picked;
  }

  testWidgets('lists Everyone and my leagues with their sizes', (
    tester,
  ) async {
    await open(tester);
    expect(find.text(AppStrings.leaderboardScopeSheetTitle), findsOneWidget);
    expect(find.text(AppStrings.leaderboardScopeEveryone), findsOneWidget);
    expect(find.text(AppStrings.leaderboardTop50), findsOneWidget);
    expect(find.text('Family'), findsOneWidget);
    expect(find.text(AppStrings.leaderboardLeaguePlayers(3)), findsOneWidget);
    expect(find.text(AppStrings.leaderboardManageLeagues), findsOneWidget);
  });

  testWidgets('without leagues it offers to create or join one', (
    tester,
  ) async {
    await open(tester, leagues: const []);
    expect(find.text(AppStrings.leaderboardCreateOrJoinLeague), findsOneWidget);
    expect(find.text(AppStrings.leaderboardManageLeagues), findsNothing);
  });

  testWidgets('picking a league returns it', (tester) async {
    final choice = await open(tester, tap: find.text('Family'));
    expect(choice?.leagueId, 'L1');
    expect(choice?.manageLeagues, isFalse);
  });

  testWidgets('picking Everyone returns no league', (tester) async {
    final choice = await open(
      tester,
      selected: 'L1',
      tap: find.text(AppStrings.leaderboardScopeEveryone),
    );
    expect(choice, isNotNull);
    expect(choice?.leagueId, isNull);
    expect(choice?.manageLeagues, isFalse);
  });

  testWidgets('the leagues button asks for the leagues screen', (
    tester,
  ) async {
    final choice = await open(
      tester,
      tap: find.text(AppStrings.leaderboardManageLeagues),
    );
    expect(choice?.manageLeagues, isTrue);
  });
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement**

```dart
import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/league.dart';
import 'leaderboard_sheet_parts.dart';

/// What the scope sheet picked: a league (null for everyone), or the
/// leagues screen.
class LeaderboardScopeChoice {
  const LeaderboardScopeChoice.league(this.leagueId) : manageLeagues = false;

  const LeaderboardScopeChoice.manageLeagues()
    : leagueId = null,
      manageLeagues = true;

  final String? leagueId;
  final bool manageLeagues;
}

/// "Whose scores?": everyone, one of my [leagues], or the leagues screen.
/// Null when dismissed.
Future<LeaderboardScopeChoice?> showLeaderboardScopeSheet(
  BuildContext context, {
  required List<League> leagues,
  required String? selectedLeagueId,
}) {
  return showModalBottomSheet<LeaderboardScopeChoice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: ZipColors.ink,
    builder: (sheetContext) {
      void pick(LeaderboardScopeChoice choice) =>
          Navigator.of(sheetContext).pop(choice);
      return LeaderboardSheetFrame(
        title: AppStrings.leaderboardScopeSheetTitle,
        children: [
          LeaderboardSheetOption(
            key: const Key('leaderboard_scope_everyone'),
            leading: const Icon(Icons.public_rounded, color: ZipColors.ember),
            label: AppStrings.leaderboardScopeEveryone,
            subtitle: AppStrings.leaderboardTop50,
            selected: selectedLeagueId == null,
            onTap: () => pick(const LeaderboardScopeChoice.league(null)),
          ),
          for (final league in leagues)
            LeaderboardSheetOption(
              key: Key('leaderboard_scope_${league.id}'),
              leading: _LeagueMark(name: league.name),
              label: league.name,
              subtitle: AppStrings.leaderboardLeaguePlayers(
                league.memberUids.length,
              ),
              selected: league.id == selectedLeagueId,
              onTap: () => pick(LeaderboardScopeChoice.league(league.id)),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('leaderboard_scope_manage'),
            onPressed: () =>
                pick(const LeaderboardScopeChoice.manageLeagues()),
            icon: Icon(
              leagues.isEmpty ? Icons.group_add_rounded : Icons.group_rounded,
            ),
            label: Text(
              leagues.isEmpty
                  ? AppStrings.leaderboardCreateOrJoinLeague
                  : AppStrings.leaderboardManageLeagues,
            ),
          ),
        ],
      );
    },
  );
}

/// A league's first letter on a sky tile.
class _LeagueMark extends StatelessWidget {
  const _LeagueMark({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final letter = trimmed.isEmpty
        ? '?'
        : String.fromCharCodes(trimmed.runes.take(1)).toUpperCase();
    return ExcludeSemantics(
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ZipColors.skySoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          letter,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: ZipColors.sky,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** — `feat(leaderboard): "Whose scores?" sheet`

---

### Task 9: Table-shaped shimmer

**Files:**
- Modify: `lib/features/leaderboard/view/widgets/leaderboard_shimmer.dart` (whole file)
- Test: `test/features/leaderboard/view/widgets/leaderboard_shimmer_test.dart` (existing; must still pass)

- [ ] **Step 1: Replace the file**

```dart
import 'package:flutter/material.dart';

import '../../../../core/widgets/app_shimmer.dart';
import 'leaderboard_table.dart';

/// Skeleton of the board table: a header strip and [rowCount] rows shaped
/// like [LeaderboardTableRow] (rank · avatar · name · time).
class LeaderboardShimmer extends StatelessWidget {
  const LeaderboardShimmer({super.key, this.rowCount = 10});

  final int rowCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: leaderboardTableMaxWidth,
          ),
          child: DecoratedBox(
            decoration: leaderboardTableDecoration(),
            child: AppShimmer(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      height: 30,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: AppShimmerBox(
                            width: 64,
                            height: 8,
                            borderRadius: 4,
                          ),
                        ),
                      ),
                    ),
                    for (var i = 0; i < rowCount; i++)
                      const _LeaderboardRowShimmer(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LeaderboardRowShimmer extends StatelessWidget {
  const _LeaderboardRowShimmer();

  @override
  Widget build(BuildContext context) {
    // Mirrors LeaderboardTableRow: 48px, rank 28, avatar r=14, time 56.
    return const SizedBox(
      height: leaderboardTableRowHeight,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Center(
                child: AppShimmerBox(width: 14, height: 14, borderRadius: 4),
              ),
            ),
            SizedBox(width: 10),
            AppShimmerCircle(radius: 14),
            SizedBox(width: 10),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: AppShimmerBox(width: 120, height: 12, borderRadius: 4),
              ),
            ),
            AppShimmerBox(width: 40, height: 14, borderRadius: 4),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2:** `flutter test test/features/leaderboard/view/widgets/leaderboard_shimmer_test.dart`. Expected: PASS. If the test counts rows by `Container`, adjust it to count `AppShimmerCircle` (one per row).
- [ ] **Step 3: Commit** — `feat(leaderboard): table-shaped shimmer`

---

### Task 10: Rewire the screen and its tests

**Files:**
- Modify: `lib/features/leaderboard/view/leaderboard_screen.dart`
- Delete: `lib/features/leaderboard/view/widgets/leaderboard_scope_bar.dart`, `leaderboard_day_strip.dart`
- Modify: `test/features/leaderboard/view/leaderboard_screen_area_c_test.dart`, `leaderboard_screen_test.dart`

**Screen changes:**
1. **Imports.**
   - Remove `leaderboard_day_strip.dart`, `leaderboard_scope_bar.dart` and `leaderboard_row.dart`.
   - Add `board_calendar.dart`, `leaderboard_board_sheet.dart`, `leaderboard_scope_sheet.dart`, `leaderboard_filter_row.dart`, `leaderboard_game_tabs.dart` and `leaderboard_table.dart`.
2. **Header.**
   - Drop the `leaderboard_manage_leagues` IconButton.
   - Header bottom padding becomes `layout.space(10)`.
3. **Game tabs.** Replace the game `BlocBuilder` with:

   ```dart
   Padding(
     padding: EdgeInsets.symmetric(horizontal: layout.space(16)),
     child: BlocBuilder<LeaderboardCubit, LeaderboardState>(
       buildWhen: (p, n) => p.gameId != n.gameId,
       builder: (context, state) => LeaderboardGameTabs(
         gameId: state.gameId,
         onChanged: context.read<LeaderboardCubit>().selectGame,
       ),
     ),
   ),
   SizedBox(height: layout.space(10)),
   ```

4. **Filter row.** Replace the period bar, scope bar and day strip builders with:

   ```dart
   Padding(
     padding: EdgeInsets.symmetric(horizontal: layout.space(16)),
     child: BlocBuilder<LeaderboardCubit, LeaderboardState>(
       buildWhen: (p, n) =>
           p.period != n.period ||
           p.dayId != n.dayId ||
           p.leagueId != n.leagueId ||
           p.leagues != n.leagues ||
           p.currentUid != n.currentUid,
       builder: (context, state) {
         final cubit = context.read<LeaderboardCubit>();
         final league = state.league;
         final hasLeagues = context.read<LeagueRepository?>() != null;
         return LeaderboardFilterRow(
           boardIcon: switch (state.period) {
             LeaderboardPeriod.daily => Icons.today_rounded,
             LeaderboardPeriod.weekly => Icons.date_range_rounded,
             LeaderboardPeriod.allTime => Icons.military_tech_rounded,
           },
           boardLabel: leaderboardBoardLabel(
             period: state.period,
             dayId: state.dayId,
             recentDayIds: cubit.recentDayIds,
           ),
           onBoardTap: () => _pickBoard(context),
           scopeIcon: league == null
               ? Icons.public_rounded
               : Icons.group_rounded,
           scopeLabel: state.currentUid != null && hasLeagues
               ? (league?.name ?? AppStrings.leaderboardScopeEveryone)
               : null,
           onScopeTap: () => _pickScope(context),
         );
       },
     ),
   ),
   SizedBox(height: layout.space(10)),
   ```

5. **Picker handlers** on `_LeaderboardViewState`:

   ```dart
   Future<void> _pickBoard(BuildContext context) async {
     final cubit = context.read<LeaderboardCubit>();
     final choice = await showLeaderboardBoardSheet(
       context,
       period: cubit.state.period,
       dayId: cubit.state.dayId,
       recentDayIds: cubit.recentDayIds,
       showAllTime: _showAllTimeLeaderboard,
     );
     if (choice == null || !mounted || cubit.isClosed) return;
     cubit.selectBoard(choice.period, dayId: choice.dayId);
   }

   Future<void> _pickScope(BuildContext context) async {
     final cubit = context.read<LeaderboardCubit>();
     final router = GoRouter.of(context);
     final choice = await showLeaderboardScopeSheet(
       context,
       leagues: cubit.state.leagues,
       selectedLeagueId: cubit.state.leagueId,
     );
     if (choice == null || !mounted || cubit.isClosed) return;
     if (choice.manageLeagues) {
       unawaited(router.push('/leagues'));
       return;
     }
     cubit.selectLeague(choice.leagueId);
   }
   ```

   Add `import 'dart:async';`.

6. **Ready branch.**
   - Replace `ListView.separated` with `ListView.builder(itemExtent: leaderboardTableRowHeight, …)`, wrapped in `LeaderboardTableCard(period: state.period, child: …)`.
   - Put the card inside `Padding(padding: EdgeInsets.fromLTRB(12, 0, 12, hasNavDock ? 0 : layout.pagePadding.bottom))`.
   - The list's bottom padding is `(hasNavDock ? 88 : 0) + (showPinned ? 64 : 0) + (showSignInFab ? 80 : 0)`.
   - The item builder returns:

   ```dart
   LeaderboardTableRow(
     key: isYou ? _userRowKey : null,
     entry: entry,
     period: state.period,
     gameId: state.gameId,
     isYou: isYou,
     showDivider: index < state.entries.length - 1,
     onTap: () => showPlayerCardSheet(
       context,
       entry: entry,
       gameId: state.gameId,
       period: state.period,
       isYou: isYou,
     ),
   )
   ```

7. **Pinned row.** The overlay's horizontal padding is 12. `_PinnedUserRow` takes `period` and `gameId` instead of `timeLabel` and `showCleanRunChips`, and draws:

   ```dart
   Container(
     decoration: BoxDecoration(
       color: ZipColors.wall,
       borderRadius: BorderRadius.circular(14),
       border: Border.all(color: ZipColors.ember.withValues(alpha: 0.5)),
       boxShadow: [/* unchanged two shadows */],
     ),
     child: Stack(clipBehavior: Clip.none, children: [
       ClipRRect(
         borderRadius: BorderRadius.circular(14),
         child: LeaderboardTableRow(entry: entry, period: period,
             gameId: gameId, isYou: true, showDivider: false, onTap: onTap),
       ),
       /* the unchanged "Your Rank" badge, Positioned(top: -8, right: 16) */
     ]),
   )
   ```

8. **Row maths.** In `_isUserReached`, `pinnedHeight = leaderboardTableRowHeight + layout.space(10)` and `approxItemHeight = leaderboardTableRowHeight`. `userItemTop` becomes `userIndex * leaderboardTableRowHeight`, and `_scrollToUser` uses the same.
9. **Dead code.** Delete `_timeLabel`, `_formatTime`, `_LeaderboardSegment`, `_LeaderboardSegmentBar` and `_LeaderboardPillTrack`.

**Test changes** (area C, `pump` unchanged). Add helpers:

```dart
Future<void> openBoardSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('leaderboard_board_pill')));
  await tester.pumpAndSettle();
}

Future<void> openScopeSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('leaderboard_scope_pill')));
  await tester.pumpAndSettle();
}
```

Replace the seven tests with:

```dart
  testWidgets('fits a 360×640 phone with both pills showing', (tester) async {
    await pump(tester);
    board.add([_ada, _bo]);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(AppStrings.leaderboardToday), findsOneWidget);
    expect(find.text(AppStrings.leaderboardScopeEveryone), findsOneWidget);
    expect(find.text(AppStrings.leaderboardColumnTime), findsOneWidget);
    expect(find.byKey(const Key('leaderboard_manage_leagues')), findsNothing);
  });

  testWidgets('a 390×800 phone shows at least nine rows', (tester) async {
    await pump(tester, size: const Size(390, 800));
    board.add([
      for (var i = 1; i <= 20; i++)
        LeaderboardEntry(
          uid: 'p$i',
          displayName: 'Player $i',
          timeSeconds: 40 + i,
          updatedAt: DateTime.utc(2026, 10, 15),
          rank: i,
        ),
    ]);
    await tester.pumpAndSettle();

    // Above the 88px nav dock.
    expect(tester.getRect(find.text('Player 9')).bottom, lessThan(800 - 88));
  });

  testWidgets('a past day loads that day’s board', (tester) async {
    await pump(tester);
    board.add([_ada]);
    await tester.pumpAndSettle();

    final yesterday = leaderboardDayId(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    await openBoardSheet(tester);
    await tester.tap(find.byKey(Key('leaderboard_day_$yesterday')));
    await tester.pumpAndSettle();

    expect(calls.last.dayId, yesterday);
    expect(find.text(AppStrings.leaderboardYesterday), findsOneWidget);

    board.add(const []);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.leaderboardPastDayEmpty), findsOneWidget);
  });

  testWidgets('This week shows days and total columns', (tester) async {
    await pump(tester);
    await openBoardSheet(tester);
    await tester.tap(find.text(AppStrings.leaderboardThisWeek));
    await tester.pumpAndSettle();
    expect(calls.last.period, LeaderboardPeriod.weekly);

    board.add([_bo]);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.leaderboardThisWeek), findsOneWidget);
    expect(find.text(AppStrings.leaderboardColumnDays), findsOneWidget);
    expect(find.text(AppStrings.leaderboardColumnTotal), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('6:12'), findsOneWidget);
  });

  testWidgets('All-time loads from the sheet', (tester) async {
    await pump(tester);
    await openBoardSheet(tester);
    await tester.tap(find.text(AppStrings.leaderboardAllTime));
    await tester.pumpAndSettle();
    expect(calls.last.period, LeaderboardPeriod.allTime);
    board.add([_ada]);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.leaderboardColumnBest), findsOneWidget);
  });

  testWidgets('an empty weekly board explains debug builds', (tester) async {
    await pump(tester);
    await openBoardSheet(tester);
    await tester.tap(find.text(AppStrings.leaderboardThisWeek));
    await tester.pumpAndSettle();
    board.add(const []);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.leaderboardWeeklyDebugNote), findsOneWidget);
  });

  // 'tapping a player opens their card' — unchanged.

  testWidgets('picking a league shows its members', (tester) async {
    await pump(tester);
    board.add([_ada]);
    await tester.pumpAndSettle();

    await openScopeSheet(tester);
    await tester.tap(find.text('Family'));
    await tester.pumpAndSettle();

    expect(memberCalls.last, ['u1', 'u2']);
    expect(find.text('Family'), findsOneWidget);
  });

  testWidgets('Manage leagues opens the leagues screen', (tester) async {
    await pump(tester);
    board.add(const []);
    await tester.pumpAndSettle();

    await openScopeSheet(tester);
    await tester.tap(find.text(AppStrings.leaderboardManageLeagues));
    await tester.pumpAndSettle();

    expect(find.text('leagues screen'), findsOneWidget);
  });
```

`pump` gains `{Size size = const Size(360, 640)}`, which it uses for `tester.view.physicalSize`.

In `leaderboard_screen_test.dart`, 'hides only All-time when showAllTimeLeaderboard is false' becomes:

```dart
    await tester.tap(find.byKey(const Key('leaderboard_board_pill')));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.leaderboardAllTime), findsNothing);
    // This week stays: the weekly board isn't behind the flag.
    expect(find.text(AppStrings.leaderboardThisWeek), findsOneWidget);
    expect(periods, isNotEmpty);
    expect(periods, everyElement(LeaderboardPeriod.daily));
```

- [ ] **Step 1:** Update the area C and screen tests as above. Run them and expect FAIL: there are no pills yet.
- [ ] **Step 2:** Make screen changes 1–9 and delete the two widget files.
- [ ] **Step 3:** Run `flutter test test/features/leaderboard/` and expect PASS.
- [ ] **Step 4:** Run `flutter analyze` and expect no new issues (the base has 20 infos).
- [ ] **Step 5: Commit** — `feat(leaderboard): two pickers and a table on the Leaderboard tab`

---

### Task 11: Verify

- [ ] `dart format` only the touched files, then `git status` to check for stray changes and `git checkout pubspec.lock` if needed.
- [ ] `flutter analyze`: no new issues.
- [ ] `flutter test`: the full suite passes.
- [ ] Render the tab at 390×800 and 360×640 in a widget test that writes a PNG with real fonts, for both the daily and weekly boards and both sheets. Eyeball them against the approved mockups.
- [ ] Do an independent code review of the branch diff and fix what it finds.
- [ ] Update the README status line if it lists leaderboard features.
- [ ] Push `feat/leaderboard-table`, not master.
