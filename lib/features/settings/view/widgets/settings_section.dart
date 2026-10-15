import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_theme.dart';

/// A titled card of setting rows, in the style of Profile's list.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: layout.space(6),
            bottom: layout.space(8),
          ),
          child: Semantics(
            header: true,
            child: Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: ZipColors.inkSoft,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
        DecoratedBox(
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
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0x14FFFFFF),
                    ),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// An on/off setting.
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hint = subtitle;
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      secondary: Icon(icon, color: ZipColors.teal),
      title: Text(
        title,
        style: textTheme.titleSmall?.copyWith(
          color: ZipColors.onInk,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: hint == null
          ? null
          : Text(
              hint,
              style: textTheme.bodySmall?.copyWith(color: ZipColors.inkSoft),
            ),
    );
  }
}

/// The time of a reminder, opening the time picker. Dimmed while its
/// reminder is off.
class SettingsTimeRow extends StatelessWidget {
  const SettingsTimeRow({
    super.key,
    required this.reminder,
    required this.minutes,
    required this.onChanged,
    this.enabled = true,
  });

  /// The reminder this is the time of (for screen readers).
  final String reminder;

  /// Minutes after midnight.
  final int minutes;
  final ValueChanged<int> onChanged;
  final bool enabled;

  static String format(BuildContext context, int minutes) {
    return MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked == null) return;
    onChanged(picked.hour * 60 + picked.minute);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final time = format(context, minutes);
    return MergeSemantics(
      child: Semantics(
        label: AppStrings.settingsReminderTimeLabel(reminder, time),
        excludeSemantics: true,
        button: true,
        enabled: enabled,
        child: ListTile(
          enabled: enabled,
          onTap: enabled ? () => _pick(context) : null,
          leading: const SizedBox(width: 24),
          title: Text(
            AppStrings.settingsReminderTime,
            style: textTheme.bodyMedium?.copyWith(
              color: enabled ? ZipColors.inkSoft : ZipColors.outline,
            ),
          ),
          trailing: Text(
            time,
            style: textTheme.titleSmall?.copyWith(
              color: enabled ? ZipColors.ember : ZipColors.outline,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
