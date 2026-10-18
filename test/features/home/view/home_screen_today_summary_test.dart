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

  Future<void> pumpHome(WidgetTester tester, SharedPreferences prefs) async {
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

  testWidgets('Home has no summary before the first clear', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await pumpHome(tester, prefs);

    expect(find.textContaining(' of 3 cleared'), findsNothing);
  });

  testWidgets('Home sums up today above the tiles', (tester) async {
    final today = DateTime.now();
    final zipId = DailyPuzzleGenerator.dateId(today, period: PlayPeriod.daily);
    final sudokuId = PlayPeriod.id(today, PlayPeriod.daily);
    SharedPreferences.setMockInitialValues({
      'best_time_zip_$zipId': 42,
      'best_time_sudoku_$sudokuId': 100,
    });
    final prefs = await SharedPreferences.getInstance();

    await pumpHome(tester, prefs);

    expect(find.text('2 of 3 cleared · 2:22 total'), findsOneWidget);
    expect(find.text(AppStrings.homePerfectDayBadge), findsNothing);
  });
}
