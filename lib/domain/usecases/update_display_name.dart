import '../entities/app_user.dart';
import '../failures.dart';
import '../repositories/profile_repository.dart';

class UpdateDisplayName {
  const UpdateDisplayName(this._repo);

  final ProfileRepository _repo;

  /// Throws [Failure] on validation or repo errors.
  Future<AppUser> call(String rawName) {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) throw const Failure('Name can’t be empty.');
    if (trimmed.length > 24) {
      throw const Failure('Name must be 24 characters or fewer.');
    }
    return _repo.updateDisplayName(trimmed);
  }
}
