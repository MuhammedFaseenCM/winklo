import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/entities/leaderboard_period.dart';
import 'package:winklo/features/leaderboard/view/widgets/leaderboard_board_sheet.dart';

void main() {
  final days = recentLeaderboardDayIds(DateTime(2026, 10, 17, 9));

  /// Opens the sheet; [act] then picks something. Returns the pick.
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
      act: () =>
          tester.tap(find.byKey(const Key('leaderboard_day_2026-10-14'))),
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
      isSemantics(isSelected: true, isButton: true),
    );
    expect(
      tester.getSemantics(find.byKey(const Key('leaderboard_day_2026-10-17'))),
      isSemantics(isSelected: false),
    );
  });
}
