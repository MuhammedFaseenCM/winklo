import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/firebase/firebase_bootstrap.dart';
import 'package:winklo/data/repositories/leaderboard_repository_impl.dart';
import 'package:winklo/domain/entities/leaderboard_period.dart';
import 'package:winklo/domain/failures.dart';

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
        () => repo.submitBestTime(gameId: 'word_match', timeSeconds: 10),
        throwsA(isA<Failure>()),
      );
    });

    test('submitBestTime rejects non-positive time', () async {
      FirebaseBootstrap.isReady = false;
      final repo = LeaderboardRepositoryImpl();
      expect(
        () => repo.submitBestTime(gameId: 'zip', timeSeconds: 0),
        throwsA(isA<Failure>()),
      );
    });
  });
}
