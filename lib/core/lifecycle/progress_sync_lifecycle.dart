import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/sync_progress.dart';

typedef ProgressSyncTimerFactory =
    Timer Function(Duration duration, void Function() callback);

/// Drives [SyncProgress]:
/// - start (signed in) -> full sync
/// - [AppLifecycleState.resumed] -> full sync, at most once per
///   [resumeThrottle]
/// - sign-in (null -> uid, or a different uid) -> full sync, unthrottled
/// - local progress change -> push-only sync, debounced by [pushDebounce]
///
/// [restored] fires after any run that changed local progress (Home reloads).
class ProgressSyncLifecycle with WidgetsBindingObserver {
  ProgressSyncLifecycle({
    required this._syncProgress,
    required this._authRepository,
    required this._localChanges,
    DateTime Function()? now,
    ProgressSyncTimerFactory? createTimer,
    this.resumeThrottle = const Duration(minutes: 2),
    this.pushDebounce = const Duration(seconds: 2),
  }) : _now = now ?? DateTime.now,
       _createTimer = createTimer ?? Timer.new;

  final SyncProgress _syncProgress;
  final AuthRepository _authRepository;
  final Stream<void> _localChanges;
  final DateTime Function() _now;
  final ProgressSyncTimerFactory _createTimer;
  final Duration resumeThrottle;
  final Duration pushDebounce;

  final StreamController<void> _restored = StreamController<void>.broadcast();
  StreamSubscription<AppUser?>? _authSub;
  StreamSubscription<void>? _changeSub;
  Timer? _pushTimer;
  String? _lastUid;
  DateTime? _lastFullSyncAt;
  bool _started = false;

  Stream<void> get restored => _restored.stream;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    // Seed before subscribe so the restored session is not a new sign-in.
    _lastUid = _authRepository.currentUser?.uid;
    _authSub = _authRepository.authStateChanges().listen(_onAuth);
    _changeSub = _localChanges.listen((_) => _onLocalChange());
    if (_lastUid != null) _fullSync();
  }

  void dispose() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _pushTimer?.cancel();
    _pushTimer = null;
    final authSub = _authSub;
    final changeSub = _changeSub;
    _authSub = null;
    _changeSub = null;
    if (authSub != null) unawaited(authSub.cancel());
    if (changeSub != null) unawaited(changeSub.cancel());
    unawaited(_restored.close());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_authRepository.currentUser == null) return;
    final last = _lastFullSyncAt;
    if (last != null && _now().difference(last) < resumeThrottle) return;
    _fullSync();
  }

  void _onAuth(AppUser? user) {
    final uid = user?.uid;
    final signedIn = uid != null && uid != _lastUid;
    _lastUid = uid;
    if (uid == null) {
      _pushTimer?.cancel();
      _pushTimer = null;
      return;
    }
    if (signedIn) _fullSync();
  }

  void _onLocalChange() {
    if (!_started) return;
    if (_authRepository.currentUser == null) return;
    _pushTimer?.cancel();
    _pushTimer = _createTimer(pushDebounce, () {
      _pushTimer = null;
      unawaited(_run(pull: false));
    });
  }

  void _fullSync() {
    // A full run pushes every changed item too.
    _pushTimer?.cancel();
    _pushTimer = null;
    _lastFullSyncAt = _now();
    unawaited(_run(pull: true));
  }

  Future<void> _run({required bool pull}) async {
    try {
      final result = await _syncProgress(pull: pull);
      if (result.localChanged && _started && !_restored.isClosed) {
        _restored.add(null);
      }
    } catch (e) {
      // SyncProgress reports its own failures; never crash the app here.
      debugPrint('Progress sync failed: $e');
    }
  }
}
