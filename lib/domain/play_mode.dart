import 'app_calendar.dart';
import 'play_period.dart';

enum PlayModeKind { daily, archive, practice, level }

/// How a game was opened: today's daily, a past daily from the archive, an
/// endless practice board, or one level of the game's Levels map.
///
/// Only [daily] runs touch the daily world (streaks, boards, the daily best,
/// the daily hint quota, the reminders and the widget). Archive, practice and
/// level runs keep their own drafts under keys that start with the mode
/// ([runId]), so nothing that reads the dailies' keys can mistake them for a
/// daily. Level bests live in the level progress repository, not here.
final class PlayMode {
  const PlayMode._(this.kind) : day = null, levelId = null;

  /// [day] is kept as a calendar day.
  PlayMode.archive(DateTime day)
    : kind = PlayModeKind.archive,
      day = DateTime(day.year, day.month, day.day),
      levelId = null;

  /// One level of the Levels map, by its stable id (`zip_1_07`).
  const PlayMode.level(String this.levelId)
    : kind = PlayModeKind.level,
      day = null;

  static const daily = PlayMode._(PlayModeKind.daily);
  static const practice = PlayMode._(PlayModeKind.practice);

  final PlayModeKind kind;

  /// The archive day; null for the other modes.
  final DateTime? day;

  /// The level's id; null for the other modes.
  final String? levelId;

  bool get isDaily => kind == PlayModeKind.daily;
  bool get isArchive => kind == PlayModeKind.archive;
  bool get isPractice => kind == PlayModeKind.practice;
  bool get isLevel => kind == PlayModeKind.level;

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

  /// A level id: game, world and level number (`zip_1_07`,
  /// `path_words_2_13`).
  static final levelIdPattern = RegExp(r'^[a-z][a-z_]*_[0-9]{1,3}_[0-9]{2,3}$');

  /// Reads `mode` (and `day` or `level`) from a game route's query. A missing
  /// or unknown mode is [daily], so App Links and the widget keep opening
  /// today's puzzle. Null for an archive day that is malformed or not in the
  /// archive, and for a malformed level id.
  static PlayMode? fromQuery(
    Map<String, String> query, {
    required DateTime now,
  }) {
    switch (query['mode']) {
      case 'practice':
        return practice;
      case 'level':
        final id = query['level'] ?? '';
        return levelIdPattern.hasMatch(id) ? PlayMode.level(id) : null;
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

  /// [path] with this mode's query (`/zip?mode=archive&day=2026-10-09`,
  /// `/zip?mode=level&level=zip_1_07`).
  String location(String path) {
    switch (kind) {
      case PlayModeKind.daily:
        return path;
      case PlayModeKind.practice:
        return '$path?mode=practice';
      case PlayModeKind.archive:
        return '$path?mode=archive&day=${AppCalendar.dateIdDashed(day!)}';
      case PlayModeKind.level:
        return '$path?mode=level&level=$levelId';
    }
  }

  String get _dayId => PlayPeriod.id(day!, PlayPeriod.daily);

  /// Id of the run's period for drafts and hints: the daily's [dailyPlayId],
  /// `archive_<yyyyMMdd>`, `practice` or `level_<levelId>`.
  String runId({required String dailyPlayId}) {
    switch (kind) {
      case PlayModeKind.daily:
        return dailyPlayId;
      case PlayModeKind.archive:
        return 'archive_$_dayId';
      case PlayModeKind.practice:
        return 'practice';
      case PlayModeKind.level:
        return 'level_$levelId';
    }
  }

  /// Where an archive or practice run of [gameId] keeps its best:
  /// `archive_<game>_<yyyyMMdd>` or `practice_<game>`. Dailies keep theirs
  /// under `modeKeyFor`, through the score repository; levels in the level
  /// progress repository.
  String recordKey(String gameId) {
    switch (kind) {
      case PlayModeKind.daily:
        throw StateError('Daily bests live in the score repository');
      case PlayModeKind.level:
        throw StateError('Level bests live in LevelProgressRepository');
      case PlayModeKind.archive:
        return 'archive_${gameId}_$_dayId';
      case PlayModeKind.practice:
        return 'practice_$gameId';
    }
  }

  @override
  bool operator ==(Object other) =>
      other is PlayMode &&
      other.kind == kind &&
      other.day == day &&
      other.levelId == levelId;

  @override
  int get hashCode => Object.hash(kind, day, levelId);

  @override
  String toString() => switch (kind) {
    PlayModeKind.archive =>
      'PlayMode.archive(${AppCalendar.dateIdDashed(day!)})',
    PlayModeKind.level => 'PlayMode.level($levelId)',
    _ => 'PlayMode.${kind.name}',
  };
}
