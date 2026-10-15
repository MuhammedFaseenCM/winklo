import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/hint_quota_repository_impl.dart';
import 'package:winklo/data/repositories/progress_local_repository_impl.dart';
import 'package:winklo/data/repositories/score_repository_impl.dart';
import 'package:winklo/domain/entities/game_day_record.dart';
import 'package:winklo/domain/failures.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/repositories/progress_remote_repository.dart';
import 'package:winklo/domain/usecases/upload_progress_history.dart';

class _MockRemote extends Mock implements ProgressRemoteRepository {}

const _uid = 'u1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockRemote remote;
  late ProgressLocalRepositoryImpl local;
  late UploadProgressHistory upload;
  late List<List<GameDayRecord>> batches;
  var rejectedPerBatch = 0;

  setUpAll(() {
    registerFallbackValue(<GameDayRecord>[]);
  });

  Future<void> build(
    Map<String, Object> prefs, {
    List<GameDayRecord> remoteDays = const [],
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final p = await SharedPreferences.getInstance();
    local = ProgressLocalRepositoryImpl(p);
    remote = _MockRemote();
    batches = [];
    rejectedPerBatch = 0;
    when(
      () => remote.fetchAllDays(uid: any(named: 'uid')),
    ).thenAnswer((_) async => remoteDays);
    when(
      () => remote.saveDayBatch(
        uid: any(named: 'uid'),
        records: any(named: 'records'),
      ),
    ).thenAnswer((invocation) async {
      batches.add(
        List.of(invocation.namedArguments[#records] as List<GameDayRecord>),
      );
      return rejectedPerBatch;
    });
    upload = UploadProgressHistory(
      scores: ScoreRepositoryImpl(p),
      hintQuota: HintQuotaRepositoryImpl(p),
      local: local,
      remote: remote,
    );
  }

  List<GameDayRecord> written() => [for (final b in batches) ...b];

  test('skips when the flag is set', () async {
    await build({
      'history_uploaded_u1': true,
      'best_time_zip_daily_20261001': 42,
    });
    final result = await upload(_uid);
    expect(result.ran, isFalse);
    verifyZeroInteractions(remote);
  });

  test(
    'sets the flag without a read when there is nothing to upload',
    () async {
      await build({'best_time_zip_level_1': 5, 'hints_used_zip_20261001': 1});
      final result = await upload(_uid);
      expect(result.ran, isTrue);
      expect(result.written, 0);
      expect(local.isHistoryUploaded(_uid), isTrue);
      verifyZeroInteractions(remote);
    },
  );

  test('writes missing days with their flags, legacy ones guessed', () async {
    await build({
      'best_time_zip_daily_20260901': 42,
      'best_pts_zip_daily_20260901': 900,
      'clear_meta_zip_daily_20260901':
          '{"usedHints":false,"hadMistakes":false}',
      'clear_board_zip_daily_20260901': 'path',
      'best_time_sudoku_20260902': 99,
      'hints_used_sudoku_20260902': 1,
    });
    final result = await upload(_uid);
    expect(result.written, 2);
    expect(result.rejected, 0);
    expect(written(), [
      const GameDayRecord(
        gameId: GameIds.zip,
        playId: '20260901',
        timeSeconds: 42,
        points: 900,
        usedHints: false,
        hadMistakes: false,
        flagsKnown: true,
        board: 'path',
      ),
      const GameDayRecord(
        gameId: GameIds.sudoku,
        playId: '20260902',
        timeSeconds: 99,
        usedHints: true,
        hadMistakes: true,
        flagsKnown: false,
        hintsUsed: 1,
      ),
    ]);
    expect(local.isHistoryUploaded(_uid), isTrue);
    verify(() => remote.fetchAllDays(uid: _uid)).called(1);
  });

  test('the same day in several games is one doc per game', () async {
    await build({
      'best_time_zip_daily_20260901': 42,
      'best_time_path_words_20260901': 61,
      'best_time_sudoku_20260901': 99,
    });
    await upload(_uid);
    expect(written().map((d) => '${d.gameId}_${d.playId}'), [
      'zip_20260901',
      'path_words_20260901',
      'sudoku_20260901',
    ]);
  });

  test('skips days the remote already has', () async {
    await build(
      {
        'best_time_zip_daily_20260901': 42,
        'clear_meta_zip_daily_20260901':
            '{"usedHints":false,"hadMistakes":false}',
        'best_time_zip_daily_20260902': 50,
      },
      remoteDays: [
        GameDayRecord(
          gameId: GameIds.zip,
          playId: '20260901',
          timeSeconds: 42,
          usedHints: false,
          hadMistakes: false,
          flagsKnown: true,
          clearedAt: DateTime.utc(2026, 9, 1),
        ),
      ],
    );
    final result = await upload(_uid);
    expect(result.written, 1);
    expect(written().single.playId, '20260902');
  });

  test('writes the merged day when local improves the remote copy', () async {
    await build(
      {
        'best_time_zip_daily_20260901': 40,
        'clear_meta_zip_daily_20260901':
            '{"usedHints":false,"hadMistakes":false}',
      },
      remoteDays: [
        const GameDayRecord(
          gameId: GameIds.zip,
          playId: '20260901',
          timeSeconds: 55,
          points: 990,
          usedHints: true,
          hadMistakes: false,
          flagsKnown: true,
          hintsUsed: 2,
        ),
      ],
    );
    await upload(_uid);
    expect(
      written().single,
      const GameDayRecord(
        gameId: GameIds.zip,
        playId: '20260901',
        timeSeconds: 40,
        points: 990,
        usedHints: false,
        hadMistakes: false,
        flagsKnown: true,
        hintsUsed: 2,
      ),
    );
  });

  test('never writes a regression of a better remote copy', () async {
    await build(
      {'best_time_zip_daily_20260901': 70, 'best_pts_zip_daily_20260901': 10},
      remoteDays: [
        const GameDayRecord(
          gameId: GameIds.zip,
          playId: '20260901',
          timeSeconds: 30,
          points: 900,
          usedHints: false,
          hadMistakes: false,
          flagsKnown: true,
          hintsUsed: 1,
        ),
      ],
    );
    final result = await upload(_uid);
    expect(result.written, 0);
    expect(batches, isEmpty);
    expect(local.isHistoryUploaded(_uid), isTrue);
  });

  test('splits the writes into batches of 400', () async {
    final prefs = <String, Object>{};
    for (var i = 0; i < 850; i++) {
      final day = DateTime(2024, 1, 1 + i);
      final id =
          '${day.year}${day.month.toString().padLeft(2, '0')}'
          '${day.day.toString().padLeft(2, '0')}';
      prefs['best_time_zip_daily_$id'] = 60;
    }
    await build(prefs);
    final result = await upload(_uid);
    expect(batches.map((b) => b.length), [400, 400, 50]);
    expect(result.written, 850);
  });

  test('ignores archive, practice and bonus-game keys', () async {
    await build({
      'best_time_zip_archive_20261001': 10,
      'best_time_zip_practice': 10,
      'best_time_path_words_practice': 10,
      'best_time_sudoku_archive_20261001': 10,
      'best_time_match_deck1': 10,
      'best_time_race_cat1': 10,
    });
    await upload(_uid);
    expect(batches, isEmpty);
    verifyNever(() => remote.fetchAllDays(uid: any(named: 'uid')));
  });

  test('sets the flag when the rules rejected some writes', () async {
    await build({
      'best_time_zip_daily_20260901': 42,
      'best_time_zip_daily_20260902': 43,
    });
    rejectedPerBatch = 1;
    final result = await upload(_uid);
    expect(result.written, 1);
    expect(result.rejected, 1);
    expect(local.isHistoryUploaded(_uid), isTrue);
  });

  test('a failed read leaves the flag unset', () async {
    await build({'best_time_zip_daily_20260901': 42});
    when(
      () => remote.fetchAllDays(uid: any(named: 'uid')),
    ).thenThrow(const Failure('offline'));
    await expectLater(upload(_uid), throwsA(isA<Failure>()));
    expect(local.isHistoryUploaded(_uid), isFalse);
  });

  test('a failed batch leaves the flag unset', () async {
    await build({'best_time_zip_daily_20260901': 42});
    when(
      () => remote.saveDayBatch(
        uid: any(named: 'uid'),
        records: any(named: 'records'),
      ),
    ).thenThrow(const Failure('timeout'));
    await expectLater(upload(_uid), throwsA(isA<Failure>()));
    expect(local.isHistoryUploaded(_uid), isFalse);
  });

  test('a cancelled run stops and leaves the flag unset', () async {
    await build({'best_time_zip_daily_20260901': 42});
    final result = await upload(_uid, isCancelled: () => true);
    expect(result.ran, isFalse);
    expect(batches, isEmpty);
    expect(local.isHistoryUploaded(_uid), isFalse);
  });

  test('a run cancelled after its last batch leaves the flag unset', () async {
    await build({'best_time_zip_daily_20260901': 42});
    final result = await upload(_uid, isCancelled: () => batches.isNotEmpty);
    expect(result.ran, isFalse);
    expect(batches, hasLength(1));
    expect(local.isHistoryUploaded(_uid), isFalse);
  });

  test('an empty uid does nothing', () async {
    await build({'best_time_zip_daily_20260901': 42});
    final result = await upload('');
    expect(result.ran, isFalse);
    verifyZeroInteractions(remote);
  });
}
