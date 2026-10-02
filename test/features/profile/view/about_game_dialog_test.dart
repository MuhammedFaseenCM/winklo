import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/repositories/analytics_repository.dart';
import 'package:winklo/features/profile/view/widgets/about_game_dialog.dart';

import '../../../helpers/mock_analytics_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('about sheet shows games, daily play, and version', (
    tester,
  ) async {
    PackageInfo.setMockInitialValues(
      appName: 'Winklo',
      packageName: 'com.example.winklo',
      version: '1.0.0',
      buildNumber: '3',
      buildSignature: '',
    );

    final analytics = MockAnalyticsRepository();
    stubAnalytics(analytics);

    await tester.pumpWidget(
      RepositoryProvider<AnalyticsRepository>.value(
        value: analytics,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () => showAboutGameDialog(context),
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.profileAboutBody), findsOneWidget);
    expect(find.text(AppStrings.profileAboutGamesHeading), findsOneWidget);
    expect(find.text(AppStrings.zipTitle), findsOneWidget);
    expect(find.text(AppStrings.zipTagline), findsOneWidget);
    expect(find.text(AppStrings.pathWordsTitle), findsOneWidget);
    expect(find.text(AppStrings.pathWordsTagline), findsOneWidget);
    expect(find.text(AppStrings.sudokuTitle), findsOneWidget);
    expect(find.text(AppStrings.sudokuTagline), findsOneWidget);
    expect(find.text(AppStrings.profileAboutDailyHeading), findsOneWidget);
    expect(find.text(AppStrings.profileAboutDailyBody), findsOneWidget);
    expect(find.text(AppStrings.profileAboutVersion('1.0.0')), findsOneWidget);
    expect(find.text(AppStrings.tutorialGotIt), findsOneWidget);
    verify(() => analytics.logProfileAboutOpened()).called(1);

    final gotIt = find.text(AppStrings.tutorialGotIt);
    await tester.ensureVisible(gotIt);
    await tester.pumpAndSettle();
    await tester.tap(gotIt);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.profileAboutBody), findsNothing);
  });
}
