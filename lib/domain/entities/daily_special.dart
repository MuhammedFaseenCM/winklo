/// What makes a daily special. The winklo-admin cron writes `special` on the
/// puzzle docs of Saturdays and Sundays, which are harder boards at the
/// weekday size.
abstract final class DailySpecial {
  static const weekend = 'weekend';
}

/// The doc's `special` field: a trimmed non-empty string, or null.
String? readDailySpecial(Object? raw) {
  if (raw is! String) return null;
  final value = raw.trim();
  return value.isEmpty ? null : value;
}

bool isWeekendSpecial(String? special) => special == DailySpecial.weekend;
