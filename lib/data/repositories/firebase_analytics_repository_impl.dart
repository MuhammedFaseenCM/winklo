import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import '../../core/firebase/firebase_bootstrap.dart';
import '../../domain/repositories/analytics_repository.dart';

class FirebaseAnalyticsRepositoryImpl implements AnalyticsRepository {
  FirebaseAnalyticsRepositoryImpl({FirebaseAnalytics? analytics})
    : _injected = analytics;

  final FirebaseAnalytics? _injected;

  FirebaseAnalytics? get _client {
    if (!FirebaseBootstrap.isReady) return null;
    return _injected ?? FirebaseAnalytics.instance;
  }

  Future<void> _safe(
    Future<void> Function(FirebaseAnalytics analytics) run,
  ) async {
    final analytics = _client;
    if (analytics == null) return;
    try {
      await run(analytics);
    } catch (e, st) {
      debugPrint('Analytics log failed: $e');
      debugPrint('$st');
    }
  }

  @override
  Future<void> logScreenView({required String screenName}) {
    return _safe(
      (a) => a.logScreenView(screenName: screenName, screenClass: screenName),
    );
  }

  @override
  Future<void> logHomeGameOpened({required String gameId}) {
    return _safe(
      (a) =>
          a.logEvent(name: 'home_game_opened', parameters: {'game_id': gameId}),
    );
  }

  // Analytics parameters can't be booleans; flags are logged as 1 or 0.
  static int _flag(bool value) => value ? 1 : 0;

  @override
  Future<void> logGameStarted({
    required String gameId,
    String? dayId,
    bool resumed = false,
  }) {
    return _safe(
      (a) => a.logEvent(
        name: 'game_started',
        parameters: {
          'game_id': gameId,
          'day_id': ?dayId,
          'resumed': _flag(resumed),
        },
      ),
    );
  }

  @override
  Future<void> logGameCompleted({
    required String gameId,
    required int points,
    required int timeSeconds,
    int? streak,
    String? dayId,
    bool? usedHints,
  }) {
    return _safe((a) {
      final parameters = <String, Object>{
        'game_id': gameId,
        'points': points,
        'time_seconds': timeSeconds,
        'streak': ?streak,
        'day_id': ?dayId,
        if (usedHints != null) 'used_hints': _flag(usedHints),
      };
      return a.logEvent(name: 'game_completed', parameters: parameters);
    });
  }

  @override
  Future<void> logHintUsed({
    required String gameId,
    required int hintsUsed,
    required int penaltySeconds,
  }) {
    return _safe(
      (a) => a.logEvent(
        name: 'hint_used',
        parameters: {
          'game_id': gameId,
          'hints_used': hintsUsed,
          'penalty_seconds': penaltySeconds,
        },
      ),
    );
  }

  @override
  Future<void> logGameReset({required String gameId}) {
    return _safe(
      (a) => a.logEvent(name: 'game_reset', parameters: {'game_id': gameId}),
    );
  }

  @override
  Future<void> logHowToPlayOpened({required String gameId}) {
    return _safe(
      (a) => a.logEvent(
        name: 'how_to_play_opened',
        parameters: {'game_id': gameId},
      ),
    );
  }

  @override
  Future<void> logTutorialShown({required String gameId}) {
    return _safe(
      (a) =>
          a.logEvent(name: 'tutorial_shown', parameters: {'game_id': gameId}),
    );
  }

  @override
  Future<void> logTutorialDismissed({required String gameId}) {
    return _safe(
      (a) => a.logEvent(
        name: 'tutorial_dismissed',
        parameters: {'game_id': gameId},
      ),
    );
  }

  @override
  Future<void> logResultsAction({
    required String gameId,
    required String action,
  }) {
    return _safe(
      (a) => a.logEvent(
        name: 'results_action',
        parameters: {'game_id': gameId, 'action': action},
      ),
    );
  }

  @override
  Future<void> logProfilePrivacyOpened() {
    return _safe((a) => a.logEvent(name: 'profile_privacy_opened'));
  }

  @override
  Future<void> logProfileAboutOpened() {
    return _safe((a) => a.logEvent(name: 'profile_about_opened'));
  }

  @override
  Future<void> logProfileReportOpened() {
    return _safe((a) => a.logEvent(name: 'profile_report_opened'));
  }

  @override
  Future<void> logProfileReportSubmitted() {
    return _safe((a) => a.logEvent(name: 'profile_report_submitted'));
  }

  @override
  Future<void> logProfileSignOut() {
    return _safe((a) => a.logEvent(name: 'profile_sign_out'));
  }

  @override
  Future<void> logProfileDeleteAccountOpened() {
    return _safe((a) => a.logEvent(name: 'profile_delete_account_opened'));
  }

  @override
  Future<void> logAppOpen({String? platform}) {
    return _safe((a) {
      final parameters = <String, Object>{};
      if (platform != null && platform.isNotEmpty) {
        parameters['platform'] = platform;
      }
      return a.logEvent(
        name: 'app_open',
        parameters: parameters.isEmpty ? null : parameters,
      );
    });
  }

  @override
  Future<void> logLogin() {
    return _safe((a) => a.logLogin(loginMethod: 'google'));
  }

  @override
  Future<void> logShare({required String gameId}) {
    return _safe(
      (a) => a.logShare(
        contentType: 'daily_result',
        itemId: gameId,
        method: 'share_sheet',
      ),
    );
  }

  @override
  Future<void> logNotificationOpened({
    required String type,
    required String route,
  }) {
    return _safe(
      (a) => a.logEvent(
        name: 'notification_opened',
        parameters: {'type': type, 'route': route},
      ),
    );
  }

  @override
  Future<void> logUpdatePromptShown({required bool forced}) {
    return _safe(
      (a) => a.logEvent(
        name: 'update_prompt_shown',
        parameters: {'kind': forced ? 'forced' : 'soft'},
      ),
    );
  }

  @override
  Future<void> logUpdatePromptAccepted({required bool forced}) {
    return _safe(
      (a) => a.logEvent(
        name: 'update_prompt_accepted',
        parameters: {'kind': forced ? 'forced' : 'soft'},
      ),
    );
  }

  @override
  Future<void> logProfileNameChanged() {
    return _safe((a) => a.logEvent(name: 'profile_name_changed'));
  }

  @override
  Future<void> logProfileAvatarChanged({required String source}) {
    return _safe(
      (a) => a.logEvent(
        name: 'profile_avatar_changed',
        parameters: {'source': source},
      ),
    );
  }

  @override
  Future<void> logStreakFreezeUsed({required String gameId}) {
    return _safe(
      (a) => a.logEvent(
        name: 'streak_freeze_used',
        parameters: {'game_id': gameId},
      ),
    );
  }

  @override
  Future<void> logReviewPrompt({
    required String source,
    required String outcome,
  }) {
    return _safe(
      (a) => a.logEvent(
        name: 'review_prompt',
        parameters: {'source': source, 'outcome': outcome},
      ),
    );
  }
}
