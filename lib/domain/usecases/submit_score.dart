import 'package:winklo/domain/repositories/score_repository.dart';

class SubmitScore {
  SubmitScore(this._repo);
  final ScoreRepository _repo;

  Future<bool> call({
    required String modeKey,
    required int points,
    int? timeSeconds,
    bool? usedHints,
    bool? hadMistakes,
    String? board,
  }) => _repo.submitScore(
    modeKey: modeKey,
    points: points,
    timeSeconds: timeSeconds,
    usedHints: usedHints,
    hadMistakes: hadMistakes,
    board: board,
  );
}
