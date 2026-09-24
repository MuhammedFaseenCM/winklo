abstract final class AvatarCatalog {
  static const presetIds = [
    'preset_01',
    'preset_02',
    'preset_03',
    'preset_04',
    'preset_05',
    'preset_06',
  ];

  static String? assetPathFor(String? avatarId) {
    if (avatarId == null || !isPresetId(avatarId)) {
      return null;
    }
    return 'assets/avatars/$avatarId.png';
  }

  static bool isPresetId(String id) => presetIds.contains(id);
}
