import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/core/di/app_repositories.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/play_period.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/usecases/sign_in_with_google.dart';
import 'package:winklo/domain/usecases/sign_out.dart';
import 'package:winklo/features/auth/cubit/auth_cubit.dart';
import 'package:winklo/features/home/view/home_screen.dart';
import 'package:winklo/features/zip/logic/daily_puzzle_generator.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockSignInWithGoogle extends Mock implements SignInWithGoogle {}

class _MockSignOut extends Mock implements SignOut {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  const user = AppUser(uid: 'test', displayName: 'Tester');

  Future<void> pumpHome(
    WidgetTester tester, {
    required SharedPreferences prefs,
    required GoRouter router,
    AppUser? authUser = user,
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
          child: MaterialApp.router(
            theme: buildAppTheme(),
            routerConfig: router,
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

  testWidgets('signed-out user can open Zip without sign-in sheet', (
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

    expect(find.text(AppStrings.signInWithGoogle), findsNothing);
    expect(find.text('zip-screen'), findsOneWidget);
  });

  testWidgets('signed-out user can open Path Words without sign-in sheet', (
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

    expect(find.text(AppStrings.signInWithGoogle), findsNothing);
    expect(find.text('path-words'), findsOneWidget);
  });
}
