import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/data/repositories/play_mode_record_repository_impl.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/repositories/play_mode_record_repository.dart';
import 'package:winklo/domain/usecases/get_best_points.dart';
import 'package:winklo/domain/usecases/get_best_time_seconds.dart';
import 'package:winklo/domain/usecases/sign_in_with_google.dart';
import 'package:winklo/domain/usecases/sign_out.dart';
import 'package:winklo/features/auth/cubit/auth_cubit.dart';
import 'package:winklo/features/more_play/view/archive_screen.dart';
import 'package:winklo/features/more_play/view/more_play_screen.dart';

import '../../helpers/screenshot.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockSignInWithGoogle extends Mock implements SignInWithGoogle {}

class _MockSignOut extends Mock implements SignOut {}

class _MockGetBestPoints extends Mock implements GetBestPoints {}

class _MockGetBestTimeSeconds extends Mock implements GetBestTimeSeconds {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(loadScreenshotFonts);

  late _MockGetBestPoints getBestPoints;
  late _MockGetBestTimeSeconds getBestTimeSeconds;
  late PlayModeRecordRepositoryImpl records;
  late AuthCubit authCubit;

  setUp(() async {
    getBestPoints = _MockGetBestPoints();
    getBestTimeSeconds = _MockGetBestTimeSeconds();
    when(() => getBestPoints(any())).thenReturn(0);
    when(() => getBestTimeSeconds(any())).thenReturn(null);
    SharedPreferences.setMockInitialValues({});
    records = PlayModeRecordRepositoryImpl(
      await SharedPreferences.getInstance(),
    );
    final auth = _MockAuthRepository();
    const user = AppUser(uid: 'u', displayName: 'Tester');
    when(() => auth.currentUser).thenReturn(user);
    when(() => auth.authStateChanges()).thenAnswer((_) => Stream.value(user));
    authCubit = AuthCubit(
      authRepository: auth,
      signInWithGoogle: _MockSignInWithGoogle(),
      signOut: _MockSignOut(),
    );
  });

  tearDown(() => authCubit.close());

  Future<void> pump(
    WidgetTester tester, {
    required String initial,
    Key? boundary,
    DateTime Function()? now,
  }) async {
    tester.view.physicalSize = const Size(360, 640) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('home')),
        GoRoute(
          path: '/more',
          builder: (_, _) => const MorePlayScreen(),
          routes: [
            GoRoute(
              path: 'archive',
              builder: (_, state) => ArchiveScreen(
                initialGameId: state.uri.queryParameters['game'] ?? 'zip',
                now: now,
              ),
            ),
          ],
        ),
        for (final path in [
          '/zip',
          '/path-words',
          '/sudoku',
          '/word-match',
          '/category-race',
        ])
          GoRoute(path: path, builder: (_, state) => Text('${state.uri}')),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<GetBestPoints>.value(value: getBestPoints),
          RepositoryProvider<GetBestTimeSeconds>.value(
            value: getBestTimeSeconds,
          ),
          RepositoryProvider<PlayModeRecordRepository>.value(value: records),
        ],
        child: BlocProvider.value(
          value: authCubit,
          child: RepaintBoundary(
            key: boundary,
            child: MaterialApp.router(
              theme: buildAppTheme(),
              debugShowCheckedModeBanner: false,
              routerConfig: router,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('hub', () {
    testWidgets('lists the archive, practice and bonus games', (tester) async {
      await pump(tester, initial: '/more');
      expect(find.text(AppStrings.moreWaysTitle), findsOneWidget);
      expect(find.text(AppStrings.archiveHint), findsOneWidget);
      expect(find.text(AppStrings.practiceHint), findsOneWidget);
      expect(find.text(AppStrings.wordMatch), findsOneWidget);
      expect(find.text(AppStrings.categoryRace), findsOneWidget);
    });

    testWidgets('practice opens the game in practice mode', (tester) async {
      await pump(tester, initial: '/more');
      await tester.tap(find.text(AppStrings.sudokuTitle));
      await tester.pumpAndSettle();
      expect(find.text('/sudoku?mode=practice'), findsOneWidget);
    });

    testWidgets('bonus games open their routes', (tester) async {
      await pump(tester, initial: '/more');
      await tester.tap(find.text(AppStrings.categoryRace));
      await tester.pumpAndSettle();
      expect(find.text('/category-race'), findsOneWidget);
    });

    testWidgets('at 360x640 it fits without overflow', (tester) async {
      const boundary = Key('hub');
      await pump(tester, initial: '/more', boundary: boundary);
      expect(tester.takeException(), isNull);
      await saveScreenshot(tester, find.byKey(boundary), 'more_play_360x640');
    });
  });

  group('archive', () {
    DateTime fixedNow() => DateTime(2026, 10, 15, 9);

    testWidgets('a day opens that daily in archive mode', (tester) async {
      await pump(
        tester,
        initial: '/more/archive?game=path_words',
        now: fixedNow,
      );
      await tester.tap(find.byKey(const ValueKey('archive-day-12')));
      await tester.pumpAndSettle();
      expect(
        find.text('/path-words?mode=archive&day=2026-10-12'),
        findsOneWidget,
      );
    });

    testWidgets('days outside the archive do nothing', (tester) async {
      await pump(tester, initial: '/more/archive', now: fixedNow);
      await tester.tap(find.byKey(const ValueKey('archive-day-15')));
      await tester.tap(find.byKey(const ValueKey('archive-day-10')));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.archiveTitle), findsOneWidget);
    });

    testWidgets('cleared days show a check; switching games reloads', (
      tester,
    ) async {
      when(() => getBestTimeSeconds('zip_daily_20261011')).thenReturn(60);
      await records.recordTime('archive_zip_20261013', 70);
      await pump(tester, initial: '/more/archive', now: fixedNow);
      // Two days and the legend.
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(3));
      expect(find.text(AppStrings.archiveMonthCleared(2)), findsOneWidget);
      await tester.tap(find.text(AppStrings.sudokuTitle));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('at 360x640 it fits without overflow', (tester) async {
      when(() => getBestTimeSeconds('zip_daily_20261011')).thenReturn(60);
      await records.recordTime('archive_zip_20261013', 70);
      const boundary = Key('archive');
      await pump(
        tester,
        initial: '/more/archive',
        boundary: boundary,
        now: () => DateTime(2026, 10, 30, 9),
      );
      expect(tester.takeException(), isNull);
      await saveScreenshot(tester, find.byKey(boundary), 'archive_360x640');
    });
  });
}
