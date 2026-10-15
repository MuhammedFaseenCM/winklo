import 'package:bloc/bloc.dart';

import '../../../domain/archive_calendar.dart';
import '../../../domain/game_ids.dart';
import '../../../domain/logic/progress_merge.dart';
import '../../../domain/play_mode.dart';
import '../../../domain/play_period.dart';
import '../../../domain/repositories/play_mode_record_repository.dart';
import '../../../domain/usecases/get_best_points.dart';
import '../../../domain/usecases/get_best_time_seconds.dart';

/// The archive calendar of one game, a month at a time.
class ArchiveState {
  const ArchiveState({
    required this.gameId,
    this.months = const [],
    this.monthIndex = 0,
  });

  final String gameId;

  /// Oldest first.
  final List<ArchiveMonth> months;

  /// The month on screen.
  final int monthIndex;

  ArchiveMonth? get month =>
      months.isEmpty ? null : months[monthIndex.clamp(0, months.length - 1)];

  @override
  bool operator ==(Object other) =>
      other is ArchiveState &&
      other.gameId == gameId &&
      other.monthIndex == monthIndex &&
      other.months.length == months.length &&
      _sameMonths(other.months, months);

  static bool _sameMonths(List<ArchiveMonth> a, List<ArchiveMonth> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(gameId, monthIndex, Object.hashAll(months));
}

/// Builds the archive calendar. A day shows ✓ when it was cleared in the
/// daily or in the archive; it only reads those bests, never writes.
class ArchiveCubit extends Cubit<ArchiveState> {
  ArchiveCubit({
    required this.getBestPoints,
    required this.getBestTimeSeconds,
    required this.records,
    String initialGameId = GameIds.zip,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(ArchiveState(gameId: _known(initialGameId)));

  final GetBestPoints getBestPoints;
  final GetBestTimeSeconds getBestTimeSeconds;
  final PlayModeRecordRepository records;
  final DateTime Function() _now;

  static const games = [GameIds.zip, GameIds.pathWords, GameIds.sudoku];

  static String _known(String gameId) =>
      games.contains(gameId) ? gameId : GameIds.zip;

  /// (Re)reads the calendar, e.g. after a run; keeps the month on screen.
  void load() => _build(state.gameId, keepMonth: true);

  void selectGame(String gameId) => _build(_known(gameId), keepMonth: true);

  void showMonth(int index) {
    if (index < 0 || index >= state.months.length) return;
    emit(
      ArchiveState(
        gameId: state.gameId,
        months: state.months,
        monthIndex: index,
      ),
    );
  }

  bool isCleared(String gameId, DateTime day) {
    final dailyKey = modeKeyFor(gameId, PlayPeriod.id(day, PlayPeriod.daily));
    if (getBestPoints(dailyKey) > 0 || getBestTimeSeconds(dailyKey) != null) {
      return true;
    }
    final archiveKey = PlayMode.archive(day).recordKey(gameId);
    return records.bestTimeSeconds(archiveKey) != null;
  }

  void _build(String gameId, {required bool keepMonth}) {
    final months = archiveMonths(
      now: _now(),
      isCleared: (day) => isCleared(gameId, day),
    );
    final keep =
        keepMonth &&
        state.months.isNotEmpty &&
        state.monthIndex < state.months.length - 1;
    final index = months.isEmpty
        ? 0
        : keep
        ? state.monthIndex.clamp(0, months.length - 1)
        : months.length - 1;
    emit(ArchiveState(gameId: gameId, months: months, monthIndex: index));
  }
}
