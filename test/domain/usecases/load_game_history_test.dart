import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/hint_quota_repository_impl.dart';
import 'package:winklo/data/repositories/score_repository_impl.dart';
import 'package:winklo/data/repositories/streak_repository_impl.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/entities/game_day_record.dart';
import 'package:winklo/domain/failures.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/repositories/progress_remote_repository.dart';
import 'package:winklo/domain/usecases/load_game_history.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockRemote extends Mock implements ProgressRemoteRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockAuth auth;
  late _MockRemote remote;
  late SharedPreferences prefs;
  late LoadGameHistory load;
  var remoteAvailable = true;
  final now = DateTime(2026, 10, 15, 9);

  Future<void> build(Map<String, Object> initial) async {
    SharedPreferences.setMockInitialValues(initial);
    prefs = await SharedPreferences.getInstance();
    load = LoadGameHistory(
      auth: auth,
      scores: ScoreRepositoryImpl(prefs),
      hintQuota: HintQuotaRepositoryImpl(prefs),
      streaks: StreakRepositoryImpl(prefs),
      remote: remote,
      isRemoteAvailable: () => remoteAvailable,
      now: () => now,
    );
  }

  void signIn(String uid) => when(
    () => auth.currentUser,
  ).thenReturn(AppUser(uid: uid, displayName: 'Ana'));

  void stubRemote(List<GameDayRecord> days) => when(
    () => remote.fetchAllDays(uid: any(named: 'uid')),
  ).thenAnswer((_) async => days);

  setUp(() {
    auth = _MockAuth();
    remote = _MockRemote();
    remoteAvailable = true;
    when(() => auth.currentUser).thenReturn(null);
  });

  test('signed out reads this device only', () async {
    await build({'best_time_zip_daily_20261001': 42});
    final history = await load();
    expect(history.days.map((d) => d.playId), ['20261001']);
    expect(history.remoteIncluded, isFalse);
    expect(history.remoteFailed, isFalse);
    expect(history.today, DateTime(2026, 10, 15));
    verifyZeroInteractions(remote);
  });

  test('merges the remote copy with local days', () async {
    signIn('u1');
    stubRemote(const [
      GameDayRecord(
        gameId: GameIds.zip,
        playId: '20261001',
        timeSeconds: 30,
        usedHints: false,
        hadMistakes: false,
        flagsKnown: true,
      ),
    ]);
    await build({
      'best_time_zip_daily_20261001': 42,
      'hints_used_zip_20261001': 1,
    });
    final history = await load();
    final day = history.days.single;
    expect(day.timeSeconds, 30);
    expect(day.usedHints, isFalse);
    expect(day.hintsUsed, 1);
    expect(history.remoteIncluded, isTrue);
    verify(() => remote.fetchAllDays(uid: 'u1')).called(1);
  });

  test('keeps remote-only days, with legacy flags when unknown', () async {
    signIn('u1');
    stubRemote(const [
      GameDayRecord(
        gameId: GameIds.sudoku,
        playId: '20260901',
        timeSeconds: 99,
        hintsUsed: 0,
      ),
      // Not cleared: left out.
      GameDayRecord(gameId: GameIds.zip, playId: '20260902', hintsUsed: 2),
    ]);
    await build({});
    final history = await load();
    final day = history.days.single;
    expect(day.playId, '20260901');
    expect(day.usedHints, isFalse);
    expect(day.hadMistakes, isTrue);
    expect(day.flagsKnown, isFalse);
  });

  test('the same day in several games stays separate, sorted', () async {
    signIn('u1');
    stubRemote(const [
      GameDayRecord(gameId: GameIds.sudoku, playId: '20261001', timeSeconds: 9),
    ]);
    await build({
      'best_time_path_words_20261001': 61,
      'best_time_zip_daily_20261001': 42,
      'best_time_zip_daily_20260930': 50,
    });
    final history = await load();
    expect(history.days.map((d) => '${d.gameId}_${d.playId}'), [
      'zip_20260930',
      'zip_20261001',
      'path_words_20261001',
      'sudoku_20261001',
    ]);
    expect(history.daysOf(GameIds.zip), hasLength(2));
  });

  test('a remote failure falls back to this device', () async {
    signIn('u1');
    when(
      () => remote.fetchAllDays(uid: any(named: 'uid')),
    ).thenThrow(const Failure('offline'));
    await build({'best_time_zip_daily_20261001': 42});
    final history = await load();
    expect(history.days, hasLength(1));
    expect(history.remoteIncluded, isFalse);
    expect(history.remoteFailed, isTrue);
  });

  test('an unavailable remote counts as a failure when signed in', () async {
    signIn('u1');
    remoteAvailable = false;
    await build({'best_time_zip_daily_20261001': 42});
    final history = await load();
    expect(history.remoteFailed, isTrue);
    verifyZeroInteractions(remote);
  });

  test('caches the remote copy per uid until a refresh', () async {
    signIn('u1');
    stubRemote(const []);
    await build({});
    await load();
    await load();
    verify(() => remote.fetchAllDays(uid: 'u1')).called(1);
    await load(refreshRemote: true);
    verify(() => remote.fetchAllDays(uid: 'u1')).called(1);
  });

  test('a stale cached copy is used when a refresh fails', () async {
    signIn('u1');
    stubRemote(const [
      GameDayRecord(gameId: GameIds.zip, playId: '20260901', timeSeconds: 9),
    ]);
    await build({});
    await load();
    when(
      () => remote.fetchAllDays(uid: any(named: 'uid')),
    ).thenThrow(const Failure('offline'));
    final history = await load(refreshRemote: true);
    expect(history.days.single.playId, '20260901');
    expect(history.remoteIncluded, isTrue);
    expect(history.remoteFailed, isFalse);
  });

  test('a different uid fetches its own copy', () async {
    signIn('u1');
    stubRemote(const [
      GameDayRecord(gameId: GameIds.zip, playId: '20260901', timeSeconds: 9),
    ]);
    await build({});
    await load();
    signIn('u2');
    stubRemote(const []);
    final history = await load();
    expect(history.days, isEmpty);
    verify(() => remote.fetchAllDays(uid: 'u2')).called(1);
  });

  test('concurrent loads share one fetch', () async {
    signIn('u1');
    final pending = Completer<List<GameDayRecord>>();
    when(
      () => remote.fetchAllDays(uid: any(named: 'uid')),
    ).thenAnswer((_) => pending.future);
    await build({});
    final a = load();
    final b = load();
    pending.complete(const []);
    await Future.wait([a, b]);
    verify(() => remote.fetchAllDays(uid: 'u1')).called(1);
  });

  test('streaks are decayed for today but not persisted', () async {
    await build({
      'streak_current_zip': 4,
      'streak_longest_zip': 9,
      'streak_last_zip': '20261010',
      'streak_freeze_zip': true,
      'streak_current_sudoku': 2,
      'streak_longest_sudoku': 2,
      'streak_last_sudoku': '20261014',
      'streak_freeze_sudoku': true,
    });
    final history = await load();
    expect(history.streakOf(GameIds.zip).current, 0);
    expect(history.streakOf(GameIds.zip).longest, 9);
    expect(history.streakOf(GameIds.sudoku).current, 2);
    expect(history.streakOf(GameIds.pathWords).current, 0);
    expect(prefs.getInt('streak_current_zip'), 4);
    expect(history.achievementInput.longestStreakByGame[GameIds.zip], 9);
  });
}
