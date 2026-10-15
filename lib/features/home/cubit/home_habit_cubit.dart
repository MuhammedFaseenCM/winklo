import 'package:bloc/bloc.dart';

import '../../../domain/app_calendar.dart';
import '../../../domain/habit/freeze_saved_notice.dart';
import '../../../domain/habit/weekly_recap.dart';
import '../../../domain/repositories/habit_repository.dart';
import '../../../domain/usecases/get_weekly_recap.dart';
import 'home_habit_state.dart';

/// Reloads with Home: takes the pending freeze-saved notices (each is shown
/// once, until dismissed) and, on Sunday and Monday, builds the recap card.
class HomeHabitCubit extends Cubit<HomeHabitState> {
  HomeHabitCubit({
    required this._habit,
    required this._weeklyRecap,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const HomeHabitState());

  final HabitRepository _habit;
  final GetWeeklyRecap _weeklyRecap;
  final DateTime Function() _now;

  /// [currentStreaks] are Home's decayed streaks, for the recap's streak.
  Future<void> load({required Map<String, int> currentStreaks}) async {
    final taken = await _habit.takeFreezeSavedNotices();
    final recap = _recap(currentStreaks);
    if (isClosed) return;
    final notices = [
      for (final shown in state.freezeNotices)
        if (!taken.any((n) => n.gameId == shown.gameId)) shown,
      ...taken,
    ];
    final next = HomeHabitState(
      freezeNotices: notices,
      recap: recap?.recap,
      recapIsLastWeek: recap?.lastWeek ?? false,
    );
    if (next != state) emit(next);
  }

  ({WeeklyRecap recap, bool lastWeek})? _recap(Map<String, int> streaks) {
    final today = AppCalendar.calendarDay(_now());
    final lastWeek = switch (today.weekday) {
      DateTime.sunday => false,
      DateTime.monday => true,
      _ => null,
    };
    if (lastWeek == null) return null;
    final thisWeek = WeeklyRecap.weekStart(today);
    final weekStart = lastWeek
        ? DateTime(thisWeek.year, thisWeek.month, thisWeek.day - 7)
        : thisWeek;
    final recap = _weeklyRecap(weekStart: weekStart, currentStreaks: streaks);
    if (recap.isEmpty || _habit.dismissedRecapWeek == recap.weekStartId) {
      return null;
    }
    return (recap: recap, lastWeek: lastWeek);
  }

  void dismissNotice(String gameId) {
    emit(
      state.copyWith(
        freezeNotices: [
          for (final FreezeSavedNotice n in state.freezeNotices)
            if (n.gameId != gameId) n,
        ],
      ),
    );
  }

  /// Hidden until the next week's card.
  Future<void> dismissRecap() async {
    final recap = state.recap;
    if (recap == null) return;
    emit(state.copyWith(clearRecap: true));
    await _habit.dismissRecapWeek(recap.weekStartId);
  }
}
