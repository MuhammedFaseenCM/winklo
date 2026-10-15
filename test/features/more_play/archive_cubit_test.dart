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

  test('months run from 11 Oct to yesterday, newest on screen', () {
    now = DateTime(2026, 11, 3);
    final cubit = build()..load();
    expect(cubit.state.months.length, 2);
    expect(cubit.state.monthIndex, 1);
    expect(cubit.state.month!.month, 11);
    expect(cubit.state.month!.lastDay, 2);
    cubit.close();
  });

  test('✓ for a daily clear or an archive clear, per game', () async {
    when(() => getBestTimeSeconds('zip_daily_20261012')).thenReturn(80);
    when(() => getBestPoints('path_words_20261011')).thenReturn(700);
    await records.recordTime('archive_zip_20261013', 99);
    await records.recordTime('archive_sudoku_20261014', 99);

    final cubit = build()..load();
    expect(cubit.state.month!.clearedDays, {12, 13});
    cubit.selectGame(GameIds.pathWords);
    expect(cubit.state.gameId, GameIds.pathWords);
    expect(cubit.state.month!.clearedDays, {11});
    cubit.selectGame(GameIds.sudoku);
    expect(cubit.state.month!.clearedDays, {14});
    await cubit.close();
  });

  test('reloading after a run picks up the new clear', () async {
    final cubit = build(game: GameIds.sudoku)..load();
    expect(cubit.state.month!.clearedDays, isEmpty);
    await records.recordTime('archive_sudoku_20261011', 50);
    cubit.load();
    expect(cubit.state.month!.clearedDays, {11});
    await cubit.close();
  });

  test('an unknown game opens Zip', () {
    final cubit = build(game: 'word_match')..load();
    expect(cubit.state.gameId, GameIds.zip);
    cubit.close();
  });

  test('showMonth pages and ignores out-of-range months', () {
    now = DateTime(2026, 12, 20);
    final cubit = build()..load();
    expect(cubit.state.monthIndex, 2);
    cubit.showMonth(0);
    expect(cubit.state.month!.month, 10);
    cubit.showMonth(5);
    expect(cubit.state.monthIndex, 0);
    cubit.load();
    expect(cubit.state.monthIndex, 0);
    cubit.close();
  });

  test('never writes anything', () async {
    final cubit = build()..load();
    cubit.selectGame(GameIds.pathWords);
    expect(prefs.getKeys(), isEmpty);
    await cubit.close();
  });
}
