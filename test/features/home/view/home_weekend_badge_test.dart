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
import 'package:winklo/domain/entities/zip_level.dart';
import 'package:winklo/domain/play_period.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/repositories/zip_level_repository.dart';
import 'package:winklo/domain/usecases/sign_in_with_google.dart';
import 'package:winklo/domain/usecases/sign_out.dart';
import 'package:winklo/features/auth/cubit/auth_cubit.dart';
import 'package:winklo/features/home/view/home_screen.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockSignInWithGoogle extends Mock implements SignInWithGoogle {}

class _MockSignOut extends Mock implements SignOut {}

class _FakeZipLevels implements ZipLevelRepository {
  _FakeZipLevels(this.special);

  final String? special;

  @override
  Future<ZipLevel> fetchDailyLevel(
    DateTime date, {
    Duration period = PlayPeriod.daily,
  }) async => ZipLevel(
    id: 'daily_${PlayPeriod.id(date, period)}',
    size: 8,
    numbers: {const Cell(0, 0): 1, const Cell(7, 7): 2},
    walls: const [],
    special: special,
  );

  @override
  Future<List<ZipLevel>> fetchLevels() async => const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<void> pumpHome(
    WidgetTester tester, {
    String? special,
    Map<String, Object> prefsValues = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefsValues);
    final prefs = await SharedPreferences.getInstance();
    const user = AppUser(uid: 'test', displayName: 'Tester');
    final auth = _MockAuthRepository();
    when(() => auth.currentUser).thenReturn(user);
    when(() => auth.authStateChanges()).thenAnswer((_) => Stream.value(user));
    final router = GoRouter(
      initialLocation: '/',
      routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())],
    );
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: buildRepositoryProviders(prefs: prefs),
        child: RepositoryProvider<ZipLevelRepository>.value(
          value: _FakeZipLevels(special),
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
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
  }

  testWidgets('a weekend special day marks every tile', (tester) async {
    await pumpHome(tester, special: 'weekend');
    expect(find.text(AppStrings.weekendSpecial), findsNWidgets(3));
    expect(find.text(AppStrings.today), findsNothing);
  });

  testWidgets('a weekday keeps the Today pill', (tester) async {
    await pumpHome(tester);
    expect(find.text(AppStrings.weekendSpecial), findsNothing);
    expect(find.text(AppStrings.today), findsNWidgets(3));
  });

  testWidgets('the badge fits a narrow tile next to a streak and a freeze', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final today = PlayPeriod.id(DateTime.now(), PlayPeriod.daily);
    await pumpHome(
      tester,
      special: 'weekend',
      prefsValues: {
        for (final game in ['zip', 'path_words', 'sudoku']) ...{
          'streak_current_$game': 123,
          'streak_longest_$game': 123,
          'streak_last_$game': today,
        },
      },
    );
    expect(find.text(AppStrings.weekendSpecial), findsNWidgets(3));
    expect(find.byTooltip(AppStrings.streakFreezeReady), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
