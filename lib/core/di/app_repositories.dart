import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:winklo/core/config/avatar_upload_config.dart';
import 'package:winklo/core/config/path_words_nouns_config.dart';
import 'package:winklo/core/dev_flags.dart';
import 'package:winklo/core/sfx/audioplayers_sfx_playback.dart';
import 'package:winklo/core/sfx/sfx_service.dart';
import 'package:winklo/data/clients/avatar/avatar_upload_client.dart';
import 'package:winklo/data/clients/avatar/r2_avatar_upload_client.dart';
import 'package:winklo/data/clients/notification/firebase_notification_client.dart';
import 'package:winklo/data/clients/notification/notification_client.dart';
import 'package:winklo/data/clients/path_words/http_path_words_nouns_client.dart';
import 'package:winklo/data/clients/path_words/path_words_nouns_client.dart';
import 'package:winklo/data/repositories/activity_repository_impl.dart';
import 'package:winklo/data/repositories/app_update_repository_impl.dart';
import 'package:winklo/data/repositories/auth_repository_impl.dart';
import 'package:winklo/data/repositories/category_repository_impl.dart';
import 'package:winklo/data/repositories/firebase_analytics_repository_impl.dart';
import 'package:winklo/data/repositories/hint_quota_repository_impl.dart';
import 'package:winklo/data/repositories/in_progress_run_repository_impl.dart';
import 'package:winklo/data/repositories/issue_report_repository_impl.dart';
import 'package:winklo/data/repositories/leaderboard_repository_impl.dart';
import 'package:winklo/data/repositories/notification_repository_impl.dart';
import 'package:winklo/data/repositories/profile_repository_impl.dart';
import 'package:winklo/data/repositories/score_repository_impl.dart';
import 'package:winklo/data/repositories/sfx_settings_repository_impl.dart';
import 'package:winklo/data/repositories/streak_repository_impl.dart';
import 'package:winklo/data/repositories/tutorial_repository_impl.dart';
import 'package:winklo/data/repositories/word_list_repository_impl.dart';
import 'package:winklo/data/repositories/word_match_repository_impl.dart';
import 'package:winklo/data/repositories/zip_level_repository_impl.dart';
import 'package:winklo/domain/repositories/activity_repository.dart';
import 'package:winklo/domain/repositories/analytics_repository.dart';
import 'package:winklo/domain/repositories/app_update_repository.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/repositories/category_repository.dart';
import 'package:winklo/domain/repositories/hint_quota_repository.dart';
import 'package:winklo/domain/repositories/in_progress_run_repository.dart';
import 'package:winklo/domain/repositories/issue_report_repository.dart';
import 'package:winklo/domain/repositories/leaderboard_repository.dart';
import 'package:winklo/domain/repositories/notification_repository.dart';
import 'package:winklo/domain/repositories/profile_repository.dart';
import 'package:winklo/domain/repositories/score_repository.dart';
import 'package:winklo/domain/repositories/sfx_settings_repository.dart';
import 'package:winklo/domain/repositories/streak_repository.dart';
import 'package:winklo/domain/repositories/tutorial_repository.dart';
import 'package:winklo/domain/repositories/word_list_repository.dart';
import 'package:winklo/domain/repositories/word_match_repository.dart';
import 'package:winklo/domain/repositories/zip_level_repository.dart';
import 'package:winklo/domain/usecases/check_app_update.dart';
import 'package:winklo/domain/usecases/clear_notification_token.dart';
import 'package:winklo/domain/usecases/ensure_signed_in.dart';
import 'package:winklo/domain/usecases/fetch_categories.dart';
import 'package:winklo/domain/usecases/generate_daily_path_words.dart';
import 'package:winklo/domain/usecases/generate_daily_sudoku.dart';
import 'package:winklo/domain/usecases/fetch_word_match_deck_by_id.dart';
import 'package:winklo/domain/usecases/fetch_word_match_decks.dart';
import 'package:winklo/domain/usecases/fetch_zip_levels.dart';
import 'package:winklo/domain/usecases/get_best_points.dart';
import 'package:winklo/domain/usecases/get_best_time_seconds.dart';
import 'package:winklo/domain/usecases/get_streak.dart';
import 'package:winklo/domain/usecases/handle_notification_tap.dart';
import 'package:winklo/domain/usecases/initialize_notifications.dart';
import 'package:winklo/domain/usecases/record_app_open.dart';
import 'package:winklo/domain/usecases/record_daily_clear.dart';
import 'package:winklo/domain/usecases/schedule_engagement_notifications.dart';
import 'package:winklo/domain/usecases/sign_in_with_google.dart';
import 'package:winklo/domain/usecases/sign_out.dart';
import 'package:winklo/domain/usecases/submit_issue_report.dart';
import 'package:winklo/domain/usecases/submit_leaderboard_time.dart';
import 'package:winklo/domain/usecases/submit_score.dart';
import 'package:winklo/domain/usecases/sync_fcm_token.dart';
import 'package:winklo/domain/usecases/update_avatar.dart';
import 'package:winklo/domain/usecases/update_display_name.dart';
import 'package:winklo/domain/usecases/watch_leaderboard.dart';

List<SingleChildWidget> buildRepositoryProviders({
  required SharedPreferences prefs,
}) {
  return [
    RepositoryProvider<SharedPreferences>.value(value: prefs),
    RepositoryProvider<SfxSettingsRepository>(
      create: (context) =>
          SfxSettingsRepositoryImpl(context.read<SharedPreferences>()),
    ),
    RepositoryProvider<SfxService>(
      create: (context) => SfxService(
        settings: context.read<SfxSettingsRepository>(),
        playClip: createAudioplayersPlayClip(),
      ),
    ),
    RepositoryProvider<AnalyticsRepository>(
      create: (_) => FirebaseAnalyticsRepositoryImpl(),
    ),
    RepositoryProvider<NotificationClient>(
      create: (_) => FirebaseNotificationClient(),
    ),
    RepositoryProvider<NotificationRepository>(
      create: (context) => NotificationRepositoryImpl(
        notificationClient: context.read<NotificationClient>(),
      ),
    ),
    RepositoryProvider<InitializeNotifications>(
      create: (context) =>
          InitializeNotifications(context.read<NotificationRepository>()),
    ),
    RepositoryProvider<SyncFcmToken>(
      create: (context) => SyncFcmToken(context.read<NotificationRepository>()),
    ),
    RepositoryProvider<ClearNotificationToken>(
      create: (context) =>
          ClearNotificationToken(context.read<NotificationRepository>()),
    ),
    RepositoryProvider<ScheduleEngagementNotifications>(
      create: (context) => ScheduleEngagementNotifications(
        context.read<NotificationRepository>(),
      ),
    ),
    RepositoryProvider<HandleNotificationTap>(
      create: (_) => HandleNotificationTap(),
    ),
    RepositoryProvider<AuthRepository>(create: (_) => AuthRepositoryImpl()),
    RepositoryProvider<ActivityRepository>(
      create: (context) =>
          ActivityRepositoryImpl(context.read<SharedPreferences>()),
    ),
    RepositoryProvider<RecordAppOpen>(
      create: (context) => RecordAppOpen(
        context.read<AuthRepository>(),
        context.read<ActivityRepository>(),
        context.read<AnalyticsRepository>(),
      ),
    ),
    RepositoryProvider<AvatarUploadClient>(
      create: (_) => R2AvatarUploadClient(baseUrl: AvatarUploadConfig.baseUrl),
    ),
    RepositoryProvider<ProfileRepository>(
      create: (context) => ProfileRepositoryImpl(
        avatarUploadClient: context.read<AvatarUploadClient>(),
      ),
    ),
    RepositoryProvider<UpdateDisplayName>(
      create: (context) => UpdateDisplayName(context.read<ProfileRepository>()),
    ),
    RepositoryProvider<UpdateAvatar>(
      create: (context) => UpdateAvatar(context.read<ProfileRepository>()),
    ),
    RepositoryProvider<IssueReportRepository>(
      create: (_) => IssueReportRepositoryImpl(),
    ),
    RepositoryProvider<SubmitIssueReport>(
      create: (context) =>
          SubmitIssueReport(context.read<IssueReportRepository>()),
    ),
    RepositoryProvider<LeaderboardRepository>(
      create: (_) => LeaderboardRepositoryImpl(),
    ),
    RepositoryProvider<SignInWithGoogle>(
      create: (context) => SignInWithGoogle(context.read<AuthRepository>()),
    ),
    RepositoryProvider<SignOut>(
      create: (context) => SignOut(context.read<AuthRepository>()),
    ),
    RepositoryProvider<EnsureSignedIn>(
      create: (context) => EnsureSignedIn(context.read<AuthRepository>()),
    ),
    RepositoryProvider<WatchLeaderboard>(
      create: (context) =>
          WatchLeaderboard(context.read<LeaderboardRepository>()),
    ),
    RepositoryProvider<SubmitLeaderboardTime>(
      create: (context) =>
          SubmitLeaderboardTime(context.read<LeaderboardRepository>()),
    ),
    RepositoryProvider<AppUpdateRepository>(
      create: (_) => AppUpdateRepositoryImpl(),
    ),
    RepositoryProvider<CheckAppUpdate>(
      create: (context) => CheckAppUpdate(context.read<AppUpdateRepository>()),
    ),
    RepositoryProvider<ScoreRepository>(
      create: (context) =>
          ScoreRepositoryImpl(context.read<SharedPreferences>()),
    ),
    RepositoryProvider<HintQuotaRepository>(
      create: (context) => HintQuotaRepositoryImpl(
        context.read<SharedPreferences>(),
        playPeriod: DevFlags.playPeriod,
      ),
    ),
    RepositoryProvider<StreakRepository>(
      create: (context) =>
          StreakRepositoryImpl(context.read<SharedPreferences>()),
    ),
    RepositoryProvider<TutorialRepository>(
      create: (context) =>
          TutorialRepositoryImpl(context.read<SharedPreferences>()),
    ),
    RepositoryProvider<InProgressRunRepository>(
      create: (context) =>
          InProgressRunRepositoryImpl(context.read<SharedPreferences>()),
    ),
    RepositoryProvider<ZipLevelRepository>(
      create: (_) => ZipLevelRepositoryImpl(),
    ),
    RepositoryProvider<WordMatchRepository>(
      create: (_) => WordMatchRepositoryImpl(),
    ),
    RepositoryProvider<CategoryRepository>(
      create: (_) => CategoryRepositoryImpl(),
    ),
    RepositoryProvider<PathWordsNounsClient>(
      create: (_) =>
          HttpPathWordsNounsClient(baseUrl: PathWordsNounsConfig.baseUrl),
    ),
    RepositoryProvider<WordListRepository>(
      create: (context) => WordListRepositoryImpl(
        prefs: context.read<SharedPreferences>(),
        nounsClient: context.read<PathWordsNounsClient>(),
      ),
    ),
    RepositoryProvider<SubmitScore>(
      create: (context) => SubmitScore(context.read<ScoreRepository>()),
    ),
    RepositoryProvider<GetBestPoints>(
      create: (context) => GetBestPoints(context.read<ScoreRepository>()),
    ),
    RepositoryProvider<GetBestTimeSeconds>(
      create: (context) => GetBestTimeSeconds(context.read<ScoreRepository>()),
    ),
    RepositoryProvider<GetStreak>(
      create: (context) => GetStreak(context.read<StreakRepository>()),
    ),
    RepositoryProvider<RecordDailyClear>(
      create: (context) => RecordDailyClear(context.read<StreakRepository>()),
    ),
    RepositoryProvider<FetchZipLevels>(
      create: (context) => FetchZipLevels(context.read<ZipLevelRepository>()),
    ),
    RepositoryProvider<FetchWordMatchDecks>(
      create: (context) =>
          FetchWordMatchDecks(context.read<WordMatchRepository>()),
    ),
    RepositoryProvider<FetchWordMatchDeckById>(
      create: (context) =>
          FetchWordMatchDeckById(context.read<WordMatchRepository>()),
    ),
    RepositoryProvider<FetchCategories>(
      create: (context) => FetchCategories(context.read<CategoryRepository>()),
    ),
    RepositoryProvider<GenerateDailyPathWords>(
      create: (context) => GenerateDailyPathWords(
        context.read<WordListRepository>(),
        period: DevFlags.playPeriod,
      ),
    ),
    RepositoryProvider<GenerateDailySudoku>(
      create: (_) => GenerateDailySudoku(period: DevFlags.playPeriod),
    ),
  ];
}
