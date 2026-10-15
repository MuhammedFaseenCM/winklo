// Mocks of the sealed Firestore reference types, as mocktail needs them.
// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/firebase/firebase_bootstrap.dart';
import 'package:winklo/data/clients/leaderboard/leaderboard_submit_client.dart';
import 'package:winklo/data/repositories/leaderboard_repository_impl.dart';
import 'package:winklo/domain/entities/cell.dart';
import 'package:winklo/domain/entities/leaderboard_proof.dart';
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

// ignore: prefer_void_to_null
typedef _TxResult = Null;

const _proof = ZipLeaderboardProof([Cell(0, 0), Cell(0, 1)]);

/// Today in the tests' clock, so the day is live.
final _now = DateTime.utc(2026, 10, 15, 12);
const _day = '2026-10-15';

void main() {
  late _MockFirestore firestore;
  late _MockFirebaseAuth auth;
  late _MockUser user;
  late _MockSubmitClient client;
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
    final docRef = _MockDoc();
    final snapshot = _MockSnapshot();
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
    rejected = [];
  });

  LeaderboardRepositoryImpl repo({bool debug = false}) =>
      LeaderboardRepositoryImpl(
        firestore: firestore,
        auth: auth,
        submitClient: client,
        isDebugMode: debug,
        now: () => _now,
        reportRejected: (e, _) => rejected.add(e),
      );

  Future<void> submit(
    LeaderboardRepositoryImpl r, {
    int time = 42,
    String? day = _day,
    LeaderboardProof? proof = _proof,
  }) => r.submitBestTime(
    gameId: 'zip',
    timeSeconds: time,
    usedHints: false,
    hadMistakes: false,
    currentStreak: 3,
    dayId: day,
    proof: proof,
  );

  void verifyNoDirectWrite() =>
      verifyNever(() => firestore.runTransaction<_TxResult>(any()));

  test('release builds post the clear to the Worker only', () async {
    when(
      () => client.submit(
        idToken: any(named: 'idToken'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async => const LeaderboardSubmitResult(improved: true));

    await submit(repo());

    final body =
        verify(
              () => client.submit(
                idToken: 'id-token',
                body: captureAny(named: 'body'),
              ),
            ).captured.single
            as Map<String, Object?>;
    expect(body, {
      'gameId': 'zip',
      'dayId': _day,
      'timeSeconds': 42,
      'usedHints': false,
      'hadMistakes': false,
      'currentStreak': 3,
      'displayName': 'Ada',
      'photoUrl': null,
      'avatarId': 'preset_01',
      'proof': {
        'path': [
          [0, 0],
          [0, 1],
        ],
      },
    });
    verifyNoDirectWrite();
  });

  test('falls back to the direct writes when the Worker is down', () async {
    when(
      () => client.submit(
        idToken: any(named: 'idToken'),
        body: any(named: 'body'),
      ),
    ).thenThrow(const LeaderboardSubmitUnavailable('HTTP 503'));

    await submit(repo());

    // All-time, then daily.
    verify(() => firestore.runTransaction<_TxResult>(any())).called(2);
    expect(rejected, isEmpty);
  });

  test('falls back when no ID token is available', () async {
    when(() => user.getIdToken(any())).thenThrow(Exception('offline'));

    await submit(repo());

    verifyNever(
      () => client.submit(
        idToken: any(named: 'idToken'),
        body: any(named: 'body'),
      ),
    );
    verify(() => firestore.runTransaction<_TxResult>(any())).called(2);
  });

  test('a refusal is final: reported, thrown, and not written', () async {
    when(
      () => client.submit(
        idToken: any(named: 'idToken'),
        body: any(named: 'body'),
      ),
    ).thenThrow(const LeaderboardSubmitRejected(422, 'bad_proof'));

    await expectLater(
      submit(repo()),
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
  });

  test('a refused token is retried fresh, then written directly', () async {
    when(
      () => client.submit(
        idToken: any(named: 'idToken'),
        body: any(named: 'body'),
      ),
    ).thenThrow(const LeaderboardSubmitRejected(401, 'unauthorized'));

    await submit(repo());

    verify(() => user.getIdToken(false)).called(1);
    verify(() => user.getIdToken(true)).called(1);
    verify(() => firestore.runTransaction<_TxResult>(any())).called(2);
  });

  test('a fresh token that the Worker takes is enough', () async {
    var calls = 0;
    when(
      () => client.submit(
        idToken: any(named: 'idToken'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async {
      if (calls++ == 0) {
        throw const LeaderboardSubmitRejected(401, 'unauthorized');
      }
      return const LeaderboardSubmitResult(improved: true);
    });

    await submit(repo());

    verifyNoDirectWrite();
    expect(rejected, isEmpty);
  });

  test('debug builds keep writing directly', () async {
    await submit(repo(debug: true));

    verifyNever(
      () => client.submit(
        idToken: any(named: 'idToken'),
        body: any(named: 'body'),
      ),
    );
    verify(() => firestore.runTransaction<_TxResult>(any())).called(2);
  });

  test('a clear without a proof is written directly', () async {
    await submit(repo(), proof: null);

    verifyNever(
      () => client.submit(
        idToken: any(named: 'idToken'),
        body: any(named: 'body'),
      ),
    );
    verify(() => firestore.runTransaction<_TxResult>(any())).called(2);
  });

  test('a time under the minimum is skipped on release boards', () async {
    await submit(repo(), time: 9);

    verifyZeroInteractions(client);
    verifyZeroInteractions(firestore);
  });

  test('a day whose board has closed is skipped on release boards', () async {
    await submit(repo(), day: '2026-10-12');

    verifyZeroInteractions(client);
    verifyZeroInteractions(firestore);
  });
}
