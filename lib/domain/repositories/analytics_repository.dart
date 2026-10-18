abstract class AnalyticsRepository {
  Future<void> logScreenView({required String screenName});

  Future<void> logHomeGameOpened({required String gameId});

  /// [dayId] is the daily's play id; with [resumed] it gives each day's
  /// start-to-clear rate (first opens vs. returns to a saved run).
  Future<void> logGameStarted({
    required String gameId,
    String? dayId,
    bool resumed = false,
  });

  Future<void> logGameCompleted({
    required String gameId,
    required int points,
    required int timeSeconds,
    int? streak,
    String? dayId,
    bool? usedHints,
  });

  /// [hintsUsed] counts this hint; [penaltySeconds] is the time it added
  /// (0 in practice).
  Future<void> logHintUsed({
    required String gameId,
    required int hintsUsed,
    required int penaltySeconds,
  });

  Future<void> logGameReset({required String gameId});

  Future<void> logHowToPlayOpened({required String gameId});

  Future<void> logTutorialShown({required String gameId});

  Future<void> logTutorialDismissed({required String gameId});

  Future<void> logResultsAction({
    required String gameId,
    required String action,
  });

  Future<void> logProfilePrivacyOpened();

  Future<void> logProfileAboutOpened();

  Future<void> logProfileReportOpened();

  Future<void> logProfileReportSubmitted();

  Future<void> logProfileSignOut();

  Future<void> logProfileDeleteAccountOpened();

  Future<void> logAppOpen({String? platform});

  /// Google sign-in finished.
  Future<void> logLogin();

  /// A daily result went out through the system share sheet.
  Future<void> logShare({required String gameId});

  Future<void> logNotificationOpened({
    required String type,
    required String route,
  });

  /// The soft update banner or the forced update screen appeared.
  Future<void> logUpdatePromptShown({required bool forced});

  Future<void> logUpdatePromptAccepted({required bool forced});

  Future<void> logProfileNameChanged();

  /// [source] is `preset` or `photo`.
  Future<void> logProfileAvatarChanged({required String source});

  /// A clear after a missed day spent the game's streak freeze.
  Future<void> logStreakFreezeUsed({required String gameId});

  /// [source] is `profile`, `personal_best`, or `streak`.
  /// [outcome] is `in_app`, `store`, or `failed`.
  Future<void> logReviewPrompt({
    required String source,
    required String outcome,
  });
}
