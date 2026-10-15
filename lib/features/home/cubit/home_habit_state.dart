import 'package:flutter/foundation.dart';

import '../../../domain/habit/freeze_saved_notice.dart';
import '../../../domain/habit/weekly_recap.dart';

/// Home's habit cards: streaks a freeze saved, and the weekly recap.
class HomeHabitState {
  const HomeHabitState({
    this.freezeNotices = const [],
    this.recap,
    this.recapIsLastWeek = false,
  });

  final List<FreezeSavedNotice> freezeNotices;

  /// The recap card's week (Sunday: this week, Monday: the one that ended).
  final WeeklyRecap? recap;
  final bool recapIsLastWeek;

  bool get isEmpty => freezeNotices.isEmpty && recap == null;

  HomeHabitState copyWith({
    List<FreezeSavedNotice>? freezeNotices,
    WeeklyRecap? recap,
    bool clearRecap = false,
    bool? recapIsLastWeek,
  }) {
    return HomeHabitState(
      freezeNotices: freezeNotices ?? this.freezeNotices,
      recap: clearRecap ? null : (recap ?? this.recap),
      recapIsLastWeek: recapIsLastWeek ?? this.recapIsLastWeek,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HomeHabitState &&
      listEquals(other.freezeNotices, freezeNotices) &&
      other.recap == recap &&
      other.recapIsLastWeek == recapIsLastWeek;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(freezeNotices), recap, recapIsLastWeek);
}
