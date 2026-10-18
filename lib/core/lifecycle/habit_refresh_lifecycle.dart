import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../domain/play_period.dart';
import 'progress_sync_lifecycle.dart';

/// Runs the habit refresh (reminders and the home-screen widget):
/// - on start (app open) and on [AppLifecycleState.resumed]
/// - after a local progress change (a clear), debounced by [debounce]
/// - after a sync restored remote progress ([restored])
/// - just after each local midnight, while the app runs
class HabitRefreshLifecycle with WidgetsBindingObserver {
  HabitRefreshLifecycle({
    required this._refresh,
    required this._localChanges,
    this._restored,
    DateTime Function()? now,
    ProgressSyncTimerFactory? createTimer,
    this.debounce = defaultDebounce,
  }) : _now = now ?? DateTime.now,
       _createTimer = createTimer ?? Timer.new;

  static const defaultDebounce = Duration(seconds: 1);

  /// After midnight, so the new day id is already in effect.
  static const midnightSlack = Duration(seconds: 1);

  final Future<void> Function() _refresh;
  final Stream<void> _localChanges;
  final Stream<void>? _restored;
  final DateTime Function() _now;
  final ProgressSyncTimerFactory _createTimer;
  final Duration debounce;

  StreamSubscription<void>? _changeSub;
  StreamSubscription<void>? _restoredSub;
  Timer? _debounceTimer;
  Timer? _midnightTimer;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _changeSub = _localChanges.listen((_) => _onLocalChange());
    _restoredSub = _restored?.listen((_) => _refreshNow());
    _refreshNow();
  }

  void dispose() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _midnightTimer?.cancel();
    _midnightTimer = null;
    final changeSub = _changeSub;
    final restoredSub = _restoredSub;
    _changeSub = null;
    _restoredSub = null;
    if (changeSub != null) unawaited(changeSub.cancel());
    if (restoredSub != null) unawaited(restoredSub.cancel());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshNow();
  }

  void _onLocalChange() {
    if (!_started) return;
    _debounceTimer?.cancel();
    _debounceTimer = _createTimer(debounce, () {
      _debounceTimer = null;
      _refreshNow();
    });
  }

  void _refreshNow() {
    if (!_started) return;
    _armMidnight();
    unawaited(_run());
  }

  void _armMidnight() {
    _midnightTimer?.cancel();
    final now = _now();
    final wait =
        PlayPeriod.nextStart(now, PlayPeriod.daily).difference(now) +
        midnightSlack;
    _midnightTimer = _createTimer(
      wait.isNegative ? Duration.zero : wait,
      _refreshNow,
    );
  }

  Future<void> _run() async {
    try {
      await _refresh();
    } catch (e) {
      // Best effort: the next trigger replans.
      debugPrint('Habit refresh failed: $e');
    }
  }
}
