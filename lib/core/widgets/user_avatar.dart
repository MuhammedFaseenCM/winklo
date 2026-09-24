import 'package:flutter/material.dart';

import '../../domain/avatars/avatar_catalog.dart';
import '../theme/app_theme.dart';

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

  @override
  Widget build(BuildContext context) {
    final assetPath = AvatarCatalog.assetPathFor(avatarId);
    if (assetPath != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: ZipColors.mistDeep,
        child: ClipOval(
          child: Image.asset(
            assetPath,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    final url = photoUrl;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: ZipColors.mistDeep,
        backgroundImage: NetworkImage(url),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: ZipColors.mistDeep,
      child: Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
        style: const TextStyle(color: ZipColors.onInk),
      ),
    );
  }
}
