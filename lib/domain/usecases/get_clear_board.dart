import 'package:winklo/domain/repositories/score_repository.dart';

class GetClearBoard {
  GetClearBoard(this._repo);
  final ScoreRepository _repo;

  String? call(String modeKey) => _repo.getClearBoard(modeKey);
}
