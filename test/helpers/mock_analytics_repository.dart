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
    () => analytics.logGameStarted(gameId: any(named: 'gameId')),
  ).thenAnswer((_) async {});
  when(
    () => analytics.logGameCompleted(
      gameId: any(named: 'gameId'),
      points: any(named: 'points'),
      timeSeconds: any(named: 'timeSeconds'),
      streak: any(named: 'streak'),
    ),
  ).thenAnswer((_) async {});
  when(
    () => analytics.logHintUsed(
      gameId: any(named: 'gameId'),
      hintsRemaining: any(named: 'hintsRemaining'),
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
}
