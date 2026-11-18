// Mocks of the sealed Firestore reference types, as mocktail needs them.
// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/firebase/firebase_bootstrap.dart';
import 'package:winklo/data/clients/leaderboard/leaderboard_skip_log.dart';
import 'package:winklo/data/clients/leaderboard/leaderboard_submit_client.dart';
import 'package:winklo/data/repositories/leaderboard_repository_impl.dart';
import 'package:winklo/domain/entities/cell.dart';
import 'package:winklo/domain/entities/leaderboard_proof.dart';
import 'package:winklo/domain/failures.dart';
import 'package:winklo/domain/repositories/leaderboard_repository.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockDoc extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class _MockSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

class _MockSubmitClient extends Mock implements LeaderboardSubmitClient {}

class _FakeSkipLog implements LeaderboardSkipLog {
  final skips = <LeaderboardSkip>[];

  @override
  Future<void> record(LeaderboardSkip skip) async => skips.add(skip);
}

// ignore: prefer_void_to_null
typedef _TxResult = Null;

const _proof = ZipLeaderboardProof([Cell(0, 0), Cell(0, 1)]);

/// Today in the tests' clock, so the day is live.
final _now = DateTime.utc(2026, 10, 15, 12);

void main() {
  late _MockFirestore firestore;
  late _MockFirebaseAuth auth;
  late _MockUser user;
  late _MockSubmitClient client;
  late _MockSnapshot snapshot;
  late _MockDoc docRef;
  late _FakeSkipLog skipLog;
  late List<Object> rejected;

  setUpAll(() {
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    final wasReady = FirebaseBootstrap.isReady;
    addTearDown(() => FirebaseBootstrap.isReady = wasReady);
    FirebaseBootstrap.isReady = true;

    firestore = _MockFirestore();
    final collection = _MockCollection();
    docRef = _MockDoc();
    snapshot = _MockSnapshot();
    when(() => firestore.collection(any())).thenReturn(collection);
    when(() => collection.doc(any())).thenReturn(docRef);
    when(() => docRef.collection(any())).thenReturn(collection);
    when(() => docRef.get()).thenAnswer((_) async => snapshot);
    when(() => docRef.firestore).thenReturn(firestore);
    when(
      () => snapshot.data(),
    ).thenReturn({'displayName': 'Ada', 'avatarId': 'preset_01'});
    // The improve-only write's callback returns nothing, so T is Null.
    when(
      () => firestore.runTransaction<_TxResult>(any()),
    ).thenAnswer((_) async => null);

    auth = _MockFirebaseAuth();
    user = _MockUser();
    when(() => user.uid).thenReturn('u1');
    when(() => user.displayName).thenReturn('Ada G');
    when(() => user.photoURL).thenReturn(null);
    when(() => user.getIdToken(any())).thenAnswer((_) async => 'id-token');
    when(() => auth.currentUser).thenReturn(user);

    client = _MockSubmitClient();
    skipLog = _FakeSkipLog();
    rejected = [];
  });

  LeaderboardRepositoryImpl repo({bool debug = false}) =>
      LeaderboardRepositoryImpl(
        firestore: firestore,
        auth: auth,
        submitClient: client,
        skipLog: skipLog,
        isDebugMode: debug,
        now: () => _now,
        reportRejected: (e, _) => rejected.add(e),
      );

  void verifyNoDirectWrite() =>
      verifyNever(() => firestore.runTransaction<_TxResult>(any()));

  Future<LevelClearSubmitOutcome> send(
    LeaderboardRepositoryImpl r, {
    String expectedUid = 'u1',
  }) => r.submitLevelClear(
    gameId: 'zip',
    levelId: 'w1_l3',
    timeSeconds: 42,
    usedHints: true,
    proof: _proof,
    expectedUid: expectedUid,
  );

  void stubClient(Future<LeaderboardSubmitResult> Function() answer) {
    when(
      () => client.submitLevelClear(
        idToken: any(named: 'idToken'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) => answer());
  }

  void verifyNeverSent() => verifyNever(
    () => client.submitLevelClear(
      idToken: any(named: 'idToken'),
      body: any(named: 'body'),
    ),
  );

  test('release posts the body to the Worker and returns sent', () async {
    stubClient(() async => const LeaderboardSubmitResult(improved: true));

    expect(await send(repo()), LevelClearSubmitOutcome.sent);

    final body =
        verify(
              () => client.submitLevelClear(
                idToken: 'id-token',
                body: captureAny(named: 'body'),
              ),
            ).captured.single
            as Map<String, Object?>;
    expect(body, {
      'gameId': 'zip',
      'levelId': 'w1_l3',
      'timeSeconds': 42,
      'usedHints': true,
      'proof': {
        'path': [
          [0, 0],
          [0, 1],
        ],
      },
      'displayName': 'Ada',
      'photoUrl': null,
      'avatarId': 'preset_01',
    });
    verifyNoDirectWrite();
  });

  test('an unavailable Worker is unavailable, with no direct write', () async {
    stubClient(() async => throw const LeaderboardSubmitUnavailable('503'));

    expect(await send(repo()), LevelClearSubmitOutcome.unavailable);
    verifyNoDirectWrite();
  });

  test('no ID token is unavailable, with no direct write', () async {
    when(() => user.getIdToken(any())).thenThrow(Exception('offline'));

    expect(await send(repo()), LevelClearSubmitOutcome.unavailable);
    verifyNeverSent();
    verifyNoDirectWrite();
  });

  test(
    'a 422 refusal throws LeaderboardSubmitRefused and is reported',
    () async {
      stubClient(
        () async => throw const LeaderboardSubmitRejected(422, 'bad_proof'),
      );

      await expectLater(
        send(repo()),
        throwsA(
          isA<LeaderboardSubmitRefused>().having(
            (e) => e.code,
            'code',
            'bad_proof',
          ),
        ),
      );
      expect(rejected.single, isA<LeaderboardSubmitRejected>());
      verifyNoDirectWrite();
    },
  );

  test('a stale token is retried once with a fresh one', () async {
    var calls = 0;
    stubClient(() async {
      if (calls++ == 0) {
        throw const LeaderboardSubmitRejected(401, 'unauthorized');
      }
      return const LeaderboardSubmitResult(improved: false);
    });

    expect(await send(repo()), LevelClearSubmitOutcome.sent);
    verify(() => user.getIdToken(false)).called(1);
    verify(() => user.getIdToken(true)).called(1);
  });

  test('a token the Worker keeps refusing is unavailable', () async {
    stubClient(
      () async => throw const LeaderboardSubmitRejected(401, 'unauthorized'),
    );

    expect(await send(repo()), LevelClearSubmitOutcome.unavailable);
    verifyNoDirectWrite();
  });

  test('a debug root is notSent and never calls the client', () async {
    expect(await send(repo(debug: true)), LevelClearSubmitOutcome.notSent);
    verifyNeverSent();
  });

  test('no client is notSent', () async {
    final noClient = LeaderboardRepositoryImpl(
      firestore: firestore,
      auth: auth,
      isDebugMode: false,
      now: () => _now,
    );
    expect(await send(noClient), LevelClearSubmitOutcome.notSent);
    verifyNeverSent();
  });

  test('signed out is notSent', () async {
    when(() => auth.currentUser).thenReturn(null);
    expect(await send(repo()), LevelClearSubmitOutcome.notSent);
    verifyNeverSent();
  });

  test('another signed-in account throws before posting', () async {
    await expectLater(
      send(repo(), expectedUid: 'someone-else'),
      throwsA(isA<Failure>()),
    );
    verifyNeverSent();
  });

  test('the profile name is posted, not the auth name', () async {
    when(
      () => snapshot.data(),
    ).thenReturn({'displayName': 'Renamed', 'avatarId': 'preset_07'});
    stubClient(() async => const LeaderboardSubmitResult(improved: true));

    await send(repo());

    final body =
        verify(
              () => client.submitLevelClear(
                idToken: any(named: 'idToken'),
                body: captureAny(named: 'body'),
              ),
            ).captured.single
            as Map<String, Object?>;
    expect(body['displayName'], 'Renamed');
    expect(body['avatarId'], 'preset_07');
  });

  test('an account switch during the profile read throws before '
      'posting', () async {
    when(() => docRef.get()).thenAnswer((_) async {
      when(() => user.uid).thenReturn('u2');
      return snapshot;
    });

    await expectLater(send(repo()), throwsA(isA<Failure>()));
    verifyNeverSent();
  });
}
