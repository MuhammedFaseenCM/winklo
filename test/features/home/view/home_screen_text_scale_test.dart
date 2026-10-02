import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/core/di/app_repositories.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_text_scale.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/play_period.dart';
import 'package:winklo/domain/streak_calculator.dart';
import 'package:winklo/features/home/view/home_screen.dart';
import 'package:winklo/features/zip/logic/daily_puzzle_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<void> pumpHome(
    WidgetTester tester, {
    required Size size,
    TextScaler textScaler = const TextScaler.linear(1.6),
    Map<String, Object> prefsValues = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefsValues);
    final prefs = await SharedPreferences.getInstance();

    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/',
      routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())],
    );

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size, textScaler: textScaler),
        child: MultiRepositoryProvider(
          providers: buildRepositoryProviders(prefs: prefs),
          child: MaterialApp.router(
            theme: buildAppTheme(),
            builder: (context, child) =>
                AppTextScale(child: child ?? const SizedBox.shrink()),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
  }

  testWidgets('home ignores large system text scale', (tester) async {
    final now = DateTime.now();
    final levelId = DailyPuzzleGenerator.dateId(now, period: PlayPeriod.daily);
    final streakDateId = StreakCalculator.dateId(now);

    final overflowErrors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) {
        overflowErrors.add(details);
      }
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);

    await pumpHome(
      tester,
      size: const Size(360, 780),
      prefsValues: {
        'best_time_zip_$levelId': 30,
        'best_pts_zip_$levelId': 1,
        'streak_current_${GameIds.zip}': 1,
        'streak_longest_${GameIds.zip}': 1,
        'streak_last_${GameIds.zip}': streakDateId,
      },
    );

    expect(find.text(AppStrings.result), findsWidgets);
    expect(overflowErrors, isEmpty);
  });

  testWidgets('short phone shows all game CTAs without scrolling', (
    tester,
  ) async {
    await pumpHome(tester, size: const Size(320, 640));

    final playFinder = find.text(AppStrings.playTodaysPathWords);
    expect(playFinder, findsOneWidget);
    expect(find.text(AppStrings.playTodaysZip), findsOneWidget);
    expect(find.text(AppStrings.playTodaysSudoku), findsOneWidget);

    final buttonBox = tester.getRect(playFinder);
    expect(buttonBox.bottom, lessThanOrEqualTo(640));
    expect(buttonBox.height, greaterThan(0));
  });
}
