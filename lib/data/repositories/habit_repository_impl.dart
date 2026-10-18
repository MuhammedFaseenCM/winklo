import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/habit/freeze_saved_notice.dart';
import '../../domain/repositories/habit_repository.dart';

class HabitRepositoryImpl implements HabitRepository {
  HabitRepositoryImpl(this._prefs);

  final SharedPreferences _prefs;

  /// JSON list of `{gameId, days}`. The `streak_` prefix makes it per-user
  /// progress, so an account switch purges (or stashes) it with the streaks.
  static const freezeSavedKey = 'streak_notice_freeze_saved';

  /// The `habit_` prefix makes it per-user progress too, so another account
  /// on this phone gets its own recap card.
  static const _recapDismissedKey = 'habit_recap_dismissed_week';

  @override
  Future<void> addFreezeSavedNotice(FreezeSavedNotice notice) async {
    final notices = [
      for (final n in _readNotices())
        if (n.gameId != notice.gameId) n,
      notice,
    ];
    await _prefs.setString(
      freezeSavedKey,
      jsonEncode([
        for (final n in notices) {'gameId': n.gameId, 'days': n.days},
      ]),
    );
  }

  @override
  Future<List<FreezeSavedNotice>> takeFreezeSavedNotices() async {
    if (!_prefs.containsKey(freezeSavedKey)) return const [];
    final notices = _readNotices();
    await _prefs.remove(freezeSavedKey);
    return notices;
  }

  List<FreezeSavedNotice> _readNotices() {
    final raw = _prefs.getString(freezeSavedKey);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item case {'gameId': final String id, 'days': final int days})
            FreezeSavedNotice(gameId: id, days: days),
      ];
    } catch (e) {
      debugPrint('Freeze notices unreadable: $e');
      return const [];
    }
  }

  @override
  String? get dismissedRecapWeek => _prefs.getString(_recapDismissedKey);

  @override
  Future<void> dismissRecapWeek(String weekStartId) =>
      _prefs.setString(_recapDismissedKey, weekStartId);
}
