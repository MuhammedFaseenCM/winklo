import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/entities/leaderboard_period.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/repositories/analytics_repository.dart';
import 'package:winklo/domain/repositories/app_review_repository.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/usecases/sign_in_with_google.dart';
import 'package:winklo/domain/usecases/sign_out.dart';
import 'package:winklo/features/auth/cubit/auth_cubit.dart';
import 'package:winklo/features/results/results_args.dart';
import 'package:winklo/features/results/results_screen.dart';

import '../../helpers/mock_analytics_repository.dart';
import '../../helpers/mock_app_review_repository.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockSignInWithGoogle extends Mock implements SignInWithGoogle {}

class _MockSignOut extends Mock implements SignOut {}

void main() {
  setUpAll(() {
    registerFallbackValue(LeaderboardPeriod.daily);
  });

  Future<void> flushPromptTimers(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
  }

  Future<void> pumpDailyResults(
    WidgetTester tester, {
    required ResultsArgs args,
    required MockAppReviewRepository review,
    MockAnalyticsRepository? analytics,
  }) async {
    final auth = _MockAuthRepository();
    when(() => auth.currentUser).thenReturn(null);
    when(() => auth.authStateChanges()).thenAnswer((_) => Stream.value(null));

    final analyticsRepo = analytics ?? MockAnalyticsRepository();
    if (analytics == null) {
      stubAnalytics(analyticsRepo);
    }

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<AuthRepository>.value(value: auth),
          RepositoryProvider<AnalyticsRepository>.value(value: analyticsRepo),
          RepositoryProvider<AppReviewRepository>.value(value: review),
        ],
        child: BlocProvider(
          create: (_) => AuthCubit(
            authRepository: auth,
            signInWithGoogle: _MockSignInWithGoogle(),
            signOut: _MockSignOut(),
          ),
          child: MaterialApp(
            theme: buildAppTheme(),
            home: ResultsScreen(args: args),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'PB daily with shouldPrompt requests review and records attempt',
    (tester) async {
      final review = MockAppReviewRepository();
      when(
        () => review.shouldPromptAfterMilestone(
          isPersonalBest: true,
          streak: any(named: 'streak'),
        ),
      ).thenReturn(true);
      when(
        () => review.requestReviewOrOpenStore(),
      ).thenAnswer((_) async => ReviewOutcome.inApp);
      when(() => review.recordAutoPromptAttempt()).thenAnswer((_) async {});

      await pumpDailyResults(
        tester,
        review: review,
        args: const ResultsArgs(
          title: 'Puzzle cleared!',
          subtitle: '',
          timeSeconds: 12,
          improved: true,
          replayDaily: true,
          gameId: GameIds.zip,
        ),
      );

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      verify(() => review.requestReviewOrOpenStore()).called(1);
      verify(() => review.recordAutoPromptAttempt()).called(1);
      await flushPromptTimers(tester);
    },
  );

  testWidgets('7-day streak logs review_prompt with streak source', (
    tester,
  ) async {
    final review = MockAppReviewRepository();
    final analytics = MockAnalyticsRepository();
    stubAnalytics(analytics);
    when(
      () => review.shouldPromptAfterMilestone(isPersonalBest: false, streak: 7),
    ).thenReturn(true);
    when(
      () => review.requestReviewOrOpenStore(),
    ).thenAnswer((_) async => ReviewOutcome.store);
    when(() => review.recordAutoPromptAttempt()).thenAnswer((_) async {});

    await pumpDailyResults(
      tester,
      review: review,
      analytics: analytics,
      args: const ResultsArgs(
        title: 'Puzzle cleared!',
        subtitle: '',
        timeSeconds: 12,
        improved: false,
        currentStreak: 7,
        replayDaily: true,
        gameId: GameIds.zip,
      ),
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    verify(
      () => analytics.logReviewPrompt(source: 'streak', outcome: 'store'),
    ).called(1);
    await flushPromptTimers(tester);
  });

  testWidgets('shouldPrompt false skips review request', (tester) async {
    final review = MockAppReviewRepository();
    when(
      () => review.shouldPromptAfterMilestone(
        isPersonalBest: any(named: 'isPersonalBest'),
        streak: any(named: 'streak'),
      ),
    ).thenReturn(false);

    await pumpDailyResults(
      tester,
      review: review,
      args: const ResultsArgs(
        title: 'Puzzle cleared!',
        subtitle: '',
        timeSeconds: 12,
        improved: true,
        replayDaily: true,
        gameId: GameIds.zip,
      ),
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    verifyNever(() => review.requestReviewOrOpenStore());
    verifyNever(() => review.recordAutoPromptAttempt());
    await flushPromptTimers(tester);
  });

  testWidgets('local results never call AppReviewRepository', (tester) async {
    final review = MockAppReviewRepository();
    when(
      () => review.shouldPromptAfterMilestone(
        isPersonalBest: any(named: 'isPersonalBest'),
        streak: any(named: 'streak'),
      ),
    ).thenReturn(true);
    when(
      () => review.requestReviewOrOpenStore(),
    ).thenAnswer((_) async => ReviewOutcome.inApp);

    final analytics = MockAnalyticsRepository();
    stubAnalytics(analytics);

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<AnalyticsRepository>.value(value: analytics),
          RepositoryProvider<AppReviewRepository>.value(value: review),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: ResultsScreen(
            args: ResultsArgs(
              title: 'Puzzle cleared!',
              subtitle: '',
              timeSeconds: 12,
              improved: true,
              gameId: GameIds.zip,
              local: const LocalResultInfo(
                kind: LocalResultKind.practice,
                label: 'Practice',
                bestSeconds: 10,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    verifyNever(
      () => review.shouldPromptAfterMilestone(
        isPersonalBest: any(named: 'isPersonalBest'),
        streak: any(named: 'streak'),
      ),
    );
    verifyNever(() => review.requestReviewOrOpenStore());
  });

  testWidgets('dispose before delay skips review request', (tester) async {
    final review = MockAppReviewRepository();
    when(
      () => review.shouldPromptAfterMilestone(
        isPersonalBest: any(named: 'isPersonalBest'),
        streak: any(named: 'streak'),
      ),
    ).thenReturn(true);
    when(
      () => review.requestReviewOrOpenStore(),
    ).thenAnswer((_) async => ReviewOutcome.inApp);
    when(() => review.recordAutoPromptAttempt()).thenAnswer((_) async {});

    const dailyArgs = ResultsArgs(
      title: 'Puzzle cleared!',
      subtitle: '',
      timeSeconds: 12,
      improved: true,
      replayDaily: true,
      gameId: GameIds.zip,
    );

    Widget dailyResultsPage() {
      final auth = _MockAuthRepository();
      when(() => auth.currentUser).thenReturn(null);
      when(() => auth.authStateChanges()).thenAnswer((_) => Stream.value(null));
      final analytics = MockAnalyticsRepository();
      stubAnalytics(analytics);
      return MultiRepositoryProvider(
        providers: [
          RepositoryProvider<AuthRepository>.value(value: auth),
          RepositoryProvider<AnalyticsRepository>.value(value: analytics),
          RepositoryProvider<AppReviewRepository>.value(value: review),
        ],
        child: BlocProvider(
          create: (_) => AuthCubit(
            authRepository: auth,
            signInWithGoogle: _MockSignInWithGoogle(),
            signOut: _MockSignOut(),
          ),
          child: const ResultsScreen(args: dailyArgs),
        ),
      );
    }

    final rootNav = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: rootNav,
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => rootNav.currentState!.push<void>(
              MaterialPageRoute<void>(builder: (_) => dailyResultsPage()),
            ),
            child: const Text('open-results'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open-results'));
    await tester.pump();
    rootNav.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));

    verifyNever(() => review.requestReviewOrOpenStore());
  });
}
