import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/firebase/firebase_bootstrap.dart';
import 'package:winklo/data/repositories/progress_remote_repository_impl.dart';
import 'package:winklo/domain/entities/game_day_record.dart';
import 'package:winklo/domain/entities/game_streak.dart';
import 'package:winklo/domain/failures.dart';
import 'package:winklo/domain/game_ids.dart';

void main() {
  final clearedAt = DateTime.utc(2026, 10, 7, 9, 30);

  final fullDay = GameDayRecord(
    gameId: GameIds.sudoku,
    playId: '20261007',
    timeSeconds: 80,
    points: 900,
    usedHints: true,
    hadMistakes: false,
    flagsKnown: false,
    hintsUsed: 2,
    clearedAt: clearedAt,
  );

  const fullStreak = GameStreak(
    gameId: GameIds.zip,
    current: 2,
    longest: 3,
    lastClearedDateId: '20261007',
    freezeAvailable: false,
    isOnFreeze: true,
  );

  group('gameDayDocId', () {
    test('joins gameId and playId', () {
      expect(
        gameDayDocId(GameIds.pathWords, '20261007'),
        'path_words_20261007',
      );
      expect(gameDayDocId(GameIds.zip, '202610071230'), 'zip_202610071230');
    });
  });

  group('gameDayToFirestore', () {
    test('writes exactly the documented keys when every field is set', () {
      final payload = gameDayToFirestore(fullDay);
      expect(payload.keys.toSet(), gameDayFirestoreKeys);
    });

    test('maps values and stamps updatedAt on the server', () {
      final payload = gameDayToFirestore(fullDay);
      expect(payload['gameId'], GameIds.sudoku);
      expect(payload['playId'], '20261007');
      expect(payload['timeSeconds'], 80);
      expect(payload['points'], 900);
      expect(payload['usedHints'], isTrue);
      expect(payload['hadMistakes'], isFalse);
      expect(payload['flagsKnown'], isFalse);
      expect(payload['hintsUsed'], 2);
      expect(payload['clearedAt'], Timestamp.fromDate(clearedAt));
      expect(payload['updatedAt'], isA<FieldValue>());
    });

    test('leaves null fields absent instead of writing nulls', () {
      final payload = gameDayToFirestore(
        const GameDayRecord(gameId: GameIds.zip, playId: '20261007'),
      );
      expect(payload.keys.toSet(), {
        'gameId',
        'playId',
        'hintsUsed',
        'updatedAt',
      });
      expect(payload.values, isNot(contains(isNull)));
      expect(payload.keys.toSet().difference(gameDayFirestoreKeys), isEmpty);
    });

    test('clamps hintsUsed into the range the rules accept', () {
      expect(
        gameDayToFirestore(
          const GameDayRecord(gameId: 'zip', playId: '20261007', hintsUsed: 99),
        )['hintsUsed'],
        50,
      );
      expect(
        gameDayToFirestore(
          const GameDayRecord(gameId: 'zip', playId: '20261007', hintsUsed: -1),
        )['hintsUsed'],
        0,
      );
    });

    test('drops negative times and points', () {
      final payload = gameDayToFirestore(
        const GameDayRecord(
          gameId: 'zip',
          playId: '20261007',
          timeSeconds: -1,
          points: -5,
        ),
      );
      expect(payload.containsKey('timeSeconds'), isFalse);
      expect(payload.containsKey('points'), isFalse);
    });
  });

  group('gameDayFromFirestore', () {
    test('returns null for a missing doc', () {
      expect(
        gameDayFromFirestore(null, gameId: 'zip', playId: '20261007'),
        isNull,
      );
    });

    test('round-trips a full record', () {
      final data = gameDayToFirestore(fullDay)
        ..['updatedAt'] = Timestamp.fromDate(clearedAt);
      expect(
        gameDayFromFirestore(data, gameId: GameIds.sudoku, playId: '20261007'),
        // Timestamp.toDate() is local time; same instant as [clearedAt].
        fullDay.copyWith(clearedAt: clearedAt.toLocal()),
      );
    });

    test('takes ids from the doc path, not the data', () {
      final record = gameDayFromFirestore(
        {'gameId': 'other', 'playId': 'x', 'timeSeconds': 12},
        gameId: GameIds.zip,
        playId: '20261007',
      )!;
      expect(record.gameId, GameIds.zip);
      expect(record.playId, '20261007');
      expect(record.cleared, isTrue);
    });

    test('reads malformed fields as absent', () {
      final record = gameDayFromFirestore(
        {
          'timeSeconds': 'fast',
          'points': -3,
          'usedHints': 'yes',
          'hadMistakes': 0,
          'flagsKnown': null,
          'hintsUsed': 1.5,
          'clearedAt': '2026-10-07',
        },
        gameId: GameIds.zip,
        playId: '20261007',
      )!;
      expect(
        record,
        const GameDayRecord(gameId: GameIds.zip, playId: '20261007'),
      );
      expect(record.cleared, isFalse);
    });

    test('accepts integral doubles', () {
      final record = gameDayFromFirestore(
        {'timeSeconds': 12.0, 'points': 900.0, 'hintsUsed': 2.0},
        gameId: GameIds.zip,
        playId: '20261007',
      )!;
      expect(record.timeSeconds, 12);
      expect(record.points, 900);
      expect(record.hintsUsed, 2);
    });

    test('an empty doc is an uncleared day with no hints', () {
      final record = gameDayFromFirestore(
        {},
        gameId: GameIds.zip,
        playId: '20261007',
      )!;
      expect(record.cleared, isFalse);
      expect(record.hintsUsed, 0);
    });
  });

  group('streakToFirestore', () {
    test('writes exactly the documented keys', () {
      expect(streakToFirestore(fullStreak).keys.toSet(), streakFirestoreKeys);
    });

    test('maps values, keeps a null lastClearedDateId, never isOnFreeze', () {
      final payload = streakToFirestore(fullStreak);
      expect(payload['current'], 2);
      expect(payload['longest'], 3);
      expect(payload['lastClearedDateId'], '20261007');
      expect(payload['freezeAvailable'], isFalse);
      expect(payload['updatedAt'], isA<FieldValue>());

      final empty = streakToFirestore(const GameStreak(gameId: GameIds.zip));
      expect(empty.keys.toSet(), streakFirestoreKeys);
      expect(empty['lastClearedDateId'], isNull);
      expect(empty['freezeAvailable'], isTrue);
    });
  });

  group('streakFromFirestore', () {
    test('returns null for a missing doc', () {
      expect(streakFromFirestore(null, gameId: GameIds.zip), isNull);
    });

    test('round-trips stored fields', () {
      final streak = streakFromFirestore(
        streakToFirestore(fullStreak),
        gameId: GameIds.zip,
      )!;
      expect(streak.gameId, GameIds.zip);
      expect(streak.current, 2);
      expect(streak.longest, 3);
      expect(streak.lastClearedDateId, '20261007');
      expect(streak.freezeAvailable, isFalse);
      expect(streak.isOnFreeze, isFalse);
    });

    test('falls back to defaults for malformed fields', () {
      final streak = streakFromFirestore({
        'current': -1,
        'longest': 'many',
        'lastClearedDateId': '2026-10-07',
        'freezeAvailable': 'no',
      }, gameId: GameIds.sudoku)!;
      expect(streak.current, 0);
      expect(streak.longest, 0);
      expect(streak.lastClearedDateId, isNull);
      expect(streak.freezeAvailable, isTrue);
    });
  });

  group('confirmedSnapshotData', () {
    test('passes server-confirmed data (or a missing doc) through', () {
      final data = {'hintsUsed': 1};
      expect(confirmedSnapshotData(data, hasPendingWrites: false), data);
      expect(confirmedSnapshotData(null, hasPendingWrites: false), isNull);
    });

    test('throws for a snapshot showing unacknowledged local writes', () {
      expect(
        () => confirmedSnapshotData({'hintsUsed': 1}, hasPendingWrites: true),
        throwsA(isA<Failure>()),
      );
    });
  });

  group('ProgressRemoteRepositoryImpl when Firebase is not ready', () {
    late bool wasReady;
    late ProgressRemoteRepositoryImpl repo;

    setUp(() {
      wasReady = FirebaseBootstrap.isReady;
      FirebaseBootstrap.isReady = false;
      repo = ProgressRemoteRepositoryImpl();
    });

    tearDown(() {
      FirebaseBootstrap.isReady = wasReady;
    });

    test('fetchDay returns null', () async {
      expect(
        await repo.fetchDay(uid: 'u1', gameId: 'zip', playId: '20261007'),
        isNull,
      );
    });

    test('fetchStreak returns null', () async {
      expect(await repo.fetchStreak(uid: 'u1', gameId: 'zip'), isNull);
    });

    test('saveDay throws Failure', () {
      expect(repo.saveDay(uid: 'u1', record: fullDay), throwsA(isA<Failure>()));
    });

    test('saveStreak throws Failure', () {
      expect(
        repo.saveStreak(uid: 'u1', streak: fullStreak),
        throwsA(isA<Failure>()),
      );
    });
  });

  group('ProgressRemoteRepositoryImpl validation', () {
    final repo = ProgressRemoteRepositoryImpl();

    test('rejects unsupported games', () {
      expect(
        repo.fetchDay(uid: 'u1', gameId: 'word_match', playId: '20261007'),
        throwsA(isA<Failure>()),
      );
      expect(
        repo.saveStreak(
          uid: 'u1',
          streak: const GameStreak(gameId: 'category_race'),
        ),
        throwsA(isA<Failure>()),
      );
    });

    test('rejects malformed playIds', () {
      for (final bad in ['2026-10-07', '2026100', '20261007123', 'daily_x']) {
        expect(
          repo.saveDay(
            uid: 'u1',
            record: GameDayRecord(gameId: 'zip', playId: bad),
          ),
          throwsA(isA<Failure>()),
          reason: bad,
        );
      }
    });

    test('rejects an empty uid', () {
      expect(repo.fetchStreak(uid: '', gameId: 'zip'), throwsA(isA<Failure>()));
    });
  });
}
