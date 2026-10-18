import '../../core/strings/app_strings.dart';
import '../entities/app_user.dart';
import '../failures.dart';
import '../repositories/profile_repository.dart';

class UpdateDisplayName {
  const UpdateDisplayName(this._repo);

  final ProfileRepository _repo;

  /// Throws [Failure] on validation or repo errors.
  Future<AppUser> call(String rawName) {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) throw Failure(AppStrings.profileNameEmpty);
    if (trimmed.length > 24) {
      throw Failure(AppStrings.profileNameTooLong);
    }
    return _repo.updateDisplayName(trimmed);
  }
}
