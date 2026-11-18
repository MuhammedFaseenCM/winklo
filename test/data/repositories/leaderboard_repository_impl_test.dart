// Mocks of the sealed Firestore reference types, as mocktail needs them.
// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/firebase/firebase_bootstrap.dart';
import 'package:winklo/data/repositories/leaderboard_repository_impl.dart';
import 'package:winklo/domain/entities/leaderboard_period.dart';
import 'package:winklo/domain/failures.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockDoc extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class _MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class _MockSnap extends Mock implements QuerySnapshot<Map<String, dynamic>> {}

class _MockDocSnap extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

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

  test('resolveLeaderboardIdentity keeps values inside the rules', () {
    final google = resolveLeaderboardIdentity(
      authDisplayName: 'A' * 60,
      authPhotoUrl: 'https://lh3.googleusercontent.com/a/photo=s96-c',
    );
    expect(google.displayName, 'A' * 40);
    expect(google.photoUrl, 'https://lh3.googleusercontent.com/a/photo=s96-c');

    final elsewhere = resolveLeaderboardIdentity(
      authDisplayName: 'Ada',
      authPhotoUrl: 'https://example.com/g.jpg',
    );
    expect(elsewhere.photoUrl, isNull);
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

  group('mapLevelsLeaderboardRows', () {
    test('reads stars, levels and total time with dense ranks', () {
      final entries = mapLevelsLeaderboardRows([
        (
          id: 'a',
          data: {
            'stars': 12,
            'levelsCleared': 6,
            'timeSeconds': 99,
            'displayName': 'Ada',
            'photoUrl': 'https://x/p.png',
            'avatarId': 'preset_03',
            'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 15)),
          },
        ),
        (id: 'b', data: {'stars': 12, 'levelsCleared': 6, 'timeSeconds': 99}),
        (id: 'c', data: {'stars': 9, 'levelsCleared': 3, 'timeSeconds': 60}),
      ]);
      expect(entries.map((e) => e.rank), [1, 1, 2]);
      final first = entries.first;
      expect(first.stars, 12);
      expect(first.levelsCleared, 6);
      expect(first.timeSeconds, 99);
      expect(first.displayName, 'Ada');
      expect(first.photoUrl, 'https://x/p.png');
      expect(first.avatarId, 'preset_03');
      expect(first.updatedAt.toUtc(), DateTime.utc(2026, 10, 15));
    });

    test('a row without identity falls back and does not crash', () {
      final entry = mapLevelsLeaderboardRows([
        (id: 'b', data: {'stars': 3, 'levelsCleared': 1, 'timeSeconds': 20}),
      ]).single;
      expect(entry.displayName, 'Player');
      expect(entry.photoUrl, isNull);
      expect(entry.avatarId, isNull);
      expect(entry.updatedAt.millisecondsSinceEpoch, 0);
    });

    test('skips rows without stars, levels or a total', () {
      final entries = mapLevelsLeaderboardRows([
        (id: 'a', data: {'levelsCleared': 1, 'timeSeconds': 10}),
        (id: 'b', data: {'stars': 3, 'levelsCleared': 0, 'timeSeconds': 10}),
        (id: 'c', data: {'stars': '3', 'levelsCleared': 1, 'timeSeconds': 10}),
        (id: 'd', data: {'stars': 0, 'levelsCleared': 1, 'timeSeconds': 30}),
      ]);
      expect(entries.map((e) => e.uid), ['d']);
    });
  });

  group('LeaderboardRepositoryImpl levels board', () {
    late _MockFirestore firestore;
    late _MockCollection collection;
    late _MockQuery query;
    late _MockSnap snap;
    late bool wasReady;

    _MockDocSnap row(String id, Map<String, dynamic> data) {
      final doc = _MockDocSnap();
      when(() => doc.id).thenReturn(id);
      when(doc.data).thenReturn(data);
      return doc;
    }

    setUpAll(() {
      registerFallbackValue(FieldPath.documentId);
    });

    setUp(() {
      wasReady = FirebaseBootstrap.isReady;
      FirebaseBootstrap.isReady = true;
      firestore = _MockFirestore();
      collection = _MockCollection();
      query = _MockQuery();
      snap = _MockSnap();
      final doc = _MockDoc();
      when(() => firestore.collection(any())).thenReturn(collection);
      when(() => collection.doc(any())).thenReturn(doc);
      when(() => doc.collection(any())).thenReturn(collection);
      when(
        () => collection.orderBy(
          any<Object>(),
          descending: any(named: 'descending'),
        ),
      ).thenReturn(query);
      when(
        () =>
            query.orderBy(any<Object>(), descending: any(named: 'descending')),
      ).thenReturn(query);
      when(() => query.limit(any())).thenReturn(query);
      when(() => query.snapshots()).thenAnswer((_) => Stream.value(snap));
      when(
        () => collection.where(any<Object>(), whereIn: any(named: 'whereIn')),
      ).thenReturn(query);
    });

    tearDown(() => FirebaseBootstrap.isReady = wasReady);

    LeaderboardRepositoryImpl repo({bool debug = false}) =>
        LeaderboardRepositoryImpl(
          firestore: firestore,
          auth: _MockFirebaseAuth(),
          isDebugMode: debug,
        );

    test('watchBoard queries the levels collection in board order', () async {
      final docs = [
        row('a', {'stars': 9, 'levelsCleared': 3, 'timeSeconds': 60}),
      ];
      when(() => snap.docs).thenReturn(docs);

      final entries = await repo()
          .watchBoard(gameId: 'zip', period: LeaderboardPeriod.levels)
          .first;

      expect(entries.single.uid, 'a');
      expect(entries.single.stars, 9);
      expect(entries.single.levelsCleared, 3);
      verifyInOrder([
        () => firestore.collection('leaderboards'),
        () => collection.doc('zip'),
        () => collection.orderBy('stars', descending: true),
        () => query.orderBy('levelsCleared', descending: false),
        () => query.orderBy('timeSeconds', descending: false),
        () => query.orderBy('updatedAt', descending: false),
        () => query.limit(50),
      ]);
    });

    test('watchBoard on a debug root is empty and reads nothing', () async {
      final entries = await repo(
        debug: true,
      ).watchBoard(gameId: 'zip', period: LeaderboardPeriod.levels).first;
      expect(entries, isEmpty);
      verifyNever(() => query.snapshots());
    });

    test('watchMembersBoard ranks the members rows on the phone', () async {
      final docs = [
        row('a', {'stars': 9, 'levelsCleared': 3, 'timeSeconds': 60}),
        row('b', {'stars': 9, 'levelsCleared': 5, 'timeSeconds': 40}),
        row('c', {'stars': 12, 'levelsCleared': 6, 'timeSeconds': 99}),
      ];
      when(() => snap.docs).thenReturn(docs);

      final entries = await repo()
          .watchMembersBoard(
            gameId: 'zip',
            period: LeaderboardPeriod.levels,
            memberUids: const ['a', 'b', 'c'],
          )
          .first;

      expect(entries.map((e) => e.uid), ['c', 'a', 'b']);
      expect(entries.map((e) => e.rank), [1, 2, 3]);
      verify(
        () => collection.where(any<Object>(), whereIn: ['a', 'b', 'c']),
      ).called(1);
    });

    test('watchMembersBoard on a debug root is empty', () async {
      final entries = await repo(debug: true)
          .watchMembersBoard(
            gameId: 'zip',
            period: LeaderboardPeriod.levels,
            memberUids: const ['a'],
          )
          .first;
      expect(entries, isEmpty);
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
