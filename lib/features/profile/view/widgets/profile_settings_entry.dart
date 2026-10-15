import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_theme.dart';

/// Opens Settings (`/profile/settings`).
Future<void> openSettings(BuildContext context) =>
    context.push('/profile/settings');

/// The Settings row of the signed-out Profile (sound, vibration and
/// reminders work without an account).
class ProfileSettingsEntry extends StatelessWidget {
  const ProfileSettingsEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.tune_rounded, color: ZipColors.teal),
      title: Text(
        AppStrings.profileSettings,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: ZipColors.onInk,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: ZipColors.inkSoft),
      onTap: () => openSettings(context),
    );
  }
}
