import 'package:flutter/material.dart';

import '../../domain/avatars/avatar_catalog.dart';
import '../theme/app_theme.dart';
import 'app_image.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.displayName,
    this.photoUrl,
    this.avatarId,
    this.radius = 18,
  });

  final String displayName;
  final String? photoUrl;
  final String? avatarId;
  final double radius;

  Widget get _initials => Text(
    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
    style: const TextStyle(color: ZipColors.onInk),
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
      backgroundColor: ZipColors.mistDeep,
      child: _initials,
    );
  }
}
