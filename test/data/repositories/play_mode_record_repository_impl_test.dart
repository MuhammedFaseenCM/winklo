import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/play_mode_record_repository_impl.dart';
import 'package:winklo/data/repositories/progress_local_repository_impl.dart';
import 'package:winklo/domain/game_ids.dart';

void main() {
  late SharedPreferences prefs;
  late PlayModeRecordRepositoryImpl records;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    records = PlayModeRecordRepositoryImpl(prefs);
  });

  test('a first clear is stored but is not a new best', () async {
    final result = await records.recordTime('archive_zip_20261012', 90);
    expect(result.best, 90);
    expect(result.previous, isNull);
    expect(result.improved, isFalse);
    expect(records.bestTimeSeconds('archive_zip_20261012'), 90);
  });

  test('best times improve only', () async {
    await records.recordTime('practice_zip', 90);
    final slower = await records.recordTime('practice_zip', 120);
    expect(slower.best, 90);
    expect(slower.improved, isFalse);
    final faster = await records.recordTime('practice_zip', 60);
    expect(faster.best, 60);
    expect(faster.previous, 90);
    expect(faster.improved, isTrue);
    expect(records.bestTimeSeconds('practice_zip'), 60);
  });

  test('score bests keep the highest', () async {
    const key = 'bonus_category_race_animals';
    expect(records.bestScore(key), isNull);
    await records.recordScore(key, 5);
    final lower = await records.recordScore(key, 3);
    expect(lower.best, 5);
    expect(lower.improved, isFalse);
    final higher = await records.recordScore(key, 8);
    expect(higher.best, 8);
    expect(higher.improved, isTrue);
  });

  test('refuses daily mode keys', () async {
    for (final key in [
      'zip_daily_20261012',
      'path_words_20261012',
      'sudoku_20261012',
      'match_deck',
      '',
    ]) {
      expect(() => records.recordTime(key, 10), throwsArgumentError);
      expect(() => records.recordScore(key, 10), throwsArgumentError);
    }
  });

  test('never writes a daily key', () async {
    await records.recordTime('archive_zip_20261012', 70);
    await records.recordTime('archive_path_words_20261012', 70);
    await records.recordTime('archive_sudoku_20261012', 70);
    await records.recordTime('practice_sudoku', 70);
    await records.setHintsUsed(GameIds.zip, 'archive_20261012', 2);
    for (final key in prefs.getKeys()) {
      for (final daily in [
        'best_time_zip_daily_',
        'best_time_path_words_',
        'best_time_sudoku_',
        'best_pts_zip_daily_',
        'best_pts_path_words_',
        'best_pts_sudoku_',
      ]) {
        expect(key.startsWith(daily), isFalse, reason: key);
      }
      expect(key, isNot('hints_used_zip_20261012'));
    }
  });

  test('hint counts are per run and can be reset', () async {
    expect(records.hintsUsed(GameIds.zip, 'archive_20261012'), 0);
    await records.setHintsUsed(GameIds.zip, 'archive_20261012', 2);
    expect(records.hintsUsed(GameIds.zip, 'archive_20261012'), 2);
    expect(records.hintsUsed(GameIds.zip, 'archive_20261013'), 0);
    expect(records.hintsUsed(GameIds.sudoku, 'archive_20261012'), 0);
    await records.clearHints(GameIds.zip, 'archive_20261012');
    expect(records.hintsUsed(GameIds.zip, 'archive_20261012'), 0);
  });

  test('hint counts refuse daily run ids', () async {
    expect(
      () => records.setHintsUsed(GameIds.zip, '20261012', 1),
      throwsArgumentError,
    );
  });

  test('a sign-out purge removes them with the rest of the progress', () async {
    await records.recordTime('archive_zip_20261012', 70);
    await records.recordScore('bonus_category_race_food', 4);
    await records.setHintsUsed(GameIds.zip, 'archive_20261012', 1);
    await ProgressLocalRepositoryImpl(prefs).purgeUserProgress();
    expect(prefs.getKeys(), isEmpty);
  });
}
