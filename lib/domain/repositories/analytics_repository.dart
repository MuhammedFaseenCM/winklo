abstract class AnalyticsRepository {
  Future<void> logScreenView({required String screenName});

  Future<void> logHomeGameOpened({required String gameId});

  Future<void> logGameStarted({required String gameId});

  Future<void> logGameCompleted({
    required String gameId,
    required int points,
    required int timeSeconds,
    int? streak,
  });

  Future<void> logHintUsed({
    required String gameId,
    required int hintsRemaining,
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
}
