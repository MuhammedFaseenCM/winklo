import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/habit/freeze_saved_notice.dart';
import 'package:winklo/domain/habit/weekly_recap.dart';
import 'package:winklo/features/home/cubit/home_habit_state.dart';
import 'package:winklo/features/home/view/widgets/home_habit_cards.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<void> pump(
    WidgetTester tester,
    HomeHabitState state, {
    void Function(String gameId)? onDismissNotice,
    VoidCallback? onDismissRecap,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: HomeHabitCardsView(
          state: state,
          onDismissNotice: onDismissNotice ?? (_) {},
          onDismissRecap: onDismissRecap ?? () {},
        ),
      ),
    ),
  );

  testWidgets('says which streak a freeze saved, and dismisses', (
    tester,
  ) async {
    String? dismissed;
    await pump(
      tester,
      const HomeHabitState(
        freezeNotices: [FreezeSavedNotice(gameId: GameIds.zip, days: 12)],
      ),
      onDismissNotice: (id) => dismissed = id,
    );
    expect(
      find.text('Your freeze saved your 12-day Zip streak'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip(AppStrings.dismiss));
    expect(dismissed, GameIds.zip);
  });

  testWidgets('shows this week’s recap, and dismisses', (tester) async {
    var dismissed = 0;
    await pump(
      tester,
      const HomeHabitState(
        recap: WeeklyRecap(
          weekStartId: '20261012',
          cleared: 18,
          possible: 21,
          bestGameId: GameIds.zip,
          bestSeconds: 58,
        ),
      ),
      onDismissRecap: () => dismissed++,
    );
    expect(find.text(AppStrings.homeRecapTitle), findsOneWidget);
    expect(
      find.text('This week: 18 of 21 cleared, best Zip 0:58'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip(AppStrings.dismiss));
    expect(dismissed, 1);
  });

  testWidgets('on Monday the recap says last week', (tester) async {
    await pump(
      tester,
      const HomeHabitState(
        recap: WeeklyRecap(weekStartId: '20261012', cleared: 3, possible: 21),
        recapIsLastWeek: true,
      ),
    );
    expect(find.text('Last week: 3 of 21 cleared'), findsOneWidget);
  });

  testWidgets('nothing to show takes no space', (tester) async {
    await pump(tester, const HomeHabitState());
    expect(find.byType(Card), findsNothing);
    expect(tester.getSize(find.byType(HomeHabitCardsView)).height, 0);
  });
}
