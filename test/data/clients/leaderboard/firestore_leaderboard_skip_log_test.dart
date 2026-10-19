// Mocks of the sealed Firestore reference types, as mocktail needs them.
// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:winklo/core/firebase/firebase_bootstrap.dart';
import 'package:winklo/data/clients/leaderboard/firestore_leaderboard_skip_log.dart';
import 'package:winklo/data/clients/leaderboard/leaderboard_skip_log.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockDoc extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class _MockSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

const _skip = LeaderboardSkip(
  uid: 'u1',
  gameId: 'zip',
  dayId: '2026-10-19',
  timeSeconds: 6,
  reason: 'too_fast',
  usedHints: false,
  hadMistakes: false,
  identity: (displayName: 'Adarsh', photoUrl: null, avatarId: 'preset_03'),
);

void main() {
  late _MockFirestore firestore;
  late _MockDoc entryDoc;
  late _MockSnapshot entry;
  late _MockCollection skips;
  late _MockDoc skipDoc;

  setUpAll(() {
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    final wasReady = FirebaseBootstrap.isReady;
    addTearDown(() => FirebaseBootstrap.isReady = wasReady);
    FirebaseBootstrap.isReady = true;

    firestore = _MockFirestore();
    final boards = _MockCollection();
    entryDoc = _MockDoc();
    entry = _MockSnapshot();
    when(() => firestore.collection('leaderboards')).thenReturn(boards);
    when(() => boards.doc(any())).thenReturn(entryDoc);
    when(() => entryDoc.collection(any())).thenReturn(boards);
    when(() => entryDoc.get()).thenAnswer((_) async => entry);
    when(() => entry.data()).thenReturn(null);

    skips = _MockCollection();
    skipDoc = _MockDoc();
    when(() => firestore.collection('leaderboard_skips')).thenReturn(skips);
    when(() => skips.doc(any())).thenReturn(skipDoc);
    when(() => skipDoc.set(any())).thenAnswer((_) async {});
  });

  FirestoreLeaderboardSkipLog log() => FirestoreLeaderboardSkipLog(
    firestore: firestore,
    packageInfo: () async => PackageInfo(
      appName: 'Winklo',
      packageName: 'com.winklo.faseencm',
      version: '1.1.2',
      buildNumber: '21',
    ),
  );

  Map<String, dynamic> written() =>
      verify(() => skipDoc.set(captureAny())).captured.single
          as Map<String, dynamic>;

  test('fields carry the player, the clear and the build', () {
    expect(
      leaderboardSkipFields(
        _skip,
        appVersion: '1.1.2',
        buildNumber: '21',
        platform: 'android',
      ),
      {
        'uid': 'u1',
        'gameId': 'zip',
        'dayId': '2026-10-19',
        'timeSeconds': 6,
        'reason': 'too_fast',
        'usedHints': false,
        'hadMistakes': false,
        'displayName': 'Adarsh',
        'photoUrl': null,
        'avatarId': 'preset_03',
        'appVersion': '1.1.2',
        'buildNumber': '21',
        'platform': 'android',
      },
    );
  });

  test('fields leave the identity out when the profile was unread', () {
    final fields = leaderboardSkipFields(
      const LeaderboardSkip(
        uid: 'u1',
        gameId: 'zip',
        dayId: '2026-10-19',
        timeSeconds: 6,
        reason: 'too_fast',
        usedHints: false,
        hadMistakes: false,
      ),
      appVersion: '1.1.2',
      buildNumber: '21',
      platform: 'android',
    );
    expect(fields.keys, isNot(contains('displayName')));
    expect(fields.keys, isNot(contains('photoUrl')));
    expect(fields.keys, isNot(contains('avatarId')));
  });

  test('every written key is a known one', () {
    final keys = {
      ...leaderboardSkipFields(
        _skip,
        appVersion: '1',
        buildNumber: '1',
        platform: 'android',
      ).keys,
      'createdAt',
    };
    expect(keys, leaderboardSkipFirestoreKeys);
  });

  test('one doc per player, game and day', () {
    expect(leaderboardSkipDocId(_skip), 'u1_zip_2026-10-19');
  });

  test('logs a clear the board does not show', () async {
    await log().record(_skip);

    verify(() => skips.doc('u1_zip_2026-10-19')).called(1);
    final fields = written();
    expect(fields['reason'], 'too_fast');
    expect(fields['timeSeconds'], 6);
    expect(fields['buildNumber'], '21');
    expect(fields['createdAt'], isA<FieldValue>());
  });

  test('logs when the board holds a slower time', () async {
    when(() => entry.data()).thenReturn({'timeSeconds': 40});

    await log().record(_skip);

    expect(written()['timeSeconds'], 6);
  });

  test('skips the log when the board already shows it or better', () async {
    // Posted from another device, or added by an admin.
    when(() => entry.data()).thenReturn({'timeSeconds': 6});

    await log().record(_skip);

    verifyNever(() => skipDoc.set(any()));
  });

  test('logs when the board cannot be read (offline)', () async {
    when(() => entryDoc.get()).thenThrow(
      FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
    );

    await log().record(_skip);

    expect(written()['reason'], 'too_fast');
  });

  test('never throws when the write fails', () async {
    when(() => skipDoc.set(any())).thenThrow(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
    );

    await expectLater(log().record(_skip), completes);
  });

  test('does nothing before Firebase is ready', () async {
    FirebaseBootstrap.isReady = false;

    await log().record(_skip);

    verifyZeroInteractions(firestore);
  });
}
