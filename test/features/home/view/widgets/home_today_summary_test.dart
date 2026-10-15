import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/features/home/logic/today_summary.dart';
import 'package:winklo/features/home/view/widgets/home_today_summary.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<void> pump(WidgetTester tester, TodaySummary? summary) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [HomeTodaySummary(summary: summary)],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows how many are cleared and the total time', (tester) async {
    await pump(tester, const TodaySummary(cleared: 2, totalSeconds: 221));

    expect(find.text('2 of 3 cleared · 3:41 total'), findsOneWidget);
    expect(find.text(AppStrings.homePerfectDayBadge), findsNothing);
  });

  testWidgets('a perfect day gets the badge', (tester) async {
    await pump(tester, const TodaySummary(cleared: 3, totalSeconds: 221));

    expect(find.text(AppStrings.homePerfectDayBadge), findsOneWidget);
  });

  testWidgets('renders nothing without a summary', (tester) async {
    await pump(tester, null);

    expect(find.textContaining('cleared'), findsNothing);
    expect(find.text(AppStrings.homePerfectDayBadge), findsNothing);
  });

  testWidgets('fits a 360×640 phone on a perfect day with long times', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pump(tester, const TodaySummary(cleared: 3, totalSeconds: 35999));

    expect(tester.takeException(), isNull);
    expect(find.text(AppStrings.homePerfectDayBadge), findsOneWidget);
  });
}
