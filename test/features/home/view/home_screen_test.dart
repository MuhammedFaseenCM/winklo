import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/core/di/app_repositories.dart';
import 'package:winklo/core/lifecycle/progress_sync_lifecycle.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/play_period.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/usecases/sign_in_with_google.dart';
import 'package:winklo/domain/usecases/sign_out.dart';
import 'package:winklo/domain/usecases/sync_progress.dart';
import 'package:winklo/features/auth/cubit/auth_cubit.dart';
import 'package:winklo/features/home/view/home_screen.dart';
import 'package:winklo/features/zip/logic/daily_puzzle_generator.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockSignInWithGoogle extends Mock implements SignInWithGoogle {}

class _MockSignOut extends Mock implements SignOut {}

class _MockSyncProgress extends Mock implements SyncProgress {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  const user = AppUser(uid: 'test', displayName: 'Tester');

  Future<void> pumpHome(
    WidgetTester tester, {
    required SharedPreferences prefs,
    required GoRouter router,
    AppUser? authUser = user,
    ProgressSyncLifecycle? progressSync,
  }) async {
    final auth = _MockAuthRepository();
    when(() => auth.currentUser).thenReturn(authUser);
    when(
      () => auth.authStateChanges(),
    ).thenAnswer((_) => Stream.value(authUser));

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: buildRepositoryProviders(prefs: prefs),
        child: BlocProvider(
          create: (_) => AuthCubit(
            authRepository: auth,
            signInWithGoogle: _MockSignInWithGoogle(),
            signOut: _MockSignOut(),
          ),
          child: Builder(
            builder: (_) {
              final app = MaterialApp.router(
                theme: buildAppTheme(),
                routerConfig: router,
              );
              if (progressSync == null) return app;
              return RepositoryProvider<ProgressSyncLifecycle>.value(
                value: progressSync,
                child: app,
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
  }

  testWidgets('reloads cleared state after returning from a daily game', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final levelId = DailyPuzzleGenerator.dateId(
      DateTime.now(),
      period: PlayPeriod.daily,
    );

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
        GoRoute(
          path: '/zip',
          builder: (context, _) {
            return Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    await prefs.setInt('best_time_zip_$levelId', 42);
                    if (context.mounted) context.pop();
                  },
                  child: const Text('finish-zip'),
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: '/path-words',
          builder: (_, _) => const Scaffold(body: Text('path-words')),
        ),
        GoRoute(
          path: '/leaderboard',
          builder: (_, _) => const Scaffold(body: Text('leaderboard')),
        ),
      ],
    );

    await pumpHome(tester, prefs: prefs, router: router);

    expect(find.text(AppStrings.playTodaysZip), findsOneWidget);
    expect(find.text(AppStrings.result), findsNothing);

    await tester.tap(find.text(AppStrings.playTodaysZip));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('finish-zip'), findsOneWidget);
    await tester.tap(find.text('finish-zip'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text(AppStrings.result), findsOneWidget);
    expect(find.text(AppStrings.playTodaysZip), findsNothing);
  });

  testWidgets('reloads cleared state when a sync restores progress', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final levelId = DailyPuzzleGenerator.dateId(
      DateTime.now(),
      period: PlayPeriod.daily,
    );

    final auth = _MockAuthRepository();
    when(() => auth.currentUser).thenReturn(user);
    when(() => auth.authStateChanges()).thenAnswer((_) => Stream.value(user));
    final sync = _MockSyncProgress();
    final pending = Completer<SyncProgressResult>();
    when(
      () => sync(pull: any(named: 'pull')),
    ).thenAnswer((_) => pending.future);
    final lifecycle = ProgressSyncLifecycle(
      syncProgress: sync,
      authRepository: auth,
      localChanges: const Stream<void>.empty(),
    );
    addTearDown(lifecycle.dispose);

    final router = GoRouter(
      initialLocation: '/',
      routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())],
    );

    await pumpHome(
      tester,
      prefs: prefs,
      router: router,
      progressSync: lifecycle,
    );
    lifecycle.start();
    expect(find.text(AppStrings.playTodaysZip), findsOneWidget);

    // Sync restores today's clear from the remote copy.
    await prefs.setInt('best_time_zip_$levelId', 42);
    pending.complete(const SyncProgressResult(localChanged: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text(AppStrings.result), findsOneWidget);
    expect(find.text(AppStrings.playTodaysZip), findsNothing);
  });

  testWidgets('reloads after results replaces the game and returns home', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final levelId = DailyPuzzleGenerator.dateId(
      DateTime.now(),
      period: PlayPeriod.daily,
    );

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
        GoRoute(
          path: '/zip',
          builder: (context, _) {
            return Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    await prefs.setInt('best_time_zip_$levelId', 42);
                    if (context.mounted) {
                      context.pushReplacement('/results');
                    }
                  },
                  child: const Text('finish-zip'),
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: '/results',
          builder: (context, _) {
            return Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => context.go('/'),
                  child: Text(AppStrings.backHome),
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: '/leaderboard',
          builder: (_, _) => const Scaffold(body: Text('leaderboard')),
        ),
      ],
    );

    await pumpHome(tester, prefs: prefs, router: router);

    await tester.tap(find.text(AppStrings.playTodaysZip));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('finish-zip'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text(AppStrings.backHome), findsOneWidget);
    await tester.tap(find.text(AppStrings.backHome));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text(AppStrings.result), findsOneWidget);
    expect(find.text(AppStrings.playTodaysZip), findsNothing);
  });

  testWidgets('signed-out user sees play sign-in sheet and stays on Home', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
        GoRoute(
          path: '/zip',
          builder: (_, _) => const Scaffold(body: Text('zip-screen')),
        ),
        GoRoute(
          path: '/path-words',
          builder: (_, _) => const Scaffold(body: Text('path-words')),
        ),
        GoRoute(
          path: '/leaderboard',
          builder: (_, _) => const Scaffold(body: Text('leaderboard')),
        ),
      ],
    );

    await pumpHome(tester, prefs: prefs, router: router, authUser: null);

    await tester.tap(find.text(AppStrings.playTodaysZip));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(AppStrings.playSignInTitle), findsOneWidget);
    expect(find.text(AppStrings.signInWithGoogle), findsOneWidget);
    expect(find.text('zip-screen'), findsNothing);

    await tester.tap(find.text(AppStrings.signInCancel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(AppStrings.playTodaysZip), findsOneWidget);
    expect(find.text('zip-screen'), findsNothing);
  });

  testWidgets('signed-out Path Words tap shows play sign-in sheet', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
        GoRoute(
          path: '/zip',
          builder: (_, _) => const Scaffold(body: Text('zip-screen')),
        ),
        GoRoute(
          path: '/path-words',
          builder: (_, _) => const Scaffold(body: Text('path-words')),
        ),
        GoRoute(
          path: '/leaderboard',
          builder: (_, _) => const Scaffold(body: Text('leaderboard')),
        ),
      ],
    );

    await pumpHome(tester, prefs: prefs, router: router, authUser: null);

    await tester.tap(find.text(AppStrings.playTodaysPathWords));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(AppStrings.playSignInTitle), findsOneWidget);
    expect(find.text('path-words'), findsNothing);
  });

  testWidgets('signed-in user opens Zip without sign-in sheet', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
        GoRoute(
          path: '/zip',
          builder: (_, _) => const Scaffold(body: Text('zip-screen')),
        ),
        GoRoute(
          path: '/path-words',
          builder: (_, _) => const Scaffold(body: Text('path-words')),
        ),
        GoRoute(
          path: '/leaderboard',
          builder: (_, _) => const Scaffold(body: Text('leaderboard')),
        ),
      ],
    );

    await pumpHome(tester, prefs: prefs, router: router);

    await tester.tap(find.text(AppStrings.playTodaysZip));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(AppStrings.playSignInTitle), findsNothing);
    expect(find.text('zip-screen'), findsOneWidget);
  });

  testWidgets('tile leaderboard button opens that game leaderboard', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
        GoRoute(
          path: '/leaderboard',
          builder: (context, state) {
            final game = state.uri.queryParameters['game'] ?? '';
            return Scaffold(body: Text('leaderboard:$game'));
          },
        ),
      ],
    );

    await pumpHome(tester, prefs: prefs, router: router);

    final leaderboardButtons = find.byIcon(Icons.leaderboard_rounded);
    expect(leaderboardButtons, findsNWidgets(3));

    await tester.tap(leaderboardButtons.at(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('leaderboard:path_words'), findsOneWidget);
  });
}
