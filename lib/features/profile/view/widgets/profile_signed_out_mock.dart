import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/user_avatar.dart';
import 'profile_settings_list.dart';

/// Decorative fake profile for the signed-out tease.
///
/// Sound effects live in the signed-out foreground (above the blur scrim);
/// this mock omits the SFX row so a dead Switch is not shown under the blur.
class ProfileSignedOutMock extends StatelessWidget {
  const ProfileSignedOutMock({super.key});

  static const _mockName = 'Player';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: UserAvatar(displayName: _mockName, radius: 56)),
          const SizedBox(height: 16),
          Text(
            _mockName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: ZipColors.onInk,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.profileEditDisplayName,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: ZipColors.inkSoft),
          ),
          const SizedBox(height: 28),
          ProfileSettingsList(
            enabled: false,
            onSfxChanged: null,
            onPrivacy: _noop,
            onAbout: _noop,
            onReport: _noop,
            onSignOut: _noop,
          ),
        ],
      ),
    );
  }
}

void _noop() {}
