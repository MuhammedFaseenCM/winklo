import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/repositories/app_review_repository.dart';
import '../clients/remote_config_client.dart';

class AppReviewRepositoryImpl implements AppReviewRepository {
  AppReviewRepositoryImpl({
    required SharedPreferences prefs,
    required String playStoreUrl,
    DateTime Function()? clock,
    Future<bool> Function()? isReviewAvailable,
    Future<void> Function()? requestReview,
    Future<bool> Function(String url)? openStoreUrl,
  }) : _prefs = prefs,
       _playStoreUrl = playStoreUrl,
       _clock = clock ?? DateTime.now,
       _isReviewAvailable =
           isReviewAvailable ?? (() => InAppReview.instance.isAvailable()),
       _requestReview =
           requestReview ?? (() => InAppReview.instance.requestReview()),
       _openStoreUrl = openStoreUrl ?? _launchStore;

  static const lastMsKey = 'review_auto_last_ms';
  static const attemptsKey = 'review_auto_attempts';
  static const cooldown = Duration(days: 30);
  static const maxAttempts = 3;
  static const streakThreshold = 7;

  final SharedPreferences _prefs;
  final String _playStoreUrl;
  final DateTime Function() _clock;
  final Future<bool> Function() _isReviewAvailable;
  final Future<void> Function() _requestReview;
  final Future<bool> Function(String url) _openStoreUrl;

  static Future<bool> _launchStore(String url) async {
    try {
      final uri = Uri.parse(url);
      if (!await canLaunchUrl(uri)) return false;
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  String get _resolvedStoreUrl {
    final trimmed = _playStoreUrl.trim();
    return trimmed.isEmpty ? RemoteConfigClient.defaultPlayStoreUrl : trimmed;
  }

  @override
  bool shouldPromptAfterMilestone({
    required bool isPersonalBest,
    required int? streak,
  }) {
    final milestone = isPersonalBest || (streak ?? 0) >= streakThreshold;
    if (!milestone) return false;
    final attempts = _prefs.getInt(attemptsKey) ?? 0;
    if (attempts >= maxAttempts) return false;
    final lastMs = _prefs.getInt(lastMsKey);
    if (lastMs == null) return true;
    final elapsed = _clock().difference(
      DateTime.fromMillisecondsSinceEpoch(lastMs, isUtc: true),
    );
    return elapsed >= cooldown;
  }

  @override
  Future<void> recordAutoPromptAttempt() async {
    final attempts = (_prefs.getInt(attemptsKey) ?? 0) + 1;
    await _prefs.setInt(attemptsKey, attempts);
    await _prefs.setInt(lastMsKey, _clock().toUtc().millisecondsSinceEpoch);
  }

  @override
  Future<ReviewOutcome> requestReviewOrOpenStore() async {
    try {
      if (await _isReviewAvailable()) {
        await _requestReview();
        return ReviewOutcome.inApp;
      }
    } catch (_) {
      // Fall through to store.
    }
    return openStoreListing();
  }

  @override
  Future<ReviewOutcome> openStoreListing() async {
    final opened = await _openStoreUrl(_resolvedStoreUrl);
    return opened ? ReviewOutcome.store : ReviewOutcome.failed;
  }
}
