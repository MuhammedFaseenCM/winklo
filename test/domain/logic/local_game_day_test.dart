import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/hint_quota_repository_impl.dart';
import 'package:winklo/data/repositories/score_repository_impl.dart';
import 'package:winklo/domain/entities/game_day_record.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/logic/local_game_day.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<GameDayRecord> read(
    Map<String, Object> prefs, {
    String gameId = GameIds.zip,
    String playId = '20261001',
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final p = await SharedPreferences.getInstance();
    return readLocalGameDay(
      scores: ScoreRepositoryImpl(p),
      hintQuota: HintQuotaRepositoryImpl(p),
      gameId: gameId,
      playId: playId,
    );
  }

  test('the daily games are Zip, Path Words and Sudoku', () {
    expect(dailyProgressGameIds, [
      GameIds.zip,
      GameIds.pathWords,
      GameIds.sudoku,
    ]);
  });

  group('readLocalGameDay', () {
    test('reads time, points, hints, board and meta', () async {
      final day = await read({
        'best_time_zip_daily_20261001': 42,
        'best_pts_zip_daily_20261001': 900,
        'hints_used_zip_20261001': 1,
        'clear_board_zip_daily_20261001': 'path',
        'clear_meta_zip_daily_20261001':
            '{"usedHints":true,"hadMistakes":false}',
      });
      expect(
        day,
        const GameDayRecord(
          gameId: GameIds.zip,
          playId: '20261001',
          timeSeconds: 42,
          points: 900,
          hintsUsed: 1,
          board: 'path',
          usedHints: true,
          hadMistakes: false,
          flagsKnown: true,
        ),
      );
    });

    test('derives legacy flags without meta', () async {
      final day = await read({
        'best_time_sudoku_20261001': 80,
        'hints_used_sudoku_20261001': 0,
      }, gameId: GameIds.sudoku);
      expect(day.usedHints, isFalse);
      expect(day.hadMistakes, isTrue);
      expect(day.flagsKnown, isFalse);
    });

    test('an uncleared day has no flags', () async {
      final day = await read({'hints_used_zip_20261001': 2});
      expect(day.cleared, isFalse);
      expect(day.hintsUsed, 2);
      expect(day.usedHints, isNull);
      expect(day.flagsKnown, isNull);
    });
  });

  group('readLocalDailyHistory', () {
    test('reads every daily clear of the three games only', () async {
      SharedPreferences.setMockInitialValues({
        'best_time_zip_daily_20261001': 42,
        'best_time_zip_daily_20261002': 50,
        'best_time_path_words_20261001': 61,
        'best_time_sudoku_20261003': 99,
        'hints_used_sudoku_20261003': 2,
        'best_time_zip_archive_20261001': 10,
        'best_time_zip_practice': 10,
        'best_time_match_deck1': 10,
        'hints_used_zip_20261009': 1, // hints but no clear
      });
      final p = await SharedPreferences.getInstance();
      final days = readLocalDailyHistory(
        scores: ScoreRepositoryImpl(p),
        hintQuota: HintQuotaRepositoryImpl(p),
      );
      expect(days.map((d) => (d.gameId, d.playId, d.timeSeconds)), [
        (GameIds.zip, '20261001', 42),
        (GameIds.zip, '20261002', 50),
        (GameIds.pathWords, '20261001', 61),
        (GameIds.sudoku, '20261003', 99),
      ]);
      expect(days.last.usedHints, isTrue);
    });
  });

  group('withLegacyClearFlags', () {
    test('fills legacy flags from the hint count', () {
      const day = GameDayRecord(
        gameId: GameIds.pathWords,
        playId: '20261001',
        timeSeconds: 30,
        hintsUsed: 2,
      );
      final out = withLegacyClearFlags(day);
      expect(out.usedHints, isTrue);
      expect(out.hadMistakes, isFalse);
      expect(out.flagsKnown, isFalse);
    });

    test('recomputes guessed flags from the hint count', () {
      const day = GameDayRecord(
        gameId: GameIds.zip,
        playId: '20261001',
        timeSeconds: 30,
        hintsUsed: 1,
        usedHints: false,
        hadMistakes: false,
        flagsKnown: false,
      );
      expect(withLegacyClearFlags(day).usedHints, isTrue);
    });

    test('leaves known flags alone', () {
      const day = GameDayRecord(
        gameId: GameIds.sudoku,
        playId: '20261001',
        timeSeconds: 30,
        hintsUsed: 3,
        usedHints: false,
        hadMistakes: false,
        flagsKnown: true,
      );
      expect(withLegacyClearFlags(day), day);
    });

    test('leaves an uncleared day alone', () {
      const day = GameDayRecord(
        gameId: GameIds.zip,
        playId: '20261001',
        hintsUsed: 1,
      );
      expect(withLegacyClearFlags(day), day);
    });
  });
}
