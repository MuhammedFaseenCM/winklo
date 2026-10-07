import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/progress_local_repository_impl.dart';
import 'package:winklo/data/repositories/score_repository_impl.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/entities/leaderboard_entry.dart';
import 'package:winklo/domain/entities/leaderboard_period.dart';
import 'package:winklo/domain/failures.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/repositories/leaderboard_repository.dart';
import 'package:winklo/domain/usecases/ensure_signed_in.dart';
import 'package:winklo/domain/usecases/sign_in_with_google.dart';
import 'package:winklo/domain/usecases/sign_out.dart';
import 'package:winklo/domain/usecases/submit_leaderboard_time.dart';
import 'package:winklo/domain/usecases/watch_leaderboard.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockLeaderboardRepository extends Mock
    implements LeaderboardRepository {}

void main() {
  const user = AppUser(uid: 'u1', displayName: 'Ada', photoUrl: 'https://x');

  group('leaderboardDayId', () {
    test('formats local calendar day as yyyy-MM-dd', () {
      expect(leaderboardDayId(DateTime(2026, 9, 24, 23, 30)), '2026-09-24');
    });
  });

  group('auth usecases', () {
    late _MockAuthRepository auth;

    setUp(() {
      auth = _MockAuthRepository();
    });

    test('SignInWithGoogle forwards to repository', () async {
      when(() => auth.signInWithGoogle()).thenAnswer((_) async => user);
      expect(await SignInWithGoogle(auth)(), user);
      verify(() => auth.signInWithGoogle()).called(1);
    });

    test('SignOut forwards to repository', () async {
      when(() => auth.signOut()).thenAnswer((_) async {});
      await SignOut(auth)();
      verify(() => auth.signOut()).called(1);
    });

    test('EnsureSignedIn returns current user when signed in', () async {
      when(() => auth.currentUser).thenReturn(user);
      expect(await EnsureSignedIn(auth)(), user);
      verifyNever(() => auth.signInWithGoogle());
    });

    test('EnsureSignedIn signs in when signed out', () async {
      when(() => auth.currentUser).thenReturn(null);
      when(() => auth.signInWithGoogle()).thenAnswer((_) async => user);
      expect(await EnsureSignedIn(auth)(), user);
      verify(() => auth.signInWithGoogle()).called(1);
    });
  });

  group('leaderboard usecases', () {
    late _MockLeaderboardRepository repo;

    setUp(() {
      repo = _MockLeaderboardRepository();
    });

    test('WatchLeaderboard forwards params', () async {
      final entries = [
        LeaderboardEntry(
          uid: 'u1',
          displayName: 'Ada',
          timeSeconds: 10,
          updatedAt: DateTime.utc(2026, 9, 24),
          rank: 1,
        ),
      ];
      when(
        () => repo.watchBoard(
          gameId: 'zip',
          period: LeaderboardPeriod.daily,
          dayId: '2026-09-24',
        ),
      ).thenAnswer((_) => Stream.value(entries));

      final stream = WatchLeaderboard(repo)(
        gameId: 'zip',
        period: LeaderboardPeriod.daily,
        dayId: '2026-09-24',
      );
      expect(await stream.first, entries);
    });

    test('SubmitLeaderboardTime forwards params', () async {
      when(
        () => repo.submitBestTime(
          gameId: 'path_words',
          timeSeconds: 42,
          usedHints: false,
          hadMistakes: false,
          currentStreak: 4,
        ),
      ).thenAnswer((_) async {});

      await SubmitLeaderboardTime(repo)(
        gameId: 'path_words',
        timeSeconds: 42,
        usedHints: false,
        hadMistakes: false,
        currentStreak: 4,
      );
      verify(
        () => repo.submitBestTime(
          gameId: 'path_words',
          timeSeconds: 42,
          usedHints: false,
          hadMistakes: false,
          currentStreak: 4,
        ),
      ).called(1);
    });

    test('SubmitLeaderboardTime forwards dayId', () async {
      when(
        () => repo.submitBestTime(
          gameId: 'sudoku',
          timeSeconds: 42,
          usedHints: false,
          hadMistakes: true,
          currentStreak: 1,
          dayId: '2026-10-07',
        ),
      ).thenAnswer((_) async {});

      await SubmitLeaderboardTime(repo)(
        gameId: 'sudoku',
        timeSeconds: 42,
        usedHints: false,
        hadMistakes: true,
        currentStreak: 1,
        dayId: '2026-10-07',
      );
      verify(
        () => repo.submitBestTime(
          gameId: 'sudoku',
          timeSeconds: 42,
          usedHints: false,
          hadMistakes: true,
          currentStreak: 1,
          dayId: '2026-10-07',
        ),
      ).called(1);
    });

    group('SubmitLeaderboardTime sync marker', () {
      late SharedPreferences prefs;
      late ProgressLocalRepositoryImpl progress;
      late SubmitLeaderboardTime submit;

      void stubRepo() {
        when(
          () => repo.submitBestTime(
            gameId: any(named: 'gameId'),
            timeSeconds: any(named: 'timeSeconds'),
            usedHints: any(named: 'usedHints'),
            hadMistakes: any(named: 'hadMistakes'),
            currentStreak: any(named: 'currentStreak'),
            dayId: any(named: 'dayId'),
          ),
        ).thenAnswer((_) async {});
      }

      Future<void> run(int time) => submit(
        gameId: 'zip',
        timeSeconds: time,
        usedHints: false,
        hadMistakes: false,
        currentStreak: 1,
        dayId: '2026-10-07',
        playId: '20261007',
      );

      setUp(() async {
        SharedPreferences.setMockInitialValues({
          'best_time_zip_daily_20261007': 30,
        });
        prefs = await SharedPreferences.getInstance();
        progress = ProgressLocalRepositoryImpl(prefs);
        submit = SubmitLeaderboardTime(
          repo,
          scores: ScoreRepositoryImpl(prefs),
          progress: progress,
        );
      });

      test('records the leaderboard marker for the stored best', () async {
        stubRepo();

        await run(30);

        expect(progress.pushedSignature('lb_zip_20261007'), '30');
      });

      test('a slower replay keeps the best time marker', () async {
        stubRepo();
        await progress.setPushedSignature('lb_zip_20261007', '30');

        await run(45);

        expect(progress.pushedSignature('lb_zip_20261007'), '30');
      });

      test('a failed submit records no marker', () async {
        when(
          () => repo.submitBestTime(
            gameId: any(named: 'gameId'),
            timeSeconds: any(named: 'timeSeconds'),
            usedHints: any(named: 'usedHints'),
            hadMistakes: any(named: 'hadMistakes'),
            currentStreak: any(named: 'currentStreak'),
            dayId: any(named: 'dayId'),
          ),
        ).thenThrow(const Failure('rules'));

        await expectLater(run(30), throwsA(isA<Failure>()));

        expect(progress.pushedSignature('lb_zip_20261007'), isNull);
      });

      test('without a playId no marker is written', () async {
        stubRepo();

        await submit(
          gameId: 'zip',
          timeSeconds: 30,
          usedHints: false,
          hadMistakes: false,
          currentStreak: 1,
        );

        expect(progress.pushedSignature('lb_zip_20261007'), isNull);
      });
    });
  });
}
