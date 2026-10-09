import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/hint_quota_repository_impl.dart';
import 'package:winklo/data/repositories/progress_local_repository_impl.dart';
import 'package:winklo/data/repositories/score_repository_impl.dart';
import 'package:winklo/data/repositories/streak_repository_impl.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/entities/client_error_report.dart';
import 'package:winklo/domain/entities/game_day_record.dart';
import 'package:winklo/domain/entities/game_streak.dart';
import 'package:winklo/domain/failures.dart';
import 'package:winklo/domain/play_period.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/repositories/client_error_repository.dart';
import 'package:winklo/domain/repositories/leaderboard_repository.dart';
import 'package:winklo/domain/repositories/progress_remote_repository.dart';
import 'package:winklo/domain/usecases/get_streak.dart';
import 'package:winklo/domain/usecases/report_client_error.dart';
import 'package:winklo/domain/usecases/sync_progress.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockRemote extends Mock implements ProgressRemoteRepository {}

class _MockLeaderboard extends Mock implements LeaderboardRepository {}

class _MockClientErrors extends Mock implements ClientErrorRepository {}

const _uid = 'u1';
const _today = '20261007';
const _yesterday = '20261006';

/// Local stores are the real prefs-backed impls (so restores land in the same
/// keys the UI reads); remote, auth, leaderboard and telemetry are mocks.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockAuth auth;
  late _MockRemote remote;
  late _MockLeaderboard leaderboard;
  late _MockClientErrors clientErrors;
  late SharedPreferences prefs;
  late ProgressLocalRepositoryImpl local;
  late SyncProgress sync;
  late Map<String, GameDayRecord> remoteDays;
  late Map<String, GameStreak> remoteStreaks;
  var remoteAvailable = true;
  final now = DateTime(2026, 10, 7, 12);

  setUpAll(() {
    registerFallbackValue(const GameDayRecord(gameId: 'zip', playId: _today));
    registerFallbackValue(const GameStreak(gameId: 'zip'));
    registerFallbackValue(
      const ClientErrorReport(
        severity: 'error',
        source: 'handled',
        code: 'x',
        message: 'x',
      ),
    );
  });

  Future<void> build({
    Map<String, Object> initial = const {},
    Duration period = PlayPeriod.daily,
    DateTime? at,
    DateTime Function()? clockFn,
    Duration leaderboardTimeout = const Duration(seconds: 20),
  }) async {
    SharedPreferences.setMockInitialValues(initial);
    prefs = await SharedPreferences.getInstance();
    local = ProgressLocalRepositoryImpl(prefs);
    final clock = at ?? now;
    sync = SyncProgress(
      auth: auth,
      scores: ScoreRepositoryImpl(prefs),
      streaks: StreakRepositoryImpl(prefs),
      hintQuota: HintQuotaRepositoryImpl(prefs),
      local: local,
      remote: remote,
      leaderboard: leaderboard,
      reportClientError: ReportClientError(clientErrors),
      playPeriod: period,
      isRemoteAvailable: () => remoteAvailable,
      now: clockFn ?? () => clock,
      leaderboardTimeout: leaderboardTimeout,
    );
  }

  void stubSubmit() {
    when(
      () => leaderboard.submitBestTime(
        gameId: any(named: 'gameId'),
        timeSeconds: any(named: 'timeSeconds'),
        usedHints: any(named: 'usedHints'),
        hadMistakes: any(named: 'hadMistakes'),
        currentStreak: any(named: 'currentStreak'),
        dayId: any(named: 'dayId'),
        expectedUid: any(named: 'expectedUid'),
      ),
    ).thenAnswer((_) async {});
  }

  void verifyNoSubmit() {
    verifyNever(
      () => leaderboard.submitBestTime(
        gameId: any(named: 'gameId'),
        timeSeconds: any(named: 'timeSeconds'),
        usedHints: any(named: 'usedHints'),
        hadMistakes: any(named: 'hadMistakes'),
        currentStreak: any(named: 'currentStreak'),
        dayId: any(named: 'dayId'),
        expectedUid: any(named: 'expectedUid'),
      ),
    );
  }

  void verifyNoRemoteWrites() {
    verifyNever(
      () => remote.saveDay(
        uid: any(named: 'uid'),
        record: any(named: 'record'),
      ),
    );
    verifyNever(
      () => remote.saveStreak(
        uid: any(named: 'uid'),
        streak: any(named: 'streak'),
      ),
    );
  }

  List<GameDayRecord> savedDays() => verify(
    () => remote.saveDay(
      uid: _uid,
      record: captureAny(named: 'record'),
    ),
  ).captured.cast<GameDayRecord>();

  setUp(() {
    auth = _MockAuth();
    remote = _MockRemote();
    leaderboard = _MockLeaderboard();
    clientErrors = _MockClientErrors();
    remoteDays = {};
    remoteStreaks = {};
    remoteAvailable = true;

    when(
      () => auth.currentUser,
    ).thenReturn(const AppUser(uid: _uid, displayName: 'Ana'));
    when(
      () => remote.fetchDay(
        uid: any(named: 'uid'),
        gameId: any(named: 'gameId'),
        playId: any(named: 'playId'),
      ),
    ).thenAnswer((inv) async {
      final g = inv.namedArguments[#gameId] as String;
      final p = inv.namedArguments[#playId] as String;
      return remoteDays['${g}_$p'];
    });
    when(
      () => remote.saveDay(
        uid: any(named: 'uid'),
        record: any(named: 'record'),
      ),
    ).thenAnswer((inv) async {
      final r = inv.namedArguments[#record] as GameDayRecord;
      remoteDays['${r.gameId}_${r.playId}'] = r;
    });
    when(
      () => remote.fetchStreak(
        uid: any(named: 'uid'),
        gameId: any(named: 'gameId'),
      ),
    ).thenAnswer(
      (inv) async => remoteStreaks[inv.namedArguments[#gameId] as String],
    );
    when(
      () => remote.saveStreak(
        uid: any(named: 'uid'),
        streak: any(named: 'streak'),
      ),
    ).thenAnswer((inv) async {
      final s = inv.namedArguments[#streak] as GameStreak;
      remoteStreaks[s.gameId] = s;
    });
    stubSubmit();
    when(() => clientErrors.report(any())).thenAnswer((_) async {});
  });

  group('no-op', () {
    test('when signed out', () async {
      when(() => auth.currentUser).thenReturn(null);
      await build(initial: {'best_time_zip_daily_$_today': 30});

      final result = await sync();

      expect(result, const SyncProgressResult());
      verifyZeroInteractions(remote);
      verifyZeroInteractions(leaderboard);
      expect(local.ownerUid, isNull);
    });

    test('when the remote is unavailable', () async {
      remoteAvailable = false;
      await build(
        initial: {
          'progress_owner_uid': 'someone_else',
          'best_time_zip_daily_$_today': 30,
        },
      );

      final result = await sync();

      expect(result, const SyncProgressResult());
      verifyZeroInteractions(remote);
      verifyZeroInteractions(leaderboard);
      // No purge without a remote copy to restore from.
      expect(prefs.getInt('best_time_zip_daily_$_today'), 30);
      expect(local.ownerUid, 'someone_else');
    });
  });

  group('ownership', () {
    test('legacy data is claimed by the first uid and kept', () async {
      await build(
        initial: {
          'best_time_zip_daily_$_today': 30,
          'best_pts_zip_daily_$_today': 850,
        },
      );

      final result = await sync();

      expect(local.ownerUid, _uid);
      expect(result.localChanged, isFalse);
      expect(prefs.getInt('best_time_zip_daily_$_today'), 30);
      final saved = savedDays().single;
      expect(saved.timeSeconds, 30);
      expect(saved.points, 850);
    });

    test(
      'account switch purges the previous owner and restores this account',
      () async {
        remoteDays['sudoku_$_today'] = const GameDayRecord(
          gameId: 'sudoku',
          playId: _today,
          timeSeconds: 200,
          points: 700,
          usedHints: false,
          hadMistakes: false,
          flagsKnown: true,
          hintsUsed: 0,
        );
        remoteStreaks['sudoku'] = const GameStreak(
          gameId: 'sudoku',
          current: 4,
          longest: 9,
          lastClearedDateId: _today,
        );
        await build(
          initial: {
            'progress_owner_uid': 'previous',
            'best_time_zip_daily_$_today': 30,
            'best_pts_zip_daily_$_today': 850,
            'streak_current_zip': 3,
            'streak_longest_zip': 3,
            'streak_last_zip': _today,
            'streak_freeze_zip': true,
            'hints_used_zip_$_today': 2,
            'in_progress_zip': '{}',
            'sync_lb_zip_$_today': '30',
            'tutorial_seen_zip': true,
          },
        );

        // Push-only request: the switch still forces a pull.
        final result = await sync(pull: false);

        expect(result.localChanged, isTrue);
        expect(result.failures, 0);
        expect(local.ownerUid, _uid);
        // Previous owner's progress is gone and never uploaded as ours.
        expect(prefs.getInt('best_time_zip_daily_$_today'), isNull);
        expect(prefs.getInt('streak_current_zip'), isNull);
        expect(prefs.getInt('hints_used_zip_$_today'), isNull);
        expect(prefs.getString('in_progress_zip'), isNull);
        expect(prefs.getBool('tutorial_seen_zip'), isTrue);
        verifyNever(
          () => leaderboard.submitBestTime(
            gameId: 'zip',
            timeSeconds: any(named: 'timeSeconds'),
            usedHints: any(named: 'usedHints'),
            hadMistakes: any(named: 'hadMistakes'),
            currentStreak: any(named: 'currentStreak'),
            dayId: any(named: 'dayId'),
            expectedUid: any(named: 'expectedUid'),
          ),
        );
        verifyNoRemoteWrites();
        // This account's remote progress is now local (lock + streak).
        expect(prefs.getInt('best_time_sudoku_$_today'), 200);
        expect(prefs.getInt('best_pts_sudoku_$_today'), 700);
        expect(prefs.getInt('streak_current_sudoku'), 4);
        expect(prefs.getInt('streak_longest_sudoku'), 9);
      },
    );

    test('same owner never purges', () async {
      await build(
        initial: {
          'progress_owner_uid': _uid,
          'best_time_zip_daily_$_today': 30,
        },
      );

      await sync();

      expect(prefs.getInt('best_time_zip_daily_$_today'), 30);
    });
  });

  group('restore from remote', () {
    test('day restores lock, points, meta and hint quota', () async {
      remoteDays['zip_$_today'] = const GameDayRecord(
        gameId: 'zip',
        playId: _today,
        timeSeconds: 41,
        points: 800,
        usedHints: true,
        hadMistakes: false,
        flagsKnown: true,
        hintsUsed: 2,
      );
      await build(initial: {'progress_owner_uid': _uid});

      final result = await sync();

      expect(result.localChanged, isTrue);
      // Zip mode key is `zip_daily_<playId>` (matches ZipBloc / HomeCubit).
      expect(prefs.getInt('best_time_zip_daily_$_today'), 41);
      expect(prefs.getInt('best_pts_zip_daily_$_today'), 800);
      expect(
        prefs.getString('clear_meta_zip_daily_$_today'),
        '{"usedHints":true,"hadMistakes":false}',
      );
      expect(prefs.getInt('hints_used_zip_$_today'), 2);
      // Merged equals remote: no write back, but the marker is recorded.
      verifyNever(
        () => remote.saveDay(
          uid: any(named: 'uid'),
          record: any(named: 'record'),
        ),
      );
      expect(prefs.getString('sync_day_zip_$_today'), isNotNull);
    });

    test('remote zip board is restored for the review', () async {
      remoteDays['zip_$_today'] = const GameDayRecord(
        gameId: 'zip',
        playId: _today,
        timeSeconds: 41,
        points: 800,
        usedHints: false,
        hadMistakes: false,
        flagsKnown: true,
        board: '0,0;0,1',
      );
      await build(initial: {'progress_owner_uid': _uid});

      await sync();

      expect(prefs.getString('clear_board_zip_daily_$_today'), '0,0;0,1');
      verifyNever(
        () => remote.saveDay(
          uid: any(named: 'uid'),
          record: any(named: 'record'),
        ),
      );
    });

    test('local zip board is pushed with the clear', () async {
      await build(
        initial: {
          'progress_owner_uid': _uid,
          'best_time_zip_daily_$_today': 40,
          'best_pts_zip_daily_$_today': 800,
          'clear_meta_zip_daily_$_today':
              '{"usedHints":false,"hadMistakes":false}',
          'clear_board_zip_daily_$_today': '1,1;1,0',
        },
      );

      await sync();

      expect(savedDays().single.board, '1,1;1,0');
    });

    test('remote legacy flags are not stored as known meta', () async {
      remoteDays['path_words_$_today'] = const GameDayRecord(
        gameId: 'path_words',
        playId: _today,
        timeSeconds: 60,
        usedHints: false,
        hadMistakes: false,
        flagsKnown: false,
      );
      await build(initial: {'progress_owner_uid': _uid});

      await sync();

      expect(prefs.getInt('best_time_path_words_$_today'), 60);
      expect(prefs.getString('clear_meta_path_words_$_today'), isNull);
    });

    test('local better time is kept and pushed over a worse remote', () async {
      remoteDays['zip_$_today'] = const GameDayRecord(
        gameId: 'zip',
        playId: _today,
        timeSeconds: 50,
        points: 750,
        usedHints: true,
        hadMistakes: false,
        flagsKnown: true,
        hintsUsed: 1,
      );
      await build(
        initial: {
          'progress_owner_uid': _uid,
          'best_time_zip_daily_$_today': 40,
          'best_pts_zip_daily_$_today': 800,
          'clear_meta_zip_daily_$_today':
              '{"usedHints":false,"hadMistakes":false}',
        },
      );

      await sync();

      final saved = savedDays().single;
      expect(saved.timeSeconds, 40);
      expect(saved.points, 800);
      expect(saved.usedHints, isFalse);
      expect(saved.flagsKnown, isTrue);
      expect(saved.hintsUsed, 1);
      expect(prefs.getInt('best_time_zip_daily_$_today'), 40);
      expect(prefs.getInt('hints_used_zip_$_today'), 1);
    });

    test('remote newer streak is restored locally', () async {
      remoteStreaks['zip'] = const GameStreak(
        gameId: 'zip',
        current: 6,
        longest: 6,
        lastClearedDateId: _today,
        freezeAvailable: false,
      );
      await build(
        initial: {
          'progress_owner_uid': _uid,
          'streak_current_zip': 2,
          'streak_longest_zip': 8,
          'streak_last_zip': '20261004',
          'streak_freeze_zip': true,
        },
      );

      final result = await sync();

      expect(result.localChanged, isTrue);
      expect(prefs.getInt('streak_current_zip'), 6);
      expect(prefs.getInt('streak_longest_zip'), 8);
      expect(prefs.getString('streak_last_zip'), _today);
      expect(prefs.getBool('streak_freeze_zip'), isFalse);
      // longest differs from remote -> merged copy pushed.
      final pushed = verify(
        () => remote.saveStreak(
          uid: _uid,
          streak: captureAny(named: 'streak'),
        ),
      ).captured.cast<GameStreak>();
      expect(pushed.single.longest, 8);
      expect(pushed.single.current, 6);
    });
  });

  group('push', () {
    test('local newer streak is pushed', () async {
      remoteStreaks['zip'] = const GameStreak(
        gameId: 'zip',
        current: 2,
        longest: 2,
        lastClearedDateId: _yesterday,
      );
      await build(
        initial: {
          'progress_owner_uid': _uid,
          'streak_current_zip': 3,
          'streak_longest_zip': 3,
          'streak_last_zip': _today,
          'streak_freeze_zip': true,
        },
      );

      final result = await sync();

      expect(result.localChanged, isFalse);
      final pushed = verify(
        () => remote.saveStreak(
          uid: _uid,
          streak: captureAny(named: 'streak'),
        ),
      ).captured.cast<GameStreak>();
      expect(pushed.single.current, 3);
      expect(pushed.single.lastClearedDateId, _today);
      expect(prefs.getString('sync_streak_zip'), isNotNull);
    });

    test('pristine streaks and empty days are never written', () async {
      await build(initial: {'progress_owner_uid': _uid});

      final result = await sync();

      expect(result, const SyncProgressResult());
      verifyNoRemoteWrites();
      verifyNoSubmit();
    });

    test('cleared day gets clearedAt on first push', () async {
      await build(
        initial: {
          'progress_owner_uid': _uid,
          'best_time_zip_daily_$_today': 30,
          'clear_meta_zip_daily_$_today':
              '{"usedHints":false,"hadMistakes":false}',
        },
      );

      await sync();

      final saved = savedDays().single;
      expect(saved.clearedAt, now);
      expect(saved.flagsKnown, isTrue);
    });

    test('no writes when signatures are unchanged', () async {
      await build(
        initial: {
          'progress_owner_uid': _uid,
          'best_time_zip_daily_$_today': 30,
          'best_pts_zip_daily_$_today': 850,
          'streak_current_zip': 1,
          'streak_longest_zip': 1,
          'streak_last_zip': _today,
          'streak_freeze_zip': true,
        },
      );

      await sync();
      clearInteractions(remote);
      clearInteractions(leaderboard);

      final second = await sync();

      expect(second, const SyncProgressResult());
      verifyNoRemoteWrites();
      verifyNoSubmit();

      // Push-only run with nothing changed does not even read.
      clearInteractions(remote);
      await sync(pull: false);
      verifyZeroInteractions(remote);
      verifyNoSubmit();
    });

    test('push-only run fetches and merges before writing a change', () async {
      await build(initial: {'progress_owner_uid': _uid});
      await sync();
      // Another device posted a better time meanwhile.
      remoteDays['zip_$_today'] = const GameDayRecord(
        gameId: 'zip',
        playId: _today,
        timeSeconds: 25,
        points: 900,
        usedHints: false,
        hadMistakes: false,
        flagsKnown: true,
      );
      await prefs.setInt('best_time_zip_daily_$_today', 35);
      await prefs.setInt('best_pts_zip_daily_$_today', 820);
      clearInteractions(remote);

      final result = await sync(pull: false);

      expect(result.localChanged, isTrue);
      expect(prefs.getInt('best_time_zip_daily_$_today'), 25);
      verifyNever(
        () => remote.saveDay(
          uid: any(named: 'uid'),
          record: any(named: 'record'),
        ),
      );
      expect(remoteDays['zip_$_today']!.timeSeconds, 25);
      // Only the changed day was read.
      verify(
        () => remote.fetchDay(
          uid: _uid,
          gameId: any(named: 'gameId'),
          playId: any(named: 'playId'),
        ),
      ).called(1);
    });
  });

  group('leaderboard backfill', () {
    test(
      'legacy Zip clear uses dayId from playId and hint proxy flags',
      () async {
        await build(
          initial: {
            'progress_owner_uid': _uid,
            'best_time_zip_daily_$_today': 30,
            'hints_used_zip_$_today': 2,
            'streak_current_zip': 4,
            'streak_longest_zip': 4,
            'streak_last_zip': _today,
            'streak_freeze_zip': true,
          },
        );

        await sync();

        verify(
          () => leaderboard.submitBestTime(
            gameId: 'zip',
            timeSeconds: 30,
            usedHints: true,
            hadMistakes: false,
            currentStreak: 4,
            dayId: '2026-10-07',
            expectedUid: _uid,
          ),
        ).called(1);
        final saved = savedDays().single;
        expect(saved.flagsKnown, isFalse);
        expect(saved.usedHints, isTrue);
        expect(saved.hadMistakes, isFalse);
        expect(prefs.getString('sync_lb_zip_$_today'), '30');
      },
    );

    test(
      'legacy Sudoku clear yesterday reports mistakes and yesterday',
      () async {
        await build(
          initial: {
            'progress_owner_uid': _uid,
            'best_time_sudoku_$_yesterday': 300,
          },
        );

        await sync();

        verify(
          () => leaderboard.submitBestTime(
            gameId: 'sudoku',
            timeSeconds: 300,
            usedHints: false,
            hadMistakes: true,
            currentStreak: 0,
            dayId: '2026-10-06',
            expectedUid: any(named: 'expectedUid'),
          ),
        ).called(1);
      },
    );

    test('known meta flags are submitted', () async {
      await build(
        initial: {
          'progress_owner_uid': _uid,
          'best_time_sudoku_$_today': 120,
          'hints_used_sudoku_$_today': 1,
          'clear_meta_sudoku_$_today':
              '{"usedHints":false,"hadMistakes":false}',
        },
      );

      await sync();

      verify(
        () => leaderboard.submitBestTime(
          gameId: 'sudoku',
          timeSeconds: 120,
          usedHints: false,
          hadMistakes: false,
          currentStreak: 0,
          dayId: '2026-10-07',
          expectedUid: any(named: 'expectedUid'),
        ),
      ).called(1);
    });

    test('currentStreak is lazily decayed like GetStreak', () async {
      await build(
        initial: {
          'progress_owner_uid': _uid,
          'best_time_path_words_$_yesterday': 50,
          'streak_current_path_words': 5,
          'streak_longest_path_words': 5,
          'streak_last_path_words': '20261003',
          'streak_freeze_path_words': true,
        },
      );

      await sync();

      verify(
        () => leaderboard.submitBestTime(
          gameId: 'path_words',
          timeSeconds: 50,
          usedHints: false,
          hadMistakes: false,
          currentStreak: 0,
          dayId: '2026-10-06',
          expectedUid: any(named: 'expectedUid'),
        ),
      ).called(1);
      // The decay is persisted and pushed, as GetStreak would persist it.
      expect(prefs.getInt('streak_current_path_words'), 0);
      expect(prefs.getInt('streak_longest_path_words'), 5);
      expect(remoteStreaks['path_words']!.current, 0);
    });

    test('a 0 s clear pushes the day but is never submitted', () async {
      await build(
        initial: {
          'progress_owner_uid': _uid,
          'best_time_zip_daily_$_today': 0,
          'best_pts_zip_daily_$_today': 1000,
        },
      );

      final result = await sync();

      expect(result.failures, 0);
      expect(savedDays().single.timeSeconds, 0);
      verifyNoSubmit();
      expect(prefs.getString('sync_lb_zip_$_today'), isNull);
    });

    test('marker prevents a repeat submit until the time improves', () async {
      await build(
        initial: {
          'progress_owner_uid': _uid,
          'best_time_zip_daily_$_today': 30,
        },
      );

      await sync();
      await sync();

      verify(
        () => leaderboard.submitBestTime(
          gameId: 'zip',
          timeSeconds: 30,
          usedHints: any(named: 'usedHints'),
          hadMistakes: any(named: 'hadMistakes'),
          currentStreak: any(named: 'currentStreak'),
          dayId: any(named: 'dayId'),
          expectedUid: any(named: 'expectedUid'),
        ),
      ).called(1);

      await prefs.setInt('best_time_zip_daily_$_today', 28);
      await sync(pull: false);

      verify(
        () => leaderboard.submitBestTime(
          gameId: 'zip',
          timeSeconds: 28,
          usedHints: any(named: 'usedHints'),
          hadMistakes: any(named: 'hadMistakes'),
          currentStreak: any(named: 'currentStreak'),
          dayId: '2026-10-07',
          expectedUid: any(named: 'expectedUid'),
        ),
      ).called(1);
    });

    test(
      'debug minute window covers the previous and current minute',
      () async {
        final at = DateTime(2026, 10, 7, 12, 0, 30);
        await build(
          period: PlayPeriod.minute,
          at: at,
          initial: {
            'progress_owner_uid': _uid,
            'best_time_path_words_202610071200': 12,
            'best_time_path_words_202610071159': 15,
          },
        );

        await sync();

        for (final playId in ['202610071159', '202610071200']) {
          verify(
            () => remote.fetchDay(
              uid: _uid,
              gameId: 'path_words',
              playId: playId,
            ),
          ).called(1);
        }
        final submitted = verify(
          () => leaderboard.submitBestTime(
            gameId: 'path_words',
            timeSeconds: captureAny(named: 'timeSeconds'),
            usedHints: any(named: 'usedHints'),
            hadMistakes: any(named: 'hadMistakes'),
            currentStreak: any(named: 'currentStreak'),
            dayId: '2026-10-07',
            expectedUid: any(named: 'expectedUid'),
          ),
        ).captured;
        expect(submitted, [15, 12]);
      },
    );
  });

  group('failures', () {
    test(
      'failed submit leaves no marker, is reported once and retried',
      () async {
        when(
          () => leaderboard.submitBestTime(
            gameId: any(named: 'gameId'),
            timeSeconds: any(named: 'timeSeconds'),
            usedHints: any(named: 'usedHints'),
            hadMistakes: any(named: 'hadMistakes'),
            currentStreak: any(named: 'currentStreak'),
            dayId: any(named: 'dayId'),
            expectedUid: any(named: 'expectedUid'),
          ),
        ).thenThrow(const Failure('rules'));
        await build(
          initial: {
            'progress_owner_uid': _uid,
            'best_time_zip_daily_$_today': 30,
            'best_time_sudoku_$_today': 90,
          },
        );

        final result = await sync();

        expect(result.failures, 2);
        expect(prefs.getString('sync_lb_zip_$_today'), isNull);
        expect(prefs.getString('sync_lb_sudoku_$_today'), isNull);
        // Day docs still pushed.
        expect(prefs.getString('sync_day_zip_$_today'), isNotNull);
        final report =
            verify(() => clientErrors.report(captureAny())).captured.single
                as ClientErrorReport;
        expect(report.code, 'progress_sync_failed');
        expect(report.source, 'handled');
        expect(report.uid, _uid);

        stubSubmit();
        final retry = await sync();
        expect(retry.failures, 0);
        expect(prefs.getString('sync_lb_zip_$_today'), '30');
        verifyNever(() => clientErrors.report(any()));
      },
    );

    test('failed saveDay leaves no day marker', () async {
      when(
        () => remote.saveDay(
          uid: any(named: 'uid'),
          record: any(named: 'record'),
        ),
      ).thenThrow(const Failure('offline'));
      await build(
        initial: {
          'progress_owner_uid': _uid,
          'best_time_zip_daily_$_today': 30,
        },
      );

      final result = await sync();

      expect(result.failures, 1);
      expect(prefs.getString('sync_day_zip_$_today'), isNull);
      // Leaderboard is independent of the day doc.
      expect(prefs.getString('sync_lb_zip_$_today'), '30');
      verify(() => clientErrors.report(any())).called(1);
    });

    test('failed pull does not overwrite the remote copy', () async {
      when(
        () => remote.fetchDay(
          uid: any(named: 'uid'),
          gameId: any(named: 'gameId'),
          playId: any(named: 'playId'),
        ),
      ).thenThrow(const Failure('timeout'));
      when(
        () => remote.fetchStreak(
          uid: any(named: 'uid'),
          gameId: any(named: 'gameId'),
        ),
      ).thenThrow(const Failure('timeout'));
      await build(
        initial: {
          'progress_owner_uid': _uid,
          'best_time_zip_daily_$_today': 30,
          'streak_current_zip': 1,
          'streak_longest_zip': 1,
          'streak_last_zip': _today,
          'streak_freeze_zip': true,
        },
      );

      final result = await sync();

      expect(result.failures, 3 + 6);
      verifyNoRemoteWrites();
      // Local clear still backfills the board.
      verify(
        () => leaderboard.submitBestTime(
          gameId: 'zip',
          timeSeconds: 30,
          usedHints: false,
          hadMistakes: false,
          currentStreak: 1,
          dayId: '2026-10-07',
          expectedUid: any(named: 'expectedUid'),
        ),
      ).called(1);
      verify(() => clientErrors.report(any())).called(1);
    });

    test('a throwing reporter does not fail the run', () async {
      when(() => clientErrors.report(any())).thenThrow(Exception('down'));
      when(
        () => remote.saveDay(
          uid: any(named: 'uid'),
          record: any(named: 'record'),
        ),
      ).thenThrow(const Failure('offline'));
      await build(
        initial: {
          'progress_owner_uid': _uid,
          'best_time_zip_daily_$_today': 30,
        },
      );

      expect(await sync(), const SyncProgressResult(failures: 1));
    });
  });

  group('serialization', () {
    test('a pull during an in-flight pull shares that run', () async {
      await build(initial: {'progress_owner_uid': _uid});
      final gate = Completer<void>();
      var fetchStreakCalls = 0;
      when(
        () => remote.fetchStreak(
          uid: any(named: 'uid'),
          gameId: any(named: 'gameId'),
        ),
      ).thenAnswer((_) async {
        fetchStreakCalls++;
        if (fetchStreakCalls == 1) await gate.future;
        return null;
      });

      final running = sync();
      await Future<void>.delayed(Duration.zero);
      expect(fetchStreakCalls, 1);
      final joined = sync();
      expect(identical(running, joined), isTrue);

      gate.complete();
      expect(await joined, await running);
      await Future<void>.delayed(Duration.zero);
      expect(fetchStreakCalls, 3, reason: 'one run only');
    });

    test(
      'calls during a push-only run share one rerun with OR-ed pull',
      () async {
        await build(
          initial: {
            'progress_owner_uid': _uid,
            'streak_current_zip': 1,
            'streak_longest_zip': 1,
            'streak_last_zip': _today,
            'streak_freeze_zip': true,
          },
        );
        final gate = Completer<void>();
        var fetchStreakCalls = 0;
        when(
          () => remote.fetchStreak(
            uid: any(named: 'uid'),
            gameId: any(named: 'gameId'),
          ),
        ).thenAnswer((_) async {
          fetchStreakCalls++;
          if (fetchStreakCalls == 1) await gate.future;
          return null;
        });

        final running = sync(pull: false);
        await Future<void>.delayed(Duration.zero);
        expect(fetchStreakCalls, 1);
        var rerunDone = false;
        final second = sync(pull: false)..then((_) => rerunDone = true);
        final third = sync();
        expect(identical(second, third), isTrue);
        // A push-only run must not absorb a pull.
        expect(identical(running, third), isFalse);

        await Future<void>.delayed(Duration.zero);
        expect(fetchStreakCalls, 1, reason: 'no overlap while in flight');
        expect(rerunDone, isFalse);

        gate.complete();
        await running;
        await second;
        // One rerun only, and it pulled (OR of false and true).
        expect(fetchStreakCalls, 1 + 3);
        expect(rerunDone, isTrue);
      },
    );

    test('a push-only rerun stays push-only', () async {
      await build(initial: {'progress_owner_uid': _uid});
      final gate = Completer<void>();
      var calls = 0;
      when(
        () => remote.fetchStreak(
          uid: any(named: 'uid'),
          gameId: any(named: 'gameId'),
        ),
      ).thenAnswer((_) async {
        calls++;
        if (calls == 1) await gate.future;
        return null;
      });

      final running = sync();
      await Future<void>.delayed(Duration.zero);
      final rerun = sync(pull: false);
      gate.complete();
      await running;
      await rerun;

      expect(calls, 3);
    });

    test('restores the current period before streaks and yesterday', () async {
      await build(initial: {'progress_owner_uid': _uid});
      final order = <String>[];
      when(
        () => remote.fetchDay(
          uid: any(named: 'uid'),
          gameId: any(named: 'gameId'),
          playId: any(named: 'playId'),
        ),
      ).thenAnswer((inv) async {
        order.add('day_${inv.namedArguments[#playId]}');
        return null;
      });
      when(
        () => remote.fetchStreak(
          uid: any(named: 'uid'),
          gameId: any(named: 'gameId'),
        ),
      ).thenAnswer((_) async {
        order.add('streak');
        return null;
      });

      await sync();

      expect(order, [
        for (var i = 0; i < 3; i++) 'day_$_today',
        for (var i = 0; i < 3; i++) 'streak',
        for (var i = 0; i < 3; i++) 'day_$_yesterday',
      ]);
    });
  });

  group('account switch during a run', () {
    test('stops before any write for the old account', () async {
      await build(
        initial: {
          'progress_owner_uid': _uid,
          'best_time_zip_daily_$_today': 30,
          'best_time_sudoku_$_today': 90,
        },
      );
      final gate = Completer<void>();
      var fetchDayCalls = 0;
      when(
        () => remote.fetchDay(
          uid: any(named: 'uid'),
          gameId: any(named: 'gameId'),
          playId: any(named: 'playId'),
        ),
      ).thenAnswer((_) async {
        fetchDayCalls++;
        if (fetchDayCalls == 1) await gate.future;
        return null;
      });

      final running = sync();
      await Future<void>.delayed(Duration.zero);
      expect(fetchDayCalls, 1);
      when(
        () => auth.currentUser,
      ).thenReturn(const AppUser(uid: 'u2', displayName: 'Bo'));
      // A pull for another account is not absorbed by the old one's run.
      final next = sync();
      expect(identical(running, next), isFalse);

      gate.complete();
      final first = await running;

      // Aborted, not failed: nothing reported under the old uid.
      expect(first.failures, 0);
      verifyNever(
        () => remote.saveDay(
          uid: _uid,
          record: any(named: 'record'),
        ),
      );
      verifyNoSubmit();
      verifyNever(() => clientErrors.report(any()));

      await next;
      expect(local.ownerUid, 'u2');
      // u1's clears were never pushed: stashed, not lost, and not posted
      // to u2's boards.
      expect(prefs.getInt('best_time_zip_daily_$_today'), isNull);
      expect(prefs.getString('progress_stash_$_uid'), isNotNull);
      verifyNoSubmit();
    });
  });

  group('stash on account switch', () {
    test(
      "the previous owner's unpushed progress comes back when they return",
      () async {
        await build(
          initial: {
            'progress_owner_uid': 'previous',
            'best_time_zip_daily_$_today': 30,
            'hints_used_zip_$_today': 1,
          },
        );

        await sync();
        expect(prefs.getInt('best_time_zip_daily_$_today'), isNull);
        verifyNoSubmit();
        verifyNoRemoteWrites();

        when(
          () => auth.currentUser,
        ).thenReturn(const AppUser(uid: 'previous', displayName: 'P'));
        final result = await sync();

        expect(result.localChanged, isTrue);
        expect(local.ownerUid, 'previous');
        expect(prefs.getInt('best_time_zip_daily_$_today'), 30);
        expect(prefs.getInt('hints_used_zip_$_today'), 1);
        expect(prefs.getString('progress_stash_previous'), isNull);
        final saved = verify(
          () => remote.saveDay(
            uid: 'previous',
            record: captureAny(named: 'record'),
          ),
        ).captured.cast<GameDayRecord>();
        expect(saved.single.timeSeconds, 30);
        verify(
          () => leaderboard.submitBestTime(
            gameId: 'zip',
            timeSeconds: 30,
            usedHints: true,
            hadMistakes: false,
            currentStreak: 0,
            dayId: '2026-10-07',
            expectedUid: 'previous',
          ),
        ).called(1);
      },
    );

    test('fully pushed progress is purged without a stash', () async {
      await build(
        initial: {
          'progress_owner_uid': _uid,
          'best_time_zip_daily_$_today': 30,
        },
      );
      await sync();
      expect(prefs.getString('sync_lb_zip_$_today'), '30');
      // The mock remote is not per uid; u2 has no progress of its own.
      remoteDays.clear();

      when(
        () => auth.currentUser,
      ).thenReturn(const AppUser(uid: 'u2', displayName: 'Bo'));
      await sync();

      expect(prefs.getInt('best_time_zip_daily_$_today'), isNull);
      expect(prefs.getString('progress_stash_$_uid'), isNull);
    });
  });

  group('streak decay', () {
    test(
      'a decayed streak is pushed instead of un-decayed by the remote',
      () async {
        remoteStreaks['zip'] = const GameStreak(
          gameId: 'zip',
          current: 5,
          longest: 5,
          lastClearedDateId: '20261003',
        );
        await build(
          initial: {
            'progress_owner_uid': _uid,
            'streak_current_zip': 5,
            'streak_longest_zip': 5,
            'streak_last_zip': '20261003',
            'streak_freeze_zip': true,
            'sync_streak_zip': 'c=5|l=5|d=20261003|f=1',
          },
        );
        var changes = 0;
        final getStreak = GetStreak(
          StreakRepositoryImpl(prefs, onChanged: () => changes++),
        );

        // Home: GetStreak persists the decay and fires a push-only sync.
        expect((await getStreak(gameId: 'zip', now: now)).current, 0);
        expect(changes, 1);
        final first = await sync(pull: false);

        expect(first.localChanged, isFalse);
        expect(prefs.getInt('streak_current_zip'), 0);
        expect(remoteStreaks['zip']!.current, 0);
        expect(remoteStreaks['zip']!.longest, 5);

        // Home reloads: nothing left to decay, nothing to push or restore.
        expect((await getStreak(gameId: 'zip', now: now)).current, 0);
        expect(changes, 1);
        clearInteractions(remote);
        expect(await sync(pull: false), const SyncProgressResult());
        expect(await sync(), const SyncProgressResult());
        verifyNoRemoteWrites();
      },
    );

    test('a pull decays a stale local copy without signalling Home', () async {
      remoteStreaks['zip'] = const GameStreak(
        gameId: 'zip',
        current: 0,
        longest: 5,
        lastClearedDateId: '20261003',
      );
      await build(
        initial: {
          'progress_owner_uid': _uid,
          'streak_current_zip': 5,
          'streak_longest_zip': 5,
          'streak_last_zip': '20261003',
          'streak_freeze_zip': true,
        },
      );

      final result = await sync();

      expect(result.localChanged, isFalse);
      expect(prefs.getInt('streak_current_zip'), 0);
      verifyNever(
        () => remote.saveStreak(
          uid: any(named: 'uid'),
          streak: any(named: 'streak'),
        ),
      );
    });
  });

  group('regressed remote', () {
    test(
      'a pull re-pushes a day the remote lost after it was pushed',
      () async {
        await build(
          initial: {
            'progress_owner_uid': _uid,
            'best_time_zip_daily_$_today': 40,
            'clear_meta_zip_daily_$_today':
                '{"usedHints":false,"hadMistakes":false}',
          },
        );
        await sync();
        // A stale merge write from another device lands on the server.
        remoteDays['zip_$_today'] = remoteDays['zip_$_today']!.copyWith(
          timeSeconds: 50,
        );
        clearInteractions(remote);

        final result = await sync();

        expect(result.localChanged, isFalse);
        expect(savedDays().single.timeSeconds, 40);
        expect(remoteDays['zip_$_today']!.timeSeconds, 40);
      },
    );

    test('a pull re-pushes a streak the remote regressed', () async {
      await build(
        initial: {
          'progress_owner_uid': _uid,
          'streak_current_zip': 3,
          'streak_longest_zip': 3,
          'streak_last_zip': _today,
          'streak_freeze_zip': true,
        },
      );
      await sync();
      remoteStreaks['zip'] = const GameStreak(
        gameId: 'zip',
        current: 2,
        longest: 3,
        lastClearedDateId: _yesterday,
      );
      clearInteractions(remote);

      await sync();

      final pushed = verify(
        () => remote.saveStreak(
          uid: _uid,
          streak: captureAny(named: 'streak'),
        ),
      ).captured.cast<GameStreak>();
      expect(pushed.single.current, 3);
      expect(pushed.single.lastClearedDateId, _today);
    });
  });

  group('slow remote', () {
    test('a hanging reporter does not hold the run', () async {
      when(
        () => clientErrors.report(any()),
      ).thenAnswer((_) => Completer<void>().future);
      when(
        () => remote.saveDay(
          uid: any(named: 'uid'),
          record: any(named: 'record'),
        ),
      ).thenThrow(const Failure('offline'));
      await build(
        initial: {
          'progress_owner_uid': _uid,
          'best_time_zip_daily_$_today': 30,
        },
      );

      expect(await sync(), const SyncProgressResult(failures: 1));
      verify(() => clientErrors.report(any())).called(1);
      // The next run is not queued behind the hanging report.
      expect(await sync(), const SyncProgressResult(failures: 1));
    });

    test('the same failure is reported once per cooldown', () async {
      var clock = now;
      when(
        () => remote.saveDay(
          uid: any(named: 'uid'),
          record: any(named: 'record'),
        ),
      ).thenThrow(const Failure('offline'));
      await build(
        clockFn: () => clock,
        initial: {
          'progress_owner_uid': _uid,
          'best_time_zip_daily_$_today': 30,
        },
      );

      await sync();
      await sync();
      verify(() => clientErrors.report(any())).called(1);

      clock = now.add(const Duration(minutes: 11));
      await sync();
      verify(() => clientErrors.report(any())).called(1);
    });

    test('a leaderboard timeout skips the remaining submits', () async {
      when(
        () => leaderboard.submitBestTime(
          gameId: any(named: 'gameId'),
          timeSeconds: any(named: 'timeSeconds'),
          usedHints: any(named: 'usedHints'),
          hadMistakes: any(named: 'hadMistakes'),
          currentStreak: any(named: 'currentStreak'),
          dayId: any(named: 'dayId'),
          expectedUid: any(named: 'expectedUid'),
        ),
      ).thenAnswer((_) => Completer<void>().future);
      await build(
        leaderboardTimeout: const Duration(milliseconds: 10),
        initial: {
          'progress_owner_uid': _uid,
          'best_time_zip_daily_$_today': 30,
          'best_time_sudoku_$_today': 90,
        },
      );

      final result = await sync();

      expect(result.failures, 1);
      verify(
        () => leaderboard.submitBestTime(
          gameId: any(named: 'gameId'),
          timeSeconds: any(named: 'timeSeconds'),
          usedHints: any(named: 'usedHints'),
          hadMistakes: any(named: 'hadMistakes'),
          currentStreak: any(named: 'currentStreak'),
          dayId: any(named: 'dayId'),
          expectedUid: any(named: 'expectedUid'),
        ),
      ).called(1);
      expect(prefs.getString('sync_lb_zip_$_today'), isNull);
      expect(prefs.getString('sync_lb_sudoku_$_today'), isNull);
    });
  });

  test('a bloc-confirmed leaderboard marker skips the resubmit', () async {
    await build(
      initial: {
        'progress_owner_uid': _uid,
        'best_time_zip_daily_$_today': 30,
        'sync_lb_zip_$_today': '30',
      },
    );

    await sync(pull: false);

    expect(savedDays().single.timeSeconds, 30);
    verifyNoSubmit();
  });
}
