/// The critters a player can pick as their avatar.
enum AvatarCritter {
  fox,
  cat,
  owl,
  frog,
  panda,
  bunny,
  penguin,
  tiger,
  koala,
  bear,
  raccoon,
  chick,
}

abstract final class AvatarCatalog {
  /// Preset id → critter, in picker order. Ids 01–06 are the original
  /// presets, redrawn as the critter nearest the old art, so players who
  /// picked one keep a related face. Ids are stored in profiles and
  /// leaderboard rows, so they never change.
  static const presets = <String, AvatarCritter>{
    'preset_01': AvatarCritter.fox,
    'preset_03': AvatarCritter.cat,
    'preset_05': AvatarCritter.owl,
    'preset_07': AvatarCritter.frog,
    'preset_02': AvatarCritter.panda,
    'preset_06': AvatarCritter.bunny,
    'preset_08': AvatarCritter.penguin,
    'preset_09': AvatarCritter.tiger,
    'preset_10': AvatarCritter.koala,
    'preset_04': AvatarCritter.bear,
    'preset_11': AvatarCritter.raccoon,
    'preset_12': AvatarCritter.chick,
  };

  static Iterable<String> get presetIds => presets.keys;

  static AvatarCritter? critterFor(String? avatarId) => presets[avatarId];

  /// Bundled SVG for a preset, or null if [avatarId] isn't one.
  static String? assetFor(String? avatarId) {
    final critter = critterFor(avatarId);
    return critter == null ? null : 'assets/avatars/${critter.name}.svg';
  }

  static bool isPresetId(String id) => presets.containsKey(id);
}
