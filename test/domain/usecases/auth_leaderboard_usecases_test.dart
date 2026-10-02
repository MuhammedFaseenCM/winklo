import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/entities/leaderboard_entry.dart';
import 'package:winklo/domain/entities/leaderboard_period.dart';
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
        ),
      ).thenAnswer((_) async {});

      await SubmitLeaderboardTime(repo)(
        gameId: 'path_words',
        timeSeconds: 42,
        usedHints: false,
        hadMistakes: false,
      );
      verify(
        () => repo.submitBestTime(
          gameId: 'path_words',
          timeSeconds: 42,
          usedHints: false,
          hadMistakes: false,
        ),
      ).called(1);
    });
  });
}
