// Temporary switches for local playtesting. Keep these off for shipping.
import 'package:flutter/foundation.dart';

import '../domain/play_period.dart';

abstract final class DevFlags {
  /// Home shows only Zip, and today's Zip can be played again.
  static const zipOnlyTesting = false;

  /// Widget tests run in debug; keep the daily keyspace stable there.
  static bool useDailyPlayPeriodInTests = false;

  /// Debug: use calendar-day puzzle IDs like release (`daily_YYYYMMDD`).
  ///
  /// Pass `--dart-define=DAILY_PLAY_PERIOD=true` (see `.vscode/launch.json`).
  /// When false/absent, debug still rotates a new puzzle every minute.
  static const dailyPlayPeriod = bool.fromEnvironment(
    'DAILY_PLAY_PERIOD',
    defaultValue: false,
  );

  /// Debug builds rotate a new puzzle every minute unless tests or
  /// [dailyPlayPeriod] force the release-like daily keyspace.
  static bool get minutePlayPeriod =>
      kDebugMode && !useDailyPlayPeriodInTests && !dailyPlayPeriod;

  static Duration get playPeriod =>
      minutePlayPeriod ? PlayPeriod.minute : PlayPeriod.daily;
}
