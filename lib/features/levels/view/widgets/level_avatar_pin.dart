import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../domain/entities/app_user.dart';

/// The player's avatar on a pin, standing on the current level.
class LevelAvatarPin extends StatelessWidget {
  const LevelAvatarPin({super.key, required this.user});

  final AppUser? user;

  static const width = 40.0;
  static const height = 46.0;

  @override
  Widget build(BuildContext context) {
    final user = this.user;
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: _PinPainter(),
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: UserAvatar(
                displayName: user?.displayName ?? '',
                photoUrl: user?.photoUrl,
                avatarId: user?.avatarId,
                radius: 15,
                tintSeed: user?.uid,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = ZipColors.onInk;
    canvas.drawCircle(Offset(size.width / 2, 18), 18, paint);
    canvas.drawPath(
      Path()
        ..moveTo(size.width / 2 - 6, 33)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width / 2 + 6, 33)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(_PinPainter oldDelegate) => false;
}
