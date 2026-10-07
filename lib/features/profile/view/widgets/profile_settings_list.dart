import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_theme.dart';

class ProfileSettingsList extends StatelessWidget {
  const ProfileSettingsList({
    super.key,
    required this.onPrivacy,
    required this.onAbout,
    required this.onReport,
    required this.onSignOut,
    this.enabled = true,
    this.sfxEnabled,
    this.onSfxChanged,
  });

  final VoidCallback onPrivacy;
  final VoidCallback onAbout;
  final VoidCallback onReport;
  final VoidCallback onSignOut;

  /// Decorative rows (signed-out mock) ignore taps.
  final bool enabled;

  /// Sound-effects mute; not gated by [enabled].
  final bool? sfxEnabled;
  final ValueChanged<bool>? onSfxChanged;

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
            if (onSfxChanged != null) ...[
              ListTile(
                leading: const Icon(
                  Icons.volume_up_outlined,
                  color: ZipColors.teal,
                ),
                title: Text(
                  AppStrings.profileSoundEffects,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: ZipColors.onInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: Switch.adaptive(
                  value: sfxEnabled ?? true,
                  onChanged: onSfxChanged,
                ),
              ),
              const Divider(height: 1, thickness: 1, color: Color(0x14FFFFFF)),
            ],
            _SettingsRow(
              icon: Icons.privacy_tip_outlined,
              label: AppStrings.profilePrivacyPolicy,
              iconColor: ZipColors.sky,
              onTap: enabled ? onPrivacy : null,
            ),
            const Divider(height: 1, thickness: 1, color: Color(0x14FFFFFF)),
            _SettingsRow(
              icon: Icons.info_outline,
              label: AppStrings.profileAboutGame,
              iconColor: ZipColors.ember,
              onTap: enabled ? onAbout : null,
            ),
            const Divider(height: 1, thickness: 1, color: Color(0x14FFFFFF)),
            _SettingsRow(
              icon: Icons.flag_outlined,
              label: AppStrings.profileReportIssue,
              iconColor: const Color(0xFFFBBF24),
              onTap: enabled ? onReport : null,
            ),
            const Divider(height: 1, thickness: 1, color: Color(0x14FFFFFF)),
            _SettingsRow(
              icon: Icons.logout,
              label: AppStrings.signOut,
              foreground: error,
              showChevron: false,
              onTap: enabled ? onSignOut : null,
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
      leading: Icon(icon, color: leadingColor),
      title: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: showChevron
          ? const Icon(Icons.chevron_right, color: ZipColors.inkSoft)
          : null,
      onTap: onTap,
    );
  }
}
