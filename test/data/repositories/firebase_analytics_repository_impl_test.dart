import 'package:winklo/core/firebase/firebase_bootstrap.dart';
import 'package:winklo/data/repositories/firebase_analytics_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'FirebaseAnalyticsRepositoryImpl no-ops when Firebase is not ready',
    () async {
      FirebaseBootstrap.isReady = false;
      final repo = FirebaseAnalyticsRepositoryImpl();

      await repo.logScreenView(screenName: 'home');
      await repo.logHomeGameOpened(gameId: 'zip');
      await repo.logGameStarted(gameId: 'zip');
      await repo.logGameCompleted(
        gameId: 'zip',
        points: 10,
        timeSeconds: 5,
        streak: 1,
      );
      await repo.logHintUsed(gameId: 'zip', hintsRemaining: 2);
      await repo.logGameReset(gameId: 'zip');
      await repo.logHowToPlayOpened(gameId: 'zip');
      await repo.logTutorialShown(gameId: 'zip');
      await repo.logTutorialDismissed(gameId: 'zip');
      await repo.logResultsAction(gameId: 'zip', action: 'home');
      await repo.logProfilePrivacyOpened();
      await repo.logProfileAboutOpened();
      await repo.logProfileReportOpened();
      await repo.logProfileReportSubmitted();
      await repo.logProfileSignOut();
      await repo.logAppOpen(platform: 'android');
    },
  );
}
