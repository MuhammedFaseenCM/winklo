import '../repositories/progress_local_repository.dart';

/// After the player confirms deleting their account: drops this device's
/// copy of that account's progress, and any stash of it, rather than
/// stashing it for a uid that will never sign in again.
class ForgetAccountProgress {
  ForgetAccountProgress(this._local);

  final ProgressLocalRepository _local;

  Future<void> call(String uid) => _local.forgetUserProgress(uid);
}
