import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:winklo/core/dev_flags.dart';
import 'package:winklo/core/haptics/haptics_service.dart';
import 'package:winklo/core/sfx/sfx_service.dart';
import 'package:winklo/data/repositories/home_widget_repository_impl.dart';
import 'package:winklo/data/repositories/settings_repository_impl.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/repositories/home_widget_repository.dart';
import 'package:winklo/domain/repositories/notification_repository.dart';
import 'package:winklo/domain/repositories/score_repository.dart';
import 'package:winklo/domain/repositories/settings_repository.dart';
import 'package:winklo/domain/usecases/get_streak.dart';
import 'package:winklo/domain/usecases/get_weekly_recap.dart';
import 'package:winklo/domain/usecases/refresh_habit_surfaces.dart';
import 'package:winklo/domain/usecases/save_reminder_settings.dart';
import 'package:winklo/domain/usecases/schedule_engagement_notifications.dart';

/// Settings, reminders, the weekly recap and the home-screen widget. Goes at
/// the end of [buildRepositoryProviders]: it reads the score, streak,
/// notification and auth providers declared before it.
List<SingleChildWidget> buildHabitProviders() => [
  RepositoryProvider<SettingsRepository>(
    create: (context) => SettingsRepositoryImpl(
      context.read<SharedPreferences>(),
      sfx: context.read<SfxService>(),
      haptics: context.read<HapticsService>(),
    ),
  ),
  RepositoryProvider<HomeWidgetRepository>(
    create: (_) => HomeWidgetRepositoryImpl(),
  ),
  RepositoryProvider<GetWeeklyRecap>(
    create: (context) => GetWeeklyRecap(context.read<ScoreRepository>()),
  ),
  RepositoryProvider<RefreshHabitSurfaces>(
    create: (context) => RefreshHabitSurfaces(
      getStreak: context.read<GetStreak>(),
      scores: context.read<ScoreRepository>(),
      settings: context.read<SettingsRepository>(),
      schedule: context.read<ScheduleEngagementNotifications>(),
      weeklyRecap: context.read<GetWeeklyRecap>(),
      homeWidget: context.read<HomeWidgetRepository>(),
      playPeriod: DevFlags.playPeriod,
    ),
  ),
  RepositoryProvider<SaveReminderSettings>(
    create: (context) => SaveReminderSettings(
      settings: context.read<SettingsRepository>(),
      notifications: context.read<NotificationRepository>(),
      auth: context.read<AuthRepository>(),
      refresh: context.read<RefreshHabitSurfaces>().call,
    ),
  ),
];
