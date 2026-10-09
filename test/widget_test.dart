import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:winklo/app.dart';
import 'package:winklo/core/dev_flags.dart';
import 'package:winklo/core/di/app_repositories.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/streak_calculator.dart';

import 'package:mocktail/mocktail.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/entities/cell.dart';
import 'package:winklo/domain/entities/path_words_puzzle.dart';
import 'package:winklo/domain/usecases/generate_daily_path_words.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/usecases/sign_in_with_google.dart';
import 'package:winklo/domain/usecases/sign_out.dart';
import 'package:winklo/features/auth/cubit/auth_cubit.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockSignInWithGoogle extends Mock implements SignInWithGoogle {}

class _MockSignOut extends Mock implements SignOut {}

/// Daily puzzles come only from Firestore, which tests don't have.
class _FixedPathWords extends GenerateDailyPathWords {
  @override
  Future<PathWordsPuzzle> call({required DateTime day}) async {
    return PathWordsPuzzle(
      id: 'daily_test',
      day: day,
      size: 2,
      letters: const ['a', 'b', 'c', 'd'],
      targets: const [
        PathWordsTarget(
          id: 't0',
          word: 'ab',
          start: Cell(0, 0),
          path: [Cell(0, 0), Cell(0, 1)],
          colorIndex: 0,
        ),
      ],
    );
  }
}

Widget _buildTestApp(SharedPreferences prefs, {AppUser? authUser}) {
  final baseProviders = [
    ...buildRepositoryProviders(prefs: prefs),
    RepositoryProvider<GenerateDailyPathWords>.value(value: _FixedPathWords()),
  ];
  if (authUser != null) {
    final mockAuth = _MockAuthRepository();
    when(() => mockAuth.currentUser).thenReturn(authUser);
    when(
      () => mockAuth.authStateChanges(),
    ).thenAnswer((_) => Stream.value(authUser));
    return MultiRepositoryProvider(
      providers: [
        ...baseProviders,
        RepositoryProvider<AuthRepository>.value(value: mockAuth),
      ],
      child: BlocProvider(
        create: (context) => AuthCubit(
          authRepository: mockAuth,
          signInWithGoogle: _MockSignInWithGoogle(),
          signOut: _MockSignOut(),
        ),
        child: const WinkloApp(),
      ),
    );
  }

  return MultiRepositoryProvider(
    providers: baseProviders,
    child: BlocProvider(
      create: (context) => AuthCubit(
        authRepository: context.read<AuthRepository>(),
        signInWithGoogle: context.read<SignInWithGoogle>(),
        signOut: context.read<SignOut>(),
      ),
      child: const WinkloApp(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Winklo',
      packageName: 'com.winklo.faseencm',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  testWidgets('Home shows Winklo brand and daily CTAs', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_buildTestApp(prefs));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text(AppStrings.appTitle), findsOneWidget);
    expect(find.text(AppStrings.homeTagline), findsOneWidget);
    expect(find.text(AppStrings.zipTitle), findsOneWidget);
    expect(find.text(AppStrings.playTodaysZip), findsOneWidget);
    if (DevFlags.zipOnlyTesting) {
      expect(find.text(AppStrings.pathWordsTitle), findsNothing);
      expect(find.text(AppStrings.playTodaysPathWords), findsNothing);
      expect(find.text(AppStrings.today), findsOneWidget);
    } else {
      expect(find.text(AppStrings.pathWordsTitle), findsOneWidget);
      expect(find.text(AppStrings.playTodaysPathWords), findsOneWidget);
      expect(find.text(AppStrings.today), findsNWidgets(3));
    }
    expect(find.text('Choose a puzzle'), findsNothing);
    expect(find.text('Parked for later'), findsNothing);
    expect(find.text(AppStrings.wordMatch), findsNothing);
    expect(find.text(AppStrings.categoryRace), findsNothing);
  });

  testWidgets('Home shows Path Words streak independently of Zip', (
    tester,
  ) async {
    if (DevFlags.zipOnlyTesting) return;
    final todayId = StreakCalculator.dateId(DateTime.now());
    SharedPreferences.setMockInitialValues({
      'streak_current_${GameIds.pathWords}': 3,
      'streak_longest_${GameIds.pathWords}': 5,
      'streak_last_${GameIds.pathWords}': todayId,
      'best_pts_path_words_$todayId': 18,
      'best_time_path_words_$todayId': 29,
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      _buildTestApp(
        prefs,
        authUser: const AppUser(uid: 'u1', displayName: 'Tester'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text(AppStrings.streakLabel(3)), findsOneWidget);
    expect(find.textContaining(AppStrings.longestStreakLabel(5)), findsNothing);
    expect(find.text(AppStrings.cleared), findsNothing);
    expect(find.text(AppStrings.result), findsOneWidget);
    expect(find.text(AppStrings.comeBackTomorrow), findsNothing);
    expect(find.text(AppStrings.playAgain), findsNothing);
    expect(find.text(AppStrings.playTodaysPathWords), findsNothing);
    expect(find.text(AppStrings.playTodaysZip), findsOneWidget);

    await tester.tap(find.text(AppStrings.result));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text(AppStrings.pathWordsClearedTitle), findsNothing);
    expect(find.text(AppStrings.newPuzzleUnlocksTomorrow), findsNothing);
    expect(find.text(AppStrings.backHome), findsNothing);
    expect(find.text(AppStrings.pathWordsTitle), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is GameWidget), findsOneWidget);
    expect(find.text(AppStrings.pathWordsUndo), findsNothing);
  });
}
