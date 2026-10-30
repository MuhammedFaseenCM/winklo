import '../repositories/level_progress_repository.dart';
import '../repositories/progress_local_repository.dart';

/// After the player confirms deleting their account: drops this device's
/// copy of that account's progress, and any stash of it, rather than
/// stashing it for a uid that will never sign in again. Level progress goes
/// too, even when dropping the daily progress fails.
class ForgetAccountProgress {
  ForgetAccountProgress(this._local, [this._levels]);

  final ProgressLocalRepository _local;
  final LevelProgressRepository? _levels;

  Future<void> call(String uid) async {
    try {
      await _local.forgetUserProgress(uid);
    } finally {
      await _levels?.forget(uid);
    }
  }
}
