import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/lifecycle/progress_change_signal.dart';
import 'package:winklo/core/lifecycle/progress_sync_lifecycle.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/usecases/sync_progress.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockSyncProgress extends Mock implements SyncProgress {}

class _FakeTimer implements Timer {
  _FakeTimer(this.duration, this._callback);

  final Duration duration;
  final void Function() _callback;
  bool _active = true;

  void fire() {
    if (!_active) return;
    _active = false;
    _callback();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

const _user = AppUser(uid: 'u1', displayName: 'A');
const _other = AppUser(uid: 'u2', displayName: 'B');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockAuthRepository auth;
  late _MockSyncProgress sync;
  late StreamController<AppUser?> authEvents;
  late ProgressChangeSignal signal;
  late List<_FakeTimer> timers;
  late DateTime now;
  late AppUser? currentUser;
  late List<bool> pulls;
  late SyncProgressResult nextResult;

  setUp(() {
    auth = _MockAuthRepository();
    sync = _MockSyncProgress();
    authEvents = StreamController<AppUser?>.broadcast();
    signal = ProgressChangeSignal();
    timers = [];
    now = DateTime(2026, 10, 7, 9);
    currentUser = _user;
    pulls = [];
    nextResult = const SyncProgressResult();
    when(() => auth.currentUser).thenAnswer((_) => currentUser);
    when(() => auth.authStateChanges()).thenAnswer((_) => authEvents.stream);
    when(() => sync(pull: any(named: 'pull'))).thenAnswer((inv) async {
      pulls.add(inv.namedArguments[#pull] as bool);
      return nextResult;
    });
  });

  tearDown(() async {
    await authEvents.close();
    await signal.dispose();
  });

  ProgressSyncLifecycle build() => ProgressSyncLifecycle(
    syncProgress: sync,
    authRepository: auth,
    localChanges: signal.changes,
    now: () => now,
    createTimer: (duration, callback) {
      final timer = _FakeTimer(duration, callback);
      timers.add(timer);
      return timer;
    },
  );

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  test('start runs a full sync when signed in', () async {
    final lifecycle = build()..start();
    await flush();
    expect(pulls, [true]);
    lifecycle.dispose();
  });

  test('start does nothing when signed out', () async {
    currentUser = null;
    final lifecycle = build()..start();
    await flush();
    expect(pulls, isEmpty);
    lifecycle.dispose();
  });

  test('start twice only syncs once', () async {
    final lifecycle = build()
      ..start()
      ..start();
    await flush();
    expect(pulls, [true]);
    lifecycle.dispose();
  });

  test('resume is throttled to once per 2 minutes', () async {
    final lifecycle = build()..start();
    await flush();
    expect(pulls, [true]);

    now = now.add(const Duration(minutes: 1, seconds: 59));
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await flush();
    expect(pulls, [true]);

    now = now.add(const Duration(seconds: 1));
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await flush();
    expect(pulls, [true, true]);

    // Throttle restarts from the last full sync.
    now = now.add(const Duration(minutes: 1));
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await flush();
    expect(pulls, [true, true]);
    lifecycle.dispose();
  });

  test('non-resumed states and signed-out resume do not sync', () async {
    currentUser = null;
    final lifecycle = build()..start();
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await flush();
    expect(pulls, isEmpty);
    lifecycle.dispose();
  });

  test('sign-in runs a full sync even inside the resume throttle', () async {
    currentUser = null;
    final lifecycle = build()..start();
    await flush();
    expect(pulls, isEmpty);

    currentUser = _user;
    authEvents.add(_user);
    await flush();
    expect(pulls, [true]);

    // Re-emitting the same user (profile refresh) is not a new sign-in.
    authEvents.add(_user);
    await flush();
    expect(pulls, [true]);

    // Sign out then back in within seconds: unthrottled.
    currentUser = null;
    authEvents.add(null);
    await flush();
    now = now.add(const Duration(seconds: 5));
    currentUser = _user;
    authEvents.add(_user);
    await flush();
    expect(pulls, [true, true]);
    lifecycle.dispose();
  });

  test('switching directly to another uid runs a full sync', () async {
    final lifecycle = build()..start();
    await flush();
    currentUser = _other;
    authEvents.add(_other);
    await flush();
    expect(pulls, [true, true]);
    lifecycle.dispose();
  });

  test('local changes debounce into one push-only sync', () async {
    final lifecycle = build()..start();
    await flush();
    pulls.clear();

    signal.notify();
    await flush();
    signal.notify();
    await flush();
    signal.notify();
    await flush();

    expect(timers, hasLength(3));
    expect(
      timers.every((t) => t.duration == const Duration(seconds: 2)),
      isTrue,
    );
    expect(timers.where((t) => t.isActive), hasLength(1));
    expect(pulls, isEmpty);

    timers.last.fire();
    await flush();
    expect(pulls, [false]);
    lifecycle.dispose();
  });

  test('local change while signed out does not schedule a push', () async {
    currentUser = null;
    final lifecycle = build()..start();
    signal.notify();
    await flush();
    expect(timers, isEmpty);
    lifecycle.dispose();
  });

  test('sign-out cancels a pending push', () async {
    final lifecycle = build()..start();
    await flush();
    pulls.clear();
    signal.notify();
    await flush();
    expect(timers.single.isActive, isTrue);

    currentUser = null;
    authEvents.add(null);
    await flush();
    expect(timers.single.isActive, isFalse);
    expect(pulls, isEmpty);
    lifecycle.dispose();
  });

  test('a full sync supersedes a pending push', () async {
    final lifecycle = build()..start();
    await flush();
    pulls.clear();
    signal.notify();
    await flush();

    now = now.add(const Duration(minutes: 3));
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await flush();
    expect(timers.single.isActive, isFalse);
    expect(pulls, [true]);
    lifecycle.dispose();
  });

  test('restored fires only when a run changed local data', () async {
    final lifecycle = build();
    var restored = 0;
    final sub = lifecycle.restored.listen((_) => restored++);

    nextResult = const SyncProgressResult(localChanged: true);
    lifecycle.start();
    await flush();
    await flush();
    expect(restored, 1);

    nextResult = const SyncProgressResult(failures: 2);
    signal.notify();
    await flush();
    timers.last.fire();
    await flush();
    await flush();
    expect(restored, 1);

    await sub.cancel();
    lifecycle.dispose();
  });

  test('a throwing sync is swallowed', () async {
    when(
      () => sync(pull: any(named: 'pull')),
    ).thenAnswer((_) async => throw StateError('boom'));
    final lifecycle = build()..start();
    await flush();
    lifecycle.dispose();
  });

  test('dispose stops listening and closes restored', () async {
    final lifecycle = build()..start();
    await flush();
    pulls.clear();
    var done = false;
    lifecycle.restored.listen(null, onDone: () => done = true);

    lifecycle.dispose();
    await flush();
    expect(done, isTrue);

    signal.notify();
    currentUser = _other;
    authEvents.add(_other);
    await flush();
    expect(timers, isEmpty);
    expect(pulls, isEmpty);
    // Second dispose is a no-op.
    lifecycle.dispose();
  });
}
