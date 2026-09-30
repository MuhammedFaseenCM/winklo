import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class RemoteConfigClient {
  RemoteConfigClient._();
  static final instance = RemoteConfigClient._();

  bool _initialized = false;
  Map<String, dynamic> _defaults = const {};

  bool get isInitialized => _initialized;

  static const kAppVersionKey = 'appVersion';
  static const kMinBuildNumberKey = 'minBuildNumber';
  static const kForceUpdateKey = 'forceUpdate';
  static const kAppStoreUrlKey = 'appStoreUrl';
  static const kPlayStoreUrlKey = 'playStoreUrl';
  static const kShowAllTimeLeaderboardKey = 'showAllTimeLeaderboard';

  static const defaultPlayStoreUrl =
      'https://play.google.com/store/apps/details?id=com.winklo.faseencm';

  static Map<String, dynamic> defaultValues() => {
    kAppVersionKey: '0.0.0',
    kMinBuildNumberKey: 0,
    kForceUpdateKey: false,
    kAppStoreUrlKey: '',
    kPlayStoreUrlKey: defaultPlayStoreUrl,
    kShowAllTimeLeaderboardKey: true,
  };

  Future<void> initialize({
    Map<String, dynamic>? defaults,
    Duration fetchTimeout = const Duration(seconds: 10),
    Duration minimumFetchInterval = Duration.zero,
  }) async {
    if (_initialized) return;
    _initialized = true;
    _defaults = defaults ?? defaultValues();
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setDefaults(_defaults);
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: fetchTimeout,
          minimumFetchInterval: minimumFetchInterval,
        ),
      );
      await remoteConfig.fetchAndActivate();
    } catch (e) {
      debugPrint('RemoteConfigClient: init failed — $e');
    }
  }

  Future<bool> refresh() async {
    if (!_initialized) return false;
    try {
      return await FirebaseRemoteConfig.instance.fetchAndActivate();
    } catch (e) {
      debugPrint('RemoteConfigClient: refresh failed — $e');
      return false;
    }
  }

  String getString(String key) {
    final fallback =
        (_defaults[key] as String?) ?? (defaultValues()[key] as String? ?? '');
    if (!_initialized) {
      return fallback.trim();
    }
    try {
      return FirebaseRemoteConfig.instance.getString(key).trim();
    } catch (e) {
      debugPrint('RemoteConfigClient: getString($key) failed — $e');
      return fallback.trim();
    }
  }

  bool getBool(String key) {
    final fallback =
        (_defaults[key] as bool?) ?? (defaultValues()[key] as bool? ?? false);
    if (!_initialized) {
      return fallback;
    }
    try {
      return FirebaseRemoteConfig.instance.getBool(key);
    } catch (e) {
      debugPrint('RemoteConfigClient: getBool($key) failed — $e');
      return fallback;
    }
  }

  int getInt(String key) {
    final fallback =
        (_defaults[key] as int?) ?? (defaultValues()[key] as int? ?? 0);
    if (!_initialized) {
      return fallback;
    }
    try {
      return FirebaseRemoteConfig.instance.getInt(key);
    } catch (e) {
      debugPrint('RemoteConfigClient: getInt($key) failed — $e');
      return fallback;
    }
  }

  String get appVersion => getString(kAppVersionKey);
  int get minBuildNumber => getInt(kMinBuildNumberKey);
  bool get forceUpdate => getBool(kForceUpdateKey);
  String get playStoreUrl => getString(kPlayStoreUrlKey);
  String get appStoreUrl => getString(kAppStoreUrlKey);
  bool get showAllTimeLeaderboard => getBool(kShowAllTimeLeaderboardKey);
}
