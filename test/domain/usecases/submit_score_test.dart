import 'package:winklo/domain/repositories/score_repository.dart';
import 'package:winklo/domain/usecases/submit_score.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockScoreRepository extends Mock implements ScoreRepository {}

void main() {
  late _MockScoreRepository repo;
  late SubmitScore usecase;

  setUp(() {
    repo = _MockScoreRepository();
    usecase = SubmitScore(repo);
  });

  test('forwards params and returns repository result', () async {
    when(
      () =>
          repo.submitScore(modeKey: 'zip_daily', points: 900, timeSeconds: 12),
    ).thenAnswer((_) async => true);

    final improved = await usecase(
      modeKey: 'zip_daily',
      points: 900,
      timeSeconds: 12,
    );

    expect(improved, isTrue);
    verify(
      () =>
          repo.submitScore(modeKey: 'zip_daily', points: 900, timeSeconds: 12),
    ).called(1);
  });

  test('forwards clean-run flags', () async {
    when(
      () => repo.submitScore(
        modeKey: 'sudoku_20261007',
        points: 700,
        timeSeconds: 90,
        usedHints: true,
        hadMistakes: false,
      ),
    ).thenAnswer((_) async => true);

    await usecase(
      modeKey: 'sudoku_20261007',
      points: 700,
      timeSeconds: 90,
      usedHints: true,
      hadMistakes: false,
    );

    verify(
      () => repo.submitScore(
        modeKey: 'sudoku_20261007',
        points: 700,
        timeSeconds: 90,
        usedHints: true,
        hadMistakes: false,
      ),
    ).called(1);
  });
}
