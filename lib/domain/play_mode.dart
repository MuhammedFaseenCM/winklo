import 'app_calendar.dart';
import 'play_period.dart';

enum PlayModeKind { daily, archive, practice }

/// How a game was opened: today's daily, a past daily from the archive, or an
/// endless practice board.
///
/// Only [daily] runs touch the daily world (streaks, boards, the daily best,
/// the daily hint quota, the reminders and the widget). Archive and practice
/// runs keep their own drafts, hints and bests under keys that start with the
/// mode ([runId], [recordKey]), so nothing that reads the dailies' keys can
/// mistake them for a daily.
final class PlayMode {
  const PlayMode._(this.kind) : day = null;

  /// [day] is kept as a calendar day.
  PlayMode.archive(DateTime day)
    : kind = PlayModeKind.archive,
      day = DateTime(day.year, day.month, day.day);

  static const daily = PlayMode._(PlayModeKind.daily);
  static const practice = PlayMode._(PlayModeKind.practice);

  final PlayModeKind kind;

  /// The archive day; null for the other modes.
  final DateTime? day;

  bool get isDaily => kind == PlayModeKind.daily;
  bool get isArchive => kind == PlayModeKind.archive;
  bool get isPractice => kind == PlayModeKind.practice;

  /// The first hard daily, where the archive starts.
  static final archiveFirstDay = DateTime(2026, 10, 11);

  /// The archive's newest day: yesterday on the device's calendar. Today is
  /// never in it, so nobody can learn today's board before playing it.
  static DateTime archiveLastDay(DateTime now) {
    final today = AppCalendar.calendarDay(now);
    return DateTime(today.year, today.month, today.day - 1);
  }

  static bool isArchiveDay(DateTime day, {required DateTime now}) {
    final d = DateTime(day.year, day.month, day.day);
    return !d.isBefore(archiveFirstDay) && !d.isAfter(archiveLastDay(now));
  }

  static final _dayPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  /// Reads `mode` (and `day`) from a game route's query. A missing or unknown
  /// mode is [daily], so App Links and the widget keep opening today's
  /// puzzle. Null for an archive day that is malformed or not in the archive.
  static PlayMode? fromQuery(
    Map<String, String> query, {
    required DateTime now,
  }) {
    switch (query['mode']) {
      case 'practice':
        return practice;
      case 'archive':
        final match = _dayPattern.firstMatch(query['day'] ?? '');
        if (match == null) return null;
        final y = int.parse(match.group(1)!);
        final m = int.parse(match.group(2)!);
        final d = int.parse(match.group(3)!);
        final day = DateTime(y, m, d);
        // DateTime rolls 2026-13-01 over into 2027; refuse it.
        if (day.year != y || day.month != m || day.day != d) return null;
        if (!isArchiveDay(day, now: now)) return null;
        return PlayMode.archive(day);
      default:
        return daily;
    }
  }

  /// [path] with this mode's query (`/zip?mode=archive&day=2026-10-09`).
  String location(String path) {
    switch (kind) {
      case PlayModeKind.daily:
        return path;
      case PlayModeKind.practice:
        return '$path?mode=practice';
      case PlayModeKind.archive:
        return '$path?mode=archive&day=${AppCalendar.dateIdDashed(day!)}';
    }
  }

  String get _dayId => PlayPeriod.id(day!, PlayPeriod.daily);

  /// Id of the run's period for drafts and hints: the daily's [dailyPlayId],
  /// `archive_<yyyyMMdd>` or `practice`.
  String runId({required String dailyPlayId}) {
    switch (kind) {
      case PlayModeKind.daily:
        return dailyPlayId;
      case PlayModeKind.archive:
        return 'archive_$_dayId';
      case PlayModeKind.practice:
        return 'practice';
    }
  }

  /// Where an archive or practice run of [gameId] keeps its best:
  /// `archive_<game>_<yyyyMMdd>` or `practice_<game>`. Dailies keep theirs
  /// under `modeKeyFor`, through the score repository.
  String recordKey(String gameId) {
    switch (kind) {
      case PlayModeKind.daily:
        throw StateError('Daily bests live in the score repository');
      case PlayModeKind.archive:
        return 'archive_${gameId}_$_dayId';
      case PlayModeKind.practice:
        return 'practice_$gameId';
    }
  }

  @override
  bool operator ==(Object other) =>
      other is PlayMode && other.kind == kind && other.day == day;

  @override
  int get hashCode => Object.hash(kind, day);

  @override
  String toString() => switch (kind) {
    PlayModeKind.archive =>
      'PlayMode.archive(${AppCalendar.dateIdDashed(day!)})',
    _ => 'PlayMode.${kind.name}',
  };
}
