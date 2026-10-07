import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/firebase/firebase_bootstrap.dart';
import 'package:winklo/data/repositories/leaderboard_repository_impl.dart';
import 'package:winklo/domain/entities/leaderboard_period.dart';
import 'package:winklo/domain/failures.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

void main() {
  group('mapLeaderboardRows', () {
    test('assigns ranks in row order and skips invalid times', () {
      final entries = mapLeaderboardRows([
        (id: 'a', data: {'timeSeconds': 12, 'displayName': 'Ada'}),
        (id: 'b', data: {'timeSeconds': 0, 'displayName': 'Bad'}),
        (id: 'c', data: {'timeSeconds': 15, 'displayName': 'Cam'}),
      ]);
      expect(entries, hasLength(2));
      expect(entries[0].uid, 'a');
      expect(entries[0].rank, 1);
      expect(entries[0].timeSeconds, 12);
      expect(entries[1].uid, 'c');
      expect(entries[1].rank, 2);
    });

    test('assigns dense ranks for equal timeSeconds', () {
      final entries = mapLeaderboardRows([
        (id: 'a', data: {'timeSeconds': 12, 'displayName': 'Siyadh'}),
        (id: 'b', data: {'timeSeconds': 15, 'displayName': 'Amal'}),
        (id: 'c', data: {'timeSeconds': 15, 'displayName': 'Anas'}),
        (id: 'd', data: {'timeSeconds': 20, 'displayName': 'Dev'}),
      ]);
      expect(entries.map((e) => e.rank).toList(), [1, 2, 2, 3]);
      expect(entries.map((e) => e.uid).toList(), ['a', 'b', 'c', 'd']);
    });

    test('parses avatarId', () {
      final entries = mapLeaderboardRows([
        (
          id: 'a',
          data: {
            'timeSeconds': 12,
            'displayName': 'Ada',
            'avatarId': 'preset_03',
          },
        ),
      ]);
      expect(entries.single.avatarId, 'preset_03');
    });

    test('parses usedHints, hadMistakes, and currentStreak', () {
      final entries = mapLeaderboardRows([
        (
          id: 'a',
          data: {
            'timeSeconds': 12,
            'displayName': 'Ada',
            'usedHints': false,
            'hadMistakes': true,
            'currentStreak': 7,
          },
        ),
        (id: 'b', data: {'timeSeconds': 15, 'displayName': 'Bob'}),
      ]);
      expect(entries[0].usedHints, isFalse);
      expect(entries[0].hadMistakes, isTrue);
      expect(entries[0].currentStreak, 7);
      expect(entries[1].usedHints, isNull);
      expect(entries[1].hadMistakes, isNull);
      expect(entries[1].currentStreak, isNull);
    });

    test('falls back to Player when displayName missing', () {
      final entries = mapLeaderboardRows([
        (id: 'x', data: {'timeSeconds': 9}),
      ]);
      expect(entries.single.displayName, 'Player');
    });
  });

  test('resolveLeaderboardIdentity prefers the Firestore profile', () {
    final identity = resolveLeaderboardIdentity(
      authDisplayName: 'Google',
      authPhotoUrl: 'https://example.com/g.jpg',
      profile: {
        'displayName': 'Ada',
        'photoUrl': null,
        'avatarId': 'preset_01',
      },
    );
    expect(identity.displayName, 'Ada');
    expect(identity.photoUrl, isNull);
    expect(identity.avatarId, 'preset_01');
  });

  group('leaderboardSubmitIdentity', () {
    test('returns null when profile document was not read', () {
      expect(
        leaderboardSubmitIdentity(
          profileDocumentRead: false,
          authDisplayName: 'Google',
          authPhotoUrl: 'https://example.com/g.jpg',
          profile: null,
        ),
        isNull,
      );
    });

    test('resolves identity when profile document was read', () {
      final identity = leaderboardSubmitIdentity(
        profileDocumentRead: true,
        authDisplayName: 'Google',
        authPhotoUrl: 'https://example.com/g.jpg',
        profile: {'avatarId': 'preset_03'},
      );
      expect(identity, isNotNull);
      expect(identity!.avatarId, 'preset_03');
    });
  });

  group('LeaderboardRepositoryImpl', () {
    test('watchBoard errors when Firebase is not ready', () async {
      FirebaseBootstrap.isReady = false;
      final repo = LeaderboardRepositoryImpl(firestore: null, auth: null);

      await expectLater(
        repo.watchBoard(gameId: 'zip', period: LeaderboardPeriod.allTime),
        emitsError(isA<Failure>()),
      );
    });

    test('submitBestTime rejects unsupported gameId', () async {
      FirebaseBootstrap.isReady = false;
      final repo = LeaderboardRepositoryImpl();
      expect(
        () => repo.submitBestTime(
          gameId: 'word_match',
          timeSeconds: 10,
          usedHints: false,
          hadMistakes: false,
          currentStreak: 2,
        ),
        throwsA(isA<Failure>()),
      );
    });

    test('submitBestTime rejects non-positive time', () async {
      FirebaseBootstrap.isReady = false;
      final repo = LeaderboardRepositoryImpl();
      expect(
        () => repo.submitBestTime(
          gameId: 'zip',
          timeSeconds: 0,
          usedHints: false,
          hadMistakes: false,
          currentStreak: 2,
        ),
        throwsA(isA<Failure>()),
      );
    });

    test('submitBestTime rejects a malformed dayId', () async {
      final wasReady = FirebaseBootstrap.isReady;
      addTearDown(() => FirebaseBootstrap.isReady = wasReady);
      FirebaseBootstrap.isReady = false;
      final repo = LeaderboardRepositoryImpl();
      for (final bad in ['20261007', '2026-10-7', '', 'today']) {
        await expectLater(
          repo.submitBestTime(
            gameId: 'zip',
            timeSeconds: 10,
            usedHints: false,
            hadMistakes: false,
            currentStreak: 2,
            dayId: bad,
          ),
          throwsA(
            isA<Failure>().having((f) => f.message, 'message', contains('day')),
          ),
          reason: bad,
        );
      }
    });

    test('submitBestTime with a valid dayId still needs sign-in', () async {
      final wasReady = FirebaseBootstrap.isReady;
      addTearDown(() => FirebaseBootstrap.isReady = wasReady);
      FirebaseBootstrap.isReady = false;
      final repo = LeaderboardRepositoryImpl();
      await expectLater(
        repo.submitBestTime(
          gameId: 'sudoku',
          timeSeconds: 10,
          usedHints: false,
          hadMistakes: true,
          currentStreak: 2,
          dayId: '2026-10-07',
        ),
        throwsA(
          isA<Failure>().having(
            (f) => f.message,
            'message',
            contains('Sign in'),
          ),
        ),
      );
    });

    test(
      'submitBestTime refuses a run for another account before any I/O',
      () async {
        final wasReady = FirebaseBootstrap.isReady;
        addTearDown(() => FirebaseBootstrap.isReady = wasReady);
        FirebaseBootstrap.isReady = true;
        final firestore = _MockFirestore();
        final auth = _MockFirebaseAuth();
        final user = _MockUser();
        when(() => user.uid).thenReturn('u2');
        when(() => auth.currentUser).thenReturn(user);
        final repo = LeaderboardRepositoryImpl(
          firestore: firestore,
          auth: auth,
        );

        await expectLater(
          repo.submitBestTime(
            gameId: 'zip',
            timeSeconds: 10,
            usedHints: false,
            hadMistakes: false,
            currentStreak: 2,
            dayId: '2026-10-07',
            expectedUid: 'u1',
          ),
          throwsA(isA<Failure>()),
        );
        verifyZeroInteractions(firestore);
      },
    );
  });

  group('leaderboardImprovePayload', () {
    const identity = (
      displayName: 'Ada',
      photoUrl: null as String?,
      avatarId: 'preset_01' as String?,
    );

    test('writes only whitelisted keys, all of them on an improve', () {
      final payload = leaderboardImprovePayload(
        timeImproved: true,
        timeSeconds: 12,
        usedHints: false,
        hadMistakes: true,
        currentStreak: 3,
        identity: identity,
      );
      expect(payload.keys.toSet(), leaderboardFirestoreKeys);
      expect(payload['timeSeconds'], 12);
      expect(payload['hadMistakes'], isTrue);
      expect(payload['avatarId'], 'preset_01');
    });

    test('a slower time only refreshes the streak', () {
      final payload = leaderboardImprovePayload(
        timeImproved: false,
        timeSeconds: 40,
        usedHints: true,
        hadMistakes: false,
        currentStreak: 4,
      );
      expect(payload, {'currentStreak': 4});
    });
  });
}
