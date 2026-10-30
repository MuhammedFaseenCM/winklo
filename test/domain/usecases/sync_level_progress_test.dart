import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/level_progress_repository_impl.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/entities/client_error_report.dart';
import 'package:winklo/domain/entities/level_progress.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/repositories/level_progress_remote_repository.dart';
import 'package:winklo/domain/usecases/report_client_error.dart';
import 'package:winklo/domain/usecases/sync_level_progress.dart';

class _MockReport extends Mock implements ReportClientError {}

class _FakeReportArg extends Fake implements ClientErrorReport {}

class _MockAuth extends Mock implements AuthRepository {}

class _MemoryRemote implements LevelProgressRemoteRepository {
  final docs = <String, Object?>{};
  int fetches = 0;
  int saves = 0;
  void Function()? onFetch;
  Future<void> Function()? onFetchAsync;
  void Function()? onSave;
  Object? fetchError;

  @override
  Future<Object?> fetch(String uid, String game) async {
    fetches++;
    onFetch?.call();
    await onFetchAsync?.call();
    final error = fetchError;
    if (error != null) throw error;
    return docs['$uid/$game'];
  }

  @override
  Future<void> save(String uid, String game, LevelProgress progress) async {
    saves++;
    onSave?.call();
    docs['$uid/$game'] = progress.toJson();
  }
}

void main() {
  late _MockAuth auth;
  late AppUser? user;
  late _MemoryRemote remote;
  late LevelProgressRepositoryImpl local;
  late SyncLevelProgress sync;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    auth = _MockAuth();
    user = const AppUser(uid: 'u1', displayName: 'A');
    when(() => auth.currentUser).thenAnswer((_) => user);
    remote = _MemoryRemote();
    local = LevelProgressRepositoryImpl(
      await SharedPreferences.getInstance(),
      currentUid: () => user?.uid,
    );
    sync = SyncLevelProgress(auth: auth, local: local, remote: remote);
  });

  test('a pull merges both copies and writes the result to both', () async {
    remote.docs['u1/zip'] = {
      'zip_1_01': {'stars': 3, 'bestSeconds': 40},
      'zip_1_02': {'stars': 1, 'bestSeconds': 60},
    };
    await local.record('zip', 'zip_1_01', stars: 2, seconds: 20);
    await sync(pull: true);
    expect(
      local.progress('zip')['zip_1_01'],
      const LevelRecord(stars: 3, bestSeconds: 20),
    );
    expect(local.progress('zip').isCleared('zip_1_02'), isTrue);
    expect(
      LevelProgress.parse(
        remote.docs['u1/zip'],
      ).progress.sameAs(local.progress('zip')),
      isTrue,
    );
    expect(local.needsPush('zip'), isFalse);
  });

  test('a push-only run does nothing when nothing changed', () async {
    await sync(pull: false);
    expect(remote.fetches, 0);
  });

  test('a push-only run pushes a new clear', () async {
    await local.record('zip', 'zip_1_01', stars: 2, seconds: 20);
    await sync(pull: false);
    expect(remote.saves, 1);
    expect(local.needsPush('zip'), isFalse);
  });

  test('an identical remote copy is not written again', () async {
    remote.docs['u1/zip'] = {
      'zip_1_01': {'stars': 2, 'bestSeconds': 20},
    };
    await local.record('zip', 'zip_1_01', stars: 2, seconds: 20);
    await sync(pull: true);
    expect(remote.saves, 0);
  });

  test('invalid remote entries are dropped and the doc rewritten', () async {
    remote.docs['u1/zip'] = {
      'zip_1_01': {'stars': 9, 'bestSeconds': 20},
    };
    await sync(pull: true);
    expect(remote.saves, 1);
    expect(local.progress('zip').records, isEmpty);
  });

  test('signed out: nothing happens', () async {
    user = null;
    await sync(pull: true);
    expect(remote.fetches, 0);
  });

  test('an account switch mid-sync leaves both copies alone', () async {
    await local.record('zip', 'zip_1_01', stars: 2, seconds: 20);
    remote.onFetch = () => user = const AppUser(uid: 'u2', displayName: 'B');
    await sync(pull: true);
    expect(remote.saves, 0);
    user = const AppUser(uid: 'u1', displayName: 'A');
    expect(local.progress('zip').isCleared('zip_1_01'), isTrue);
    expect(local.needsPush('zip'), isTrue);
    user = const AppUser(uid: 'u2', displayName: 'B');
    expect(local.progress('zip').records, isEmpty);
  });

  test('a clear recorded during the save stays pending', () async {
    await local.record('zip', 'zip_1_01', stars: 2, seconds: 20);
    remote.onSave = () =>
        unawaited(local.record('zip', 'zip_1_02', stars: 1, seconds: 30));
    await sync(pull: false);
    await pumpEventQueue();
    expect(local.needsPush('zip'), isTrue);
    expect(
      LevelProgress.parse(remote.docs['u1/zip']).progress.isCleared('zip_1_02'),
      isFalse,
    );
  });

  test('a switch during the save does not mark pushed', () async {
    await local.record('zip', 'zip_1_01', stars: 2, seconds: 20);
    remote.onSave = () => user = const AppUser(uid: 'u2', displayName: 'B');
    await sync(pull: false);
    expect(local.progress('zip').records, isEmpty);
    user = const AppUser(uid: 'u1', displayName: 'A');
    expect(local.needsPush('zip'), isTrue);
  });

  test('remote unavailable: nothing happens', () async {
    sync = SyncLevelProgress(
      auth: auth,
      local: local,
      remote: remote,
      isRemoteAvailable: () => false,
    );
    await sync(pull: true);
    expect(remote.fetches, 0);
  });

  test('a pull into an empty local restores without saving', () async {
    remote.docs['u1/zip'] = {
      'zip_1_01': {'stars': 2, 'bestSeconds': 20},
    };
    await sync(pull: true);
    expect(local.progress('zip').isCleared('zip_1_01'), isTrue);
    expect(remote.saves, 0);
  });

  group('failures', () {
    late _MockReport report;
    late DateTime now;
    final reports = <ClientErrorReport>[];

    setUpAll(() => registerFallbackValue(_FakeReportArg()));

    setUp(() {
      reports.clear();
      now = DateTime(2026, 10, 7, 9);
      report = _MockReport();
      when(() => report(any())).thenAnswer((inv) async {
        reports.add(inv.positionalArguments.first as ClientErrorReport);
      });
      sync = SyncLevelProgress(
        auth: auth,
        local: local,
        remote: remote,
        reportClientError: report,
        now: () => now,
      );
    });

    test('is reported once per cooldown and rethrown', () async {
      remote.fetchError = StateError('permission-denied');
      await expectLater(sync(pull: true), throwsStateError);
      expect(reports, hasLength(1));
      expect(reports.single.code, 'level_progress_sync_failed');
      expect(reports.single.uid, 'u1');
      expect(reports.single.function, 'SyncLevelProgress');
      await expectLater(sync(pull: true), throwsStateError);
      expect(reports, hasLength(1));
      now = now.add(const Duration(minutes: 11));
      await expectLater(sync(pull: true), throwsStateError);
      expect(reports, hasLength(2));
    });

    test('a timeout is not reported', () async {
      remote.fetchError = TimeoutException('slow');
      await expectLater(sync(pull: true), throwsA(isA<TimeoutException>()));
      expect(reports, isEmpty);
    });
  });

  test('overlapping calls run one after the other', () async {
    final gate = Completer<void>();
    remote.onFetchAsync = () => gate.future;
    final first = sync(pull: true);
    await pumpEventQueue();
    expect(remote.fetches, 1);
    final second = sync(pull: false);
    await pumpEventQueue();
    expect(remote.fetches, 1);
    gate.complete();
    await first;
    await second;
    // The queued rerun was push-only with nothing new to push.
    expect(remote.fetches, 1);
  });

  test('a queued pull reruns after a push-only run', () async {
    await local.record('zip', 'zip_1_01', stars: 2, seconds: 20);
    final gate = Completer<void>();
    remote.onFetchAsync = () => gate.future;
    final first = sync(pull: false);
    final second = sync(pull: true);
    await pumpEventQueue();
    expect(remote.fetches, 1);
    gate.complete();
    await Future.wait([first, second]);
    expect(remote.fetches, 2);
  });
}
