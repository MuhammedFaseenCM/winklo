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

  @override
  Future<void> logGameStarted({required String gameId}) {
    return _safe(
      (a) => a.logEvent(name: 'game_started', parameters: {'game_id': gameId}),
    );
  }

  @override
  Future<void> logGameCompleted({
    required String gameId,
    required int points,
    required int timeSeconds,
    int? streak,
  }) {
    return _safe((a) {
      final parameters = <String, Object>{
        'game_id': gameId,
        'points': points,
        'time_seconds': timeSeconds,
      };
      if (streak != null) {
        parameters['streak'] = streak;
      }
      return a.logEvent(name: 'game_completed', parameters: parameters);
    });
  }

  @override
  Future<void> logHintUsed({
    required String gameId,
    required int hintsRemaining,
  }) {
    return _safe(
      (a) => a.logEvent(
        name: 'hint_used',
        parameters: {'game_id': gameId, 'hints_remaining': hintsRemaining},
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
}
