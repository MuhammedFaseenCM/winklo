import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/lifecycle/habit_refresh_lifecycle.dart';
import 'package:winklo/core/lifecycle/progress_change_signal.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProgressChangeSignal signal;
  late StreamController<void> restored;
  late List<_FakeTimer> timers;
  late DateTime now;
  late int refreshes;
  late Object? failure;

  setUp(() {
    signal = ProgressChangeSignal();
    restored = StreamController<void>.broadcast();
    timers = [];
    now = DateTime(2026, 10, 15, 22, 30);
    refreshes = 0;
    failure = null;
  });

  tearDown(() async {
    await signal.dispose();
    await restored.close();
  });

  HabitRefreshLifecycle build() => HabitRefreshLifecycle(
    refresh: () async {
      refreshes++;
      final error = failure;
      if (error != null) throw error;
    },
    localChanges: signal.changes,
    restored: restored.stream,
    now: () => now,
    createTimer: (duration, callback) {
      final timer = _FakeTimer(duration, callback);
      timers.add(timer);
      return timer;
    },
  );

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  List<_FakeTimer> active() => timers.where((t) => t.isActive).toList();

  test('start refreshes once and arms the midnight timer', () async {
    final lifecycle = build()
      ..start()
      ..start();
    await flush();
    expect(refreshes, 1);
    expect(
      active().single.duration,
      const Duration(hours: 1, minutes: 30, seconds: 1),
    );
    lifecycle.dispose();
  });

  test('midnight refreshes and re-arms for the next one', () async {
    final lifecycle = build()..start();
    await flush();
    final midnight = active().single;
    now = DateTime(2026, 10, 16, 0, 0, 1);
    midnight.fire();
    await flush();
    expect(refreshes, 2);
    expect(active().single.duration, const Duration(hours: 24));
    lifecycle.dispose();
  });

  test('local changes refresh once after the debounce', () async {
    final lifecycle = build()..start();
    await flush();
    signal
      ..notify()
      ..notify();
    await flush();
    final debounces = active()
        .where((t) => t.duration == HabitRefreshLifecycle.defaultDebounce)
        .toList();
    expect(debounces, hasLength(1));
    expect(refreshes, 1);
    debounces.single.fire();
    await flush();
    expect(refreshes, 2);
    lifecycle.dispose();
  });

  test('resume and a sync restore refresh at once', () async {
    final lifecycle = build()..start();
    await flush();
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
    await flush();
    expect(refreshes, 1);
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await flush();
    expect(refreshes, 2);
    restored.add(null);
    await flush();
    expect(refreshes, 3);
    lifecycle.dispose();
  });

  test('resume re-arms midnight from the new time', () async {
    final lifecycle = build()..start();
    await flush();
    now = DateTime(2026, 10, 17, 9);
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await flush();
    expect(active().single.duration, const Duration(hours: 15, seconds: 1));
    lifecycle.dispose();
  });

  test('a failing refresh is swallowed', () async {
    failure = StateError('plugin');
    final lifecycle = build()..start();
    await flush();
    expect(refreshes, 1);
    lifecycle.dispose();
  });

  test('dispose stops every trigger', () async {
    final lifecycle = build()..start();
    await flush();
    lifecycle.dispose();
    expect(active(), isEmpty);
    signal.notify();
    restored.add(null);
    await flush();
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await flush();
    expect(refreshes, 1);
    expect(active(), isEmpty);
  });
}
