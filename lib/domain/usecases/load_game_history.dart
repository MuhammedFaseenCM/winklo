import '../app_calendar.dart';
import '../entities/game_day_record.dart';
import '../entities/game_history.dart';
import '../entities/game_streak.dart';
import '../logic/local_game_day.dart';
import '../logic/progress_merge.dart';
import '../repositories/auth_repository.dart';
import '../repositories/hint_quota_repository.dart';
import '../repositories/progress_remote_repository.dart';
import '../repositories/score_repository.dart';
import '../repositories/streak_repository.dart';
import '../streak_calculator.dart';

/// Loads the [GameHistory] that stats and achievements read: every daily
/// clear on this device merged (`mergeGameDay`) with the signed-in account's
/// `game_days`, plus each game's stored streak.
///
/// Local progress is read fresh on every call. The remote copy (one read of
/// the whole collection) is cached per account for the app session and
/// fetched again on [call] with `refreshRemote`; when that fails, the cached
/// copy is kept. Concurrent fetches for one account share a request.
class LoadGameHistory {
  LoadGameHistory({
    required this._auth,
    required this._scores,
    required this._hintQuota,
    required this._streaks,
    required this._remote,
    bool Function()? isRemoteAvailable,
    DateTime Function()? now,
  }) : _isRemoteAvailable = isRemoteAvailable ?? _alwaysAvailable,
       _now = now ?? DateTime.now;

  final AuthRepository _auth;
  final ScoreRepository _scores;
  final HintQuotaRepository _hintQuota;
  final StreakRepository _streaks;
  final ProgressRemoteRepository _remote;

  /// Domain cannot see Firebase; DI passes e.g. `() => FirebaseBootstrap.isReady`.
  final bool Function() _isRemoteAvailable;
  final DateTime Function() _now;

  static bool _alwaysAvailable() => true;

  String? _cachedUid;
  List<GameDayRecord>? _cachedRemote;
  String? _inflightUid;
  Future<List<GameDayRecord>>? _inflight;

  Future<GameHistory> call({bool refreshRemote = false}) async {
    final now = _now();
    final todayId = StreakCalculator.dateId(now);
    var uid = _auth.currentUser?.uid;
    List<GameDayRecord>? remote;
    for (var attempt = 0; attempt < 2; attempt++) {
      remote = null;
      if (uid != null && uid.isNotEmpty && _isRemoteAvailable()) {
        remote = await _remoteDays(uid, refresh: refreshRemote);
      }
      // The account changed while the remote copy loaded: local progress is
      // being swapped for the new account's, so read for that one instead.
      final current = _auth.currentUser?.uid;
      if (current == uid) break;
      uid = current;
    }
    final signedIn = uid != null && uid.isNotEmpty;

    final local = readLocalDailyHistory(scores: _scores, hintQuota: _hintQuota);
    final streaks = <String, GameStreak>{};
    for (final gameId in dailyProgressGameIds) {
      final stored = await _streaks.getStreak(gameId);
      streaks[gameId] = StreakCalculator.applyLazyDecay(
        streak: stored,
        todayId: todayId,
      ).streak;
    }

    return GameHistory(
      days: _merge(local, remote ?? const []),
      streaks: streaks,
      today: AppCalendar.calendarDay(now),
      remoteIncluded: remote != null,
      remoteFailed: signedIn && remote == null,
    );
  }

  /// The account's remote days; null when they can't be read and nothing is
  /// cached for [uid].
  Future<List<GameDayRecord>?> _remoteDays(
    String uid, {
    required bool refresh,
  }) async {
    final cached = _cachedUid == uid ? _cachedRemote : null;
    if (cached != null && !refresh) return cached;
    try {
      final days = await _fetch(uid);
      _cachedUid = uid;
      _cachedRemote = days;
      return days;
    } catch (_) {
      return cached;
    }
  }

  Future<List<GameDayRecord>> _fetch(String uid) {
    final inflight = _inflight;
    if (inflight != null && _inflightUid == uid) return inflight;
    final future = _remote.fetchAllDays(uid: uid);
    _inflightUid = uid;
    _inflight = future;
    void clear() {
      if (identical(_inflight, future)) {
        _inflight = null;
        _inflightUid = null;
      }
    }

    future.then((_) => clear(), onError: (_) => clear());
    return future;
  }

  /// Cleared days by game (in [dailyProgressGameIds] order), then period.
  static List<GameDayRecord> _merge(
    List<GameDayRecord> local,
    List<GameDayRecord> remote,
  ) {
    String key(GameDayRecord d) => '${d.gameId}_${d.playId}';
    final byKey = <String, GameDayRecord>{
      for (final day in local) key(day): day,
    };
    for (final day in remote) {
      if (!dailyProgressGameIds.contains(day.gameId)) continue;
      final mine = byKey[key(day)];
      byKey[key(day)] = mine == null ? day : mergeGameDay(mine, day);
    }
    final days = [
      for (final day in byKey.values)
        if (day.cleared) withLegacyClearFlags(day),
    ];
    days.sort((a, b) {
      final byGame = dailyProgressGameIds
          .indexOf(a.gameId)
          .compareTo(dailyProgressGameIds.indexOf(b.gameId));
      return byGame != 0 ? byGame : a.playId.compareTo(b.playId);
    });
    return days;
  }
}
