import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/repositories/score_repository.dart';
import 'package:winklo/domain/usecases/get_weekly_recap.dart';

class _MockScores extends Mock implements ScoreRepository {}

void main() {
  test('reads the week from the daily mode keys', () {
    final scores = _MockScores();
    when(() => scores.getBestPoints(any())).thenReturn(0);
    when(() => scores.getBestTimeSeconds(any())).thenReturn(null);
    when(() => scores.getBestTimeSeconds('zip_daily_20261013')).thenReturn(58);
    when(() => scores.getBestTimeSeconds('sudoku_20261018')).thenReturn(150);
    when(() => scores.getBestPoints('path_words_20261014')).thenReturn(20);

    final recap = GetWeeklyRecap(scores)(
      weekStart: DateTime(2026, 10, 12),
      currentStreaks: const {GameIds.sudoku: 5},
    );

    expect(recap.weekStartId, '20261012');
    expect(recap.cleared, 3);
    expect(recap.possible, 21);
    expect(recap.bestGameId, GameIds.zip);
    expect(recap.bestSeconds, 58);
    expect(recap.streakGameId, GameIds.sudoku);
    expect(recap.streakDays, 5);
  });
}
