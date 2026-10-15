import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/play_mode_record_repository_impl.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/usecases/get_best_points.dart';
import 'package:winklo/domain/usecases/get_best_time_seconds.dart';
import 'package:winklo/features/more_play/cubit/archive_cubit.dart';

class _MockGetBestPoints extends Mock implements GetBestPoints {}

class _MockGetBestTimeSeconds extends Mock implements GetBestTimeSeconds {}

void main() {
  late _MockGetBestPoints getBestPoints;
  late _MockGetBestTimeSeconds getBestTimeSeconds;
  late PlayModeRecordRepositoryImpl records;
  late SharedPreferences prefs;
  var now = DateTime(2026, 10, 15, 9);

  setUp(() async {
    getBestPoints = _MockGetBestPoints();
    getBestTimeSeconds = _MockGetBestTimeSeconds();
    when(() => getBestPoints(any())).thenReturn(0);
    when(() => getBestTimeSeconds(any())).thenReturn(null);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    records = PlayModeRecordRepositoryImpl(prefs);
    now = DateTime(2026, 10, 15, 9);
  });

  ArchiveCubit build({String game = GameIds.zip}) => ArchiveCubit(
    getBestPoints: getBestPoints,
    getBestTimeSeconds: getBestTimeSeconds,
    records: records,
    initialGameId: game,
    now: () => now,
  );

  blocTest<ArchiveCubit, ArchiveState>(
    'months run from 11 Oct to yesterday, newest on screen',
    setUp: () => now = DateTime(2026, 11, 3),
    build: build,
    act: (cubit) => cubit.load(),
    expect: () => [
      isA<ArchiveState>()
          .having((s) => s.months.length, 'months', 2)
          .having((s) => s.monthIndex, 'monthIndex', 1)
          .having((s) => s.month!.month, 'month', 11)
          .having((s) => s.month!.lastDay, 'lastDay', 2),
    ],
  );

  blocTest<ArchiveCubit, ArchiveState>(
    'a check for a daily clear or an archive clear, per game',
    setUp: () async {
      when(() => getBestTimeSeconds('zip_daily_20261012')).thenReturn(80);
      when(() => getBestPoints('path_words_20261011')).thenReturn(700);
      await records.recordTime('archive_zip_20261013', 99);
      await records.recordTime('archive_sudoku_20261014', 99);
    },
    build: build,
    act: (cubit) => cubit
      ..load()
      ..selectGame(GameIds.pathWords)
      ..selectGame(GameIds.sudoku),
    expect: () => [
      isA<ArchiveState>().having((s) => s.gameId, 'game', GameIds.zip).having(
        (s) => s.month!.clearedDays,
        'cleared',
        {12, 13},
      ),
      isA<ArchiveState>()
          .having((s) => s.gameId, 'game', GameIds.pathWords)
          .having((s) => s.month!.clearedDays, 'cleared', {11}),
      isA<ArchiveState>()
          .having((s) => s.gameId, 'game', GameIds.sudoku)
          .having((s) => s.month!.clearedDays, 'cleared', {14}),
    ],
  );

  blocTest<ArchiveCubit, ArchiveState>(
    'reloads by itself when a run stores a best',
    build: () => build(game: GameIds.sudoku),
    act: (cubit) async {
      cubit.load();
      await records.recordTime('archive_sudoku_20261011', 50);
      await pumpEventQueue();
    },
    expect: () => [
      isA<ArchiveState>().having(
        (s) => s.month!.clearedDays,
        'cleared',
        isEmpty,
      ),
      isA<ArchiveState>().having((s) => s.month!.clearedDays, 'cleared', {11}),
    ],
  );

  blocTest<ArchiveCubit, ArchiveState>(
    'an unknown game opens Zip',
    build: () => build(game: 'word_match'),
    act: (cubit) => cubit.load(),
    expect: () => [
      isA<ArchiveState>().having((s) => s.gameId, 'game', GameIds.zip),
    ],
  );

  blocTest<ArchiveCubit, ArchiveState>(
    'showMonth pages and ignores out-of-range months; load keeps the page',
    setUp: () => now = DateTime(2026, 12, 20),
    build: build,
    act: (cubit) => cubit
      ..load()
      ..showMonth(0)
      ..showMonth(5)
      ..load(),
    expect: () => [
      isA<ArchiveState>().having((s) => s.monthIndex, 'index', 2),
      isA<ArchiveState>()
          .having((s) => s.monthIndex, 'index', 0)
          .having((s) => s.month!.month, 'month', 10),
    ],
  );

  test('never writes anything', () async {
    final cubit = build()..load();
    cubit.selectGame(GameIds.pathWords);
    expect(prefs.getKeys(), isEmpty);
    await cubit.close();
  });
}
