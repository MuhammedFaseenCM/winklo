import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/zip_ui.dart';
import '../../../domain/repositories/settings_repository.dart';
import '../../../domain/usecases/save_reminder_settings.dart';
import '../cubit/settings_cubit.dart';
import '../cubit/settings_state.dart';
import 'widgets/settings_language_slot.dart';
import 'widgets/settings_section.dart';

/// `/profile/settings`: sound and vibration, reminders, and (later) the
/// language.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SettingsCubit(
        settings: context.read<SettingsRepository>(),
        saveReminders: context.read<SaveReminderSettings>(),
      ),
      child: const _SettingsView(),
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView();

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    return Scaffold(
      backgroundColor: ZipColors.ink,
      appBar: AppBar(
        title: Text(
          AppStrings.settingsTitle,
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: ZipColors.onInk,
      ),
      body: ZipAtmosphere(
        child: BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, state) {
            final cubit = context.read<SettingsCubit>();
            final reminders = state.reminders;
            final gap = SizedBox(height: layout.space(20));
            // Clear of the shell's floating nav dock (extendBody).
            final bottomInset = MediaQuery.paddingOf(context).bottom;
            return ListView(
              padding: layout.pagePadding.copyWith(
                bottom: layout.pagePadding.bottom + bottomInset,
              ),
              children: [
                SettingsSection(
                  title: AppStrings.settingsSoundSection,
                  children: [
                    SettingsSwitchRow(
                      icon: Icons.volume_up_outlined,
                      title: AppStrings.profileSoundEffects,
                      value: state.soundEnabled,
                      onChanged: (v) => unawaited(cubit.setSound(v)),
                    ),
                    SettingsSwitchRow(
                      icon: Icons.vibration_rounded,
                      title: AppStrings.profileVibration,
                      value: state.vibrationEnabled,
                      onChanged: (v) => unawaited(cubit.setVibration(v)),
                    ),
                  ],
                ),
                gap,
                SettingsSection(
                  title: AppStrings.settingsRemindersSection,
                  children: [
                    SettingsSwitchRow(
                      icon: Icons.wb_sunny_outlined,
                      title: AppStrings.settingsDailyReady,
                      subtitle: AppStrings.settingsDailyReadyHint,
                      value: reminders.dailyReadyEnabled,
                      onChanged: (v) => unawaited(cubit.setDailyReady(v)),
                    ),
                    SettingsTimeRow(
                      reminder: AppStrings.settingsDailyReady,
                      minutes: reminders.dailyReadyMinutes,
                      enabled: reminders.dailyReadyEnabled,
                      onChanged: (m) => unawaited(cubit.setDailyReadyTime(m)),
                    ),
                    SettingsSwitchRow(
                      icon: Icons.local_fire_department_outlined,
                      title: AppStrings.settingsStreakAtRisk,
                      subtitle: AppStrings.settingsStreakAtRiskHint,
                      value: reminders.streakAtRiskEnabled,
                      onChanged: (v) => unawaited(cubit.setStreakAtRisk(v)),
                    ),
                    SettingsTimeRow(
                      reminder: AppStrings.settingsStreakAtRisk,
                      minutes: reminders.streakReminderMinutes,
                      enabled: reminders.streakAtRiskEnabled,
                      onChanged: (m) =>
                          unawaited(cubit.setStreakReminderTime(m)),
                    ),
                    SettingsSwitchRow(
                      icon: Icons.insights_rounded,
                      title: AppStrings.settingsWeeklyRecap,
                      subtitle: AppStrings.settingsWeeklyRecapHint(
                        SettingsTimeRow.format(
                          context,
                          reminders.weeklyRecapMinutes,
                        ),
                      ),
                      value: reminders.weeklyRecapEnabled,
                      onChanged: (v) => unawaited(cubit.setWeeklyRecap(v)),
                    ),
                    SettingsSwitchRow(
                      icon: Icons.campaign_outlined,
                      title: AppStrings.settingsAnnouncements,
                      subtitle: AppStrings.settingsAnnouncementsHint,
                      value: reminders.announcementsEnabled,
                      onChanged: (v) => unawaited(cubit.setAnnouncements(v)),
                    ),
                  ],
                ),
                if (SettingsLanguageSlot.visible) ...[
                  gap,
                  SettingsSection(
                    title: AppStrings.settingsLanguageSection,
                    children: [SettingsLanguageSlot()],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
