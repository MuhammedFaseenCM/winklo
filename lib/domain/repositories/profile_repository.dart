import '../entities/app_user.dart';

abstract class ProfileRepository {
  Stream<AppUser?> watchProfile(String uid);

  Future<AppUser?> getProfile(String uid);

  Future<AppUser> updateDisplayName(String displayName);

  Future<AppUser> updateAvatarPreset(String avatarId);

  Future<AppUser> updateAvatarPhoto(
    List<int> bytes, {
    String contentType = 'image/jpeg',
  });
}
