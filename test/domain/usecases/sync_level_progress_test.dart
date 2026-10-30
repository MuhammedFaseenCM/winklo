import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/level_progress_repository_impl.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/entities/level_progress.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/repositories/level_progress_remote_repository.dart';
import 'package:winklo/domain/usecases/sync_level_progress.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MemoryRemote implements LevelProgressRemoteRepository {
  final docs = <String, Object?>{};
  int fetches = 0;
  int saves = 0;
  void Function()? onFetch;

  @override
  Future<Object?> fetch(String uid, String game) async {
    fetches++;
    onFetch?.call();
    return docs['$uid/$game'];
  }

  @override
  Future<void> save(String uid, String game, LevelProgress progress) async {
    saves++;
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
  });
}
