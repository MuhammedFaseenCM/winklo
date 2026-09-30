import '../avatars/avatar_catalog.dart';
import '../entities/app_user.dart';
import '../failures.dart';
import '../repositories/profile_repository.dart';

class UpdateAvatar {
  const UpdateAvatar(this._repo);

  final ProfileRepository _repo;

  Future<AppUser> preset(String avatarId) {
    if (!AvatarCatalog.isPresetId(avatarId)) {
      throw const Failure('Invalid avatar.');
    }
    return _repo.updateAvatarPreset(avatarId);
  }

  Future<AppUser> photo(List<int> bytes, {String contentType = 'image/jpeg'}) =>
      _repo.updateAvatarPhoto(bytes, contentType: contentType);
}
