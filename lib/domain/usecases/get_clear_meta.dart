import '../entities/clear_meta.dart';
import '../repositories/score_repository.dart';

class GetClearMeta {
  GetClearMeta(this._repo);
  final ScoreRepository _repo;

  ClearMeta? call(String modeKey) => _repo.getClearMeta(modeKey);
}
