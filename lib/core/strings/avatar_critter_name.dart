import '../../domain/avatars/avatar_catalog.dart';
import 'app_strings.dart';

/// [critter]'s name in the current language, e.g. for a screen reader.
String avatarCritterName(AvatarCritter critter) => switch (critter) {
  AvatarCritter.fox => AppStrings.avatarCritterFox,
  AvatarCritter.cat => AppStrings.avatarCritterCat,
  AvatarCritter.owl => AppStrings.avatarCritterOwl,
  AvatarCritter.frog => AppStrings.avatarCritterFrog,
  AvatarCritter.panda => AppStrings.avatarCritterPanda,
  AvatarCritter.bunny => AppStrings.avatarCritterBunny,
  AvatarCritter.penguin => AppStrings.avatarCritterPenguin,
  AvatarCritter.tiger => AppStrings.avatarCritterTiger,
  AvatarCritter.koala => AppStrings.avatarCritterKoala,
  AvatarCritter.bear => AppStrings.avatarCritterBear,
  AvatarCritter.raccoon => AppStrings.avatarCritterRaccoon,
  AvatarCritter.chick => AppStrings.avatarCritterChick,
};
