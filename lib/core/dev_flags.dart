// Temporary switches for local playtesting. Keep these off for shipping.
import 'package:flutter/foundation.dart';

import '../domain/play_period.dart';

abstract final class DevFlags {
  /// Home shows only Zip, and today's Zip can be played again.
  static const zipOnlyTesting = false;

  /// Temporary: Profile badges + `/profile/stats` show a fully unlocked
  /// preview (no Firestore writes). Turn off before shipping.
  static const previewFullProgress = false;

  /// Stats/profile tests set this so they still hit [LoadGameHistory].
  static bool disablePreviewFullProgressInTests = false;

  /// Whether [StatsCubit] should emit the preview history.
  static bool get showFullProgressPreview =>
      kDebugMode && previewFullProgress && !disablePreviewFullProgressInTests;

  /// Widget tests run in debug; keep the daily keyspace stable there.
  static bool useDailyPlayPeriodInTests = false;

  /// Debug: use calendar-day puzzle IDs like release (`daily_YYYYMMDD`).
  ///
  /// On by default so `flutter run` loads today's Firestore puzzles. Pass
  /// `--dart-define=DAILY_PLAY_PERIOD=false` (or the "minute play period"
  /// launch config) to rotate a new puzzle every minute for local testing.
  static const dailyPlayPeriod = bool.fromEnvironment(
    'DAILY_PLAY_PERIOD',
    defaultValue: true,
  );

  /// Debug builds rotate a new puzzle every minute only when
  /// [dailyPlayPeriod] is off (and tests haven't forced the daily keyspace).
  static bool get minutePlayPeriod =>
      kDebugMode && !useDailyPlayPeriodInTests && !dailyPlayPeriod;

  static Duration get playPeriod =>
      minutePlayPeriod ? PlayPeriod.minute : PlayPeriod.daily;
}
