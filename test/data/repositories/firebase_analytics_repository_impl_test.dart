import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/firebase/firebase_bootstrap.dart';
import 'package:winklo/data/repositories/firebase_analytics_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockFirebaseAnalytics extends Mock implements FirebaseAnalytics {}

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
      await repo.logHintUsed(gameId: 'zip', hintsUsed: 2, penaltySeconds: 20);
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

  group('with Firebase ready', () {
    late _MockFirebaseAnalytics firebase;
    late FirebaseAnalyticsRepositoryImpl repo;

    setUp(() {
      FirebaseBootstrap.isReady = true;
      firebase = _MockFirebaseAnalytics();
      repo = FirebaseAnalyticsRepositoryImpl(analytics: firebase);
      when(
        () => firebase.logEvent(
          name: any(named: 'name'),
          parameters: any(named: 'parameters'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => firebase.logLogin(loginMethod: any(named: 'loginMethod')),
      ).thenAnswer((_) async {});
      when(
        () => firebase.logShare(
          contentType: any(named: 'contentType'),
          itemId: any(named: 'itemId'),
          method: any(named: 'method'),
        ),
      ).thenAnswer((_) async {});
    });

    tearDown(() => FirebaseBootstrap.isReady = false);

    void verifyEvent(String name, Map<String, Object>? parameters) {
      verify(
        () => firebase.logEvent(name: name, parameters: parameters),
      ).called(1);
    }

    test('game_started carries the day and whether the run resumed', () async {
      await repo.logGameStarted(
        gameId: 'zip',
        dayId: '20261014',
        resumed: true,
      );
      verifyEvent('game_started', {
        'game_id': 'zip',
        'day_id': '20261014',
        'resumed': 1,
      });
    });

    test('game_started without a day keeps the old shape', () async {
      await repo.logGameStarted(gameId: 'word_match');
      verifyEvent('game_started', {'game_id': 'word_match', 'resumed': 0});
    });

    test('game_completed carries the day and hint use', () async {
      await repo.logGameCompleted(
        gameId: 'sudoku',
        points: 90,
        timeSeconds: 75,
        streak: 3,
        dayId: '20261014',
        usedHints: false,
      );
      verifyEvent('game_completed', {
        'game_id': 'sudoku',
        'points': 90,
        'time_seconds': 75,
        'streak': 3,
        'day_id': '20261014',
        'used_hints': 0,
      });
    });

    test('sign-in logs the standard login event', () async {
      await repo.logLogin();
      verify(() => firebase.logLogin(loginMethod: 'google')).called(1);
    });

    test('sharing a result logs the standard share event', () async {
      await repo.logShare(gameId: 'zip');
      verify(
        () => firebase.logShare(
          contentType: 'daily_result',
          itemId: 'zip',
          method: 'share_sheet',
        ),
      ).called(1);
    });

    test('notification_opened carries the type and route', () async {
      await repo.logNotificationOpened(type: 'streak_at_risk', route: '/');
      verifyEvent('notification_opened', {
        'type': 'streak_at_risk',
        'route': '/',
      });
    });

    test('update prompts log their kind', () async {
      await repo.logUpdatePromptShown(forced: false);
      await repo.logUpdatePromptAccepted(forced: true);
      verifyEvent('update_prompt_shown', {'kind': 'soft'});
      verifyEvent('update_prompt_accepted', {'kind': 'forced'});
    });

    test('profile changes log name and avatar source', () async {
      await repo.logProfileNameChanged();
      await repo.logProfileAvatarChanged(source: 'photo');
      verifyEvent('profile_name_changed', null);
      verifyEvent('profile_avatar_changed', {'source': 'photo'});
    });

    test('streak_freeze_used names the game', () async {
      await repo.logStreakFreezeUsed(gameId: 'sudoku');
      verifyEvent('streak_freeze_used', {'game_id': 'sudoku'});
    });
  });
}
