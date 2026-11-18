import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/firebase/firebase_bootstrap.dart';
import 'package:winklo/data/repositories/profile_repository_impl.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/failures.dart';
import 'package:winklo/domain/game_ids.dart';

void main() {
  test('mapUserProfile reads name, photo, and avatar', () {
    final user = mapUserProfile('u1', {
      'displayName': ' Ada ',
      'photoUrl': 'https://example.com/a.jpg',
      'avatarId': 'preset_01',
    });
    expect(user?.uid, 'u1');
    expect(user?.displayName, 'Ada');
    expect(user?.photoUrl, 'https://example.com/a.jpg');
    expect(user?.avatarId, 'preset_01');
  });

  test('mapUserProfile returns null for a missing doc', () {
    expect(mapUserProfile('u1', null), isNull);
  });

  test('identity refresh covers every leaderboard game', () {
    expect(leaderboardIdentityGameIds, [
      GameIds.zip,
      GameIds.pathWords,
      GameIds.sudoku,
    ]);
  });

  test('identity refresh covers all-time, today and the Levels rows', () {
    expect(
      leaderboardIdentityDocPaths(
        root: 'leaderboards',
        uid: 'u1',
        dayId: '2026-11-18',
      ),
      [
        'leaderboards/zip/all_time/u1',
        'leaderboards/zip/daily/2026-11-18/entries/u1',
        'leaderboards/zip/levels/u1',
        'leaderboards/path_words/all_time/u1',
        'leaderboards/path_words/daily/2026-11-18/entries/u1',
        'leaderboards/sudoku/all_time/u1',
        'leaderboards/sudoku/daily/2026-11-18/entries/u1',
      ],
    );
  });

  test('leaderboardIdentityPatch omits updatedAt', () {
    final patch = leaderboardIdentityPatch(
      const AppUser(
        uid: 'u1',
        displayName: 'Ada',
        photoUrl: 'https://lh3.googleusercontent.com/a/photo=s96-c',
        avatarId: 'preset_01',
      ),
    );
    expect(patch.keys, ['displayName', 'photoUrl', 'avatarId']);
    expect(patch.containsKey('updatedAt'), isFalse);
    expect(
      patch['photoUrl'],
      'https://lh3.googleusercontent.com/a/photo=s96-c',
    );
    expect(patch['avatarId'], 'preset_01');
  });

  test('leaderboardIdentityPatch drops a photo host the rules reject', () {
    final patch = leaderboardIdentityPatch(
      const AppUser(
        uid: 'u1',
        displayName: 'Ada',
        photoUrl: 'https://example.com/a.jpg',
      ),
    );
    expect(patch['photoUrl'], isA<FieldValue>());
  });

  test('leaderboardIdentityPatch clears null photo and avatar', () {
    final patch = leaderboardIdentityPatch(
      const AppUser(uid: 'u1', displayName: 'Ada'),
    );
    expect(patch['displayName'], 'Ada');
    expect(patch['photoUrl'], isA<FieldValue>());
    expect(patch['avatarId'], isA<FieldValue>());
  });

  test('mapUserProfile treats blank photo and avatar as null', () {
    final user = mapUserProfile('u1', {
      'displayName': '',
      'photoUrl': '',
      'avatarId': '',
    });
    expect(user?.displayName, 'Player');
    expect(user?.photoUrl, isNull);
    expect(user?.avatarId, isNull);
  });

  group('ProfileRepositoryImpl when Firebase is not ready', () {
    late ProfileRepositoryImpl repo;

    setUp(() {
      FirebaseBootstrap.isReady = false;
      repo = ProfileRepositoryImpl();
    });

    test('watchProfile errors', () async {
      await expectLater(
        repo.watchProfile('u1'),
        emitsError(
          isA<Failure>().having(
            (f) => f.message,
            'message',
            contains('unavailable'),
          ),
        ),
      );
    });

    test('getProfile throws', () async {
      await expectLater(repo.getProfile('u1'), throwsA(isA<Failure>()));
    });

    test('updateDisplayName throws', () async {
      await expectLater(repo.updateDisplayName('Ada'), throwsA(isA<Failure>()));
    });

    test('updateAvatarPreset throws', () async {
      await expectLater(
        repo.updateAvatarPreset('preset_01'),
        throwsA(isA<Failure>()),
      );
    });

    test('updateAvatarPhoto throws', () async {
      await expectLater(
        repo.updateAvatarPhoto([1, 2, 3]),
        throwsA(isA<Failure>()),
      );
    });
  });
}
