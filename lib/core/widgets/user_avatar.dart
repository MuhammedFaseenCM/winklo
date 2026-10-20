import 'package:flutter/material.dart';

import '../../domain/avatars/avatar_catalog.dart';
import '../theme/app_theme.dart';
import 'app_image.dart';

/// Hues for initials avatars, so a board of letters isn't all grey.
const avatarTintPalette = <Color>[
  ZipColors.ember,
  ZipColors.sky,
  ZipColors.success,
  ZipColors.number,
  Color(0xFFA78BFA), // violet
  Color(0xFFFBBF24), // amber
  Color(0xFFA3E635), // lime
];

/// [seed]'s hue from [avatarTintPalette]: the same seed always gets the same.
Color avatarTintFor(String seed) {
  var hash = 0;
  for (final unit in seed.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return avatarTintPalette[hash % avatarTintPalette.length];
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.displayName,
    this.photoUrl,
    this.avatarId,
    this.radius = 18,
    this.tintSeed,
  });

  final String displayName;
  final String? photoUrl;
  final String? avatarId;
  final double radius;

  /// When set, an initials avatar is tinted with [avatarTintFor] this seed.
  final String? tintSeed;

  Color? get _tint => tintSeed == null ? null : avatarTintFor(tintSeed!);

  Widget get _initials => Text(
    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
    style: TextStyle(
      color: _tint ?? ZipColors.onInk,
      fontWeight: _tint == null ? null : FontWeight.w700,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final presetUrl = AvatarCatalog.imageUrlFor(avatarId);
    if (presetUrl != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: ZipColors.mistDeep,
        child: ClipOval(
          child: AppImage.network(
            presetUrl,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorWidget: Center(child: _initials),
            placeholder: Center(
              child: SizedBox(
                width: radius,
                height: radius,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ),
      );
    }

    final url = photoUrl;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: ZipColors.mistDeep,
        child: ClipOval(
          child: AppImage.network(
            url,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorWidget: Center(child: _initials),
            placeholder: Center(
              child: SizedBox(
                width: radius,
                height: radius,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: _tint?.withValues(alpha: 0.18) ?? ZipColors.mistDeep,
      child: _initials,
    );
  }
}
