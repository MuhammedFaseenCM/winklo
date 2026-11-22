import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/pending_level_clear_repository_impl.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/entities/cell.dart';
import 'package:winklo/domain/entities/client_error_report.dart';
import 'package:winklo/domain/entities/leaderboard_proof.dart';
import 'package:winklo/domain/entities/pending_level_clear.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/repositories/client_error_repository.dart';
import 'package:winklo/domain/repositories/leaderboard_repository.dart';
import 'package:winklo/domain/repositories/pending_level_clear_repository.dart';
import 'package:winklo/domain/usecases/report_client_error.dart';
import 'package:winklo/domain/usecases/submit_level_clear.dart';

import '../../helpers/mock_analytics_repository.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockLeaderboard extends Mock implements LeaderboardRepository {}

class _MockClientErrors extends Mock implements ClientErrorRepository {}

/// Records the order of store calls on top of the real prefs-backed store.
class _LoggedPending implements PendingLevelClearRepository {
  _LoggedPending(this.inner, this.log);
  final PendingLevelClearRepositoryImpl inner;
  final List<String> log;

  @override
  List<PendingLevelClear> pending(String uid, String game) =>
      inner.pending(uid, game);

  @override
  Future<void> keep(String uid, String game, PendingLevelClear clear) {
    log.add('keep ${clear.levelId}');
    return inner.keep(uid, game, clear);
  }

  @override
  Future<void> drop(String uid, String game, String levelId) {
    log.add('drop $levelId');
    return inner.drop(uid, game, levelId);
  }
}

/// A store whose read-modify-write has gaps in it, as a slow disk gives: a
/// second call that starts inside a gap works from the list the first one
/// read, and one of the two writes is lost.
class _GappyPending implements PendingLevelClearRepository {
  final Map<String, List<PendingLevelClear>> data = {};

  @override
  List<PendingLevelClear> pending(String uid, String game) =>
      List.of(data['$uid/$game'] ?? const []);

  @override
  Future<void> keep(String uid, String game, PendingLevelClear clear) async {
    final all = pending(uid, game);
    await pumpEventQueue(times: 3);
    final index = all.indexWhere((c) => c.levelId == clear.levelId);
    if (index >= 0) {
      if (!clear.betterThan(all[index])) return;
      all[index] = clear;
    } else {
      all.add(clear);
    }
    data['$uid/$game'] = all;
  }

  @override
  Future<void> drop(String uid, String game, String levelId) async {
    final all = pending(uid, game);
    await pumpEventQueue(times: 3);
    data['$uid/$game'] = [
      for (final c in all)
        if (c.levelId != levelId) c,
    ];
  }
}

const _proof = ZipLeaderboardProof([Cell(0, 0), Cell(0, 1)]);

void main() {
  late _MockAuth auth;
  late _MockLeaderboard leaderboard;
  late _MockClientErrors clientErrors;
  late MockAnalyticsRepository analytics;
  late PendingLevelClearRepositoryImpl store;
  late List<String> log;
  late SubmitLevelClear submit;
  const user = AppUser(
    uid: 'u1',
    displayName: 'Ana',
    photoUrl: 'p.png',
    avatarId: 'a1',
  );
  AppUser? current;

  setUpAll(() {
    registerFallbackValue(_proof);
    registerFallbackValue(
      const ClientErrorReport(
        severity: 'error',
        source: 'handled',
        code: 'x',
        message: 'x',
      ),
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    store = PendingLevelClearRepositoryImpl(prefs);
    log = [];
    auth = _MockAuth();
    leaderboard = _MockLeaderboard();
    clientErrors = _MockClientErrors();
    analytics = MockAnalyticsRepository();
    stubAnalytics(analytics);
    current = user;
    when(() => auth.currentUser).thenAnswer((_) => current);
    when(() => clientErrors.report(any())).thenAnswer((_) async {});
    submit = SubmitLevelClear(
      auth: auth,
      leaderboard: leaderboard,
      pending: _LoggedPending(store, log),
      analytics: analytics,
      reportClientError: ReportClientError(clientErrors),
    );
  });

  PendingLevelClear clear(String id, {int stars = 2, int seconds = 20}) =>
      PendingLevelClear(
        levelId: id,
        stars: stars,
        timeSeconds: seconds,
        usedHints: false,
        proof: _proof,
      );

  void stubSubmit(Future<LevelClearSubmitOutcome> Function(Invocation) answer) {
    when(
      () => leaderboard.submitLevelClear(
        gameId: any(named: 'gameId'),
        levelId: any(named: 'levelId'),
        timeSeconds: any(named: 'timeSeconds'),
        usedHints: any(named: 'usedHints'),
        proof: any(named: 'proof'),
        expectedUid: any(named: 'expectedUid'),
      ),
    ).thenAnswer(answer);
  }

  void stubOutcome(LevelClearSubmitOutcome outcome) =>
      stubSubmit((_) async => outcome);

  Future<void> run({
    String levelId = 'zip_1_01',
    int stars = 3,
    bool improved = true,
  }) => submit(
    game: 'zip',
    levelId: levelId,
    stars: stars,
    timeSeconds: 20,
    usedHints: false,
    proof: _proof,
    improved: improved,
  );

  void verifyLogged({
    required bool accepted,
    bool improved = true,
    String? code,
  }) {
    verify(
      () => analytics.logLevelBoardSubmit(
        levelId: 'zip_1_01',
        accepted: accepted,
        improved: improved,
        code: code,
      ),
    ).called(1);
  }

  group('call', () {
    test('signed out does nothing', () async {
      current = null;
      await run();
      expect(log, isEmpty);
      verifyNever(
        () => leaderboard.submitLevelClear(
          gameId: any(named: 'gameId'),
          levelId: any(named: 'levelId'),
          timeSeconds: any(named: 'timeSeconds'),
          usedHints: any(named: 'usedHints'),
          proof: any(named: 'proof'),
          expectedUid: any(named: 'expectedUid'),
        ),
      );
    });

    test('keeps the clear first, then sends it for the current uid', () async {
      List<PendingLevelClear>? keptWhenSent;
      stubSubmit((_) async {
        keptWhenSent = store.pending('u1', 'zip');
        return LevelClearSubmitOutcome.sent;
      });
      await run();
      expect(keptWhenSent!.single.levelId, 'zip_1_01');
      verify(
        () => leaderboard.submitLevelClear(
          gameId: 'zip',
          levelId: 'zip_1_01',
          timeSeconds: 20,
          usedHints: false,
          proof: _proof,
          expectedUid: 'u1',
        ),
      ).called(1);
    });

    test('sent drops the clear and logs an accepted submit', () async {
      stubOutcome(LevelClearSubmitOutcome.sent);
      await run();
      expect(store.pending('u1', 'zip'), isEmpty);
      expect(log, ['keep zip_1_01', 'drop zip_1_01']);
      verifyLogged(accepted: true);
      verifyNever(() => clientErrors.report(any()));
    });

    test('unavailable keeps the clear', () async {
      stubOutcome(LevelClearSubmitOutcome.unavailable);
      await run();
      expect(store.pending('u1', 'zip').single.levelId, 'zip_1_01');
      verifyLogged(accepted: false, code: 'unavailable');
    });

    test('a refusal drops the clear and reports it', () async {
      stubSubmit((_) async => throw const LeaderboardSubmitRefused('too_fast'));
      await run();
      expect(store.pending('u1', 'zip'), isEmpty);
      verifyLogged(accepted: false, code: 'too_fast');
      final report =
          verify(() => clientErrors.report(captureAny())).captured.single
              as ClientErrorReport;
      expect(report.code, SubmitLevelClear.failureCode);
      expect(report.uid, 'u1');
    });

    test('notSent drops the clear', () async {
      stubOutcome(LevelClearSubmitOutcome.notSent);
      await run();
      expect(store.pending('u1', 'zip'), isEmpty);
      verifyLogged(accepted: false, code: 'not_sent');
    });

    test(
      'an unexpected error keeps the clear, reports, never throws',
      () async {
        stubSubmit((_) async => throw StateError('boom'));
        await run();
        expect(store.pending('u1', 'zip'), hasLength(1));
        verify(() => clientErrors.report(any())).called(1);
      },
    );
  });

  group('accepted', () {
    test('emits the level id when the Worker takes a clear', () async {
      stubOutcome(LevelClearSubmitOutcome.sent);
      final ids = <String>[];
      final sub = submit.accepted.listen(ids.add);
      await run();
      await pumpEventQueue();
      expect(ids, ['zip_1_01']);
      await sub.cancel();
    });

    test('emits nothing for unavailable, notSent or a refusal', () async {
      final ids = <String>[];
      final sub = submit.accepted.listen(ids.add);
      stubOutcome(LevelClearSubmitOutcome.unavailable);
      await run();
      stubOutcome(LevelClearSubmitOutcome.notSent);
      await run();
      stubSubmit((_) async => throw const LeaderboardSubmitRefused('too_fast'));
      await run();
      await pumpEventQueue();
      expect(ids, isEmpty);
      await sub.cancel();
    });

    test('emits each clear a resend gets taken', () async {
      await store.keep('u1', 'zip', clear('zip_1_01'));
      await store.keep('u1', 'zip', clear('zip_1_02'));
      stubOutcome(LevelClearSubmitOutcome.sent);
      final ids = <String>[];
      final sub = submit.accepted.listen(ids.add);
      await submit.resendPending('zip');
      await pumpEventQueue();
      expect(ids, ['zip_1_01', 'zip_1_02']);
      await sub.cancel();
    });

    test('emits nothing when another account signed in meanwhile', () async {
      stubSubmit((_) async {
        current = const AppUser(uid: 'u2', displayName: 'Bo');
        return LevelClearSubmitOutcome.sent;
      });
      final ids = <String>[];
      final sub = submit.accepted.listen(ids.add);
      await run();
      await pumpEventQueue();
      expect(ids, isEmpty);
      await sub.cancel();
    });
  });

  group('resendPending', () {
    setUp(() async {
      await store.keep('u1', 'zip', clear('zip_1_01'));
      await store.keep('u1', 'zip', clear('zip_1_02'));
      await store.keep('u2', 'zip', clear('zip_9_09'));
    });

    test('sends the current account\'s clears only, then drops them', () async {
      stubOutcome(LevelClearSubmitOutcome.sent);
      await submit.resendPending('zip');
      expect(store.pending('u1', 'zip'), isEmpty);
      expect(store.pending('u2', 'zip'), hasLength(1));
      verify(
        () => leaderboard.submitLevelClear(
          gameId: 'zip',
          levelId: any(named: 'levelId'),
          timeSeconds: any(named: 'timeSeconds'),
          usedHints: any(named: 'usedHints'),
          proof: any(named: 'proof'),
          expectedUid: 'u1',
        ),
      ).called(2);
    });

    test('signed out sends nothing', () async {
      current = null;
      await submit.resendPending('zip');
      verifyNever(
        () => leaderboard.submitLevelClear(
          gameId: any(named: 'gameId'),
          levelId: any(named: 'levelId'),
          timeSeconds: any(named: 'timeSeconds'),
          usedHints: any(named: 'usedHints'),
          proof: any(named: 'proof'),
          expectedUid: any(named: 'expectedUid'),
        ),
      );
    });

    test('an account switch mid-loop stops it', () async {
      final sent = <String>[];
      stubSubmit((inv) async {
        sent.add(inv.namedArguments[#levelId] as String);
        current = const AppUser(uid: 'u2', displayName: 'Bo');
        return LevelClearSubmitOutcome.sent;
      });
      await submit.resendPending('zip');
      expect(sent, ['zip_1_01']);
      expect(store.pending('u1', 'zip').single.levelId, 'zip_1_02');
      expect(store.pending('u2', 'zip'), hasLength(1));
    });

    test('stops at the first unavailable', () async {
      final sent = <String>[];
      stubSubmit((inv) async {
        sent.add(inv.namedArguments[#levelId] as String);
        return LevelClearSubmitOutcome.unavailable;
      });
      await submit.resendPending('zip');
      expect(sent, hasLength(1));
      expect(store.pending('u1', 'zip'), hasLength(2));
    });

    test('a refused clear is dropped and the next one still goes', () async {
      stubSubmit((inv) async {
        if (inv.namedArguments[#levelId] == 'zip_1_01') {
          throw const LeaderboardSubmitRefused('too_fast');
        }
        return LevelClearSubmitOutcome.sent;
      });
      await submit.resendPending('zip');
      expect(store.pending('u1', 'zip'), isEmpty);
    });

    test(
      'a Path Words resend starting during a Zip resend still sends',
      () async {
        await store.keep(
          'u1',
          'path_words',
          const PendingLevelClear(
            levelId: 'path_words_1_01',
            stars: 2,
            timeSeconds: 20,
            usedHints: false,
            proof: PathWordsLeaderboardProof([
              PathWordsProofStroke(
                targetId: 't0',
                cells: [Cell(0, 0), Cell(0, 1)],
              ),
            ]),
          ),
        );
        final release = Completer<void>();
        final sent = <String>[];
        stubSubmit((inv) async {
          sent.add(inv.namedArguments[#levelId] as String);
          if (inv.namedArguments[#gameId] == 'zip') await release.future;
          return LevelClearSubmitOutcome.sent;
        });
        final zip = submit.resendPending('zip');
        await pumpEventQueue();
        await submit.resendPending('path_words');
        expect(sent, contains('path_words_1_01'));
        expect(store.pending('u1', 'path_words'), isEmpty);
        release.complete();
        await zip;
      },
    );

    test('a second call for the same game shares the running resend', () async {
      final release = Completer<void>();
      stubSubmit((inv) async {
        await release.future;
        return LevelClearSubmitOutcome.sent;
      });
      final first = submit.resendPending('zip');
      final second = submit.resendPending('zip');
      expect(identical(first, second), isTrue);
      release.complete();
      await first;
    });

    test('sends one after another, not together', () async {
      var inFlight = 0;
      var maxInFlight = 0;
      stubSubmit((_) async {
        inFlight++;
        if (inFlight > maxInFlight) maxInFlight = inFlight;
        await pumpEventQueue(times: 5);
        inFlight--;
        return LevelClearSubmitOutcome.sent;
      });
      await submit.resendPending('zip');
      expect(maxInFlight, 1);
    });
  });

  test('a clear made during a resend is not lost, and a better one survives '
      'the older one being sent', () async {
    await store.keep('u1', 'zip', clear('zip_1_01', stars: 1, seconds: 40));
    await store.keep('u1', 'zip', clear('zip_1_02'));
    final release = Completer<void>();
    final sentSeconds = <int>[];
    stubSubmit((inv) async {
      sentSeconds.add(inv.namedArguments[#timeSeconds] as int);
      // The resend's first send waits until the new clear is under way.
      if (!release.isCompleted) await release.future;
      return LevelClearSubmitOutcome.sent;
    });

    final resend = submit.resendPending('zip');
    await pumpEventQueue();
    // A better run of level 1 and a new level 3, while the resend is
    // waiting on the network.
    final made = Future.wait([
      submit(
        game: 'zip',
        levelId: 'zip_1_01',
        stars: 3,
        timeSeconds: 15,
        usedHints: false,
        proof: _proof,
      ),
      submit(
        game: 'zip',
        levelId: 'zip_1_03',
        stars: 2,
        timeSeconds: 25,
        usedHints: false,
        proof: _proof,
      ),
    ]);
    await pumpEventQueue();
    release.complete();
    await Future.wait([resend, made]);

    // Every clear went out and was dropped; none of the interleaved
    // reads and writes lost another's update.
    expect(store.pending('u1', 'zip'), isEmpty);
    expect(sentSeconds, containsAll([40, 15, 25]));
  });

  test('a better run kept while the older one is in flight stays pending '
      'when that older one finishes', () async {
    await store.keep('u1', 'zip', clear('zip_1_01', stars: 1, seconds: 40));
    final release = Completer<void>();
    var calls = 0;
    stubSubmit((_) async {
      calls++;
      if (calls == 1) {
        await release.future;
        return LevelClearSubmitOutcome.sent;
      }
      // The better run's own send can't get through.
      return LevelClearSubmitOutcome.unavailable;
    });

    final resend = submit.resendPending('zip');
    await pumpEventQueue();
    await submit(
      game: 'zip',
      levelId: 'zip_1_01',
      stars: 3,
      timeSeconds: 15,
      usedHints: false,
      proof: _proof,
    );
    release.complete();
    await resend;

    final left = store.pending('u1', 'zip').single;
    expect(left.stars, 3);
    expect(left.timeSeconds, 15);
  });

  test('a clear made while a resend runs leaves the right pending state '
      '(store calls are queued)', () async {
    final gappy = _GappyPending();
    final shared = SubmitLevelClear(
      auth: auth,
      leaderboard: leaderboard,
      pending: gappy,
      analytics: analytics,
    );
    await gappy.keep('u1', 'zip', clear('zip_1_01'));
    await gappy.keep('u1', 'zip', clear('zip_1_02'));
    stubSubmit(
      (inv) async => inv.namedArguments[#levelId] == 'zip_1_03'
          ? LevelClearSubmitOutcome.unavailable
          : LevelClearSubmitOutcome.sent,
    );

    await Future.wait([
      shared.resendPending('zip'),
      shared(
        game: 'zip',
        levelId: 'zip_1_03',
        stars: 2,
        timeSeconds: 25,
        usedHints: false,
        proof: _proof,
      ),
    ]);

    expect(
      [for (final c in gappy.pending('u1', 'zip')) c.levelId],
      ['zip_1_03'],
    );
  });

  test('overlapping resends post each clear once', () async {
    await store.keep('u1', 'zip', clear('zip_1_01'));
    await store.keep('u1', 'zip', clear('zip_1_02'));
    final release = Completer<void>();
    final sent = <String>[];
    stubSubmit((inv) async {
      sent.add(inv.namedArguments[#levelId] as String);
      await release.future;
      return LevelClearSubmitOutcome.sent;
    });

    final first = submit.resendPending('zip');
    await pumpEventQueue();
    // The next sync pass, while the first loop is still sending.
    final second = submit.resendPending('zip');
    release.complete();
    await Future.wait([first, second]);

    expect(sent, ['zip_1_01', 'zip_1_02']);
    expect(store.pending('u1', 'zip'), isEmpty);

    // Once it has finished, a new resend starts a new run.
    await store.keep('u1', 'zip', clear('zip_1_03'));
    await submit.resendPending('zip');
    expect(sent, ['zip_1_01', 'zip_1_02', 'zip_1_03']);
  });
}
