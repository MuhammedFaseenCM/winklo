import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icon.dart';

class ProfileSettingsList extends StatelessWidget {
  const ProfileSettingsList({
    super.key,
    required this.onPrivacy,
    required this.onAbout,
    required this.onRate,
    required this.onReport,
    required this.onSignOut,
    required this.onDeleteAccount,
    this.enabled = true,
    this.onSettings,
  });

  final VoidCallback onPrivacy;
  final VoidCallback onAbout;
  final VoidCallback onRate;
  final VoidCallback onReport;
  final VoidCallback onSignOut;
  final VoidCallback onDeleteAccount;

  /// Decorative rows (signed-out mock) ignore taps.
  final bool enabled;

  /// Opens Settings (sound, vibration, reminders); the row is left out when
  /// null.
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Container(
      decoration: BoxDecoration(
        gradient: ZipColors.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ZipColors.glassBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x20000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onSettings case final openSettings?) ...[
              _SettingsRow(
                icon: AppIcons.tune,
                label: AppStrings.profileSettings,
                iconColor: ZipColors.teal,
                onTap: enabled ? openSettings : null,
              ),
              const Divider(height: 1, thickness: 1, color: Color(0x14FFFFFF)),
            ],
            _SettingsRow(
              icon: AppIcons.privacy,
              label: AppStrings.profilePrivacyPolicy,
              iconColor: ZipColors.sky,
              onTap: enabled ? onPrivacy : null,
            ),
            const Divider(height: 1, thickness: 1, color: Color(0x14FFFFFF)),
            _SettingsRow(
              icon: AppIcons.info,
              label: AppStrings.profileAboutGame,
              iconColor: ZipColors.ember,
              onTap: enabled ? onAbout : null,
            ),
            const Divider(height: 1, thickness: 1, color: Color(0x14FFFFFF)),
            _SettingsRow(
              icon: AppIcons.starOutline,
              label: AppStrings.profileRateOnPlayStore,
              iconColor: const Color(0xFFFBBF24),
              onTap: enabled ? onRate : null,
            ),
            const Divider(height: 1, thickness: 1, color: Color(0x14FFFFFF)),
            _SettingsRow(
              icon: AppIcons.flag,
              label: AppStrings.profileReportIssue,
              iconColor: const Color(0xFFFBBF24),
              onTap: enabled ? onReport : null,
            ),
            const Divider(height: 1, thickness: 1, color: Color(0x14FFFFFF)),
            _SettingsRow(
              icon: AppIcons.signOut,
              label: AppStrings.signOut,
              foreground: error,
              showChevron: false,
              onTap: enabled ? onSignOut : null,
            ),
            const Divider(height: 1, thickness: 1, color: Color(0x14FFFFFF)),
            _SettingsRow(
              icon: AppIcons.userRemove,
              label: AppStrings.deleteAccount,
              foreground: error,
              onTap: enabled ? onDeleteAccount : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.foreground,
    this.showChevron = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? foreground;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final textColor = foreground ?? ZipColors.onInk;
    final leadingColor = iconColor ?? foreground ?? ZipColors.onInk;
    return ListTile(
      enabled: onTap != null,
      leading: AppIcon(icon, color: leadingColor),
      title: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: showChevron
          ? const AppIcon(AppIcons.chevronRight, color: ZipColors.inkSoft)
          : null,
      onTap: onTap,
    );
  }
}
