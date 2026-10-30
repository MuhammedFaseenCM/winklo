import 'package:winklo/domain/repositories/analytics_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockAnalyticsRepository extends Mock implements AnalyticsRepository {}

void stubAnalytics(MockAnalyticsRepository analytics) {
  when(
    () => analytics.logScreenView(screenName: any(named: 'screenName')),
  ).thenAnswer((_) async {});
  when(
    () => analytics.logHomeGameOpened(gameId: any(named: 'gameId')),
  ).thenAnswer((_) async {});
  when(
    () => analytics.logGameStarted(
      gameId: any(named: 'gameId'),
      dayId: any(named: 'dayId'),
      resumed: any(named: 'resumed'),
    ),
  ).thenAnswer((_) async {});
  when(
    () => analytics.logGameCompleted(
      gameId: any(named: 'gameId'),
      points: any(named: 'points'),
      timeSeconds: any(named: 'timeSeconds'),
      streak: any(named: 'streak'),
      dayId: any(named: 'dayId'),
      usedHints: any(named: 'usedHints'),
    ),
  ).thenAnswer((_) async {});
  when(
    () => analytics.logLevelCleared(
      gameId: any(named: 'gameId'),
      levelId: any(named: 'levelId'),
      world: any(named: 'world'),
      number: any(named: 'number'),
      stars: any(named: 'stars'),
      firstClear: any(named: 'firstClear'),
      improved: any(named: 'improved'),
    ),
  ).thenAnswer((_) async {});
  when(
    () => analytics.logHintUsed(
      gameId: any(named: 'gameId'),
      hintsUsed: any(named: 'hintsUsed'),
      penaltySeconds: any(named: 'penaltySeconds'),
    ),
  ).thenAnswer((_) async {});
  when(
    () => analytics.logGameReset(gameId: any(named: 'gameId')),
  ).thenAnswer((_) async {});
  when(
    () => analytics.logHowToPlayOpened(gameId: any(named: 'gameId')),
  ).thenAnswer((_) async {});
  when(
    () => analytics.logTutorialShown(gameId: any(named: 'gameId')),
  ).thenAnswer((_) async {});
  when(
    () => analytics.logTutorialDismissed(gameId: any(named: 'gameId')),
  ).thenAnswer((_) async {});
  when(
    () => analytics.logResultsAction(
      gameId: any(named: 'gameId'),
      action: any(named: 'action'),
    ),
  ).thenAnswer((_) async {});
  when(() => analytics.logProfilePrivacyOpened()).thenAnswer((_) async {});
  when(() => analytics.logProfileAboutOpened()).thenAnswer((_) async {});
  when(() => analytics.logProfileReportOpened()).thenAnswer((_) async {});
  when(() => analytics.logProfileReportSubmitted()).thenAnswer((_) async {});
  when(() => analytics.logProfileSignOut()).thenAnswer((_) async {});
  when(
    () => analytics.logProfileDeleteAccountOpened(),
  ).thenAnswer((_) async {});
  when(() => analytics.logLogin()).thenAnswer((_) async {});
  when(
    () => analytics.logShare(gameId: any(named: 'gameId')),
  ).thenAnswer((_) async {});
  when(
    () => analytics.logNotificationOpened(
      type: any(named: 'type'),
      route: any(named: 'route'),
    ),
  ).thenAnswer((_) async {});
  when(
    () => analytics.logUpdatePromptShown(forced: any(named: 'forced')),
  ).thenAnswer((_) async {});
  when(
    () => analytics.logUpdatePromptAccepted(forced: any(named: 'forced')),
  ).thenAnswer((_) async {});
  when(() => analytics.logProfileNameChanged()).thenAnswer((_) async {});
  when(
    () => analytics.logProfileAvatarChanged(source: any(named: 'source')),
  ).thenAnswer((_) async {});
  when(
    () => analytics.logStreakFreezeUsed(gameId: any(named: 'gameId')),
  ).thenAnswer((_) async {});
  when(
    () => analytics.logReviewPrompt(
      source: any(named: 'source'),
      outcome: any(named: 'outcome'),
    ),
  ).thenAnswer((_) async {});
}
