import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_icons.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/features/home/view/widgets/home_freeze_badge.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<void> pump(WidgetTester tester, int count) => tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: Center(child: HomeFreezeBadge(count: count)),
      ),
    ),
  );

  testWidgets('one freeze shows the snowflake with the old tooltip', (
    tester,
  ) async {
    await pump(tester, 1);
    expect(find.byIcon(AppIcons.freeze), findsOneWidget);
    expect(find.byTooltip(AppStrings.streakFreezeReady), findsOneWidget);
    expect(find.text(AppStrings.freezeCountLabel(1)), findsNothing);
  });

  testWidgets('two freezes show the count', (tester) async {
    await pump(tester, 2);
    expect(find.byIcon(AppIcons.freeze), findsOneWidget);
    expect(find.text('×2'), findsOneWidget);
    expect(find.byTooltip(AppStrings.streakFreezesReady(2)), findsOneWidget);
  });

  testWidgets('no freezes shows nothing', (tester) async {
    await pump(tester, 0);
    expect(find.byIcon(AppIcons.freeze), findsNothing);
  });
}
