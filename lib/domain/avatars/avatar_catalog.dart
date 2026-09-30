import '../../core/config/static_assets_config.dart';

abstract final class AvatarCatalog {
  static const presetIds = [
    'preset_01',
    'preset_02',
    'preset_03',
    'preset_04',
    'preset_05',
    'preset_06',
  ];

  /// Public R2 URL for a bundled preset illustration, or null if unknown.
  static String? imageUrlFor(String? avatarId) {
    if (avatarId == null || !isPresetId(avatarId)) {
      return null;
    }
    return StaticAssetsConfig.url('avatars/$avatarId.png');
  }

  static bool isPresetId(String id) => presetIds.contains(id);
}
